//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/SyncPlan.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   the bookkeeping inside lib/store.tsx's sync: the snapshot it keeps
//           under "classping.v1.snap:<user>" (PersistedSnapshot), the row
//           fingerprint `hashRow(JSON.stringify(row))`, what one table's flush
//           sends (`syncTable`), the pending count (`countPending`); and
//           lib/notes.ts (`conflictTitle`)
//
//  Summary: What the phone remembers about the server between syncs, and the
//           sums worked out from it before anything is sent: which rows
//           changed, which ids to delete, how many changes are waiting, and
//           what a first sync would do. Foundation only, so its tests run on
//           Linux.
//

import Foundation

// MARK: - The snapshot

/// The six tables kept as lists, in the order the web's flush sends them.
/// The profile goes before them and progress after, as on the web.
let LIST_TABLES: [ScopedTable] = [.classes, .tasks, .grades, .notes, .taskPlans, .studySessions]

/// What the server held the last time this phone and the server agreed: one
/// fingerprint per row, by table and id, plus one for the profile and one for
/// progress. It's the common ancestor 14a's merge needs to tell "changed
/// here" from "changed there". Saved in its own file, apart from the planner:
/// losing it costs one careful merge, never your work. The web's
/// `PersistedSnapshot`.
struct SyncSnapshot: Codable, Equatable, Sendable {
    /// Table name ("classes") to id to fingerprint.
    var tables: [String: [String: String]] = [:]
    /// The profile row's fingerprint, or nil when the server has no profile yet.
    var profile: String? = nil
    /// The progress row's fingerprint, or nil when the server has none yet.
    var game: String? = nil
    /// When the server last confirmed, in milliseconds since 1970, like 14a's
    /// `SyncStatus.lastSyncedAt`.
    var lastSyncedAt: Double? = nil

    /// One table's fingerprints (empty when it has none yet).
    func rows(_ table: ScopedTable) -> [String: String] {
        tables[table.rawValue] ?? [:]
    }

    /// Replaces one table's fingerprints.
    mutating func setRows(_ table: ScopedTable, _ fingerprints: [String: String]) {
        tables[table.rawValue] = fingerprints
    }
}

// MARK: - Fingerprints

/// A row as one line of JSON with its columns in alphabetical order. The web
/// fingerprints `JSON.stringify(row)`, whose order is the mapper's; a Swift
/// dictionary has no order, so sorting makes the same row give the same text
/// every time. It only has to agree with itself: each device keeps its own
/// snapshot.
func canonicalJSON(_ row: ServerRow) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(JSONValue.object(row)) else { return "" }
    return String(decoding: data, as: UTF8.self)
}

/// A row's fingerprint: 14a's `hashRow` of its canonical JSON. Two rows with
/// the same fingerprint say the same thing.
func rowFingerprint(_ row: ServerRow) -> String {
    hashRow(canonicalJSON(row))
}

// MARK: - What one table sends

/// What one table's flush sends: every row whose fingerprint moved since the
/// snapshot (new rows included), and the ids the snapshot has that this phone
/// no longer does (gone for good here, so gone from the server too). The web's
/// `syncTable`, worked out before anything is sent.
struct TableChanges: Equatable, Sendable {
    /// Rows to write.
    var upserts: [ServerRow] = []
    /// Ids to delete, in order.
    var deletes: [String] = []
    /// The new fingerprint of each row in `upserts`, by id, for the snapshot
    /// once the server has them.
    var fingerprints: [String: String] = [:]

    /// How many changes this is, for the "Waiting to sync" count.
    var count: Int { upserts.count + deletes.count }
}

/// Compares a table's rows on this phone with the snapshot.
func tableChanges(_ rows: [ServerRow], snapshot: [String: String]) -> TableChanges {
    var changes = TableChanges()
    var present: Set<String> = []
    // `continue` skips a row with no id; nothing can be sent without one.
    for row in rows {
        guard let id = row["id"]?.stringValue else { continue }
        present.insert(id)
        let fingerprint = rowFingerprint(row)
        if snapshot[id] != fingerprint {
            changes.upserts.append(row)
            changes.fingerprints[id] = fingerprint
        }
    }
    // Sorted so the same state always asks for the same deletes.
    changes.deletes = snapshot.keys.filter { !present.contains($0) }.sorted()
    return changes
}

// MARK: - What a first sync would do

/// One table's share of the first-sync review (D-90, D-97): what would happen
/// if you went ahead. Worked out from 14a's merge outcomes without changing
/// anything on the phone or the server.
struct TableReview: Equatable, Sendable {
    let table: ScopedTable
    /// Only on the web: the phone gets it.
    var fromWeb = 0
    /// Made on this phone and never sent: the web gets it.
    var toWeb = 0
    /// Changed on this phone since the last sync: the web gets the phone's version.
    var changedHere = 0
    /// On both, but different with nothing to say which came later (or both
    /// changed): the web's version stays. A note keeps the phone's version as
    /// a "Conflicted copy"; anything else loses the phone's version.
    var differ = 0
    /// Deleted somewhere else since the last sync: it goes from this phone too.
    var removedHere = 0
    /// The same on both sides.
    var same = 0

    /// True when nothing at all would change.
    var isQuiet: Bool { fromWeb + toWeb + changedHere + differ + removedHere == 0 }
}

/// Sorts a table's merge outcomes into the review's buckets. `localIDs` are
/// the ids this phone has, to tell "only on the web" from "the web's version
/// of something you also have".
func tableReview(_ table: ScopedTable, outcomes: [String: MergeOutcome], localIDs: Set<String>) -> TableReview {
    var review = TableReview(table: table)
    for (id, outcome) in outcomes {
        switch outcome {
        case .server:
            if localIDs.contains(id) { review.same += 1 } else { review.fromWeb += 1 }
        case .localNew:
            review.toWeb += 1
        case .local:
            review.changedHere += 1
        case .conflict:
            review.differ += 1
        case .removed:
            review.removedHere += 1
        }
    }
    return review
}

/// The words for one table in the review, as the web names things on screen.
func reviewTableName(_ table: ScopedTable) -> String {
    switch table {
    case .classes: return "Classes"
    case .tasks: return "Tasks"
    case .grades: return "Grades"
    case .notes: return "Notes"
    case .taskPlans: return "Planned days"
    case .studySessions: return "Study sessions"
    case .profiles: return "Profile"
    case .gameState: return "Progress"
    }
}

// MARK: - Notes both sides changed

/// What the web prefixes to a note both devices changed at once.
/// `CONFLICT_TITLE_PREFIX` in lib/notes.ts.
let CONFLICT_TITLE_PREFIX = "Conflicted copy"

/// The title for this phone's copy of such a note: "Conflicted copy, Week 1",
/// or just "Conflicted copy" for an untitled one. `conflictTitle`.
func conflictTitle(_ original: String) -> String {
    let base = original.trimmingCharacters(in: .whitespacesAndNewlines)
    return base.isEmpty ? CONFLICT_TITLE_PREFIX : "\(CONFLICT_TITLE_PREFIX), \(base)"
}

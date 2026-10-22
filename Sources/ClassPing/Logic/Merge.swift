//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Merge.swift
//  Phase:   14a (the sync rules, before any network)
//  Ports:   lib/merge.ts (`hashRow`, `mergeWithServer`, `snapshotToJson`,
//           `snapshotFromJson`); its tests are lib/merge.test.ts
//
//  Summary: The three-way merge that decides, row by row, what to keep when
//           this phone and the server disagree. It needs a third thing, the
//           "snapshot": a short fingerprint of every row as it was the last
//           time the server confirmed it. With that, "on my phone but not on
//           the server" can be told apart: made here and never sent (keep and
//           send), or deleted somewhere else (drop). Nothing here touches the
//           network; Phase 14c uses it.
//

import Foundation

// MARK: - The fingerprint

/// A short fingerprint of some text, 53 bits wide, written in base 36. The
/// web's `hashRow` (cyrb53). Two copies of a row get the same fingerprint
/// only if they are the same text, so comparing fingerprints answers "did
/// this row change?" without keeping the whole row.
///
/// It must give the web's exact answers: a snapshot the web saved has to mean
/// the same thing here. So it follows JavaScript's arithmetic exactly:
/// - `Math.imul` multiplies two 32-bit numbers and keeps the low 32 bits.
///   Swift's `&*` (the wrapping multiply) on `UInt32` does the same.
/// - `charCodeAt` reads UTF-16 units, so an emoji is two steps, not one.
///   Swift's `utf16` view gives the same units.
/// - `>>>` shifts without a sign; `>>` on `UInt32` does too.
func hashRow(_ input: String) -> String {
    var h1: UInt32 = 0xdeadbeef
    var h2: UInt32 = 0x41c6ce57
    // Mix in one UTF-16 unit at a time, as the web's loop does.
    for unit in input.utf16 {
        let ch = UInt32(unit)
        h1 = (h1 ^ ch) &* 2654435761
        h2 = (h2 ^ ch) &* 1597334677
    }
    // Two finishing rounds. The second uses the first's new h1, in this order.
    h1 = ((h1 ^ (h1 >> 16)) &* 2246822507) ^ ((h2 ^ (h2 >> 13)) &* 3266489909)
    h2 = ((h2 ^ (h2 >> 16)) &* 2246822507) ^ ((h1 ^ (h1 >> 13)) &* 3266489909)
    // 21 bits of h2 above all 32 bits of h1 make the 53-bit number the web
    // prints with `toString(36)`: lower case digits and letters.
    let value = (UInt64(h2 & 2_097_151) << 32) + UInt64(h1)
    return String(value, radix: 36)
}

// MARK: - The merge

/// What happened to one row in the merge. The raw text is the web's.
enum MergeOutcome: String, Sendable {
    /// Both sides agree, or only the server moved: the server's row is taken.
    case server
    /// Only this phone moved: its row is kept, and it still needs sending.
    case local
    /// Made here and never sent: kept, and it still needs sending.
    case localNew = "local-new"
    /// Gone from the server since we last agreed: dropped from this phone.
    case removed
    /// Both sides moved on their own: the caller decides, both are handed back.
    case conflict
}

/// Both versions of a row that changed on both sides since the last agreement.
struct MergeConflict<T> {
    let id: String
    let local: T
    let server: T
}

/// The merge's answer: the rows to keep, which of them still need sending,
/// the rows both sides changed, and why each row went the way it did.
/// `<T>` stands for whatever kind of row is being merged (a task, a class).
struct MergeResult<T> {
    var merged: [T]
    /// Ids whose phone version differs from the server's and must be sent.
    var pending: [String]
    var conflicts: [MergeConflict<T>]
    /// Per-id outcome: the merge's reasoning, kept for tests and diagnostics.
    var outcomes: [String: MergeOutcome]
}

/// Merges the server's rows into this phone's, using the snapshot as the
/// common ancestor. `rowJSON` turns a row into the text that gets
/// fingerprinted; `id` reads a row's id.
///
/// | on server | on phone | snapshot | result |
/// |---|---|---|---|
/// | yes | yes | matches the phone's row | the server's row (no local edit) |
/// | yes | yes | differs from the phone's | the phone's row, to send; if the server moved too, a conflict |
/// | yes | no | any | the server's row (another device made it) |
/// | no | yes | absent | keep and send (made here, never sent) |
/// | no | yes | present | drop (it was deleted or purged elsewhere) |
///
/// The last row stops a long-offline phone from bringing back everything it
/// deleted, which is why the snapshot is saved on the phone and survives a
/// close. A server row comes first in the order, then rows only the phone has.
func mergeWithServer<T>(
    _ local: [T],
    _ server: [T],
    snapshot: [String: String],
    id: (T) -> String,
    rowJSON: (T) -> String
) -> MergeResult<T> {
    // The web builds a Map from each list: a later row with the same id
    // replaces an earlier one, but keeps the earlier one's place in line.
    var localByID: [String: T] = [:]
    var localOrder: [String] = []
    for item in local {
        let key = id(item)
        if localByID[key] == nil { localOrder.append(key) }
        localByID[key] = item
    }
    var serverByID: [String: T] = [:]
    var serverOrder: [String] = []
    for item in server {
        let key = id(item)
        if serverByID[key] == nil { serverOrder.append(key) }
        serverByID[key] = item
    }

    // Server order first, then anything only the phone has, so the list
    // doesn't shuffle on every merge.
    var ids = serverOrder
    for key in localOrder where serverByID[key] == nil {
        ids.append(key)
    }

    var merged: [T] = []
    var pending: [String] = []
    var conflicts: [MergeConflict<T>] = []
    var outcomes: [String: MergeOutcome] = [:]

    for key in ids {
        let mine = localByID[key]
        let theirs = serverByID[key]
        let base = snapshot[key]

        if let theirs, mine == nil {
            // Only the server has it: another device made it.
            merged.append(theirs)
            outcomes[key] = .server
        } else if let mine, theirs == nil {
            if base == nil {
                // Never reached the server. This is the offline-made row the
                // web's old "replace everything" threw away.
                merged.append(mine)
                pending.append(key)
                outcomes[key] = .localNew
            } else {
                // We agreed it existed; the server says it doesn't any more.
                outcomes[key] = .removed
            }
        } else if let mine, let theirs {
            let mineHash = hashRow(rowJSON(mine))
            let theirsHash = hashRow(rowJSON(theirs))
            if mineHash == theirsHash {
                // The same row on both sides, whatever the snapshot says.
                merged.append(theirs)
                outcomes[key] = .server
            } else if let base {
                let localMoved = mineHash != base
                let serverMoved = theirsHash != base
                if localMoved && serverMoved {
                    conflicts.append(MergeConflict(id: key, local: mine, server: theirs))
                    merged.append(theirs)
                    outcomes[key] = .conflict
                } else if localMoved {
                    merged.append(mine)
                    pending.append(key)
                    outcomes[key] = .local
                } else {
                    merged.append(theirs)
                    outcomes[key] = .server
                }
            } else {
                // No common ancestor for a row both sides have: made apart
                // under one id, or the snapshot was lost. The server's row
                // holds the place; ours comes back as the other side.
                conflicts.append(MergeConflict(id: key, local: mine, server: theirs))
                merged.append(theirs)
                outcomes[key] = .conflict
            }
        }
    }

    return MergeResult(merged: merged, pending: pending, conflicts: conflicts, outcomes: outcomes)
}

// MARK: - Keeping the snapshot

/// The snapshot as JSON, for saving on the phone. The web's `snapshotToJson`.
func snapshotToJSON(_ snapshot: [String: String]) -> JSONValue {
    .object(snapshot.mapValues { JSONValue.string($0) })
}

/// The snapshot back from saved JSON. A missing, damaged or wrong-shaped
/// value gives an empty snapshot, and any entry that isn't text is skipped,
/// as the web's `snapshotFromJson` does. `compactMapValues` keeps only the
/// values the closure turns into something other than nil.
func snapshotFromJSON(_ raw: JSONValue?) -> [String: String] {
    guard case .object(let object)? = raw else { return [:] }
    return object.compactMapValues { $0.stringValue }
}

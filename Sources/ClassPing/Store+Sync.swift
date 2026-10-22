//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Sync.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   the sync half of lib/store.tsx: the first pull's merge
//           (`hydrate`, lines ~1316 to 1500 on 2026-10-22), the flush
//           (`syncTable` and `flush`, ~1752 to 1975) and the pending count
//
//  Summary: How the planner on this phone and the one on the server become
//           one. A pull is merged in with 14a's three-way merge, using the
//           snapshot as the common ancestor; a push sends only the rows that
//           changed since the snapshot and deletes what this phone no longer
//           has. No network code here: the way to the server is a
//           `SyncTransport`, so the store tests can use a fake one.
//

import Foundation

// MARK: - The way to the server

/// Everything the server holds for one account, as rows: the web's first
/// pull, eight selects at once.
struct ServerPull: Sendable {
    /// Rows for each of the six list tables (missing = none).
    var lists: [ScopedTable: [ServerRow]] = [:]
    /// The profile row, or nil for a brand-new account.
    var profile: ServerRow? = nil
    /// The progress row, or nil when there is none yet.
    var game: ServerRow? = nil
}

/// Why a step with the server failed: its message, and whether the phone
/// simply has no connection. 14a's `isAuthError` and `describeSyncError`
/// read the message.
struct SyncFailure: Error, Equatable, Sendable {
    var message: String
    var offline = false
}

/// The road to the server. The app's is `SupabaseTransport` (Sync/), which
/// needs the network and a signed-in account; the store tests use a fake
/// that records what it was asked. Every call gives back a `Result` (11a)
/// instead of throwing, so callers need no `do`/`catch`.
protocol SyncTransport: Sendable {
    /// Reads every table for the signed-in account.
    func pull() async -> Result<ServerPull, SyncFailure>
    /// Writes rows (insert or update by key). Gives back how many were sent.
    func upsert(_ table: ScopedTable, _ rows: [ServerRow]) async -> Result<Int, SyncFailure>
    /// Deletes rows by id. Gives back how many were asked for.
    func delete(_ table: ScopedTable, ids: [String]) async -> Result<Int, SyncFailure>
}

// MARK: - What a pull would do, and doing it

/// The first-sync review (D-90, D-97): per table, what going ahead would do,
/// and what happens to the profile and progress. Nothing has changed yet.
struct SyncReview: Equatable, Sendable {
    /// The six list tables, in order.
    var tables: [TableReview] = []
    /// The server has a profile, so the phone takes it (the web does the same
    /// on a first sync).
    var profileFromWeb = false
    /// The server has progress, so the phone takes it.
    var gameFromWeb = false

    /// Rows the web would get from this phone.
    var toWeb: Int { tables.reduce(0) { $0 + $1.toWeb + $1.changedHere } }
    /// Rows this phone would get from the web.
    var fromWeb: Int { tables.reduce(0) { $0 + $1.fromWeb } }
    /// Rows where the web's version would be kept over this phone's.
    var differ: Int { tables.reduce(0) { $0 + $1.differ } }
}

/// One list's merge: the merged items, what the review counts, and the new
/// fingerprints (built from the server's rows, as the web rebuilds its
/// snapshot from what the server just said it holds).
private struct ListMerge<T> {
    var result: MergeResult<T>
    var review: TableReview
    var fingerprints: [String: String]
}

/// Merges one list. `read` turns a server row into an item (nil for a row
/// the phone can't use); `write` is the item's `serverRow`.
private func mergeList<T: Identifiable>(
    _ table: ScopedTable,
    local: [T],
    serverRows: [ServerRow],
    base: [String: String],
    read: (ServerRow) -> T?,
    write: (T) -> ServerRow
) -> ListMerge<T> where T.ID == UUID {
    let server = serverRows.compactMap(read)
    let result = mergeWithServer(local, server, snapshot: base,
                                 id: { webID($0.id) },
                                 rowJSON: { canonicalJSON(write($0)) })
    var fingerprints: [String: String] = [:]
    for item in server {
        fingerprints[webID(item.id)] = rowFingerprint(write(item))
    }
    let review = tableReview(table, outcomes: result.outcomes,
                             localIDs: Set(local.map { webID($0.id) }))
    return ListMerge(result: result, review: review, fingerprints: fingerprints)
}

extension Store {
    /// Works out what merging `pull` would do, without changing anything on
    /// the phone. The first-sync review shows it before you say go (D-90).
    func reviewPull(_ pull: ServerPull, snapshot: SyncSnapshot?, userID: String) -> SyncReview {
        let base = snapshot ?? SyncSnapshot()
        var review = SyncReview()
        review.tables = [
            mergeList(.classes, local: courses, serverRows: pull.lists[.classes] ?? [], base: base.rows(.classes),
                      read: Course.init(serverRow:), write: { $0.serverRow(userID: userID) }).review,
            mergeList(.tasks, local: assignments, serverRows: pull.lists[.tasks] ?? [], base: base.rows(.tasks),
                      read: Assignment.init(serverRow:), write: { $0.serverRow(userID: userID) }).review,
            mergeList(.grades, local: grades, serverRows: pull.lists[.grades] ?? [], base: base.rows(.grades),
                      read: Grade.init(serverRow:), write: { $0.serverRow(userID: userID) }).review,
            mergeList(.notes, local: notes, serverRows: pull.lists[.notes] ?? [], base: base.rows(.notes),
                      read: Note.init(serverRow:), write: { $0.serverRow(userID: userID) }).review,
            mergeList(.taskPlans, local: taskPlans, serverRows: pull.lists[.taskPlans] ?? [], base: base.rows(.taskPlans),
                      read: TaskPlan.init(serverRow:), write: { $0.serverRow(userID: userID) }).review,
            mergeList(.studySessions, local: studySessions, serverRows: pull.lists[.studySessions] ?? [],
                      base: base.rows(.studySessions),
                      read: StudySession.init(serverRow:), write: { $0.serverRow(userID: userID) }).review,
        ]
        review.profileFromWeb = pull.profile != nil && !profileChangedHere(base, userID: userID)
        review.gameFromWeb = pull.game != nil
        return review
    }

    /// Merges a pull into this phone, saves the planner, and gives back the
    /// new snapshot. The web's hydrate: each list through the merge with the
    /// snapshot as the common ancestor; a note both sides changed keeps this
    /// phone's version beside the server's as a "Conflicted copy"; the
    /// profile takes the server's unless you changed it here since the last
    /// sync; progress always takes the server's.
    @discardableResult
    func applyPull(_ pull: ServerPull, snapshot: SyncSnapshot?, userID: String, now: Date) -> SyncSnapshot {
        let base = snapshot ?? SyncSnapshot()
        var next = SyncSnapshot()

        let classes = mergeList(.classes, local: courses, serverRows: pull.lists[.classes] ?? [],
                                base: base.rows(.classes), read: Course.init(serverRow:),
                                write: { $0.serverRow(userID: userID) })
        courses = classes.result.merged
        next.setRows(.classes, classes.fingerprints)

        let tasks = mergeList(.tasks, local: assignments, serverRows: pull.lists[.tasks] ?? [],
                              base: base.rows(.tasks), read: Assignment.init(serverRow:),
                              write: { $0.serverRow(userID: userID) })
        assignments = tasks.result.merged
        next.setRows(.tasks, tasks.fingerprints)

        let gradeMerge = mergeList(.grades, local: grades, serverRows: pull.lists[.grades] ?? [],
                                   base: base.rows(.grades), read: Grade.init(serverRow:),
                                   write: { $0.serverRow(userID: userID) })
        grades = gradeMerge.result.merged
        next.setRows(.grades, gradeMerge.fingerprints)

        let noteMerge = mergeList(.notes, local: notes, serverRows: pull.lists[.notes] ?? [],
                                  base: base.rows(.notes), read: Note.init(serverRow:),
                                  write: { $0.serverRow(userID: userID) })
        // Nobody's typing is thrown away: this phone's side of a conflict
        // becomes a new note, which the next push sends as one.
        let copies = noteMerge.result.conflicts.map { conflict -> Note in
            var copy = conflict.local
            copy.id = UUID()
            copy.title = conflictTitle(conflict.local.title)
            copy.updatedAt = now
            return copy
        }
        notes = noteMerge.result.merged + copies
        next.setRows(.notes, noteMerge.fingerprints)

        let plans = mergeList(.taskPlans, local: taskPlans, serverRows: pull.lists[.taskPlans] ?? [],
                              base: base.rows(.taskPlans), read: TaskPlan.init(serverRow:),
                              write: { $0.serverRow(userID: userID) })
        taskPlans = plans.result.merged
        next.setRows(.taskPlans, plans.fingerprints)

        let sessions = mergeList(.studySessions, local: studySessions,
                                 serverRows: pull.lists[.studySessions] ?? [],
                                 base: base.rows(.studySessions), read: StudySession.init(serverRow:),
                                 write: { $0.serverRow(userID: userID) })
        studySessions = sessions.result.merged
        next.setRows(.studySessions, sessions.fingerprints)

        // The profile: a preference changed here since the last sync outranks
        // the server's copy; otherwise the server's wins. No server row yet
        // (a new account): nil, and the next push sends this phone's.
        if let row = pull.profile {
            let fromServer = Profile(serverRow: row)
            if !profileChangedHere(base, userID: userID) { profile = fromServer }
            next.profile = rowFingerprint(fromServer.serverRow(userID: userID))
        }

        // Progress: the server's, kept exactly as it is (D-74).
        if let row = pull.game {
            game = GameBlobs(serverRow: row)
            next.game = rowFingerprint(game.serverRow(userID: userID))
        }

        // Saved before anything goes to the network, as everywhere else.
        save()
        next.lastSyncedAt = (now.timeIntervalSince1970 * 1000).rounded()
        return next
    }

    /// True when you changed the profile here since the server last
    /// confirmed it. Never true before the first sync (no fingerprint yet).
    private func profileChangedHere(_ snapshot: SyncSnapshot, userID: String) -> Bool {
        guard let known = snapshot.profile else { return false }
        return rowFingerprint(profile.serverRow(userID: userID)) != known
    }
}

// MARK: - What a push sends, and sending it

/// Everything waiting to go to the server, worked out from the snapshot.
struct PendingPush: Equatable, Sendable {
    /// The profile row, when it changed (nil = nothing to send).
    var profile: ServerRow? = nil
    /// The list tables that have changes, in send order.
    var tables: [ScopedTable: TableChanges] = [:]
    /// The progress row, when it changed.
    var game: ServerRow? = nil

    /// How many changes are waiting: rows to write, ids to delete, and one
    /// each for the profile and progress. The web's `countPending`.
    var count: Int {
        tables.values.reduce(0) { $0 + $1.count } + (profile == nil ? 0 : 1) + (game == nil ? 0 : 1)
    }
}

extension Store {
    /// What this phone would send now. The web computes the same before every
    /// flush, which is also what the "Waiting to sync" count shows.
    func pendingPush(snapshot: SyncSnapshot, userID: String) -> PendingPush {
        var pending = PendingPush()
        let profileRow = profile.serverRow(userID: userID)
        if snapshot.profile != rowFingerprint(profileRow) { pending.profile = profileRow }
        let rows: [ScopedTable: [ServerRow]] = [
            .classes: courses.map { $0.serverRow(userID: userID) },
            .tasks: assignments.map { $0.serverRow(userID: userID) },
            .grades: grades.map { $0.serverRow(userID: userID) },
            .notes: notes.map { $0.serverRow(userID: userID) },
            .taskPlans: taskPlans.map { $0.serverRow(userID: userID) },
            .studySessions: studySessions.map { $0.serverRow(userID: userID) },
        ]
        for table in LIST_TABLES {
            let changes = tableChanges(rows[table] ?? [], snapshot: snapshot.rows(table))
            if changes.count > 0 { pending.tables[table] = changes }
        }
        let gameRow = game.serverRow(userID: userID)
        if snapshot.game != rowFingerprint(gameRow) { pending.game = gameRow }
        return pending
    }

    /// Sends what's pending, in the web's order: profile, then each list
    /// (writes, then deletes), then progress. After each step the server
    /// confirms, the snapshot learns it, so a failure halfway loses nothing:
    /// the next push sends only what's still different. Gives back the
    /// snapshot as far as it got, and the failure, if any.
    func push(_ pending: PendingPush, snapshot: SyncSnapshot, via transport: some SyncTransport,
              now: Date) async -> (snapshot: SyncSnapshot, failure: SyncFailure?) {
        var next = snapshot

        if let row = pending.profile {
            let sent = await send(.profiles, [row], via: transport)
            if let failure = sent { return (next, failure) }
            next.profile = rowFingerprint(row)
        }

        // `where` visits only the tables with changes; no `break` needed,
        // each failure returns straight away.
        for table in LIST_TABLES where pending.tables[table] != nil {
            let changes = pending.tables[table] ?? TableChanges()
            var known = next.rows(table)
            if !changes.upserts.isEmpty {
                let sent = await send(table, changes.upserts, via: transport)
                if let failure = sent { return (next, failure) }
                for (id, fingerprint) in changes.fingerprints { known[id] = fingerprint }
                next.setRows(table, known)
            }
            if !changes.deletes.isEmpty {
                if case .failure(let failure) = await transport.delete(table, ids: changes.deletes) {
                    return (next, failure)
                }
                for id in changes.deletes { known[id] = nil }
                next.setRows(table, known)
            }
        }

        if let row = pending.game {
            let sent = await send(.gameState, [row], via: transport)
            if let failure = sent { return (next, failure) }
            next.game = rowFingerprint(row)
        }

        next.lastSyncedAt = (now.timeIntervalSince1970 * 1000).rounded()
        return (next, nil)
    }

    /// Trims rows to the table's columns (14a's `scopeRows`) and writes them.
    /// Nil when it worked, otherwise why not.
    private func send(_ table: ScopedTable, _ rows: [ServerRow],
                      via transport: some SyncTransport) async -> SyncFailure? {
        switch scopeRows(table, rows) {
        case .failure(let contract):
            return SyncFailure(message: contract.message)
        case .success(let scoped):
            if case .failure(let failure) = await transport.upsert(table, scoped) { return failure }
            return nil
        }
    }
}

// MARK: - Keeping the snapshot

extension Store {
    /// Where one account's snapshot is kept: beside planner.json, one file per
    /// account, so signing in as someone else never reuses it. The web's
    /// `snapKey`.
    static func snapshotURL(userID: String) -> URL {
        let safe = userID.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return documentsFolder.appending(path: "sync-\(safe).json")
    }

    /// The saved snapshot for this account, or nil before its first sync (or
    /// if the file can't be read, which only costs one careful merge).
    static func loadSnapshot(userID: String) -> SyncSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL(userID: userID)) else { return nil }
        return try? JSONDecoder().decode(SyncSnapshot.self, from: data)
    }

    /// Saves the snapshot. False when it couldn't be written.
    @discardableResult
    static func saveSnapshot(_ snapshot: SyncSnapshot, userID: String) -> Bool {
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        return (try? data.write(to: snapshotURL(userID: userID), options: .atomic)) != nil
    }
}

// SyncStoreTests.swift: the store's half of sync (Store+Sync.swift) against
// a fake server that never touches the network: the first-sync review
// changes nothing; a first sync keeps both sides' new work, lets the web win
// a clash (a note keeps a "Conflicted copy"), and takes the web's profile and
// progress; later syncs keep an edit made here, drop what was deleted
// elsewhere, delete on the server what left this phone, and a failure
// halfway loses nothing. The rules are lib/store.tsx's hydrate and flush.
// Uses an isolated Documents path, never the real planner file.
// Run: tools/persistence-test.sh (CI: scripts/test-store.sh).
// Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
private let USER = "user_test"
private let C_PHONE = id("10000000-0000-4000-8000-000000000001")   // only on the phone
private let C_WEB = id("10000000-0000-4000-8000-000000000002")     // only on the web
private let C_BOTH = id("10000000-0000-4000-8000-000000000003")    // on both, different
private let N_BOTH = id("40000000-0000-4000-8000-000000000001")    // a note on both, different
private let NOW = Date(timeIntervalSince1970: 1_790_000_000)

private func course(_ uuid: UUID, _ name: String) -> Course {
    Course(id: uuid, name: name, short: String(name.prefix(4)), color: .teal, days: [0, 2], startMin: 540, endMin: 600)
}

private func note(_ uuid: UUID, _ title: String, _ body: String) -> Note {
    Note(id: uuid, courseID: nil, date: "2026-09-01", title: title, body: body, assignmentID: nil, updatedAt: NOW)
}

/// A server that keeps rows in memory and remembers what it was asked.
/// An `actor` so the store's async calls can reach it safely from any thread.
private actor FakeServer: SyncTransport {
    var lists: [ScopedTable: [ServerRow]] = [:]
    var profile: ServerRow? = nil
    var game: ServerRow? = nil
    var upserts: [(ScopedTable, [ServerRow])] = []
    var deletes: [(ScopedTable, [String])] = []
    /// A table whose writes fail, to test a failure halfway.
    var failing: ScopedTable? = nil

    init(lists: [ScopedTable: [ServerRow]] = [:], profile: ServerRow? = nil, game: ServerRow? = nil) {
        self.lists = lists
        self.profile = profile
        self.game = game
    }

    func failWrites(to table: ScopedTable?) { failing = table }

    func pull() async -> Result<ServerPull, SyncFailure> {
        .success(ServerPull(lists: lists, profile: profile, game: game))
    }

    func upsert(_ table: ScopedTable, _ rows: [ServerRow]) async -> Result<Int, SyncFailure> {
        if table == failing { return .failure(SyncFailure(message: "network: offline", offline: true)) }
        upserts.append((table, rows))
        switch table {
        case .profiles: profile = rows.first
        case .gameState: game = rows.first
        default:
            var current = lists[table] ?? []
            for row in rows {
                current.removeAll { $0["id"] == row["id"] }
                current.append(row)
            }
            lists[table] = current
        }
        return .success(rows.count)
    }

    func delete(_ table: ScopedTable, ids: [String]) async -> Result<Int, SyncFailure> {
        deletes.append((table, ids))
        lists[table] = (lists[table] ?? []).filter { !ids.contains($0["id"]?.stringValue ?? "") }
        return .success(ids.count)
    }

    func upsertedIDs(_ table: ScopedTable) -> [String] {
        upserts.filter { $0.0 == table }.flatMap { $0.1 }.compactMap { $0["id"]?.stringValue }
    }

    func deletedIDs(_ table: ScopedTable) -> [String] {
        deletes.filter { $0.0 == table }.flatMap { $0.1 }
    }

    func rowCount(_ table: ScopedTable) -> Int { (lists[table] ?? []).count }
}

@MainActor
@Suite(.serialized) struct SyncStoreTests {
    /// An empty store with no planner file and no snapshot.
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        try? FileManager.default.removeItem(at: Store.snapshotURL(userID: USER))
        return Store()
    }

    /// The phone: one class only it has, one on both (named differently), a
    /// note on both (written differently), and a name of its own.
    private func phone() -> Store {
        let store = fresh()
        store.courses = [course(C_PHONE, "Phone Only"), course(C_BOTH, "Biology (phone)")]
        store.notes = [note(N_BOTH, "Week 1", "Typed on the phone")]
        store.profile.username = "Phone name"
        return store
    }

    /// The web: one class only it has, the shared class and note as the web
    /// has them, a profile and some progress.
    private func web() -> FakeServer {
        var profile = Profile()
        profile.username = "Web name"
        profile.accent = .ocean
        return FakeServer(
            lists: [
                .classes: [course(C_WEB, "Web Only").serverRow(userID: USER),
                           course(C_BOTH, "Biology (web)").serverRow(userID: USER)],
                .notes: [note(N_BOTH, "Week 1", "Typed on the web").serverRow(userID: USER)],
            ],
            profile: profile.serverRow(userID: USER),
            game: GameBlobs(xp: .object(["total": .number(120)])).serverRow(userID: USER))
    }

    // MARK: the review changes nothing (D-90)

    @Test func theReviewChangesNothingAndCountsWhatWouldHappen() async {
        let store = phone()
        let before = store.document
        let server = web()
        guard case .success(let pull) = await server.pull() else { Issue.record("no pull"); return }
        let review = store.reviewPull(pull, snapshot: nil, userID: USER)
        #expect(store.document == before)
        let classes = review.tables.first { $0.table == .classes }
        #expect(classes?.toWeb == 1)       // Phone Only
        #expect(classes?.fromWeb == 1)     // Web Only
        #expect(classes?.differ == 1)      // Biology, no common ancestor
        #expect(review.tables.first { $0.table == .notes }?.differ == 1)
        #expect(review.profileFromWeb)
        #expect(review.gameFromWeb)
        #expect(review.toWeb == 1)
        #expect(review.fromWeb == 1)
        #expect(await server.upserts.isEmpty)
    }

    // MARK: a first sync

    @Test func aFirstSyncKeepsBothSidesNewWorkAndTheWebWinsAClash() async {
        let store = phone()
        let server = web()
        guard case .success(let pull) = await server.pull() else { Issue.record("no pull"); return }
        let snapshot = store.applyPull(pull, snapshot: nil, userID: USER, now: NOW)

        // Classes: the web's two in the server's order, then the phone's own.
        #expect(store.courses.map(\.name) == ["Web Only", "Biology (web)", "Phone Only"])
        // The note: the web's version, plus the phone's as a conflicted copy.
        #expect(store.notes.count == 2)
        #expect(store.notes.first { $0.id == N_BOTH }?.body == "Typed on the web")
        let copy = store.notes.first { $0.id != N_BOTH }
        #expect(copy?.title == "Conflicted copy, Week 1")
        #expect(copy?.body == "Typed on the phone")
        #expect(copy?.updatedAt == NOW)
        // Profile and progress come from the web on a first sync.
        #expect(store.profile.username == "Web name")
        #expect(store.profile.accent == .ocean)
        #expect(store.game.xp == .object(["total": .number(120)]))
        // The snapshot is what the server said it holds.
        #expect(Set(snapshot.rows(.classes).keys) == [webID(C_WEB), webID(C_BOTH)])
        #expect(snapshot.profile != nil)
        #expect(snapshot.lastSyncedAt == 1_790_000_000_000)
        // And the planner was saved before anything else.
        #expect(Store.load().courses.count == 3)
    }

    @Test func afterAFirstSyncOnlyThePhonesOwnWorkIsSent() async {
        let store = phone()
        let server = web()
        guard case .success(let pull) = await server.pull() else { Issue.record("no pull"); return }
        let snapshot = store.applyPull(pull, snapshot: nil, userID: USER, now: NOW)
        let pending = store.pendingPush(snapshot: snapshot, userID: USER)
        // The phone's class and the note copy; nothing else differs.
        #expect(pending.tables[.classes]?.upserts.compactMap { $0["id"]?.stringValue } == [webID(C_PHONE)])
        #expect(pending.tables[.notes]?.upserts.count == 1)
        #expect(pending.tables[.classes]?.deletes == [])
        #expect(pending.profile == nil)
        #expect(pending.game == nil)
        #expect(pending.count == 2)

        let outcome = await store.push(pending, snapshot: snapshot, via: server, now: NOW)
        #expect(outcome.failure == nil)
        #expect(await server.upsertedIDs(.classes) == [webID(C_PHONE)])
        #expect(await server.rowCount(.classes) == 3)
        #expect(await server.deletes.isEmpty)
        // Nothing is left to send.
        #expect(store.pendingPush(snapshot: outcome.snapshot, userID: USER).count == 0)
    }

    // MARK: later syncs

    @Test func anEditHereSinceTheLastSyncIsKeptAndSent() async {
        let store = phone()
        let server = web()
        guard case .success(let first) = await server.pull() else { Issue.record("no pull"); return }
        var snapshot = store.applyPull(first, snapshot: nil, userID: USER, now: NOW)
        snapshot = await store.push(store.pendingPush(snapshot: snapshot, userID: USER),
                                    snapshot: snapshot, via: server, now: NOW).snapshot

        // Renamed here; the server hasn't moved.
        if let index = store.courses.firstIndex(where: { $0.id == C_WEB }) {
            store.courses[index].name = "Renamed here"
        }
        guard case .success(let second) = await server.pull() else { Issue.record("no pull"); return }
        snapshot = store.applyPull(second, snapshot: snapshot, userID: USER, now: NOW)
        #expect(store.courses.first { $0.id == C_WEB }?.name == "Renamed here")
        let pending = store.pendingPush(snapshot: snapshot, userID: USER)
        #expect(pending.tables[.classes]?.upserts.compactMap { $0["name"]?.stringValue } == ["Renamed here"])
    }

    @Test func somethingDeletedElsewhereGoesFromThisPhone() async {
        let store = phone()
        let server = web()
        guard case .success(let first) = await server.pull() else { Issue.record("no pull"); return }
        var snapshot = store.applyPull(first, snapshot: nil, userID: USER, now: NOW)
        snapshot = await store.push(store.pendingPush(snapshot: snapshot, userID: USER),
                                    snapshot: snapshot, via: server, now: NOW).snapshot

        // The web deletes "Web Only" for good.
        _ = await server.delete(.classes, ids: [webID(C_WEB)])
        guard case .success(let second) = await server.pull() else { Issue.record("no pull"); return }
        snapshot = store.applyPull(second, snapshot: snapshot, userID: USER, now: NOW)
        #expect(!store.courses.contains { $0.id == C_WEB })
        // And it isn't sent back.
        #expect(store.pendingPush(snapshot: snapshot, userID: USER).count == 0)
    }

    @Test func somethingGoneFromThisPhoneIsDeletedOnTheServer() async {
        let store = phone()
        let server = web()
        guard case .success(let first) = await server.pull() else { Issue.record("no pull"); return }
        var snapshot = store.applyPull(first, snapshot: nil, userID: USER, now: NOW)
        snapshot = await store.push(store.pendingPush(snapshot: snapshot, userID: USER),
                                    snapshot: snapshot, via: server, now: NOW).snapshot

        // Gone for good here (the 30-day clear-out, D-75).
        store.courses.removeAll { $0.id == C_PHONE }
        let pending = store.pendingPush(snapshot: snapshot, userID: USER)
        #expect(pending.tables[.classes]?.deletes == [webID(C_PHONE)])
        let outcome = await store.push(pending, snapshot: snapshot, via: server, now: NOW)
        #expect(await server.deletedIDs(.classes) == [webID(C_PHONE)])
        #expect(outcome.snapshot.rows(.classes)[webID(C_PHONE)] == nil)
    }

    @Test func aFailureHalfwayLosesNothing() async {
        let store = phone()
        store.assignments = [Assignment(id: id("20000000-0000-4000-8000-000000000001"), courseID: nil,
                                        title: "Essay", due: "2026-09-10", dueTime: nil)]
        let server = FakeServer()
        await server.failWrites(to: .tasks)
        let snapshot = store.applyPull(ServerPull(), snapshot: nil, userID: USER, now: NOW)
        let pending = store.pendingPush(snapshot: snapshot, userID: USER)
        let outcome = await store.push(pending, snapshot: snapshot, via: server, now: NOW)
        #expect(outcome.failure?.offline == true)
        // The profile and classes went through and are remembered...
        #expect(outcome.snapshot.profile != nil)
        #expect(outcome.snapshot.rows(.classes).count == 2)
        // ...so next time only the task (and what follows it) is left.
        let left = store.pendingPush(snapshot: outcome.snapshot, userID: USER)
        #expect(left.tables[.classes] == nil)
        #expect(left.tables[.tasks]?.upserts.count == 1)
        #expect(left.profile == nil)
    }

    @Test func aProfileChangedHereSinceTheLastSyncIsKept() async {
        let store = phone()
        let server = web()
        guard case .success(let first) = await server.pull() else { Issue.record("no pull"); return }
        let snapshot = store.applyPull(first, snapshot: nil, userID: USER, now: NOW)
        #expect(store.profile.username == "Web name")
        store.profile.username = "Changed here"
        guard case .success(let second) = await server.pull() else { Issue.record("no pull"); return }
        store.applyPull(second, snapshot: snapshot, userID: USER, now: NOW)
        #expect(store.profile.username == "Changed here")
    }

    @Test func aNewAccountGetsThisPhonesProfileAndProgress() async {
        let store = phone()
        store.game = GameBlobs(pet: .object(["tier": .number(1)]))
        let server = FakeServer()
        let snapshot = store.applyPull(ServerPull(), snapshot: nil, userID: USER, now: NOW)
        #expect(snapshot.profile == nil)
        let pending = store.pendingPush(snapshot: snapshot, userID: USER)
        #expect(pending.profile?["username"] == .string("Phone name"))
        #expect(pending.game?["data"]?["pet"] == .object(["tier": .number(1)]))
        _ = await store.push(pending, snapshot: snapshot, via: server, now: NOW)
        #expect(await server.profile?["username"] == .string("Phone name"))
    }

    @Test func theSnapshotIsSavedPerAccount() {
        _ = fresh()
        var snapshot = SyncSnapshot()
        snapshot.setRows(.classes, ["a": "1"])
        #expect(Store.saveSnapshot(snapshot, userID: USER))
        #expect(Store.loadSnapshot(userID: USER) == snapshot)
        #expect(Store.loadSnapshot(userID: "user_someone_else") == nil)
        #expect(Store.snapshotURL(userID: "user_a/../b").lastPathComponent == "sync-user_ab.json")
    }
}

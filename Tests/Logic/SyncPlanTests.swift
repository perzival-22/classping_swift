// SyncPlanTests.swift: the sync bookkeeping of Phase 14cd
// (Logic/SyncPlan.swift): fingerprints, what one table's flush sends, the
// first-sync review's buckets, the snapshot file, and lib/notes.ts's
// conflictTitle. Run: tools/logic-test.sh (CI: scripts/test-logic.sh).
// Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func row(_ id: String, _ title: String) -> ServerRow {
    ["id": .string(id), "user_id": .string("user_1"), "title": .string(title)]
}

@Suite struct SyncPlanTests {
    // MARK: fingerprints

    @Test func canonicalJSONSortsTheColumns() {
        let a: ServerRow = ["b": .bool(true), "a": .string("x/y"), "c": .null]
        #expect(canonicalJSON(a) == #"{"a":"x/y","b":true,"c":null}"#)
    }

    @Test func theSameRowGivesTheSameFingerprint() {
        let a: ServerRow = ["id": .string("1"), "title": .string("Essay"), "done": .bool(false)]
        let b: ServerRow = ["done": .bool(false), "title": .string("Essay"), "id": .string("1")]
        #expect(rowFingerprint(a) == rowFingerprint(b))
        #expect(rowFingerprint(a) != rowFingerprint(["id": .string("1"), "title": .string("Essay!"), "done": .bool(false)]))
    }

    // MARK: what a table sends (the web's syncTable)

    @Test func sendsNewAndChangedRowsAndDeletesWhatLeft() {
        let kept = row("a", "Same")
        let changed = row("b", "Changed")
        let added = row("c", "New")
        let snapshot = ["a": rowFingerprint(kept), "b": rowFingerprint(row("b", "Before")),
                        "z": "gone", "y": "gone too"]
        let changes = tableChanges([kept, changed, added], snapshot: snapshot)
        #expect(changes.upserts.compactMap { $0["id"]?.stringValue } == ["b", "c"])
        #expect(changes.deletes == ["y", "z"])
        #expect(changes.fingerprints["b"] == rowFingerprint(changed))
        #expect(changes.fingerprints["a"] == nil)
        #expect(changes.count == 4)
    }

    @Test func aRowWithoutAnIdIsNeverSent() {
        let changes = tableChanges([["title": .string("no id")]], snapshot: [:])
        #expect(changes.upserts.isEmpty)
        #expect(changes.count == 0)
    }

    @Test func nothingChangedSendsNothing() {
        let rows = [row("a", "One"), row("b", "Two")]
        let snapshot = Dictionary(uniqueKeysWithValues: rows.map { ($0["id"]?.stringValue ?? "", rowFingerprint($0)) })
        #expect(tableChanges(rows, snapshot: snapshot) == TableChanges())
    }

    // MARK: the first-sync review

    @Test func sortsOutcomesIntoTheReviewsBuckets() {
        let outcomes: [String: MergeOutcome] = [
            "web-only": .server, "both-same": .server, "mine": .localNew,
            "edited": .local, "clash": .conflict, "gone": .removed,
        ]
        let review = tableReview(.tasks, outcomes: outcomes, localIDs: ["both-same", "mine", "edited", "clash", "gone"])
        #expect(review.fromWeb == 1)
        #expect(review.same == 1)
        #expect(review.toWeb == 1)
        #expect(review.changedHere == 1)
        #expect(review.differ == 1)
        #expect(review.removedHere == 1)
        #expect(!review.isQuiet)
        #expect(tableReview(.tasks, outcomes: ["a": .server], localIDs: ["a"]).isQuiet)
    }

    @Test func namesEachTableInTheWebsWords() {
        #expect(reviewTableName(.classes) == "Classes")
        #expect(reviewTableName(.tasks) == "Tasks")
        #expect(reviewTableName(.taskPlans) == "Planned days")
    }

    // MARK: the snapshot

    @Test func theSnapshotKeepsEachTablesFingerprints() {
        var snapshot = SyncSnapshot()
        #expect(snapshot.rows(.classes).isEmpty)
        snapshot.setRows(.classes, ["a": "1"])
        snapshot.profile = "p"
        snapshot.lastSyncedAt = 1_790_000_000_000
        #expect(snapshot.rows(.classes) == ["a": "1"])
        #expect(snapshot.tables["classes"] == ["a": "1"])
        let data = (try? JSONEncoder().encode(snapshot)) ?? Data()
        #expect((try? JSONDecoder().decode(SyncSnapshot.self, from: data)) == snapshot)
    }

    @Test func listsGoInTheWebsOrder() {
        #expect(LIST_TABLES.map(\.rawValue) == ["classes", "tasks", "grades", "notes", "task_plans", "study_sessions"])
    }

    // MARK: notes both sides changed (lib/notes.ts)

    @Test func namesTheConflictedCopy() {
        #expect(conflictTitle("Week 1") == "Conflicted copy, Week 1")
        #expect(conflictTitle("  Week 1 \n") == "Conflicted copy, Week 1")
        #expect(conflictTitle("") == "Conflicted copy")
        #expect(conflictTitle("   ") == "Conflicted copy")
    }
}

// FeedStoreTests.swift: saved calendar feeds and a refresh through the store
// (Store+Feeds.swift): lib/feeds.ts's list helpers, case for case from
// feeds.test.ts, then previewFeed and applyFeedWrites on real Courses and
// Assignments, and the wipe after an account is deleted (Store+Sync.swift).
// Uses an isolated Documents path, never the real planner file.
// Run: tools/persistence-test.sh (CI: scripts/test-store.sh). Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private let DAY: TimeInterval = 86_400

private func feed(_ url: String, id: UUID = UUID(), label: String = "x", last: Date? = nil) -> SavedFeed {
    SavedFeed(id: id, url: url, label: label, lastSyncedAt: last)
}

@Suite struct FeedListTests {
    @Test func addsANewFeed() {
        let one = feed("https://a.edu/x.ics")
        #expect(upsertFeed([], one) == [one])
    }

    @Test func refreshesTheExistingEntryWhenTheSameURLIsPastedAgain() {
        let first = feed("https://a.edu/x.ics", label: "old")
        let again = feed("https://a.edu/x.ics", label: "new")
        let next = upsertFeed([first], again)
        #expect(next.count == 1)
        #expect(next[0].id == first.id)
        #expect(next[0].label == "new")
    }

    @Test func refusesToGrowPastTheCap() {
        let five = (0..<5).map { feed("https://a.edu/\($0).ics") }
        #expect(upsertFeed(five, feed("https://a.edu/6.ics")) == five)
    }

    @Test func removesByIDAndRecordsARefresh() {
        let a = feed("https://a.edu/a.ics")
        let b = feed("https://a.edu/b.ics")
        #expect(removeFeed([a, b], id: a.id) == [b])
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(markFeedSynced([a, b], id: b.id, at: at).map(\.lastSyncedAt) == [nil, at])
    }

    @Test func saysHowOldAFeedIs() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(lastSyncedLabel(feed("https://a"), now: now) == "Never refreshed")
        #expect(lastSyncedLabel(feed("https://a", last: Date(timeIntervalSince1970: 0)), now: now) == "Never refreshed")
        #expect(lastSyncedLabel(feed("https://a", last: now.addingTimeInterval(-3_600)), now: now) == "Refreshed today")
        #expect(lastSyncedLabel(feed("https://a", last: now.addingTimeInterval(-DAY - 1)), now: now) == "Refreshed yesterday")
        #expect(lastSyncedLabel(feed("https://a", last: now.addingTimeInterval(-3 * DAY)), now: now) == "Refreshed 3 days ago")
        #expect(lastSyncedLabel(feed("https://a", last: now.addingTimeInterval(-29 * DAY - 1)), now: now) == "Refreshed 29 days ago")
        #expect(lastSyncedLabel(feed("https://a", last: now.addingTimeInterval(-30 * DAY)), now: now) == "Refreshed over a month ago")
    }
}

@MainActor
@Suite(.serialized) struct FeedStoreTests {
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    private let bio = ImportedClass(name: "Biology 110", short: "Biolo", color: "indigo",
                                    days: [1, 3], start: 555, end: 630, room: "Science Hall 204",
                                    sourceUID: "cls-bio")
    private let essay = ImportedTask(title: "Essay 2", due: "2026-10-30", dueTime: "23:59",
                                     kind: "assignment", sourceUID: "task-essay")

    /// Saves a feed and applies its first refresh with the default ticks.
    private func firstRefresh(_ store: Store) -> SavedFeed? {
        guard case .success(let saved) = store.saveFeed(url: " https://canvas.u.edu/feeds/abc.ics ") else { return nil }
        let plan = store.previewFeed(saved, ImportResult(classes: [bio], tasks: [essay]))
        #expect(store.applyFeedWrites(planWrites(plan, accepted: plan.defaultPicks), feed: saved))
        return saved
    }

    @Test func savingAFeedKeepsItOnTheProfileOnce() {
        let store = fresh()
        guard case .success(let saved) = store.saveFeed(url: "https://canvas.u.edu/feeds/abc.ics") else {
            Issue.record("not saved")
            return
        }
        #expect(saved.label == "canvas.u.edu")
        #expect(store.profile.importFeeds.count == 1)
        // The same link again is the same feed, not a second one.
        guard case .success(let again) = store.saveFeed(url: "https://canvas.u.edu/feeds/abc.ics") else { return }
        #expect(again.id == saved.id)
        #expect(store.profile.importFeeds.count == 1)
        #expect(store.saveFeed(url: "canvas.u.edu/abc.ics") == .failure(.notALink))
    }

    @Test func aSixthFeedIsRefused() {
        let store = fresh()
        for n in 0..<5 { _ = store.saveFeed(url: "https://a.edu/\(n).ics") }
        #expect(store.saveFeed(url: "https://a.edu/6.ics") == .failure(.full))
    }

    @Test func aFirstRefreshAddsToTheInboxWithTheFeedsStamp() {
        let store = fresh()
        guard let saved = firstRefresh(store) else {
            Issue.record("not saved")
            return
        }
        let course = store.courses[0]
        #expect(course.name == "Biology 110" && course.room == "Science Hall 204")
        #expect(course.sourceFeed == webID(saved.id))
        #expect(course.sourceUID == "cls-bio")
        #expect(course.sourceHash == classFingerprint(bio.owned))
        // A feed's deadlines go to the Inbox, as the web's applyFeedWrites adds them.
        #expect(store.assignments[0].courseID == nil)
        #expect(store.assignments[0].sourceHash == taskFingerprint(essay.owned))
        #expect(store.profile.importFeeds[0].lastSyncedAt != nil)
    }

    @Test func aSecondRefreshOfTheSameFeedChangesNothing() {
        let store = fresh()
        guard let saved = firstRefresh(store) else { return }
        let plan = store.previewFeed(saved, ImportResult(classes: [bio], tasks: [essay]))
        #expect(plan.actionableKeys.isEmpty)
        #expect(plan.totals[.unchanged] == 2)
    }

    @Test func aMovedLectureUpdatesOnlyWhatTheFeedOwns() {
        let store = fresh()
        guard let saved = firstRefresh(store) else { return }
        // Yours: a new color, the essay handed in and filed under Biology.
        store.courses[0].color = .coral
        store.assignments[0].done = true
        store.assignments[0].courseID = store.courses[0].id

        var moved = bio
        moved.start = 600
        moved.end = 675
        var later = essay
        later.dueTime = "17:00"
        let plan = store.previewFeed(saved, ImportResult(classes: [moved], tasks: [later]))
        #expect(plan.classes[0].action == .update)
        #expect(plan.tasks[0].action == .update)
        #expect(store.applyFeedWrites(planWrites(plan, accepted: plan.defaultPicks), feed: saved))

        #expect(store.courses[0].startMin == 600 && store.courses[0].endMin == 675)
        #expect(store.courses[0].color == .coral)
        #expect(store.assignments[0].dueTime == "17:00")
        #expect(store.assignments[0].done)
        #expect(store.assignments[0].courseID == store.courses[0].id)
        #expect(store.courses[0].sourceHash == classFingerprint(moved.owned))
    }

    @Test func aRemovedClassTakesItsWorkWithItUnderOneStamp() {
        let store = fresh()
        guard let saved = firstRefresh(store) else { return }
        let courseID = store.courses[0].id
        store.addAssignment(Assignment(courseID: courseID, title: "Lab", due: nil))
        store.taskPlans.append(TaskPlan(assignmentID: store.assignments[1].id, date: "2026-10-05"))

        // The feed cancels the lecture; you tick it.
        let plan = store.previewFeed(saved, ImportResult(tasks: [essay], cancelled: ["cls-bio"]))
        #expect(plan.classes[0].action == .withdrawn)
        #expect(!plan.classes[0].checked)
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(store.applyFeedWrites(planWrites(plan, accepted: Set(plan.actionableKeys)), feed: saved, now: at))

        #expect(store.courses[0].deletedAt == at)
        #expect(store.assignments[1].deletedAt == at)
        #expect(store.assignments[0].deletedAt == nil)
        #expect(store.taskPlans.isEmpty)
    }

    @Test func erasingAfterTheAccountIsDeletedLeavesANewPhone() {
        let store = fresh()
        _ = firstRefresh(store)
        _ = store.setUsername("kelvin")
        let userID = "user_test14e"
        #expect(Store.saveSnapshot(SyncSnapshot(), userID: userID))
        #expect(store.eraseAfterAccountDeleted(userID: userID))
        #expect(store.courses.isEmpty && store.assignments.isEmpty)
        #expect(store.profile == Profile())
        #expect(Store.loadSnapshot(userID: userID) == nil)
    }
}

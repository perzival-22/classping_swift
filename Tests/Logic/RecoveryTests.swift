// RecoveryTests.swift: the rules of Recently Deleted (lib/recovery.ts). The
// web has no recovery.test.ts; every "web:" line was printed by the web's own
// daysUntilPurge / isPurgeable / buildTrash in node 24. The trash list itself
// is built by the store, so its tests are in Persistence/TrashStoreTests.swift.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private let DAY: TimeInterval = 86_400
/// Any fixed moment: the rules only look at how long ago something went.
private let DELETED = Date(timeIntervalSince1970: 1_800_000_000)

private func after(_ seconds: TimeInterval) -> Date {
    DELETED.addingTimeInterval(seconds)
}

@Suite struct RecoveryTests {
    @Test func theWindowIsThirtyDays() {
        #expect(RECOVERY_RETENTION_DAYS == 30)
        #expect(RECOVERY_RETENTION == 30 * DAY)
    }

    @Test func daysLeftRoundUp() {
        // web: 0 -> 30, 1 s -> 30, 1 day -> 29, 29 days -> 1, 29 days + 1 s -> 1
        #expect(daysUntilPurge(DELETED, now: after(0)) == 30)
        #expect(daysUntilPurge(DELETED, now: after(1)) == 30)
        #expect(daysUntilPurge(DELETED, now: after(DAY)) == 29)
        #expect(daysUntilPurge(DELETED, now: after(29 * DAY)) == 1)
        #expect(daysUntilPurge(DELETED, now: after(29 * DAY + 1)) == 1)
    }

    @Test func theLastSecondStillCountsAsADay() {
        // web: 30 days - 1 s -> 1, not purgeable yet
        #expect(daysUntilPurge(DELETED, now: after(30 * DAY - 1)) == 1)
        #expect(!isPurgeable(DELETED, now: after(30 * DAY - 1)))
    }

    @Test func atThirtyDaysItsGone() {
        // web: 30 days -> 0, purgeable; 31 days -> 0 (never below), purgeable
        #expect(daysUntilPurge(DELETED, now: after(30 * DAY)) == 0)
        #expect(isPurgeable(DELETED, now: after(30 * DAY)))
        #expect(daysUntilPurge(DELETED, now: after(31 * DAY)) == 0)
        #expect(isPurgeable(DELETED, now: after(31 * DAY)))
    }

    @Test func aDeletionInTheFutureIsNotPurgeable() {
        // A phone whose clock was ahead when it deleted. web: -1 day -> 31
        #expect(daysUntilPurge(DELETED, now: after(-DAY)) == 31)
        #expect(!isPurgeable(DELETED, now: after(-DAY)))
    }

    @Test func theRowSaysHowLongIsLeft() {
        // TrashRow in app/settings/deleted/page.tsx.
        #expect(purgeLine(DELETED, now: after(0)) == "30 days left")
        #expect(purgeLine(DELETED, now: after(29 * DAY)) == "1 day left")
        #expect(purgeLine(DELETED, now: after(30 * DAY)) == "Deleted for good today")
    }

    @Test func kindsUseTheWebsWords() {
        #expect(EntityKind.allCases.map(\.rawValue) == ["class", "task", "grade", "note"])
        #expect(EntityKind.allCases.map(\.label) == ["Class", "Assignment", "Grade", "Note"])
    }

    @Test func rowIDsAreUniqueAcrossKinds() {
        let id = UUID()
        let a = TrashEntry(kind: .course, itemID: id, title: "x", detail: nil, deletedAt: DELETED, viaClass: false)
        let b = TrashEntry(kind: .note, itemID: id, title: "x", detail: nil, deletedAt: DELETED, viaClass: false)
        #expect(a.id != b.id)
        #expect(a.id == "class:\(id.uuidString)")
    }

    @Test func newestFirstThenClassAssignmentGradeNote() {
        func row(_ kind: EntityKind, _ title: String, _ at: TimeInterval) -> TrashEntry {
            TrashEntry(kind: kind, itemID: UUID(), title: title, detail: nil,
                       deletedAt: after(at), viaClass: false)
        }
        // web: buildTrash orders Essay (9), Untitled note (8), Inbox (7), then the
        // class and what went with it at one moment: Biology, Lab, Quiz.
        let sorted = sortTrash([
            row(.grade, "Quiz", 5), row(.assignment, "Lab", 5), row(.course, "Biology", 5),
            row(.assignment, "Inbox", 7), row(.note, "Untitled note", 8), row(.assignment, "Essay", 9),
        ])
        #expect(sorted.map(\.title) == ["Essay", "Untitled note", "Inbox", "Biology", "Lab", "Quiz"])
    }

    /// Phone-only: two of one kind at one moment go by title, so the list
    /// can't reshuffle (the web keeps whatever order the store had).
    @Test func tiesOfOneKindGoByTitle() {
        let at = after(5)
        let rows = ["Zoo", "Apple", "Mango"].map {
            TrashEntry(kind: .assignment, itemID: UUID(), title: $0, detail: nil, deletedAt: at, viaClass: true)
        }
        #expect(sortTrash(rows).map(\.title) == ["Apple", "Mango", "Zoo"])
    }
}

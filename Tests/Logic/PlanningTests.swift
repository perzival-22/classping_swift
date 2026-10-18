// PlanningTests.swift: the Swift twin of the `nextRepeatDate`, `localDateKey`
// and `studyMinutes` cases in lib/planning.test.ts, plus a year rollover and
// bad input. The plan-normalising cases wait for the code they test (D-31).
// Run: scripts/test-logic.sh.
import Foundation
import Testing
@testable import CPLogic

@Suite struct PlanningTests {

    @Test func advancesWeeklyAndMonthlyClampingShortMonths() {
        #expect(nextRepeatDate("2026-09-08", "weekly") == "2026-09-15")
        #expect(nextRepeatDate("2027-01-31", "monthly") == "2027-02-28")
        #expect(nextRepeatDate("2028-01-31", "monthly") == "2028-02-29")
    }

    @Test func rollsIntoTheNextYear() {
        #expect(nextRepeatDate("2026-12-29", "weekly") == "2027-01-05")
        #expect(nextRepeatDate("2026-12-15", "monthly") == "2027-01-15")
    }

    @Test func refusesBadInput() {
        #expect(nextRepeatDate("2026-02-31", "weekly") == nil)
        #expect(nextRepeatDate("", "monthly") == nil)
        #expect(nextRepeatDate("2026-09-08", "daily") == nil)
    }

    // MARK: study records (Phase 7b)

    /// `localDateKey` is `dayOf` here: local calendar parts, never UTC.
    @Test func usesLocalCalendarComponentsInsteadOfUTC() {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 8; c.hour = 23; c.minute = 30
        #expect(dayOf(Calendar.current.date(from: c)!) == "2026-09-08")
    }

    @Test func totalsByTaskSubjectAndTimeWindow() {
        let t1 = UUID(), t2 = UUID(), c1 = UUID()
        let sessions = [
            Block(assignmentID: t1, courseID: c1, minutes: 25, completedAt: Date(timeIntervalSince1970: 10)),
            Block(assignmentID: t1, courseID: c1, minutes: 20, completedAt: Date(timeIntervalSince1970: 20)),
            Block(assignmentID: t2, courseID: c1, minutes: 15, completedAt: Date(timeIntervalSince1970: 30)),
        ]
        #expect(studyMinutes(sessions, taskID: t1) == 45)
        #expect(studyMinutes(sessions, courseID: c1, since: Date(timeIntervalSince1970: 20)) == 35)
        #expect(studyMinutes(sessions) == 60)
    }
}

/// A stand-in study session.
private struct Block: StudyRecord {
    var assignmentID: UUID?
    var courseID: UUID?
    var minutes: Int
    var completedAt: Date
}

// ExamPrepTests.swift: the Swift twin of lib/exam-prep.test.ts.
// `prepSubtasks` has no twin: the store turns the steps into checklist rows
// itself (Store+Planning.swift), and Persistence/PlanningStoreTests checks it.
// Run: scripts/test-logic.sh.
import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// The web's exam "e1", due 20 Sep 2026 at 09:00.
private let e1 = UUID()
private let examDate = "2026-09-20"

/// A stand-in study session, the web's `session({...})` helper.
private struct Block: StudyRecord {
    var assignmentID: UUID? = e1
    var courseID: UUID? = nil
    var minutes = 25
    var completedAt = Date(timeIntervalSince1970: 0)
}

@Suite struct ExamPrepTests {

    // MARK: prep ladder

    @Test func countsBackFromTheExamInLocalCalendarDays() {
        #expect(prepLadder(examDate, at(2026, 9, 1)).map(\.date) == [
            "2026-09-13", "2026-09-15", "2026-09-17", "2026-09-18", "2026-09-19",
        ])
    }

    @Test func crossesAMonthBoundaryWithoutDrifting() {
        #expect(prepLadder("2026-10-02", at(2026, 9, 20)).map(\.date) == [
            "2026-09-25", "2026-09-27", "2026-09-29", "2026-09-30", "2026-10-01",
        ])
    }

    @Test func dropsRungsThatAreAlreadyBehindTheStudent() {
        #expect(prepLadder(examDate, at(2026, 9, 18, 15)).map(\.daysBefore) == [2, 1])
    }

    @Test func returnsNothingForAnExamTodayPastOrUndated() {
        let now = at(2026, 9, 20, 7)
        #expect(prepLadder("2026-09-20", now).isEmpty)
        #expect(prepLadder("2026-09-19", now).isEmpty)
        #expect(prepLadder(nil, now).isEmpty)
        #expect(prepLadder("nonsense", now).isEmpty)
    }

    @Test func givesEveryRungSomethingSpecificToDo() {
        let steps = prepLadder(examDate, at(2026, 9, 1))
        #expect(steps.allSatisfy { !$0.focus.isEmpty })
        #expect(steps.first?.title == "7 days before · Gather everything, notes, slides, past papers")
        #expect(steps.last?.title.hasPrefix("1 day before ·") == true)
    }

    // MARK: writing the ladder onto a task

    @Test func recognisesAChecklistThatAlreadyCarriesALadder() {
        let titles = prepLadder(examDate, at(2026, 9, 1)).map(\.title)
        #expect(hasPrepLadder(titles))
        #expect(!hasPrepLadder([]))
    }

    @Test func stopsClaimingAPlanExistsOnceTheStudentHasDeletedIt() {
        #expect(!hasPrepLadder(["Read chapter 4"]))
    }

    @Test func pointsAtTheNextRungStillAhead() {
        let steps = prepLadder(examDate, at(2026, 9, 1))
        #expect(nextPrepDate(steps, at(2026, 9, 14)) == "2026-09-15")
        #expect(nextPrepDate(steps, at(2026, 9, 13)) == "2026-09-13")
        #expect(nextPrepDate([], at(2026, 9, 14)) == nil)
    }

    // MARK: prep progress

    @Test func scopesTheTargetToTheRungsThatAreStillReachable() {
        let p = prepProgress(examID: e1, examDate: examDate, sessions: [Block](), now: at(2026, 9, 18, 9))
        #expect(p.target == 2 * minutesPerStep)
        #expect(p.daysLeft == 2)
        #expect(p.logged == 0)
        #expect(p.ratio == 0)
    }

    @Test func countsOnlyThisTasksSessions() {
        let p = prepProgress(examID: e1, examDate: examDate,
                             sessions: [Block(minutes: 30), Block(assignmentID: UUID(), minutes: 90)],
                             now: at(2026, 9, 18, 9))
        #expect(p.logged == 30)
    }

    @Test func clampsAMetTargetAt1() {
        let p = prepProgress(examID: e1, examDate: examDate, sessions: [Block(minutes: 240)],
                             now: at(2026, 9, 19, 9))
        #expect(p.ratio == 1)
    }

    @Test func reportsACompletePlanWhenThereIsNothingLeftToSchedule() {
        let p = prepProgress(examID: e1, examDate: examDate, sessions: [Block](), now: at(2026, 9, 20, 9))
        #expect(p.target == 0)
        #expect(p.ratio == 1)
        #expect(p.daysLeft == 0)
    }

    @Test func countsDaysLeftAcrossAMonthBoundary() {
        let p = prepProgress(examID: e1, examDate: "2026-10-02", sessions: [Block](), now: at(2026, 9, 28, 9))
        #expect(p.daysLeft == 4)
    }
}

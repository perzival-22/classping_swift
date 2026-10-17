// DeadlineTests.swift: the Swift twin of lib/deadline.test.ts.
// Run: tools/logic-test.sh (copies Logic/ into a throwaway package and runs this).
// Kelvin does not type this file; it proves the Swift port behaves like the web app.
import Foundation
import Testing
@testable import CPLogic

/// A Date at the given local wall-clock, built in the runner's own zone, which is
/// the same zone the Deadline logic reads through `Calendar.current`. Everything
/// here is constructed and checked in that one zone, so the tests are stable
/// wherever they run (the CI box, this laptop, a phone).
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// The UTC ISO string a legacy web task form would have stored for a local Date,
/// i.e. `new Date(y, m, d, hh, mm).toISOString()`.
private func legacyISO(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: date)
}

@Suite struct DeadlineTests {

    // MARK: parseLegacyDue

    @Test func keepsLocalDayAndTimeOfALegacyTimestamp() {
        let legacy = legacyISO(at(2026, 9, 7, 23, 30))
        #expect(parseLegacyDue(legacy) == Deadline(date: "2026-09-07", time: "23:30"))
    }

    @Test func readsThe2359SentinelAsAllDay() {
        let legacy = legacyISO(at(2026, 9, 7, 23, 59))
        #expect(parseLegacyDue(legacy) == Deadline(date: "2026-09-07", time: nil))
    }

    @Test func treatsABareDayAsAllDayWithoutShifting() {
        #expect(parseLegacyDue("2026-09-07") == Deadline(date: "2026-09-07", time: nil))
    }

    @Test func undatedForEmptyMissingOrUnparseable() {
        for v in ["", "   ", "not a date"] {
            #expect(parseLegacyDue(v) == UNDATED)
        }
        #expect(parseLegacyDue(nil) == UNDATED)
    }

    // MARK: makeDeadline

    @Test func dropsAMalformedTimeInsteadOfGuessing() {
        #expect(makeDeadline("2026-09-07", "25:00") == Deadline(date: "2026-09-07", time: nil))
        #expect(makeDeadline("2026-09-07", "9:5") == Deadline(date: "2026-09-07", time: nil))
    }

    @Test func rejectsAShapeValidButImpossibleDay() {
        #expect(makeDeadline("2026-02-31", "10:00") == UNDATED)
    }

    @Test func dropsTheTimeWhenThereIsNoDay() {
        #expect(makeDeadline(nil, "10:00") == UNDATED)
    }

    // MARK: fromDbTime

    @Test func narrowsPostgresTimeToHHmm() {
        #expect(fromDbTime("23:30:00") == "23:30")
    }

    @Test func passesNullThroughForAnAllDayRow() {
        #expect(fromDbTime(nil) == nil)
    }

    // MARK: deadlineInstant

    @Test func allDayExpiresAtEndOfItsDay() {
        guard let inst = deadlineInstant(Deadline(date: "2026-09-07", time: nil)) else {
            Issue.record("expected an instant"); return
        }
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: inst)
        #expect(c.year == 2026)
        #expect(c.month == 9)
        #expect(c.day == 7)
        #expect(c.hour == 23)
        #expect(c.minute == 59)
    }

    @Test func usesLocalComponentsForAnExactDeadline() {
        guard let inst = deadlineInstant(Deadline(date: "2026-09-07", time: "09:15")) else {
            Issue.record("expected an instant"); return
        }
        let c = Calendar.current.dateComponents([.day, .hour, .minute], from: inst)
        #expect(c.day == 7)
        #expect(c.hour == 9)
        #expect(c.minute == 15)
    }

    @Test func hasNoInstantWhenUndated() {
        #expect(deadlineInstant(UNDATED) == nil)
    }

    // MARK: isOverdue

    @Test func doesNotCallATaskDueLaterTodayOverdue() {
        #expect(isOverdue(Deadline(date: "2026-09-07", time: "23:30"), at(2026, 9, 7, 8)) == false)
    }

    @Test func keepsAnAllDayTaskDueTodayOutOfOverdueAllDay() {
        #expect(isOverdue(Deadline(date: "2026-09-07", time: nil), at(2026, 9, 7, 22)) == false)
    }

    @Test func marksItOverdueOnceItsDayIsOver() {
        #expect(isOverdue(Deadline(date: "2026-09-07", time: nil), at(2026, 9, 8, 0, 30)) == true)
    }

    @Test func marksAnExactDeadlineOverdueAMinuteAfterItPasses() {
        #expect(isOverdue(Deadline(date: "2026-09-07", time: "09:15"), at(2026, 9, 7, 9, 16)) == true)
    }

    @Test func neverMarksUndatedWorkOverdue() {
        #expect(isOverdue(UNDATED, at(2030, 1, 1)) == false)
    }

    // MARK: dueBucket

    @Test(arguments: [
        (Deadline(date: "2026-09-05", time: nil), DueBucket.overdue),
        (Deadline(date: "2026-09-07", time: nil), DueBucket.today),
        (Deadline(date: "2026-09-07", time: "09:00"), DueBucket.overdue),
        (Deadline(date: "2026-09-07", time: "18:00"), DueBucket.today),
        (Deadline(date: "2026-09-08", time: nil), DueBucket.upcoming),
        (Deadline(date: nil, time: nil), DueBucket.none),
    ])
    func sortsEachDeadlineIntoItsSection(_ pair: (Deadline, DueBucket)) {
        #expect(dueBucket(pair.0, at(2026, 9, 7, 12)) == pair.1)
    }

    // MARK: compareDeadlines

    @Test func sortsEarliestFirstAndUndatedLast() {
        let list = [
            Deadline(date: nil, time: nil),
            Deadline(date: "2026-09-09", time: nil),
            Deadline(date: "2026-09-07", time: nil),
            Deadline(date: "2026-09-07", time: "09:00"),
        ]
        let sorted = list.sorted { compareDeadlines($0, $1) < 0 }
        #expect(sorted == [
            Deadline(date: "2026-09-07", time: "09:00"),
            Deadline(date: "2026-09-07", time: nil),
            Deadline(date: "2026-09-09", time: nil),
            Deadline(date: nil, time: nil),
        ])
    }

    @Test func isAStableTotalOrder() {
        let a = Deadline(date: "2026-09-07", time: "09:00")
        let b = Deadline(date: "2026-09-07", time: nil)
        #expect(compareDeadlines(a, b) < 0)
        #expect(compareDeadlines(b, a) > 0)
        #expect(compareDeadlines(a, a) == 0)
    }

    // MARK: daysUntil

    @Test func countsWholeCalendarDaysNot24hBlocks() {
        // 1am tomorrow is two hours away but one day away.
        #expect(daysUntil(Deadline(date: "2026-09-08", time: "01:00"), at(2026, 9, 7, 23)) == 1)
    }

    @Test func goesNegativeOncePast() {
        #expect(daysUntil(Deadline(date: "2026-09-05", time: nil), at(2026, 9, 7, 23)) == -2)
    }

    @Test func survivesADstBoundaryWithoutDrifting() {
        // US clocks go forward 2026-03-08. Rounding, not flooring, is what saves this.
        let before = at(2026, 3, 7, 12)
        #expect(daysUntil(Deadline(date: "2026-03-08", time: nil), before) == 1)
        #expect(daysUntil(Deadline(date: "2026-03-09", time: nil), before) == 2)
    }

    // MARK: formatTime

    @Test(arguments: [
        ("00:00", "12:00 AM"),
        ("09:05", "9:05 AM"),
        ("12:00", "12:00 PM"),
        ("13:05", "1:05 PM"),
        ("23:30", "11:30 PM"),
    ])
    func rendersThe12HourClock(_ pair: (String, String)) {
        #expect(formatTime(pair.0) == pair.1)
    }

    // MARK: formatDeadline

    @Test func saysNoDeadlineRatherThanInventingOne() {
        #expect(formatDeadline(UNDATED, at(2026, 9, 7, 12)) == "No deadline")
    }

    @Test func showsTheTimeOnlyWhenTheStudentGaveOne() {
        let now = at(2026, 9, 7, 12)
        #expect(formatDeadline(Deadline(date: "2026-09-07", time: nil), now) == "Today")
        #expect(formatDeadline(Deadline(date: "2026-09-07", time: "23:30"), now) == "Today · 11:30 PM")
    }

    @Test func namesTheNearFutureInDays() {
        let now = at(2026, 9, 7, 12)
        #expect(formatDeadline(Deadline(date: "2026-09-08", time: nil), now) == "Tomorrow")
        #expect(formatDeadline(Deadline(date: "2026-09-10", time: nil), now) == "In 3 days")
    }

    @Test func fallsBackToADateBeyondAWeekOut() {
        let now = at(2026, 9, 7, 12)
        #expect(formatDeadline(Deadline(date: "2026-10-20", time: nil), now) == "Oct 20")
        #expect(formatDeadline(Deadline(date: "2027-01-05", time: nil), now) == "Jan 5, 2027")
    }

    @Test func countsOverdueDays() {
        let now = at(2026, 9, 7, 12)
        #expect(formatDeadline(Deadline(date: "2026-09-04", time: nil), now) == "3 days overdue")
        #expect(formatDeadline(Deadline(date: "2026-09-06", time: nil), now) == "1 day overdue")
    }

    @Test func saysOverdueWithTheTimeForSomethingMissedEarlierToday() {
        let now = at(2026, 9, 7, 12)
        #expect(formatDeadline(Deadline(date: "2026-09-07", time: "09:00"), now) == "Overdue · 9:00 AM")
    }

    // MARK: dayOf

    @Test func readsLocalComponentsSoItNeverLandsOnThePreviousDay() {
        #expect(dayOf(at(2026, 9, 7, 0, 30)) == "2026-09-07")
        #expect(dayOf(at(2026, 9, 7, 23, 30)) == "2026-09-07")
    }
}

// TimeTests.swift: the Swift twin of lib/time.test.ts.
// Run: tools/logic-test.sh (copies Logic/ into a throwaway package and runs this).
// Covers the helpers Time.swift ports; localClock and zonedInstant are server-only
// and were not ported (see Time.swift's header note and DECISIONS.md D-16).
import Foundation
import Testing
@testable import CPLogic

/// Local noon on a date, in the runner's own zone. Noon so the term maths cannot
/// depend on the runner's time zone the way a midnight value could.
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

@Suite struct TimeTests {

    // MARK: scheduleDate

    @Test(arguments: [
        (2026, 9, 9, 1, 2026, 9, 10),
        (2026, 9, 9, -1, 2026, 9, 8),
        (2026, 9, 9, 2, 2026, 9, 11),
        (2026, 9, 12, 0, 2026, 9, 12),
        (2026, 9, 9, 5, 2026, 9, 14),
        (2026, 9, 9, -5, 2026, 9, 4),
        (2026, 12, 31, 1, 2027, 1, 1),
        (2026, 3, 6, 1, 2026, 3, 7),     // across the US spring-forward weekend
        (2026, 10, 30, 1, 2026, 10, 31), // across the US fall-back weekend
    ])
    func browsesByWholeCalendarDays(_ c: (Int, Int, Int, Int, Int, Int, Int)) {
        let now = at(c.0, c.1, c.2, 14)                 // 14:30-ish, like the web test
        let original = now                               // a Date is a value: copying is a snapshot
        let expected = at(c.4, c.5, c.6, 0)              // local midnight of the expected day
        #expect(scheduleDate(now, c.3) == expected)
        #expect(now == original)                         // the input was not mutated
    }

    // MARK: fmtTime

    @Test(arguments: [
        (510, "8:30 AM"),
        (0, "12:00 AM"),
        (720, "12:00 PM"),
        (1439, "11:59 PM"),
        (780, "1:00 PM"),
        (605, "10:05 AM"),
    ])
    func formatsMinutesFromMidnight(_ pair: (Int, String)) {
        #expect(fmtTime(pair.0) == pair.1)
    }

    // MARK: dayNumber

    @Test func countsWholeDaysBetweenDates() {
        #expect(dayNumber("2025-08-26")! - dayNumber("2025-08-25")! == 1)
        #expect(dayNumber("2026-01-01")! - dayNumber("2025-01-01")! == 365)
    }

    @Test func rejectsAnythingThatIsNotAPlainISODate() {
        #expect(dayNumber("") == nil)
        #expect(dayNumber("25/08/2025") == nil)
        #expect(dayNumber("2025-13-45") == nil)
    }

    // MARK: termProgress

    // Fall term: 110 days, 16 weeks.
    private static let fallStart = "2025-08-25"
    private static let fallEnd = "2025-12-12"

    @Test func needsBothEndsOfTheTerm() {
        #expect(termProgress(nil, Self.fallEnd, at(2025, 9, 1)) == nil)
        #expect(termProgress(Self.fallStart, nil, at(2025, 9, 1)) == nil)
        #expect(termProgress(nil, nil, at(2025, 9, 1)) == nil)
    }

    @Test func rejectsATermThatEndsBeforeItStarts() {
        #expect(termProgress("2025-12-12", "2025-08-25", at(2025, 9, 1)) == nil)
    }

    @Test func countsBothEndpointsAsPartOfTheTerm() {
        guard let p = termProgress(Self.fallStart, Self.fallEnd, at(2025, 8, 25)) else {
            Issue.record("expected term progress"); return
        }
        #expect(p.totalDays == 110)
        #expect(p.totalWeeks == 16)
        #expect(p.phase == .during)
        #expect(p.elapsedDays == 1)
        #expect(p.remainingDays == 110)
        #expect(p.week == 1)
    }

    @Test func reportsTheWeekTheTermIsIn() {
        #expect(termProgress(Self.fallStart, Self.fallEnd, at(2025, 9, 1))?.week == 2)
        #expect(termProgress(Self.fallStart, Self.fallEnd, at(2025, 8, 31))?.week == 1)
        #expect(termProgress(Self.fallStart, Self.fallEnd, at(2025, 12, 12))?.week == 16)
    }

    @Test func flagsTheTermAsNotStartedYet() {
        guard let p = termProgress(Self.fallStart, Self.fallEnd, at(2025, 8, 1)) else {
            Issue.record("expected term progress"); return
        }
        #expect(p.phase == .before)
        #expect(p.elapsedDays == 0)
        #expect(p.fraction == 0)
    }

    @Test func flagsAFinishedTermWithoutOverrunningTheBar() {
        guard let p = termProgress(Self.fallStart, Self.fallEnd, at(2026, 3, 1)) else {
            Issue.record("expected term progress"); return
        }
        #expect(p.phase == .after)
        #expect(p.elapsedDays == p.totalDays)
        #expect(p.remainingDays == 0)
        #expect(p.fraction == 1)
    }

    @Test func handlesASingleDayTerm() {
        guard let p = termProgress("2025-08-25", "2025-08-25", at(2025, 8, 25)) else {
            Issue.record("expected term progress"); return
        }
        #expect(p.totalDays == 1)
        #expect(p.totalWeeks == 1)
        #expect(p.fraction == 1)
        #expect(p.week == 1)
    }

    @Test func isUnaffectedByADstChangeInsideTheTerm() {
        guard let p = termProgress(Self.fallStart, Self.fallEnd, at(2025, 11, 3)) else {
            Issue.record("expected term progress"); return
        }
        #expect(p.elapsedDays == 71)
        #expect(p.remainingDays == 40)
        #expect(p.elapsedDays + p.remainingDays == p.totalDays + 1)
    }
}

// WeekTests.swift: the week maths behind the strip and the grid.
// Run: tools/logic-test.sh. Kelvin does not type this file.
//
// The web has no tests for weekInfo, isWithinTerm or termRangeLabel, so these
// cases are written from their doc comments and code (lib/store.tsx,
// lib/time.ts, app/week/page.tsx). Dates are built in the runner's own zone.
import Foundation
import Testing
@testable import CPLogic

/// A local date and time, in the runner's own time zone.
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

@Suite struct WeekTests {

    // MARK: Days of the week

    @Test func numbersDaysFromMondayAsZero() {
        #expect(dayIndex(of: at(2026, 10, 19)) == 0)   // Monday
        #expect(dayIndex(of: at(2026, 10, 21)) == 2)   // Wednesday
        #expect(dayIndex(of: at(2026, 10, 24)) == 5)   // Saturday
        #expect(dayIndex(of: at(2026, 10, 25)) == 6)   // Sunday
    }

    @Test func readsTheTimeOfDayInMinutes() {
        #expect(minuteOfDay(at(2026, 10, 21, 10, 40)) == 640)
        #expect(minuteOfDay(at(2026, 10, 21, 0, 0)) == 0)
        #expect(minuteOfDay(at(2026, 10, 21, 23, 59)) == 1439)
    }

    // MARK: Weeks

    @Test func findsTheMondayToSundayWeekAroundAnyDay() {
        let week = weekInfo(at(2026, 10, 21, 14, 30))
        #expect(week.todayCol == 2)
        #expect(week.dates.count == 7)
        #expect(week.dates.first == at(2026, 10, 19, 0))
        #expect(week.dates.last == at(2026, 10, 25, 0))
        // A Sunday belongs to the week that started six days earlier.
        let sunday = weekInfo(at(2026, 10, 25, 9))
        #expect(sunday.todayCol == 6)
        #expect(sunday.dates.first == at(2026, 10, 19, 0))
    }

    @Test func keepsSevenMidnightsAcrossTheClockChange() {
        // US clocks go back on Sunday 1 Nov 2026.
        let dates = weekInfo(at(2026, 11, 1, 9)).dates
        let expected = (26...31).map { at(2026, 10, $0, 0) } + [at(2026, 11, 1, 0)]
        #expect(dates == expected)
    }

    @Test func stepsWholeWeeksForwardAndBack() {
        let now = at(2026, 10, 21, 14, 30)
        #expect(weekDates(now, 1).first == at(2026, 10, 26, 0))
        #expect(weekDates(now, -1).first == at(2026, 10, 12, 0))
        // Across the new year.
        #expect(weekDates(at(2026, 12, 30), 1).first == at(2027, 1, 4, 0))
    }

    @Test func titlesTheWeekByItsDistanceFromNow() {
        #expect(weekTitle(0) == "This Week")
        #expect(weekTitle(1) == "Next Week")
        #expect(weekTitle(-1) == "Last Week")
        #expect(weekTitle(3) == "In 3 Weeks")
        #expect(weekTitle(-2) == "2 Weeks Ago")
    }

    @Test func labelsTheWeekRangeAndOnlyRepeatsAChangedMonth() {
        #expect(weekRangeLabel(weekDates(at(2026, 10, 21), 0)) == "OCT 19 – 25")
        #expect(weekRangeLabel(weekDates(at(2026, 10, 28), 0)) == "OCT 26 – NOV 1")
        #expect(weekRangeLabel([]) == "")
        #expect(fmtMD(at(2026, 7, 6)) == "Jul 6")
    }

    // MARK: The semester

    @Test func treatsAMissingHalfOrInvertedTermAsNoLimit() {
        let day = at(2026, 10, 21)
        #expect(isWithinTerm(nil, nil, day))
        #expect(isWithinTerm("2026-12-15", "2026-09-01", day))    // inverted: a typo
        #expect(isWithinTerm("not a date", nil, day))              // broken: ignored
        #expect(!isWithinTerm("2026-11-01", nil, day))             // only a start, not reached yet
        #expect(isWithinTerm(nil, "2026-12-15", day))              // only an end, still before it
    }

    @Test func countsBothEndsOfTheTermAsInside() {
        #expect(isWithinTerm("2026-09-01", "2026-12-15", at(2026, 9, 1, 0, 5)))
        #expect(isWithinTerm("2026-09-01", "2026-12-15", at(2026, 12, 15, 23, 30)))
        #expect(!isWithinTerm("2026-09-01", "2026-12-15", at(2026, 8, 31, 23, 30)))
        #expect(!isWithinTerm("2026-09-01", "2026-12-15", at(2026, 12, 16, 0, 5)))
    }

    @Test func namesTheTermWindow() {
        #expect(termRangeLabel("2026-09-01", "2026-12-15") == "Sep 1 – Dec 15")
        #expect(termRangeLabel("2026-09-01", nil) == "from Sep 1")
        #expect(termRangeLabel(nil, "2026-12-15") == "until Dec 15")
        #expect(termRangeLabel(nil, nil) == nil)
        #expect(termRangeLabel("", "") == nil)
        #expect(termRangeLabel("2026-02-30", nil) == nil)
    }

    // MARK: The grid

    @Test func stretchesTheGridToFitEveryMeeting() {
        #expect(gridHours([]) == 8...17)
        #expect(gridHours([ClassMeeting(days: [0], start: 540, end: 600)]) == 8...17)
        #expect(gridHours([ClassMeeting(days: [0], start: 450, end: 540)]) == 7...17)    // 7:30 AM
        #expect(gridHours([ClassMeeting(days: [0], start: 1020, end: 1090)]) == 8...19)  // ends 6:10 PM
    }

    @Test func printsHoursAndClockTimesTheWayTheGridDoes() {
        #expect(hourLabel(0) == "12")
        #expect(hourLabel(8) == "8")
        #expect(hourLabel(12) == "12")
        #expect(hourLabel(13) == "1")
        #expect(hourLabel(24) == "12")
        #expect(fmtClock(540) == "9:00")
        #expect(fmtClock(780) == "1:00")
        #expect(fmtClock(0) == "12:00")
    }
}

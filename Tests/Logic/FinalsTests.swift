// FinalsTests.swift: the countdown on the Days to Finals card
// (components/FinalsCountdown.tsx, which has no test file of its own).
// The words are the web's. The day count is the phone's own (D-56): run this
// suite with TZ=America/New_York as well, where the web's count is a day short.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 9, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// Thursday, 10 December 2026.
private let finals = "2026-12-10"

@Suite struct FinalsTests {
    @Test func countsWholeCalendarDays() {
        // 11 more days in October, 30 in November, 10 in December.
        #expect(finalsStatus(finals, at(2026, 10, 20)) == FinalsStatus(
            days: 51, headline: "51", unit: "days",
            message: "Finals begin Thursday, Dec 10. You've got this."))
    }

    @Test func twoDaysOutIsStillPlural() {
        #expect(finalsStatus(finals, at(2026, 12, 8, 23, 59)) == FinalsStatus(
            days: 2, headline: "2", unit: "days",
            message: "Finals begin Thursday, Dec 10. You've got this."))
    }

    @Test func theDayBeforeSaysTomorrow() {
        #expect(finalsStatus(finals, at(2026, 12, 9, 0, 1)) == FinalsStatus(
            days: 1, headline: "1", unit: "day",
            message: "Finals are tomorrow, Thursday, Dec 10."))
    }

    /// The web's card says "Done" on finals day anywhere west of London.
    @Test func finalsDayIsTodayFromMidnightToMidnight() {
        let today = FinalsStatus(days: 0, headline: "Today", unit: nil,
                                 message: "Finals are today. Good luck! 🍀")
        #expect(finalsStatus(finals, at(2026, 12, 10, 0, 0)) == today)
        #expect(finalsStatus(finals, at(2026, 12, 10, 23, 59)) == today)
    }

    @Test func afterFinalsItSaysDone() {
        #expect(finalsStatus(finals, at(2026, 12, 11, 0, 1)) == FinalsStatus(
            days: -1, headline: "Done", unit: nil,
            message: "Finals were Thursday, Dec 10. Set a new date for next term."))
        #expect(finalsStatus(finals, at(2027, 1, 20))?.days == -41)
    }

    /// The count crosses the end of daylight saving (1 November 2026 in the
    /// US) without losing or gaining a day: a 25-hour day still counts once.
    @Test func daylightSavingDoesNotMoveTheCount() {
        #expect(finalsStatus("2026-11-02", at(2026, 10, 31, 23, 30))?.days == 2)
        #expect(finalsStatus("2026-11-01", at(2026, 10, 31, 23, 30))?.days == 1)
        #expect(finalsStatus("2027-03-15", at(2027, 3, 13, 0, 30))?.days == 2)
    }

    @Test func noUsableDateMeansNoCountdown() {
        #expect(finalsStatus(nil, at(2026, 10, 20)) == nil)
        #expect(finalsStatus("", at(2026, 10, 20)) == nil)
        #expect(finalsStatus("2026-02-30", at(2026, 10, 20)) == nil)
        #expect(finalsStatus("12/10/2026", at(2026, 10, 20)) == nil)
    }
}

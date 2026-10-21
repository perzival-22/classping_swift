// TermTests.swift: what the Semester card says under its dates
// (`CurrentTerm` in app/settings/page.tsx). Every "web:" line was printed by
// the web's own code with node, in London and New York. "Starts in" is the
// phone's own count: the web's always says 1 day (D-69).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 9, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

@Suite struct TermTests {
    @Test func duringTheTermCountsWeeksAndDaysLeft() {
        // web: Week 8 of 16 · 60 days to go.
        #expect(termNote(start: "2026-09-01", end: "2026-12-18", now: at(2026, 10, 20)) == TermNote(
            showsWindow: true, fraction: 50.0 / 109.0, line: "Week 8 of 16 \u{00B7} 60 days to go."))
    }

    @Test func theFirstAndLastDaysAreInside() {
        // web: Week 1 of 16 · 109 days to go. / Week 16 of 16 · 1 day to go.
        #expect(termNote(start: "2026-09-01", end: "2026-12-18", now: at(2026, 9, 1, 0, 1)).line
                == "Week 1 of 16 \u{00B7} 109 days to go.")
        let last = termNote(start: "2026-09-01", end: "2026-12-18", now: at(2026, 12, 18, 23, 59))
        #expect(last.line == "Week 16 of 16 \u{00B7} 1 day to go.")
        #expect(last.fraction == 1)
        // web: Week 1 of 1 · 1 day to go.
        #expect(termNote(start: "2026-10-20", end: "2026-10-20", now: at(2026, 10, 20)).line
                == "Week 1 of 1 \u{00B7} 1 day to go.")
    }

    @Test func afterTheTermPointsToArchiving() {
        #expect(termNote(start: "2026-09-01", end: "2026-12-18", now: at(2026, 12, 19, 0, 1)) == TermNote(
            showsWindow: true, fraction: 1,
            line: "This term has ended. Archive it below to clear your timetable."))
    }

    /// The web says "Starts in 1 day" for any term that hasn't begun.
    @Test func beforeTheTermCountsTheRealDaysToGo() {
        let note = termNote(start: "2026-10-30", end: "2027-02-20", now: at(2026, 10, 20))
        #expect(note.line == "Starts in 10 days, 17 weeks long.")
        #expect(note.showsWindow)
        #expect(note.fraction == 0)
        #expect(termNote(start: "2026-10-21", end: "2027-02-20", now: at(2026, 10, 20, 23, 59)).line
                == "Starts in 1 day, 18 weeks long.")
        #expect(termNote(start: "2026-10-21", end: "2026-10-21", now: at(2026, 10, 20)).line
                == "Starts in 1 day, 1 week long.")
    }

    @Test func anEndBeforeTheStartIsCalledOut() {
        #expect(termNote(start: "2026-12-18", end: "2026-09-01", now: at(2026, 10, 20)) == TermNote(
            showsWindow: false, fraction: nil,
            line: "The end date is before the start date, check the dates."))
    }

    @Test func halfSetOrUnsetAsksForBothDates() {
        let ask = "Set both dates to see how far through the semester you are. They're printed on your grade report too."
        #expect(termNote(start: "2026-09-01", end: nil, now: at(2026, 10, 20))
                == TermNote(showsWindow: true, fraction: nil, line: ask))
        #expect(termNote(start: nil, end: "2026-12-18", now: at(2026, 10, 20))
                == TermNote(showsWindow: true, fraction: nil, line: ask))
        #expect(termNote(start: nil, end: nil, now: at(2026, 10, 20))
                == TermNote(showsWindow: false, fraction: nil, line: ask))
    }

    @Test func theWindowNoteIsTheWebsWords() {
        #expect(TERM_WINDOW_NOTE == "Your classes only appear inside this window, on Today, on the week grid, and in the calendar you export to your phone.")
    }

    @Test func aDayStartsAtLocalMidnight() {
        #expect(dayStart("2026-10-20") == at(2026, 10, 20, 0, 0))
        #expect(dayStart("2026-10-20").map(dayOf) == "2026-10-20")
        #expect(dayStart("2026-02-30") == nil)
        #expect(dayStart(nil) == nil)
    }
}

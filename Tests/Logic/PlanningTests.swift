// PlanningTests.swift: the Swift twin of the `nextRepeatDate` cases in
// lib/planning.test.ts (the rest of that file arrives with Phase 6), plus a
// year rollover and bad input.
// Run: tools/logic-test.sh. Kelvin does not type this file.
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
}

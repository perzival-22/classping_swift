// Phase 6b: the term glance, including deadline boundaries and clear days.
import Foundation
import Testing
@testable import CPLogic

private struct Work: Completable {
    var due: String? = nil
    var dueTime: String? = nil
    var done = false
}

private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12,
                _ minute: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Suite struct StreakTests {
    private let now = at(2026, 10, 17)

    @Test func emptyWorkHasNoStats() {
        #expect(termStats([Work](), now)
                == TermStats(completed: 0, overdue: 0, dueThisWeek: 0, streak: 0))
    }

    @Test func completedWorkCountsWithoutBeingOverdueOrUpcoming() {
        let work = [Work(due: "2026-10-15", done: true),
                    Work(due: "2026-10-19", done: true), Work(done: true)]
        let stats = termStats(work, now)
        #expect(stats.completed == 3)
        #expect(stats.overdue == 0)
        #expect(stats.dueThisWeek == 0)
    }

    @Test func weekWindowIncludesNowAndExactlySevenDays() {
        let work = [Work(due: "2026-10-17", dueTime: "12:00"),
                    Work(due: "2026-10-24", dueTime: "12:00"),
                    Work(due: "2026-10-24", dueTime: "12:01"),
                    Work(due: "2026-10-17", dueTime: "11:59")]
        let stats = termStats(work, now)
        #expect(stats.dueThisWeek == 2)
        #expect(stats.overdue == 1)
    }

    @Test func allDayWorkBecomesOverdueAfterItsDayEnds() {
        let work = [Work(due: "2026-10-16"), Work(due: "2026-10-17")]
        #expect(termStats(work, now).overdue == 1)
        #expect(termStats(work, now).dueThisWeek == 1)
        #expect(termStats([work[1]], at(2026, 10, 18, 0)).overdue == 1)
    }

    @Test func inboxAndInvalidDeadlinesDoNotClaimClearDays() {
        let work = [Work(), Work(due: "not a date"), Work(done: true)]
        #expect(termStats(work, now)
                == TermStats(completed: 1, overdue: 0, dueThisWeek: 0, streak: 0))
    }

    @Test func clearStreakStartsAtEarliestDeadline() {
        // Oct 14 at noon to Oct 18 at midnight spans 3.5 fixed days.
        let work = [Work(due: "2026-10-14", dueTime: "12:00", done: true)]
        #expect(termStats(work, now).streak == 4)
    }

    @Test func futureDeadlinesGiveAtMostOneInitialClearDay() {
        #expect(termStats([Work(due: "2026-11-01")], now).streak == 1)
    }

    @Test func unfinishedWorkDueLaterTodayStopsTheEndOfDayStreak() {
        let stats = termStats([Work(due: "2026-10-17", dueTime: "18:00")], now)
        #expect(stats.overdue == 0)
        #expect(stats.dueThisWeek == 1)
        #expect(stats.streak == 0)
    }

    @Test func catchingUpRestartsClearDays() {
        var work = [Work(due: "2026-10-14", dueTime: "12:00")]
        #expect(termStats(work, now).streak == 0)
        work[0].done = true
        #expect(termStats(work, now).streak == 4)
    }

    @Test func capsTheStreakAtOneYear() {
        #expect(termStats([Work(due: "2020-01-01", done: true)], now).streak == 365)
    }

    @Test func usesFixedTwentyFourHourDaysAcrossDaylightSaving() {
        let fallNow = at(2026, 11, 1)
        let today = Calendar.current.startOfDay(for: fallNow)
        // Keep the web's fixed 24-hour endpoint, even on a 25-hour day.
        let endpoint = today.addingTimeInterval(86_400)
        let work = Work(due: dayOf(endpoint), dueTime: timeOf(endpoint))
        #expect(termStats([work], fallNow).streak == 1)
        // One minute before that endpoint stops the streak instead.
        let before = endpoint.addingTimeInterval(-60)
        let earlier = Work(due: dayOf(before), dueTime: timeOf(before))
        #expect(termStats([earlier], fallNow).streak == 0)
    }
}

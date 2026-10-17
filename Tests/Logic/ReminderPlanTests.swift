// ReminderPlanTests.swift: the phone-only half of the reminders (D-27, D-28).
// The web has no tests for these because it has no planner: it checks every
// 30 seconds. These pin what the phone plans ahead: 8 AM nudges, quiet hours
// holding a reminder until they end, weekly class alarms, the 64 cap and the
// "what has rung" bookkeeping.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// A stand-in task. Due Sat 12 Sep 2026 at 10:00 unless a test says otherwise.
private struct Work: Remindable {
    var id = UUID()
    var title = "Lab report"
    var courseID: UUID? = nil
    var kindName = "assignment"
    var due: String? = "2026-09-12"
    var dueTime: String? = "10:00"
    var reminder = true
    var done = false
    var remindLeads: [Int] = []
    var snoozedUntil: Date? = nil
}

/// A stand-in class: Mon/Wed 10:00 to 10:50 with a 15-minute alarm.
private struct Subject: Alarmable {
    var id = UUID()
    var name = "Machine Learning"
    var days = [0, 2]
    var startMin = 600
    var endMin = 650
    var room: String? = nil
    var additionalMeetings: [ClassMeeting] = []
    var alarm = true
    var remindBefore = 15
    var archived = false
}

/// Thu 10 Sep 2026 at noon. 7 Sep 2026 is a Monday.
private let NOW = at(2026, 9, 10, 12, 0)

/// The daily nudges planned for `w`, as (moment, title) pairs.
private func nags(_ w: Work, quiet: QuietHours? = nil, now: Date = NOW) -> [(Date, String)] {
    taskReminders(w, quiet: quiet, fired: [], now: now)
        .filter { $0.kind == .taskNag }
        .map { ($0.firstDate, $0.title) }
}

@Suite struct ReminderPlanTests {

    // MARK: the daily nudge (D-27)

    @Test func startsExactly24HoursOutThenRingsAt8AM() {
        let planned = nags(Work())
        #expect(planned.count == 6)   // Fri 11 through Wed 16: the week ahead from Thursday
        #expect(planned[0].0 == at(2026, 9, 11, 10, 0))
        #expect(planned[0].1 == "Due in 24 hours")
        #expect(planned[1].0 == at(2026, 9, 12, 8, 0))   // due day, before the 10:00 deadline
        #expect(planned[1].1 == "Due in 24 hours")
        #expect(planned[2].0 == at(2026, 9, 13, 8, 0))
        #expect(planned[2].1 == "Overdue")
    }

    @Test func startsAllDayWorkAt8AMOnItsDayNotAtMidnight() {
        let planned = nags(Work(dueTime: nil))
        #expect(planned.first?.0 == at(2026, 9, 12, 8, 0))
        #expect(planned.first?.1 == "Due in 24 hours")
        #expect(planned.dropFirst().first?.1 == "Overdue")
    }

    @Test func ringsRightAwayWhenTheWindowIsAlreadyOpen() {
        // Due tomorrow at 9 AM, set up today at noon: the web rings at once.
        let planned = nags(Work(due: "2026-09-11", dueTime: "09:00"))
        #expect(planned.first?.0 == NOW)
        #expect(planned.first?.1 == "Due in 24 hours")
    }

    @Test func quietHoursHoldANudgeButNeverIntoTheNextDay() {
        // Due Sat 23:30: the window opens Fri 23:30, inside 22:00 to 07:00.
        // Held to Sat 07:00 it would belong to Saturday, so Friday gets none,
        // and Saturday's 8 AM nudge is the first.
        let planned = nags(Work(dueTime: "23:30"), quiet: defaultQuietHours)
        #expect(planned.first?.0 == at(2026, 9, 12, 8, 0))
    }

    @Test func quietHoursEndingAfter8AMHoldTheMorningNudge() {
        let lateRiser = QuietHours(start: 23 * 60, end: 9 * 60 + 30)
        let planned = nags(Work(), quiet: lateRiser)
        #expect(planned[1].0 == at(2026, 9, 12, 9, 30))
    }

    @Test func aSnoozeHoldsTheNudgeUntilItEnds() {
        let until = at(2026, 9, 11, 18, 0)
        let planned = nags(Work(snoozedUntil: until))
        #expect(planned.first?.0 == until)
    }

    @Test func quietHoursHoldAnEarlyWarningUntilMorning() {
        // 3 days before Sat 23:30 is Wed 23:30, inside quiet hours: held to
        // Thu 07:00, still within its day of grace.
        let w = Work(dueTime: "23:30", remindLeads: [4320])
        let lead = taskReminders(w, quiet: defaultQuietHours, fired: [], now: at(2026, 9, 9, 12))
            .filter { $0.kind == .taskLead }
        #expect(lead.map(\.firstDate) == [at(2026, 9, 10, 7, 0)])
    }

    // MARK: classes

    @Test func givesEachMeetingDayOneWeeklyAlarm() {
        let out = classReminders([Subject()], postClass: false, quiet: nil, now: NOW)
        #expect(out.count == 2)
        // Monday's next one is 14 Sep, Wednesday's 16 Sep (today is Thursday).
        #expect(out.map(\.timing) == [.weekly(at(2026, 9, 14, 9, 45)), .weekly(at(2026, 9, 16, 9, 45))])
        #expect(out.first?.title == "Machine Learning starts at 10:00 AM")
        #expect(out.first?.body == "That's in 15 minutes.")
    }

    @Test func ringsAPreClassAlarmThroughQuietHours() {
        let early = Subject(days: [4], startMin: 7 * 60 + 15, endMin: 8 * 60, remindBefore: 30)
        let out = classReminders([early], postClass: false, quiet: defaultQuietHours, now: NOW)
        #expect(out.map(\.firstDate) == [at(2026, 9, 11, 6, 45)])
    }

    @Test func movesAnAlarmBeforeMidnightToTheDayBefore() {
        let late = Subject(days: [1], startMin: 5, endMin: 60, remindBefore: 10)   // Tue 12:05 AM
        let out = classReminders([late], postClass: false, quiet: nil, now: NOW)
        #expect(out.map(\.firstDate) == [at(2026, 9, 14, 23, 55)])   // Monday night
    }

    @Test func asksAfterClassAndRespectsTheSwitch() {
        let s = Subject(alarm: false)
        let on = classReminders([s], postClass: true, quiet: nil, now: NOW)
        #expect(on.map(\.kind) == [.postClass, .postClass])
        #expect(on.first?.firstDate == at(2026, 9, 14, 10, 50))
        #expect(on.first?.title == "Machine Learning just ended")
        #expect(classReminders([s], postClass: false, quiet: nil, now: NOW).isEmpty)
    }

    @Test func waitsForQuietHoursOnlyWithinThe20MinuteWindow() {
        // Ends 6:50 AM, quiet until 7:00: asks at 7:00, 10 minutes late.
        #expect(postClassMinute(6 * 60 + 50, defaultQuietHours) == 7 * 60)
        // Ends 10:30 PM: quiet all night, so it doesn't ask at all.
        #expect(postClassMinute(22 * 60 + 30, defaultQuietHours) == nil)
        // Outside quiet hours: right at the end.
        #expect(postClassMinute(650, defaultQuietHours) == 650)
    }

    @Test func leavesArchivedClassesSilent() {
        #expect(classReminders([Subject(archived: true)], postClass: true, quiet: nil, now: NOW).isEmpty)
    }

    @Test func ringsLaterTodayOrNextWeekNeverInThePast() {
        // Thursday is day 3. 1:00 PM is still ahead today; 11:00 AM has gone.
        #expect(nextWeekly(3, 13 * 60, after: NOW) == at(2026, 9, 10, 13, 0))
        #expect(nextWeekly(3, 11 * 60, after: NOW) == at(2026, 9, 17, 11, 0))
    }

    // MARK: the whole plan

    @Test func keepsTheSoonest64InOrder() {
        // 20 tasks with a week of nudges each is far more than iOS will hold.
        let tasks = (0..<20).map { _ in Work(due: "2026-09-11", dueTime: "15:00") }
        let plan = reminderPlan(courses: [Subject()], tasks: tasks, postClass: true,
                                quiet: nil, fired: [], now: NOW)
        #expect(plan.count == maxPendingReminders)
        #expect(zip(plan, plan.dropFirst()).allSatisfy { $0.firstDate <= $1.firstDate })
    }

    @Test func countsAOneOffWhoseMomentHasPassedAsRung() {
        let id = "t1"
        let past = "task:\(id):2026-09-10"
        let future = "task:\(id):2026-09-11"
        let fired = settledFired([], scheduled: [past: at(2026, 9, 10, 8), future: at(2026, 9, 11, 8)],
                                 now: NOW, liveTaskIDs: [id])
        #expect(fired == [past])
    }

    @Test func forgetsWhatNoLongerMatters() {
        // Yesterday's nudge and a deleted task's warning both go.
        let old: Set = ["task:t1:2026-09-09", leadKey("gone", 4320, NOW)]
        #expect(settledFired(old, scheduled: [:], now: NOW, liveTaskIDs: ["t1"]).isEmpty)
    }

    // MARK: the clock helper

    @Test func atMinuteRollsIntoTheNeighbouringDays() {
        let day = at(2026, 9, 10, 15)
        #expect(atMinute(day, 480) == at(2026, 9, 10, 8, 0))
        #expect(atMinute(day, 1450) == at(2026, 9, 11, 0, 10))
        #expect(atMinute(day, -10) == at(2026, 9, 9, 23, 50))
    }

    @Test func keepsTheClockTimeAcrossDaylightSavingChanges() {
        // The US clocks change on 8 Mar and 1 Nov 2026; elsewhere these are
        // ordinary days. Either way 8 AM must stay 8 AM, and a Monday 9:45
        // alarm must stay 9:45, not drift by the hour that was skipped or repeated.
        let cal = Calendar.current
        for day in [at(2026, 3, 8, 12), at(2026, 11, 1, 12)] {
            let eight = cal.dateComponents([.hour, .minute], from: atMinute(day, 480))
            #expect(eight.hour == 8 && eight.minute == 0)
            let alarm = cal.dateComponents([.hour, .minute, .weekday],
                                           from: nextWeekly(0, 585, after: day))
            #expect(alarm.hour == 9 && alarm.minute == 45 && alarm.weekday == 2)   // Apple: 2 = Monday
        }
    }
}

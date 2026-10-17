// RemindersTests.swift: the Swift twin of lib/reminders.test.ts.
// The web's `dueReminders` asks "what rings right now?"; the phone plans
// ahead instead (D-28), so the "what fires now" cases ask the planner what
// it would ring at that moment. Same tasks, same clocks, same answers.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// Local wall-clock Date in the runner's own zone, the zone the logic reads.
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// The web test's task id "t1", as a UUID.
private let t1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!

/// The `task({...})` helper: an essay due 10 Sep at 23:30 with its reminder on.
private struct Item: Remindable {
    var id = t1
    var title = "Essay"
    var courseID: UUID? = nil
    var kindName = "assignment"
    var due: String? = "2026-09-10"
    var dueTime: String? = "23:30"
    var reminder = true
    var done = false
    var remindLeads: [Int] = []
    var snoozedUntil: Date? = nil
}

/// What the planner would ring at `now` itself: `dueReminders` in the web.
private func ringingNow(_ t: Item, _ now: Date, _ fired: Set<String> = []) -> [PlannedReminder] {
    taskReminders(t, quiet: nil, fired: fired, now: now).filter { $0.firstDate <= now }
}

@Suite struct RemindersTests {

    // MARK: quiet hours

    @Test func treatsAWindowThatWrapsMidnightAsOneWindow() {
        let q = defaultQuietHours   // 22:00 -> 07:00
        #expect(inQuietHours(23 * 60, q))
        #expect(inQuietHours(2 * 60, q))
        #expect(!inQuietHours(12 * 60, q))
    }

    @Test func makesStartInclusiveAndEndExclusive() {
        let q = defaultQuietHours
        #expect(!inQuietHours(22 * 60 - 1, q))
        #expect(inQuietHours(22 * 60, q))
        #expect(inQuietHours(7 * 60 - 1, q))
        #expect(!inQuietHours(7 * 60, q))
    }

    @Test func handlesASameDayWindowToo() {
        let q = QuietHours(start: 9 * 60, end: 11 * 60)
        #expect(inQuietHours(10 * 60, q))
        #expect(!inQuietHours(8 * 60, q))
        #expect(!inQuietHours(23 * 60, q))
    }

    @Test func isNeverQuietWhenUnset() {
        #expect(!inQuietHours(3 * 60, nil))
    }

    @Test func storesOffAsAnEmptyWindow() {
        #expect(normalizeQuietHours(start: 480, end: 480) == nil)
        #expect(normalizeQuietHours(start: 1320, end: 420) == QuietHours(start: 1320, end: 420))
    }

    @Test func rejectsOutOfRangeAndMissingWindows() {
        #expect(normalizeQuietHours(start: -1, end: 60) == nil)
        #expect(normalizeQuietHours(start: 0, end: 1440) == nil)
        // The web's "x" can't be an Int; a missing end is the same failure.
        #expect(normalizeQuietHours(start: 60, end: nil) == nil)
        #expect(normalizeQuietHours(start: nil, end: nil) == nil)
    }

    @Test func letsAPreClassAlarmRingThroughTheNightButNothingElse() {
        let q = defaultQuietHours
        let at3am = 3 * 60
        #expect(mayFire(.classAlarm, at3am, q))
        #expect(!mayFire(.postClass, at3am, q))
        #expect(!mayFire(.taskNag, at3am, q))
        #expect(!mayFire(.taskLead, at3am, q))
    }

    @Test func letsEverythingThroughOutsideTheWindow() {
        let noon = 12 * 60
        let kinds: [ReminderKind] = [.classAlarm, .postClass, .taskNag, .taskLead]
        #expect(kinds.allSatisfy { mayFire($0, noon, defaultQuietHours) })
    }

    // MARK: snooze

    /// Tue 8 Sep 2026, 14:20.
    let now = at(2026, 9, 8, 14, 20)

    @Test func offsetsTheHourPresetsFromRightNow() {
        #expect(snoozeUntil(.oneHour, now) == now.addingTimeInterval(3600))
        #expect(snoozeUntil(.threeHours, now) == now.addingTimeInterval(3 * 3600))
    }

    @Test func landsTheEveningPresetOn6PMToday() {
        #expect(snoozeUntil(.evening, now) == at(2026, 9, 8, 18, 0))
    }

    @Test func rollsTheEveningPresetToTomorrowOnce6PMHasPassed() {
        #expect(snoozeUntil(.evening, at(2026, 9, 8, 21, 0)) == at(2026, 9, 9, 18, 0))
    }

    @Test func makesTomorrowMeanTomorrowMorning() {
        #expect(snoozeUntil(.tomorrow, at(2026, 9, 8, 2, 0)) == at(2026, 9, 9, 8, 0))
    }

    @Test func expiresOnItsOwn() {
        let until = now.addingTimeInterval(60)
        #expect(isSnoozed(until, now))
        #expect(!isSnoozed(until, now.addingTimeInterval(120)))
        #expect(!isSnoozed(nil, now))
    }

    // MARK: lead times

    @Test func sortsLongestFirstAndDropsDuplicatesAndNonsense() {
        #expect(normalizeLeads([1440, 10080, 1440, 0, -5]) == [10080, 1440])
    }

    @Test func refusesALeadLongerThanAFortnight() {
        #expect(normalizeLeads([maxLeadMinutes + 1]) == nil)
        #expect(normalizeLeads([maxLeadMinutes]) == [maxLeadMinutes])
    }

    @Test func treatsAnEmptyListAsUnset() {
        #expect(normalizeLeads([]) == nil)
    }

    @Test func givesAnExamTheDefaultLadderAndAnAssignmentNothing() {
        #expect(effectiveLeads(Item(kindName: "exam")) == examLeadMinutes)
        #expect(effectiveLeads(Item(kindName: "assignment")) == [])
        #expect(effectiveLeads(Item()) == [])
    }

    @Test func letsAnExplicitChoiceOverrideTheExamLadder() {
        #expect(effectiveLeads(Item(kindName: "exam", remindLeads: [2880])) == [2880])
    }

    @Test func labelsOffsetsInTheUnitsAStudentWouldSay() {
        #expect(leadLabel(10080) == "1 week")
        #expect(leadLabel(1440) == "1 day")
        #expect(leadLabel(4320) == "3 days")
        #expect(leadLabel(180) == "3 hours")
        #expect(leadLabel(45) == "45 min")
    }

    // MARK: what fires now

    @Test func nagsOnceADayInsideTheLast24Hours() {
        let out = ringingNow(Item(), at(2026, 9, 10, 9, 0))   // due 23:30 same day
        #expect(out.count == 1)
        #expect(out.first?.kind == .taskNag)
        #expect(out.first?.title == "Due in 24 hours")
        #expect(out.first?.id == "task:\(t1.uuidString):2026-09-10")
    }

    @Test func saysOverdueOnceTheDeadlineHasPassed() {
        #expect(ringingNow(Item(), at(2026, 9, 11, 9, 0)).first?.title == "Overdue")
    }

    @Test func doesNotRepeatANagAlreadyFiredToday() {
        let fired: Set = ["task:\(t1.uuidString):2026-09-10"]
        #expect(ringingNow(Item(), at(2026, 9, 10, 9, 0), fired).isEmpty)
    }

    @Test func staysSilentForUndatedDoneAndSwitchedOffTasks() {
        let now = at(2026, 9, 10, 9, 0)
        // Not just silent now: nothing is planned for them at all.
        #expect(taskReminders(Item(due: nil, dueTime: nil), quiet: nil, fired: [], now: now).isEmpty)
        #expect(taskReminders(Item(done: true), quiet: nil, fired: [], now: now).isEmpty)
        #expect(taskReminders(Item(reminder: false), quiet: nil, fired: [], now: now).isEmpty)
    }

    @Test func staysSilentWhileSnoozedThenSpeaksAgainAfter() {
        let now = at(2026, 9, 10, 9, 0)
        let snoozed = Item(snoozedUntil: now.addingTimeInterval(3600))
        #expect(ringingNow(snoozed, now).isEmpty)
        #expect(ringingNow(snoozed, now.addingTimeInterval(2 * 3600)).count == 1)
    }

    @Test func firesAnEarlyOneShotAtItsLeadAndOnlyOnce() {
        // 3 days before a 10 Sep 23:30 deadline is 7 Sep 23:30.
        let t = Item(remindLeads: [4320])
        #expect(ringingNow(t, at(2026, 9, 7, 20, 0)).isEmpty)

        let out = ringingNow(t, at(2026, 9, 8, 8, 0))
        #expect(out.count == 1)
        #expect(out.first?.kind == .taskLead)
        #expect(out.first?.id == leadKey(t1.uuidString, 4320, at(2026, 9, 10, 23, 30)))

        let fired = Set(out.map(\.id))
        #expect(ringingNow(t, at(2026, 9, 8, 8, 0), fired).isEmpty)
    }

    @Test func reArmsAnEarlyWarningWhenTheDeadlineMoves() {
        let t = Item(remindLeads: [4320])
        let spent = Set(ringingNow(t, at(2026, 9, 8, 8, 0)).map(\.id))
        // Pushed back a fortnight: a new deadline deserves its own warning.
        let moved = Item(due: "2026-09-24", remindLeads: [4320])
        #expect(ringingNow(moved, at(2026, 9, 22, 8, 0), spent).map(\.kind) == [.taskLead])
    }

    @Test func dropsALeadPingThatIsMoreThanADayStale() {
        let t = Item(remindLeads: [10080])   // 1 week -> 3 Sep 23:30
        #expect(ringingNow(t, at(2026, 9, 6, 12, 0)).isEmpty)
    }

    @Test func neverDoublesTheDailyNagWithALeadInside24Hours() {
        let t = Item(remindLeads: [1440, 120])
        #expect(ringingNow(t, at(2026, 9, 10, 9, 0)).map(\.kind) == [.taskNag])
    }

    @Test func givesAnExamItsLadderWithoutAnyConfiguration() {
        let exam = Item(title: "Physics final", kindName: "exam")
        let due = at(2026, 9, 10, 23, 30)
        // Each rung owns its own window, so the ladder is climbed one at a time.
        let threeDaysOut = ringingNow(exam, at(2026, 9, 8, 8, 0))
        #expect(threeDaysOut.map(\.id) == [leadKey(t1.uuidString, 4320, due)])
        #expect(threeDaysOut.first?.title == "3 days until your exam")

        #expect(ringingNow(exam, at(2026, 9, 9, 8, 0)).map(\.id) == [leadKey(t1.uuidString, 2880, due)])
    }

    // MARK: pruning the fired map

    let live: Set = ["t1"]

    @Test func keepsTodaysPerDayKeysAndDropsYesterdays() {
        #expect(keepFiredKey("class:c1:2026-09-10", "2026-09-10", live))
        #expect(!keepFiredKey("class:c1:2026-09-09", "2026-09-10", live))
        #expect(keepFiredKey("postclass:c1:2026-09-10", "2026-09-10", live))
    }

    @Test func keepsALeadKeyForAsLongAsItsTaskExists() {
        let key = leadKey("t1", 10080, at(2026, 9, 10, 23, 30))
        #expect(keepFiredKey(key, "2026-09-10", live))
        #expect(keepFiredKey(key, "2026-11-01", live))
        #expect(!keepFiredKey(leadKey("gone", 10080, .now), "2026-09-10", live))
    }

    @Test func keepsANagKeyOnlyForTodayAndOnlyForALiveTask() {
        #expect(keepFiredKey("task:t1:2026-09-10", "2026-09-10", live))
        #expect(!keepFiredKey("task:t1:2026-09-09", "2026-09-10", live))
        #expect(!keepFiredKey("task:gone:2026-09-10", "2026-09-10", live))
    }

    @Test func agesOutTheOldUndatedKeyFormatAndAnythingUnrecognised() {
        #expect(!keepFiredKey("task:t1", "2026-09-10", live))
        #expect(!keepFiredKey("nonsense", "2026-09-10", live))
    }
}

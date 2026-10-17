//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ReminderPlan.swift
//  Phase:   7a (reminders ring)
//  Ports:   the reminder loop in lib/store.tsx and `dueReminders` in
//           lib/reminders.ts, turned inside out (D-28)
//
//  Summary: The web app asks every 30 seconds "what should ring right now?",
//           which only works while a tab is open. iOS can ring a notification
//           at a set moment even when the app is closed, so this file answers
//           the other question: "what should ring from now on, and when?".
//           The store hands that list to iOS. Foundation only, for the tests.
//

import Foundation

// MARK: - What the plan is made of

/// A class that can ring before it starts. It builds on `Schedulable` (5a),
/// which already lists the meetings, and adds the alarm fields. `Course`
/// signs up in Models+Reminders.swift.
protocol Alarmable: Schedulable {
    var name: String { get }
    var alarm: Bool { get }
    var remindBefore: Int { get }
    var archived: Bool { get }
}

/// When one notification rings.
enum ReminderTiming: Equatable {
    /// Once, at this moment. A moment that has already come means "right now".
    case once(Date)
    /// Every week on the same weekday at the same clock time, starting here.
    case weekly(Date)
}

/// One notification the phone should ring.
struct PlannedReminder: Equatable, Identifiable {
    /// The dedupe key, which is also the notification's id. Handing iOS the
    /// same id again replaces that notification instead of adding a second.
    let id: String
    let kind: ReminderKind
    let timing: ReminderTiming
    let title: String
    let body: String
    /// What it's about: the class for class reminders, the task for task
    /// reminders. Phase 7c uses these to open the right screen on a tap.
    var courseID: UUID? = nil
    var assignmentID: UUID? = nil

    /// The first time it rings, whichever kind of timing it has.
    /// `case .once(let d), .weekly(let d)` pulls the date out of either case.
    var firstDate: Date {
        switch timing {
        case .once(let d), .weekly(let d): d
        }
    }
}

/// How many notifications iOS will hold waiting at once. It quietly drops the
/// rest, so the plan keeps the soonest 64 itself and knows exactly what's set.
let maxPendingReminders = 64

/// How many days of daily nudges to plan. The plan is rebuilt every time the
/// app opens, so a week ahead is plenty.
let nudgeDays = 7

/// How long after a class ends its nudge may still ring.
/// `POST_CLASS_WINDOW_MIN` in lib/store.tsx.
let postClassWindow = 20

// MARK: - Shared rules

/// The moment a reminder may really ring: not before its natural moment, not
/// before now, not while its task is snoozed, and not in quiet hours unless
/// it's a class alarm. Other kinds wait for them to end. The web's loop
/// reaches the same answer by waiting: it asks again until the answer is yes.
func settle(_ natural: Date, _ kind: ReminderKind, quiet: QuietHours?,
            snoozedUntil: Date?, now: Date) -> Date {
    // A moment that's already gone means "right away".
    var moment = max(natural, now)
    // A snooze holds everything until it ends.
    if let snoozedUntil, snoozedUntil > moment { moment = snoozedUntil }
    // Outside quiet hours (or a class alarm): ring as planned.
    let mins = minuteOfDay(moment)
    guard let quiet, !mayFire(kind, mins, quiet) else { return moment }
    // Inside them: wait until they end, later today, or tomorrow morning when
    // it's late at night in a window that wraps past midnight.
    return atMinute(moment, quiet.end > mins ? quiet.end : quiet.end + 1440)
}

/// The next moment after `now` on weekday `day` (0 = Monday) at `minute`
/// past midnight. A minute below 0 or past 1439 spills into the next or
/// previous day, so an alarm 10 minutes before a 12:05 AM Tuesday class lands
/// on Monday at 11:55 PM.
func nextWeekly(_ day: Int, _ minute: Int, after now: Date) -> Date {
    // Fold day and minute into one "minute of the week" (Monday 12:00 AM is 0,
    // and a week has 10,080 minutes), then split it again, so any spill
    // lands on the right weekday. The double `%` keeps the result positive.
    let week = 7 * 1440
    let w = ((day * 1440 + minute) % week + week) % week
    let targetDay = w / 1440
    let targetMinute = w % 1440
    // Days forward from today to that weekday: 0 when it's today.
    let ahead = (targetDay - dayIndex(of: now) + 7) % 7
    let candidate = atMinute(scheduleDate(now, ahead), targetMinute)
    // Today's has already gone: the same time next week.
    return candidate > now ? candidate : atMinute(scheduleDate(now, ahead + 7), targetMinute)
}

/// The minute of the day a class ending at `end` gets its after-class nudge,
/// or nil when quiet hours cover the whole 20 minutes after it. On the web
/// the loop waits for quiet hours to end and still asks if that's within the
/// window; this is the same wait, worked out ahead of time.
func postClassMinute(_ end: Int, _ quiet: QuietHours?) -> Int? {
    guard let quiet, !mayFire(.postClass, end, quiet) else { return end }
    // Minutes from the class's end until quiet hours close, across midnight.
    let wait = (quiet.end - end + 1440) % 1440
    return wait < postClassWindow ? end + wait : nil
}

// MARK: - Classes

/// The pre-class alarms and after-class nudges for every meeting of every
/// class. Each meeting day becomes one weekly notification: a Mon/Wed/Fri
/// class is three alarms that repeat on their own, instead of a new one for
/// every date. The web's loop checks the same two rules every 30 seconds.
func classReminders<C: Alarmable>(_ courses: [C], postClass: Bool,
                                  quiet: QuietHours?, now: Date) -> [PlannedReminder] {
    var out: [PlannedReminder] = []
    // Archived classes stay silent, as on the web.
    for slot in expandClassMeetings(courses.filter { !$0.archived }) {
        let c = slot.course
        let m = slot.meeting
        let key = meetingKey(slot)
        // `where` skips a day number that isn't a real weekday.
        for day in m.days where (0...6).contains(day) {
            // The pre-class alarm, when it's on. It rings through quiet hours.
            if c.alarm {
                let lead = c.remindBefore
                out.append(PlannedReminder(
                    id: "class:\(key):\(day)",
                    kind: .classAlarm,
                    timing: .weekly(nextWeekly(day, m.start - lead, after: now)),
                    title: "\(c.name) starts at \(fmtTime(m.start))",
                    body: "That's in \(lead) minute\(lead == 1 ? "" : "s").",
                    courseID: c.id))
            }
            // The after-class nudge, unless quiet hours swallow its window.
            if postClass, let minute = postClassMinute(m.end, quiet) {
                out.append(PlannedReminder(
                    id: "postclass:\(key):\(day)",
                    kind: .postClass,
                    timing: .weekly(nextWeekly(day, minute, after: now)),
                    title: "\(c.name) just ended",
                    body: "Did it come with homework? Add it before you forget.",
                    courseID: c.id))
            }
        }
    }
    return out
}

// MARK: - Tasks

/// Everything one task has coming: its early warnings, then one daily nudge
/// for each of the next `nudgeDays` days. `dueReminders` in lib/reminders.ts
/// answers "what rings right now?"; this lists the moments instead. A moment
/// that's already here comes back as "now", unless `fired` says it rang.
func taskReminders<T: Remindable>(_ task: T, quiet: QuietHours?,
                                  fired: Set<String>, now: Date) -> [PlannedReminder] {
    // Nothing for switched-off, completed or undated work. Undated work waits
    // in the Inbox until it has a deadline: there's nothing to be late for.
    guard task.reminder, !task.done, let due = dueAt(task) else { return [] }
    let id = task.id.uuidString
    var out: [PlannedReminder] = []

    // Early warnings, longest first. `where` leaves out any lead inside the
    // last 24 hours: the daily nudge already covers that stretch.
    let ahead = task.kindName == "exam" ? "your exam" : "this is due"
    for lead in effectiveLeads(task) where TimeInterval(lead * 60) > nagWindow {
        let key = leadKey(id, lead, due)
        let natural = due.addingTimeInterval(-TimeInterval(lead * 60))
        let moment = settle(natural, .taskLead, quiet: quiet,
                            snoozedUntil: task.snoozedUntil, now: now)
        // Not one that already rang, and not one pushed more than a day past
        // its moment: late is still useful, stale is not.
        if !fired.contains(key) && moment <= natural.addingTimeInterval(leadGrace) {
            out.append(PlannedReminder(
                id: key, kind: .taskLead, timing: .once(moment),
                title: "\(leadLabel(lead)) until \(ahead)",
                body: "\(task.title), worth starting now.",
                assignmentID: task.id))
        }
    }

    // The daily nudge (D-27). It starts 24 hours before a timed deadline. An
    // all-day deadline counts as 11:59 PM, so 24 hours before it would be a
    // midnight buzz the night before; it starts at 8 AM on its day instead.
    let start = isAllDay(deadlineOf(task))
        ? atMinute(due, morningHour * 60)
        : due.addingTimeInterval(-nagWindow)
    let firstDay = dayOf(start)
    for offset in 0..<nudgeDays {
        let day = scheduleDate(now, offset)
        // Days before the window opens get nothing. Day strings compare
        // like dates ("2026-09-09" < "2026-09-10").
        if dayOf(day) >= firstDay {
            // The first day rings when the window opens; later days at 8 AM.
            let natural = dayOf(day) == firstDay ? start : atMinute(day, morningHour * 60)
            let key = nagKey(id, dayOf(day))
            let moment = settle(natural, .taskNag, quiet: quiet,
                                snoozedUntil: task.snoozedUntil, now: now)
            // A nudge belongs to its day. Pushed past midnight by a snooze or
            // quiet hours, it gives way to the next day's.
            if !fired.contains(key) && moment < scheduleDate(day, 1) {
                let title = moment >= due ? "Overdue" : "Due in 24 hours"
                out.append(PlannedReminder(
                    id: key, kind: .taskNag, timing: .once(moment),
                    title: title,
                    body: "\(task.title), tap ✓ when it's done.",
                    assignmentID: task.id))
            }
        }
    }
    return out
}

// MARK: - The whole plan

/// Everything that should ring from `now` on, soonest first, at most 64.
/// The store calls this with the live classes and assignments.
func reminderPlan<C: Alarmable, T: Remindable>(courses: [C], tasks: [T], postClass: Bool,
                                               quiet: QuietHours?, fired: Set<String>,
                                               now: Date) -> [PlannedReminder] {
    let all = classReminders(courses, postClass: postClass, quiet: quiet, now: now)
        + tasks.flatMap { taskReminders($0, quiet: quiet, fired: fired, now: now) }
    // Soonest first. Swift compares tuples left to right, so the id only
    // decides between two that ring at the same moment: a steady order.
    let sorted = all.sorted { ($0.firstDate, $0.id) < ($1.firstDate, $1.id) }
    return Array(sorted.prefix(maxPendingReminders))
}

/// What has already rung. Every one-off the last plan gave iOS whose moment
/// has passed counts as rung, on top of what was known before; then
/// `keepFiredKey` forgets the ones that no longer matter. The web keeps this
/// list in localStorage (`classping.notified.v1`).
func settledFired(_ fired: Set<String>, scheduled: [String: Date], now: Date,
                  liveTaskIDs: Set<String>) -> Set<String> {
    let rang = scheduled.filter { $0.value <= now }.keys
    let dayKey = dayOf(now)
    return fired.union(rang).filter { keepFiredKey($0, dayKey, liveTaskIDs) }
}

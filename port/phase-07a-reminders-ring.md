---
title: "Phase 7a: Reminders ring"
date: 2026-10-17
generated_by: skills-for-architects
---

# Phase 7a: Reminders ring

*First of three parts of Phase 7 (D-29). Checked on 2026-10-17 on top of your Phase 6b commit `8e6ff4f`: `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 159/159 (52 new: 33 twins of `lib/reminders.test.ts` and 19 for the phone's planner), and `persistence-test.sh` still passes 9/9. Nothing here has been on a phone yet; your `xtool dev` run is that check.*

**Before you start:** 6b is typed, building and committed (it is: `8e6ff4f`). This phase adds five files and changes three.

## 1. Goal

Your phone starts ringing for ClassPing, with the app open or closed: before each class, when a class ends, once a day for work that's due within 24 hours, earlier for exams, and never overnight if you switch on quiet hours.

**On your phone:** the first time you open the app after this phase, iOS asks **"ClassPing" Would Like to Send You Notifications**. Tap **Allow**. In the Profile tab, a new **Reminders** card has two switches: **After-class nudge** (on) and **Quiet hours** (off; switch it on and **From 10:00 PM to 7:00 AM** appears, with a line underneath saying what that means right now). Then the notifications themselves: "Machine Learning starts at 10:00 AM · That's in 15 minutes." before class, "Machine Learning just ended · Did it come with homework?" after it, "Due in 24 hours · Lab report, tap ✓ when it's done." the day before a deadline and at 8 AM on the day, and "3 days until your exam" ahead of an exam. If you switch notifications off in the Settings app, the Reminders card says so and gives you a button back to Settings.

What's still to come in Phase 7: the reminder controls on a task (warn me early, snooze), the exam plan and "Plan the work" (7b); and tapping a notification to land on the right screen, plus the post-class prompt and Today's "just finished" banner (7c). Until 7c, tapping a notification just opens the app.

## 2. New Swift concepts

**`UNUserNotificationCenter`: asking iOS to ring later.** An iOS app can't run a loop while it's closed, but it can hand iOS a list of notifications with a time on each, and iOS rings them on time even if the app never opens again. Each one is a *request*: an id, the *content* (title, body, sound) and a *trigger* (when). A calendar trigger names a clock time; with `repeats: true` it rings every time the clock matches:

```swift
let content = UNMutableNotificationContent()
content.title = "Machine Learning starts at 10:00 AM"
content.body = "That's in 15 minutes."
// Every Monday at 9:45 AM (weekday 2 is Monday in Apple's numbering).
let when = DateComponents(hour: 9, minute: 45, weekday: 2)
let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
let request = UNNotificationRequest(identifier: "class:ML:0", content: content, trigger: trigger)
try? await UNUserNotificationCenter.current().add(request)
```

Adding a request with an id that's already waiting replaces it, which is what stops anything ringing twice. iOS holds at most 64 waiting requests per app and quietly drops the rest, so ClassPing hands it the soonest 64 and tops the list up every time the app opens.

**`async` and `await`.** Some questions take a while to answer: "may I show notifications?" goes to iOS's notification service and, the first time, waits for you to tap Allow. A function marked `async` is allowed to pause like that, and every call to it is marked `await`, which says "this may pause here". While it's paused the screen keeps working; when the answer comes back, the function carries on from that line. You can only `await` inside something that's itself async, such as `.task { }` (4b), or a `Task { }` you start yourself, which is how a button's action (which can't wait) kicks off async work:

```swift
Button("Allow notifications") {
    Task {
        let ok = await store.requestNotificationAccess()   // waits for your tap on Allow
        print(ok)
    }
}
```

A task can be *cancelled*, for example when `.task(id:)` starts a newer run. Cancelling doesn't stop the code by force; it sets `Task.isCancelled`, and the code checks it at sensible points and stops itself. `try? await Task.sleep(...)` is a pause that ends early on cancel (that's the throw `try?` ignores, as in 4b's Undo bar).

**Delegates.** Some Apple frameworks ask your app questions while they work: "a notification is arriving and your app is on screen, should I show it?". You answer by handing the framework an object, its *delegate*, whose methods it calls. The object's class says which questions it can answer by adopting a protocol, here `UNUserNotificationCenterDelegate`, and these older frameworks want it to inherit from `NSObject`, the base class of Apple's Objective-C world:

```swift
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]   // yes: show it as a banner with its sound
    }
}
```

Two things to know. The notification center keeps only a *weak* reference to its delegate (it won't keep it alive), so the app has to hold on to it. And every method in this protocol is optional, so if you misspell one, Swift doesn't complain: iOS just never calls it. (7c adds the second method, the one for taps.)

You'll also meet: **`UserDefaults`**, the small key-value store `@AppStorage` (4b) is built on, used here for bookkeeping that never syncs, like the web's localStorage; **`@Environment(\.scenePhase)`**, which says whether the app is on screen; **`if case .once(let date) = r.timing`**, which checks one case of an enum and pulls out its value in one step; and **comparing tuples**, `(a.date, a.id) < (b.date, b.id)`, which compares the dates and only looks at the ids when the dates are equal.

## 3. What it maps from the web app

The big difference first. The web checks every 30 seconds, while a tab is open, "what should ring **right now**?" (the reminder loop in `lib/store.tsx`, deciding through `dueReminders` in `lib/reminders.ts`). A phone app can't do that while it's closed, so the iPhone version asks the other question once per change: "what should ring **from now on**, and when?", and hands iOS the answer (D-28). The rules are the same, so the answers are the same: `RemindersTests.swift` runs every one of the web's `dueReminders` cases against the planner, asking what it would ring at that exact moment.

```
WEB (while a tab is open)                    PHONE (always, even closed)
every 30 s:                                  on launch, on every change, on every return:
  for each class / task:                       fired = what has rung since last time
    should it ring at this minute?             plan  = everything due from now on (≤ 64)
    yes, and not in `fired` -> show it         iOS's waiting list := plan
                            -> add to `fired`  iOS rings each one at its moment
```

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/reminders.ts`: quiet hours, `mayFire`, snooze presets, lead times, `leadLabel`, `leadKey`, `keepFiredKey` | `Logic/Reminders.swift` | Same rules and words. Quiet hours read the profile's two optional numbers (Phase 1) instead of one object. Snooze is ported now so 7b only has to draw it |
| `dueReminders` and the reminder loop in `lib/store.tsx` | `Logic/ReminderPlan.swift` | Plans ahead instead of checking every 30 s (D-28). A moment that has already come rings at once, as the loop would |
| a class alarm checked every 30 s | one **weekly** notification per meeting day | Calc on Mon/Wed/Fri is three alarms that repeat by themselves, so classes use a handful of iOS's 64 slots, not one per date |
| the nag "once per day" (in practice, the first check after midnight) | 24 h before a timed deadline, then **8 AM** each day (D-27) | Your pick. All-day work starts at 8 AM on its day, since 24 h before 11:59 PM would be a midnight buzz the night before |
| the fired map in localStorage (`classping.notified.v1`) | `UserDefaults`, `settledFired` | The phone also remembers what it handed iOS; anything whose moment has passed counts as rung |
| `ensureNotificationPermission`, `showReminder` in `lib/notifications.ts` | `Store+Notifications.swift` | iOS asks once, the first time there's something to ring (D-30). The web's "Reminder set ✓" test notification is dropped: it existed to prove the browser's permission worked |
| the Reminders card in `app/settings/page.tsx`, `components/QuietHours.tsx` | `Screens/Profile/RemindersSection.swift` | Same switches, sentences and the "nudge the end by a minute" rule. Adds a notice when iOS has notifications off. No push or email rows: a free Apple ID has no push, and email prefs need sign-in (Phase 14) |
| the class form's "Reminder: 15 minutes before each meeting." | `CourseFormView` footer | Now true, so the "coming soon" goes |
| web push, `public/sw.js`, `app/api/cron/post-class` | (none) | Local notifications do the job; push needs a paid account |

## 4. Files, in the order to type them

The first three are pure logic (no screens), so 4.1 to 4.3 build on their own. 4.4 and 4.5 need each other's names, so build after both.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Reminders.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Reminders.swift
//  Phase:   7a (reminders ring)
//  Ports:   lib/reminders.ts (quiet hours, snooze, lead times, the dedupe
//           keys and keepFiredKey). Its `dueReminders` became the planner in
//           Logic/ReminderPlan.swift (D-28).
//
//  Summary: The rules for when a nudge may ring and when it must not. Three
//           separate controls: quiet hours belong to your day, early warnings
//           ("lead times") belong to one task, and a snooze belongs to one
//           task right now. Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - What can be reminded about

/// Anything ClassPing can nudge you about. It builds on `TaskListable` from
/// Phase 4b (title, class, kind, `due` and `dueTime`) and adds the reminder
/// fields. `Assignment` signs up in Models+Reminders.swift; the tests use a
/// small stand-in. The web reads these straight off `TaskItem`.
protocol Remindable: TaskListable {
    var id: UUID { get }
    var reminder: Bool { get }
    var done: Bool { get }
    var remindLeads: [Int] { get }
    var snoozedUntil: Date? { get }
}

/// The four kinds of notification. `ReminderKind` in lib/reminders.ts.
/// The raw values are the web's words. Swift won't take `class` as a case
/// name (it's a keyword), so that one is `classAlarm` with the raw value "class".
enum ReminderKind: String {
    case classAlarm = "class"
    case postClass = "post-class"
    case taskNag = "task-nag"
    case taskLead = "task-lead"
}

// MARK: - Quiet hours

/// A nightly window, in minutes from local midnight. `QuietHours` in the web.
/// `start` is inclusive and `end` exclusive, so 22:00 to 07:00 is silent at
/// 6:59 AM and audible at 7:00 AM: no minute belongs to both.
struct QuietHours: Equatable {
    var start: Int
    var end: Int
}

/// 10:00 PM to 7:00 AM, what the switch proposes the first time it goes on.
/// `DEFAULT_QUIET_HOURS`.
let defaultQuietHours = QuietHours(start: 22 * 60, end: 7 * 60)

/// The profile's two stored numbers as a usable window, or nil for "off".
/// `normalizeQuietHours`. The profile keeps `quietStart` and `quietEnd` as
/// two optionals (Phase 1), so this takes them apart instead of one object.
/// A window whose ends match is empty, which is how "off" is stored.
func normalizeQuietHours(start: Int?, end: Int?) -> QuietHours? {
    // Both numbers must exist and be real minutes of a day.
    guard let start, let end,
          (0...1439).contains(start), (0...1439).contains(end) else { return nil }
    // Equal ends are an empty window: off.
    guard start != end else { return nil }
    return QuietHours(start: start, end: end)
}

/// Is this minute of the day inside the quiet window? `inQuietHours`.
func inQuietHours(_ mins: Int, _ quiet: QuietHours?) -> Bool {
    // No window (or an empty one) is never quiet.
    guard let quiet, quiet.start != quiet.end else { return false }
    // A window like 9:00 to 11:00 sits inside one day. One like 22:00 to 7:00
    // wraps past midnight, so it's "late evening OR early morning".
    return quiet.start < quiet.end
        ? mins >= quiet.start && mins < quiet.end
        : mins >= quiet.start || mins < quiet.end
}

/// Which kinds ring through quiet hours: only the pre-class alarm. You set
/// that one yourself for that morning's class; everything else is the app's
/// idea, so it waits. `survivesQuietHours`.
func survivesQuietHours(_ kind: ReminderKind) -> Bool {
    kind == .classAlarm
}

/// May this kind ring at minute `mins` under `quiet`? `mayFire`.
func mayFire(_ kind: ReminderKind, _ mins: Int, _ quiet: QuietHours?) -> Bool {
    survivesQuietHours(kind) || !inQuietHours(mins, quiet)
}

// MARK: - Snooze

/// The four ways to put a task down, in the order the buttons show them.
/// `SNOOZE_PRESETS`. `CaseIterable` gives `SnoozePreset.allCases` for the
/// buttons, and `Identifiable` lets `ForEach` loop over them.
enum SnoozePreset: String, CaseIterable, Identifiable {
    case oneHour = "1h", threeHours = "3h", evening, tomorrow

    var id: String { rawValue }

    /// The button's words.
    var label: String {
        switch self {
        case .oneHour:    "1 hour"
        case .threeHours: "3 hours"
        case .evening:    "This evening"
        case .tomorrow:   "Tomorrow"
        }
    }
}

/// The hour "This evening" lands on. `EVENING_HOUR`.
private let eveningHour = 18

/// The hour "Tomorrow" lands on. `MORNING_HOUR`. Also the hour of the daily
/// nudge on the phone (D-27), which is why it isn't private.
let morningHour = 8

/// When a snooze ends. `snoozeUntil` in the web. The two named presets are
/// clock times, not offsets: "Tomorrow" means tomorrow morning, so snoozing
/// at 2 AM doesn't buy twenty-two hours of silence nobody asked for.
func snoozeUntil(_ preset: SnoozePreset, _ now: Date) -> Date {
    switch preset {
    case .oneHour:
        return now.addingTimeInterval(3600)
    case .threeHours:
        return now.addingTimeInterval(3 * 3600)
    case .evening:
        // 6 PM today, or tomorrow's 6 PM once today's has gone.
        let today = atMinute(Calendar.current.startOfDay(for: now), eveningHour * 60)
        return today > now ? today : atMinute(scheduleDate(now, 1), eveningHour * 60)
    case .tomorrow:
        return atMinute(scheduleDate(now, 1), morningHour * 60)
    }
}

/// True while a snooze is still running. `isSnoozed`. Nothing about a
/// snoozed task may ring.
func isSnoozed(_ snoozedUntil: Date?, _ now: Date) -> Bool {
    guard let snoozedUntil else { return false }
    return snoozedUntil > now
}

// MARK: - Early warnings (lead times)

/// The furthest ahead an early warning may be: 14 days. Beyond that it stops
/// being a reminder and becomes a second deadline. `MAX_LEAD_MINUTES`.
let maxLeadMinutes = 20_160

/// One choice in the "Warn me early" picker.
struct LeadChoice: Identifiable {
    let minutes: Int
    let label: String
    var id: Int { minutes }
}

/// The picker's choices, longest first. `LEAD_CHOICES`.
let leadChoices = [
    LeadChoice(minutes: 10_080, label: "1 week"),
    LeadChoice(minutes: 4_320, label: "3 days"),
    LeadChoice(minutes: 2_880, label: "2 days"),
]

/// The ladder an exam gets when you haven't picked: 1 week, 3 days, 2 days.
/// Finding out about an exam the night before is a real loss, so exams warn
/// early by default. `EXAM_LEAD_MINUTES`.
let examLeadMinutes = [10_080, 4_320, 2_880]

/// A stored list of leads cleaned up: positive, at most 14 days, no repeats,
/// longest first. Nil when nothing usable is left, which means "not chosen".
/// `normalizeLeads`. (The web also throws out text; an `[Int]` can't hold any.)
func normalizeLeads(_ raw: [Int]) -> [Int]? {
    // A Set drops repeats; `sorted(by: >)` puts the longest first.
    let kept = Set(raw.filter { $0 > 0 && $0 <= maxLeadMinutes })
    return kept.isEmpty ? nil : kept.sorted(by: >)
}

/// The leads actually in force: what you chose, else the exam ladder for an
/// exam, else none. Never invents leads for ordinary work. `effectiveLeads`.
func effectiveLeads<T: Remindable>(_ task: T) -> [Int] {
    if let chosen = normalizeLeads(task.remindLeads) { return chosen }
    return task.kindName == "exam" ? examLeadMinutes : []
}

/// "1 week", "3 days", "3 hours", "45 min". `leadLabel`. Uses the picker's
/// own words when the number is one of its choices.
func leadLabel(_ minutes: Int) -> String {
    if let known = leadChoices.first(where: { $0.minutes == minutes }) {
        return known.label
    }
    // Whole days, then whole hours, then plain minutes.
    if minutes % 1440 == 0 {
        let d = minutes / 1440
        return "\(d) day\(d == 1 ? "" : "s")"
    }
    if minutes % 60 == 0 {
        let h = minutes / 60
        return "\(h) hour\(h == 1 ? "" : "s")"
    }
    return "\(minutes) min"
}

// MARK: - Windows

/// The daily nudge runs from 24 hours before the deadline. `NAG_WINDOW_MS`,
/// in seconds here, because `TimeInterval` (what `Date` maths uses) is seconds.
let nagWindow: TimeInterval = 24 * 3600

/// An early warning is still worth sending up to a day late, not more.
/// `LEAD_GRACE_MS`.
let leadGrace: TimeInterval = nagWindow

// MARK: - Dedupe keys

/// The id of one early warning: `task:<id>:lead:<minutes>@<yyyy-MM-dd>T<HHmm>`.
/// `leadKey`. The deadline is part of it, so moving a deadline re-arms its
/// warnings: a new date deserves a new heads-up.
func leadKey(_ taskID: String, _ lead: Int, _ deadline: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: deadline)
    let stamp = String(format: "%04d-%02d-%02dT%02d%02d",
                       c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    return "task:\(taskID):lead:\(lead)@\(stamp)"
}

/// The id of one day's nudge for one task: `task:<id>:<yyyy-MM-dd>`. The web
/// builds the same text inline in `dueReminders`. The day in it is what lets
/// an open task nudge again tomorrow.
func nagKey(_ taskID: String, _ day: String) -> String {
    "task:\(taskID):\(day)"
}

/// Is `key` still worth remembering as "already rang"? `keepFiredKey`.
/// Class and per-day keys die with their day. An early-warning key lives as
/// long as its task, because a one-shot must stay spent.
func keepFiredKey(_ key: String, _ dayKey: String, _ liveTaskIDs: Set<String>) -> Bool {
    // Class alarms and after-class nudges: today's only.
    if key.hasPrefix("class:") || key.hasPrefix("postclass:") {
        return key.hasSuffix(":\(dayKey)")
    }
    guard key.hasPrefix("task:") else { return false }
    let rest = String(key.dropFirst("task:".count))

    // An early warning: kept while its task exists. `range(of:)` finds where
    // ":lead:" starts, and everything before it is the task id.
    if let lead = rest.range(of: ":lead:") {
        return liveTaskIDs.contains(String(rest[..<lead.lowerBound]))
    }

    // A daily nudge: kept only today, and only for a live task. Ids never
    // contain ":", so the last ":" separates the id from the day. An old
    // `task:<id>` key with no day has no ":" left and ages out here.
    guard let sep = rest.lastIndex(of: ":") else { return false }
    return key.hasSuffix(":\(dayKey)") && liveTaskIDs.contains(String(rest[..<sep]))
}

// MARK: - Clock helper

/// The moment `mins` minutes after the start of `day`'s date, on the local
/// clock: atMinute(today, 480) is 8:00 AM today. Minutes past the end of the
/// day roll into the next one (1450 is 12:10 AM tomorrow), and negative ones
/// into the day before (-10 is 11:50 PM yesterday).
func atMinute(_ day: Date, _ mins: Int) -> Date {
    let cal = Calendar.current
    // Split into whole days and the minute within that day. Swift's `/`
    // rounds toward zero, so negative minutes need the "- 1439" to round down.
    let days = mins >= 0 ? mins / 1440 : (mins - 1439) / 1440
    let rest = mins - days * 1440
    // Step the calendar day, then build that day's clock time from its parts,
    // the same way Deadline.swift builds a deadline, so a daylight-saving
    // change can't move it by an hour.
    let base = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: day)) ?? day
    var c = cal.dateComponents([.year, .month, .day], from: base)
    c.hour = rest / 60
    c.minute = rest % 60
    return cal.date(from: c) ?? base
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/ReminderPlan.swift` (new file)

The heart of this phase. Read the `taskReminders` function slowly: each reminder has a *natural* moment (24 hours before, 8 AM, three days before), `settle` pushes it later for "not before now", a snooze and quiet hours, and then a limit drops it if it was pushed too far (an early warning more than a day late, a daily nudge past midnight).

```swift
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
/// it's a class alarm, in which case it waits for them to end. The web's loop
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
```

### 4.3 `~/ClassPing/Sources/ClassPing/Models+Reminders.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Reminders.swift
//  Phase:   7a (reminders ring)
//  Ports:   nothing new: it connects the models to Logic/Reminders.swift and
//           Logic/ReminderPlan.swift
//
//  Summary: Signs Course and Assignment up for the reminder logic. Both
//           already have every field the protocols ask for, so the
//           extensions are empty, like `extension Assignment: Dated {}`.
//

import Foundation

/// Course has a name, `alarm`, `remindBefore` and `archived`, plus the
/// meetings `Schedulable` already covers, so the planner can read it.
extension Course: Alarmable {}

/// Assignment has `id`, `reminder`, `done`, `remindLeads` and
/// `snoozedUntil`, and is already `TaskListable` (Assignment+TaskView.swift).
extension Assignment: Remindable {}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Notifications.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Notifications.swift
//  Phase:   7a (reminders ring)
//  Ports:   lib/notifications.ts (permission, showing a notification) and the
//           bookkeeping of the reminder loop in lib/store.tsx (the fired map)
//
//  Summary: Hands the reminder plan to iOS. Each sync works out what has
//           already rung, builds the plan, and replaces iOS's list of waiting
//           notifications with it. Also asks for permission, once.
//           ClassPingApp.swift decides when to sync.
//

import Foundation
import UserNotifications

/// Whether ClassPing may show notifications, in the three states a screen
/// needs. iOS has a few more; `notificationAccess()` folds them into these.
enum NotificationAccess {
    case notAsked   // iOS hasn't asked you yet
    case allowed
    case blocked    // you said no, or turned them off in the Settings app
}

extension Store {
    /// Everything the plan is built from. When any of it changes, the app
    /// rebuilds the plan: `ReminderSync` in ClassPingApp.swift watches it.
    struct ReminderInputs: Equatable {
        var courses: [Course]
        var assignments: [Assignment]
        var postClass: Bool
        var quietStart: Int?
        var quietEnd: Int?
    }

    /// The live classes and assignments plus the two reminder settings.
    var reminderInputs: ReminderInputs {
        ReminderInputs(courses: liveCourses, assignments: liveAssignments,
                       postClass: profile.postClassNudge,
                       quietStart: profile.quietStart, quietEnd: profile.quietEnd)
    }

    // MARK: Permission

    /// What iOS currently allows, without asking anything.
    /// `async` because the answer comes from iOS's own notification service;
    /// `await` pauses here until it replies, without freezing the screen.
    func notificationAccess() async -> NotificationAccess {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied:        return .blocked
        default:             return .allowed   // authorized, provisional, ephemeral
        }
    }

    /// Asks for permission if iOS hasn't asked yet, then says whether
    /// notifications may show. iOS draws its own Allow / Don't Allow box, and
    /// only ever once: after that it remembers the answer, and only the
    /// Settings app can change it. `ensureNotificationPermission` on the web.
    func requestNotificationAccess() async -> Bool {
        switch await notificationAccess() {
        case .allowed:
            return true
        case .blocked:
            return false
        case .notAsked:
            // `requestAuthorization` can throw; `try?` turns a failure into
            // nil, and `?? false` turns nil into a plain "no".
            let center = UNUserNotificationCenter.current()
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    // MARK: Keeping iOS up to date

    /// Where the bookkeeping is kept. `UserDefaults` is a small key-value
    /// store that belongs to this app on this phone (the `@AppStorage` from
    /// 4b is built on it). Like the web's localStorage, it never syncs.
    private static let firedKey = "classping.reminders.fired"
    private static let scheduledKey = "classping.reminders.scheduled"

    /// Rebuilds the plan and hands it to iOS. Safe to call as often as you
    /// like: each call replaces the whole waiting list, and a reminder's id
    /// stops it ringing twice. The web's 30-second loop, done once per change.
    func syncReminders() async {
        let now = Date.now
        let defaults = UserDefaults.standard

        // 1. What has rung since last time: the last plan's one-offs whose
        //    moment has passed, on top of what was already known.
        //    `as? [String: Double]` reads the saved dictionary back as the
        //    type it was saved as, or gives nil (then `?? [:]`, an empty one).
        let oldFired = Set(defaults.stringArray(forKey: Store.firedKey) ?? [])
        let oldTimes = defaults.dictionary(forKey: Store.scheduledKey) as? [String: Double] ?? [:]
        let scheduled = oldTimes.mapValues { Date(timeIntervalSince1970: $0) }
        let liveIDs = Set(liveAssignments.map { $0.id.uuidString })
        let fired = settledFired(oldFired, scheduled: scheduled, now: now, liveTaskIDs: liveIDs)

        // 2. What should ring from now on.
        let quiet = normalizeQuietHours(start: profile.quietStart, end: profile.quietEnd)
        let plan = reminderPlan(courses: liveCourses, tasks: liveAssignments,
                                postClass: profile.postClassNudge, quiet: quiet,
                                fired: fired, now: now)

        // 3. Permission, asked the first time there is something to ring (D-30).
        var allowed = false
        if !plan.isEmpty {
            allowed = await requestNotificationAccess()
        }
        // While iOS was asking, something may have changed and started a newer
        // sync (`.task(id:)` cancels this one when it does). Let that one finish.
        guard !Task.isCancelled else { return }

        // 4. Write down what's about to go to iOS before it goes, so even if
        //    this is interrupted nothing can ring twice. Only one-offs are
        //    recorded; a weekly reminder never finishes.
        var times: [String: Double] = [:]
        if allowed {
            for r in plan {
                if case .once(let date) = r.timing {
                    times[r.id] = date.timeIntervalSince1970
                }
            }
        }
        defaults.set(Array(fired), forKey: Store.firedKey)
        defaults.set(times, forKey: Store.scheduledKey)

        // 5. Replace iOS's waiting list with the new plan.
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard allowed else { return }
        for r in plan {
            // `try?`: one that fails to schedule is skipped; the next sync
            // tries again.
            try? await center.add(notificationRequest(for: r))
        }
    }

    /// One planned reminder as an iOS notification request: what it says,
    /// and when it rings.
    private func notificationRequest(for r: PlannedReminder) -> UNNotificationRequest {
        // What the notification shows.
        let content = UNMutableNotificationContent()
        content.title = r.title
        content.body = r.body
        content.sound = .default
        // Groups ClassPing's notifications by kind in Notification Center.
        content.threadIdentifier = r.kind.rawValue
        // Details a tap can read later (Phase 7c opens the right screen).
        content.userInfo = ["kind": r.kind.rawValue,
                            "course": r.courseID?.uuidString ?? "",
                            "assignment": r.assignmentID?.uuidString ?? ""]
        return UNNotificationRequest(identifier: r.id, content: content,
                                     trigger: trigger(for: r.timing))
    }

    /// When it rings, as an iOS trigger. A calendar trigger names a clock time
    /// ("Monday 9:45 AM"), so it still rings at 9:45 after a daylight-saving
    /// change or in another time zone: a ClassPing time is always local time.
    /// Nil means "right away".
    private func trigger(for timing: ReminderTiming) -> UNNotificationTrigger? {
        let cal = Calendar.current
        switch timing {
        case .once(let date):
            // Already due (a catch-up): no trigger, so iOS shows it at once.
            // Compared with the clock now, not when the plan was made: the
            // permission box may have been open for a while.
            guard date > Date.now.addingTimeInterval(1) else { return nil }
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        case .weekly(let first):
            // Only weekday, hour and minute: iOS rings each time all three
            // match, which is once a week. The calendar gives Apple's weekday
            // number (1 = Sunday) itself, so nothing converts days by hand.
            let parts = cal.dateComponents([.weekday, .hour, .minute], from: first)
            return UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        }
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/ClassPingApp.swift` (replaces the file)

The `init`, the `notificationDelegate` property, the `.modifier(ReminderSync())` line and everything below the `App` are new.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   0 (housekeeping), changed in 7a (reminders)
//  Ports:   app/layout.tsx (the root that wraps every screen), and when the
//           reminder loop in lib/store.tsx runs
//
//  Summary: The app's entry point. It creates the one Store the whole app
//           shares and hands it to every screen through the SwiftUI
//           environment. Since 7a it also keeps iOS's reminders in step with
//           the store, and lets them show while the app is open.
//
import SwiftUI
import UserNotifications   // NEW in Phase 7a

/// @main marks where the app starts, similar to the root layout in the web app
@main
struct ClassPingApp: App {
    /// The app's single store. `@State` keeps the same Store alive for as long as
    /// the app runs, instead of making a new one every time SwiftUI redraws.
    // CHANGED in Phase 1: load what's saved on the phone instead of always the sample.
    @State private var store = Store.load()

    /// NEW in Phase 7a: the object iOS asks before showing a notification
    /// while the app is open. iOS only holds on to it weakly (it won't keep
    /// it alive by itself), so the app keeps it here for as long as it runs.
    private let notificationDelegate = NotificationDelegate()

    /// NEW in Phase 7a: runs once, as the app starts, so the delegate is in
    /// place before any notification can arrive.
    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            // `.environment(store)` puts the store where any screen below can ask for it
            // with `@Environment(Store.self)`. In the web app this is the
            // <StoreProvider> in lib/store.tsx.
            // CHANGED in Phase 7a: `.modifier(ReminderSync())` keeps the
            // reminders up to date. It sits inside `.environment(store)`, so
            // it can read the store too.
            RootView()
                .modifier(ReminderSync())
                .environment(store)
        }
    }
}

/// Rebuilds the reminder plan when the app starts, whenever your classes,
/// work or reminder settings change, and whenever the app comes back to the
/// screen. The web runs its check every 30 seconds while a tab is open; the
/// phone only needs to when something changed. A `ViewModifier`, like 4b's
/// Undo bar, because it needs the environment and a piece of state.
// NEW in Phase 7a
private struct ReminderSync: ViewModifier {
    @Environment(Store.self) private var store

    /// Whether the app is on screen (`.active`), half-covered (`.inactive`,
    /// say while Notification Center is pulled down) or in the background.
    /// SwiftUI keeps it up to date.
    @Environment(\.scenePhase) private var scenePhase

    /// How many times the app has come back to the screen. Each return bumps
    /// it, which re-runs the sync: a new day's nudges get planned, and what
    /// rang in the meantime is crossed off.
    @State private var wakeUps = 0

    func body(content: Content) -> some View {
        content
            // `.task(id:)` (4b) runs this when the app starts, and again,
            // cancelling the old run first, every time the id changes.
            .task(id: Trigger(inputs: store.reminderInputs, wakeUps: wakeUps)) {
                // Wait a moment, so a burst of quick edits (ticking off three
                // tasks) makes one sync, not three. A newer edit cancels the
                // wait; `try?` ignores that cancellation, and the guard stops.
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await store.syncReminders()
            }
            // Count each return to the screen.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { wakeUps += 1 }
            }
    }

    /// What the sync watches: the store's reminder inputs plus the wake-up
    /// count. Equatable, so `.task(id:)` can tell when it changed.
    private struct Trigger: Equatable {
        let inputs: Store.ReminderInputs
        let wakeUps: Int
    }
}

/// Lets reminders show while ClassPing is open. Without it, iOS stays silent
/// about a notification that arrives while you're in the app (the web shows
/// them while it's open, the only time it can). A delegate is an object iOS
/// calls back with "this is happening, what should I do?". `NSObject` is the
/// base class Apple's older callback-based frameworks expect.
// NEW in Phase 7a
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// A notification is arriving with the app on screen: show it anyway, as
    /// a banner with its sound, and keep it in Notification Center.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Profile/RemindersSection.swift` (new file, in a new `Profile` folder)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/RemindersSection.swift
//  Phase:   7a (reminders ring)
//  Ports:   the Reminders card of app/settings/page.tsx (the after-class
//           nudge) and components/QuietHours.tsx (QuietHoursRow)
//
//  Summary: The Reminders card in the Profile tab: whether iOS lets ClassPing
//           ring at all (with a way to fix it), the after-class nudge switch,
//           and quiet hours with their two times. Changes save through
//           ProfileView, which saves whenever the profile changes.
//

import SwiftUI
import UIKit   // for the address of the Settings app's notification page

struct RemindersSection: View {
    @Environment(Store.self) private var store

    /// Opens a link: here, the Settings app on ClassPing's own page.
    @Environment(\.openURL) private var openURL

    /// On screen or not. Read so the card can ask iOS again when you come
    /// back from the Settings app.
    @Environment(\.scenePhase) private var scenePhase

    /// What iOS says about notifications, or nil until it has answered.
    @State private var access: NotificationAccess? = nil

    var body: some View {
        // `@Bindable` lets the switch write straight into the store (Phase 3).
        @Bindable var store = store
        let quiet = normalizeQuietHours(start: store.profile.quietStart,
                                        end: store.profile.quietEnd)

        VStack(alignment: .leading, spacing: 14) {
            Text("REMINDERS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)

            // MARK: Permission
            accessNotice

            // MARK: After-class nudge
            row("bell.fill", "After-class nudge",
                "When a class ends, we'll ask if it came with an assignment, so you log it before you forget.") {
                Toggle("After-class nudge", isOn: $store.profile.postClassNudge)
                    .labelsHidden()
            }
            footnote(store.profile.postClassNudge
                     ? "On, the moment a class ends, even when ClassPing is closed."
                     : "Off, no reminder when a class ends.")

            Divider()

            // MARK: Quiet hours
            row("moon.fill", "Quiet hours",
                "Hold reminders overnight. A class alarm still rings, you set that one yourself.") {
                Toggle("Quiet hours", isOn: quietOn)
                    .labelsHidden()
            }
            // The two times, only while quiet hours are on.
            if let quiet {
                HStack(alignment: .bottom, spacing: 12) {
                    timeBox("From", quiet.start) { setQuiet(start: $0) }
                    Text("to")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                        .padding(.bottom, 8)
                    timeBox("Until", quiet.end) { setQuiet(end: $0) }
                }
                .padding(.leading, 48)
            }
            // The line under it. `TimelineView` (5a) redraws it every minute,
            // so "Quiet now" switches on and off by itself.
            TimelineView(.everyMinute) { context in
                footnote(quietSummary(quiet, context.date))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // Ask iOS when the card appears, and again each time the app comes
        // back, in case you just changed it in Settings. `.task(id:)` re-runs
        // whenever `scenePhase` changes.
        .task(id: scenePhase) {
            access = await store.notificationAccess()
        }
    }

    // MARK: - Pieces

    /// What to say when iOS won't ring for ClassPing, or hasn't asked yet.
    /// Nothing at all once notifications are allowed. `@ViewBuilder` lets one
    /// property hand back different views from different `switch` cases.
    @ViewBuilder private var accessNotice: some View {
        switch access {
        case .blocked:
            notice("Notifications are off for ClassPing, so nothing can ring. Turn them on in Settings.",
                   button: "Open Settings") {
                // The Settings app's page for this app's notifications.
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
        case .notAsked:
            notice("ClassPing needs your OK before it can ring for classes and deadlines.",
                   button: "Allow notifications") {
                // A button's action can't wait, so `Task { }` starts a piece
                // of async work that runs on its own: ask iOS, read the answer
                // back for this card, then plan the reminders.
                Task {
                    _ = await store.requestNotificationAccess()
                    access = await store.notificationAccess()
                    await store.syncReminders()
                }
            }
        case .allowed, nil:
            EmptyView()
        }
    }

    /// The switch for quiet hours, as a true/false binding (`Binding(get:set:)`
    /// from 5b). On writes the default 10 PM to 7 AM window; off clears both
    /// times, which is how "off" is stored on the web too.
    private var quietOn: Binding<Bool> {
        Binding(
            get: {
                normalizeQuietHours(start: store.profile.quietStart,
                                    end: store.profile.quietEnd) != nil
            },
            set: { on in
                store.profile.quietStart = on ? defaultQuietHours.start : nil
                store.profile.quietEnd = on ? defaultQuietHours.end : nil
            })
    }

    /// Moves one end of the window. Two equal ends would be an empty window,
    /// which means "off", so the end moves on a minute instead of the whole
    /// feature switching off under you. `setEnd` in QuietHours.tsx.
    private func setQuiet(start: Int? = nil, end: Int? = nil) {
        guard var next = normalizeQuietHours(start: store.profile.quietStart,
                                             end: store.profile.quietEnd) else { return }
        if let start { next.start = start }
        if let end { next.end = end }
        if next.start == next.end { next.end = (next.end + 1) % 1440 }
        store.profile.quietStart = next.start
        store.profile.quietEnd = next.end
    }

    /// The line under quiet hours. Same three sentences as the web.
    private func quietSummary(_ quiet: QuietHours?, _ now: Date) -> String {
        guard let quiet else { return "Off, reminders can arrive at any hour." }
        if inQuietHours(minuteOfDay(now), quiet) {
            return "Quiet now, nudges resume at \(fmtTime(quiet.end))."
        }
        return "On, nothing between \(fmtTime(quiet.start)) and \(fmtTime(quiet.end)), except a class alarm."
    }

    /// One setting: a soft brand tile with a symbol, a title and a sentence,
    /// and its control on the right. `<Control: View>` lets the caller pass
    /// any view as the control (here, always a Toggle).
    private func row<Control: View>(_ symbol: String, _ title: String, _ text: String,
                                    @ViewBuilder control: () -> Control) -> some View {
        let accent = store.profile.accent
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 36, height: 36)
                .background(Theme.brandSoft(accent),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control()
        }
    }

    /// One end of the quiet window: a small label over a time picker. The
    /// picker wants a Date, the profile stores minutes, so the binding
    /// converts both ways: minutes to today at that time, and back.
    private func timeBox(_ label: String, _ minutes: Int,
                         _ set: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            DatePicker(label,
                       selection: Binding(get: { atMinute(.now, minutes) },
                                          set: { set(minuteOfDay($0)) }),
                       displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    /// The small grey line under a setting.
    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A tinted box with a sentence and one button, for the permission states.
    private func notice(_ text: String, button: String,
                        action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(button, action: action)
                .font(.system(size: 13.5, weight: .semibold))
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (replaces the file)

Three touched spots: the header, the new `RemindersSection()` card under Appearance, and the "Reminders and quiet hours" line gone from the coming-soon list.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card)
//  Ports:   the profile card and the Appearance / App color sections of
//           app/settings/page.tsx, moved into their own tab (D-19)
//
//  Summary: The Profile tab. For now: your avatar and name, the Appearance
//           card (moved here from Today), the Reminders card, and a list of
//           what arrives in this tab later. Phase 11 builds the full
//           settings, Phase 12 your level.
//

import SwiftUI

struct ProfileView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` lets the pickers write into the store (Phase 3).
        @Bindable var store = store
        let accent = store.profile.accent

        ScrollView {
            VStack(spacing: 16) {
                // Surface a failed local save beside the controls that caused it.
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                // MARK: You
                VStack(spacing: 10) {
                    AvatarBadge(name: store.profile.username, size: 84, accent: accent)
                    Text(store.profile.username.isEmpty ? "Your profile" : store.profile.username)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Your level, streak and trophies are coming soon.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .cardStyle()

                // MARK: Appearance
                // Moved from Today's temporary card (Phase 3). Phase 11 turns
                // this into the full Appearance section of the settings.
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("APPEARANCE")
                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)

                    Picker("App color", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // MARK: Reminders
                // NEW in Phase 7a: the after-class nudge and quiet hours.
                RemindersSection()

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    comingRow("graduationcap", "Grades & GPA")
                    // CHANGED in Phase 7a: the "Reminders and quiet hours" row
                    // is gone; it's the card above now.
                    comingRow("calendar", "Semester, backups, Recently Deleted")
                    comingRow("person.crop.circle", "Your name, photo and account")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Profile")
        // Save whenever a profile field changes, so the choice survives a
        // relaunch. CHANGED in Phase 5a: this moved here from TodayView.
        .onChange(of: store.profile) { store.save() }
    }

    /// The small spaced-out caps over each card, like the web's section labels.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// One upcoming feature, shown as a label until its screen is available.
    private func comingRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.faint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }
}

/// A round avatar: the first letter of your name on the brand gradient, or a
/// person symbol before you've set a name. The tab bar uses a small one, the
/// Profile tab a big one. Phase 11 adds your photo; Phase 12 the pet-tier ring.
struct AvatarBadge: View {
    let name: String
    let size: CGFloat
    let accent: Profile.Accent

    var body: some View {
        ZStack {
            Circle().fill(Theme.brandGradient(accent))
            // `.first` is the name's first character, or nil for an empty name.
            if let initial = name.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        // The tab's own label says "Profile", so VoiceOver skips the picture.
        .accessibilityHidden(true)
    }
}
```

### 4.8 `~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift` (replaces the file)

Only the header's Phase line and the reminder footer change (marked `CHANGED in Phase 7a`).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift
//  Phase:   5b (classes: add and edit), changed in 7a (the reminder footer)
//  Ports:   components/ClassForm.tsx, app/class/new/page.tsx and
//           app/class/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new class, and for editing one. Only a name is
//           required. A class meets at one or more times (MeetingFields), or
//           "Schedule not known yet" saves it with no times. New classes can
//           be saved one after another with "Save & add another".
//

import SwiftUI

struct CourseFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The class being edited, or nil for a new one.
    let editing: Course?

    /// What to do after Save. The Add menu passes "close the whole sheet";
    /// when nil, the form closes itself with `dismiss()`.
    let onFinish: (() -> Void)?

    // MARK: Form state
    // The form's own scratch copy of every field (the 4a pattern): nothing
    // reaches the store until Save.
    @State private var name: String
    @State private var unscheduled: Bool        // "Schedule not known yet"
    @State private var meetings: [ClassMeeting] // main meeting first
    @State private var color: SubjectColor
    @State private var instructor: String
    @State private var credits: String          // text, so it can be left empty
    @State private var notes: String
    @State private var alarm: Bool              // the pre-class reminder
    @State private var remindBefore: Int        // minutes before class
    @State private var problem: String? = nil   // what stopped the last Save
    @State private var added: String? = nil     // "Biology added. Ready for the next class."
    /// Keep a new class's identity across a failed save, so Retry updates the
    /// in-memory copy instead of adding a duplicate.
    @State private var draftID = UUID()

    /// Starting values, from the class being edited or the web's defaults for
    /// a new one (indigo, a 15-minute reminder, one empty meeting).
    init(editing: Course? = nil, onFinish: (() -> Void)? = nil) {
        self.editing = editing
        self.onFinish = onFinish
        _name = State(initialValue: editing?.name ?? "")
        // `.map` on an optional runs only when there is a value.
        _unscheduled = State(initialValue: editing.map { isUnscheduled($0) } ?? false)
        _meetings = State(initialValue: editing.map { classMeetings($0) } ?? [newMeeting(primaryMeetingID)])
        _color = State(initialValue: editing?.color ?? .indigo)
        _instructor = State(initialValue: editing?.instructor ?? "")
        _credits = State(initialValue: editing?.credits.map(creditText) ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _alarm = State(initialValue: editing?.alarm ?? true)
        _remindBefore = State(initialValue: editing?.remindBefore ?? 15)
    }

    var body: some View {
        let accent = store.profile.accent

        Form {
            // After "Save & add another": a quiet confirmation at the top.
            if let added {
                Section {
                    Text(added)
                        .foregroundStyle(Theme.brand(accent))
                }
            }

            // MARK: Name
            Section {
                TextField("e.g. Biology", text: $name)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Class name (required)")
            }

            // MARK: When it meets
            Section {
                Toggle(isOn: $unscheduled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schedule not known yet")
                        Text("Add the subject now and set its meeting times later.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                if unscheduled {
                    Text("No meeting times yet. Add them with Edit once you have your timetable; this subject is ready for tasks, notes and grades in the meantime.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            // `$meetings` hands MeetingFields a binding to the whole list.
            if !unscheduled {
                MeetingFields(meetings: $meetings, accent: accent)
            }

            // MARK: More details
            Section("More details (optional)") {
                TextField("Teacher", text: $instructor)
                TextField("Credit hours", text: $credits)
                    .keyboardType(.decimalPad)
                TextField("Notes: office hours, what to bring…", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Subject color") {
                colorRow
            }

            // MARK: Reminder
            Section {
                Toggle("Pre-class reminder", isOn: $alarm)
                Picker("Remind me before class", selection: $remindBefore) {
                    ForEach(remindChoices, id: \.self) { mins in
                        Text("\(mins) minutes").tag(mins)
                    }
                }
            } footer: {
                // CHANGED in Phase 7a: the alarm really rings now. The web
                // form says the same, minus its "More details" pointer.
                Text(alarm
                     ? "Reminder: \(remindBefore) minutes before each meeting. It rings even in quiet hours."
                     : "Pre-class reminders are off.")
            }

            // What's wrong, in the web's words.
            if let problem {
                Section {
                    Text(problem)
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            // A timetable is usually typed in one class after another.
            if editing == nil {
                Section {
                    Button("Save & add another") { save(another: true) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(editing == nil ? "New Class" : "Edit Class")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(another: false) }
            }
        }
        // The web's length caps: 200 for the name, 1000 for the notes.
        .onChange(of: name) {
            if name.count > 200 { name = String(name.prefix(200)) }
        }
        .onChange(of: notes) {
            if notes.count > 1000 { notes = String(notes.prefix(1000)) }
        }
    }

    // MARK: - Pieces

    /// The nine colors as round swatches; the picked one gets a ring.
    /// `ColorPicker.tsx` on the web.
    private var colorRow: some View {
        HStack(spacing: 0) {
            ForEach(SubjectColor.allCases, id: \.self) { c in
                Button {
                    color = c
                } label: {
                    Circle()
                        .fill(Theme.subject(c))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Theme.ink, lineWidth: 2)
                                .padding(-4)
                                .opacity(color == c ? 0.8 : 0)
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(c.rawValue.capitalized)
                .accessibilityAddTraits(color == c ? .isSelected : [])
            }
        }
    }

    /// The reminder choices: 10, 15, 30 and 60 minutes, plus whatever the class
    /// already uses, in order. A `Set` drops the duplicate when it's one of those.
    private var remindChoices: [Int] {
        Set([10, 15, 30, 60, remindBefore]).sorted()
    }

    // MARK: - Saving

    /// What stops Save, in the web form's order, or nil when it can go ahead.
    private func validationProblem(_ cleanName: String, _ creditInput: String) -> String? {
        if cleanName.isEmpty { return "Enter a class name." }
        // Meeting times only matter when the class has a schedule.
        if !unscheduled, let meetingProblem = meetingError(meetings) {
            return meetingProblem
        }
        if !creditInput.isEmpty {
            // `Double("abc")` is nil; a real number must also be above zero.
            guard let value = Double(creditInput), value.isFinite, value > 0 else {
                return "Credit hours must be greater than zero, or left empty."
            }
        }
        return nil
    }

    /// Checks the fields, builds the class and hands it to the store.
    /// `save` in components/ClassForm.tsx.
    private func save(another: Bool) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let creditInput = credits.trimmingCharacters(in: .whitespaces)
        problem = validationProblem(cleanName, creditInput)
        guard problem == nil else { return }

        // Tidy every meeting: a blank room or label is stored as nothing.
        let tidy = meetings.map { m in
            var t = m
            t.room = cleaned(m.room)
            t.label = cleaned(m.label)
            return t
        }
        // The main meeting lives on the class itself; the rest are extras.
        let main = tidy.first ?? newMeeting(primaryMeetingID)

        // Start from the class being edited, so fields this form doesn't show
        // (extra reminders, term, goal, feed ids...) survive the edit.
        var c = editing ?? Course(name: "", short: "", color: .indigo,
                                  days: [], startMin: 600, endMin: 660)
        if editing == nil { c.id = draftID }
        c.name = cleanName
        c.short = shortCode(cleanName)
        c.color = color
        // "Schedule not known yet" stores no days at all: every schedule
        // screen skips the class, but it's there for tasks, notes and grades.
        c.days = unscheduled ? [] : main.days
        c.startMin = main.start
        c.endMin = main.end
        c.room = unscheduled ? nil : main.room
        c.additionalMeetings = unscheduled ? [] : Array(tidy.dropFirst())
        c.instructor = cleaned(instructor)
        c.credits = Double(creditInput)
        c.notes = cleaned(notes)
        c.remindBefore = remindBefore
        c.alarm = alarm

        // New or edited: the store saves to the phone either way.
        if editing == nil && store.course(c.id) == nil {
            store.addCourse(c)
        } else {
            store.updateCourse(c)
        }

        // Keep the draft and its identity available until the local write works.
        guard !store.lastSaveFailed else {
            added = nil
            problem = "Couldn't save on this device. Keep this form open and try Save again."
            return
        }

        if another {
            // Clear the subject's own fields; the reminder choice carries over
            // to the next class, which is the point of typing a timetable in a row.
            name = ""
            draftID = UUID()
            unscheduled = false
            meetings = [newMeeting(primaryMeetingID)]
            color = .indigo
            instructor = ""
            credits = ""
            notes = ""
            added = "\(cleanName) added. Ready for the next class."
        } else if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

// MARK: - Helpers

/// The short code on grid blocks: the name's first word, at most 5 letters
/// ("Calculus III" -> "Calcu"). The web works it out on every save the same way.
private func shortCode(_ name: String) -> String {
    let firstWord = name.split(whereSeparator: { $0.isWhitespace }).first ?? ""
    return String(firstWord.prefix(5))
}

/// Trimmed text, or nil when nothing is left.
private func cleaned(_ text: String?) -> String? {
    let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
}

/// 3.0 -> "3", 1.5 -> "1.5", for showing stored credits in the text field.
private func creditText(_ value: Double) -> String {
    // Double's text round-trips without locale-dependent separators or Int overflow.
    let text = String(value)
    return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
}
```

### Not typed: the tests

`RemindersTests.swift` and `ReminderPlanTests.swift` are in `docs/ios/reference/Tests/Logic/`. To run them with your own `scripts/test-logic.sh`, copy both into `~/ClassPing/Tests/Logic/`:

```bash
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/Reminder*.swift ~/ClassPing/Tests/Logic/
bash scripts/test-logic.sh
```

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 7a: reminders ring (class alarms, after-class nudge, daily nudges, quiet hours)"
```

On the phone:

1. The app opens and iOS asks to send notifications. Tap **Allow**. If you have overdue work with its reminder on, an **Overdue** banner may arrive straight away: today's nudge hadn't rung yet, so it rings now, as the web would. It won't ring again today.
2. **Profile** tab: the **Reminders** card. Switch **Quiet hours** on: From 10:00 PM, Until 7:00 AM, and the line underneath reads "On, nothing between 10:00 PM and 7:00 AM, except a class alarm." Switch it off again for the next steps.
3. **A class alarm, for real.** **+ → Class**: name "Ping test", today's weekday only, starting about 13 minutes from now and ending 5 minutes after that, reminder **10 minutes**. Save, go to the Home Screen and lock the phone. About 3 minutes later: "Ping test starts at …, That's in 10 minutes." When the class ends: "Ping test just ended."
4. **A daily nudge.** **+ → Assignment**: "Ping task", due today with a time 2 hours from now, Daily reminder on, Save. Within a second or so: **Due in 24 hours · Ping task, tap ✓ when it's done.** (The window was already open, so it rings at once.)
5. **Quiet hours hold it.** Switch quiet hours on and set **From** to a minute ago and **Until** to 30 minutes from now: the line says "Quiet now, nudges resume at …". Add another assignment due in 2 hours: no banner. Switch quiet hours off: the banner arrives.
6. **Permission off.** Settings app → Notifications → ClassPing → Allow Notifications off. Back in ClassPing, the Reminders card says notifications are off, with **Open Settings**. Tap it, switch them back on, come back: the notice is gone.
7. Delete "Ping test" (Today → My Classes → trash) and the two test assignments.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] iOS asked for permission once, and the Reminders card matches what iOS says.
- [ ] A class alarm rings before class with the phone locked, and the after-class nudge rings when it ends; with **After-class nudge** off, only the alarm rings.
- [ ] A dated assignment with its reminder on nudges inside its last 24 hours, with the app open (a banner) or closed.
- [ ] Quiet hours hold a nudge until they end, but not a class alarm.
- [ ] An undated or completed assignment never rings.

## 7. If it breaks

- **`type 'Course' does not conform to protocol 'Alarmable'`** (or Assignment / `Remindable`): a property name in the protocol doesn't match the model's exactly (`remindBefore`, `snoozedUntil`, `remindLeads`), or 4.3 is missing.
- **`cannot find type 'TaskListable' in scope`**: Reminders.swift builds on the protocol from Phase 4b's `Logic/TaskView.swift`; check the spelling there.
- **No banner while the app is open, but notifications arrive when it's closed:** the delegate. Either `UNUserNotificationCenter.current().delegate = notificationDelegate` is missing from `init`, or the `willPresent` method name or labels differ by a letter. Every method of that protocol is optional, so a typo builds fine and is simply never called.
- **Nothing ever rings:** look at the Reminders card first. If it says notifications are off, that's it. If not: check Focus / Do Not Disturb, and that the class has **Pre-class reminder** on and today's weekday ticked. Classes that are archived, or have no set schedule, never ring.
- **`Expression is 'async' but is not marked with 'await'`**: a call to an `async` function (`syncReminders`, `notificationAccess`, `requestNotificationAccess`) without `await` in front.
- **`'async' call in a function that does not support concurrency`** (in RemindersSection): the button's code isn't wrapped in `Task { ... }`.
- **A reminder rings twice:** the two `defaults.set(...)` lines in `syncReminders` must run before `removeAllPendingNotificationRequests()`, not after the `for` loop.

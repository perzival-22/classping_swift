---
title: "Phase 10a: The study timer"
date: 2026-10-20
---

# Phase 10a: The study timer

First of two parts of Phase 10. This one is the timer: one block or
Pomodoro, an alert at the end of every block, and every finished focus block
recorded. **10b** adds the ambient sound, after I test background audio in a
throwaway project (D-63).

It builds on your commit `4108db2` (the finals card fix). Your Sources match
the reference; the only difference was your own comments in
`FinalsCountdown.swift`, which the reference now uses. On 2026-10-20 you
confirmed on the phone: Done over the keyboard on every field, and Clear
staying cleared after a full close. I checked the save file on your phone
too: it matches the screen.

**Start here:** make the folder `Sources/ClassPing/Screens/Study/`, then type
the seven files in section 4, in order. Three are new and four replace files
you have. Then copy the two test files from 4.8. No script changes.

**Verification (2026-10-20):** the reference iOS build passed with no
warnings. 392/392 logic tests passed (default zone and America/New_York; +21
in the new StudyTests) and 70/70 reference store tests (+3 in the new
StudyStoreTests). Your own logic and store suites plus the two new test files
passed 392/392 and 82/82 against the new source in disposable packages. The
seven guide blocks laid over your 4108db2 tree are identical to the reference,
and that tree built with no warnings. The "web:" cases are the web's own
output (node 24). On the web, D-61: 1084/1084 unit tests with
TZ=America/New_York, eslint and tsc clean. No 10a phone check has happened
yet.

## 1. Goal

Start studying from a task, run one block or a Pomodoro, and get told when
each block ends, even with the phone locked in your pocket.

**On your phone:** open an assignment and tap **Start studying**, next to
Complete. Pick 25 minutes (or Pomodoro, 4 rounds) and tap **Start**. A ring
counts down. Lock the phone: when the block ends, an alert says "Session
complete, 25 min on "Essay". Nice work." Back in the app, the sheet shows 🎉,
and the task's **Focused** row says "25 min recorded".

This part includes:

- **Setup:** One block (15, 25, 45, 60, or any number up to 240) or Pomodoro
  (a focus length and 2, 3, 4 or 6 rounds), with the web's "4 × 25 min, 5 min
  breaks, 1h 55m in all" line.
- **Running:** round dots, a ring that fills (green during a break), the time
  left, **Pause** / **Resume**, **Stop**, and **Focus mode**.
- **Done:** **Mark it done** (while the task is open), **Another session**,
  **Close**.
- **Alerts** at the end of every block, in the web's words ("Break time",
  "Round 2 of 4", "Long break", "Session complete"). You chose this
  (2026-10-20).
- **Every finished focus block is recorded,** at the moment it ended, so the
  Focused row and the exam prep card's minutes (7b) finally count something.
- **A fix to 7a's reminder sync,** which would have deleted these alerts (see
  section 3).

Not in 10a: the sound picker (10b) and XP. The web pays XP per focus minute
and for finishing from a block; XP comes with Phase 12, and the sessions it
needs are being recorded from now on.

## 2. New Swift concepts

### An enum as a screen's state

The timer is always in exactly one of four states, and three of them carry a
running session with them:

```swift
private enum Phase: Equatable {
    case setup
    case running(StudyRun)
    case paused(StudyRun)
    case done(StudyRun)
}

switch phase {
case .setup:            StudySetupView(...)
case .running(let run): TimelineView(...) { context in live(run, at: context.date) }
case .paused(let run):  face(run, ...)
case .done(let run):    finished(run)
}

if case .running(let run) = phase { ... }   // one case, and its value
```

You've used `switch` on enums since Phase 1 and an enum with a value for
5b's sheet. What's new is using one as the whole screen's state: a paused
session can't be missing its run, and setup can't accidentally have one.
`if case` tests a single case and unpacks it, without a full `switch`.

### A trimmed shape

`trim(from:to:)` draws only part of a shape's outline. The ring is a grey
circle with the same circle on top, trimmed to the share of the block that's
gone:

```swift
Circle().stroke(Theme.surface2, lineWidth: 11)
Circle()
    .trim(from: 0, to: gone)                       // 0.25 = a quarter
    .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
    .rotationEffect(.degrees(-90))                 // start at twelve o'clock
```

A circle's outline starts at three o'clock, which is why it's turned back a
quarter. `lineCap: .round` rounds the ends, like the web's
`strokeLinecap="round"`.

### A countdown alert, and asking iOS what's waiting

7a's reminders use calendar triggers ("Monday 9:45"). A block end is "in 1,500
seconds", so it uses a countdown trigger. And to replace only the timer's
alerts, the store asks iOS for its waiting list and removes those ids:

```swift
let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1500, repeats: false)

let waiting = await center.pendingNotificationRequests()
center.removePendingNotificationRequests(withIdentifiers:
    waiting.map(\.identifier).filter { $0.hasPrefix(studyAlertPrefix) })
```

(`TimelineView` is back from 5a, now with `.periodic(from: .now, by: 0.5)`:
redraw every half second, like the web's 500 ms tick.)

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `lib/study.ts` | `Logic/Study.swift`: blocks, plans, focus minutes, rounds |
| `lib/study.test.ts` | `StudyTests.swift`, plus the run, the alerts, `clock` and `span` |
| `clock`, `span` and the `showReminder` messages in `components/StudyTimer.tsx` | `studyClock`, `studySpan` and `studyAlerts` in `Logic/Study.swift` |
| The rest of `components/StudyTimer.tsx` | `Screens/Study/StudySetupView.swift` and `StudyTimerView.swift` |
| "Start studying" and `onFocusComplete` / `onFinishTask` in `app/tasks/[id]/page.tsx` | `AssignmentDetailView.swift`, the sheet, `addStudySession` |
| `addStudySession` in `lib/store.tsx` | `Store+Planning.swift`, next to 7b's `focusedMinutes` |
| `showReminder` from the page | Alerts handed to iOS ahead of time (`Store+Notifications.swift`) |

Where the phone deliberately differs:

- **Every block's end is known when you tap Start (D-62).** The web keeps
  only the current block's end; when it notices the block is over, it starts
  the next one *from that moment*. A phone in a pocket notices late, so the
  web's session stretches (and its alert waits until you look). Here a running
  session is the plan plus one moment it's timed from, so the count is right
  whenever you look, and iOS gets every block's alert in advance.
- **Each focus block is recorded at its real end,** even if the phone only
  noticed an hour later. The web records it with the time it noticed.
- **The reminder sync leaves the timer's alerts alone.** 7a cleared every
  waiting notification on each sync, so editing a task, or just coming back
  to the app, would have silenced a running session. It now removes
  everything except ids starting with `study.`, and makes room for them under
  iOS's limit of 64 by dropping its own furthest reminders (they come back at
  the next sync).
- **No swipe-to-dismiss while a session runs,** and Close only shows before
  and after. The web closes on a tap outside the sheet, which on a phone is
  too easy to do by accident. **Stop** ends a session on purpose.
- **Focus mode covers the sheet, not the whole screen.** A full-screen cover
  would make the timer "disappear", and its `onDisappear` would cancel the
  alerts right when you lock the phone.
- **Start studying is on the task's screen only.** The web's button lives in
  the unfolded task row, and on the phone that row's job is done by the task
  screen (4b).
- **A failed save keeps the session.** Grades roll back on a failed write
  (D-49) because you'd retry from the form; a finished block has no form, so
  it stays in memory and the next save that works keeps it.
- **A session ends with the app.** If iOS or you close ClassPing mid-session,
  the session is gone, as on the web. Its leftover alerts are cleared by the
  next reminder sync, which runs as soon as the app opens.

Web behavior kept on purpose: the presets, the rounds, 25 / 5 / 15, the long
break only after a fourth round with more work after it, no break at the end,
"Rest" during a break, the green ring during a break, and the alert words.
Even "Start 1 minutes" for a one-minute block, which the web says too.

**On the web (D-61, your yes):** the CSV's Generated line now uses the
browser's own day. `app/grades/page.tsx` sends `generatedOn: dayOf(new Date())`
with the export, `app/api/export/grades/route.ts` passes it on, and
`lib/report.ts` prints it (in the PDF too), falling back to the UTC date when
it isn't a real day. Three new tests. Uncommitted, like the last web change:
commit `lib/report.ts`, `lib/report.test.ts`, `app/api/export/grades/route.ts`
and `app/grades/page.tsx` on their own.

## 4. Files, in the order to type them

Seven source files: three new (4.1, 4.5, 4.6) and four replaced (4.2, 4.3,
4.4, 4.7). Build once all seven are in.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Study.swift` (new file)

The maths, Foundation only, so `StudyTests` runs on Linux. The first half is
`lib/study.ts`; the second half (`StudyRun` onward) is the phone's own clock.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Study.swift
//  Phase:   10a (the study timer)
//  Ports:   lib/study.ts (blocks, Pomodoro plans, focus minutes), and the
//           `clock` and `span` helpers and block-end messages of
//           components/StudyTimer.tsx
//
//  Summary: What a study session is made of, and where a running one stands.
//           A plain timer is a plan of one focus block; Pomodoro alternates
//           focus and breaks. A running session is a plan plus one moment it
//           was timed from, so every block's end is known in advance: the
//           phone can sleep through a block and the count is still right.
//

import Foundation

/// What a block is for. The web calls them "focus" and "break"; `break` is a
/// Swift keyword, so here the second one is `rest`. On screen it's "Break".
enum BlockKind: String, Equatable, Sendable {
    case focus, rest
}

/// One timed stretch of a session. `StudyBlock` in lib/study.ts.
struct StudyBlock: Equatable, Sendable {
    var kind: BlockKind
    var minutes: Int
    /// True for the longer break earned after a run of focus blocks.
    var long = false
}

/// The four numbers a Pomodoro session is built from. `PomodoroConfig`.
/// The defaults are the classic 25 / 5 / 15, four rounds.
struct PomodoroConfig: Equatable, Sendable {
    /// Minutes of work per focus block.
    var focus = 25
    var shortBreak = 5
    var longBreak = 15
    /// How many focus blocks the whole session has.
    var rounds = 4
}

/// The web's `DEFAULT_POMODORO`: what a fresh `PomodoroConfig()` already is.
let DEFAULT_POMODORO = PomodoroConfig()
/// A long break replaces the short one after this many focus blocks.
let ROUNDS_PER_LONG_BREAK = 4
let MAX_ROUNDS = 8
/// Matches the single-block ceiling: a "focus block" of four hours isn't one.
let MAX_BLOCK_MINUTES = 240

/// A typed number of minutes, rounded and kept between `lo` and `hi`. The
/// web's `clamp`, with JavaScript's `Math.round` (a half rounds up: 25.5 is
/// 26), which is `floor(n + 0.5)`.
func clampMinutes(_ n: Double, _ lo: Int, _ hi: Int) -> Int {
    guard n.isFinite else { return lo }
    let rounded = (n + 0.5).rounded(.down)
    return Int(min(Double(hi), max(Double(lo), rounded)))
}

/// Every number of a config put back in range. `normalizeConfig` on the web.
func normalizeConfig(_ c: PomodoroConfig) -> PomodoroConfig {
    PomodoroConfig(focus: min(MAX_BLOCK_MINUTES, max(1, c.focus)),
                   shortBreak: min(60, max(1, c.shortBreak)),
                   longBreak: min(60, max(1, c.longBreak)),
                   rounds: min(MAX_ROUNDS, max(1, c.rounds)))
}

/// A config expanded into the blocks to run, in order. `buildPlan`.
/// No break at the end: the session ends on the work. The long break comes
/// after every fourth focus block, but only when more work follows.
func buildPlan(_ config: PomodoroConfig) -> [StudyBlock] {
    let c = normalizeConfig(config)
    var plan: [StudyBlock] = []
    for round in 1...c.rounds {
        plan.append(StudyBlock(kind: .focus, minutes: c.focus))
        // A break only between rounds, so the last round is never followed by one.
        if round < c.rounds {
            let long = round % ROUNDS_PER_LONG_BREAK == 0
            plan.append(StudyBlock(kind: .rest, minutes: long ? c.longBreak : c.shortBreak,
                                   long: long))
        }
    }
    return plan
}

/// A single timed block, so both modes run the same code. `singlePlan`.
func singlePlan(_ minutes: Int) -> [StudyBlock] {
    [StudyBlock(kind: .focus, minutes: min(MAX_BLOCK_MINUTES, max(1, minutes)))]
}

/// Minutes of focus in the first `count` blocks. `focusMinutesDone`.
/// Breaks don't count: resting is part of the method, not the work.
func focusMinutesDone(_ plan: [StudyBlock], _ count: Int) -> Int {
    plan.prefix(max(0, min(count, plan.count)))
        .filter { $0.kind == .focus }
        .reduce(0) { $0 + $1.minutes }
}

/// The whole plan's length, breaks included. `planMinutes`.
func planMinutes(_ plan: [StudyBlock]) -> Int {
    plan.reduce(0) { $0 + $1.minutes }
}

/// How many focus blocks the plan has, for "Round 2 of 4". `focusCount`.
func focusCount(_ plan: [StudyBlock]) -> Int {
    plan.filter { $0.kind == .focus }.count
}

/// Which round block `index` belongs to, counting from 1. A break reports the
/// round it follows. `roundAt`.
func roundAt(_ plan: [StudyBlock], _ index: Int) -> Int {
    plan.prefix(max(0, min(index + 1, plan.count))).filter { $0.kind == .focus }.count
}

/// 3671 seconds -> "1:01:11", 125 -> "2:05". The web's `clock`: partial
/// seconds round up, so the display never shows 0:00 while time is left.
func studyClock(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

/// 115 minutes -> "1h 55m", 60 -> "1h", 25 -> "25 min". The web's `span`.
func studySpan(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

// MARK: - A running session (the phone's own)

/// A running or paused session: the plan, the block that was running at
/// `anchor`, and how much of that block was left then. Every later block
/// follows straight on, so each block's end is known from these four values.
/// The web keeps only the current block's end and starts the next block when
/// it notices the old one ended, which a sleeping phone notices late (D-62).
struct StudyRun: Equatable, Sendable {
    var plan: [StudyBlock]
    var index: Int
    var anchor: Date
    /// Seconds of block `index` still to go at `anchor`.
    var left: Double

    /// A fresh run: the first block, all of it, from `now`.
    init(plan: [StudyBlock], now: Date) {
        self.plan = plan
        index = 0
        anchor = now
        left = Double((plan.first?.minutes ?? 1) * 60)
    }

    init(plan: [StudyBlock], index: Int, anchor: Date, left: Double) {
        self.plan = plan
        self.index = index
        self.anchor = anchor
        self.left = left
    }
}

/// Where a run stands at one moment: which block, and how much of it is left.
struct RunPosition: Equatable, Sendable {
    var index: Int
    /// Seconds left in block `index`. Zero once finished.
    var remaining: Double
    /// True when the last block has ended.
    var finished: Bool
}

/// When each block from `run.index` on ends, in order.
func blockEnds(_ run: StudyRun) -> [Date] {
    // A run past its last block has nothing left to end.
    guard run.index >= 0, run.index < run.plan.count else { return [] }
    var ends: [Date] = []
    var end = run.anchor.addingTimeInterval(run.left)
    for i in run.index..<run.plan.count {
        if i > run.index { end = end.addingTimeInterval(Double(run.plan[i].minutes * 60)) }
        ends.append(end)
    }
    return ends
}

/// The block running at `now`, and its time left, worked out from the clock
/// alone. However long the phone slept, the answer is where the session
/// would have got to.
func runPosition(_ run: StudyRun, at now: Date) -> RunPosition {
    let ends = blockEnds(run)
    // The first block whose end is still ahead is the one running now.
    if let k = ends.firstIndex(where: { $0 > now }) {
        return RunPosition(index: run.index + k, remaining: ends[k].timeIntervalSince(now),
                           finished: false)
    }
    return RunPosition(index: run.plan.count, remaining: 0, finished: true)
}

/// The same session, stopped at `now`: the current block and what's left of
/// it, ready to start counting again from whenever you resume.
func pausedRun(_ run: StudyRun, at now: Date) -> StudyRun {
    let p = runPosition(run, at: now)
    return StudyRun(plan: run.plan, index: min(p.index, run.plan.count - 1),
                    anchor: now, left: p.remaining)
}

/// One focus block that has run to its end.
struct FinishedFocus: Equatable, Sendable {
    var index: Int
    var minutes: Int
    var endedAt: Date
}

/// The focus blocks that ended since block `done`, and the new `done`: how
/// many blocks are now behind you. The timer calls this as the clock moves
/// and records each block once, at the moment it really ended. (The web
/// records a block when it notices, with "now" as its time.)
func newlyFinished(_ run: StudyRun, from done: Int, at now: Date)
    -> (blocks: [FinishedFocus], through: Int) {
    let ends = blockEnds(run)
    let p = runPosition(run, at: now)
    // Blocks before `run.index` were dealt with before this run was timed.
    let start = max(done, run.index)
    var blocks: [FinishedFocus] = []
    if start < p.index {
        for i in start..<p.index where run.plan[i].kind == .focus {
            blocks.append(FinishedFocus(index: i, minutes: run.plan[i].minutes,
                                        endedAt: ends[i - run.index]))
        }
    }
    return (blocks, max(done, p.index))
}

/// A notification the phone should show when a block ends.
struct StudyAlert: Equatable, Sendable {
    var id: String
    var at: Date
    var title: String
    var body: String
}

/// The id prefix of every study alert, so the reminder sync can leave them be.
let studyAlertPrefix = "study."

/// What to say at the end of each block still ahead of `now`, in the web's
/// words (its `showReminder` calls in StudyTimer's `advance`): the next
/// block, or the end of the session.
func studyAlerts(_ run: StudyRun, title: String, after now: Date) -> [StudyAlert] {
    let ends = blockEnds(run)
    let rounds = focusCount(run.plan)
    var alerts: [StudyAlert] = []
    for (k, end) in ends.enumerated() where end > now {
        let i = run.index + k
        let next = i + 1
        if next >= run.plan.count {
            alerts.append(StudyAlert(id: "\(studyAlertPrefix)\(i)", at: end,
                                     title: "Session complete",
                                     body: "\(studySpan(planMinutes(run.plan))) on \u{201C}\(title)\u{201D}. Nice work."))
        } else if run.plan[next].kind == .rest {
            alerts.append(StudyAlert(id: "\(studyAlertPrefix)\(i)", at: end,
                                     title: run.plan[next].long ? "Long break" : "Break time",
                                     body: "\(run.plan[next].minutes) minutes off. Stand up."))
        } else {
            alerts.append(StudyAlert(id: "\(studyAlertPrefix)\(i)", at: end,
                                     title: "Round \(roundAt(run.plan, next)) of \(rounds)",
                                     body: "\(run.plan[next].minutes) more minutes on \u{201C}\(title)\u{201D}."))
        }
    }
    return alerts
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Store+Planning.swift` (replaces your 7b file)

Changed spots:

- **Header** (changed).
- **`addStudySession`** (new, after `focusedMinutes`).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Planning.swift
//  Phase:   7b (one task's reminders, and planning the work), changed in
//           10a (study sessions)
//  Ports:   lib/store.tsx (planTask, removeTaskPlan) and the updateTask calls
//           made by TaskReminderCard and ExamPrepCard in
//           components/TaskReminders.tsx
//
//  Summary: Everything the task detail's three planning cards change: the
//           reminder switch, early warnings and snooze; the exam plan's
//           checklist steps; and the day you mean to work on it. Each action
//           saves straight away, and 7a's reminder sync notices the change
//           by itself, so a snooze silences the phone within a second.
//           Since 10a it also records the study timer's finished blocks.
//

import Foundation

extension Store {
    // MARK: - Reminders

    /// Turns a task's daily nudge on or off. Off also ends any snooze, so
    /// switching back on starts fresh. The switch in TaskReminderCard.
    func setReminder(_ on: Bool, for id: UUID) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].reminder = on
        if !on { assignments[i].snoozedUntil = nil }
        save()
    }

    /// Adds or removes one early warning. `toggleLead` in TaskReminderCard.
    /// It starts from the warnings in force, so the first tap on an exam edits
    /// its default ladder instead of starting from nothing. Removing the last
    /// one leaves an empty list, which means "not chosen", so an exam gets its
    /// ladder back. The web does exactly the same.
    func toggleLead(_ minutes: Int, for id: UUID) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        var next = Set(effectiveLeads(assignments[i]))
        if next.contains(minutes) {
            next.remove(minutes)
        } else {
            next.insert(minutes)
        }
        assignments[i].remindLeads = next.sorted(by: >)
        save()
    }

    /// Puts a task down until the preset's moment: nothing about it rings
    /// before then. `snooze` in TaskReminderCard.
    func snooze(_ id: UUID, _ preset: SnoozePreset, now: Date = .now) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].snoozedUntil = snoozeUntil(preset, now)
        save()
    }

    /// Ends a snooze early. "Wake it" on the web.
    func wake(_ id: UUID) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].snoozedUntil = nil
        save()
    }

    // MARK: - Exam prep

    /// Writes the exam's plan onto its checklist, after any steps already
    /// there, and only once. `onAddSteps` in app/tasks/[id]/page.tsx.
    func addPrepSteps(to id: UUID, now: Date = .now) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        // Already carries a plan, or there's nothing left to plan: no change.
        guard !hasPrepLadder(assignments[i].subtasks.map(\.title)) else { return }
        let steps = prepLadder(assignments[i].due, now)
        guard !steps.isEmpty else { return }
        // `+=` adds the new rows to the end of the checklist.
        assignments[i].subtasks += steps.map { Subtask(title: $0.title) }
        save()
    }

    /// Minutes of focused work recorded against a task. The detail's
    /// "Focused" row, `studyMinutes(studySessions, { taskId })` on the web.
    func focusedMinutes(_ id: UUID) -> Int {
        studyMinutes(studySessions, taskID: id)
    }

    // NEW in Phase 10a
    /// Records one finished focus block: `addStudySession` in lib/store.tsx.
    /// Minutes are kept between 1 and 240, as the web does. `completedAt` is
    /// when the block really ended, which can be a while before the phone
    /// noticed (D-62). Unlike a grade, nothing rolls back if the write fails:
    /// there's no form to retry from, so the session stays in memory, the
    /// screen shows the save-failure line, and the next save that works keeps it.
    func addStudySession(minutes: Int, assignmentID: UUID?, courseID: UUID?,
                         mode: StudySession.Mode, completedAt: Date = .now) {
        studySessions.append(StudySession(assignmentID: assignmentID, courseID: courseID,
                                          minutes: min(240, max(1, minutes)),
                                          completedAt: completedAt, mode: mode))
        save()
    }

    // MARK: - Planning the work

    /// The day a task is planned for, if it has one. A task has at most one.
    func taskPlan(for id: UUID) -> TaskPlan? {
        taskPlans.first(where: { $0.assignmentID == id })
    }

    /// Plans a task onto a work day, or moves its plan there. `planTask` in
    /// lib/store.tsx. Moving clears any "top three" priority (the web does
    /// too). The deadline is never touched: this is when, not by when.
    func planTask(_ id: UUID, on date: String) {
        guard isValidDate(date) else { return }
        if let i = taskPlans.firstIndex(where: { $0.assignmentID == id }) {
            taskPlans[i].date = date
            taskPlans[i].priority = nil
            taskPlans[i].updatedAt = .now
        } else {
            taskPlans.append(TaskPlan(assignmentID: id, date: date))
        }
        save()
    }

    /// Takes a task off its work day. `removeTaskPlan` in lib/store.tsx.
    func removeTaskPlan(_ id: UUID) {
        taskPlans.removeAll(where: { $0.assignmentID == id })
        save()
    }
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Store+Notifications.swift` (replaces your 7a file)

Changed spots:

- **Header** (changed).
- **`studyAlertCount`** (new, after the two sync flags).
- **Step 2 of `replaceReminders`** (changed): the plan makes room for study
  alerts.
- **Step 5** (changed): removes every waiting notification except study ones
  while a session has some.
- **`scheduleStudyAlerts`** (new, at the end).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Notifications.swift
//  Phase:   7a (reminders ring), changed in 10a (the study timer's alerts)
//  Ports:   lib/notifications.ts (permission, showing a notification) and the
//           bookkeeping of the reminder loop in lib/store.tsx (the fired map)
//
//  Summary: Hands the reminder plan to iOS. Each sync works out what has
//           already rung, builds the plan, and replaces iOS's list of waiting
//           notifications with it. Also asks for permission, once.
//           ClassPingApp.swift decides when to sync. Since 10a it also holds
//           the study timer's block-end alerts, which the sync leaves alone.
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

    /// Notification-center calls suspend, so main-actor isolation alone doesn't
    /// stop two syncs interleaving their remove/add operations. Keep one writer;
    /// edits during a batch request another pass using the latest store values.
    private static var reminderSyncInProgress = false
    private static var reminderSyncRequested = false

    // NEW in Phase 10a
    /// How many study alerts this run of the app has handed iOS. A `static`
    /// lives as long as the app's process, so after a relaunch it's 0 again:
    /// a session can't outlive the app, and the first sync then clears any
    /// alerts it left behind.
    private static var studyAlertCount = 0

    /// Rebuilds the plan and hands it to iOS. Safe to call as often as you
    /// like: each call replaces the whole waiting list, and a reminder's id
    /// stops it ringing twice. The web's 30-second loop, done once per change.
    func syncReminders() async {
        guard !Task.isCancelled else { return }
        Store.reminderSyncRequested = true
        guard !Store.reminderSyncInProgress else { return }
        Store.reminderSyncInProgress = true
        defer { Store.reminderSyncInProgress = false }

        // Finish a batch even if SwiftUI cancels its caller after an edit.
        // The newer call marks another pass, rather than racing this writer.
        while Store.reminderSyncRequested {
            Store.reminderSyncRequested = false
            await replaceReminders()
        }
    }

    private func replaceReminders() async {
        let inputs = reminderInputs
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
        // CHANGED in Phase 10a: iOS keeps only 64 waiting notifications, so
        // while a study session's alerts are waiting, the plan makes room
        // for them by dropping its furthest reminders (the plan is soonest
        // first). Dropped ones aren't recorded below, so they stay eligible.
        let quiet = normalizeQuietHours(start: profile.quietStart, end: profile.quietEnd)
        let room = max(0, maxPendingReminders - Store.studyAlertCount)
        let plan = Array(reminderPlan(courses: liveCourses, tasks: liveAssignments,
                                      postClass: profile.postClassNudge, quiet: quiet,
                                      fired: fired, now: now).prefix(room))

        // 3. Permission, asked the first time there is something to ring (D-30).
        var allowed = false
        if !plan.isEmpty {
            allowed = await requestNotificationAccess()
        }
        // Permission can stay open for minutes. Re-plan against the current
        // clock and data before handing iOS anything calculated before it.
        guard inputs == reminderInputs, dayOf(now) == dayOf(.now),
              minuteOfDay(now) == minuteOfDay(.now) else {
            Store.reminderSyncRequested = true
            return
        }

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
        // CHANGED in Phase 10a: every waiting notification goes except a
        // running session's study alerts. Before, this cleared everything,
        // so editing a task mid-session silenced the timer.
        let center = UNUserNotificationCenter.current()
        if Store.studyAlertCount > 0 {
            let waiting = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: waiting
                .map(\.identifier)
                .filter { !$0.hasPrefix(studyAlertPrefix) })
        } else {
            center.removeAllPendingNotificationRequests()
        }
        guard allowed else { return }
        for r in plan {
            // A rejected one-off must stay eligible for the next sync, even
            // if its planned date has passed by then.
            if (try? await center.add(notificationRequest(for: r))) == nil {
                times.removeValue(forKey: r.id)
                defaults.set(times, forKey: Store.scheduledKey)
            }
        }
        if inputs != reminderInputs { Store.reminderSyncRequested = true }
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
        // Details the notification delegate uses to open the right screen.
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

    // MARK: - The study timer's alerts (NEW in Phase 10a)

    /// Replaces the study timer's waiting alerts with `alerts`: the running
    /// session's block ends, or none (paused, stopped, done or closed). The
    /// web shows these with `showReminder` when it notices a block ended;
    /// handing them to iOS ahead of time is what makes them ring in a pocket.
    func scheduleStudyAlerts(_ alerts: [StudyAlert]) async {
        let center = UNUserNotificationCenter.current()
        // Take away the last set first. Only study ids: reminders stay.
        let waiting = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: waiting
            .map(\.identifier)
            .filter { $0.hasPrefix(studyAlertPrefix) })

        // The first session asks for permission, if iOS never has (D-30).
        var allowed = false
        if !alerts.isEmpty {
            allowed = await requestNotificationAccess()
        }
        let before = Store.studyAlertCount
        Store.studyAlertCount = allowed ? alerts.count : 0

        if allowed {
            for alert in alerts {
                // A newer call (pause, stop) has taken over: add nothing stale.
                // `.task(id:)` cancels this task when the session changes.
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.body
                content.sound = .default
                content.threadIdentifier = "study"
                // A countdown trigger: ring this many seconds from now, to the
                // second, which a block end needs.
                let wait = max(1, alert.at.timeIntervalSinceNow)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
                _ = try? await center.add(UNNotificationRequest(identifier: alert.id,
                                                                content: content, trigger: trigger))
            }
        }

        // iOS keeps only the 64 soonest. When the number of study alerts
        // changes, rebuild the reminders so they make room, or take it back.
        if Store.studyAlertCount != before {
            await syncReminders()
        }
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/ClassPingApp.swift` (replaces your 7c file)

Changed spots:

- **Header** (changed).
- **In `didReceive`** (new): a tap on a study alert finishes without setting a
  route, so the app opens as you left it.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   0 (housekeeping), changed in 7a (reminders), 7c (taps) and
//           10a (a study alert's tap)
//  Ports:   app/layout.tsx (the root that wraps every screen), when the
//           reminder loop in lib/store.tsx runs, and the notificationclick
//           handler in public/sw.js
//
//  Summary: The app's entry point. It creates the one Store the whole app
//           shares and hands it to every screen through the SwiftUI
//           environment. Since 7a it also keeps iOS's reminders in step with
//           the store, and lets them show while the app is open. Since 7c a
//           tap on one tells the store where to go. Since 10a a tap on a
//           study timer's alert just opens the app as you left it.
//
import SwiftUI
import UIKit
import UserNotifications

/// @main marks where the app starts, similar to the root layout in the web app
@main
struct ClassPingApp: App {
    /// UIKit retains the launch delegate for the app's lifetime. It owns the
    /// same store that receives notification taps and drives every screen.
    @UIApplicationDelegateAdaptor(ClassPingAppDelegate.self) private var appDelegate

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
                .environment(appDelegate.store)
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

/// Registers notifications in UIKit's launch lifecycle, before iOS delivers
/// the response that opened the app. The adaptor keeps this object alive.
@MainActor
final class ClassPingAppDelegate: NSObject, UIApplicationDelegate {
    /// One loaded store, shared by notification handling and SwiftUI.
    let store = Store.load()
    private lazy var notificationDelegate = NotificationDelegate(store: store)

    /// Register before launch finishes, including launches from a notification.
    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}

/// Receives iOS callbacks on their notification queue. Read the payload there;
/// only the parsed route crosses to the main actor that owns the store.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// The launch delegate's store; never create a second store for a tap.
    let store: Store

    init(store: Store) {
        self.store = store
    }

    /// Keep banners visible while ClassPing is already on screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    /// Finish every response, including ignored actions. A default tap queues
    /// its route until RootView is active, even if the screen doesn't exist yet.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        // NEW in Phase 10a: a study alert has nowhere to send you. The timer
        // is still on screen if the session is running, so leave it there.
        guard !response.notification.request.identifier.hasPrefix(studyAlertPrefix) else {
            completionHandler()
            return
        }
        let destination = notificationRoute(response.notification.request.content.userInfo)
        let store = self.store
        Task { @MainActor in
            store.route = destination
            completionHandler()
        }
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Study/StudySetupView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Study/StudySetupView.swift
//  Phase:   10a (the study timer)
//  Ports:   the setup half of components/StudyTimer.tsx
//
//  Summary: The one decision before a study session: how long. One block
//           (15, 25, 45 or 60 minutes, or any number up to 240), or Pomodoro
//           (a focus length and 2, 3, 4 or 6 rounds, with breaks between).
//           Presets first, because "25 minutes" is a choice a stuck student
//           can make. The sound picker joins in 10b.
//

import SwiftUI

struct StudySetupView: View {
    @Environment(Store.self) private var store

    /// One block (`.timer`) or Pomodoro, owned by the timer screen.
    /// StudySession.Mode already names the two, so no new enum is needed.
    @Binding var mode: StudySession.Mode
    /// One block's length, in minutes.
    @Binding var minutes: Int
    /// Pomodoro's focus length and rounds.
    @Binding var config: PomodoroConfig
    /// Starts the session the setup describes.
    let onStart: () -> Void

    /// The "Or set" field's text, kept as typed so a half-typed number isn't
    /// overwritten. A preset tap writes its number in here too.
    @State private var typed = ""
    @FocusState private var typing: Bool

    /// The web's `PRESETS` and `ROUND_CHOICES`.
    private let presets = [15, 25, 45, 60]
    private let roundChoices = [2, 3, 4, 6]

    var body: some View {
        let accent = store.profile.accent
        // What Start would run: the web's `previewPlan`.
        let preview = mode == .timer ? singlePlan(minutes) : buildPlan(config)

        VStack(alignment: .leading, spacing: 14) {
            // One block is the default; Pomodoro is a method you opt into.
            Picker("Mode", selection: $mode) {
                Text("One block").tag(StudySession.Mode.timer)
                Text("Pomodoro").tag(StudySession.Mode.pomodoro)
            }
            .pickerStyle(.segmented)

            if mode == .timer {
                chipRow(presets, selected: minutes, unit: "min") { p in
                    minutes = p
                    typed = "\(p)"
                }
                // Any length from 1 to 240. `clampMinutes` rounds the way
                // the web's input does, and keeps it in range.
                HStack(spacing: 10) {
                    Text("OR SET")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Theme.faint)
                    TextField("Minutes", text: $typed)
                        .keyboardType(.numberPad)
                        .focused($typing)
                        .inputField(accent)
                        .accessibilityLabel("Minutes")
                    Text("min").foregroundStyle(Theme.muted)
                }
                .onChange(of: typed) { _, text in
                    if let value = Double(text) {
                        minutes = clampMinutes(value, 1, MAX_BLOCK_MINUTES)
                    }
                }
            } else {
                label("FOCUS BLOCK")
                chipRow(presets, selected: config.focus, unit: "min") { config.focus = $0 }
                label("ROUNDS")
                chipRow(roundChoices, selected: config.rounds, unit: nil) { config.rounds = $0 }
                // "4 × 25 min, 5 min breaks, 1h 55m in all"
                Text("\(config.rounds) \u{00D7} \(config.focus) min, \(config.shortBreak) min breaks, \(studySpan(planMinutes(preview))) in all")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }

            Button(action: onStart) {
                Text(mode == .timer ? "Start \(minutes) minutes" : "Start \(config.rounds) rounds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        // Start from whatever length the screen holds.
        .onAppear { typed = "\(minutes)" }
        // Swipe down or tap Done to put the number pad away (D-54).
        .keyboardDismissable { typing = false }
    }

    /// A small caps label over a row of chips.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundStyle(Theme.faint)
    }

    /// Four chips in a row, the chosen one filled with your accent. `unit`
    /// is the small word under each number ("min"), or nil for none.
    private func chipRow(_ values: [Int], selected: Int, unit: String?,
                         pick: @escaping (Int) -> Void) -> some View {
        let accent = store.profile.accent
        return HStack(spacing: 10) {
            ForEach(values, id: \.self) { value in
                let on = value == selected
                Button { pick(value) } label: {
                    VStack(spacing: 2) {
                        Text("\(value)").font(.system(size: 18, weight: .bold))
                        if let unit {
                            Text(unit).font(.system(size: 10.5, weight: .medium)).opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(on ? Color.white : Theme.muted)
                    .background(on ? Theme.brand(accent) : Theme.surface2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unit.map { "\(value) \($0 == "min" ? "minutes" : $0)" } ?? "\(value) rounds")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Study/StudyTimerView.swift` (new file)

The longest file this phase. Read `advance` closely: it's the one place
blocks are recorded, and the only reason they can't be counted twice.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Study/StudyTimerView.swift
//  Phase:   10a (the study timer)
//  Ports:   components/StudyTimer.tsx (the running, paused and finished
//           states, focus mode, and its `onFocusComplete` and
//           `onFinishTask` callbacks in app/tasks/[id]/page.tsx)
//
//  Summary: A study session for one assignment, in a sheet. Setup, then a
//           ring counting down each block, Pause and Stop, and a focus mode
//           that hides everything but the clock. Every block's end is worked out when you start, so
//           the session keeps time with the phone in your pocket: an alert
//           rings at each block's end, and each finished focus block is
//           recorded at the moment it ended.
//

import SwiftUI

struct StudyTimerView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The work being studied. A copy taken when the sheet opened; whether
    /// it's done is read live from the store.
    let assignment: Assignment

    /// Where the session is. An enum with a value in three of its cases: the
    /// run travels with the state it belongs to, so a paused session can't be
    /// missing its run, and setup can't have one.
    private enum Phase: Equatable {
        case setup
        case running(StudyRun)
        case paused(StudyRun)
        case done(StudyRun)
    }

    @State private var phase = Phase.setup
    // The setup choices, kept here so "Another session" starts from them.
    @State private var mode = StudySession.Mode.timer
    @State private var minutes = 25
    @State private var config = DEFAULT_POMODORO
    /// How many of the plan's blocks are behind you and dealt with.
    @State private var credited = 0
    /// Focus mode, the web's "zen": everything but the clock hidden.
    @State private var zen = false

    var body: some View {
        let accent = store.profile.accent

        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // `switch` on the phase: each case gets its own screen.
                    // `let run` takes the value out of the case to use it.
                    switch phase {
                    case .setup:
                        header("WORKING ON", assignment.title)
                        StudySetupView(mode: $mode, minutes: $minutes, config: $config,
                                       onStart: start)
                    case .running(let run):
                        // A clock redrawn twice a second; every number on it
                        // comes from the time, never from counting ticks.
                        TimelineView(.periodic(from: .now, by: 0.5)) { context in
                            live(run, at: context.date)
                        }
                    case .paused(let run):
                        face(run, RunPosition(index: run.index, remaining: run.left,
                                              finished: false), paused: true)
                    case .done(let run):
                        finished(run)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.canvas)
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // While a session runs, Stop ends it; Close is for before and after.
                if !isActive {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .tint(Theme.brand(accent))
            // Focus mode hides the bar along with everything else.
            .toolbar(zen ? .hidden : .visible, for: .navigationBar)
        }
        // Focus mode, laid over the whole sheet. An overlay rather than a
        // full-screen cover: a cover would make this screen "disappear",
        // and its `onDisappear` would cancel the alerts you need most then.
        .overlay {
            if zen { zenView }
        }
        // A swipe down can't throw away a running session by accident.
        .interactiveDismissDisabled(isActive)
        // Hand iOS this session's block-end alerts whenever it starts, pauses,
        // resumes, stops or ends. `.task(id:)` cancels the last call first.
        .task(id: phase) {
            await store.scheduleStudyAlerts(currentAlerts)
        }
        // Closing the sheet ends the session, so its alerts go too.
        .onDisappear {
            Task { await store.scheduleStudyAlerts([]) }
        }
    }

    // MARK: - State

    /// True while a session is running or paused.
    private var isActive: Bool {
        switch phase {
        case .running, .paused: true
        case .setup, .done: false
        }
    }

    /// The alerts for what's still ahead, while running; none otherwise.
    /// `if case` checks one case of an enum and takes its value out.
    private var currentAlerts: [StudyAlert] {
        if case .running(let run) = phase {
            return studyAlerts(run, title: assignment.title, after: .now)
        }
        return []
    }

    // MARK: - Actions

    /// Starts the plan the setup describes: the web's `startPlan`.
    private func start() {
        let plan = mode == .timer ? singlePlan(minutes) : buildPlan(config)
        credited = 0
        phase = .running(StudyRun(plan: plan, now: .now))
    }

    /// Records the focus blocks that ended since last time, each at its real
    /// end, and finishes the session after its last block. The web's
    /// `advance`, which runs once per block; this catches up on several at
    /// once after the phone slept.
    private func advance(_ run: StudyRun, at now: Date) {
        let result = newlyFinished(run, from: credited, at: now)
        for block in result.blocks {
            store.addStudySession(minutes: block.minutes, assignmentID: assignment.id,
                                  courseID: assignment.courseID, mode: mode,
                                  completedAt: block.endedAt)
        }
        credited = result.through
        if runPosition(run, at: now).finished {
            phase = .done(run)
            zen = false
        }
    }

    /// Stops the clock where it is. Whatever already finished is recorded first.
    private func pause(_ run: StudyRun) {
        let now = Date.now
        advance(run, at: now)
        if case .running = phase {
            phase = .paused(pausedRun(run, at: now))
        }
    }

    /// Starts the clock again from now: every later block moves along with it.
    private func resume(_ run: StudyRun) {
        var next = run
        next.anchor = .now
        phase = .running(next)
    }

    /// Back to setup. The web's `reset`; blocks already recorded stay recorded.
    private func stop() {
        phase = .setup
        zen = false
    }

    // MARK: - Pieces

    /// The small caps line and the title over the clock.
    private func header(_ label: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// A running session at one moment. `onChange(of:initial:)` (7c) notices
    /// each new block, including several at once after the phone slept, and
    /// records what finished.
    private func live(_ run: StudyRun, at now: Date) -> some View {
        let position = runPosition(run, at: now)
        return face(run, position, paused: false)
            .onChange(of: position.index, initial: true) {
                advance(run, at: now)
            }
    }

    /// The round dots, the ring with the time left, and the controls.
    private func face(_ run: StudyRun, _ position: RunPosition, paused: Bool) -> some View {
        let accent = store.profile.accent
        let index = min(position.index, run.plan.count - 1)
        let block = run.plan[index]
        let isBreak = block.kind == .rest
        let total = Double(block.minutes * 60)
        // How much of this block has gone, from 0 to 1.
        let gone = total > 0 ? 1 - min(1, position.remaining / total) : 0
        // Green for a break, your accent for work, as on the web.
        let color = isBreak ? Theme.good : Theme.brand(accent)
        let rounds = focusCount(run.plan)

        return VStack(spacing: 18) {
            header(isBreak ? "BREAK" : "WORKING ON", isBreak ? "Rest" : assignment.title)

            // One dot per round: done, now (wider), or still to come.
            if rounds > 1 {
                HStack(spacing: 6) {
                    ForEach(run.plan.indices.filter { run.plan[$0].kind == .focus }, id: \.self) { i in
                        Capsule()
                            .fill(i < index ? Theme.brand(accent) : i == index ? color : Theme.lineStrong)
                            .frame(width: i == index ? 20 : 8, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Round \(roundAt(run.plan, index)) of \(rounds)")
            }

            // The ring: a full grey circle, and on top of it the same circle
            // trimmed to the share that's gone. `trim` draws only part of a
            // shape's outline; turning it -90° starts it at twelve o'clock.
            ZStack {
                Circle()
                    .stroke(Theme.surface2, lineWidth: 11)
                Circle()
                    .trim(from: 0, to: gone)
                    .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(studyClock(position.remaining))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(paused ? "Paused" : isBreak ? "break" : "left")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 180, height: 180)
            .accessibilityElement(children: .combine)

            // Stop and Pause / Resume, then the way into focus mode.
            HStack(spacing: 10) {
                Button(action: stop) {
                    Text("Stop").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                Button {
                    if paused { resume(run) } else { pause(run) }
                } label: {
                    Text(paused ? "Resume" : "Pause").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Focus mode") { zen = true }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
        }
    }

    /// The end: what you did, then Mark it done, Another session or Close.
    private func finished(_ run: StudyRun) -> some View {
        let open = store.assignment(assignment.id)?.done == false
        return VStack(spacing: 14) {
            header("SESSION COMPLETE", assignment.title)
            Text("🎉").font(.system(size: 44))
            Text("\(studySpan(planMinutes(run.plan))) done")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
            // Only while the work is still open: the finished screen shouldn't
            // hand you a button that un-ticks it. (The web's XP line waits
            // for Phase 12.)
            if open {
                Button {
                    store.toggleAssignment(assignment.id)
                    dismiss()
                } label: {
                    Label("Mark it done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            Button { phase = .setup } label: {
                Text("Another session").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            Button("Close") { dismiss() }
                .frame(minHeight: 44)
        }
    }

    /// Focus mode: the round, what you're on, the time, a thin bar, and
    /// Pause / Resume and Exit. Nothing else. It only draws: the clock under
    /// it keeps running and recording, so finished blocks are counted once.
    @ViewBuilder
    private var zenView: some View {
        let accent = store.profile.accent
        ZStack {
            Theme.canvas.ignoresSafeArea()
            switch phase {
            case .running(let run):
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    zenFace(run, runPosition(run, at: context.date), paused: false, accent: accent)
                }
            case .paused(let run):
                zenFace(run, RunPosition(index: run.index, remaining: run.left, finished: false),
                        paused: true, accent: accent)
            case .setup, .done:
                // The session ended underneath: nothing to show, so leave.
                Color.clear.onAppear { zen = false }
            }
        }
        .tint(Theme.brand(accent))
    }

    private func zenFace(_ run: StudyRun, _ position: RunPosition, paused: Bool,
                         accent: Profile.Accent) -> some View {
        let index = min(position.index, run.plan.count - 1)
        let block = run.plan[index]
        let isBreak = block.kind == .rest
        let total = Double(block.minutes * 60)
        let gone = total > 0 ? 1 - min(1, position.remaining / total) : 0
        let color = isBreak ? Theme.good : Theme.brand(accent)
        let rounds = focusCount(run.plan)

        return VStack(spacing: 0) {
            Text(isBreak ? "BREAK" : rounds > 1 ? "ROUND \(roundAt(run.plan, index)) OF \(rounds)" : "FOCUS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            Text(isBreak ? "Rest" : assignment.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.top, 10)
            Text(studyClock(position.remaining))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .padding(.top, 24)
            // The thin bar: a track, and the share that's gone laid over it.
            Capsule()
                .fill(Theme.surface2)
                .frame(width: 220, height: 3)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: 220 * gone, height: 3)
                }
                .padding(.top, 32)
            HStack(spacing: 10) {
                Button(paused ? "Resume" : "Pause") {
                    if paused { resume(run) } else { pause(run) }
                }
                .buttonStyle(.bordered)
                Button("Exit") { zen = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 40)
        }
        .padding(.horizontal, 32)
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift` (replaces your 8d file)

Changed spots:

- **Header** (changed).
- **`@State private var studying`** (new).
- **What to do about it** (changed): Complete and Start studying in one row,
  with the timer's sheet on that row.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift
//  Phase:   4b (the Tasks screen), changed in 7b (the planning cards),
//           8d (linked notes, and Open the class) and 10a (Start studying)
//  Ports:   app/tasks/[id]/page.tsx (header, Complete, notes, details,
//           exam prep, reminders, Plan the work, checklist, linked notes,
//           Open the class, delete)
//
//  Summary: One assignment in full: its class, title and deadline, a big
//           Complete / Mark as open button, the brief, the details, and its
//           checklist. Since 7b, while it's open, also its exam prep (for a
//           dated exam), its reminder controls and the day you plan to work
//           on it. Since 8d, the notes linked to it (open, unlink, link one
//           more or start a new one) and a row that opens its class's notes.
//           Edit opens the form in a sheet; Delete moves it to Recently
//           Deleted and returns to the list, where Undo is offered. Since
//           10a, Start studying opens the study timer beside Complete. The
//           grade prompt joins later.
//

import SwiftUI

struct AssignmentDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Which assignment to show. Only the id is kept; the assignment itself
    /// is looked up in the store on every redraw, so this screen is never stale.
    let assignmentID: UUID

    /// The assignment open in the edit sheet, or nil when no sheet is showing.
    /// `.sheet(item:)` shows the sheet whenever this is non-nil, hands the
    /// value to the sheet's content, and sets it back to nil when the sheet closes.
    @State private var editing: Assignment? = nil

    /// What's typed in the "Add a smaller step" field.
    @State private var newStep = ""

    /// NEW in Phase 8d: the note New note just started, while it's open
    /// (the Notes tab's `startedNote`, 8a).
    @State private var startedNote: UUID?

    /// NEW in Phase 10a: true while the study timer's sheet is open.
    @State private var studying = false

    var body: some View {
        // Gone (just deleted, or never existed): a short note instead of a crash.
        if let a = store.assignment(assignmentID) {
            content(a)
        } else {
            ContentUnavailableView("Assignment not found.", systemImage: "doc.questionmark")
        }
    }

    /// The screen for an assignment that exists.
    private func content(_ a: Assignment) -> some View {
        let accent = store.profile.accent
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, .now)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Task and checklist changes save here, so failures must be
                // visible before the student returns to the list.
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                }

                // MARK: What it is
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(course.map { Theme.subject($0.color) } ?? Theme.lineStrong)
                            .frame(width: 9, height: 9)
                        Text(course?.name ?? "Inbox")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        if course?.archived == true {
                            Text("Archived")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .foregroundStyle(Theme.faint)
                                .background(Theme.surface2, in: Capsule())
                        }
                    }
                    Text(a.title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .strikethrough(a.done)
                    // "Due tomorrow · Tuesday, Sep 8 · 2:30 PM", red when urgent.
                    Text(a.due == nil ? due.text : "\(due.text) · \(longDeadline(a.deadline))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(due.urgent ? Theme.dangerInk : Theme.muted)
                }
                .padding(.horizontal, 4)

                // MARK: What to do about it
                // Brand gradient while open; a quiet grey "Mark as open" once done.
                // CHANGED in Phase 10a: in a row with Start studying, as on the
                // web, for open work that isn't a reminder (nothing to study).
                HStack(spacing: 10) {
                    Button {
                        store.toggleAssignment(a.id)
                    } label: {
                        Label(a.done ? "Mark as open" : "Complete", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(a.done ? Theme.muted : Color.white)
                            .background {
                                if a.done {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface2)
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.brandGradient(accent))
                                }
                            }
                    }
                    .buttonStyle(.plain)

                    if !a.done && a.kind != .reminder {
                        Button {
                            studying = true
                        } label: {
                            Label("Start studying", systemImage: "timer")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .foregroundStyle(Theme.ink)
                                .background(Theme.surface2,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                // NEW in Phase 10a: the timer, in a sheet that opens full height.
                .sheet(isPresented: $studying) {
                    StudyTimerView(assignment: a)
                        .presentationDetents([.large])
                }

                // MARK: The brief
                if let notes = a.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    card {
                        sectionLabel("Notes")
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // MARK: Details
                card {
                    detailRow("Type", a.kind.label)
                    Divider()
                    detailRow("Due", a.due == nil ? "No deadline yet" : longDeadline(a.deadline))
                    // NEW in Phase 7b: minutes recorded against it (the study
                    // timer, Phase 10, is what records them).
                    Divider()
                    let focused = store.focusedMinutes(a.id)
                    detailRow("Focused", focused > 0 ? "\(focused) min recorded" : "No sessions yet")
                    if let rule = a.repeatRule {
                        Divider()
                        detailRow("Repeats", "\(rule == .weekly ? "Weekly" : "Monthly")"
                                  + (a.repeatUntil.map { " through \($0)" } ?? ""))
                    }
                    Divider()
                    // Keep the summary in step with the card when a snooze expires.
                    TimelineView(.everyMinute) { context in
                        detailRow("Reminder", reminderSummary(a, now: context.date))
                    }
                }

                // MARK: Planning
                // NEW in Phase 7b: the three planning cards, in the web's
                // order, only while the work is still open.
                if !a.done {
                    // An undated exam has no week before it to plan (D-32).
                    if a.kind == .exam && a.due != nil {
                        ExamPrepCard(assignment: a)
                    }
                    TaskReminderCard(assignment: a)
                    PlanWorkCard(assignment: a, plannedDay: store.taskPlan(for: a.id)?.date)
                }

                // MARK: Checklist
                card {
                    HStack {
                        sectionLabel("Checklist")
                        Spacer()
                        Text("\(a.subtasks.filter { $0.done }.count)/\(a.subtasks.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(a.subtasks) { step in
                        Button {
                            store.toggleSubtask(step.id, in: a.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.done ? Theme.brand(accent) : Theme.lineStrong)
                                Text(step.title)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Theme.ink)
                                    .strikethrough(step.done)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    // Type a step and press return (or +) to add it.
                    HStack(spacing: 8) {
                        TextField("Add a smaller step", text: $newStep)
                            .font(.system(size: 13.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onSubmit { addStep(to: a.id) }
                        Button {
                            addStep(to: a.id)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.brand(accent))
                                .frame(width: 40, height: 40)
                                .background(Theme.brand(accent).opacity(0.16),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add checklist item")
                    }
                }

                // MARK: Linked notes
                // NEW in Phase 8d: the notes about this work, then a way to
                // link one more or start one. Always shown, done or not, as
                // on the web.
                linkedNotesCard(a)

                // NEW in Phase 8d: the class's notes, one tap away. Only for
                // work that has a class; the Inbox has no notes page.
                if let course {
                    NavigationLink(value: CourseNotesLink(id: course.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "book")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.muted)
                            Text("Open \(course.name)")
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.hint)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }

                // MARK: Delete
                // One tap, as on the web detail page: it's a soft delete, Undo
                // shows on the list, and nothing is erased.
                Button {
                    store.deleteAssignment(a.id)
                    dismiss()   // back to the list, where the Undo bar is waiting
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(Theme.dangerInk)
                        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                Text("Deleted assignments are kept for 30 days and can be restored.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = a }
            }
        }
        // The edit form in its own sheet, with its own navigation bar for the
        // title, Save and Cancel. Saving closes the sheet (the form's dismiss).
        .sheet(item: $editing) { original in
            NavigationStack {
                AssignmentFormView(editing: original)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editing = nil }
                        }
                    }
            }
        }
        // NEW in Phase 8d: where the note links lead. This screen is pushed
        // on the Tasks tab and on Today, whose stacks don't know about notes,
        // so it registers the two note screens itself. A destination works
        // for the whole stack while the screen that registered it is in it,
        // so a class's notes opened from here can open their notes too.
        .navigationDestination(for: NoteLink.self) { link in
            NoteView(noteID: link.id)
        }
        .navigationDestination(for: CourseNotesLink.self) { link in
            CourseNotesView(courseID: link.id)
        }
        // And New note: open the note it just started.
        .navigationDestination(item: $startedNote) { id in
            NoteView(noteID: id)
        }
        // NEW in Phase 8d: a linked note deleted from its own screen comes
        // back to here, so Undo waits here, as on the Notes tab.
        .undoBar()
    }

    // MARK: - Pieces

    /// A rounded card holding a section, with the app's card surface.
    private func card<Content: View>(@ViewBuilder _ inside: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { inside() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }

    /// A small capital-letter section label, like the web's "NOTES".
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// One "label ... value" line in the details card. `DetailRow` on the web.
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 13.5))
    }

    /// What the Reminder row says. It names a snooze first: someone asking
    /// "why did this go quiet?" is looking right here. `reminderSummary`.
    // CHANGED in Phase 7b: snoozes and early warnings
    private func reminderSummary(_ a: Assignment, now: Date) -> String {
        if !a.reminder { return "Off" }
        if isSnoozed(a.snoozedUntil, now) { return "Snoozed" }
        if a.due == nil { return "On once it has a deadline" }
        let leads = effectiveLeads(a)
        // `leads.first` is the longest warning, since they're sorted longest first.
        if let first = leads.first { return "Nudging, from \(leadLabel(first)) before" }
        return "Nudging until it's done"
    }

    /// Adds the typed step to the checklist and clears the field.
    private func addStep(to id: UUID) {
        store.addSubtask(newStep, to: id)
        newStep = ""
    }

    /// NEW in Phase 8d: the Linked notes card. Each linked note opens on
    /// tap, with Unlink beside it (which only takes the link away, the note
    /// stays). Under them, a menu of the notes that could be linked, and New
    /// note, which starts one for this work's class, linked from the start.
    /// The "Linked notes" section of app/tasks/[id]/page.tsx.
    private func linkedNotesCard(_ a: Assignment) -> some View {
        let accent = store.profile.accent
        let linked = store.linkedNotes(for: a.id)
        let linkable = store.linkableNotes(for: a)

        return card {
            sectionLabel("Linked notes")

            // One row per linked note: the note, then Unlink. Side by side,
            // not one inside the other, so Unlink can't also open the note.
            ForEach(linked) { note in
                let title = noteTitle(title: note.title, body: note.body)
                HStack(spacing: 0) {
                    NavigationLink(value: NoteLink(id: note.id)) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button("Unlink") {
                        store.linkNote(note.id, to: nil)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    // "Unlink Week 3", the web's label, so VoiceOver says which.
                    .accessibilityLabel("Unlink \(title)")
                }
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 8) {
                // A `Menu` (8c) whose buttons come from the data: one per
                // note that could be linked. Picking one links it, and it
                // moves up into the list above. Greyed out when none could.
                Menu {
                    ForEach(linkable) { note in
                        Button(noteTitle(title: note.title, body: note.body)) {
                            store.linkNote(note.id, to: a.id)
                        }
                    }
                } label: {
                    HStack {
                        Text("Link an existing note")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(linkable.isEmpty)
                .opacity(linkable.isEmpty ? 0.5 : 1)

                // Today's date, this work's class (none for the Inbox, which
                // makes a quick note) and the link, then straight into it.
                Button {
                    startedNote = store.addNote(courseID: a.courseID, date: dayOf(.now),
                                                assignmentID: a.id)
                } label: {
                    Text("New note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(Theme.brandSoft(accent),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

### 4.8 Tests (copy these, don't type them)

```bash
cd ~/ClassPing
REF=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $REF/Logic/StudyTests.swift Tests/Logic/            # new: 21 tests
cp $REF/Persistence/StudyStoreTests.swift Tests/Store/  # new: 3 tests
```

Your scripts need no changes: `test-logic.sh` copies every `Logic/*.swift`,
and `test-store.sh` already lists `Store+Planning` and copies every test file
in `Tests/Store`.

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 392 tests passing
scripts/test-store.sh     # expect 82 tests passing
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself. Use a
throwaway task for the timed checks.

1. **Setup:** open an assignment (not a reminder). **Start studying** sits next
   to Complete. The sheet says WORKING ON and the title, with One block and
   Pomodoro. Tap **Pomodoro**: Focus block and Rounds chips, and "4 × 25 min,
   5 min breaks, 1h 55m in all". Tap 15 and 2: "2 × 15 min, 5 min breaks,
   35 min in all". Back to **One block**.
2. **The number field:** tap the field next to OR SET, type 1. The button
   reads "Start 1 minutes". **Done** above the number pad puts it away.
3. **Run and pause:** **Start 1 minutes**. The ring fills and the time counts
   down. **Pause**: "Paused", the time stops. **Resume**.
4. **Pocket test:** go to the home screen and back (that runs a reminder
   sync), then lock the phone. At the end of the minute: "Session complete",
   "1 min on "your task". Nice work." Unlock and open the app: 🎉 "1 min
   done". **Close**: the Focused row says "1 min recorded".
5. **Stop:** start 1 minute again and tap **Stop** at once: back to setup.
   Wait a minute: no alert.
6. **Focus mode:** start, then **Focus mode**: just the label, the title, a big
   clock and a thin bar. **Pause** / **Resume**, then **Exit**.
7. **No accidental close:** while it runs, swipe the sheet down: it stays.
   No Close button until you Stop or it ends.
8. **Mark it done:** let a 1-minute block finish, then **Mark it done**: the
   sheet closes and the task is complete.
9. **Pomodoro, when you have time:** 2 rounds of 15 with the phone locked.
   Alerts at 15 ("Break time"), 20 ("Round 2 of 2") and 35 ("Session
   complete"), and 30 minutes recorded.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] The tree builds without warnings; 392 logic and 82 store tests pass.
- [ ] Setup, the number field and both modes behave as in steps 1 and 2.
- [ ] A locked phone gets the alert at the end of the block, after coming
      back to the app mid-session (step 4).
- [ ] Stop cancels the alert; Focus mode, Pause and Resume work.
- [ ] Finished blocks show in the Focused row; Mark it done completes the task.

## 7. If it breaks

- **Keyword 'break' cannot be used as an identifier:** the second block kind
  is `rest`, not `break`.
- **Cannot find 'studyAlertPrefix' in scope (in ClassPingApp or
  Store+Notifications):** it's declared in 4.1, near `StudyAlert`.
- **No alert with the phone locked:** check Settings → ClassPing →
  Notifications is on, and that a Focus mode (Do Not Disturb, Sleep) isn't
  holding it. The first Start asks for permission if iOS never has.
- **The alert never comes after you go home and back:** step 5 of
  `replaceReminders` still calls `removeAllPendingNotificationRequests()` on
  its own. It must keep study ids while `studyAlertCount > 0`.
- **The ring and time don't move:** the running case must be inside
  `TimelineView(.periodic(from: .now, by: 0.5))`.
- **Each block shows up twice in the Focused row:** the `.onChange` that calls
  `advance` belongs on the main face only (`live`), not on the focus-mode face.

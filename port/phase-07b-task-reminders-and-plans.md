---
title: "Phase 7b: One task's reminders, and planning the work"
date: 2026-10-17
generated_by: skills-for-architects
---

# Phase 7b: One task's reminders, and planning the work

*Second of three parts of Phase 7 (D-29). Checked on 2026-10-17 on top of your Phase 7a commit `2bb4a69`: `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 174/174 (15 new: 13 twins of `lib/exam-prep.test.ts`, 2 from `lib/planning.test.ts`), and `persistence-test.sh` passed 17/17 (5 new for this phase's store actions, plus your own 3 from `ReminderStoreTests`). Nothing here has been on a phone yet.*

**Before you start:** 7a is committed (`2bb4a69`). Run its section 5 steps on the phone if you haven't yet, at least the class alarm (step 3) and the daily nudge (step 4). This phase leans on 7a's sync: a snooze only silences the phone because 7a notices the change. If 7a's notifications don't arrive, fix that first, or you'll be debugging two phases at once.

## 1. Goal

A task's detail gets the controls that belong to that one piece of work: its reminder, earlier warnings and snooze; for an exam, a plan for the week before it; and for any task, the day you mean to work on it.

**On your phone:** open an open assignment. The details card gains a **Focused** row ("No sessions yet" until the Phase 10 timer records some) and the **Reminder** row now says things like "Nudging, from 3 days before" or "Snoozed". Under the details, three cards:

- **Reminders**: the daily nudge switch; **Warn me early** with three chips, 1 week, 3 days, 2 days, lit when on, and a line saying what you'll get; **Not now** with four chips, 1 hour, 3 hours, This evening, Tomorrow. Snooze it and the chips give way to "Snoozed until tomorrow 8:00 AM." with **Wake it**.
- **Exam prep** (dated exams only): "5 days to go", "A 4-step plan working back from the exam, 45 minutes a session.", a progress bar with "0 of 180 minutes focused", **Build the plan** (the steps land on the checklist below) and **Study on Oct 17** (plans the next session).
- **Plan the work**: a date, **Plan** (or **Move** once planned), and "Remove from Saturday, Oct 17".

Complete the task and all three cards go away; reopen it and they come back.

## 2. New Swift concepts

**`LazyVGrid` with an adaptive column.** The web lays chips out with `flex-wrap`: as many as fit on a row, then the next row. SwiftUI's nearest tool is a grid whose column count depends on the width. One `.adaptive(minimum:)` column means "as many columns of at least this width as fit, stretched to share the space":

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
          alignment: .leading, spacing: 8) {
    ForEach(SnoozePreset.allCases) { preset in
        chip(preset.label) { store.snooze(a.id, preset) }
    }
}
```

On a phone that fits three columns: the three warning chips make one row, the four snooze chips a row of three and a row of one. ("Lazy" means it only builds the cells on screen, which matters for long grids, not for four chips.)

**`ProgressView(value:)`.** A bar filled from 0 (empty) to 1 (full). The exam card passes how much of the plan's minutes you've logged, `progress.ratio`, and tints it with your accent:

```swift
ProgressView(value: 0.4)          // 40% full
    .tint(Theme.brand(accent))
```

**A date-only `DatePicker` over a stored day.** In 5b you bound a time picker to minutes from midnight with `Binding(get:set:)`. A plan stores its day as text ("2026-10-17"), so the binding converts both ways again, this time with `displayedComponents: .date`:

```swift
DatePicker("Work day", selection: Binding(
    get: { deadlineDayStart(Deadline(date: day, time: nil)) ?? .now },   // text -> Date
    set: { day = dayOf($0) }),                                          // Date -> text
    displayedComponents: .date)
```

You'll also meet: **`compactMap`**, which maps and drops every `nil` in one go (how the exam ladder leaves out steps whose day has gone, with no loop to skip through); **a `Text` inside a `Text`** ("Snoozed until **tomorrow 8:00 AM**." with only the time in bold); **`private` at the top of a file**, so the two cards in `PlanningCards.swift` share one helper that nothing else can see; and **`+=` on an array**, which adds a whole list to the end of another.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/exam-prep.ts` | `Logic/ExamPrep.swift` | Same five steps, words, 45 minutes, and the same rules for dropping past steps. `prepSubtasks` and `hasPrepLadder` take and give checklist titles, because Logic files can't see the `Subtask` model; the store makes the rows |
| `studyMinutes` in `lib/planning.ts` | `Logic/Planning.swift` | Same filters. The rest of `planning.ts` waits for the code that calls it (D-31) |
| `TaskReminderCard` in `components/TaskReminders.tsx` | `Screens/Tasks/TaskReminderCard.swift` | Same switch, chips, sentences and snooze. The snooze time reads "tomorrow 8:00 AM" (the web writes 08:00): the phone uses the 12-hour clock everywhere |
| `ExamPrepCard` | `Screens/Tasks/PlanningCards.swift` | Same. "Study on Oct 17" (the web writes 10/17). Only for an exam that has a date: the web's card says "It's today. Good luck." for an undated exam (D-32) |
| "Plan the work" in `app/tasks/[id]/page.tsx` | `PlanWorkCard`, same file | Same. "Remove from Saturday, Oct 17" (the web prints 2026-10-17) |
| `updateTask(id, { reminder, remindLeads, snoozedUntil, subtasks })` from the cards | `setReminder`, `toggleLead`, `snooze`, `wake`, `addPrepSteps` in `Store+Planning.swift` | One named action each, instead of one "update these fields" call: easier to test, and each can't touch more than it means to |
| `planTask`, `removeTaskPlan` in `lib/store.tsx` | `Store+Planning.swift` | Same: one plan per task, moving clears its priority, the deadline never moves |
| `reminderSummary` and the Focused row in `app/tasks/[id]/page.tsx` | `AssignmentDetailView` | Same words |

## 4. Files, in the order to type them

4.1 to 4.3 are logic and the protocol sign-up, so they build on their own. 4.4 needs them; 4.5 to 4.7 need 4.4. Build after 4.7.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Planning.swift` (replaces the file)

The header and everything after `nextRepeatDate` are new; `nextRepeatDate` is exactly as you have it.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Planning.swift
//  Phase:   4a (task logic and the add form), changed in 7b (study minutes)
//  Ports:   lib/planning.ts (`nextRepeatDate`, and since 7b `studyMinutes`)
//
//  Summary: Works out the next due day of a repeating assignment: a week
//           later, or the same day next month, clamped to the month's last day
//           (Jan 31 repeats on Feb 28, or Feb 29 in a leap year). Since 7b it
//           also totals the minutes of focused work recorded against a task.
//
//  Foundation only, so tools/logic-test.sh can test it on Linux.
//
//  Not ported (and why, D-31): `localDateKey` is `dayOf` in Deadline.swift.
//  `normalizeTaskPlans` and `normalizeStudySessions` repair merged or
//  restored data, so they arrive with backup restore (Phase 11) and sync
//  (Phase 14). `plansForDate` and `priorityPlans` have no caller (D-23).
//

import Foundation
// The next due day after `date` ("yyyy-MM-dd") for a task that repeats
/// `rule` ("weekly" or "monthly"), or nil when the date is broken or the rule
/// is unknown. `nextRepeatDate` in lib/planning.ts.
/// The rule arrives as text because `Assignment.RepeatRule` lives in
/// Models.swift; the store passes `rule.rawValue`.
func nextRepeatDate(_ date: String, _ rule: String) -> String? {
    //refusing anything that isnt a real calender date
    guard isValidDate(date) else {return nil}

    //pull out the three numbers. 'isValidDate' proves there are three

    let p = date.split(separator: "-").map { Int($0) ?? 0}
    let (year, month, day) = (p[0], p[1], p[2])
    // Do the calendar maths in a fixed Gregorian calendar on UTC, so no time
    // zone or daylight-saving change can nudge the day (a pure day count,
    // the way the web avoids UTC parsing).

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current

    //weekly: seven dats on : date(byAdding:) handles month and year ends.
    if rule == "weekly" {
        let start = cal.date(from: DateComponents(year: year, month: month, day: day))
        guard let start, let next = cal.date(byAdding: .day, value: 7, to: start) else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: next)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // Monthly: the same day number next month, or that month's last day if the
    // month is shorter. December rolls into January of the next year.
    if rule == "monthly" {
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        // How many days the next month has: ask the calendar for the range of
        // day numbers in the month containing its 1st.
        let first = cal.date(from: DateComponents(year: nextYear, month: nextMonth, day: 1))
        guard let first, let days = cal.range(of: .day, in: .month, for: first) else { return nil }
        return String(format: "%04d-%02d-%02d", nextYear, nextMonth, min(day, days.count))
    }

    // Any other rule: no next date.
    return nil
}

// MARK: - Study records
// NEW in Phase 7b

/// Anything that records one finished block of focused work. `StudySession`
/// (Records.swift) signs up in Models+Reminders.swift: Logic files can't see
/// the models, so `studyMinutes` asks for this instead, the same trick as
/// `Dated` in Phase 2.
protocol StudyRecord {
    var assignmentID: UUID? { get }
    var courseID: UUID? { get }
    var minutes: Int { get }
    var completedAt: Date { get }
}

/// Minutes of focused work in `sessions`, optionally only for one task, one
/// class, or since a moment. `studyMinutes` in lib/planning.ts. A filter
/// left as nil lets everything through.
func studyMinutes<S: StudyRecord>(_ sessions: [S], taskID: UUID? = nil,
                                  courseID: UUID? = nil, since: Date? = nil) -> Int {
    sessions
        .filter { s in
            // `taskID.map { ... } ?? true` reads: if there is a taskID, does
            // this session match it? If there's none, it passes.
            (taskID.map { s.assignmentID == $0 } ?? true)
                && (courseID.map { s.courseID == $0 } ?? true)
                && (since.map { s.completedAt >= $0 } ?? true)
        }
        // Add up what's left. `reduce` starts at 0 and adds each session's minutes.
        .reduce(0) { total, s in total + s.minutes }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/ExamPrep.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ExamPrep.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   lib/exam-prep.ts (the whole file)
//
//  Summary: Turns an exam's date into a plan for the week before it: up to
//           five dated steps, each with something specific to do, counted back
//           from the exam. The steps become lines on the exam's own checklist,
//           so there's nothing new to store or sync. Also measures how the
//           preparation is going. Foundation only, for the Linux tests.
//

import Foundation

/// One rung of the ladder before it's pinned to a date.
private struct StepTemplate {
    let daysBefore: Int
    let focus: String
}

/// The ladder, furthest from the exam first. Five steps rather than seven: a
/// plan a student finishes beats one that's honest about how much revision is
/// possible. The gaps shrink near the exam, because those days get used.
/// `LADDER` in lib/exam-prep.ts.
private let ladder = [
    StepTemplate(daysBefore: 7, focus: "Gather everything, notes, slides, past papers"),
    StepTemplate(daysBefore: 5, focus: "First full pass through the material"),
    StepTemplate(daysBefore: 3, focus: "Practice questions under time"),
    StepTemplate(daysBefore: 2, focus: "Fix the weak spots that pass found"),
    StepTemplate(daysBefore: 1, focus: "Final review, formulas, definitions, dates"),
]

/// Minutes of focused work each step is meant to take. `MINUTES_PER_STEP`.
let minutesPerStep = 45

/// One step of the plan, pinned to a day. `PrepStep` in the web.
struct PrepStep: Equatable {
    let daysBefore: Int
    let date: String     // "yyyy-MM-dd", the local day it falls on
    let focus: String    // what to do that day
    let title: String    // the checklist line it becomes
}

/// Moves a "yyyy-MM-dd" day by whole days, as pure calendar days on a fixed
/// UTC calendar, so no time zone or daylight-saving change can nudge it (the
/// same way `nextRepeatDate` counts). `shiftDay` in lib/exam-prep.ts.
private func shiftDay(_ date: String, _ days: Int) -> String? {
    guard isValidDate(date) else { return nil }
    let p = date.split(separator: "-").map { Int($0) ?? 0 }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    guard let start = cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])),
          let moved = cal.date(byAdding: .day, value: days, to: start) else { return nil }
    let c = cal.dateComponents([.year, .month, .day], from: moved)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

/// The plan for an exam on `examDate`, as seen from `now`. `prepLadder`.
/// Steps already in the past are left out rather than back-dated: a plan that
/// opens with "seven days before" three days out tells the student they've
/// already failed. An exam that's today, past or undated gets nothing.
func prepLadder(_ examDate: String?, _ now: Date) -> [PrepStep] {
    guard isValidDate(examDate), let examDate else { return [] }
    let today = dayOf(now)
    // Day strings compare like dates, so this means "the exam is after today".
    guard examDate > today else { return [] }

    // `compactMap` keeps what the closure returns and drops each `nil`, so
    // the steps whose day has gone simply disappear: no loop, no skipping.
    return ladder.compactMap { step in
        guard let date = shiftDay(examDate, -step.daysBefore), date >= today else { return nil }
        let days = "\(step.daysBefore) day\(step.daysBefore == 1 ? "" : "s")"
        return PrepStep(daysBefore: step.daysBefore, date: date, focus: step.focus,
                        title: "\(days) before · \(step.focus)")
    }
}

/// Does this checklist already carry a plan? `hasPrepLadder`. Checked from
/// the line titles rather than a stored flag: the checklist is the student's
/// to edit, and a flag would keep claiming a plan after every line was deleted.
/// The web passes the task; this takes its checklist's titles.
func hasPrepLadder(_ titles: [String]) -> Bool {
    ladder.contains { step in
        titles.contains { $0.hasPrefix("\(step.daysBefore) day") && $0.contains(step.focus) }
    }
}

/// The day of the next step still ahead (or today), or nil. `nextPrepDate`:
/// where "Study on ..." plans the next session.
func nextPrepDate(_ steps: [PrepStep], _ now: Date) -> String? {
    let today = dayOf(now)
    return steps.first(where: { $0.date >= today })?.date
}

/// How the preparation is going. `PrepProgress` in the web.
struct PrepProgress: Equatable {
    /// Whole days from today to the exam. Negative once it has passed.
    var daysLeft: Int
    /// Minutes of focused work recorded against this exam.
    var logged: Int
    /// Minutes the steps still ahead are meant to take.
    var target: Int
    /// 0 to 1. Exactly 1 when the target is met or nothing is left to do.
    var ratio: Double
}

/// Time left, time logged, and what the plan asks for. `prepProgress`. The
/// target counts only the steps still ahead: measuring against steps that
/// can no longer be climbed would report failure for time that simply passed.
/// The web takes the task; this takes its id and date.
func prepProgress<S: StudyRecord>(examID: UUID, examDate: String?,
                                  sessions: [S], now: Date) -> PrepProgress {
    let target = prepLadder(examDate, now).count * minutesPerStep
    let logged = studyMinutes(sessions, taskID: examID)
    // Days between two calendar days: their day numbers (Time.swift) apart.
    let daysLeft: Int
    if let examDate, let exam = dayNumber(examDate) {
        daysLeft = exam - todayNumber(now)
    } else {
        daysLeft = 0
    }
    // `min(1, max(0, ...))` holds the ratio between 0 and 1.
    let ratio = target == 0 ? 1 : min(1, max(0, Double(logged) / Double(target)))
    return PrepProgress(daysLeft: daysLeft, logged: logged, target: target, ratio: ratio)
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Models+Reminders.swift` (replaces the file)

The header and the last extension change.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Reminders.swift
//  Phase:   7a (reminders ring), changed in 7b (StudySession)
//  Ports:   nothing new: it connects the models to Logic/Reminders.swift,
//           Logic/ReminderPlan.swift and, since 7b, Logic/Planning.swift
//
//  Summary: Signs Course and Assignment up for the reminder logic, and
//           StudySession for the study-minute totals. Each already has every
//           field its protocol asks for, so the extensions are empty, like
//           `extension Assignment: Dated {}`.
//

import Foundation

/// Course has a name, `alarm`, `remindBefore` and `archived`, plus the
/// meetings `Schedulable` already covers, so the planner can read it.
extension Course: Alarmable {}

/// Assignment has `id`, `reminder`, `done`, `remindLeads` and
/// `snoozedUntil`, and is already `TaskListable` (Assignment+TaskView.swift).
extension Assignment: Remindable {}

/// StudySession has `assignmentID`, `courseID`, `minutes` and `completedAt`,
/// so `studyMinutes` can total real sessions. (They start arriving with the
/// study timer in Phase 10; until then every total is 0.)
// NEW in Phase 7b
extension StudySession: StudyRecord {}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Planning.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Planning.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   lib/store.tsx (planTask, removeTaskPlan) and the updateTask calls
//           made by TaskReminderCard and ExamPrepCard in
//           components/TaskReminders.tsx
//
//  Summary: Everything the task detail's three planning cards change: the
//           reminder switch, early warnings and snooze; the exam plan's
//           checklist steps; and the day you mean to work on it. Each action
//           saves straight away, and 7a's reminder sync notices the change
//           by itself, so a snooze silences the phone within a second.
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

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Tasks/TaskReminderCard.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/TaskReminderCard.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   TaskReminderCard in components/TaskReminders.tsx
//
//  Summary: The Reminders card on a task's detail: the daily nudge switch,
//           "Warn me early" (1 week, 3 days, 2 days before), and "Not now",
//           four ways to snooze it, or, while it's snoozed, until when and a
//           Wake it button. These live on the task, not in Profile, because
//           they belong to this piece of work.
//

import SwiftUI

struct TaskReminderCard: View {
    @Environment(Store.self) private var store

    /// The task, freshly looked up by the detail screen on every redraw.
    let assignment: Assignment

    var body: some View {
        // Redraw every minute (`TimelineView`, 5a), so a snooze that runs out
        // turns back into the four buttons by itself.
        TimelineView(.everyMinute) { context in
            content(context.date)
        }
    }

    /// The card at a given moment.
    private func content(_ now: Date) -> some View {
        let a = assignment
        let accent = store.profile.accent
        let leads = effectiveLeads(a)
        let chosen = normalizeLeads(a.remindLeads) != nil

        return VStack(alignment: .leading, spacing: 14) {
            // MARK: The switch
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("Reminders")
                    Text(a.due == nil
                         ? "Give this a deadline and we can nudge you about it."
                         : a.reminder
                            ? "A nudge each day from 24 hours out, until it's ticked off."
                            : "No nudges for this one.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                // A Binding(get:set:) (5b): reads the task, writes through the store.
                Toggle("Reminders", isOn: Binding(get: { a.reminder },
                                                  set: { store.setReminder($0, for: a.id) }))
                    .labelsHidden()
            }

            // The rest only matters for a dated task with its reminder on.
            if a.reminder && a.due != nil {
                // MARK: Warn me early
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Warn me early")
                    chipGrid {
                        ForEach(leadChoices) { choice in
                            chip(choice.label, on: leads.contains(choice.minutes), accent) {
                                store.toggleLead(choice.minutes, for: a.id)
                            }
                        }
                    }
                    Text(leadCaption(leads, chosen: chosen))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // MARK: Not now
                if isSnoozed(a.snoozedUntil, now), let until = a.snoozedUntil {
                    // Snoozed: say until when, and offer to end it early.
                    HStack(spacing: 12) {
                        // A `Text` can be dropped into another Text's string,
                        // so one sentence can have a bold part in the middle.
                        Text("Snoozed until \(Text(snoozeLabel(until, now)).fontWeight(.semibold).foregroundStyle(Theme.ink)).")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                        Spacer(minLength: 8)
                        Button {
                            store.wake(a.id)
                        } label: {
                            Text("Wake it")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.brand(accent))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(Theme.brandSoft(accent),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Not now")
                        chipGrid {
                            // `allCases` (from CaseIterable) lists the four presets in order.
                            ForEach(SnoozePreset.allCases) { preset in
                                chip(preset.label, on: false, accent) {
                                    store.snooze(a.id, preset, now: now)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Pieces

    /// The line under the warning chips. The same three sentences as the web.
    private func leadCaption(_ leads: [Int], chosen: Bool) -> String {
        if leads.isEmpty { return "Just the daily nudge." }
        let names = leads.map(leadLabel).joined(separator: ", ")
        return chosen
            ? "One heads-up at \(names) before."
            : "Exams get \(names) by default, tap to change."
    }

    /// "8:00 AM", "tomorrow 8:00 AM" or "Sep 12 6:00 PM": enough to trust a
    /// snooze. `whenLabel` in TaskReminders.tsx, which writes the time as
    /// 08:00; the phone uses the 12-hour clock it shows everywhere else.
    private func snoozeLabel(_ until: Date, _ now: Date) -> String {
        let time = fmtTime(minuteOfDay(until))
        if dayOf(until) == dayOf(now) { return time }
        if dayOf(until) == dayOf(scheduleDate(now, 1)) { return "tomorrow \(time)" }
        return "\(fmtMD(until)) \(time)"
    }

    /// Chips that wrap onto another row when they don't fit. A `LazyVGrid`
    /// with one `.adaptive` column fits as many columns of at least 100 points
    /// as the width allows, and stretches them to share it. On the web,
    /// `flex-wrap` does the same job.
    private func chipGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                  alignment: .leading, spacing: 8) {
            content()
        }
    }

    /// One chip: brand-filled when on, a quiet grey when off.
    private func chip(_ label: String, on: Bool, _ accent: Profile.Accent,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? Color.white : Theme.muted2)
                .background(on ? Theme.brand(accent) : Theme.surface2,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A small capital-letter label, like the web's "REMINDERS".
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Tasks/PlanningCards.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/PlanningCards.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   ExamPrepCard in components/TaskReminders.tsx, and the "Plan the
//           work" section of app/tasks/[id]/page.tsx
//
//  Summary: The two cards on a task's detail that plan when you'll work on
//           it. Exam prep counts back from an exam: a five-step plan for the
//           checklist, minutes focused against minutes planned, and a button
//           to plan the next session. Plan the work puts any task on a day
//           of your choosing without touching its deadline.
//

import SwiftUI

// MARK: - Exam prep

struct ExamPrepCard: View {
    @Environment(Store.self) private var store

    /// The exam, freshly looked up by the detail screen. Always dated: the
    /// detail only shows this card for an exam with a date (D-32).
    let assignment: Assignment

    var body: some View {
        let a = assignment
        let now = Date.now
        let accent = store.profile.accent
        let steps = prepLadder(a.due, now)
        let progress = prepProgress(examID: a.id, examDate: a.due,
                                    sessions: store.studySessions, now: now)
        let built = hasPrepLadder(a.subtasks.map(\.title))
        let next = nextPrepDate(steps, now)
        let planned = store.taskPlan(for: a.id)?.date

        VStack(alignment: .leading, spacing: 12) {
            if steps.isEmpty {
                // Today or already sat: nothing left to plan. Saying so beats
                // an empty card that looks like something failed to load.
                cardLabel("Exam prep")
                Text(progress.daysLeft == 0
                     ? "It's today. \(progress.logged > 0 ? "\(progress.logged) minutes logged." : "Good luck.")"
                     : "This exam has passed.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    cardLabel("Exam prep")
                    Spacer()
                    Text("\(progress.daysLeft) day\(progress.daysLeft == 1 ? "" : "s") to go")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted2)
                }

                Text(built
                     ? "\(steps.count) session\(steps.count == 1 ? "" : "s") left on your plan, \(minutesPerStep) minutes each."
                     : "A \(steps.count)-step plan working back from the exam, \(minutesPerStep) minutes a session.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                // Logged against planned, as a bar: "am I behind?" is a
                // shape, not a total. `ProgressView(value:)` draws a bar
                // filled to `value`, from 0 (empty) to 1 (full).
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress.ratio)
                        .tint(Theme.brand(accent))
                    Text("\(progress.logged) of \(progress.target) minutes focused")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }

                HStack(spacing: 8) {
                    // Write the steps onto the checklist, once.
                    if !built {
                        Button {
                            store.addPrepSteps(to: a.id, now: now)
                        } label: {
                            Text("Build the plan")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(Theme.brandGradient(accent),
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    // Plan the next session, unless the plan is already on that day.
                    if let next, planned != next {
                        Button {
                            store.planTask(a.id, on: next)
                        } label: {
                            Text("Study on \(shortDay(next))")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.brand(accent))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(Theme.brandSoft(accent),
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if built {
                    Text("The steps are on the checklist below, tick them off as you go.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "Sep 15" for a "2026-09-15" day. The web writes "09/15"; the phone
    /// writes dates the way it does everywhere else.
    private func shortDay(_ day: String) -> String {
        deadlineDayStart(Deadline(date: day, time: nil)).map(fmtMD) ?? day
    }
}

// MARK: - Plan the work

struct PlanWorkCard: View {
    @Environment(Store.self) private var store

    /// The task, freshly looked up by the detail screen.
    let assignment: Assignment

    /// The day in the picker, as "yyyy-MM-dd". The card's own scratch value
    /// (a child view with its own state, 6a): nothing is planned until you
    /// tap Plan or Move.
    @State private var day: String

    /// Starts the picker on the planned day, or today. `@State` set from
    /// `init` through `_day` (4a), as the web's `useState(existingPlan?.date ?? today)`.
    init(assignment: Assignment, plannedDay: String?) {
        self.assignment = assignment
        _day = State(initialValue: plannedDay ?? dayOf(.now))
    }

    var body: some View {
        let accent = store.profile.accent
        let plan = store.taskPlan(for: assignment.id)

        VStack(alignment: .leading, spacing: 10) {
            cardLabel("Plan the work")
            Text("Pick when you want to work on this. Its deadline stays unchanged.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                // A date-only picker. It works in Dates; the plan stores a
                // "yyyy-MM-dd" day, so the binding converts both ways.
                DatePicker("Work day", selection: dayBinding, displayedComponents: .date)
                    .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    store.planTask(assignment.id, on: day)
                } label: {
                    Text(plan == nil ? "Plan" : "Move")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Theme.brandSoft(accent),
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let plan {
                Button("Remove from \(longDeadline(Deadline(date: plan.date, time: nil)))") {
                    store.removeTaskPlan(assignment.id)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.muted2)
                .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// The picker's Date, made from and written back to `day`. Local
    /// midnight of the stored day in; just the day part out (`dayOf`).
    private var dayBinding: Binding<Date> {
        Binding(get: { deadlineDayStart(Deadline(date: day, time: nil)) ?? .now },
                set: { day = dayOf($0) })
    }
}

// MARK: - Shared

/// The small capital-letter label at the top of both cards. `private` at the
/// top level of a file means "only this file can see it", so both cards share
/// it without adding a name to the rest of the app.
private func cardLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(Theme.faint)
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift` (replaces the file)

Four touched spots: the header, the Focused row, the Planning block above the checklist, and `reminderSummary` at the bottom.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift
//  Phase:   4b (the Tasks screen), changed in 7b (the planning cards)
//  Ports:   app/tasks/[id]/page.tsx (header, Complete, notes, details,
//           exam prep, reminders, Plan the work, checklist, delete)
//
//  Summary: One assignment in full: its class, title and deadline, a big
//           Complete / Mark as open button, the brief, the details, and its
//           checklist. Since 7b, while it's open, also its exam prep (for a
//           dated exam), its reminder controls and the day you plan to work
//           on it. Edit opens the form in a sheet; Delete moves it to
//           Recently Deleted and returns to the list, where Undo is offered.
//           The study timer, grade prompt and linked notes join later.
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
                    detailRow("Reminder", reminderSummary(a))
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
    private func reminderSummary(_ a: Assignment) -> String {
        if !a.reminder { return "Off" }
        if isSnoozed(a.snoozedUntil, .now) { return "Snoozed" }
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
}
```

### Not typed: the tests, and one line in your store script

`ExamPrepTests.swift` and the new `PlanningTests.swift` are in `docs/ios/reference/Tests/Logic/`; `PlanningStoreTests.swift` is in `docs/ios/reference/Tests/Persistence/`. To run them with your own scripts:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/{ExamPrepTests,PlanningTests}.swift Tests/Logic/
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Persistence/PlanningStoreTests.swift Tests/Store/
```

Then add `Store+Planning` to the end of the `for source in ...` list in `scripts/test-store.sh` (the store tests need the new file), and run both scripts.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 7b: a task's reminders, exam prep and Plan the work"
```

On the phone:

1. **+ → Assignment**: "Ping 7b", due 4 days from today, Daily reminder on, Save. Open it from Tasks. Details: **Focused** "No sessions yet", **Reminder** "Nudging until it's done". Below: the three cards (no Exam prep: it isn't an exam).
2. **Warn me early → 3 days**: the chip lights, the line says "One heads-up at 3 days before.", and the Reminder row says "Nudging, from 3 days before". Tap it again to turn it off.
3. **Not now → 1 hour**: the chips give way to "Snoozed until …" an hour from now, and the Reminder row says "Snoozed". Tap **Wake it**: the chips come back.
4. Switch the reminder **off**: "No nudges for this one.", the chips go, the row says "Off". Switch it back on.
5. **Plan the work**: pick tomorrow, tap **Plan**: "Remove from …" appears and the button says **Move**. Pick another day, **Move**; then **Remove from …**. The deadline line at the top never changes.
6. **+ → Exam**: "Ping exam", due 6 days from today. Open it. **Exam prep**: "6 days to go", "A 4-step plan…", the bar at "0 of 180 minutes focused". The Reminders card shows all three warning chips lit and "Exams get 1 week, 3 days, 2 days by default, tap to change." Tap **Build the plan**: four "… days before · …" lines join the checklist, and the card says "4 sessions left on your plan". Tap **Study on …** (tomorrow, the five-days-before step): the button goes, and Plan the work says "Remove from" tomorrow.
7. Tap **Complete** on the exam: all three cards disappear. Mark it open again: they're back, plan and checklist intact.
8. Close the app from the app switcher and open it again: the plan, the checklist steps and any snooze are still there.
9. Delete both test items.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] The Reminder row and the Reminders card agree after every tap (switch, a warning, a snooze, Wake it).
- [ ] Snoozing a task for an hour stops its notifications for that hour (check by snoozing something that's about to nudge, as in 7a's step 4).
- [ ] An exam with a date shows Exam prep; Build the plan adds its steps once; Study on plans the next session.
- [ ] Plan, Move and Remove work, and the deadline never changes.
- [ ] Everything survives closing and reopening the app.

## 7. If it breaks

- **`cannot find 'prepLadder' in scope`** (or `hasPrepLadder`, `minutesPerStep`): `Logic/ExamPrep.swift` is missing, or a name in it is spelled differently.
- **`type 'StudySession' does not conform to protocol 'StudyRecord'`**: the protocol's property names must match `Records.swift` exactly: `assignmentID`, `courseID`, `minutes`, `completedAt`.
- **`missing argument for parameter 'plannedDay' in call`**: in 4.7, `PlanWorkCard(assignment: a, plannedDay: store.taskPlan(for: a.id)?.date)`.
- **`cannot find 'studyMinutes' in scope`** in `Store+Planning.swift`: 4.1's new part isn't typed yet.
- **A chip tap does nothing visible:** the card must get the assignment from the detail screen on each redraw (`TaskReminderCard(assignment: a)`), not keep its own copy in `@State`, which would never see the store change.
- **Your `scripts/test-store.sh` fails with `cannot find 'focusedMinutes'`** (or another 7b action): `Store+Planning` isn't in the script's file list yet.

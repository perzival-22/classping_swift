# Phase 4a: Task logic, the store actions and the add form

*Replaces part of old Milestones 3 and 4. Phase 4 was too big for one sitting (11 files), so it is split in two: **4a** (this file) adds the logic, every store action and the task form; **4b** builds the real Tasks screen on top. Checked on 2026-10-16: `build-check.sh` gave `BUILD_OK` with no warnings for both the 4a and the 4b code, `logic-test.sh` passed 69/69 (26 new: task view, due labels, repeats).*

**Before you start:** Phase 3 is typed, building and committed (it is: `7d01f4a phase 3`, and your Sources build with `BUILD_OK`). Your `RootView.swift` only shows as modified because its final newline went missing; that's harmless, so commit it or leave it.

## 1. Goal

The center **+** finally adds work. **On your phone:** tap **+ → Assignment** (or Exam, or Reminder), the sheet grows to full height with a form, fill in a title, pick a class, a due-date shortcut, maybe a time, and tap **Save**. The sheet closes and the new task is in the Tasks tab with its friendly deadline. Leave the class as **Inbox** and the date off, and it is saved as undated Inbox work. A weekly task you complete in the Tasks list spawns next week's copy.

## 2. New Swift concepts

**`Form` and its controls.** A `Form` is a scrolling list of grouped input rows, Apple's built-in settings look. Inside it you place `TextField`, `Toggle`, `Picker` and `DatePicker`, each bound to a `@State` value with `$`:

```swift
@State private var reminder = true
Form {
    Section("Reminder") {
        Toggle("Daily reminder", isOn: $reminder)   // $reminder = a two-way connection
    }
}
```

**Starting `@State` from a value passed in.** A form that edits an existing assignment must start its fields from that assignment. `@State` normally starts from a fixed value, so the `init` writes to the underscored name, which is the State box itself:

```swift
@State private var title: String
init(editing: Assignment?) {
    _title = State(initialValue: editing?.title ?? "")   // "" for a new one
}
```

**Generic functions.** `groupTasks` must work on real assignments *and* on the test's stand-in type (the tests run on Linux, where `Assignment` and SwiftUI don't exist). A generic function takes "any type T that follows this protocol":

```swift
func groupTasks<T: TaskListable>(_ tasks: [T], _ now: Date) -> [AssignmentGroup<T>]
```

`TaskListable` is a protocol built on Phase 2's `Dated`; it adds `title`, `courseID` and `kindName`. `Assignment` signs up in Phase 4b.

You'll also meet `NavigationLink(value:)` with `.navigationDestination(for:)` in the Add menu: the link pushes a *value* (the kind), and the destination says which screen to build for that type. It's explained in the comments where it appears.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/task-view.ts` | `Logic/TaskView.swift` | Same groups, order, filters and saved-preference cleanup. Works on any `TaskListable` type, so it tests on Linux. `TaskGroup` became `AssignmentGroup`: Swift already has a `TaskGroup` |
| `dueLabel`, `longDeadline` in `lib/store.tsx` | `Logic/TaskView.swift` | Same text. The web says "In 1 weeks" for 8 to 10 days; that's copied on purpose, see the open question in PROGRESS.md |
| `nextRepeatDate` in `lib/planning.ts` | `Logic/Planning.swift` | Only this function for now. The rest of `planning.ts` arrives in Phase 6 |
| `addTask`, `updateTask`, `deleteTask`, `toggleTask`, `undoDelete`, `dismissUndo` in `lib/store.tsx` | `Store+Assignments.swift` | `updateAssignment` takes the whole edited value instead of a partial one. XP and trophies on completion wait for Phase 12 |
| `pendingUndo` in `lib/store.tsx` | `Store.pendingUndo` | Only assignments can be deleted for now. Phase 11 widens it |
| `app/tasks/new/page.tsx`, `app/tasks/[id]/edit/page.tsx` | `Screens/Tasks/AssignmentFormView.swift` | One form for both. Not ported: the "Reminder set ✓" test notification (Phase 7) and the draft that survives leaving the page. Editing a quiz keeps Quiz on offer, where the web edit form quietly turns it into an assignment |
| `components/AddMenu.tsx` | `Components/AddMenu.swift` | Assignment, Exam and Reminder open the form inside the sheet. Note and Class still just close it |

## 4. Files, in the order to type them

### Step 0: three small fixes in `Models.swift` (do these first)

Your `Models.swift` still differs from the data contract in three places, all flagged last session. Phase 4 reads these names, so it won't build until they match. Change only these lines:

```swift
// 1. In `struct Assignment`, the Kind line: put CaseIterable back.
//    Phase 4b's type filter lists every kind with `Assignment.Kind.allCases`.
enum Kind: String, Codable, CaseIterable { case assignment, quiz, exam, reminder }

// 2. `subtask` -> `subtasks` (the column is `subtasks`, and it holds many).
var subtasks: [Subtask] = []

// 3. `snoozeUntil` -> `snoozedUntil` (the column is `snoozed_until`).
var snoozedUntil: Date? = nil
```

**One side effect, so it doesn't surprise you:** your saved `planner.json` stores the checklist under the old key `subtask`. Swift's automatic decoder insists on every non-optional field, so after the rename it can't find `subtasks`, treats the file as unreadable, moves it aside to `planner.unreadable.json` (Phase 1's safety rule, D-14) and starts from the sample week. You'll lose only what you added on the phone so far, plus your theme and accent choice. That's fine at this stage, but it's the reason D-13 says every field added *after* Phase 1 must be optional. (`snoozedUntil` is optional, so its rename alone wouldn't have done this.)

Check with `xtool dev build` before going on. It should still say Build complete.

### Make the new folder

```bash
cd ~/ClassPing/Sources/ClassPing
mkdir -p Screens/Tasks
```

Watch for leading spaces in file names, as before.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Planning.swift` (new file)

Type the two Logic files first: everything else uses them.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Planning.swift
//  Phase:   4a (task logic and the add form)
//  Ports:   lib/planning.ts (`nextRepeatDate` only; Phase 6 ports the rest)
//
//  Summary: Works out the next due day of a repeating assignment: a week
//           later, or the same day next month, clamped to the month's last day
//           (Jan 31 repeats on Feb 28, or Feb 29 in a leap year).
//
//  Foundation only, so tools/logic-test.sh can test it on Linux.
//

import Foundation

/// The next due day after `date` ("yyyy-MM-dd") for a task that repeats
/// `rule` ("weekly" or "monthly"), or nil when the date is broken or the rule
/// is unknown. `nextRepeatDate` in lib/planning.ts.
/// The rule arrives as text because `Assignment.RepeatRule` lives in
/// Models.swift; the store passes `rule.rawValue`.
func nextRepeatDate(_ date: String, _ rule: String) -> String? {
    // Refuse anything that isn't a real calendar day.
    guard isValidDate(date) else { return nil }

    // Pull out the three numbers. `isValidDate` already proved there are three.
    let p = date.split(separator: "-").map { Int($0) ?? 0 }
    let (year, month, day) = (p[0], p[1], p[2])

    // Do the calendar maths in a fixed Gregorian calendar on UTC, so no time
    // zone or daylight-saving change can nudge the day (a pure day count,
    // the way the web avoids UTC parsing).
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current

    // Weekly: seven days on. `date(byAdding:)` handles month and year ends.
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
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/TaskView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/TaskView.swift
//  Phase:   4a (task logic and the add form)
//  Ports:   lib/task-view.ts (the whole file), plus `dueLabel` and `longDeadline`
//           from the helpers at the bottom of lib/store.tsx
//
//  Summary: How the Tasks screen decides what to show and in what order:
//           four urgency groups (Overdue, Today, Upcoming, No deadline), the
//           subject / type / archived filters, the remembered view choices,
//           and the two deadline labels the rows and forms print.
//
//  Foundation only, like Deadline.swift, so tools/logic-test.sh can run the
//  Swift twins of lib/task-view.test.ts on Linux. That's why nothing here
//  mentions `Assignment`: the functions work on anything that is `TaskListable`.
//

import Foundation

// MARK: - What a listable task is

/// Anything the Tasks screen can group, sort and filter. It builds on `Dated`
/// (which already promises `due` and `dueTime`) and adds the three fields the
/// screen sorts and filters by. `Assignment` signs up for this in Phase 4b.
/// `kindName` is the kind as plain text ("assignment", "quiz", "exam",
/// "reminder"), because the `Assignment.Kind` enum lives in Models.swift,
/// which this file can't see.
protocol TaskListable: Dated {
    var title: String { get }
    var courseID: UUID? { get }
    var kindName: String { get }
}

/// The four kinds, as the text `kindName` uses. `TaskKindFilter` in task-view.ts.
let taskKindNames = ["assignment", "quiz", "exam", "reminder"]

/// Does `a` come before `b`? Earliest deadline first, undated last, and the
/// title breaks ties so the order never jumps around. `compareByDeadline` in
/// lib/deadline.ts.
/// `<T: TaskListable>` makes this a generic function: it works for any type T
/// that is TaskListable (the real Assignment, or the tests' stand-in), and the
/// compiler checks that both arguments are the same type.
func sortsBefore<T: TaskListable>(_ a: T, _ b: T) -> Bool {
    let order = compareDeadlines(deadlineOf(a), deadlineOf(b))
    if order != 0 { return order < 0 }
    // Same deadline: compare titles the way a person reads them.
    return a.title.localizedCompare(b.title) == .orderedAscending
}

// MARK: - Groups

/// One heading on the Tasks screen and the work under it. `TaskGroup` in
/// task-view.ts, renamed because Swift already has a `TaskGroup` (it runs
/// several async jobs at once), the same reason the model isn't called `Task`.
/// Identifiable through its bucket, so `ForEach` can tell the groups apart.
struct AssignmentGroup<T: TaskListable>: Identifiable {
    let id: DueBucket
    let label: String
    let tasks: [T]
}

/// The heading each bucket gets. `GROUP_LABEL` in the web app.
func groupLabel(_ bucket: DueBucket) -> String {
    switch bucket {
    case .overdue:  "Overdue"
    case .today:    "Today"
    case .upcoming: "Upcoming"
    case .none:     "No deadline"
    }
}

/// Sort work into the four groups, each already in deadline order.
/// `groupTasks` in lib/task-view.ts. Empty groups are dropped, so the screen
/// never shows an "Overdue" heading with nothing under it.
func groupTasks<T: TaskListable>(_ tasks: [T], _ now: Date) -> [AssignmentGroup<T>] {
    // The order the headings appear in: missed, tonight, coming, unscheduled.
    let order: [DueBucket] = [.overdue, .today, .upcoming, .none]

    // `compactMap` runs the closure on every bucket and keeps only the non-nil
    // results, which is how an empty bucket disappears from the list.
    return order.compactMap { bucket in
        // Everything whose deadline falls in this bucket, as of `now`.
        let inBucket = tasks.filter { dueBucket(deadlineOf($0), now) == bucket }
        guard !inBucket.isEmpty else { return nil }

        // Overdue reads most-recent-first (yesterday's miss is still fixable,
        // last month's probably isn't), so its comparison is flipped. Every
        // other group is soonest first.
        let sorted = bucket == .overdue
            ? inBucket.sorted { sortsBefore($1, $0) }
            : inBucket.sorted { sortsBefore($0, $1) }
        return AssignmentGroup(id: bucket, label: groupLabel(bucket), tasks: sorted)
    }
}

// MARK: - Filters

/// What's narrowing the list. `TaskFilters` in task-view.ts.
/// `includeArchived` is on by default on purpose: archiving a class clears the
/// timetable, it doesn't make the unfinished essay go away.
/// Equatable, so "are these the defaults?" is a plain `==`.
struct TaskFilters: Equatable {
    var subject: UUID? = nil        // a class id, or nil for every subject
    var kind: String? = nil         // one of `taskKindNames`, or nil for every type
    var includeArchived = true

    /// Nothing filtered. `DEFAULT_FILTERS` in the web app.
    static let defaults = TaskFilters()

    /// True when nothing is narrowing the list. `filtersAreDefault`.
    var isDefault: Bool { self == TaskFilters.defaults }

    /// How many filters are on, for the "Filters · 2" chip. `activeFilterCount`.
    var activeCount: Int {
        // Each line adds 1 when that filter is narrowing the list.
        (subject != nil ? 1 : 0) + (kind != nil ? 1 : 0) + (includeArchived ? 0 : 1)
    }
}

/// The work that passes the filters. `filterTasks` in lib/task-view.ts.
/// `isArchived` answers "is this class archived?"; the caller supplies it
/// because only the store knows the classes. Inbox work (no class) can never
/// be hidden as archived: it has no class to archive.
func filterTasks<T: TaskListable>(_ tasks: [T], _ filters: TaskFilters,
                                  isArchived: (UUID) -> Bool) -> [T] {
    tasks.filter { t in
        // `if let s = filters.subject, ...` only runs when a subject is chosen.
        if let s = filters.subject, t.courseID != s { return false }
        if let k = filters.kind, t.kindName != k { return false }
        if !filters.includeArchived, let c = t.courseID, isArchived(c) { return false }
        return true
    }
}

// MARK: - Remembered view choices

/// The Open / Done switch at the top of the Tasks screen.
enum TaskTab: String { case open, done }

/// What the student last chose, so the screen comes back the way they left it.
/// `TaskViewPrefs` in task-view.ts. The web's List / Cards switch is left out:
/// it only appears on wide (desktop) screens.
struct TaskViewPrefs: Equatable {
    var tab = TaskTab.open
    var filters = TaskFilters.defaults
}

/// Turn the raw saved values back into preferences, dropping anything that
/// doesn't make sense. `normalizeViewPrefs` in task-view.ts. The phone saves
/// four plain values (Phase 4b uses `@AppStorage`), so this takes those four
/// rather than one JSON blob. A missing `includeArchived` means shown, never
/// hidden: an old preference must not start hiding work.
func normalizeViewPrefs(tab: String?, subject: String?, kind: String?,
                        includeArchived: Bool?) -> TaskViewPrefs {
    // Only "done" picks the Done tab; anything else is Open.
    let t: TaskTab = tab == "done" ? .done : .open

    // A subject must be a real id. `UUID(uuidString:)` gives nil for "" or junk,
    // and `flatMap` passes a nil `subject` straight through.
    let s = subject.flatMap { UUID(uuidString: $0) }

    // A kind must be one of the four names; "homework" or "" become nil.
    let k = kind.flatMap { taskKindNames.contains($0) ? $0 : nil }

    return TaskViewPrefs(tab: t, filters: TaskFilters(subject: s, kind: k,
                                                      includeArchived: includeArchived ?? true))
}

// MARK: - Deadline labels

/// A row's deadline pill: its text, and whether to paint it in the warning color.
struct DueLabel: Equatable {
    let text: String
    let urgent: Bool
}

/// The short pill a task wears. `dueLabel` in lib/store.tsx. Anything due
/// within a day is urgent. Undated work is never urgent: there is nothing to be
/// late for, and a red Inbox would be useless.
func dueLabel(_ d: Deadline, _ now: Date) -> DueLabel {
    guard d.date != nil else { return DueLabel(text: "No deadline", urgent: false) }

    // Past it, or due before tonight.
    let bucket = dueBucket(d, now)
    if bucket == .overdue { return DueLabel(text: "Overdue", urgent: true) }
    if bucket == .today { return DueLabel(text: "Due today", urgent: true) }

    // Further out: count whole calendar days.
    let diff = daysUntil(d, now) ?? 0
    if diff == 1 { return DueLabel(text: "Due tomorrow", urgent: true) }
    if diff < 7 { return DueLabel(text: "In \(diff) days", urgent: false) }
    if diff == 7 { return DueLabel(text: "In 1 week", urgent: false) }
    // Weeks, rounded to the nearest, as the web's Math.round does. Note the web
    // says "In 1 weeks" for 8 to 10 days; this copies it on purpose so both apps
    // agree (see PROGRESS.md, open questions).
    let weeks = Int((Double(diff) / 7).rounded())
    return DueLabel(text: "In \(weeks) weeks", urgent: false)
}

/// "Monday, Sep 7", with " · 2:30 PM" when the student gave a time, or
/// "No deadline". `longDeadline` in lib/store.tsx. Built from the deadline's own
/// day, never by parsing a UTC timestamp.
func longDeadline(_ d: Deadline) -> String {
    guard let start = deadlineDayStart(d) else { return "No deadline" }

    // POSIX locale: English day and month names whatever the phone's language.
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEEE, MMM d"
    let day = f.string(from: start)

    // Add the clock time only when there is one.
    guard let time = d.time else { return day }
    return "\(day) · \(formatTime(time))"
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Store.swift` (replaces the file)

Only one block is new, the `pendingUndo` property, marked `// NEW in Phase 4a`. The rest is unchanged from Phase 1.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store.swift
//  Phase:   1 (complete data models), changed in 4a (the undo slot)
//  Ports:   lib/store.tsx (the shared state) and the sample week from your designs
//
//  Summary: The one place the app's data lives while it runs, plus a sample
//           store to show until you add your own classes.
//

import Foundation
import Observation

/// The single place your app's data lives while it runs.
/// @Observable: any screen showing this data redraws by itself when it changes.
/// @MainActor: only used from the main (UI) thread, which Swift 6 checks for you.
@MainActor @Observable
final class Store {
    /// Everything you've entered. Deleted items stay here with `deletedAt` set.
    var courses: [Course] = []           // every class you take
    var assignments: [Assignment] = []   // every assignment, open or done
    var grades: [Grade] = []             // NEW in Phase 1
    var notes: [Note] = []               // NEW in Phase 1
    var taskPlans: [TaskPlan] = []       // NEW in Phase 1
    var studySessions: [StudySession] = [] // NEW in Phase 1
    var profile = Profile()              // NEW in Phase 1

    /// True when the last save to the phone failed. The screens must say so,
    /// because "Saved on this device" has to be true when the app claims it.
    var lastSaveFailed = false           // NEW in Phase 1

    /// The delete that can still be taken back with Undo, or nil. Lives only in
    /// memory (it isn't part of PlannerDocument), the way `pendingUndo` in
    /// lib/store.tsx is never cached. Stored properties can't go in an
    /// extension, which is why this one sits here and not in Store+Assignments.
    var pendingUndo: PendingUndo? = nil  // NEW in Phase 4a
}

extension Store {
    /// A store filled with the classes and assignments from your design screens 02 and 06.
    /// The app uses it until you add your own. End times are made up.
    static var sample: Store {
        // Times are minutes from midnight: 510 = 8:30 AM, 560 = 9:20 AM.
        // CHANGED in Phase 1: colors are names now, not hex codes.
        let calc = Course(name: "Calculus III", short: "Calc", color: .coral,
                          days: [0, 2, 4], startMin: 510, endMin: 560)
        let ml = Course(name: "Foundations of Machine Learning", short: "ML", color: .indigo,
                        days: [0, 2], startMin: 600, endMin: 680, remindBefore: 15, room: "Friend 101")
        let poli = Course(name: "Modern Political Theory", short: "Poli", color: .teal,
                          days: [0, 2], startMin: 810, endMin: 885)
        let ochem = Course(name: "Organic Chemistry II", short: "OChem", color: .ocean,
                           days: [1, 3], startMin: 540, endMin: 615)
        let psych = Course(name: "Introduction to Psychology", short: "Psych", color: .amber,
                           days: [1, 3], startMin: 900, endMin: 975)

        let store = Store()
        store.courses = [calc, ml, poli, ochem, psych]
        // Each assignment points at its class through that class's id.
        store.assignments = [
            Assignment(courseID: ochem.id, title: "Lab report: Aldol condensation", due: day(1)),
            Assignment(courseID: ml.id, title: "Problem Set 4", due: day(2)),
            Assignment(courseID: poli.id, title: "Reading response: Rawls, Ch. 3", due: day(3), reminder: true),
            Assignment(courseID: calc.id, title: "Midterm study guide", due: day(-2), done: true),
            Assignment(courseID: psych.id, title: "Reflection journal", due: day(-1), done: true),
            // NEW in Phase 1: an exam with an exact time, and an undated Inbox item.
            Assignment(courseID: calc.id, title: "Midterm 2", due: day(5), dueTime: "10:00", kind: .exam),
            Assignment(title: "Email advisor about spring classes"),
        ]
        return store
    }

    /// The date `offset` days from today, as "yyyy-MM-dd": day(1) is tomorrow, day(-1) yesterday.
    private static func day(_ offset: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   // same format whatever your phone's language
        f.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        return f.string(from: date)
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Assignments.swift` (replaces the file)

Your Phase 1 `toggleAssignment` grows the repeat logic; everything else is new.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Assignments.swift
//  Phase:   1 (save and load), rewritten in 4a (every task action)
//  Ports:   lib/store.tsx (addTask, updateTask, deleteTask, undoDelete,
//           dismissUndo, toggleTask, taskById, classById, liveTasks, and the
//           checklist edits the task detail screen makes through updateTask)
//
//  Summary: Everything that changes an assignment. Each action changes the
//           store and then saves to the phone straight away, before anything
//           else can happen, so "Saved on this device" is always true.
//

import Foundation

/// A delete that can still be taken back. `PendingUndo` in lib/recovery.ts,
/// cut down to assignments for now (Phase 11 widens it to classes, grades and
/// notes). `at` is when the delete happened; the Undo bar gives up 8 seconds
/// later, the web's `UNDO_WINDOW_MS`.
// NEW in Phase 4a
struct PendingUndo: Equatable {
    let assignmentID: UUID
    let label: String          // "Problem Set 4 deleted"
    let at: Date
}

extension Store {
    // MARK: - Reading

    /// Every assignment that hasn't been deleted. `liveTasks` in lib/store.tsx.
    /// Screens read this, never the raw `assignments` array, so a deleted item
    /// vanishes everywhere at once.
    // NEW in Phase 4a
    var liveAssignments: [Assignment] {
        assignments.filter { $0.deletedAt == nil }
    }

    /// One live assignment by id, or nil. `taskById` in lib/store.tsx.
    // NEW in Phase 4a
    func assignment(_ id: UUID) -> Assignment? {
        liveAssignments.first(where: { $0.id == id })
    }

    /// The live class an assignment is filed under, or nil for Inbox work.
    /// `classById` in lib/store.tsx. (Phase 5 moves this to Store+Courses.swift.)
    // NEW in Phase 4a
    func course(_ id: UUID?) -> Course? {
        // No class id means Inbox: nothing to look up.
        guard let id else { return nil }
        return courses.first(where: { $0.id == id && $0.deletedAt == nil })
    }

    // MARK: - Adding and editing

    /// Adds a new assignment. `addTask` in lib/store.tsx (its XP credit comes in Phase 12).
    // NEW in Phase 4a
    func addAssignment(_ assignment: Assignment) {
        assignments.append(assignment)
        save()
    }

    /// Replaces an assignment with an edited copy, matched by id. `updateTask`
    /// in the web app takes only the changed fields; here the form hands back
    /// the whole edited value, which is simpler and can't half-apply.
    // NEW in Phase 4a
    func updateAssignment(_ edited: Assignment) {
        guard let index = assignments.firstIndex(where: { $0.id == edited.id }) else { return }
        assignments[index] = edited
        save()
    }

    // MARK: - Completing

    /// Marks an assignment completed, or back to open. `toggleTask` in lib/store.tsx.
    /// Completing a repeating assignment also adds its next copy, once.
    /// (XP and trophies for completing come in Phase 12.)
    // CHANGED in Phase 4a: repeats, and deleted items can't be toggled
    func toggleAssignment(_ id: UUID) {
        // Find the live assignment. `firstIndex(where:)` gives nil when there's
        // no match, and `guard` leaves early in that case.
        guard let index = assignments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let task = assignments[index]
        let nextDone = !task.done
        assignments[index].done = nextDone

        // A repeating assignment that was just completed spawns its next copy.
        // Every condition must hold, and a comma in an `if` means "and":
        //   - it was completed (not reopened), repeats, and has a due day,
        //   - no copy already points back at it (completing, reopening and
        //     completing again must not stack up duplicates),
        //   - the next day exists and isn't past the "repeat until" day.
        if nextDone,
           let rule = task.repeatRule,
           let due = task.due,
           !liveAssignments.contains(where: { $0.recurrenceParentID == task.id }),
           let nextDue = nextRepeatDate(due, rule.rawValue),
           task.repeatUntil.map({ nextDue <= $0 }) ?? true {
            // `var next = task` makes a full copy (structs are values), which
            // is then changed into the next occurrence.
            var next = task
            next.id = UUID()
            next.due = nextDue
            next.done = false
            next.recurrenceParentID = task.id
            next.deletedAt = nil
            // The checklist comes along, unticked.
            next.subtasks = task.subtasks.map { step in
                var fresh = step
                fresh.done = false
                return fresh
            }
            assignments.append(next)
        }
        save()
    }

    // MARK: - Checklist

    /// Adds a step to an assignment's checklist. The web does this with
    /// `updateTask(id, { subtasks: [...] })`. Blank steps are ignored, and a
    /// step is capped at 200 characters like the web input.
    // NEW in Phase 4a
    func addSubtask(_ title: String, to id: UUID) {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !clean.isEmpty,
              let index = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[index].subtasks.append(Subtask(title: clean))
        save()
    }

    /// Ticks a checklist step, or unticks it.
    // NEW in Phase 4a
    func toggleSubtask(_ stepID: UUID, in id: UUID) {
        // Two lookups: the assignment, then the step inside its checklist.
        guard let index = assignments.firstIndex(where: { $0.id == id }),
              let step = assignments[index].subtasks.firstIndex(where: { $0.id == stepID }) else { return }
        assignments[index].subtasks[step].done.toggle()
        save()
    }

    // MARK: - Deleting and undo

    /// Moves an assignment to Recently Deleted. `deleteTask` in lib/store.tsx.
    /// Nothing is erased: `deletedAt` is set, so it can come back for 30 days.
    /// Its day plan goes (as on the web), and the Undo bar is offered.
    // NEW in Phase 4a
    func deleteAssignment(_ id: UUID) {
        guard let index = assignments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = Date.now
        assignments[index].deletedAt = now
        taskPlans.removeAll(where: { $0.assignmentID == id })

        // "Problem Set 4 deleted", or "Assignment deleted" for a blank title.
        let title = assignments[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(assignmentID: id,
                                  label: "\(title.isEmpty ? "Assignment" : title) deleted",
                                  at: now)
        save()
    }

    /// Brings back the assignment the Undo bar is offering. `undoDelete`.
    // NEW in Phase 4a
    func undoDelete() {
        guard let undo = pendingUndo,
              let index = assignments.firstIndex(where: { $0.id == undo.assignmentID }) else { return }
        assignments[index].deletedAt = nil
        pendingUndo = nil
        save()
    }

    /// Lets the Undo offer go without acting on it. `dismissUndo`.
    // NEW in Phase 4a
    func dismissUndo() {
        pendingUndo = nil
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift
//  Phase:   4a (task logic and the add form)
//  Ports:   app/tasks/new/page.tsx and app/tasks/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new assignment, exam or reminder, and for editing
//           one. Only a title is required: no class means Inbox, no date means
//           "No deadline", and no time means all-day.
//

import SwiftUI

struct AssignmentFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The assignment being edited, or nil for a new one.
    let editing: Assignment?

    /// What to do after Save. The Add menu passes "close the whole sheet";
    /// when nil, the form just closes itself with `dismiss()`.
    let onFinish: (() -> Void)?

    // MARK: Form state
    // `@State` is the form's own scratch copy of every field. Nothing reaches
    // the store until Save, so Cancel or Back throws the edits away.
    @State private var title: String
    @State private var courseID: UUID?
    @State private var kind: Assignment.Kind
    @State private var hasDate: Bool          // off = No deadline (Inbox)
    @State private var dueDay: Date           // only the day part is used
    @State private var hasTime: Bool          // off = all-day
    @State private var dueClock: Date         // only the hour and minute are used
    @State private var reminder: Bool
    @State private var notes: String
    @State private var repeatRule: Assignment.RepeatRule?
    @State private var hasRepeatEnd: Bool
    @State private var repeatEnd: Date

    /// Sets the starting value of every field. A view's `@State` normally starts
    /// from a fixed value; to start it from the assignment being edited, the
    /// init writes to the underscore version (`_title`), which is the State box
    /// itself, wrapping the value in `State(initialValue:)`.
    /// New work starts like the web form: due in 3 days, all-day, reminder on.
    init(kind: Assignment.Kind = .assignment, editing: Assignment? = nil,
         onFinish: (() -> Void)? = nil) {
        self.editing = editing
        self.onFinish = onFinish

        // Where the dates start: the stored day if there is one, else 3 days out.
        let inThreeDays = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let storedDay = editing.flatMap { parseDay($0.due) }
        let storedClock = editing.flatMap { parseClock($0.dueTime) }
        let storedEnd = editing.flatMap { parseDay($0.repeatUntil) }

        _title = State(initialValue: editing?.title ?? "")
        _courseID = State(initialValue: editing?.courseID)
        _kind = State(initialValue: editing?.kind ?? kind)
        _hasDate = State(initialValue: editing == nil ? true : storedDay != nil)
        _dueDay = State(initialValue: storedDay ?? inThreeDays)
        _hasTime = State(initialValue: storedClock != nil)
        _dueClock = State(initialValue: storedClock ?? parseClock("17:00") ?? .now)
        _reminder = State(initialValue: editing?.reminder ?? true)
        _notes = State(initialValue: editing?.notes ?? "")
        _repeatRule = State(initialValue: editing?.repeatRule)
        _hasRepeatEnd = State(initialValue: storedEnd != nil)
        _repeatEnd = State(initialValue: storedEnd ?? storedDay ?? inThreeDays)
    }

    var body: some View {
        Form {
            // MARK: Class
            // `selection: $courseID` binds the picker to the form's state: the
            // `$` hands the picker a two-way connection, so picking a row
            // writes straight into `courseID`. Each row's `.tag` is the value
            // it stands for; nil is Inbox, a real choice, not "nothing chosen".
            Section("Class") {
                Picker("Class", selection: $courseID) {
                    Text("Inbox, no class").tag(UUID?.none)
                    ForEach(store.courses.filter { $0.deletedAt == nil }) { course in
                        Text(course.name).tag(UUID?.some(course.id))
                    }
                }
            }

            // MARK: Type
            Section("Type") {
                Picker("Type", selection: $kind) {
                    ForEach(kindChoices, id: \.self) { k in
                        Text(kindTitle(k)).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: Name
            Section(nameHeading) {
                TextField(namePlaceholder, text: $title)
                    .textInputAutocapitalization(.sentences)
            }

            // MARK: Due
            Section {
                // The web's shortcut chips. A horizontal scroller, because seven
                // chips don't fit across a phone.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.label) { preset in
                            presetChip(preset)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // A switch for "has a day at all"; off is the Inbox.
                Toggle("Has a due date", isOn: $hasDate)
                if hasDate {
                    // New work can't be due in the past (the web's `min` is today).
                    // An edit keeps any day, so an overdue task isn't moved by accident.
                    DatePicker("Date", selection: $dueDay, in: earliestDay...,
                               displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $dueClock, displayedComponents: .hourAndMinute)
                    }
                }
            } header: {
                Text("Due")
            } footer: {
                // The plain-words summary under the web form: "Due Monday, Sep 7".
                Text("Due \(longDeadline(draftDeadline))")
            }

            // MARK: Repeat
            // Only for dated graded work, like the web: a reminder doesn't repeat.
            if hasDate && kind != .reminder {
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatRule) {
                        Text("None").tag(Assignment.RepeatRule?.none)
                        Text("Weekly").tag(Assignment.RepeatRule?.some(.weekly))
                        Text("Monthly").tag(Assignment.RepeatRule?.some(.monthly))
                    }
                    .pickerStyle(.segmented)
                    if repeatRule != nil {
                        Toggle("Repeat until a date", isOn: $hasRepeatEnd)
                        if hasRepeatEnd {
                            DatePicker("Until", selection: $repeatEnd, in: dueDay...,
                                       displayedComponents: .date)
                        }
                    }
                }
            }

            // MARK: Reminder
            Section {
                Toggle(isOn: $reminder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder")
                        Text("Nudge me until it's done")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }

            // MARK: Notes
            Section("Notes (optional)") {
                // `axis: .vertical` lets the field grow onto new lines as you type.
                TextField("What the brief asks for, pages to read, what to bring…",
                          text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        // Let the warm canvas show through instead of the system grey.
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(editing == nil ? "New Assignment" : "Edit Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        // The web caps notes at 2000 characters; trim anything pasted past that.
        .onChange(of: notes) {
            if notes.count > 2000 { notes = String(notes.prefix(2000)) }
        }
    }

    // MARK: - Pieces

    /// A due-date shortcut: a label and how many days from today (nil = No deadline).
    private struct Preset {
        let label: String
        let days: Int?
    }

    /// The web form's `DUE_PRESETS`, in the same order.
    private var presets: [Preset] {
        [Preset(label: "No deadline", days: nil), Preset(label: "Today", days: 0),
         Preset(label: "Tomorrow", days: 1), Preset(label: "2 days", days: 2),
         Preset(label: "3 days", days: 3), Preset(label: "1 week", days: 7),
         Preset(label: "2 weeks", days: 14)]
    }

    /// One shortcut chip. Filled with the brand color when it matches the
    /// current choice, the way the web lights up the active preset.
    private func presetChip(_ preset: Preset) -> some View {
        // The day this chip stands for, or nil for "No deadline".
        let target = preset.days.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }
        let on = target.map { hasDate && dayOf($0) == dayOf(dueDay) } ?? !hasDate
        let accent = store.profile.accent

        return Button {
            // Tapping sets (or clears) the date in one go.
            if let target {
                hasDate = true
                dueDay = target
            } else {
                hasDate = false
            }
        } label: {
            Text(preset.label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(on ? Color.white : Theme.muted)
                .background(on ? Theme.brand(accent) : Theme.canvas,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)   // stops the Form row treating the whole row as one button
    }

    // MARK: - Derived values

    /// The kinds the Type picker offers. Quizzes are made from a class card on
    /// the web, so a new task offers three; editing a quiz keeps Quiz on offer
    /// so saving never quietly turns it into an assignment.
    private var kindChoices: [Assignment.Kind] {
        let base: [Assignment.Kind] = [.assignment, .exam, .reminder]
        return editing?.kind == .quiz ? base + [.quiz] : base
    }

    /// The name each kind shows in the picker.
    private func kindTitle(_ k: Assignment.Kind) -> String {
        switch k {
        case .assignment: "Assignment"
        case .quiz:       "Quiz"
        case .exam:       "Exam"
        case .reminder:   "Reminder"
        }
    }

    /// The heading over the title field changes with the kind, as on the web.
    private var nameHeading: String {
        switch kind {
        case .exam:     "Exam"
        case .reminder: "Reminder"
        default:        "Assignment"
        }
    }

    /// The example text in the empty title field.
    private var namePlaceholder: String {
        switch kind {
        case .exam:     "e.g. Midterm, Chapters 1–6"
        case .reminder: "e.g. Bring safety goggles"
        default:        "e.g. Reading response: Rawls, Ch. 3"
        }
    }

    /// The first day the date picker allows: today for new work, any day for an edit.
    private var earliestDay: Date {
        editing == nil ? Calendar.current.startOfDay(for: .now) : .distantPast
    }

    /// The deadline the form currently describes, in the stored shape.
    private var draftDeadline: Deadline {
        Deadline(date: hasDate ? dayOf(dueDay) : nil,
                 time: hasDate && hasTime ? timeOf(dueClock) : nil)
    }

    /// Only a title is required. `canSave` in the web form.
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Saving

    /// Builds the assignment from the fields and hands it to the store.
    /// `save` in app/tasks/new/page.tsx and the edit page.
    private func save() {
        guard canSave else { return }

        // Start from the edited assignment so fields this form doesn't show
        // (checklist, done, feed ids...) survive; a new one starts blank.
        var a = editing ?? Assignment(title: "")
        let deadline = draftDeadline
        a.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        a.courseID = courseID
        a.kind = kind
        a.due = deadline.date
        a.dueTime = deadline.time
        a.reminder = reminder

        // Empty notes are stored as nothing, not as "".
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        a.notes = cleanNotes.isEmpty ? nil : cleanNotes

        // A repeat needs a date and isn't for reminders. "Until" only counts
        // when it is on or after the due day (string order is date order here).
        let rule = (deadline.date != nil && kind != .reminder) ? repeatRule : nil
        a.repeatRule = rule
        let until = dayOf(repeatEnd)
        a.repeatUntil = (rule != nil && hasRepeatEnd && until >= (deadline.date ?? "")) ? until : nil

        // New or edited: the store saves to the phone either way.
        if editing == nil {
            store.addAssignment(a)
        } else {
            store.updateAssignment(a)
        }

        // Close: the caller's way if it gave one, otherwise just this screen.
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

// MARK: - Turning stored text into picker dates

/// "2026-09-07" -> local midnight that day, for a DatePicker. Nil when empty or broken.
/// Reuses Deadline.swift, which already knows how to read a stored day.
private func parseDay(_ day: String?) -> Date? {
    deadlineDayStart(Deadline(date: day, time: nil))
}

/// "14:30" -> today at 2:30 PM, for a time-only DatePicker. Only the hour and
/// minute are ever read back out (with `timeOf`), so the day doesn't matter.
private func parseClock(_ time: String?) -> Date? {
    guard isValidTime(time) else { return nil }
    return deadlineInstant(Deadline(date: dayOf(.now), time: time))
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Components/AddMenu.swift` (replaces the file)

The rows move into a `label(for:)` helper, and three of them become NavigationLinks. Changed blocks are marked.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AddMenu.swift
//  Phase:   3 (app shell), changed in 4a (the first three rows open the form)
//  Ports:   components/AddMenu.tsx (the five labelled choices)
//
//  Summary: The sheet the Add button opens: the five things you can add, named,
//           in the same order as the web app. Assignment, Exam and Reminder now
//           slide in the task form; Note and Class still just close (Phases 8 and 5).
//

import SwiftUI

struct AddMenu: View {
    /// `dismiss` closes the sheet, the way `onClose()` does in the web component.
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store

    /// How tall the sheet is. Starts at half height; jumps to full when the
    /// form slides in, because a form needs the room.
    @State private var detent: PresentationDetent = .medium   // NEW in Phase 4a

    /// One choice in the menu. `symbol` is an SF Symbol name (the native icon set
    /// that replaces components/icons.tsx). `kind` is set for the three rows
    /// that open the task form, and nil for Note and Class.
    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let symbol: String
        var kind: Assignment.Kind? = nil       // NEW in Phase 4a
    }

    /// The five choices, matching AddMenu.tsx's list and wording.
    private let options = [
        Option(label: "Assignment", detail: "Homework, essays, lab reports", symbol: "doc.text", kind: .assignment),
        Option(label: "Exam", detail: "A test or quiz to revise for", symbol: "graduationcap", kind: .exam),
        Option(label: "Reminder", detail: "Something to bring or do, not graded", symbol: "bell", kind: .reminder),
        Option(label: "Note", detail: "Write down a lecture or a thought", symbol: "pencil"),
        Option(label: "Class", detail: "Add a subject to your timetable", symbol: "book"),
    ]

    var body: some View {
        NavigationStack {
            List(options) { opt in
                // CHANGED in Phase 4a: a row with a kind is a NavigationLink.
                // `NavigationLink(value:)` doesn't build the next screen itself;
                // it pushes a value (here the kind), and the stack looks up what
                // to show for that type in `.navigationDestination` below.
                if let kind = opt.kind {
                    NavigationLink(value: kind) {
                        label(for: opt)
                    }
                } else {
                    // Note (Phase 8) and Class (Phase 5) still just close the menu.
                    Button {
                        dismiss()
                    } label: {
                        label(for: opt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // NEW in Phase 4a: what to show when a kind is pushed. Saving closes
            // the whole Add sheet (not just the form), so `onFinish` is our dismiss.
            .navigationDestination(for: Assignment.Kind.self) { kind in
                AssignmentFormView(kind: kind, onFinish: { dismiss() })
                    .onAppear { detent = .large }
            }
        }
        // A sheet that opens to about half height, draggable to full. The
        // `selection:` lets the code above change the height too.
        .presentationDetents([.medium, .large], selection: $detent)   // CHANGED in Phase 4a
    }

    /// One row's look: a brand-soft rounded square holding the icon, then the
    /// name and a one-line description, like the web rows.
    // NEW in Phase 4a (moved out of `body`, so both row types can share it)
    private func label(for opt: Option) -> some View {
        let accent = store.profile.accent
        return HStack(spacing: 14) {
            Image(systemName: opt.symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 38, height: 38)
                .background(Theme.brand(accent).opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(opt.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(opt.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
```

## 5. Run it

```bash
xtool dev build
xtool dev
git add . && git commit -m "Phase 4a: task logic, store actions, add form"
```

On the phone:
1. Tap **+**, then **Assignment**. The sheet grows to full height and shows **New Assignment**.
2. Type a title. **Save** lights up once there is one.
3. Pick a class, tap **Tomorrow**, turn on **Set a time**, pick 2:30 PM. The footer reads "Due *weekday*, *Mon d* · 2:30 PM".
4. Tap **Save**. The sheet closes. On **Tasks**, the new row says "Tomorrow · 2:30 PM".
5. Add another with **No deadline** and class **Inbox, no class**. It shows "Inbox · No deadline".
6. Add one with **Repeat: Weekly**. Tap it in the Tasks list to complete it: a second copy appears, due a week later.
7. **+ → Exam**: the form's Type starts on Exam and the heading reads "Exam".

## 6. Done when

- [ ] The three `Models.swift` fixes are in, and `xtool dev build` has no warnings.
- [ ] + → Assignment / Exam / Reminder each open the form with that type picked.
- [ ] A task saved with no date lands in Inbox as "No deadline"; one with a date and no time shows no clock.
- [ ] Completing a weekly task adds next week's copy once (complete, reopen, complete again: still only one copy).
- [ ] Everything survives a relaunch (swipe the app away, open it again).

## 7. If it breaks

- **`value of type 'Assignment' has no member 'subtasks'`** (or `snoozedUntil`): Step 0 isn't done, or a typo in it.
- **`type 'Assignment.Kind' does not conform to protocol 'CaseIterable'`** only shows up in 4b, but fix it now while you're in Models.swift.
- **`cannot find 'nextRepeatDate' in scope`** or **`cannot find 'longDeadline' in scope`**: `Planning.swift` or `TaskView.swift` ended up outside `Sources/ClassPing/Logic/`. Check with `find ~/ClassPing/Sources -name '*.swift'`.
- **`invalid redeclaration of 'PendingUndo'`**: you typed the struct into `Store.swift` as well. It lives only in `Store+Assignments.swift`.
- **The picker shows "Inbox" but saving files it under a class (or the reverse):** the `.tag(...)` values must be `UUID?.none` and `UUID?.some(course.id)`, exactly the picker's `UUID?` type. A plain `.tag(course.id)` is a different type and silently never matches.

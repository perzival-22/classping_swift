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
---
title: "Phase 6b: Today, your work and your classes"
date: 2026-10-17
generated_by: skills-for-architects
---

# Phase 6b: Today, your work and your classes

*Second half of Phase 6 (D-24). Checked on 2026-10-17 on top of Phase 6a: `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 107/107 (11 new: the term glance), `persistence-test.sh` passed 9/9 (5 new: deleting a class and Undo). Your own `Tests/Store/CourseStoreTests.swift` still passes 6/6 against this code.*

**Before you start:** Phase 4b and 6a are typed, building, committed and tried on the phone. This phase opens 4b's assignment detail and uses its Undo bar.

## 1. Goal

Today finishes: under the picked day, your term at a glance, your next assignments and your classes, and a class can finally be deleted, with an Undo that brings its work back too (D-21).

**On your phone:** below the day, a row of three numbers: **done**, **this week**, and either **overdue** (red) or **days clear** (green). Then **Assignments** with a coral count and **View all**, which jumps to the Tasks tab, and your four soonest open assignments, each with its class dot, an EXAM badge on exams and a deadline pill that's red when it's close; tap one and its detail opens right there inside Today. Then **My Classes**: every class with its book and when it meets, a pencil that opens its form, a trash can, and **+ Add** for a new class. Tap the trash: an action sheet asks **Delete "Biology"?**. Delete, and the class leaves the week, the day, the numbers and both lists, its assignments leave the Tasks tab, and an Undo bar says "Biology deleted". **Undo** puts back the class and exactly the work that went with it.

## 2. New Swift concepts

**`confirmationDialog`.** The iOS way to ask "are you sure?" before something destructive: an action sheet that slides up from the bottom. It shows while a Bool binding is `true`. `presenting:` hands it the thing being asked about, so the buttons act on the class you tapped. A button with `role: .destructive` is drawn in red, and iOS adds **Cancel** by itself. The web asks the same question inline under the row.

```swift
@State private var deleting: Course?           // nil = not asking
.confirmationDialog(deleting.map { "Delete “\($0.name)”?" } ?? "",
                    isPresented: confirmShown, titleVisibility: .visible,
                    presenting: deleting) { course in
    Button("Delete", role: .destructive) { store.deleteCourse(course.id) }
}
```

`confirmShown` is a `Binding(get:set:)` (from 4b) that turns "is a class waiting?" into the Bool the dialog wants.

**Widening a type without breaking its users.** `PendingUndo` only knew assignments: it had an `assignmentID`. Now it can also be a class, so that field becomes an enum with associated values, the pattern from 5b's `TodaySheet`:

```swift
struct PendingUndo: Equatable {
    enum Item: Equatable {
        case assignment(UUID)
        case course(UUID)
    }
    let item: Item
    let label: String
    let at: Date
}
```

`label` and `at` stay exactly as they were, so the Undo bar, which only reads those two, needs no change at all. The one place that has to know the difference is `undoDelete`, and it uses a `switch` that pulls the id out of each case: `case .course(let id): restoreCourse(id)`. If Phase 11 adds `case grade(UUID)`, Swift will refuse to build until that `switch` handles it too.

**A protocol built on another.** `protocol Completable: Dated { var done: Bool { get } }` means "everything `Dated` asks for, plus `done`". The term glance is written once, for any `Completable`, as a generic function, `func termStats<T: Completable>(_ tasks: [T], _ now: Date)`, the same idea as 4a's `TaskListable`. The Linux tests feed it a tiny test type; the app feeds it real assignments, after one line says Assignment fits: `extension Assignment: Completable {}`.

You'll also meet `@escaping` (a closure that's kept and run later, like a button's action passed into a helper) and `for i in list.indices where ...` (a loop that only visits the matching positions, so there's nothing to skip and no `break`).

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/streak.ts` (`termStats`) | `Logic/Streak.swift` | Same four numbers, the same 7-day window, the same "days clear" walk-back and its one-year cap, with fixed 24-hour days like the web so both apps agree. Ported here instead of Phase 10 because Today shows it (D-26) |
| `deleteClass` in `lib/store.tsx` | `deleteCourse` in `Store+Courses.swift` | Same: one shared stamp on the class and its live assignments, grades and notes; work already deleted keeps its own older stamp |
| the class half of `restoreItems` | `restoreCourse` in `Store+Courses.swift` | Brings back the items whose stamp matches the class's. Phase 11's Recently Deleted will call it too |
| `PendingUndo` in `lib/recovery.ts`, `undoDelete` | `Store+Assignments.swift` | `kind` + `ids` becomes an enum with an id. Grades and notes join in Phase 11 |
| `classById` | `course(_:)`, moved to `Store+Courses.swift` | Unchanged, just in the classes file where 5b said it would end up |
| `TermGlance` and `Stat` in `app/home/page.tsx` | `TermGlance` in `Screens/Today/TodaySections.swift` | Same numbers, labels and colors; hidden until you have any work |
| the Assignments section | `AssignmentsPreview` | Same four soonest, count, badge and pill. "View all" switches tab instead of loading `/tasks`. The desktop-only "Add assignment" button isn't on the phone web either |
| the My Classes section | `MyClassesSection` | Same rows, Edit and Add. The inline "Delete?" row becomes an iOS action sheet |
| the undo strip in `StatusChrome.tsx` | `.undoBar()` on Today (from 4b) | Today now offers Undo too (D-25) |
| the Grades & GPA button on Home | (none) | Grades live in the Profile tab since D-19, Phase 9 |

## 4. Files, in the order to type them

Type 4.3 and 4.4 before building: `course(_:)` moves from one to the other, so in between there are either two of it or none.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Streak.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Streak.swift
//  Phase:   6b (Today: your work and your classes)
//  Ports:   lib/streak.ts (termStats, the "term at a glance" numbers)
//
//  Summary: Four gentle numbers for the top of Today's lists: how much you've
//           completed, how much is due in the next week, how much is overdue,
//           and how many days in a row nothing has been overdue. Worked out
//           from the assignments alone, so nothing new is stored or synced.
//

import Foundation

/// Anything with a deadline that can be completed. A protocol can build on
/// another one: `Completable: Dated` means "everything `Dated` asks for
/// (`due` and `dueTime`), plus `done`". Logic files can't see the
/// Assignment model (they compile alone for the Linux tests), so termStats
/// asks for this instead, and Assignment+Deadline.swift says Assignment fits.
protocol Completable: Dated {
    var done: Bool { get }
}

/// The four numbers. `TermStats` in lib/streak.ts.
struct TermStats: Equatable {
    /// Assignments ticked off, ever.
    var completed: Int
    /// Open items already past their deadline.
    var overdue: Int
    /// Open items due in the next 7 days.
    var dueThisWeek: Int
    /// Days in a row, up to today, with nothing overdue. At most 365.
    var streak: Int
}

/// A day and a week in seconds. The web counts fixed 24-hour days in
/// milliseconds (`DAY_MS`); this does the same in seconds so both apps get
/// the same answer, daylight-saving days included.
private let daySeconds: TimeInterval = 86_400

/// Looking further back than a school year tells us nothing. `MAX_STREAK_DAYS`.
private let maxStreakDays = 365

/// Was anything overdue when `dayEnd` arrived? Something counts if it was due
/// before then and is still not done. Completion times aren't recorded, so a
/// finished task counts as never having been late: generous on purpose.
/// `hadOverdue` in lib/streak.ts.
private func hadOverdue<T: Completable>(_ tasks: [T], _ dayEnd: Date) -> Bool {
    tasks.contains { t in
        // `guard` inside a closure: leave this one item early with `false`.
        guard !t.done, let at = dueAt(t) else { return false }
        return at < dayEnd
    }
}

/// The glance numbers for a list of work at `now`. `termStats` in lib/streak.ts.
/// The streak counts days with nothing overdue, not days of perfect work, so
/// a student who has fallen behind can always restart it by catching up.
func termStats<T: Completable>(_ tasks: [T], _ now: Date) -> TermStats {
    let today = Calendar.current.startOfDay(for: now)

    // Count the first three numbers in one pass. Undated work (Inbox) is
    // neither overdue nor due this week: it's waiting to be scheduled, and
    // counting it either way would misreport the term.
    var completed = 0
    var overdue = 0
    var dueThisWeek = 0
    for t in tasks {
        if t.done {
            completed += 1
        } else if let at = dueAt(t) {
            if at < now {
                overdue += 1
            } else if at.timeIntervalSince(now) <= 7 * daySeconds {
                dueThisWeek += 1
            }
        }
    }

    // Only count back as far as you've actually been using the app: from the
    // earliest deadline on any task. Without this, two finished tasks would
    // claim a year of clear days. `compactMap` keeps only the non-nil dates,
    // and `.min()` is the earliest, or nil when nothing has a deadline.
    let daysInUse: Int
    if let earliest = tasks.compactMap({ dueAt($0) }).min() {
        let span = (today.addingTimeInterval(daySeconds).timeIntervalSince(earliest)) / daySeconds
        daysInUse = max(1, Int(span.rounded(.up)))
    } else {
        daysInUse = 0
    }
    let limit = min(maxStreakDays, daysInUse)

    // Walk back a day at a time while each day ended clean. The web stops
    // its loop with `break`; here the `while` condition does the stopping,
    // so the loop simply ends at the first day that ended with work overdue.
    var streak = 0
    while streak < limit
            && !hadOverdue(tasks, today.addingTimeInterval(daySeconds - Double(streak) * daySeconds)) {
        streak += 1
    }

    return TermStats(completed: completed, overdue: overdue,
                     dueThisWeek: dueThisWeek, streak: streak)
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Assignment+Deadline.swift` (replaces the file)

One new extension, marked `NEW in Phase 6b`, and the header's Phase line.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Assignment+Deadline.swift
//  Phase:   2 (time and deadline logic), changed in 6b (Completable)
//  Ports:   lib/store.tsx (taskDeadline, taskDueAt, byDeadline)
//
//  Summary: Teaches the Assignment model to speak the Deadline logic's language.
//           This lives outside Logic/ because it needs the model; the pure
//           functions in Logic/Deadline.swift stay model-free so they test on Linux.
//

import Foundation

/// Assignment already stores `due` and `dueTime`, so it satisfies the `Dated`
/// protocol with nothing to add. This empty extension just declares that it does,
/// which lets every function in Deadline.swift accept an Assignment directly.
extension Assignment: Dated {}

/// The same trick for Logic/Streak.swift: Assignment already has `done`, so
/// it is `Completable` too, and `termStats` can count real assignments.
// NEW in Phase 6b
extension Assignment: Completable {}

extension Assignment {
    /// The assignment's deadline as one value. `taskDeadline(task)` in lib/store.tsx:
    /// screens read this instead of poking at `due` and `dueTime` separately.
    var deadline: Deadline { deadlineOf(self) }

    /// The instant it stops being on time, or nil when undated. `taskDueAt` in the web app.
    var dueInstant: Date? { dueAt(self) }
}

/// Earliest deadline first, undated last, ties broken by title so the order is
/// stable. `byDeadline` in lib/store.tsx. Shaped for `sorted(by:)`, which wants a
/// closure that answers "does a come before b?", so it returns a Bool, not the
/// -1/0/1 that `compareDeadlines` returns. The Tasks screen (Phase 4) sorts with it.
func byDeadline(_ a: Assignment, _ b: Assignment) -> Bool {
    let order = compareDeadlines(a.deadline, b.deadline)
    if order != 0 { return order < 0 }
    // Same deadline: fall back to the title, compared the way a person reads it.
    return a.title.localizedCompare(b.title) == .orderedAscending
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Store+Assignments.swift` (replaces the file)

`PendingUndo` is widened, `course(_:)` is gone (it's in 4.4 now), `deleteAssignment` builds the new kind of `PendingUndo`, and `undoDelete` handles both kinds. Everything else is as you typed it in 4a.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Assignments.swift
//  Phase:   1 (save and load), rewritten in 4a (every task action),
//           changed in 6b (Undo covers classes too)
//  Ports:   lib/store.tsx (addTask, updateTask, deleteTask, undoDelete,
//           dismissUndo, toggleTask, taskById, liveTasks, and the checklist
//           edits the task detail screen makes through updateTask),
//           PendingUndo from lib/recovery.ts
//
//  Summary: Everything that changes an assignment, plus the Undo bar's two
//           actions, which since Phase 6b can bring back a deleted class too.
//           Each action changes the store and then saves to the phone straight
//           away, so "Saved on this device" is always true.
//

import Foundation

/// A delete that can still be taken back. `PendingUndo` in lib/recovery.ts.
/// `at` is when the delete happened; the Undo bar gives up 8 seconds later,
/// the web's `UNDO_WINDOW_MS`.
// CHANGED in Phase 6b: `assignmentID` became `item`, which says what kind of
// thing was deleted as well as which one. `label` and `at` are unchanged, so
// the Undo bar (Components/UndoBar.swift) didn't need to change at all.
struct PendingUndo: Equatable {
    /// What was deleted. Each case carries the id of the thing to bring back.
    /// The web stores a `kind` string plus a list of `ids`; an enum with an
    /// associated value says the same in one piece, and Swift checks that
    /// every `switch` over it handles both kinds. Phase 11 adds grades and notes.
    enum Item: Equatable {
        case assignment(UUID)
        case course(UUID)      // the class; its work comes back with it
    }

    let item: Item
    let label: String          // "Problem Set 4 deleted", "Biology deleted"
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

    // CHANGED in Phase 6b: `course(_:)` moved to Store+Courses.swift.

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
        // CHANGED in Phase 6b: the enum case says it was an assignment.
        pendingUndo = PendingUndo(item: .assignment(id),
                                  label: "\(title.isEmpty ? "Assignment" : title) deleted",
                                  at: now)
        save()
    }

    /// Brings back whatever the Undo bar is offering. `undoDelete`.
    // CHANGED in Phase 6b: an assignment or a whole class
    func undoDelete() {
        guard let undo = pendingUndo else { return }
        // `switch` over the enum. `case .assignment(let id)` matches that
        // case AND pulls out the id it carries into a new constant, `id`.
        switch undo.item {
        case .assignment(let id):
            if let index = assignments.firstIndex(where: { $0.id == id }) {
                assignments[index].deletedAt = nil
            }
        case .course(let id):
            // The class and the work that went with it (Store+Courses.swift).
            restoreCourse(id)
        }
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

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Courses.swift` (replaces the file)

`course(_:)` arrives from 4.3 unchanged; `deleteCourse` and `restoreCourse` are new.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Courses.swift
//  Phase:   5b (classes: add and edit), changed in 6b (delete, with Undo)
//  Ports:   lib/store.tsx (liveClasses, activeClasses, classById, addClass,
//           updateClass, deleteClass, and the class half of restoreItems)
//
//  Summary: Reading and changing classes. Like the assignment actions, each
//           change saves to the phone straight away. Deleting a class takes
//           its assignments, grades and notes with it, all stamped with the
//           same moment, so Undo brings back exactly that set (D-21).
//

import Foundation

extension Store {
    // MARK: - Reading

    /// Every class that hasn't been deleted. `liveClasses` in lib/store.tsx.
    // CHANGED in Phase 6b: comment only, `course(_:)` now lives below
    var liveCourses: [Course] {
        courses.filter { $0.deletedAt == nil }
    }

    /// The live classes on this term's timetable: archived ones left out.
    /// `activeClasses` in lib/store.tsx. Today's week draws these.
    var activeCourses: [Course] {
        liveCourses.filter { !$0.archived }
    }

    /// The live class with this id, or nil (also for Inbox work, which has
    /// no class). `classById` in lib/store.tsx.
    // NEW in Phase 6b: moved here from Store+Assignments.swift, unchanged
    func course(_ id: UUID?) -> Course? {
        // No class id means Inbox: nothing to look up.
        guard let id else { return nil }
        return courses.first(where: { $0.id == id && $0.deletedAt == nil })
    }

    // MARK: - Adding and editing

    /// Adds a new class. `addClass` in lib/store.tsx (its XP credit comes in Phase 12).
    func addCourse(_ course: Course) {
        courses.append(course)
        save()
    }

    /// Replaces a class with an edited copy, matched by id. `updateClass` on the
    /// web takes only the changed fields; the form here hands back the whole
    /// edited class, the same choice `updateAssignment` made in Phase 4a.
    func updateCourse(_ edited: Course) {
        guard let index = courses.firstIndex(where: { $0.id == edited.id }) else { return }
        courses[index] = edited
        save()
    }

    // MARK: - Deleting
    // NEW in Phase 6b

    /// Moves a class, and everything filed under it, to Recently Deleted.
    /// `deleteClass` in lib/store.tsx. Nothing is erased: every item gets
    /// the SAME `deletedAt`, which is what makes Undo exact. Work you had
    /// already deleted keeps its own older stamp, so it stays deleted.
    /// The children keep their `courseID`, so the links survive the trip.
    func deleteCourse(_ id: UUID) {
        guard let index = courses.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = Date.now
        courses[index].deletedAt = now

        // Stamp the class's live work. `for i in list.indices where ...`
        // visits only the positions that match the condition, so there's
        // nothing to skip or stop: it changes exactly the items that belong.
        for i in assignments.indices where assignments[i].courseID == id && assignments[i].deletedAt == nil {
            assignments[i].deletedAt = now
        }
        for i in grades.indices where grades[i].courseID == id && grades[i].deletedAt == nil {
            grades[i].deletedAt = now
        }
        for i in notes.indices where notes[i].courseID == id && notes[i].deletedAt == nil {
            notes[i].deletedAt = now
        }

        // Offer Undo: "Biology deleted".
        pendingUndo = PendingUndo(item: .course(id),
                                  label: "\(courses[index].name) deleted",
                                  at: now)
        save()
    }

    /// Brings a deleted class back with exactly the work that went with it:
    /// the items whose `deletedAt` matches the class's own. The class half of
    /// `restoreItems` in lib/store.tsx. It doesn't save by itself, because its
    /// caller (`undoDelete`, and Recently Deleted in Phase 11) saves once at
    /// the end.
    func restoreCourse(_ id: UUID) {
        // The class must exist and be deleted; its stamp is the key.
        guard let index = courses.firstIndex(where: { $0.id == id }),
              let stamp = courses[index].deletedAt else { return }
        courses[index].deletedAt = nil

        // Only the work stamped at that same moment. Something deleted on its
        // own last week has a different stamp and stays in Recently Deleted.
        for i in assignments.indices where assignments[i].courseID == id && assignments[i].deletedAt == stamp {
            assignments[i].deletedAt = nil
        }
        for i in grades.indices where grades[i].courseID == id && grades[i].deletedAt == stamp {
            grades[i].deletedAt = nil
        }
        for i in notes.indices where notes[i].courseID == id && notes[i].deletedAt == stamp {
            notes[i].deletedAt = nil
        }
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Today/TodaySections.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodaySections.swift
//  Phase:   6b (Today: your work and your classes)
//  Ports:   TermGlance and Stat, the Assignments section and the My Classes
//           section of app/home/page.tsx
//
//  Summary: The three blocks under the picked day on Today: four numbers
//           about your term, your next four open assignments, and your classes
//           with Edit and Delete. Deleting asks first, then the Undo bar can
//           bring the class back with all its work.
//

import SwiftUI

// MARK: - This term at a glance

/// "12 done · 3 this week · 5 days clear". `TermGlance` in app/home/page.tsx.
/// Hidden until you have any work: a row of zeroes on day one is just noise.
struct TermGlance: View {
    @Environment(Store.self) private var store
    /// The moment to count from, from Today's ticking clock.
    let now: Date

    var body: some View {
        let work = store.liveAssignments
        let accent = store.profile.accent

        // An `if` with no `else` in a body: with no work, nothing is drawn.
        if !work.isEmpty {
            let stats = termStats(work, now)
            HStack(spacing: 10) {
                stat(stats.completed, "done", Theme.ink)
                divider
                stat(stats.dueThisWeek, "this week",
                     stats.dueThisWeek > 0 ? Theme.brand(accent) : Theme.ink)
                divider
                // Overdue work takes the last slot when there is any; the
                // streak only shows while you're clear.
                if stats.overdue > 0 {
                    stat(stats.overdue, "overdue", Theme.dangerInk)
                } else {
                    stat(stats.streak, stats.streak == 1 ? "day clear" : "days clear", Theme.goodInk)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardStyle()
        }
    }

    /// One number with its label under it. `Stat` in app/home/page.tsx.
    private func stat(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted2)
        }
        .frame(maxWidth: .infinity)
        // Read "5, days clear" as one item, not two.
        .accessibilityElement(children: .combine)
    }

    /// The thin line between two numbers.
    private var divider: some View {
        Rectangle()
            .fill(Theme.surface2)
            .frame(width: 1, height: 32)
    }
}

// MARK: - Assignments

/// Your four soonest open assignments, with a count and a way to the Tasks
/// tab. The Assignments section of app/home/page.tsx.
struct AssignmentsPreview: View {
    @Environment(Store.self) private var store
    let now: Date
    /// What "View all" does. Today hands in "switch to the Tasks tab".
    let onViewAll: () -> Void

    var body: some View {
        let accent = store.profile.accent
        // Open work, soonest due first. `byDeadline` keeps undated work at the
        // end, never mixed in with dated work (a product rule).
        let open = store.liveAssignments.filter { !$0.done }.sorted(by: byDeadline)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Assignments")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                // How many are open, in a coral bubble.
                if !open.isEmpty {
                    Text("\(open.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.subject(.coral), in: Capsule())
                }
                Spacer()
                Button(action: onViewAll) {
                    HStack(spacing: 4) {
                        Text("View all")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.brandSoft(accent), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if open.isEmpty {
                Text("🎉 No open assignments.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .cardStyle()
            } else {
                // `prefix(4)` takes the first four (or fewer); `Array(...)`
                // turns that slice back into a normal list for ForEach.
                ForEach(Array(open.prefix(4))) { assignment in
                    row(assignment, accent)
                }
            }
        }
    }

    /// One assignment. Tapping it opens its own detail screen, not the list:
    /// the web learned that landing on a list made you find it a second time.
    private func row(_ a: Assignment, _ accent: Profile.Accent) -> some View {
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, now)

        // `NavigationLink(value:)` pushes the detail; TodayView says what to
        // show for an AssignmentLink with `.navigationDestination`.
        return NavigationLink(value: AssignmentLink(id: a.id)) {
            HStack(spacing: 12) {
                // The class color, indigo for Inbox work like the web.
                Circle()
                    .fill(Theme.subject(course?.color ?? .indigo))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Only exams get a badge here (the Tasks list also marks quizzes).
                        if a.kind == .exam {
                            Text("EXAM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.warnInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.warnSoft, in: Capsule())
                        }
                        Text(a.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    // The class name, or "-" for Inbox work, as on the web.
                    Text(course?.name ?? "-")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // The deadline pill: red when it's urgent, quiet otherwise.
                Text(due.text)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(due.urgent ? Theme.dangerInk : Theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(due.urgent ? Theme.dangerSoft : Theme.brandSoft(accent), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - My Classes

/// Every class on this term's timetable, with Edit and Delete. The My Classes
/// section of app/home/page.tsx.
struct MyClassesSection: View {
    @Environment(Store.self) private var store
    /// What "Add" does, and what the pencil does. Today opens its sheets.
    let onAdd: () -> Void
    let onEdit: (Course) -> Void

    /// The class whose trash button was tapped, waiting for you to confirm.
    /// nil means no question is being asked.
    @State private var deleting: Course?

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Classes")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.brandSoft(accent), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Archived classes stay out, like the week: `activeCourses`.
            ForEach(store.activeCourses) { course in
                row(course)
            }
        }
        // The "are you sure?" question, as an iOS action sheet. It shows
        // while `isPresented` is true; `presenting:` hands the class to the
        // buttons, so they act on the class you tapped even if the list
        // changes underneath. iOS adds the Cancel button by itself. The web
        // asks the same question inline, under the row.
        .confirmationDialog(deleting.map { "Delete “\($0.name)”?" } ?? "",
                            isPresented: confirmShown,
                            titleVisibility: .visible,
                            presenting: deleting) { course in
            Button("Delete", role: .destructive) {
                store.deleteCourse(course.id)
            }
        }
    }

    /// The dialog wants a true/false binding; the real state is `deleting`.
    /// `get` says "showing while a class is waiting", and when iOS closes the
    /// dialog (Cancel, Delete or a tap outside) `set` clears it.
    private var confirmShown: Binding<Bool> {
        Binding(get: { deleting != nil },
                set: { showing in
                    if !showing { deleting = nil }
                })
    }

    /// One class: its book, name and when it meets, then Edit and Delete.
    private func row(_ course: Course) -> some View {
        HStack(spacing: 12) {
            SubjectBook(color: course.color, short: course.short, compact: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                // "Mon/Wed 09:00–10:15 · Room 4", from Phase 5a.
                Text(meetingSummary(course))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            circleButton("pencil", Theme.muted, label: "Edit class") {
                onEdit(course)
            }
            circleButton("trash", Theme.faint, label: "Delete class") {
                deleting = course
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }

    /// A small round icon button on the quiet surface. `action` is the code to
    /// run when it's tapped: a function passed in like any other value.
    /// `@escaping` is Swift's word for "this closure is kept and run later"
    /// (the Button holds on to it until you tap), and the compiler asks for it.
    private func circleButton(_ symbol: String, _ color: Color, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Theme.surface2, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift` (replaces the file)

The same as 6a apart from the blocks marked `NEW in Phase 6b`: the `tab` binding, the three sections under the day, the Undo bar and the destination for a tapped assignment, plus the header.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift
//  Phase:   6b (your work and your classes), after 6a (the picked day),
//           5a (the week) and 5b (class details)
//  Ports:   app/home/page.tsx (the greeting, the quote, the picked day's
//           classes, every "nothing here" message, the term glance, the
//           assignments and My Classes) and app/week/page.tsx (the week,
//           folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Below it, the quote
//           banner, the picked day's classes, and then your term at a glance,
//           your next assignments and your classes, with Edit and Delete.
//

import SwiftUI

/// One presentation at a time: a tapped meeting's details, a class's editor,
/// or the form for a new class. Each case carries what its sheet needs.
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)
    case newCourse                    // NEW in Phase 6a: "Add a class manually"

    var id: String {
        switch self {
        case .meeting(let opened):
            "meeting-\(opened.courseID)-\(opened.meetingID)-\(dayOf(opened.date))"
        case .editCourse(let course):
            "course-\(course.id)"
        case .newCourse:              // NEW in Phase 6a
            "new-course"
        }
    }
}

/// The days' full English names, Monday first. `DAY_NAMES` in
/// app/home/page.tsx, for "View Thursday's schedule" and the title.
// NEW in Phase 6a
private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The selected tab, owned by RootView. A binding, so "View all" in the
    /// assignments can switch to the Tasks tab from in here.
    // NEW in Phase 6b
    @Binding var tab: MainTab

    // MARK: Screen state
    // None of this is saved: Today always opens on this week, folded,
    // with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    /// The sheet currently presented, or nil when none is open.
    @State private var sheet: TodaySheet?

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the Now tag moves on and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // `activeClasses` in lib/store.tsx.
            let courses = store.activeCourses

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)

                    // NEW in Phase 6a: the quote, then the picked day. Before
                    // the first class there is nothing to show for any day, so
                    // the setup steps take the day's place (the web's isFirstRun).
                    QuoteBanner(now: now)
                    if courses.isEmpty {
                        firstRun(accent)
                    } else {
                        daySection(courses, now, accent)

                        // NEW in Phase 6b: the lists under the day
                        // (TodaySections.swift). Like the web, they wait
                        // until there's a first class.
                        TermGlance(now: now)
                            .padding(.top, 8)
                        AssignmentsPreview(now: now, onViewAll: { tab = .tasks })
                            .padding(.top, 8)
                        MyClassesSection(onAdd: { sheet = .newCourse },
                                         onEdit: { course in sheet = .editCourse(course) })
                            .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            // Browsing weeks keeps the picked weekday inside the visible week.
            .onChange(of: weekOffset) { _, offset in
                selectedDay = weekDates(now, offset)[dayIndex(of: selectedDay)]
            }
            // Keep following today across midnight until another day is picked.
            .onChange(of: Calendar.current.startOfDay(for: now)) { previous, current in
                if weekOffset == 0 && selectedDay == previous {
                    selectedDay = current
                }
            }
        }
        .background(Theme.canvas)
        // NEW in Phase 6b: the Undo bar after deleting a class (or an
        // assignment from its detail screen), the same one Tasks uses.
        .undoBar()
        // Where a tapped assignment goes, as on the Tasks tab.
        .navigationDestination(for: AssignmentLink.self) { link in
            AssignmentDetailView(assignmentID: link.id)
        }
        // CHANGED in Phase 6a: "Today", or the picked day's name, like the
        // web's heading.
        .navigationTitle(Calendar.current.isDateInToday(selectedDay)
                         ? "Today" : dayNames[dayIndex(of: selectedDay)])
        // The calendar button where the web's gear used to be (the gear's
        // job moved to the Profile tab). It opens and folds the week.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWeek()
                } label: {
                    Image(systemName: weekOpen ? "calendar.circle.fill" : "calendar")
                }
                .accessibilityLabel(weekOpen ? "Fold the week away" : "Show the whole week")
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .meeting(let opened):
                CourseSheet(opened: opened)
            case .editCourse(let course):
                NavigationStack {
                    CourseFormView(editing: course)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            case .newCourse:          // NEW in Phase 6a
                NavigationStack {
                    CourseFormView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - The week

    /// The card holding the week: the grid when open, the strip when folded,
    /// and the handle underneath either way.
    private func weekCard(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let start = store.profile.termStart
        let end = store.profile.termEnd

        return VStack(spacing: 6) {
            // `$weekOffset` hands the child a binding: the strip and the grid
            // both read and change the same week.
            if weekOpen {
                WeekGrid(courses: courses, termStart: start, termEnd: end, now: now,
                         weekOffset: $weekOffset, accent: accent,
                         onOpen: { slot, day, date in
                             sheet = .meeting(OpenedMeeting(courseID: slot.course.id,
                                                            meetingID: slot.meeting.id,
                                                            day: day, date: date))
                         },
                         onSchedule: { course in
                             sheet = .editCourse(course)
                         })
                    .transition(.opacity)
            } else {
                WeekStrip(courses: courses, termStart: start, termEnd: end, now: now,
                          weekOffset: $weekOffset, selected: $selectedDay, accent: accent)
                    .transition(.opacity)
            }
            handle
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// The little bar under the week. Tap it, or drag it down to open and up
    /// to fold. `highPriorityGesture` means a drag that starts on the handle
    /// moves the week instead of scrolling the page.
    private var handle: some View {
        Capsule()
            .fill(Theme.lineStrong)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .onTapGesture { toggleWeek() }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10).onEnded { drag in
                    // Down by 24 points or more opens; up by 24 or more folds.
                    if drag.translation.height > 24 && !weekOpen { toggleWeek() }
                    if drag.translation.height < -24 && weekOpen { toggleWeek() }
                }
            )
            // To VoiceOver this is a button with a clear name.
            .accessibilityElement()
            .accessibilityLabel(weekOpen ? "Fold the week away" : "Open the whole week")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggleWeek() }
    }

    /// Opens or folds the week. `withAnimation` animates every change the
    /// toggle causes: the card grows or shrinks smoothly, and the strip and
    /// grid cross-fade because each has `.transition(.opacity)`.
    private func toggleWeek() {
        withAnimation(reduceMotion ? nil : .snappy) {
            weekOpen.toggle()
        }
    }

    // MARK: - The picked day
    // NEW in Phase 6a: replaces the one-line day card from Phase 5a.

    /// The picked day: its class cards, then whichever message explains an
    /// empty day, then the way on to the next day. The middle of the web's
    /// home page. `@ViewBuilder` lets one function return different views
    /// depending on the `if`s, and allows the `let`s at the top.
    @ViewBuilder
    private func daySection(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let day = selectedDay
        let col = dayIndex(of: day)
        let start = store.profile.termStart
        let end = store.profile.termEnd
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let dayName = dayNames[col]

        // A timetable only exists inside its semester. Outside it, nothing is
        // listed and the screen says so instead of "you're free".
        let inTerm = isWithinTerm(start, end, day)
        let slots = expandClassMeetings(courses)
        // This day's meetings, earliest first.
        let dayClasses = inTerm
            ? slots.filter { $0.meeting.days.contains(col) }.sorted { $0.meeting.start < $1.meeting.start }
            : []

        // "You're all free this week!" only once you've looked six or more
        // days ahead and nothing in the picked day's week falls in the term.
        // (The web's `checkedAll`: an empty day alone doesn't mean a free week.)
        let dates = weekDates(day, 0)
        let weekHasClasses = slots.contains { slot in
            slot.meeting.days.contains { d in
                dates.indices.contains(d) && isWithinTerm(start, end, dates[d])
            }
        }
        let checkedAll = daysAhead(of: now) >= 6 && dayClasses.isEmpty && !weekHasClasses

        // Today gets Now / Done tags; any other day gets -1, which turns them off.
        let nowMin = isToday ? minuteOfDay(now) : -1
        let nextName = dayNames[(col + 1) % 7]

        // The classes, one card each. ForEach gives every card its slot's id,
        // which is how each ClassCard keeps its own open/folded state.
        if !dayClasses.isEmpty {
            VStack(spacing: 12) {
                ForEach(dayClasses) { slot in
                    ClassCard(slot: slot, nowMin: nowMin)
                }
            }
        }

        // At most one message: outside the term, a free day, or a free week.
        if !inTerm {
            let label = termRangeLabel(start, end)
            emptyState(emoji: "📅", title: "Outside your semester",
                       message: label.map { "Your term runs \($0), so nothing is timetabled for \(isToday ? "today" : dayName)." }
                           ?? "Nothing is timetabled for this date.")
        } else if checkedAll {
            emptyState(emoji: "🎉", title: "You're all free this week!",
                       message: "No classes scheduled this week. Enjoy your time!")
            Button {
                showDay(Calendar.current.startOfDay(for: now), now)
            } label: {
                Text("Back to Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else if dayClasses.isEmpty {
            emptyState(emoji: "🌿", title: "Looks like you're free!",
                       message: isToday ? "Nothing scheduled for today." : "Nothing on \(dayName).")
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack(spacing: 8) {
                    Text("View \(nextName)'s schedule")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Theme.brand(accent).opacity(0.32), radius: 12, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }

        // On a day with classes, or outside the term, a quieter way on.
        if !dayClasses.isEmpty || !inTerm {
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack {
                    Text("View \(nextName)'s schedule")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.brand(accent).opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.brand(accent).opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// The big emoji tile, a heading and a line of explanation, centred.
    /// The web repeats this block for each of its three messages.
    private func emptyState(emoji: String, title: String, message: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 38))
                .frame(width: 80, height: 80)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.bottom, 14)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    // MARK: - First run
    // NEW in Phase 6a

    /// Before the first class: one job, get a class in. The web's first-run
    /// card leads with "Import my schedule"; importing arrives in Phase 13,
    /// so for now the manual route is the button, above the three steps.
    private func firstRun(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 10) {
            Button {
                sheet = .newCourse
            } label: {
                Text("Add a class manually")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(color: Theme.brand(accent).opacity(0.3), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)

            onboardStep(1, "Import or add your classes",
                        "Drop in your school's calendar file, or type a class in, about 20 seconds each.", accent)
            // The web says "on the Week tab"; on the phone the week lives
            // behind Today's calendar button (D-19).
            onboardStep(2, "Your week fills in",
                        "See today at a glance, and the whole week from the calendar button.", accent)
            onboardStep(3, "Get reminded",
                        "A heads-up before class starts, and before work is due.", accent)
        }
    }

    /// One numbered step. `OnboardStep` in app/home/page.tsx.
    private func onboardStep(_ n: Int, _ title: String, _ body: String, _ accent: Profile.Accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 26, height: 26)
                .background(Theme.brandSoft(accent), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }

    // MARK: - Moving between days
    // NEW in Phase 6a

    /// Picks `day` and moves the strip to the week that holds it, so "View
    /// Monday's schedule" on a Sunday lands on next week's Monday.
    private func showDay(_ day: Date, _ now: Date) {
        // Whole weeks between this week's Monday and the day, rounded down,
        // so a day in last week is -1 and not 0.
        let monday = weekDates(now, 0)[0]
        let days = Calendar.current.dateComponents([.day], from: monday, to: day).day ?? 0
        selectedDay = day
        weekOffset = Int((Double(days) / 7).rounded(.down))
    }

    /// How many days after today the picked day is (0 = today, -1 = yesterday).
    /// The web's `offset`. Counted in calendar days, so a daylight-saving
    /// change can't make it off by one.
    private func daysAhead(of now: Date) -> Int {
        let today = Calendar.current.startOfDay(for: now)
        return Calendar.current.dateComponents([.day], from: today, to: selectedDay).day ?? 0
    }

    /// "Good morning, Kelvin 👋". The web's `greeting(hour)` plus the first
    /// part of your username; just the greeting until you've set a name.
    // CHANGED in Phase 6a: the wave, as on the web.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? "\(hello) 👋" : "\(hello), \(first) 👋"
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/RootView.swift` (replaces the file)

One line changes: Today now gets the tab (`TodayView(tab: $tab)`), marked `CHANGED in Phase 6b`, plus the header. The rest is your Phase 5 file.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   3 (app shell), changed in 5a (Profile tab replaces Planner, D-19)
//           and 6b (Today can switch tabs)
//  Ports:   components/TabBar.tsx (four tabs with the Add button between them)
//
//  Summary: The screen under everything else. A custom bottom bar switches
//           between the four main screens, Today, Notes, Tasks and Profile,
//           with the brand Add button raised in the middle. The week now lives
//           inside Today. The whole app is tinted with the chosen accent and
//           forced to the chosen light/dark mode here.
//

import SwiftUI

/// Which of the four main tabs is showing. In the web app this is the current
/// `pathname`; here it is one piece of state the bar reads and writes.
// CHANGED in Phase 5a: `planner` is gone (the week is inside Today), `profile` is new
enum MainTab: Hashable { case today, notes, tasks, profile }

struct RootView: View {
    /// The shared store, for the accent and theme the whole app reads.
    @Environment(Store.self) private var store

    /// The selected tab, and whether the Add menu is open. `@State` means this
    /// view owns these values and redraws when they change.
    @State private var tab: MainTab = .today
    @State private var addOpen = false

    var body: some View {
        // Read the accent once; reading it here means the whole screen redraws
        // (new tint, new bar colors) the moment it changes in Profile.
        let accent = store.profile.accent

        // TabView keeps each screen and its navigation history alive when
        // switching tabs, including the selected day and expanded week.
        TabView(selection: $tab) {
            // CHANGED in Phase 6b: Today gets the tab, for "View all".
            NavigationStack { TodayView(tab: $tab) }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.today)
            NavigationStack { NotesView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.notes)
            NavigationStack { AssignmentsView().navigationTitle("Tasks") }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.tasks)
            NavigationStack { ProfileView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.profile)
        }
        // `safeAreaInset` pins the bar to the bottom and insets the screen above
        // it, so a list never scrolls underneath the bar.
        .safeAreaInset(edge: .bottom) {
            // CHANGED in Phase 5a: the bar also needs your name for the avatar.
            MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent,
                       name: store.profile.username)
        }
        // The warm ground behind everything, including under the bar.
        .background(Theme.canvas.ignoresSafeArea())
        // The accent tints buttons, pickers and links app-wide.
        .tint(Theme.brand(accent))
        // Force light or dark to match the profile, overriding the system setting.
        .preferredColorScheme(store.profile.theme == .dark ? .dark : .light)
        // The Add button opens this sheet.
        .sheet(isPresented: $addOpen) { AddMenu() }
    }
}

/// The bottom bar: two tabs, the Add button, two tabs. A rounded "glass" pill
/// floating above the canvas, matching components/TabBar.tsx.
private struct MainTabBar: View {
    @Binding var tab: MainTab
    @Binding var addOpen: Bool
    let accent: Profile.Accent
    /// Your username, for the letter on the Profile avatar. NEW in Phase 5a
    let name: String

    var body: some View {
        HStack(spacing: 0) {
            item(.today, "Today", "house.fill")
            item(.notes, "Notes", "book.fill")
            addButton
            item(.tasks, "Tasks", "checklist")      // CHANGED in Phase 5a: Planner removed
            profileItem                              // NEW in Phase 5a
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// One destination. Active gets the brand color, the rest stay faint, the
    /// same split the web bar makes with `--color-brand` vs `--color-faint`.
    private func item(_ which: MainTab, _ label: String, _ symbol: String) -> some View {
        let active = tab == which
        return Button {
            tab = which
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .frame(height: 26)      // CHANGED in Phase 5a: as tall as the avatar
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(active ? Theme.brand(accent) : Theme.faint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The Profile tab: your avatar instead of an icon, with a brand ring
    /// around it while the tab is open. (Phase 12 swaps that ring for your
    /// pet's tier ring, which used to sit on the + button on the web.)
    // NEW in Phase 5a
    private var profileItem: some View {
        let active = tab == .profile
        let brand = Theme.brand(accent)
        return Button {
            tab = .profile
        } label: {
            VStack(spacing: 4) {
                AvatarBadge(name: name, size: 22, accent: accent)
                    .padding(2)
                    .overlay(Circle().stroke(active ? brand : Color.clear, lineWidth: 1.5))
                Text("Profile").font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(active ? brand : Theme.faint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The raised brand circle in the middle. Opens the Add menu.
    private var addButton: some View {
        Button {
            addOpen = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.brandGradient(accent), in: Circle())
                .shadow(color: Theme.brand(accent).opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
        .frame(width: 62)       // a fixed middle slot, so the two halves balance
        .offset(y: -14)         // lifted above the bar, like the web's -mt-6
    }
}
```

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 6b: Today lists your work and classes; delete a class with Undo"
```

On the phone:

1. Under the day: **done**, **this week** and **days clear** (or **overdue** in red if something is late).
2. **Assignments**: the coral count, then your four soonest open ones, the exam with its EXAM badge. Tap one: its detail opens inside Today; go back. Tap **View all**: you're on the Tasks tab.
3. **My Classes**: all five sample classes. Tap a **pencil**: the class form opens; Cancel. Tap **+ Add**, make a class called "Test", save it, and give it an assignment from **+ → Assignment**.
4. Tap **Test**'s trash can: "Delete “Test”?". Tap **Delete**: Test leaves My Classes and the week, its assignment leaves both lists, and the bar says "Test deleted". Tap **Undo**: both come back.
5. Delete Test again and wait 8 seconds: the bar goes away by itself. **That's for real:** after the bar has gone, a deleted class can only come back from Recently Deleted, which arrives in Phase 11. Test with a throwaway class, not a real one.
6. Optional, if you can live without the sample classes until Phase 11: delete all five, and Today shows the first-run steps from 6a.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] The three numbers show, and an overdue assignment turns the last one red.
- [ ] Assignments shows at most four, soonest first; a row opens its detail; **View all** goes to Tasks.
- [ ] Edit and Add open the class form from My Classes.
- [ ] Deleting a class asks first, removes it and its work everywhere, and **Undo** brings back exactly those.
- [ ] The Undo bar clears itself after 8 seconds, on Today and on Tasks.

## 7. If it breaks

- **`invalid redeclaration of 'course'`**: `course(_:)` is still in `Store+Assignments.swift` as well as in `Store+Courses.swift`. 4.3 removes it from the first.
- **`cannot find 'restoreCourse' in scope`**: 4.3 is typed but 4.4 isn't yet.
- **`missing argument for parameter 'tab' in call`** (in RootView): 4.7's one-line change is missing.
- **`incorrect argument label in call (have 'assignmentID:label:at:', expected 'item:label:at:')`**: `deleteAssignment` still builds the old `PendingUndo`. Use `PendingUndo(item: .assignment(id), ...)`.
- **`cannot find type 'Completable' in scope`**: `Logic/Streak.swift` is missing or the protocol name is spelled differently there and in `Assignment+Deadline.swift`.
- **Tapping an assignment on Today does nothing:** the `.navigationDestination(for: AssignmentLink.self)` block is missing from TodayView.
- **Undo brings the class back but not its assignments:** in `restoreCourse`, the loops must compare with the class's own `stamp`, read *before* `courses[index].deletedAt = nil`.

---
title: "Phase 9a: Grades and GPA"
date: 2026-10-19
---

# Phase 9a: Grades and GPA

First of three parts of Phase 9. This guide builds on your clean Swift commit
`a66d453` (8d plus the notification fix), not the older 8c handoff. You confirmed
that the 8c selection/keyboard issue and notifications are fixed on the phone.
Your current project passed its 293 logic tests, 58 store tests and an iOS build
before this phase was prepared.

**Start here:** type the seven files in section 4, in order. The three files that
already exist are supplied in full; their changed spots are explained before
each block. Do not retype 8c, 8d or the notification fix.

**Verification (2026-10-19):** reference iOS build passed without warnings;
316/316 logic tests and 57/57 reference store tests passed. Kelvin's existing
store suites plus the new grade tests passed 69/69 against the new source in
a disposable package. The seven extracted guide blocks over `a66d453` are
identical to the reference and that reconstructed tree built without warnings.
No 9a phone/UI check has happened yet.

## 1. Goal

Open **Profile → Grades & GPA**, log a result, and see the class average and
this term's GPA change. Edit the result by tapping its row. Delete it, then tap
Undo. Close and reopen the app: the saved result is still there.

This part includes:

- A single add/edit sheet with class, optional assessment type, title, date,
  score, maximum and weight.
- Extra credit, a visible weight budget, Use remaining, and Save & add another.
- Credit-weighted GPA and standard/simple US scales. Existing custom bands
  remain readable; creating/editing a custom scale is 9b.
- Separate past-term results, newest date first with stable same-day order.
- Local save errors that retain the form draft, plus soft deletion and Undo.

**9b** adds the custom-scale editor, goals, projected GPA and what-if results.
**9c** adds finals countdown and local CSV sharing. Server PDF export remains
with authenticated Connect work; it is not part of this offline phase.

## 2. New Swift concepts

### Protocols and generic functions

The maths needs a score, a maximum, a weight and a course id. It doesn't need
the whole saved `Grade`. `GradedResult` describes just those fields.
`func classAverage<G: GradedResult>(_ grades: [G])` accepts an array of any one
type that supplies them. In the app, `extension Grade: GradedResult {}` signs
the existing model up. In the Linux tests, a tiny `Result` struct signs up.
Both call exactly the same function. This follows the protocol pattern already
used by your reminder and deadline logic.

`ScaleBand` moves from `Profile.swift` to `Logic/GPA.swift`. **Remove its old
definition** by replacing Profile with section 4.2. Its three JSON fields stay
the same, so this is not a data migration.

### A form draft and a committed result

The sheet owns text fields in `@State`; the store owns saved grades.
The sheet builds a `Grade` value when saving. The store validates it again,
attempts an atomic planner-file write, and returns `true` only after success.
If the write fails, the store restores its previous grade array and the sheet
keeps the draft. Tapping Save again uses the same UUID, preventing duplicate
results. A successful Save & add another gets a fresh UUID.

### Number formatting

`.formatted(.number.precision(.fractionLength(2)))` displays a two-place GPA
using the device's locale. This changes presentation, never the stored number.
The fields accept the device's decimal separator. Like the web's `Number("")`,
an empty score means zero; empty maximum or weight fails validation.

## 3. What maps from the web

| Web source | Native file / behavior |
|---|---|
| `lib/gpa.ts` | `Logic/GPA.swift`: averages, letters, points, credits, overall GPA, weight budgets, extra-credit hint, reading normalized scales |
| `lib/gpa.test.ts` | `GPATests.swift`: twins for the functions used in 9a; what-if, projection and editor diagnostics follow in 9b |
| Grade actions in `lib/store.tsx` | `Store+Grades.swift`; `Store+Assignments.swift` extends the existing Undo enum and switch |
| `app/grades/new/page.tsx`, `app/grades/[id]/edit/page.tsx`, `components/GradeFields.tsx` | One `GradeFormView` sheet; native fields replace the separate web editors |
| `app/grades/page.tsx` | `GradesView`; current classes and archived terms have separate GPA calculations |
| Profile's future Grades row | A real navigation link to Grades, as decided in D-19 |

The legacy Pro checks in the web files are compatibility code. There is no
payment gate here. Grades never expand a course's meetings into multiple
subjects, so lectures and labs cannot double-count its GPA.

Three deliberate details:

- A weight over the class's **combined** 100% warns but remains saveable, as on
  the web. Each individual entry must still be greater than 0 and at most 100.
- The native DatePicker produces a real local date string, and the store checks
  it. A missing/deleted class is rejected again at save time.
- Delete uses the shared eight-second Undo bar. A failed delete keeps the grade
  visible and preserves any previous Undo offer. Generic Undo retains the
  existing app behavior: a failed write is shown with Retry save.

## 4. Files, in the order to type them

Seven source files: four new, three replaced. Build after all seven; moving
`ScaleBand` temporarily creates a duplicate until section 4.2 is in place.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/GPA.swift` (new file)

Pure calculations, protocols and the moved ScaleBand. No SwiftUI and no store.
The custom-scale reader is included now because a saved custom profile must
never be silently calculated against the wrong bands.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Logic/GPA.swift
// Phase: 9a (grades and GPA)
// Ports: lib/gpa.ts (averages, bands, credits and weight budgets).
// Summary: Foundation-only maths. Protocols let both the real models and
// small Linux test values supply the same fields without importing SwiftUI.
//
import Foundation

/// Only the numbers and relationship the calculation needs.
protocol GradedResult {
    var courseID: UUID? { get }
    var score: Double { get }
    var max: Double { get }
    var weight: Double { get }
}

protocol GradedCourse {
    var id: UUID { get }
    var credits: Double? { get }
}

/// Moved unchanged from Profile.swift: its saved JSON keys stay identical.
struct ScaleBand: Codable, Hashable, Sendable {
    var min: Double
    var letter: String
    var points: Double
}

let DEFAULT_SCALE: [ScaleBand] = [
    .init(min: 93, letter: "A", points: 4),
    .init(min: 90, letter: "A-", points: 3.7),
    .init(min: 87, letter: "B+", points: 3.3),
    .init(min: 83, letter: "B", points: 3),
    .init(min: 80, letter: "B-", points: 2.7),
    .init(min: 77, letter: "C+", points: 2.3),
    .init(min: 73, letter: "C", points: 2),
    .init(min: 70, letter: "C-", points: 1.7),
    .init(min: 67, letter: "D+", points: 1.3),
    .init(min: 63, letter: "D", points: 1),
    .init(min: 60, letter: "D-", points: 0.7),
]

let SIMPLE_SCALE: [ScaleBand] = [
    .init(min: 90, letter: "A", points: 4),
    .init(min: 80, letter: "B", points: 3),
    .init(min: 70, letter: "C", points: 2),
    .init(min: 60, letter: "D", points: 1),
]

/// Empty is unknown, not zero. Weights need not add up to 100.
func classAverage<G: GradedResult>(_ grades: [G]) -> Double? {
    let valid = grades.filter { $0.max > 0 && $0.weight > 0 }
    guard !valid.isEmpty else { return nil }
    let total = valid.reduce(0) { $0 + $1.weight }
    return valid.reduce(0) { $0 + ($1.score / $1.max) * $1.weight } / total * 100
}

/// Highest threshold wins; a supplied zero band can name the fallback.
func letterFor(_ pct: Double, _ scale: [ScaleBand] = DEFAULT_SCALE) -> String {
    scale.sorted { $0.min > $1.min }.first { pct >= $0.min }?.letter ?? "F"
}

func pointsFor(_ pct: Double, _ scale: [ScaleBand] = DEFAULT_SCALE) -> Double {
    scale.sorted { $0.min > $1.min }.first { pct >= $0.min }?.points ?? 0
}

func creditsFor<C: GradedCourse>(_ course: C) -> Double {
    guard let credits = course.credits, credits > 0 else { return 1 }
    return credits
}

/// The caller supplies this term's courses, or one past term's courses.
func overallGpa<C: GradedCourse, G: GradedResult>(
    _ courses: [C], _ grades: [G], _ scale: [ScaleBand] = DEFAULT_SCALE
) -> Double? {
    var totalCredits = 0.0
    var totalPoints = 0.0
    for course in courses {
        if let average = classAverage(grades.filter { $0.courseID == course.id }) {
            let credits = creditsFor(course)
            totalCredits += credits
            totalPoints += pointsFor(average, scale) * credits
        }
    }
    return totalCredits == 0 ? nil : totalPoints / totalCredits
}

func usedWeight<G: GradedResult>(_ grades: [G]) -> Double {
    grades.filter { $0.max > 0 && $0.weight > 0 }.reduce(0) { $0 + $1.weight }
}

func remainingWeight<G: GradedResult>(_ grades: [G]) -> Double {
    Swift.max(100 - usedWeight(grades), 0)
}

/// Extra credit is allowed; the hint catches accidental extra zeroes.
func extraCreditHint(_ score: Double, _ max: Double) -> String? {
    guard score.isFinite, max.isFinite, max > 0, score > max else { return nil }
    return "That's above full marks, logged as extra credit (\(String(format: "%.0f", score / max * 100))%)."
}

/// This typed boundary consumes existing Codable bands. Decoding unknown
/// network data belongs to sync; the custom editor arrives in 9b.
func normalizeScale(_ raw: [ScaleBand]) -> [ScaleBand]? {
    var out: [ScaleBand] = []
    var seen: Set<String> = []
    for band in raw where out.count < 16 {
        let trimmed = band.letter.trimmingCharacters(in: .whitespacesAndNewlines)
        // The web caps letters by UTF-16 units, as JavaScript slice does.
        let letter = String(decoding: Array(trimmed.utf16.prefix(6)), as: UTF16.self)
        let key = letter.lowercased()
        if !letter.isEmpty, !seen.contains(key),
           band.min.isFinite, (0...100).contains(band.min),
           band.points.isFinite, (0...10).contains(band.points) {
            seen.insert(key)
            out.append(ScaleBand(min: (band.min * 10).rounded() / 10,
                                 letter: letter, points: (band.points * 100).rounded() / 100))
        }
    }
    return out.isEmpty ? nil : out.sorted { $0.min > $1.min }
}

/// Read custom bands already saved in a profile without silently replacing them.
func resolveScale(_ name: String?, custom: [ScaleBand] = []) -> [ScaleBand] {
    if name == "custom" { return normalizeScale(custom) ?? DEFAULT_SCALE }
    return name == "simple" ? SIMPLE_SCALE : DEFAULT_SCALE
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Profile.swift` (replaces the file)

Only the old ScaleBand declaration is replaced with a comment. All your profile
fields, defaults and Codable keys remain unchanged.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Profile.swift
//  Phase:   1 (complete data models)
//  Ports:   lib/store.tsx (Profile), lib/accents.ts, lib/feeds.ts (SavedFeed),
//           lib/gpa.ts (ScaleBand), lib/supabase/map.ts (profiles row)
//
//  Summary: Your preferences: name, theme, accent, quiet hours, term dates,
//           grade scale, saved calendar feeds and your own quotes.
//

import Foundation

//One saved Calender feed
struct SavedFeed: Identifiable, Codable, Hashable {
    var id = UUID()
    var url: String
    var label: String
    var lastSyncedAt: Date? = nil 
}

// Phase 9a: ScaleBand now lives in Logic/GPA.swift so Linux logic tests can
// use it too. Its Codable fields have not changed; old profiles still load.

struct Profile: Codable, Hashable {
    //Theme ligh or dark
    enum Theme: String, Codable {case light, dark}

    //App-wide accent
    enum Accent: String, Codable, CaseIterable { case babypink, ocean}

    //Letter-grade scale

    enum GradeScale: String, Codable {case standard, simple, custom}

    //who the user is
    var username = ""
    var avatarURL: String? = nil

    // How the app looks.
    var theme = Theme.light
    var accent = Accent.babypink    // Baby Pink is the default

    // Reminders.
    var postClassNudge = true       // "Did that class come with homework?"
    var quietStart: Int? = nil      // minutes from midnight; both nil = never quiet
    var quietEnd: Int? = nil

    // The term.
    var finalsDate: String? = nil   // "yyyy-MM-dd"
    var gradeScale: GradeScale? = nil
    var termStart: String? = nil
    var termEnd: String? = nil
    var termName: String? = nil     // "Fall 2026"
    var termSetupPrompted = false

    // Lists you build up.
    var importFeeds: [SavedFeed] = []   // at most 5
    var customScale: [ScaleBand] = []   // at most 16, used when gradeScale is .custom
    var quotes: [String] = []           // empty = the built-in quotes
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Store+Grades.swift` (new file)

The models adopt the maths protocols. The rest reads live grades, groups past
terms, and saves validated additions/edits/deletions. It needs 4.4's new
`.grade` Undo case, so build after both files are typed.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Store+Grades.swift
// Phase: 9a
// Ports: lib/store.tsx (grade actions) and app/grades' filtering.
// Summary: Grade CRUD, validation and the bridge to the pure GPA functions.
//
import Foundation

// These models already have every field the maths asks for.
extension Grade: GradedResult {}
extension Course: GradedCourse {}

extension Store {
    var liveGrades: [Grade] { grades.filter { $0.deletedAt == nil } }

    func grade(_ id: UUID) -> Grade? { liveGrades.first { $0.id == id } }

    /// Stable newest-day order: two grades entered on one date keep their order.
    func grades(for courseID: UUID) -> [Grade] {
        liveGrades.filter { $0.courseID == courseID }.sorted { $0.date > $1.date }
    }

    var gradeScale: [ScaleBand] {
        resolveScale(profile.gradeScale?.rawValue, custom: profile.customScale)
    }

    /// Past terms keep their own totals, in order of the courses in the store.
    var gradedPastTerms: [String] {
        var terms: [String] = []
        for course in liveCourses where course.archived && !grades(for: course.id).isEmpty {
            let term = gradeTerm(for: course)
            if !terms.contains(term) { terms.append(term) }
        }
        return terms
    }

    func gradeTerm(for course: Course) -> String {
        let term = course.term?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return term.isEmpty ? "Earlier" : term
    }

    func gradedCourses(in term: String) -> [Course] {
        liveCourses.filter {
            $0.archived && gradeTerm(for: $0) == term && !grades(for: $0.id).isEmpty
        }
    }

    /// Same form bounds as the web. More than full marks is valid. A missing
    /// or deleted class cannot receive a grade, even if a sheet was open.
    func validGrade(_ value: Grade) -> Bool {
        course(value.courseID) != nil &&
        !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        value.score.isFinite && value.score >= 0 &&
        value.max.isFinite && value.max > 0 &&
        value.weight.isFinite && value.weight > 0 && value.weight <= 100 &&
        isValidDate(value.date) && value.deletedAt == nil
    }

    /// Return true only after the file is written. A failure leaves the draft
    /// in the form and rolls back this array, so retry cannot add a duplicate.
    @discardableResult
    func addGrade(_ value: Grade) -> Bool {
        guard validGrade(value), !grades.contains(where: { $0.id == value.id }) else { return false }
        var clean = value
        clean.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let before = grades
        grades.append(clean)
        save()
        if lastSaveFailed { grades = before; return false }
        return true
    }

    @discardableResult
    func updateGrade(_ value: Grade) -> Bool {
        guard validGrade(value),
              let index = grades.firstIndex(where: { $0.id == value.id && $0.deletedAt == nil })
        else { return false }
        let before = grades[index]
        var clean = value
        clean.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        grades[index] = clean
        save()
        if lastSaveFailed { grades[index] = before; return false }
        return true
    }

    /// Soft-delete only; the shared Undo action restores this exact record.
    @discardableResult
    func deleteGrade(_ id: UUID) -> Bool {
        guard let index = grades.firstIndex(where: { $0.id == id && $0.deletedAt == nil })
        else { return false }
        let now = Date.now
        grades[index].deletedAt = now
        save()
        if lastSaveFailed { grades[index].deletedAt = nil; return false }
        let title = grades[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(item: .grade(id),
                                  label: "\(title.isEmpty ? "Grade" : title) deleted", at: now)
        return true
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Assignments.swift` (replaces the file)

Two additions only: `case grade(UUID)` inside `PendingUndo.Item`, and its
matching branch in `undoDelete()`. Assignment, course and note behavior stays
as it was. Your notification queue is in Store.swift and is not replaced here.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Assignments.swift
//  Phase:   1 (save and load), rewritten in 4a (every task action),
//           changed in 6b (Undo covers classes too) and 8a (and notes)
//  Ports:   lib/store.tsx (addTask, updateTask, deleteTask, undoDelete,
//           dismissUndo, toggleTask, taskById, liveTasks, and the checklist
//           edits the task detail screen makes through updateTask),
//           PendingUndo from lib/recovery.ts
//
//  Summary: Everything that changes an assignment, plus the Undo bar's two
//           actions, which since Phase 6b can bring back a deleted class too,
//           and since 8a a deleted note.
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
    /// every `switch` over it handles every kind. Phase 9 adds grades.
    enum Item: Equatable {
        case assignment(UUID)
        case course(UUID)      // the class; its work comes back with it
        case note(UUID)        // NEW in Phase 8a
        case grade(UUID)       // NEW in Phase 9a
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
    // CHANGED in Phase 8a: or a note
    func undoDelete() {
        guard let undo = pendingUndo else { return }
        // `switch` over the enum. `case .assignment(let id)` matches that
        // case AND pulls out the id it carries into a new constant, `id`.
        switch undo.item {
        case .grade(let id):
            // Phase 9a: a grade's date, class, score and weight stay intact.
            if let index = grades.firstIndex(where: { $0.id == id }) {
                grades[index].deletedAt = nil
            }
        case .assignment(let id):
            if let index = assignments.firstIndex(where: { $0.id == id }) {
                assignments[index].deletedAt = nil
            }
        case .course(let id):
            // The class and the work that went with it (Store+Courses.swift).
            restoreCourse(id)
        case .note(let id):
            // NEW in Phase 8a: the same as an assignment, one item back.
            if let index = notes.firstIndex(where: { $0.id == id }) {
                notes[index].deletedAt = nil
            }
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

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift` (new file)

Create the Grades folder. Both New Grade and tapping an existing result use this
sheet, so validation and weight-budget behavior cannot drift between editors.
On a first-run empty planner its Add your first class button opens the existing
course form.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift
// Phase: 9a
// Ports: app/grades/new, app/grades/[id]/edit and components/GradeFields.
// Summary: One sheet for adding and editing. A failed save keeps the draft.
//
import SwiftUI

struct GradeFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let editing: Grade?
    @State private var draftID: UUID
    @State private var courseID: UUID?
    @State private var title: String
    @State private var kind: Grade.Kind?
    @State private var score: String
    @State private var maximum: String
    @State private var weight: String
    @State private var date: Date
    @State private var message: String? = nil
    @State private var addedCount = 0
    @State private var showCourseForm = false

    /// State is seeded once per sheet, never overwritten by a store redraw.
    init(editing: Grade? = nil, courseID: UUID? = nil) {
        self.editing = editing
        _draftID = State(initialValue: editing?.id ?? UUID())
        _courseID = State(initialValue: editing?.courseID ?? courseID)
        _title = State(initialValue: editing?.title ?? "")
        _kind = State(initialValue: editing == nil ? .assignment : editing?.kind)
        _score = State(initialValue: editing.map { String($0.score) } ?? "")
        _maximum = State(initialValue: editing.map { String($0.max) } ?? "100")
        _weight = State(initialValue: editing.map { String($0.weight) } ?? "20")
        _date = State(initialValue: editing.flatMap {
            deadlineDayStart(Deadline(date: $0.date, time: nil))
        } ?? .now)
    }

    /// Match Number("") == 0 on the web. Decimal commas follow the device locale.
    private func number(_ text: String) -> Double {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        return Double(value.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".",
                                                 with: ".")) ?? .nan
    }

    private var draft: Grade {
        Grade(id: draftID, courseID: courseID, title: title, score: number(score),
              max: number(maximum), weight: number(weight), date: dayOf(date), kind: kind)
    }

    /// Exclude the item being edited, so its weight is not counted twice.
    private var otherGrades: [Grade] {
        store.liveGrades.filter { $0.courseID == courseID && $0.id != editing?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section { Text(message).foregroundStyle(Theme.danger) }
                }
                if addedCount > 0 {
                    Section { Text("\(addedCount) saved on this device.") }
                }
                if store.liveCourses.isEmpty {
                    Section {
                        Text("You need a class before you can log a grade.")
                        Button("Add your first class") { showCourseForm = true }
                    }
                } else {
                    Section("Class") {
                        Picker("Class", selection: $courseID) {
                            Text("Choose a class").tag(nil as UUID?)
                            ForEach(store.liveCourses) { course in
                                Text(course.name).tag(Optional(course.id))
                            }
                        }
                    }
                    Section("What was graded?") {
                        Picker("Type", selection: $kind) {
                            Text("No type").tag(nil as Grade.Kind?)
                            ForEach([Grade.Kind.assignment, .quiz, .exam, .project], id: \.self) {
                                Text($0.rawValue.capitalized).tag(Optional($0))
                            }
                        }
                        TextField("Title", text: $title)
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                    Section("Result") {
                        numberField("Score", text: $score)
                        numberField("Out of", text: $maximum)
                        if let hint = extraCreditHint(number(score), number(maximum)) {
                            Text(hint).font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                    Section("Weight in this class") {
                        numberField("Weight (%)", text: $weight)
                        budget
                    }
                    if editing == nil {
                        Section {
                            Button("Save & add another") { commit(another: true) }
                                .disabled(!store.validGrade(draft))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .tint(Theme.brand(store.profile.accent))
            .navigationTitle(editing == nil ? "New Grade" : "Edit Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit(another: false) }
                        .disabled(!store.validGrade(draft))
                }
            }
            .onChange(of: kind) { _, next in
                // The new form's type buttons fill an empty/default title.
                // Editing an existing result never renames it unexpectedly.
                let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasLabel = Grade.Kind.allCases.contains { $0.rawValue.capitalized == clean }
                if editing == nil, let next, clean.isEmpty || wasLabel {
                    title = next.rawValue.capitalized
                }
            }
            .sheet(isPresented: $showCourseForm) { CourseFormView() }
        }
    }

    /// Keep labels visible after typing, including for VoiceOver.
    private func numberField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(label)
        }
    }

    /// Warn above 100%, but allow saving: weighted averages still make sense.
    private var budget: some View {
        let used = usedWeight(otherGrades)
        let entered = number(weight)
        let pending = entered.isFinite && entered > 0 ? entered : 0
        let total = used + pending
        let left = remainingWeight(otherGrades)
        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: min(total, 100), total: 100)
                .tint(total > 100 ? Theme.danger : Theme.brand(store.profile.accent))
                .accessibilityLabel("Allocated grade weight")
                .accessibilityValue("\(total.formatted()) percent")
            Text(total > 100
                 ? "This puts the class at \(total.formatted())% of its weight. The average still works, but what do I still need can't be answered past 100%."
                 : "\(used.formatted())% already logged. This takes \(pending.formatted())% more, leaving \((100 - total).formatted())%.")
                .font(.footnote)
                .foregroundStyle(total > 100 ? Theme.danger : Theme.muted)
            if left > 0 && pending != left {
                Button("Use remaining \(left.formatted())%") { weight = String(left) }
            }
        }
    }

    /// Advance only after durable success. A failed attempt keeps its UUID,
    /// values and sheet; a successful next entry gets a fresh UUID.
    private func commit(another: Bool) {
        let saved = editing == nil ? store.addGrade(draft) : store.updateGrade(draft)
        guard saved else {
            message = store.lastSaveFailed
                ? "Couldn't save on this device. Your draft is still here. Tap Save to retry."
                : "This grade or its class is no longer available, or a field is invalid."
            return
        }
        message = nil
        if another {
            addedCount += 1
            let left = remainingWeight(store.liveGrades.filter { $0.courseID == courseID })
            title = ""
            score = ""
            maximum = "100"
            weight = String(left > 0 ? min(20, left) : 20)
            draftID = UUID()
        } else {
            dismiss()
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift` (new file)

Uses SubjectBook, shared colors/cards, an item-based sheet, and `.undoBar()`.
The wider layout is capped at 720 points; rows wrap rather than imposing a
fixed phone width. Dynamic Type and keyboard behavior still need device checks.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift
// Phase: 9a
// Ports: app/grades/page.tsx, reached from Profile (D-19).
// Summary: This term's credit-weighted GPA, results and separate past terms.
// Custom-scale editing and projections come in 9b; exports/countdown in 9c.
//
import SwiftUI

struct GradesView: View {
    @Environment(Store.self) private var store
    @State private var sheet: GradeSheet? = nil
    @State private var deleting: Grade? = nil

    /// One item binding avoids competing add and edit sheets.
    private struct GradeSheet: Identifiable {
        let id = UUID()
        var editing: Grade? = nil
        var courseID: UUID? = nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.lastSaveFailed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .foregroundStyle(Theme.danger)
                        Button("Retry save") { store.save() }
                    }
                    .font(.footnote)
                }
                overview
                scalePicker
                if store.activeCourses.isEmpty {
                    Text("No classes in this term yet. Add a class to start logging grades.")
                        .foregroundStyle(Theme.muted)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
                ForEach(store.activeCourses) { course in courseCard(course, canAdd: true) }
                ForEach(store.gradedPastTerms, id: \.self) { term in
                    pastTerm(term)
                }
            }
            .padding(16)
            // Keep the wider device layout readable without hardcoding a phone width.
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .navigationTitle("Grades")
        .tint(Theme.brand(store.profile.accent))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = GradeSheet(courseID: store.liveGrades.last?.courseID)
                } label: { Label("Add grade", systemImage: "plus") }
            }
        }
        .sheet(item: $sheet) { value in
            GradeFormView(editing: value.editing, courseID: value.courseID)
        }
        .alert("Delete this grade?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleting { store.deleteGrade(deleting.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("You can undo this deletion.")
        }
        .undoBar()
    }

    private var overview: some View {
        let gpa = overallGpa(store.activeCourses, store.liveGrades, store.gradeScale)
        let count = store.activeCourses.filter { !store.grades(for: $0.id).isEmpty }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT TERM GPA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            Text(gpa.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand(store.profile.accent))
                .monospacedDigit()
                .accessibilityLabel(gpa.map { "GPA \($0.formatted())" } ?? "No GPA yet")
            Text(count == 0 ? "Log your first result to see your GPA."
                 : "Across \(count) graded \(count == 1 ? "class" : "classes"). Weighted by credits; an unset credit counts as one.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Built-ins now; an existing custom scale remains selected and readable.
    private var scalePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Grade scale", selection: Binding(
                get: { store.profile.gradeScale ?? .standard },
                set: { next in
                    let old = store.profile.gradeScale
                    store.profile.gradeScale = next
                    store.save()
                    if store.lastSaveFailed { store.profile.gradeScale = old }
                }
            )) {
                Text("US 4.0 (plus/minus)").tag(Profile.GradeScale.standard)
                Text("US 4.0 (simple)").tag(Profile.GradeScale.simple)
                if store.profile.gradeScale == .custom || !store.profile.customScale.isEmpty {
                    Text("Custom").tag(Profile.GradeScale.custom)
                }
            }
            if store.profile.gradeScale == .custom && normalizeScale(store.profile.customScale) == nil {
                Text("Your custom scale is empty. Using US 4.0 for now.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func courseCard(_ course: Course, canAdd: Bool) -> some View {
        let grades = store.grades(for: course.id)
        let average = classAverage(grades)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SubjectBook(color: course.color, short: course.short, compact: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name).font(.headline).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(average.map { "\($0.formatted(.number.precision(.fractionLength(1))))% average" }
                         ?? "No grades logged yet")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    if course.credits != nil {
                        Text("\(creditsFor(course).formatted()) cr").font(.caption)
                    }
                }
                Spacer(minLength: 0)
                if let average {
                    Text(letterFor(average, store.gradeScale))
                        .font(.title2.bold())
                        .foregroundStyle(Theme.subjectInk(course.color))
                }
            }
            ForEach(grades) { grade in
                Divider()
                gradeRow(grade)
            }
            if canAdd {
                Button {
                    sheet = GradeSheet(courseID: course.id)
                } label: { Label("Add grade", systemImage: "plus") }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Add grade for \(course.name)")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func gradeRow(_ grade: Grade) -> some View {
        HStack(alignment: .top) {
            Button {
                sheet = GradeSheet(editing: grade)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(grade.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(grade.score.formatted()) / \(grade.max.formatted()) · \(grade.weight.formatted())% weight")
                    Text("\(grade.date)\(grade.kind.map { " · \($0.rawValue.capitalized)" } ?? "")")
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit grade")
            Button(role: .destructive) { deleting = grade } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Delete \(grade.title)")
        }
    }

    /// Archived courses never dilute today's headline. Their GPA is calculated
    /// with the same selected scale, matching the web's separate term sections.
    private func pastTerm(_ term: String) -> some View {
        let courses = store.gradedCourses(in: term)
        let gpa = overallGpa(courses, store.liveGrades, store.gradeScale)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Past term · \(term)")
                .font(.headline).foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            if let gpa {
                Text("\(gpa.formatted(.number.precision(.fractionLength(2)))) GPA")
                    .font(.subheadline)
            }
            ForEach(courses) { course in courseCard(course, canAdd: false) }
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (replaces the file)

The Grades & GPA placeholder leaves the coming-soon card and becomes a
NavigationLink below Reminders. The rest of Profile is your existing version.

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

                // Phase 9a: Grades now opens on Profile's navigation stack.
                NavigationLink {
                    GradesView()
                } label: {
                    HStack {
                        Label("Grades & GPA", systemImage: "graduationcap")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .frame(minHeight: 44)
                    .cardStyle()
                }

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
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

### Tests you copy, not type

After the seven source files are in place:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/GPATests.swift Tests/Logic/
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Persistence/GradeStoreTests.swift Tests/Store/
```

In **`scripts/test-store.sh`**, add `Store+Grades` to the end of the existing
source-name list, immediately after `Store+Notes` and before `; do`:

```bash
for source in Models Records Profile Store Store+Persistence Store+Assignments Store+Courses Assignment+Deadline Assignment+TaskView Models+Reminders Store+Planning Store+Notes Store+Grades; do
```

Keep the rest of your script, especially its private Documents path.
`scripts/test-logic.sh` already copies the entire Logic folder and needs no
change. The reference store runner now uses that same isolation approach.
The reference and your project have different older store suites, so their
totals differ; all tests in each suite must pass.

## 5. Run it

In your WSL terminal:

```bash
cd ~/ClassPing
scripts/test-logic.sh
scripts/test-store.sh
xtool dev build
xtool dev
```

The last command installs on your phone; run it yourself.

1. **First result:** Profile → Grades & GPA → Add grade. Choose a class, name it
   Midterm, enter 100 out of 100 with weight 30, and save.
2. **Weighted maths:** add 50 out of 100 with weight 70 to the same class.
   Its average must be 65%; standard scale gives D / 1.0 points. Extra unused
   classes must not lower the GPA.
3. **Edit and retry:** tap a row, change its score and cancel; the result must
   stay unchanged. Reopen, change it and save; the result and GPA must update.
   Save-failure injection is covered by the disposable tests, not by deliberately
   damaging your real planner.
4. **Extra credit:** save 105 out of 100. The hint should name extra credit,
   and saving must work.
5. **Weight budget:** try another 20% after a class reaches 100%. The warning
   must appear, but Save remains available for an otherwise valid result.
   While editing an existing 20% result, its own weight must not count twice.
6. **Batch entry:** Save & add another twice. The class, date and type stay;
   title and score reset, and each saved result has its own identity.
7. **Delete and Undo:** delete a result, undo, then relaunch. The original score,
   class, date, weight and type must all be restored.
8. **Scales:** a 90% result is A- / 3.7 on standard and A / 4.0 on simple.
   Relaunch to check the scale selection survived.
9. **Past terms:** if you have archived classes with grades, their separate
   term GPA must not affect the current headline.
10. **Presentation:** check Baby Pink and Ocean in light and dark, larger text,
    VoiceOver field/button names, the numeric keyboard, and a wider device
    if available. Verify the tab bar still yields to the keyboard and returns.

After these checks, commit your typed files and test-script change using your
normal Git workflow. Nothing was committed or installed by the agent.

## 6. Done when

- [ ] The typed tree builds without warnings and both local test scripts pass.
- [ ] Profile opens Grades; add, edit, Cancel, batch entry and relaunch work.
- [ ] Weighted averages, credit-weighted GPA and standard/simple scales match
      the examples above.
- [ ] Extra credit is accepted; over-allocation is explained.
- [ ] Delete and Undo preserve the exact saved result.
- [ ] Current and past terms remain separate.
- [ ] Keyboard, readable light/dark colors and both accents work on the phone.

Reference verification is not a phone pass. Confirm this checklist before
continuing with 9b.

## 7. If it breaks

- **Invalid redeclaration of ScaleBand:** replace Profile.swift from 4.2;
  there must be exactly one declaration, in Logic/GPA.swift.
- **Cannot find GradedResult, gradeScale or addGrade:** check GPA.swift is inside
  Logic and Store+Grades.swift is next to the other Store extensions. For store
  tests, add Store+Grades to the source list shown above.
- **Switch must be exhaustive:** add the `.grade` branch from 4.4 to Undo.
- **Save disabled:** choose a live class, enter a title, use a positive maximum
  and a weight greater than zero and no more than 100. Extra credit is allowed.
- **Save error:** the sheet keeps your draft. Free device storage if needed,
  then tap Save again; do not dismiss it to retry.
- **Reference tests complain that Documents changed:** the test isolation
  substitution deliberately stops if the persistence code changes. Update that
  substitution to the new accessor; never point a failure test at real data.
- **GPA is a dash:** no selected-term class has a usable grade yet. An archived
  class contributes only to its own past-term section.

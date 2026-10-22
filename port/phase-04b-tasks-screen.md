# Phase 4b: The Tasks screen

*Second half of Phase 4 (finishes old Milestones 3 and 4). Checked on 2026-10-16: `build-check.sh` gave `BUILD_OK` with no warnings for both the 4a and the 4b code, `logic-test.sh` passed 69/69 (26 new: task view, due labels, repeats). Re-checked on 2026-10-17 on top of your Phase 5 project (commit `3fd880f`): `BUILD_OK`, no warnings.*

> **Changed on 2026-10-17, before you typed it (D-25).** The Undo bar moved out of `AssignmentsView` into its own file, `Components/UndoBar.swift` (new section 4.5), so Today can show the same bar when you delete a class in Phase 6b. Everything else is as before. You already typed 4.1 (`Theme+Tasks.swift`) during Phase 5, so start at 4.2.

**Before you start:** Phase 4a is typed, building, committed and tried on the phone.

## 1. Goal

The Tasks tab becomes the real screen. **On your phone:** **Open / Done** at the top, a **Filters** chip, then your work under **Overdue · Today · Upcoming · No deadline** headings, earliest first, each row with its class dot, an Exam or Quiz badge, and a deadline pill that turns red when it's close. Tap the circle to complete a task. Tap the row for its detail: a big **Complete** button, notes, details, a checklist you can tick and add to, **Edit** (the 4a form in a sheet) and **Delete**. Deleting drops you back on the list with an **Undo** bar that disappears after 8 seconds. Your tab and filters are remembered across relaunches.

## 2. New Swift concepts

**`.sheet(item:)`.** Phase 3's `.sheet(isPresented:)` shows a sheet while a Bool is true. `.sheet(item:)` shows it while an *optional value* is non-nil, and hands that value to the sheet. That's exactly what Edit needs: "show the form for this assignment".

```swift
@State private var editing: Assignment? = nil
Button("Edit") { editing = a }                 // non-nil: the sheet opens
.sheet(item: $editing) { original in           // closes by setting it back to nil
    AssignmentFormView(editing: original)
}
```

The item must be `Identifiable`, which `Assignment` already is.

**`@AppStorage`.** A property saved in `UserDefaults`, the phone's small key-value store for preferences. Saving and loading happen for you, and the view redraws when it changes. It holds simple values (text, numbers, Bools), so the filters are stored as four of them:

```swift
@AppStorage("tasks.tab") private var tabRaw = "open"
```

**`.task(id:)` and `Task.sleep`.** `.task` runs async work while the view is on screen and cancels it when the view leaves. With `id:`, it also restarts whenever that value changes. The Undo bar uses it to wait 8 seconds and then clear itself:

```swift
.task(id: store.pendingUndo?.at) {
    try? await Task.sleep(for: .seconds(8))      // `Task` = Swift's concurrency type
    guard !Task.isCancelled else { return }
    store.dismissUndo()
}
```

This is also the clearest reason the model isn't called `Task`: Swift's own `Task` is right here. Phase 7 goes deeper into `async`/`await`. The bar and its timer live in `Components/UndoBar.swift`, packaged as a view modifier, so a screen adds both with one line: `.undoBar()`.

You'll also build two hand-made bindings with `Binding(get:set:)`, to connect the Open/Done picker and the filter bar to the saved values. You met `@Binding` in Phase 3's tab bar. `TaskFilterBar` is your first view that *takes* bindings from its parent.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `app/tasks/page.tsx` | `Screens/Tasks/AssignmentsView.swift` | Same tabs, groups, empty messages and row look. A row opens the detail screen straight away (on the web it unfolds in place first; on a phone the detail does that job). Not here yet: trophies, level, study timer (Phases 10 and 12), the boss fight (left out), quick add (Phase 15), the desktop-only Cards view |
| `components/TaskFilterBar.tsx` | `Screens/Tasks/TaskFilterBar.swift` | Same chips and rules. The chips scroll sideways instead of wrapping |
| `useTaskViewPrefs` (localStorage) | `@AppStorage` in `AssignmentsView` | Same remembered tab and filters, cleaned up by the ported `normalizeViewPrefs` |
| `app/tasks/[id]/page.tsx` | `Screens/Tasks/AssignmentDetailView.swift` | Header, Complete / Mark as open, notes, details, checklist, delete. Later phases add the day plan, reminder controls and exam prep (7, D-23), linked notes (8), the grade prompt (9) and the study timer (10) |
| the undo strip in `components/StatusChrome.tsx` | `Components/UndoBar.swift`, attached with `.undoBar()` | A view modifier. The web shows it on every page; here each screen that can delete adds it: Tasks now, Today in Phase 6b (D-25) |
| `PALETTE[color].bar`, the status colors in `globals.css` | `Design/Theme+Tasks.swift` | An extension, so `Theme.swift` stays as you typed it |

## 4. Files, in the order to type them

**First delete the Phase 2 list.** The new `AssignmentsView` lives in `Screens/Tasks/`, and two files declaring the same type won't build:

```bash
cd ~/ClassPing/Sources/ClassPing
git rm AssignmentsView.swift
```

`RootView.swift` doesn't change: it already shows `AssignmentsView()` on the Tasks tab, and that name now finds the new screen.

### 4.1 `~/ClassPing/Sources/ClassPing/Design/Theme+Tasks.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Tasks.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   app/globals.css (--surface-2, --line-strong, the soft/ink status
//           pairs), lib/palette.ts (each subject color's dot, `bar`)
//
//  Summary: The extra tokens the Tasks screen needs: the class color dots,
//           the soft backgrounds and inks for Overdue / Exam / Quiz pills, and
//           two quieter surfaces. Added as an extension so Theme.swift stays as typed.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade. Theme.swift's own `dyn` is private to
/// that file, so this file has its own copy. `fileprivate` = only this file.
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

/// A see-through color from 0 to 255 values, for the dark-mode tokens that the
/// CSS writes as `rgba(...)` and a hex string can't express.
fileprivate func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> UIColor {
    UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

extension Theme {
    // Quieter surfaces. `--surface-2` (pill backgrounds) and `--line-strong`
    // (the empty completion circle).
    static let surface2 = shade(UIColor(hex: "#E5E1D9"), UIColor(hex: "#2D2930"))
    static let lineStrong = shade(UIColor(hex: "#C6BEAF"), rgba(228, 214, 204, 0.28))

    // Status pairs: a soft background and the ink that reads on it.
    // Overdue / due soon. `--danger-soft` and `--danger-ink`.
    static let dangerSoft = shade(UIColor(hex: "#F1DEDA"), rgba(211, 113, 98, 0.18))
    static let dangerInk  = shade(UIColor(hex: "#A83632"), UIColor(hex: "#F0A79C"))
    // The Exam badge. `--warn-soft` and `--warn-ink`.
    static let warnSoft = shade(UIColor(hex: "#EEE2C8"), rgba(217, 179, 108, 0.18))
    static let warnInk  = shade(UIColor(hex: "#886221"), UIColor(hex: "#E2C28C"))
    // The Quiz badge. `--info-soft` and `--info-ink`.
    static let infoSoft = shade(UIColor(hex: "#DCE5EB"), rgba(142, 169, 201, 0.18))
    static let infoInk  = shade(UIColor(hex: "#365D7D"), UIColor(hex: "#ADC3DB"))

    /// A class's dot color, from its stored name. `PALETTE[color].bar` in
    /// lib/palette.ts: one hex per color, readable on both light and dark.
    static func subject(_ color: SubjectColor) -> Color {
        switch color {
        case .amber:  Color(hex: "#D9B36C")
        case .indigo: Color(hex: "#8EA9C9")
        case .coral:  Color(hex: "#C99C8D")
        case .teal:   Color(hex: "#9FBB8A")
        case .pink:   Color(hex: "#C99BAE")
        case .violet: Color(hex: "#A99BC7")
        case .mint:   Color(hex: "#A4C1A0")
        case .ocean:  Color(hex: "#8BB6C6")
        case .slate:  Color(hex: "#98A4B5")
        }
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Assignment+TaskView.swift` (new file)

Next to `Assignment+Deadline.swift`, directly in `Sources/ClassPing/`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Assignment+TaskView.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   lib/task-view.ts (`taskKind`), app/tasks/page.tsx (`typeLabel`)
//
//  Summary: Signs Assignment up for the Tasks logic in Logic/TaskView.swift,
//           and gives each kind its on-screen name. Like Assignment+Deadline,
//           this lives outside Logic/ because it needs the model.
//

import Foundation

/// Assignment already has `title`, `courseID`, `due` and `dueTime`, so the
/// only thing missing for `TaskListable` is the kind as plain text. With this,
/// `groupTasks`, `filterTasks` and `sortsBefore` all accept assignments.
extension Assignment: TaskListable {
    var kindName: String { kind.rawValue }
}

extension Assignment.Kind {
    /// The spelled-out type for the detail screen. `typeLabel` in app/tasks/page.tsx.
    var label: String {
        switch self {
        case .assignment: "Assignment"
        case .quiz:       "Quiz"
        case .exam:       "Exam"
        case .reminder:   "Reminder"
        }
    }

    /// The plural the filter chips use: "Assignments", "Quizzes"...
    /// `KINDS` in components/TaskFilterBar.tsx.
    var pluralLabel: String {
        switch self {
        case .assignment: "Assignments"
        case .quiz:       "Quizzes"
        case .exam:       "Exams"
        case .reminder:   "Reminders"
        }
    }
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Tasks/TaskFilterBar.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/TaskFilterBar.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   components/TaskFilterBar.tsx (the chip and its panel; the saved
//           preferences part lives in AssignmentsView as @AppStorage)
//
//  Summary: One "Filters" chip that opens a panel for narrowing the list by
//           subject, by type, and whether archived classes' work is shown.
//           When filters are on, the chip shows how many and "3 of 12" explains
//           why the list looks short.
//

import SwiftUI

struct TaskFilterBar: View {
    /// The filters, owned by the Tasks screen. `@Binding` means this view can
    /// read AND change a value that lives somewhere else: setting `filters`
    /// here writes straight back into the screen's storage.
    @Binding var filters: TaskFilters
    /// Whether the panel is open, also owned by the screen.
    @Binding var open: Bool

    /// Classes that actually have work in the list (a filter for an empty class
    /// is a dead end), how many tasks are showing, and out of how many.
    let courses: [Course]
    let showing: Int
    let total: Int
    let accent: Profile.Accent

    var body: some View {
        let active = filters.activeCount

        VStack(alignment: .leading, spacing: 10) {
            // The chip row: Filters (· count), then "3 of 12" and Clear when filtering.
            HStack(spacing: 8) {
                Button {
                    open.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Text("Filters")
                        if active > 0 { Text("· \(active)").bold() }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(active > 0 ? Theme.brandDeep(accent) : Theme.muted)
                    .background(active > 0 ? Theme.brand(accent).opacity(0.16) : Theme.surface2,
                                in: Capsule())
                }
                .buttonStyle(.plain)

                if active > 0 {
                    Text("\(showing) of \(total)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Clear") { filters = TaskFilters.defaults }
                        .font(.system(size: 12.5, weight: .semibold))
                }
            }

            // The panel, only while open.
            if open {
                VStack(alignment: .leading, spacing: 12) {
                    // Subject: All, then one chip per class. Tapping the active
                    // chip again turns it off, as on the web.
                    group("Subject") {
                        chip("All", filters.subject == nil) { filters.subject = nil }
                        ForEach(courses) { course in
                            chip(course.short.isEmpty ? course.name : course.short,
                                 filters.subject == course.id) {
                                filters.subject = filters.subject == course.id ? nil : course.id
                            }
                        }
                    }

                    // Type: All, then the four kinds. `allCases` exists because
                    // Kind is CaseIterable (Step 0 of Phase 4a put that back).
                    group("Type") {
                        chip("All", filters.kind == nil) { filters.kind = nil }
                        ForEach(Assignment.Kind.allCases, id: \.self) { kind in
                            chip(kind.pluralLabel, filters.kind == kind.rawValue) {
                                filters.kind = filters.kind == kind.rawValue ? nil : kind.rawValue
                            }
                        }
                    }

                    // Only worth asking when some class is archived.
                    if courses.contains(where: { $0.archived }) {
                        group("Archived classes") {
                            chip("Show their work", filters.includeArchived) { filters.includeArchived = true }
                            chip("Hide", !filters.includeArchived) { filters.includeArchived = false }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    /// A labelled row of chips that scrolls sideways when it runs out of room.
    /// `@ViewBuilder` lets the caller pass several views (the chips) in braces,
    /// the same way `HStack { ... }` takes its children.
    private func group<Content: View>(_ label: String,
                                      @ViewBuilder _ chips: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { chips() }
            }
        }
    }

    /// One chip: brand-filled when active, the card color when not.
    private func chip(_ text: String, _ active: Bool,
                      _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12.5, weight: active ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .foregroundStyle(active ? Color.white : Theme.ink)
                .background(active ? Theme.brand(accent) : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   app/tasks/[id]/page.tsx (header, Complete, notes, details, checklist, delete)
//
//  Summary: One assignment in full: its class, title and deadline, a big
//           Complete / Mark as open button, the brief, the details, and its
//           checklist. Edit opens the form in a sheet; Delete moves it to
//           Recently Deleted and returns to the list, where Undo is offered.
//           The study timer, day plan, reminder controls, exam prep, grade
//           prompt and linked notes join in later phases.
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
                    if let rule = a.repeatRule {
                        Divider()
                        detailRow("Repeats", "\(rule == .weekly ? "Weekly" : "Monthly")"
                                  + (a.repeatUntil.map { " through \($0)" } ?? ""))
                    }
                    Divider()
                    detailRow("Reminder", reminderSummary(a))
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

    /// What the Reminder row says. The web also names snoozes and lead times;
    /// those arrive with notifications in Phase 7.
    private func reminderSummary(_ a: Assignment) -> String {
        if !a.reminder { return "Off" }
        if a.due == nil { return "On once it has a deadline" }
        return "Nudging until it's done"
    }

    /// Adds the typed step to the checklist and clears the field.
    private func addStep(to id: UUID) {
        store.addSubtask(newStep, to: id)
        newStep = ""
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Components/UndoBar.swift` (new file)

The Undo bar from the web's `StatusChrome.tsx`, with its 8-second timer. The Tasks screen below adds it with `.undoBar()`; Today does the same in Phase 6b.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/UndoBar.swift
//  Phase:   4b (the Tasks screen); Today uses it too from Phase 6b
//  Ports:   components/StatusChrome.tsx (the undo strip) and the
//           UNDO_WINDOW_MS timer in lib/store.tsx
//
//  Summary: The bar that offers to take a delete back, packaged as a view
//           modifier. A screen that can delete things adds `.undoBar()`: the
//           bar sits above the tab bar while there's a delete to undo, and
//           goes away by itself 8 seconds later.
//

import SwiftUI

/// The Undo bar and its 8-second timer. In Phase 3, `.cardStyle()` was a
/// modifier written as a plain function; this one is a `ViewModifier`
/// struct instead, because it needs things a function can't hold: the store
/// from the environment, and a `.task` that lives as long as the screen.
/// `body(content:)` gets the screen it's attached to as `content` and
/// returns that screen with the bar and the timer added.
struct UndoBar: ViewModifier {
    @Environment(Store.self) private var store

    func body(content: Content) -> some View {
        content
            // The bar sits just above the tab bar while there's a delete to undo.
            .safeAreaInset(edge: .bottom) {
                if let undo = store.pendingUndo {
                    bar(undo, store.profile.accent)
                }
            }
            // Make the offer go away 8 seconds after the delete (UNDO_WINDOW_MS).
            // `.task(id:)` runs this async work when the view appears and again
            // whenever `id` changes, and cancels it when the view goes away.
            .task(id: store.pendingUndo?.at) {
                guard let undo = store.pendingUndo else { return }
                // Whatever is left of the 8 seconds (none, if we come back later).
                let left = max(0, 8 - Date.now.timeIntervalSince(undo.at))
                // `Task` here is Swift's own concurrency type, which is exactly why
                // the model can't be called Task. `try?` because sleeping throws
                // when the work is cancelled, and a cancel is not an error here.
                try? await Task.sleep(for: .seconds(left))
                // Cancelled (you left the screen, or a newer delete replaced this
                // one)? Leave the offer alone; the next run of this block decides.
                guard !Task.isCancelled else { return }
                if store.pendingUndo?.at == undo.at { store.dismissUndo() }
            }
    }

    /// The bar itself: what went, Undo, and a close button.
    private func bar(_ undo: PendingUndo, _ accent: Profile.Accent) -> some View {
        HStack(spacing: 12) {
            Text(undo.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer()
            Button("Undo") { store.undoDelete() }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
            Button {
                store.dismissUndo()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.faint)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle()
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

extension View {
    /// Adds the Undo bar to a screen: `SomeScreen().undoBar()`. A one-line
    /// wrapper, so callers don't have to write `.modifier(UndoBar())`.
    func undoBar() -> some View {
        modifier(UndoBar())
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentsView.swift` (new file, replaces the deleted root `AssignmentsView.swift`)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentsView.swift
//  Phase:   4b (the Tasks screen)  [replaces the Phase 2 list at Sources/ClassPing/AssignmentsView.swift]
//  Ports:   app/tasks/page.tsx (the list, Open/Done, groups, rows),
//           components/TaskFilterBar.tsx (`useTaskViewPrefs`, the remembered
//           choices)
//
//  Summary: The Tasks tab. Open or Done work, filtered, grouped by urgency
//           (Overdue, Today, Upcoming, No deadline) and earliest first. The
//           circle completes a task; the rest of the row opens its detail.
//           After a delete, the Undo bar (Components/UndoBar.swift) waits for
//           8 seconds.
//

import SwiftUI

/// The value pushed when a row is tapped. A tiny wrapper instead of a bare
/// UUID, so a later screen that pushes some other UUID can never land on the
/// assignment detail by mistake.
struct AssignmentLink: Hashable {
    let id: UUID
}

struct AssignmentsView: View {
    @Environment(Store.self) private var store

    // MARK: Remembered choices
    // `@AppStorage("key")` is a property saved in UserDefaults, the phone's
    // small key-value store for preferences (the web keeps these in
    // localStorage). It survives relaunches, and the view redraws when it
    // changes. It only holds simple values, so the filters are four of them.
    @AppStorage("tasks.tab") private var tabRaw = "open"
    @AppStorage("tasks.subject") private var subjectRaw = ""        // a class id, or ""
    @AppStorage("tasks.kind") private var kindRaw = ""              // a kind name, or ""
    @AppStorage("tasks.includeArchived") private var includeArchived = true

    /// Whether the filter panel is open. Not remembered, like the web.
    @State private var filtersOpen = false

    var body: some View {
        // Read everything once per redraw. `now` is the moment of this redraw;
        // the groups refresh whenever the screen does (Phase 6 adds a ticking clock).
        let now = Date.now
        let accent = store.profile.accent
        let prefs = currentPrefs
        let all = store.liveAssignments

        // Filter, split into open and done, then pick the tab's half.
        // `filterTasks` asks the store whether each class is archived.
        let visible = filterTasks(all, prefs.filters, isArchived: { id in
            store.course(id)?.archived ?? false
        })
        let list = visible.filter { $0.done == (prefs.tab == .done) }
        let groups = groupTasks(list, now)
        // "3 of 12": the 12 is every task in this tab before filtering.
        let total = all.filter { $0.done == (prefs.tab == .done) }.count
        // Only classes that have work get a filter chip.
        let filterable = store.courses.filter { course in
            course.deletedAt == nil && all.contains(where: { $0.courseID == course.id })
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                // Never hide a failed save (kept from Phase 1).
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                }

                // Open / Done. The binding reads the saved tab and writes it back.
                Picker("Show", selection: tabBinding) {
                    Text("Open").tag(TaskTab.open)
                    Text("Done").tag(TaskTab.done)
                }
                .pickerStyle(.segmented)

                TaskFilterBar(filters: filtersBinding, open: $filtersOpen,
                              courses: filterable, showing: list.count, total: total,
                              accent: accent)

                // Nothing to show: say why, in the web app's words.
                if list.isEmpty {
                    Text(emptyMessage(prefs))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }

                // One heading per non-empty group, then its rows.
                ForEach(groups) { group in
                    header(group.id, group.label, group.tasks.count, accent)
                    ForEach(group.tasks) { assignment in
                        row(assignment, now)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.canvas)
        // Where a tapped row goes. The detail looks the assignment up by id, so
        // it always shows the latest version, even right after an edit.
        .navigationDestination(for: AssignmentLink.self) { link in
            AssignmentDetailView(assignmentID: link.id)
        }
        // The Undo bar, shared with Today: see Components/UndoBar.swift.
        .undoBar()
    }

    // MARK: - Preferences as bindings

    /// The four saved values, cleaned up by the ported `normalizeViewPrefs`.
    private var currentPrefs: TaskViewPrefs {
        normalizeViewPrefs(tab: tabRaw, subject: subjectRaw, kind: kindRaw,
                           includeArchived: includeArchived)
    }

    /// A hand-made binding: `get` reads the saved tab, `set` saves a new one.
    /// `Binding(get:set:)` is how you give a Picker a two-way connection to a
    /// value that is really stored in some other shape (here, text).
    private var tabBinding: Binding<TaskTab> {
        Binding(get: { currentPrefs.tab },
                set: { tabRaw = $0.rawValue })
    }

    /// The same idea for the filters: the bar sees one TaskFilters value, and
    /// each change is split back into the three saved values.
    private var filtersBinding: Binding<TaskFilters> {
        Binding(get: { currentPrefs.filters },
                set: { f in
                    subjectRaw = f.subject?.uuidString ?? ""
                    kindRaw = f.kind ?? ""
                    includeArchived = f.includeArchived
                })
    }

    // MARK: - Pieces

    /// The empty-list message, word for word from the web page.
    private func emptyMessage(_ prefs: TaskViewPrefs) -> String {
        if prefs.filters.activeCount > 0 { return "Nothing matches these filters." }
        return prefs.tab == .open ? "🎉 All caught up, no open assignments." : "Nothing completed yet."
    }

    /// A group heading: "OVERDUE 2". Overdue in the danger ink, Today in the
    /// deep brand color, the rest faint, as on the web.
    private func header(_ bucket: DueBucket, _ label: String, _ count: Int,
                        _ accent: Profile.Accent) -> some View {
        let color: Color = switch bucket {
        case .overdue: Theme.dangerInk
        case .today:   Theme.brandDeep(accent)
        default:       Theme.faint
        }
        return HStack(spacing: 6) {
            Text(label.uppercased())
                .tracking(1.4)
                .foregroundStyle(color)
            Text("\(count)")
                .foregroundStyle(Theme.faint)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    /// One task. `TaskRow` in app/tasks/page.tsx. The circle is its own button
    /// (complete / reopen); the rest of the card is a NavigationLink to the
    /// detail. On the web the row unfolds in place first; on a phone the
    /// detail screen does that job.
    private func row(_ a: Assignment, _ now: Date) -> some View {
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, now)

        return HStack(alignment: .top, spacing: 12) {
            // The completion circle: filled green with a tick when done.
            Button {
                store.toggleAssignment(a.id)
            } label: {
                ZStack {
                    Circle()
                        .fill(a.done ? Theme.good : Color.clear)
                    Circle()
                        .strokeBorder(a.done ? Color.clear : Theme.lineStrong, lineWidth: 2)
                    if a.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(a.done ? "Mark as open" : "Complete")

            // Everything else opens the detail.
            NavigationLink(value: AssignmentLink(id: a.id)) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Title, with an Exam or Quiz badge on open work.
                        HStack(spacing: 6) {
                            if !a.done { badge(a.kind) }
                            Text(a.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(a.done ? Theme.muted : Theme.ink)
                                .strikethrough(a.done)
                                .multilineTextAlignment(.leading)
                        }
                        // The class dot and name, plus 📝 when it has notes.
                        HStack(spacing: 6) {
                            Circle()
                                .fill(a.done ? Theme.hint : course.map { Theme.subject($0.color) } ?? Theme.lineStrong)
                                .frame(width: 8, height: 8)
                            Text(course?.name ?? "Inbox")
                                .font(.system(size: 13))
                                .foregroundStyle(a.done ? Theme.hint : Theme.muted)
                                .strikethrough(a.done)
                                .lineLimit(1)
                            if !(a.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("· 📝").font(.system(size: 13)).foregroundStyle(Theme.hint)
                            }
                        }
                    }
                    Spacer(minLength: 4)
                    // The deadline pill, only on open work. Red when urgent.
                    if !a.done {
                        Text(due.text)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(due.urgent ? Theme.dangerInk : Theme.muted)
                            .background(due.urgent ? Theme.dangerSoft : Theme.surface2, in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.hint)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .cardStyle()
        .opacity(a.done ? 0.7 : 1)
    }

    /// The small kind chip. Only exams and quizzes wear one; assignments are
    /// the unmarked default. `typeBadge` in app/tasks/page.tsx.
    @ViewBuilder
    private func badge(_ kind: Assignment.Kind) -> some View {
        if kind == .exam || kind == .quiz {
            Text(kind.label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(kind == .exam ? Theme.warnInk : Theme.infoInk)
                .background(kind == .exam ? Theme.warnSoft : Theme.infoSoft, in: Capsule())
        }
    }
}
```

## 5. Run it

```bash
xtool dev build
xtool dev
git add . && git commit -m "Phase 4b: Tasks screen, filters, detail, undo"
```

On the phone:
1. **Tasks**: headings with counts. The sample's Midterm 2 wears an **EXAM** badge; "Email advisor..." sits under **No deadline**.
2. Tap a circle: the row goes to **Done**. Switch to **Done** and tap it again to reopen it.
3. **Filters → OChem**: only that class's work, with "1 of N" beside the chip. Quit and reopen the app: still filtered. **Clear** resets.
4. Tap a row: the detail. Add two checklist steps, tick one; the count reads 1/2.
5. **Edit**: change the title and tap Save. The detail shows the new title at once.
6. **Delete**: back on the list with "*title* deleted · Undo". Tap **Undo** and it's back. Delete again and wait 8 seconds: the bar goes away by itself.

## 6. Done when

- [ ] `xtool dev build` has no warnings, and the old root `AssignmentsView.swift` is gone.
- [ ] Groups appear in the order Overdue, Today, Upcoming, No deadline, and only when they have work.
- [ ] Completing and reopening work from the circle and from the detail.
- [ ] Filters and the Open/Done choice survive a relaunch.
- [ ] Edit saves; Delete + Undo brings the task back; the bar clears itself after 8 seconds.

## 7. If it breaks

- **`invalid redeclaration of 'AssignmentsView'`**: the old `Sources/ClassPing/AssignmentsView.swift` is still there. Delete it (see section 4).
- **`type 'Assignment' does not conform to protocol 'TaskListable'`**: `Assignment+TaskView.swift` is missing or has a typo in `kindName`.
- **`type 'Assignment.Kind' has no member 'allCases'`**: the `CaseIterable` from 4a's Step 0 is missing.
- **The filters forget themselves after a relaunch:** an `@AppStorage` key is spelled differently in two places, or one of the `set:` lines in `filtersBinding` is missing.
- **`value of type '...' has no member 'undoBar'`** or **`cannot find 'UndoBar' in scope`**: `Components/UndoBar.swift` is missing, or the `extension View` at its bottom is.
- **Tapping the circle opens the detail instead of completing:** the circle `Button` ended up inside the `NavigationLink`. It must be a sibling, before it in the `HStack`.

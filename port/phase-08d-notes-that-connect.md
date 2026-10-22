---
title: "Phase 8d: Notes that connect"
date: 2026-10-19
generated_by: skills-for-architects
---

# Phase 8d: Notes that connect

*Last of four parts of Phase 8 (D-36, split by D-40). Checked on 2026-10-19 over your tree as it stood that morning (8c committed as `c0a67a5`, with your own hardening, D-44, and D-43 typed but not committed): `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 293/293 (8 new, in `QuickTaskTests`), and `persistence-test.sh` 44/44 (8 new, at the end of `NoteStoreTests`). Nothing here has been on a phone yet.*

**Before you start:** commit D-43 (`RootView.swift`, the bar stepping aside for the keyboard) on its own, so this phase's changes to that file stay separate. And if, in 8c, a selected word *didn't* stay selected after you tapped **B**, put in the one-line fix from 8c's section 7 first, since 4.4 below replaces `NoteView.swift` and is built on the version without it.

## 1. Goal

Notes stop being an island. While you read or type a note, the bell and the plus file a reminder or an assignment for that note's class in a few taps. A task shows the notes that go with it, opens them, links one more or starts a new one. And **Add → Note** finally does something.

**On your phone:** open a Biology note and tap the **bell**: a small sheet, "Quick reminder", for Biology. Type `Bring goggles`, tap **Add**, and it's on the Tasks tab, due tomorrow, with its daily reminder on. Tap the **plus**, pick **Quiz**, type nothing, **Add**: "Biology quiz", due in three days. Then open a Biology task: under its checklist, **Linked notes**. **Link an existing note** lists Biology's notes; pick one and it joins the list, tap it and the note opens on top of the task, **Unlink** takes the link away (not the note). **New note** starts one already linked. **Open Biology** shows the class's notes. And **+ → Note** takes you to the Notes tab.

## 2. New Swift concepts

**An enum as a sheet's item.** `.sheet(item:)` (4b) shows a sheet while its binding holds a value, and that value has to be `Identifiable`. A struct gets an `id` field; an enum with no values attached is already `Hashable`, so it can simply be its own id. The bell and the plus share one sheet this way, and the sheet knows which one opened it:

```swift
enum QuickTaskMode: Identifiable {
    case reminder, assignment
    var id: Self { self }      // `Self` is the type itself, QuickTaskMode
}

@State private var quick: QuickTaskMode? = nil

Button { quick = .reminder } label: { Image(systemName: "bell") }
    .sheet(item: $quick) { mode in
        QuickTaskSheet(mode: mode, courseID: note.courseID)
    }
```

**Destinations where the links are.** Since 4b a `NavigationLink(value:)` pushes whatever the stack's `.navigationDestination(for:)` says that type opens. Until now each type was registered at the bottom of its tab (`NoteLink` on the Notes tab). A task's detail is pushed on the Tasks tab and on Today, and neither knows about notes, so the detail registers the note screens itself. A destination counts for the whole stack while the screen that registered it is in the stack, so a class's notes opened from the task can open their own notes too:

```swift
// In AssignmentDetailView, on the screen's ScrollView.
.navigationDestination(for: NoteLink.self) { link in
    NoteView(noteID: link.id)
}
```

Register them on the screen itself, not inside a `List` or `LazyVStack`: SwiftUI ignores destinations inside lazy containers. If two screens in one stack register the same type, the one nearest the bottom of the stack wins.

**A `Menu` built from data.** 8c's **Aa** menu had four fixed buttons. A `ForEach` inside a `Menu` makes one button per item, the phone's version of the web's `<select>`. `.disabled` greys it out when there's nothing to pick:

```swift
Menu {
    ForEach(linkable) { note in
        Button(noteTitle(title: note.title, body: note.body)) {
            store.linkNote(note.id, to: task.id)
        }
    }
} label: {
    Text("Link an existing note")
}
.disabled(linkable.isEmpty)
```

You'll also meet: **`ToolbarItemGroup`**, several buttons in one toolbar spot, in the order you write them (the bell and the plus). **`String.capitalized`**, `"quiz"` to `"Quiz"`. **`Calendar.date(bySettingHour:minute:second:of:)`**, today at 5:00 PM, for the time picker's start. And a `@Binding` handed to a sheet (6b gave Today one the same way): the Add menu borrows RootView's tab so Note can switch it.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `QuickTaskCard` in `app/classes/page.tsx` | `Logic/QuickTask.swift`, `addQuickTask` in `Store+Notes.swift`, `Screens/Notes/QuickTaskSheet.swift` | A sheet instead of a card hanging under the header (D-45). Same fields and rules: the title, Assignment / Quiz / Exam for the plus, the day (tomorrow for a reminder, three days out for an assignment), a time only if you set one, the daily reminder on; a reminder needs its own words, a blank assignment is named after its class ("Biology quiz"). The time is a switch and a picker, as in the task form, since iOS has no empty time picker. Cancel and dragging down replace the web's click-away and Escape |
| `NotePane`'s bell and plus | the toolbar in `NoteView.swift` | Reading or typing. The web's phone shows them over its reader; the phone's editor is phone-only (D-37), and a lecture is where "quiz on Friday" gets said |
| The Linked notes section of `app/tasks/[id]/page.tsx` | `linkedNotesCard` in `AssignmentDetailView.swift`; `linkedNotes`, `linkableNotes`, `linkNote` in `Store+Notes.swift` | Same list, Unlink, "Link an existing note" (a `Menu` for the `<select>`) and New note, with the same rules: only notes with no link, from the task's class (any class for an Inbox task). A note opens on top of the task, so Back returns to it, instead of jumping to the Notes tab as the web's link does (D-46) |
| `updateNote(id, { taskId })` | `linkNote` | Same: a link moves the note's `updatedAt`, the same link again writes nothing |
| "Open {class}" | the row under Linked notes | The class's notes, on top of the task |
| `deleteTask` (keeps `note.taskId`) | `deleteAssignment`, unchanged | Same: a deleted task keeps its notes' links, so Undo brings them back. The web only clears them when the task is gone for good (Recently Deleted, Phase 12) |
| Note in `components/AddMenu.tsx` | the Note row in `Components/AddMenu.swift` | Opens the Notes tab as you left it (D-46). The web's goes to `/classes`, which, while a class is on, opens on that class; the phone's Notes tab doesn't (8a), so neither does Note. Open question 19 |

## 4. Files, in the order to type them

4.1 builds on its own; 4.2 needs 4.1; 4.3 needs 4.2; 4.4 needs 4.3; 4.5 needs 4.2; 4.6 and 4.7 go together (the build breaks between them). Two new files, five replaced.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/QuickTask.swift` (new file)

Pure logic: the quick card's rules, in `Logic/` so the Linux tests can check them.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/QuickTask.swift
//  Phase:   8d (notes that connect)
//  Ports:   QuickTaskCard in app/classes/page.tsx (the small card a note's
//           bell and plus open: which kinds it offers, the day it starts on,
//           when Add is allowed, and the title it files)
//
//  Summary: The rules behind filing a reminder or an assignment from a note
//           without leaving it. The class is already known (it's the note's),
//           so only the words, the day, a time if it matters and, for an
//           assignment, assignment, quiz or exam are left to choose.
//           Foundation only, so the Linux tests can run it.
//

import Foundation

/// Which card is open: the bell's (a reminder) or the plus's (an assignment).
/// The web's `mode`. `Identifiable` so a sheet can be opened with one:
/// `.sheet(item: $quick)` shows the sheet while `quick` holds a mode. An
/// enum with no values attached is already `Hashable`, so it can be its own
/// id: `var id: Self { self }`.
enum QuickTaskMode: Identifiable {
    case reminder, assignment

    var id: Self { self }
}

/// The three kinds the assignment card offers, in the web's order.
/// `ASSIGNMENT_TYPES`. The raw values are `Assignment.Kind`'s, and the web's
/// ids, which the fallback title uses as they are ("Chemistry quiz").
enum QuickTaskType: String, CaseIterable {
    case assignment, quiz, exam

    /// The segment's label: "Assignment", "Quiz", "Exam".
    var label: String { rawValue.capitalized }
}

/// How many days from today the card's date starts on. Reminders skew soon
/// (tomorrow), assignments a few days out. `dateInputValue(isReminder ? 1 : 3)`.
func quickTaskDaysAhead(_ mode: QuickTaskMode) -> Int {
    mode == .reminder ? 1 : 3
}

/// Whether Add can be tapped. A reminder needs its own words ("Bring
/// goggles"); an assignment can go without and take a made-up title. The
/// web's `canSave` also needs a date, which the phone's date picker can't
/// leave empty, so that half always holds here.
func quickTaskCanSave(_ mode: QuickTaskMode, title: String) -> Bool {
    mode == .assignment || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// The title that gets filed: what was typed, trimmed, or for a blank
/// assignment the class and the kind, "Chemistry quiz". `finalTitle` in
/// QuickTaskCard. A note with no class passes "Quick note", the name the
/// note's header shows, so a blank one is "Quick note assignment", as on the
/// web. ("Reminder" is the web's fallback for a reminder, which `canSave`
/// never lets through blank; kept so the two read alike.)
func quickTaskTitle(_ mode: QuickTaskMode, title: String, className: String,
                    type: QuickTaskType) -> String {
    let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    // Typed words always win.
    if !typed.isEmpty { return typed }
    return mode == .reminder ? "Reminder" : "\(className) \(type.rawValue)"
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Store+Notes.swift` (replaces the file)

Built on your 8c version (with your `saveNoteBody`, D-44). Two touched spots: the header, and a new `// MARK: - Notes and tasks (NEW in Phase 8d)` section at the end with four functions: `linkedNotes`, `linkableNotes`, `linkNote` and `addQuickTask`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Notes.swift
//  Phase:   8a (notes you can write and find), changed in 8c (tidy saves)
//           and 8d (notes linked to a task, a task from a note)
//  Ports:   lib/store.tsx (liveNotes, notesForClass, addNote, updateNote,
//           deleteNote, noteById) and, from app/classes/page.tsx, the note
//           counts, the search and today's note for a class that's on.
//           Since 8d, from app/tasks/[id]/page.tsx, `linkedNotes`,
//           `linkableNotes` and `updateNote(id, { taskId })`, and from
//           app/classes/page.tsx, what QuickTaskCard's `save` files
//
//  Summary: Everything that reads or changes a note. A note belongs to a
//           class, or to none (a quick note), and to the day it was taken.
//           Each change saves to the phone straight away, and a delete can
//           be undone, like an assignment's. Since 8d a note can also be
//           linked to one task, and a task can be filed from a note.
//

import Foundation

/// Newest day first; on the same day, the latest edit first. "yyyy-MM-dd"
/// text sorts like the dates it names. The sort in `notesForClass`.
private func newestFirst(_ a: Note, _ b: Note) -> Bool {
    a.date != b.date ? a.date > b.date : a.updatedAt > b.updatedAt
}

extension Store {
    // MARK: - Reading

    /// Every note that hasn't been deleted. `liveNotes` in lib/store.tsx.
    var liveNotes: [Note] {
        notes.filter { $0.deletedAt == nil }
    }

    /// One live note by id, or nil. `noteById`.
    func note(_ id: UUID) -> Note? {
        liveNotes.first { $0.id == id }
    }

    /// A class's notes, newest first. Nil asks for the quick notes, the ones
    /// with no class. `notesForClass`.
    func notes(for courseID: UUID?) -> [Note] {
        liveNotes.filter { $0.courseID == courseID }.sorted(by: newestFirst)
    }

    /// How many notes a class holds, for its row on the Notes tab.
    func noteCount(for courseID: UUID) -> Int {
        liveNotes.filter { $0.courseID == courseID }.count
    }

    /// Today's note for a class, if one was started: what "Take notes, this
    /// class is on now" reopens, so a second visit mid-lecture keeps typing
    /// instead of filing a blank twin. `startTodaysNote` in app/classes.
    func todaysNote(for courseID: UUID, now: Date = .now) -> Note? {
        notes(for: courseID).first { $0.date == dayOf(now) }
    }

    /// The notes a search finds, newest first. A note with no class is
    /// searched as "Quick note". The search in app/classes/page.tsx.
    func searchNotes(_ query: String) -> [Note] {
        liveNotes
            .filter { n in
                noteMatches(query, title: n.title, body: n.body,
                            subject: course(n.courseID)?.name ?? "Quick note")
            }
            .sorted(by: newestFirst)
    }

    // MARK: - Writing

    /// Starts an empty note and hands back its id, so the screen can open it
    /// at once. `addNote(classId, date, taskId)`. `@discardableResult` lets a
    /// caller ignore the id without a warning.
    @discardableResult
    func addNote(courseID: UUID?, date: String, assignmentID: UUID? = nil) -> UUID {
        let note = Note(courseID: courseID, date: date, assignmentID: assignmentID)
        notes.append(note)
        save()
        return note.id
    }

    /// Saves an edit to a note's title, body, or both (nil leaves one as it
    /// is). False, with nothing saved, when the body would pass the 20,000
    /// character limit, so the screen can say so instead of losing words
    /// quietly. `updateNote` in lib/store.tsx.
    @discardableResult
    func updateNote(_ id: UUID, title: String? = nil, body: String? = nil) -> Bool {
        guard let i = notes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return false }
        if let body, !fitsBudget(noteLength(body)) { return false }

        // A save that changes nothing writes nothing, unless the last write
        // failed and the same draft is now being retried. The screen saves
        // on a timer, when you leave it and when the app goes away, so the
        // same text often arrives more than once.
        let newTitle = title ?? notes[i].title
        let newBody = body ?? notes[i].body
        guard newTitle != notes[i].title || newBody != notes[i].body else {
            if lastSaveFailed { save() }
            return true
        }

        notes[i].title = newTitle
        notes[i].body = newBody
        notes[i].updatedAt = .now
        save()
        return true
    }

    /// Applies a previewed body change only if it reaches the planner file.
    /// Tidy's preview and Undo retain the proposed text for retry; on failure,
    /// restore the original in-memory note so Discard really changes nothing.
    /// Ordinary editor drafts keep using updateNote and its save feedback.
    func saveNoteBody(_ id: UUID, body: String) -> Bool {
        guard let original = note(id), updateNote(id, body: body) else { return false }
        guard lastSaveFailed else { return true }
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index] = original
        }
        return false
    }

    /// Moves a note to Recently Deleted and offers Undo, "Week 3 deleted"
    /// (or "Note deleted" when it has no title). `deleteNote`.
    func deleteNote(_ id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = Date.now
        notes[i].deletedAt = now
        let title = notes[i].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(item: .note(id),
                                  label: "\(title.isEmpty ? "Note" : title) deleted",
                                  at: now)
        save()
    }

    // MARK: - Notes and tasks (NEW in Phase 8d)

    /// The notes linked to a task, in the order they were made (the order
    /// the store keeps them in, as on the web). `linkedNotes` in
    /// app/tasks/[id]/page.tsx.
    func linkedNotes(for assignmentID: UUID) -> [Note] {
        liveNotes.filter { $0.assignmentID == assignmentID }
    }

    /// The notes "Link an existing note" offers for a task: those not linked
    /// to any task yet, from the task's class. An Inbox task has no class, so
    /// any unlinked note will do. `linkableNotes`.
    func linkableNotes(for assignment: Assignment) -> [Note] {
        liveNotes.filter { n in
            n.assignmentID == nil
                && (assignment.courseID == nil || n.courseID == assignment.courseID)
        }
    }

    /// Links a note to a task, or unlinks it when `assignmentID` is nil.
    /// `updateNote(id, { taskId })` on the web: like any edit it moves the
    /// note's `updatedAt`, and a link that's already there writes nothing.
    func linkNote(_ id: UUID, to assignmentID: UUID?) {
        guard let i = notes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }),
              notes[i].assignmentID != assignmentID else { return }
        notes[i].assignmentID = assignmentID
        notes[i].updatedAt = .now
        save()
    }

    /// Files a reminder or an assignment from a note's quick card, for the
    /// note's class (nil for a quick note, so it lands in the Inbox).
    /// QuickTaskCard's `save`: the day the card shows, a time only when one
    /// was set, the daily reminder on, and a title even when none was typed
    /// ("Chemistry quiz", Logic/QuickTask.swift). Nil, with nothing filed,
    /// when the card couldn't be saved (a reminder with no words); otherwise
    /// the new task's id.
    @discardableResult
    func addQuickTask(_ mode: QuickTaskMode, title: String, type: QuickTaskType,
                      courseID: UUID?, due: String, dueTime: String?) -> UUID? {
        guard quickTaskCanSave(mode, title: title) else { return nil }

        // The class's name for a blank title; the note's header says "Quick
        // note" for a note with no class, and so does the made-up title.
        let className = course(courseID)?.name ?? "Quick note"

        // The three types are three of Assignment's kinds. A `switch` as a
        // value (8c): one kind per case, and Swift checks none is missing.
        let kind: Assignment.Kind = switch type {
        case .assignment: .assignment
        case .quiz: .quiz
        case .exam: .exam
        }

        let task = Assignment(courseID: courseID,
                              title: quickTaskTitle(mode, title: title, className: className, type: type),
                              due: due,
                              dueTime: dueTime,
                              kind: mode == .reminder ? .reminder : kind,
                              reminder: true)
        addAssignment(task)
        return task.id
    }
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Notes/QuickTaskSheet.swift` (new file)

The sheet the bell and the plus open. Its fields are its own `@State` until **Add**, like the task form (4a), and it hands them to `addQuickTask`, which decides whether they can be filed.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/QuickTaskSheet.swift
//  Phase:   8d (notes that connect)
//  Ports:   QuickTaskCard in app/classes/page.tsx
//
//  Summary: The small form a note's bell and plus open. It files a reminder
//           (the bell) or an assignment, quiz or exam (the plus) for the
//           note's class without leaving the note: only the words, the day
//           and a time if it matters are left to fill in. A reminder needs
//           its words; a blank assignment is named after its class.
//

import SwiftUI

struct QuickTaskSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Which card this is: the bell's or the plus's.
    let mode: QuickTaskMode

    /// The note's class, which the new task takes. Nil for a quick note,
    /// so the task goes to the Inbox.
    let courseID: UUID?

    // MARK: Form state
    // The sheet's own scratch copy of each field, as in the task form (4a):
    // nothing reaches the store until Add.
    @State private var title = ""
    @State private var type = QuickTaskType.assignment
    @State private var day: Date
    @State private var hasTime = false      // off = all-day, the web's empty time
    @State private var clock: Date

    /// Whether the title field has the keyboard. The web's `autoFocus`.
    @FocusState private var titleFocused: Bool

    /// Starts the date where the web card does: tomorrow for a reminder,
    /// three days out for an assignment. The time, once switched on, starts
    /// at 5:00 PM, as in the task form.
    init(mode: QuickTaskMode, courseID: UUID?) {
        self.mode = mode
        self.courseID = courseID
        let ahead = Calendar.current.date(byAdding: .day, value: quickTaskDaysAhead(mode), to: .now)
        _day = State(initialValue: ahead ?? .now)
        let five = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now)
        _clock = State(initialValue: five ?? .now)
    }

    var body: some View {
        let isReminder = mode == .reminder

        NavigationStack {
            Form {
                // MARK: What it is
                // The header names the class, the web card's pill.
                Section {
                    TextField(isReminder ? "Reminder, e.g. Bring goggles" : "Title (optional)",
                              text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Title")
                        // Return adds it, when it can be added.
                        .submitLabel(.done)
                        .onSubmit { add() }
                    // Assignment, quiz or exam. Not for a reminder.
                    if !isReminder {
                        Picker("Type", selection: $type) {
                            ForEach(QuickTaskType.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text(store.course(courseID)?.name ?? "Quick note")
                }

                // MARK: When
                // A day always; a time only when it matters (the web's time
                // field starts empty, and empty means all-day).
                Section {
                    DatePicker("Due date", selection: $day, displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $clock, displayedComponents: .hourAndMinute)
                    }
                }
            }
            // The warm canvas instead of the system grey, as in the task form.
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle(isReminder ? "Quick reminder" : "Quick assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(!quickTaskCanSave(mode, title: title))
                }
            }
            // Straight into the title, like the web card.
            .onAppear { titleFocused = true }
        }
        // About half the screen, room enough for the keyboard; drag for more.
        .presentationDetents([.medium, .large])
    }

    /// Files the task and closes. Nothing happens while it can't be saved
    /// (a reminder with no words), which also covers Return in the title.
    private func add() {
        let filed = store.addQuickTask(mode, title: title, type: type, courseID: courseID,
                                       due: dayOf(day), dueTime: hasTime ? timeOf(clock) : nil)
        if filed != nil { dismiss() }
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift` (replaces the file)

Your 8c version (with `saveNoteBody`, D-44) plus three touched spots, all in `NoteView`, each marked `NEW in Phase 8d`: the header, a `quick` `@State`, and on the outer `Group` a `ToolbarItemGroup` with the bell and the plus, then the `.sheet(item: $quick)`. `NoteEditorView` is unchanged.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift
//  Phase:   8a (notes you can write and find), changed in 8b (read first),
//           8c (the formatting bar and tidy) and 8d (a task from a note)
//  Ports:   NotePane in app/classes/page.tsx (the title, "class · day", the
//           bin), the saving half of components/NoteEditor.tsx (save half
//           a second after you stop typing, "Saving…" / "Saved", the 20,000
//           character limit and New page), since 8b the phone's view of a
//           note, components/NoteReader.tsx, since 8c the Tidy note
//           button and its Undo (components/NoteTidyButton.tsx), and since
//           8d NotePane's bell and plus, which open its QuickTaskCard
//
//  Summary: One note. A note with words in it opens to read, drawn by
//           NoteReaderView, with Tidy note above it; Edit switches to typing
//           it as plain markdown, with the formatting bar over the keyboard,
//           and Done goes back to reading (D-37). An empty note opens
//           straight for typing. Typing saves by itself a moment after you
//           stop, when you leave, and when the app goes to the background.
//           Reading or typing, the bell and plus file a reminder or an
//           assignment for the note's class without leaving it.
//

import SwiftUI

struct NoteView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss   // NEW in Phase 8b

    /// Which note to show. The note itself is looked up in the store.
    let noteID: UUID

    /// NEW in Phase 8b: true while typing, false while reading. Nil until the
    /// screen first appears, then settled once: an empty note opens for
    /// typing, one with words opens to read. Settled once, so typing a note's
    /// first words doesn't flip the screen over to reading.
    @State private var editing: Bool? = nil

    /// NEW in Phase 8c: a tidy waiting in its sheet for Apply or Discard.
    @State private var tidyPreview: TidyPreview? = nil

    /// NEW in Phase 8c: what Undo tidy puts back, and what Apply wrote. Undo
    /// shows while the note still holds exactly what Apply wrote; any edit
    /// after that and it's gone, as on the web.
    @State private var undoTidy: (original: String, applied: String)? = nil

    /// NEW in Phase 8d: the quick card that's open, the bell's or the plus's,
    /// or nil for none. `.sheet(item:)` below shows it while this is set.
    @State private var quick: QuickTaskMode? = nil

    var body: some View {
        if let note = store.note(noteID) {
            // CHANGED in Phase 8b: reading or typing.
            let typing = editing ?? (note.title.isEmpty && note.body.isEmpty)
            Group {
                if typing {
                    NoteEditorView(note: note, onDone: { editing = false })
                } else {
                    reader(note)
                }
            }
            .toolbar {
                // NEW in Phase 8d: file work for this note's class without
                // leaving it, a reminder (the bell) or an assignment (the
                // plus), the web's two header buttons. On this outer Group,
                // so they're there whether you're reading or typing.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        quick = .reminder
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Add reminder")
                    Button {
                        quick = .assignment
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add assignment")
                }
                // The editor owns Done so it can flush its draft before the
                // reader appears, and retain the draft if saving fails.
                if !typing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { editing = true }
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            // NEW in Phase 8d: the quick card, for the note's class. It
            // slides up over the note, and the editor stays underneath,
            // still saving what you typed.
            .sheet(item: $quick) { mode in
                QuickTaskSheet(mode: mode, courseID: note.courseID)
            }
            .onAppear {
                if editing == nil { editing = typing }
            }
        } else {
            // Just deleted (the screen is on its way back), or never existed.
            ContentUnavailableView("Note not found.", systemImage: "note.text")
        }
    }

    /// NEW in Phase 8b: the note to read. Its title and where it lives, then
    /// the note drawn. Nothing here takes the keyboard, the web phone's point:
    /// a thumb brushing the page can't change a word.
    private func reader(_ note: Note) -> some View {
        let course = store.course(note.courseID)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                        .padding(.bottom, 12)
                }
                Text(noteTitle(title: note.title, body: note.body))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
                tidyRow(note)   // NEW in Phase 8c
                    .padding(.top, 12)
                Divider()
                    .padding(.vertical, 14)
                if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // The web's empty-note line, as in the editor.
                    Text("Start typing: # for a heading, - for a bullet, - [ ] for a checkbox")
                        .font(.system(size: 15.5))
                        .foregroundStyle(Theme.hint)
                } else {
                    NoteReaderView(markdown: note.body)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        // NEW in Phase 8c: the preview, until Apply or Discard. The note can't
        // change under it while it's up (nothing syncs yet, Phase 14), so
        // the web's "this note changed" check isn't needed.
        .sheet(item: $tidyPreview) { preview in
            NoteTidySheet(preview: preview) { tidied in
                guard store.saveNoteBody(note.id, body: tidied) else { return false }
                undoTidy = (original: preview.source, applied: tidied)
                return true
            }
        }
        .toolbar {
            // The bin, as in the editor: delete, and back to the list's Undo.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
        }
    }

    /// NEW in Phase 8c: Tidy note, and Undo tidy while it lasts. Tidy is off
    /// for a note with nothing in it.
    private func tidyRow(_ note: Note) -> some View {
        let accent = store.profile.accent
        let empty = note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 6) {
            Button {
                tidyPreview = TidyPreview(source: note.body)
            } label: {
                Label("Tidy note", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Theme.brandSoft(accent), in: Capsule())
            }
            .disabled(empty)
            .opacity(empty ? 0.5 : 1)

            if let undo = undoTidy, note.body == undo.applied {
                Button("Undo tidy") {
                    if store.saveNoteBody(note.id, body: undo.original) { undoTidy = nil }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
            }
        }
    }
}

/// The writing surface. A separate view so its scratch copy of the text can
/// start from the note once, in `init` (4a's `_title = State(...)`), and then
/// belong to the typing rather than to the store.
private struct NoteEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// The note as it was when the screen opened: its id, class and day.
    let note: Note

    /// Return to the reader after the whole draft has been saved.
    let onDone: () -> Void

    /// What's typed, which can run ahead of what's saved by half a second.
    @State private var title: String
    @State private var text: String

    /// NEW in Phase 8c: what's selected in the note, or where the caret is.
    /// Nil until the editor first reports one. The formatting bar reads it
    /// to know which words to change, and sets it to select what changed.
    @State private var selection: TextSelection? = nil

    /// The note started by New page, while it's open.
    @State private var nextPage: UUID?

    /// Which field has the keyboard, or nil for none. `@FocusState` is
    /// `@State` for the keyboard: set it to move the caret, set it to nil to
    /// put the keyboard away.
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    init(note: Note, onDone: @escaping () -> Void) {
        self.note = note
        self.onDone = onDone
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.body)
    }

    var body: some View {
        let course = store.course(note.courseID)
        let length = noteLength(text)
        let full = !fitsBudget(length)
        // Saved only when the draft matches and the file write succeeded.
        let saved = !store.lastSaveFailed
            && (store.note(note.id).map { $0.title == title && $0.body == text } ?? false)

        VStack(spacing: 0) {
            // MARK: Title, and where the note lives
            VStack(alignment: .leading, spacing: 2) {
                // The grey text is what the list would call it untitled.
                TextField(noteTitle(title: "", body: text), text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .title)
                    .accessibilityLabel("Note title")
                    // Return in the title moves down into the note.
                    .submitLabel(.next)
                    .onSubmit { focus = .body }
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // MARK: The note
            // `TextEditor` is a multi-line text field that scrolls by itself.
            // It has no placeholder, so one sits behind it while it's empty.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Start typing: # for a heading, - for a bullet, - [ ] for a checkbox")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.hint)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                // CHANGED in Phase 8c: `selection:` keeps `selection` up to date
                // as you move the caret, and moves it when `selection` is set.
                TextEditor(text: $text, selection: $selection)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .body)
                    .accessibilityLabel("Note body")
                    // Let the canvas show through instead of a white box.
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
            }

            // MARK: Saving
            // "Saving…" until the store has it, then "Saved". Near the limit,
            // the count and New page, so a long lecture goes on in a new note
            // instead of stopping at the ceiling.
            VStack(alignment: .leading, spacing: 6) {
                if store.lastSaveFailed {
                    HStack(spacing: 10) {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                        Button("Retry") { save() }
                            .font(.footnote.weight(.semibold))
                    }
                }
                Text(full ? "This note is full, start a new page to keep writing"
                          : (saved ? "Saved" : "Saving…"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
                if length > maxNoteChars * 9 / 10 {
                    HStack(spacing: 10) {
                        Text("\(length.formatted()) / \(maxNoteChars.formatted())")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(full ? Theme.dangerInk : Theme.warnInk)
                        Spacer(minLength: 0)
                        Button("New page") {
                            save()
                            nextPage = store.addNote(courseID: note.courseID, date: note.date,
                                                     assignmentID: note.assignmentID)
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }

            // MARK: The formatting bar
            // NEW in Phase 8c: last in the column, so with the keyboard up it
            // sits right on top of it. Hidden while you type the title,
            // since every button changes the note's words.
            if focus != .title {
                NoteFormatBar(apply: apply)
            }
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete goes straight back, where the Undo bar is waiting.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Flush the debounce first, so Undo restores the latest typing.
                    save()
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
            // Flush before replacing the editor. A refused body or failed
            // file write must leave the draft available to fix or retry.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    save()
                    guard fitsBudget(noteLength(text)), !store.lastSaveFailed else { return }
                    focus = nil
                    onDone()
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
        // Save half a second after the typing stops (the web's 500 ms).
        // Every keystroke changes the id, which cancels the waiting save and
        // starts a new wait: only the last one survives its sleep (4b, 7a).
        .task(id: Draft(title: title, body: text)) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
        // And straight away when you leave, or the app goes to the background.
        .onDisappear { save() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { save() }
        }
        // A new note and Edit both open intentionally for typing.
        .onAppear {
            focus = .body
        }
        .navigationDestination(item: $nextPage) { id in
            NoteView(noteID: id)
        }
    }

    /// What `.task(id:)` watches: the title and the body together.
    private struct Draft: Equatable {
        let title: String
        let body: String
    }

    /// NEW in Phase 8c: one of the bar's changes, run on what's typed and
    /// what's selected. The new text goes into `text`, so it saves the way
    /// typing does, and the new selection into the editor. The keyboard
    /// comes back too, for a tap made while it was away.
    private func apply(_ change: (NoteEdit) -> NoteEdit) {
        let before = NoteEdit(text: text, selection: selection)
        let after = change(before)
        if after != before {
            text = after.text
            selection = after.textSelection
        }
        focus = .body
    }

    /// Hands the store what's on screen. Past the limit, the title still
    /// saves and the body waits until it fits again, so nothing is cut off.
    private func save() {
        let fits = fitsBudget(noteLength(text))
        store.updateNote(note.id, title: title, body: fits ? text : nil)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift` (replaces the file)

Your 7b version plus five touched spots, marked `NEW in Phase 8d`: the header; a `startedNote` `@State`; the Linked notes card and the **Open** row between the checklist and Delete; the three destinations and `.undoBar()` after the edit sheet; and the new `linkedNotesCard` function at the end.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift
//  Phase:   4b (the Tasks screen), changed in 7b (the planning cards) and
//           8d (linked notes, and Open the class)
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
//           Deleted and returns to the list, where Undo is offered. The
//           study timer and grade prompt join later.
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

### 4.6 `~/ClassPing/Sources/ClassPing/Components/AddMenu.swift` (replaces the file)

Three touched spots: the header, a `@Binding var tab`, and the Note row's button. Until 4.7 is in, the build stops at RootView's `AddMenu()` with "missing argument for parameter 'tab'".

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AddMenu.swift
//  Phase:   3 (app shell), changed in 4a (the first three rows open the
//           task form), 5b (Class opens the class form) and 8d (Note opens
//           the Notes tab)
//  Ports:   components/AddMenu.tsx (the five labelled choices)
//
//  Summary: The sheet the Add button opens: the five things you can add, named,
//           in the same order as the web app. Assignment, Exam and Reminder
//           slide in the task form, Class slides in the class form, and Note
//           closes the sheet and goes to your notes, as the web's goes to
//           /classes.
//

import SwiftUI

/// The value pushed when you pick Class. An empty marker type: it carries no
/// data, it just tells `.navigationDestination` below which form to show.
// NEW in Phase 5b
struct NewCourseLink: Hashable {}

struct AddMenu: View {
    /// `dismiss` closes the sheet, the way `onClose()` does in the web component.
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store

    /// How tall the sheet is. Starts at half height; jumps to full when a
    /// form slides in, because a form needs the room.
    @State private var detent: PresentationDetent = .medium   // NEW in Phase 4a

    /// NEW in Phase 8d: RootView's selected tab, borrowed, so Note can switch
    /// to Notes. A `@Binding`, as Today got in 6b for "View all": the tab
    /// still belongs to RootView, and writing it here changes it there.
    @Binding var tab: MainTab

    /// One choice in the menu. `symbol` is an SF Symbol name (the native icon set
    /// that replaces components/icons.tsx). `kind` is set for the three rows
    /// that open the task form; `addsCourse` for the Class row.
    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let symbol: String
        var kind: Assignment.Kind? = nil       // NEW in Phase 4a
        var addsCourse = false                 // NEW in Phase 5b
    }

    /// The five choices, matching AddMenu.tsx's list and wording.
    private let options = [
        Option(label: "Assignment", detail: "Homework, essays, lab reports", symbol: "doc.text", kind: .assignment),
        Option(label: "Exam", detail: "A test or quiz to revise for", symbol: "graduationcap", kind: .exam),
        Option(label: "Reminder", detail: "Something to bring or do, not graded", symbol: "bell", kind: .reminder),
        Option(label: "Note", detail: "Write down a lecture or a thought", symbol: "pencil"),
        // CHANGED in Phase 5b: Class now opens the class form.
        Option(label: "Class", detail: "Add a subject to your timetable", symbol: "book", addsCourse: true),
    ]

    var body: some View {
        NavigationStack {
            List(options) { opt in
                // A row with a kind pushes that kind; the Class row pushes the
                // marker. Each value type has its own destination below.
                if let kind = opt.kind {
                    NavigationLink(value: kind) {
                        label(for: opt)
                    }
                } else if opt.addsCourse {
                    // NEW in Phase 5b
                    NavigationLink(value: NewCourseLink()) {
                        label(for: opt)
                    }
                } else {
                    // CHANGED in Phase 8d: Note (the only row left with no
                    // kind or class) closes the menu and opens the Notes tab,
                    // where the web's Note goes (/classes), as it was left.
                    Button {
                        dismiss()
                        tab = .notes
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
            // What to show when a kind is pushed. Saving closes the whole Add
            // sheet (not just the form), so `onFinish` is our dismiss.
            .navigationDestination(for: Assignment.Kind.self) { kind in
                AssignmentFormView(kind: kind, onFinish: { dismiss() })
                    .onAppear { detent = .large }
            }
            // NEW in Phase 5b: and when Class is picked.
            .navigationDestination(for: NewCourseLink.self) { _ in
                CourseFormView(onFinish: { dismiss() })
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

### 4.7 `~/ClassPing/Sources/ClassPing/RootView.swift` (replaces the file)

D-43's version (commit it first, see the top) plus two touched lines: the header, and `AddMenu(tab: $tab)` in the sheet. Your D-43 comments are a little shorter than these; either is fine.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   3 (app shell), changed in 5a (Profile tab replaces Planner, D-19),
//           6b (Today can switch tabs), 7c (going where a tap asks),
//           after 8c (the bar steps aside for the keyboard, D-43) and in
//           8d (the Add menu can switch tabs too, for Note)
//  Ports:   components/TabBar.tsx (four tabs with the Add button between them),
//           and openApp() in public/sw.js (a tap opens the right screen)
//
//  Summary: The screen under everything else. A custom bottom bar switches
//           between the four main screens, Today, Notes, Tasks and Profile,
//           with the brand Add button raised in the middle. The week now lives
//           inside Today. The whole app is tinted with the chosen accent and
//           forced to the chosen light/dark mode here. Since 7c it also takes
//           the store's route: a task's detail, Today, or the post-class
//           prompt, which it shows over everything.
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

    /// NEW in Phase 7c: what's pushed on the Tasks tab, in code. A
    /// `NavigationPath` is a navigation stack written as a list: empty is the
    /// task list itself; one `AssignmentLink` in it is that task's detail on
    /// top. Tapping a row still adds to it by itself; a tap on a notification
    /// replaces it.
    @State private var tasksPath = NavigationPath()

    /// NEW in Phase 7c: whether the post-class prompt is showing, and which
    /// class it asks about (nil: none just ended, so it says so).
    @State private var promptOpen = false
    @State private var promptCourse: Course? = nil

    /// NEW in Phase 7c: the class a new task starts on after "Yes, add it".
    /// While it's set, the task form is open in a sheet.
    @State private var addingFor: Course? = nil

    /// NEW after Phase 8c (D-43): true while the keyboard is on screen. The
    /// bar steps aside then, so nothing that sits on the keyboard (the note's
    /// formatting bar, the end of a search's results) is hidden behind it.
    @State private var keyboardUp = false

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
            // CHANGED in Phase 7c: `path:` lets a tap open a task's detail.
            NavigationStack(path: $tasksPath) { AssignmentsView().navigationTitle("Tasks") }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.tasks)
            NavigationStack { ProfileView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.profile)
        }
        // `safeAreaInset` pins the bar to the bottom and insets the screen above
        // it, so a list never scrolls underneath the bar.
        .safeAreaInset(edge: .bottom) {
            // CHANGED after Phase 8c (D-43): gone while the keyboard is up.
            // A tab's screen stops at the top of the keyboard, not at the top
            // of the bar, so the bar would cover the screen's last few lines.
            if !keyboardUp {
                // CHANGED in Phase 5a: the bar also needs your name for the avatar.
                MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent,
                           name: store.profile.username)
            }
        }
        // NEW after Phase 8c (D-43): iOS announces the keyboard coming and
        // going with a notification. `onReceive` runs its closure each time
        // one arrives. "Will" fires as the keyboard starts to move, so the
        // bar is gone before the keyboard lands.
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        // The warm ground behind everything, including under the bar.
        .background(Theme.canvas.ignoresSafeArea())
        // The accent tints buttons, pickers and links app-wide.
        .tint(Theme.brand(accent))
        // Force light or dark to match the profile, overriding the system setting.
        .preferredColorScheme(store.profile.theme == .dark ? .dark : .light)
        // NEW in Phase 7c: the post-class prompt, over the whole screen, tab
        // bar included. An overlay, not a sheet: a sheet can't open while
        // another one is showing, so a tap would get lost; an overlay always
        // appears, and at worst waits under a sheet you still have open.
        .overlay {
            ZStack {
                if promptOpen {
                    PostClassPrompt(course: promptCourse,
                                    onAdd: { course in
                                        promptOpen = false
                                        addingFor = course
                                    },
                                    onClose: {
                                        promptOpen = false
                                        tab = .today
                                    })
                        .transition(.opacity)
                }
            }
            // Fade the prompt in and out instead of popping. On the ZStack,
            // so only the prompt animates, not the tab switch behind it.
            .animation(.easeOut(duration: 0.2), value: promptOpen)
        }
        // The Add button opens this sheet.
        // CHANGED in Phase 8d: with the tab, so Note can switch to Notes.
        .sheet(isPresented: $addOpen) { AddMenu(tab: $tab) }
        // NEW in Phase 7c: "Yes, add it" opens the task form on that class.
        // `sheet(item:)` shows it while `addingFor` is set and clears it on close.
        .sheet(item: $addingFor) { course in
            NavigationStack {
                AssignmentFormView(courseID: course.id, onFinish: { addingFor = nil })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { addingFor = nil }
                        }
                    }
            }
        }
        // NEW in Phase 7c: go where a tapped notification or "Log it" asked.
        // `initial: true` also runs this when the screen first appears, for a
        // tap that launched the app before this screen existed.
        .onChange(of: store.route, initial: true) { _, route in
            guard let route else { return }
            go(route)
            // Taken. Back to nil, so the same request again still counts as a change.
            store.route = nil
        }
    }

    /// Opens the screen a route names. NEW in Phase 7c. Nothing you have open
    /// is closed: if a sheet is showing, the screen waits underneath it.
    private func go(_ route: AppRoute) {
        switch route {
        case .today:
            tab = .today
        case .task(let id):
            tab = .tasks
            // The list with that task's detail on top, or just the list if
            // the task was deleted since the notification was planned.
            tasksPath = store.assignment(id) == nil
                ? NavigationPath()
                : NavigationPath([AssignmentLink(id: id)])
        case .postClass(let id):
            // The class the notification names, which stays right even if
            // you tap it an hour later; else whichever class just ended.
            promptCourse = store.course(id) ?? justEnded(store.activeCourses, now: .now)?.course
            promptOpen = true
        }
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

### Not typed: the tests

`QuickTaskTests.swift` (8 tests) is new in `docs/ios/reference/Tests/Logic/`, and `NoteStoreTests.swift` in `docs/ios/reference/Tests/Persistence/` is your version with 8 more at the end (links, the link picker's rules, a link surviving a deleted note or task and Undo, and what a quick task files). To run them with your own scripts:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/QuickTaskTests.swift Tests/Logic/
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Persistence/NoteStoreTests.swift Tests/Store/
scripts/test-logic.sh
scripts/test-store.sh
```

No script changes: `QuickTask.swift` is in `Logic/`, which both scripts copy whole, and `Store+Notes.swift` is already on `test-store.sh`'s list. Copying `NoteStoreTests.swift` changes its "Run:" line to the reference's (`tools/persistence-test.sh`); nothing else of yours changes.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 8d: notes that connect"
```

On the phone (use a class that has a note or two, Biology here):

1. **A quick reminder.** Open a Biology note and tap the **bell**. "Quick reminder", Biology over the title field, **Add** greyed out. Type a space: still grey. Type `Bring goggles`, tap **Add**. On the Tasks tab: "Bring goggles", Biology, due tomorrow, all-day.
2. **A blank quick assignment.** Back in the note, tap the **plus**, pick **Quiz**, leave the title empty, **Add**: "Biology quiz", due in three days.
3. **While typing.** Tap **Edit**, type a line, tap the **plus**, switch on **Set a time**, pick 9:00 AM, **Add**. Back in the editor your line is there and the bottom says "Saved". The task is due at 9:00 AM.
4. **From a quick note.** Notes tab → **Quick note**, type a word, tap the **plus**, **Add**: "Quick note assignment", in the Inbox (open question 18).
5. **Link a note.** Open a Biology task. Under the checklist, **Linked notes**, empty. **Link an existing note** lists Biology's notes; pick one: it appears above, and it's gone from the menu.
6. **Open it, unlink it.** Tap the linked note: it opens on top of the task; **Back**: the task. Tap **Unlink**: the row goes and the note is back in the menu. On the Notes tab it's still in Biology.
7. **New note.** Tap **New note**: an empty note, ready for typing, "Biology · Today". Type a line and go **Back**: it's in Linked notes, and in Biology's notes.
8. **Open Biology.** Tap **Open Biology**: the class's notes, on top of the task. Open one of its notes, then **Back** twice: the task.
9. **Undo, twice.** Open a linked note and tap its bin: back on the task, "… deleted" with **Undo**. Tap **Undo**: it's linked again. Now delete the task itself, tap **Undo** on the list, open it: its notes are still linked.
10. **An Inbox task.** Open a task with no class: the menu offers notes from every class, and quick notes.
11. **From Today.** Tap a task on Today: the same card, and its notes open there too.
12. **Add → Note.** From Today, tap **+** → **Note**: the Notes tab.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] The bell and the plus are on a note while reading and while typing, and file their task for the note's class (the Inbox for a quick note).
- [ ] A reminder can't be added without words; a blank assignment is named after its class and kind.
- [ ] A task lists its linked notes; they open on top of it, and Unlink, Link an existing note and New note all work, on the Tasks tab and from Today.
- [ ] Open (the class) shows that class's notes, and their notes open from there.
- [ ] A deleted linked note comes back linked with Undo, and so do the links of a deleted task.
- [ ] **+ → Note** opens the Notes tab.

## 7. If it breaks

- **Tapping a linked note or Open Biology does nothing:** the two `.navigationDestination(for:)` calls are missing, or ended up inside `card { }` or the `VStack`. They belong on the ScrollView's chain of modifiers, after `.sheet(item: $editing)`, as in 4.5.
- **`missing argument for parameter 'tab' in call`**: RootView still says `AddMenu()`. That's 4.7.
- **`type 'QuickTaskMode' does not conform to protocol 'Identifiable'`**: `var id: Self { self }` is missing from the enum in 4.1.
- **`switch must be exhaustive`** in `addQuickTask`: a `case` for one of the three types is missing.
- **The note's toolbar looks crowded while typing** (Back, bell, plus, bin, Done): iOS shortens the back button to just its arrow to make room. Expected.
- **Add stays grey on a reminder:** it needs words, and spaces don't count. On the plus it's never grey.

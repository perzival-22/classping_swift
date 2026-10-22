---
title: "Phase 8a: Notes you can write and find"
date: 2026-10-18
generated_by: skills-for-architects
---

# Phase 8a: Notes you can write and find

*First of three parts of Phase 8 (D-36). Checked on 2026-10-18 on top of your typed 7c (identical to the reference): `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 205/205 (21 new, in `NotesTests`) and `persistence-test.sh` 28/28 (7 new in `NoteStoreTests`, plus your 2 `PostClassStoreTests`). Nothing here has been on a phone yet.*

*Since typed (D-42): your tree goes further than this doc in `NoteView.swift`, `NotesView.swift`, `CourseNotesView.swift` and `Store+Notes.swift` (save before Done and before delete, Retry, the save-failure line, VoiceOver names). The reference holds your version, and later phases build on it.*

**Before you start:** commit 7c. Your tree still shows its seven files as changed, and 8a replaces two files 7c didn't touch, so it's an easy commit to tangle.

## 1. Goal

The Notes tab stops being a placeholder: every class with its notes, quick notes with no class, a search across all of them, and a note you can type into that saves by itself.

**On your phone:**

- **Notes tab:** your classes, each with its book, its timetable and "· 2 notes"; a green **NOW** tag on the one that's on. Under them, your quick notes ("Quick note · Today"). **Quick note** at the top right; a search field when you pull the list down a little.
- **A class:** its times, room and teacher, **New note** (or **Take notes, this class is on now** during the class, which reopens today's note), then its notes newest first, each with its day ("Today", "Yesterday", "Tue, Sep 1"), a line of preview and a bin.
- **A note:** a big title field, "Biology · Today", and the note as plain text. "Saving…" turns into "Saved" half a second after you stop typing.

What 8a doesn't do yet: the note is plain markdown text (`# Cells`, `- [ ] read ch. 4`), not drawn as headings and checkboxes. That's 8b, the reader. Buttons for bold, highlight and colours, tidy, and filing an assignment from a note are 8c.

## 2. New Swift concepts

**`TextEditor` and `@FocusState`.** `TextField` is one line; `TextEditor` is a box of many lines that scrolls by itself, bound to a `String` the same way. `@FocusState` is `@State` for the keyboard: whichever field it names has the caret, and nil puts the keyboard away.

```swift
@State private var text = ""
@FocusState private var focus: Field?
private enum Field { case title, body }

TextEditor(text: $text)
    .focused($focus, equals: .body)      // this box is `.body`
    .onAppear { focus = .body }          // open with the keyboard up
Button("Done") { focus = nil }           // put it away
```

`.toolbar { ToolbarItemGroup(placement: .keyboard) { … } }` puts that Done button on a bar above the keyboard.

**`.searchable`.** One modifier gives a screen iOS's own search field, under the title (pull the list down to see it), bound to a `String`. The screen decides what to show for it:

```swift
.searchable(text: $search, prompt: "Search every note")

if search.isEmpty { classList } else { results }
```

**Pushing a screen from code: `navigationDestination(item:)`.** A `NavigationLink(value:)` pushes when you tap it. Quick note and New note must create the note first and then open it, so the push comes from code. `navigationDestination(item:)` watches an optional: set it, and the screen for that value is pushed; go back, and it's nil again. No path to manage, unlike 7c's tab-wide `NavigationPath`:

```swift
@State private var startedNote: UUID?

Button("Quick note") {
    startedNote = store.addNote(courseID: nil, date: dayOf(.now))
}
.navigationDestination(item: $startedNote) { id in NoteView(noteID: id) }
```

You'll also meet the autosave, built from pieces you know: `.task(id:)` (4b) restarts on every keystroke, and its `Task.sleep` (7a) means only the last keystroke's save survives half a second. `.onDisappear` and `scenePhase` (7a) save straight away on the way out. Also **regular expressions** through `replacingOccurrences(of:with:options: .regularExpression)`, with **raw strings** `#"…"#` so the backslashes stay as typed, and `utf16.count`, which counts a note the way JavaScript does.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `MAX_NOTE_CHARS`, `fitsBudget` in `lib/notes.ts` | `maxNoteChars`, `fitsBudget`, `noteLength` in `Logic/Notes.swift` | Same 20,000 limit, counted in UTF-16 units like JavaScript's `length` (`noteLength`), so a note fits on one app exactly when it fits on the other |
| `stripMarkers`, `noteTitle`, `notePreview`, `noteText`, `dayLabel` | same names, same file | Same output. The tests were checked against `lib/notes.ts` itself, run in node, quirks included (`\*` loses its star but keeps its backslash in a preview) |
| The search and `liveClassId` in `app/classes/page.tsx` | `noteMatches` and `liveCourseID`, same file | Same: title, words and class name, ignoring case; a class is on from its start minute to its end minute |
| `notesForClass`, `addNote`, `updateNote`, `deleteNote`, `noteById` in `lib/store.tsx` | `Store+Notes.swift` | Same rules: newest day first, an unchanged save writes nothing, an edit past the limit is refused whole. Undo after a delete, as the web's store offers |
| The first pane of `app/classes/page.tsx` | `Screens/NotesView.swift` | Same rows and words. Quick note sits in the navigation bar; the search is iOS's own field. A note from an archived class is found by its class's name (the web calls it "Quick note") |
| `NoteListPane` | `Screens/Notes/CourseNotesView.swift` | Same header, list and New note / "Take notes, this class is on now". The web offers those two only on a laptop (D-37). "Delete this note?" drops the web's "It can't be undone": both apps offer Undo. Times read "10:00 AM – 11:15 AM", the phone's clock everywhere |
| `NotePane`, and the saving in `NoteEditor.tsx` | `Screens/Notes/NoteView.swift` | Plain markdown editing on the phone (D-37), with the web editor's save rhythm (500 ms), words ("Saving…", "Saved", "This note is full, start a new page to keep writing"), count past 90% and New page |
| `parseBlocks`, `inlineToHtml` | 8b | The reader draws them |
| `htmlToMd`, `mdToHtml`, `noteColorOf`, `lib/highlight.ts` | none | Browser-only: they convert between markdown and a web page's DOM |
| `normalizeNotes`, `mergeNotes`, `conflictTitle`, `MAX_NOTES` | Phase 11 / 14 | No caller until backup restore and sync (D-31's rule) |

## 4. Files, in the order to type them

4.1 builds on its own, 4.2 too, and 4.3 needs both. 4.4 needs 4.3. 4.5 and 4.6 need each other, so build after 4.6. Four new files, two replaced.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Notes.swift` (new file)

Pure logic, so the Linux tests can run it. Most of it is regular expressions, each one of the web's `.replace` calls in the same order: the tests compare its answers with the web's own code.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Notes.swift
//  Phase:   8a (notes you can write and find)
//  Ports:   lib/notes.ts (MAX_NOTE_CHARS, fitsBudget, NOTE_COLORS,
//           stripMarkers, noteTitle, notePreview, noteText, dayLabel), the
//           search and the live-class check in app/classes/page.tsx
//
//  Summary: The words around a note: what a list calls it, the line under
//           that, its plain text for search, and "Today", "Yesterday" or
//           "Tue, Sep 1" for its day. Notes are stored as markdown with a few
//           extras (__underline__, ==highlight==, [[red|colored text]],
//           :::columns), and everything here reads straight through them.
//           Drawing a note comes with the reader in 8b. Foundation only.
//

import Foundation

// MARK: - The limit

/// The longest one note may be. `MAX_NOTE_CHARS` in lib/notes.ts: a dense
/// 90-minute lecture runs 4,000 to 6,000 characters.
let maxNoteChars = 20_000

/// How long a note's text is, counted the way the web counts it (JavaScript's
/// `length`, in UTF-16 units). An emoji counts as two, so a note the web
/// accepts is exactly a note the phone accepts.
func noteLength(_ text: String) -> Int {
    text.utf16.count
}

/// May a note's body become this long? `fitsBudget` in lib/notes.ts. Only the
/// one note is measured: other notes, however long, never count against it.
func fitsBudget(_ length: Int) -> Bool {
    length <= maxNoteChars
}

// MARK: - Reading through the markers

/// The pens a note can write in, by name. A note stores `[[red|late!]]`,
/// never a shade; the colors themselves come with the reader (8b).
/// `NOTE_COLORS` in lib/notes.ts.
let notePens = ["red", "orange", "green", "blue", "purple"]

/// `[[red|text]]`, as a regular expression. `[\s\S]*?` is "any characters, as
/// few as possible", so a pen ends at its own `]]` and two can share a line.
/// A `#"..."#` string is a raw string: backslashes stay as typed, which is
/// what a regular expression needs.
private let penPattern = #"\[\[("# + notePens.joined(separator: "|") + #")\|([\s\S]*?)\]\]"#

/// Every match of `pattern` in `text` replaced by `template`, where `$1` and
/// `$2` stand for the bracketed parts. The web's `.replace(/…/g, "…")`.
private func replacing(_ pattern: String, in text: String, with template: String) -> String {
    text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
}

/// Does `text` match `pattern` anywhere? The web's `/…/.test(text)`.
private func matches(_ pattern: String, _ text: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
}

/// One table row's cells, trimmed: `| a | b |` and `a | b` both give
/// ["a", "b"]. A pipe typed inside a cell is stored as `\|`, so it doesn't
/// split, and comes back as a plain `|`. `splitRow` in lib/notes.ts.
func tableCells(_ line: String) -> [String] {
    // The outer pipes are optional; drop them.
    var inner = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if inner.hasPrefix("|") { inner.removeFirst() }
    if inner.hasSuffix("|") { inner.removeLast() }

    // Walk the characters, cutting at every pipe that has no backslash in
    // front of it. (The web does this with a look-behind in a regex.)
    var cells: [String] = []
    var current = ""
    var previous: Character? = nil
    for ch in inner {
        if ch == "|" && previous != "\\" {
            cells.append(current)
            current = ""
        } else {
            current.append(ch)
        }
        previous = ch
    }
    cells.append(current)
    return cells.map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\|", with: "|")
    }
}

/// Is this the `| --- | --- |` line under a table's header row?
/// `isTableDelimiter` in lib/notes.ts.
func isTableRuler(_ line: String) -> Bool {
    let cells = tableCells(line)
    return !cells.isEmpty && cells.allSatisfy { matches(#"^:?-+:?$"#, $0) }
}

/// One line with its markers gone, leaving the words. `stripMarkers`.
/// Each step is one of the web's `.replace` calls, in the same order.
func stripMarkers(_ line: String) -> String {
    // A table row: the ruler goes entirely, and a row reads as its cells'
    // words with spaces between them.
    if matches(#"^\s*\|"#, line) {
        if isTableRuler(line) { return "" }
        let words = tableCells(line).joined(separator: " ")
        return replacing(penPattern, in: words, with: "$2")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var s = line
    // What starts a block: #, ##, ###, >, - [ ], - , 1.
    s = replacing(#"^\s{0,3}(#{1,3}\s+|>\s?|[-*]\s+\[[ xX]\]\s*|[-*]\s+|\d+\.\s+)"#, in: s, with: "")
    // A code fence line, and the column fences, carry no words.
    s = replacing(#"^```.*$"#, in: s, with: "")
    s = replacing(#"^:::(columns|col)?\s*$"#, in: s, with: "")
    // A pen leaves its words behind; a link leaves its text.
    s = replacing(penPattern, in: s, with: "$2")
    s = replacing(#"\[([^\]]*)\]\([^)]*\)"#, in: s, with: "$1")
    // Bold, underline, highlight, code and italic markers go.
    s = replacing(#"(\*\*|__|==|`|\*)"#, in: s, with: "")
    // A backslash-escaped character becomes the character itself.
    s = replacing(#"\\([\\*_=`\[\]])"#, in: s, with: "$1")
    return s
}

// MARK: - What a list shows

/// What to call a note: its typed title, else its first line with words in
/// it (markers gone, at most 80 characters), else "Untitled note".
/// `noteTitle` in lib/notes.ts.
func noteTitle(title: String, body: String) -> String {
    let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !typed.isEmpty { return typed }
    // `lazy` works through the lines one at a time, so `first(where:)` stops
    // at the first line with words: no loop to break out of.
    let firstWords = body.components(separatedBy: "\n").lazy
        .map { stripMarkers($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    return firstWords.map { String($0.prefix(80)) } ?? "Untitled note"
}

/// One line of preview: the words after the first line that has any, joined
/// with spaces, cut to `max` characters with "…". `notePreview`.
func notePreview(_ body: String, max: Int = 120) -> String {
    let lines = body.components(separatedBy: "\n")
        .map { stripMarkers($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    // Nothing but blank lines: no preview.
    guard let first = lines.firstIndex(where: { !$0.isEmpty }) else { return "" }
    // `lines[(first + 1)...]` is everything after that line (possibly nothing).
    let text = lines[(first + 1)...].filter { !$0.isEmpty }.joined(separator: " ")
    return text.count > max ? String(text.prefix(max - 1)) + "…" : text
}

/// The whole note as plain text, line by line: what search reads.
/// `noteText` in lib/notes.ts.
func noteText(_ body: String) -> String {
    body.components(separatedBy: "\n").map(stripMarkers).joined(separator: "\n")
}

/// "Today", "Yesterday", or "Tue, Sep 1" for a note's "yyyy-MM-dd" day.
/// Anything that isn't a day comes back unchanged. `dayLabel`.
func dayLabel(_ key: String, today: Date = .now) -> String {
    guard let day = deadlineDayStart(Deadline(date: key, time: nil)) else { return key }
    if dayOf(day) == dayOf(today) { return "Today" }
    if dayOf(day) == dayOf(scheduleDate(today, -1)) { return "Yesterday" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEE, MMM d"
    return f.string(from: day)
}

// MARK: - Finding notes, and the class that's on

/// Does a note match a search? Its title, its plain text and its class's name
/// are searched together, ignoring case. An empty search matches nothing.
/// The search in app/classes/page.tsx.
func noteMatches(_ query: String, title: String, body: String, subject: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return false }
    return "\(title)\n\(noteText(body))\n\(subject)".lowercased().contains(q)
}

/// The class in session right now, if any: one of its meetings is today and
/// the clock is between its start and end, both counted. `liveClassId` in
/// app/classes/page.tsx, which tags it Now and offers today's note.
func liveCourseID<C: Schedulable>(_ courses: [C], now: Date) -> UUID? {
    let today = dayIndex(of: now)
    let mins = minuteOfDay(now)
    return expandClassMeetings(courses).first { slot in
        slot.meeting.days.contains(today) && mins >= slot.meeting.start && mins <= slot.meeting.end
    }?.course.id
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Store+Assignments.swift` (replaces the file)

Four touched spots: the header, the summary, the new `.note` case in `PendingUndo.Item`, and the matching `case .note` in `undoDelete`. Swift won't build `undoDelete` until its `switch` handles the new case, which is the point of using an enum (6b).

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

### 4.3 `~/ClassPing/Sources/ClassPing/Store+Notes.swift` (new file)

Every note action, in the same shape as `Store+Assignments.swift`. It needs 4.1 and 4.2.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Notes.swift
//  Phase:   8a (notes you can write and find)
//  Ports:   lib/store.tsx (liveNotes, notesForClass, addNote, updateNote,
//           deleteNote, noteById) and, from app/classes/page.tsx, the note
//           counts, the search and today's note for a class that's on
//
//  Summary: Everything that reads or changes a note. A note belongs to a
//           class, or to none (a quick note), and to the day it was taken.
//           Each change saves to the phone straight away, and a delete can
//           be undone, like an assignment's.
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

        // A save that changes nothing writes nothing. The note screen saves
        // on a timer, when you leave it and when the app goes away, so the
        // same text often arrives more than once.
        let newTitle = title ?? notes[i].title
        let newBody = body ?? notes[i].body
        guard newTitle != notes[i].title || newBody != notes[i].body else { return true }

        notes[i].title = newTitle
        notes[i].body = newBody
        notes[i].updatedAt = .now
        save()
        return true
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
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift` (new file, in a new `Notes` folder)

Two views in one file: `NoteView` finds the note, and the private `NoteEditorView` holds the typing. The split is 4a's trick again: the editor's `@State` starts from the note once, in `init`, and then belongs to your typing.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift
//  Phase:   8a (notes you can write and find)
//  Ports:   NotePane in app/classes/page.tsx (the title, "class · day", the
//           bin) and the saving half of components/NoteEditor.tsx (save half
//           a second after you stop typing, "Saving…" / "Saved", the 20,000
//           character limit and New page)
//
//  Summary: One note, open for writing: its title, then the note itself as
//           plain markdown text. It saves by itself a moment after you stop
//           typing, when you leave, and when the app goes to the background.
//           Phase 8b opens notes in a reader first, with Edit to come here.
//

import SwiftUI

struct NoteView: View {
    @Environment(Store.self) private var store

    /// Which note to show. The note itself is looked up in the store.
    let noteID: UUID

    var body: some View {
        if let note = store.note(noteID) {
            NoteEditorView(note: note)
        } else {
            // Just deleted (the screen is on its way back), or never existed.
            ContentUnavailableView("Note not found.", systemImage: "note.text")
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

    /// What's typed, which can run ahead of what's saved by half a second.
    @State private var title: String
    @State private var text: String

    /// The note started by New page, while it's open.
    @State private var nextPage: UUID?

    /// Which field has the keyboard, or nil for none. `@FocusState` is
    /// `@State` for the keyboard: set it to move the caret, set it to nil to
    /// put the keyboard away.
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    init(note: Note) {
        self.note = note
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.body)
    }

    var body: some View {
        let course = store.course(note.courseID)
        let length = noteLength(text)
        let full = !fitsBudget(length)
        // Saved when the store holds exactly what's on screen.
        let saved = store.note(note.id).map { $0.title == title && $0.body == text } ?? false

        VStack(spacing: 0) {
            // MARK: Title, and where the note lives
            VStack(alignment: .leading, spacing: 2) {
                // The grey text is what the list would call it untitled.
                TextField(noteTitle(title: "", body: text), text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .title)
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
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .body)
                    // Let the canvas show through instead of a white box.
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
            }

            // MARK: Saving
            // "Saving…" until the store has it, then "Saved". Near the limit,
            // the count and New page, so a long lecture goes on in a new note
            // instead of stopping at the ceiling.
            HStack(spacing: 10) {
                Text(full ? "This note is full, start a new page to keep writing"
                          : (saved ? "Saved" : "Saving…"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if length > maxNoteChars * 9 / 10 {
                    Text("\(length.formatted()) / \(maxNoteChars.formatted())")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(full ? Theme.dangerInk : Theme.warnInk)
                    Button("New page") {
                        save()
                        nextPage = store.addNote(courseID: note.courseID, date: note.date,
                                                 assignmentID: note.assignmentID)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete goes straight back, where the Undo bar is waiting.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
            // A bar on top of the keyboard, with a way to put it away.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
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
        // A brand-new note opens with the keyboard up, ready to type.
        .onAppear {
            if note.title.isEmpty && note.body.isEmpty { focus = .body }
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

    /// Hands the store what's on screen. Past the limit, the title still
    /// saves and the body waits until it fits again, so nothing is cut off.
    private func save() {
        let fits = fitsBudget(noteLength(text))
        store.updateNote(note.id, title: title, body: fits ? text : nil)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/NotesView.swift` (replaces the file)

The whole tab, replacing the Phase 3 placeholder. It defines `CourseNotesLink` and `NoteLink`, and opens `CourseNotesView` from 4.6, so it won't build until 4.6 is in.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/NotesView.swift
//  Phase:   3 (app shell), rebuilt in 8a (notes you can write and find)
//  Ports:   app/classes/page.tsx (the first pane: Quick note, the search,
//           your classes with their note counts and Now tag, quick notes)
//
//  Summary: The Notes tab. Your classes, each with its timetable, how many
//           notes it holds and a Now tag while it's on; under them your quick
//           notes, the ones with no class; and a search across every note.
//           A class opens its notes; Quick note starts one with no class.
//

import SwiftUI

/// Pushes one class's notes. A small Hashable value, like 4b's AssignmentLink.
// NEW in Phase 8a
struct CourseNotesLink: Hashable {
    let id: UUID
}

/// Pushes one note.
// NEW in Phase 8a
struct NoteLink: Hashable {
    let id: UUID
}

struct NotesView: View {
    @Environment(Store.self) private var store

    /// What's typed in the search field. `.searchable` below draws the field
    /// and keeps this up to date.
    @State private var search = ""

    /// The note Quick note just started. Setting it opens that note
    /// (`navigationDestination(item:)` below); going back sets it to nil.
    @State private var startedNote: UUID?

    /// Whether the new-class form is open, for "Add your first class".
    @State private var addingCourse = false

    var body: some View {
        // Redrawn each minute, so the Now tag moves with the timetable.
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // A search replaces the list until it's cleared.
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        classList(context.date)
                    } else {
                        results
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Notes")
        // A search field under the title. Pull the list down a little to
        // reveal it; `prompt` is the grey text inside it.
        .searchable(text: $search, prompt: "Search every note")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Quick note") {
                    startedNote = store.addNote(courseID: nil, date: dayOf(.now))
                }
                .font(.system(size: 15, weight: .semibold))
            }
        }
        // Where each kind of row goes. Registered here, at the bottom of the
        // tab's stack, they also work for rows on the screens pushed above.
        .navigationDestination(for: CourseNotesLink.self) { link in
            CourseNotesView(courseID: link.id)
        }
        .navigationDestination(for: NoteLink.self) { link in
            NoteView(noteID: link.id)
        }
        // A push from code: while `startedNote` holds an id, that note is open.
        .navigationDestination(item: $startedNote) { id in
            NoteView(noteID: id)
        }
        .sheet(isPresented: $addingCourse) {
            NavigationStack {
                CourseFormView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { addingCourse = false }
                        }
                    }
            }
        }
        // A note deleted from its own screen comes back to here, Undo waiting.
        .undoBar()
    }

    // MARK: - The list

    /// The classes, then the quick notes. Before the first class (and with no
    /// quick notes either), one button to add a class instead.
    @ViewBuilder
    private func classList(_ now: Date) -> some View {
        let courses = store.activeCourses
        let quick = store.notes(for: nil)
        let live = liveCourseID(courses, now: now)

        Text(courses.isEmpty ? "Add a class to start taking notes." : "Pick one to open its notes.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

        if courses.isEmpty && quick.isEmpty {
            Button {
                addingCourse = true
            } label: {
                Text("Add your first class")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.brandGradient(store.profile.accent),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }

        ForEach(courses) { course in
            NavigationLink(value: CourseNotesLink(id: course.id)) {
                courseRow(course, live: course.id == live)
            }
            .buttonStyle(.plain)
        }

        ForEach(quick) { note in
            NavigationLink(value: NoteLink(id: note.id)) {
                noteRow(noteTitle(title: note.title, body: note.body),
                        "Quick note · \(dayLabel(note.date))")
            }
            .buttonStyle(.plain)
        }
    }

    /// One class: its book, its name (Now while it's on), its timetable and
    /// how many notes it holds. `ClassRow` in app/classes/page.tsx.
    private func courseRow(_ course: Course, live: Bool) -> some View {
        let count = store.noteCount(for: course.id)
        return HStack(spacing: 12) {
            SubjectBook(color: course.color, short: course.short, compact: true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(course.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if live {
                        Text("NOW")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.good, in: Capsule())
                    }
                }
                Text(meetingSummary(course) + (count > 0 ? " · \(count) note\(count == 1 ? "" : "s")" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.hint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// A note's row: what it's called, and one quieter line under it.
    private func noteRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Search

    /// Every note the search finds, or a line saying none did.
    @ViewBuilder
    private var results: some View {
        let found = store.searchNotes(search)
        if found.isEmpty {
            Text("No notes match “\(search)”.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
        ForEach(found) { note in
            NavigationLink(value: NoteLink(id: note.id)) {
                // The preview, or the day when there's nothing after the title.
                let preview = notePreview(note.body)
                noteRow(noteTitle(title: note.title, body: note.body),
                        preview.isEmpty ? dayLabel(note.date) : preview)
            }
            .buttonStyle(.plain)
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Notes/CourseNotesView.swift` (new file)

One class's notes. It uses `NoteLink` from 4.5 and `NoteView` from 4.4. Build now.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/CourseNotesView.swift
//  Phase:   8a (notes you can write and find)
//  Ports:   NoteListPane in app/classes/page.tsx (one class's notes)
//
//  Summary: One class's notes, newest first: its book, timetable, room and
//           teacher at the top, then New note (or, while the class is on,
//           "Take notes, this class is on now", which reopens today's note),
//           then each note with its day and a line of preview. The pencil
//           edits the class; the bin deletes a note, with Undo.
//

import SwiftUI

struct CourseNotesView: View {
    @Environment(Store.self) private var store

    /// The class whose notes these are. Looked up in the store on every
    /// redraw, so an edit to the class shows straight away.
    let courseID: UUID

    /// The note New note just started, while it's open (as on the Notes tab).
    @State private var startedNote: UUID?
    /// The class open in the edit form, or nil.
    @State private var editingCourse: Course?
    /// The note waiting for "Delete this note?", or nil.
    @State private var deleting: Note?

    var body: some View {
        if let course = store.course(courseID) {
            content(course)
        } else {
            // Deleted from Today while this screen was open.
            ContentUnavailableView("Class not found.", systemImage: "book.closed")
        }
    }

    /// The screen for a class that exists.
    private func content(_ course: Course) -> some View {
        let accent = store.profile.accent
        let notes = store.notes(for: course.id)

        return TimelineView(.everyMinute) { context in
            let live = liveCourseID(store.activeCourses, now: context.date) == course.id

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(course)

                    // While the class is on, one tap reopens today's lecture
                    // note (or starts it); otherwise a fresh note, a new topic.
                    Button {
                        startedNote = live
                            ? (store.todaysNote(for: course.id)?.id
                               ?? store.addNote(courseID: course.id, date: dayOf(.now)))
                            : store.addNote(courseID: course.id, date: dayOf(.now))
                    } label: {
                        Label(live ? "Take notes, this class is on now" : "New note",
                              systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.brandGradient(accent),
                                        in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if notes.isEmpty {
                        Text("No notes yet for this class.\nStart one for today's lecture or a new topic, the date fills itself in.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(notes) { note in
                                noteRow(note)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.canvas)
        .navigationTitle(course.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCourse = course
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit class")
            }
        }
        .navigationDestination(item: $startedNote) { id in
            NoteView(noteID: id)
        }
        .sheet(item: $editingCourse) { original in
            NavigationStack {
                CourseFormView(editing: original)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editingCourse = nil }
                        }
                    }
            }
        }
        // The "are you sure?" for a note's bin (6b's confirmationDialog).
        // `presenting:` hands the waiting note to the buttons.
        .confirmationDialog("Delete this note?",
                            isPresented: Binding(get: { deleting != nil },
                                                 set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible,
                            presenting: deleting) { note in
            Button("Delete", role: .destructive) {
                store.deleteNote(note.id)
            }
        }
        .undoBar()
    }

    // MARK: - Pieces

    /// The book, then the class's times, room and teacher, and the focused
    /// minutes recorded for it once there are any. The name is the screen's
    /// title above.
    private func header(_ course: Course) -> some View {
        // One meeting: its times. More: the web's one-line summary of them all.
        let times = course.additionalMeetings.isEmpty
            ? "\(fmtTime(course.startMin)) – \(fmtTime(course.endMin))"
            : meetingSummary(course)
        let room = course.room.map { $0.isEmpty ? "" : " · \($0)" } ?? ""
        let teacher = course.instructor.map { $0.isEmpty ? "" : " · \($0)" } ?? ""
        let focused = studyMinutes(store.studySessions, courseID: course.id)

        return HStack(alignment: .top, spacing: 12) {
            SubjectBook(color: course.color, short: course.short)
            VStack(alignment: .leading, spacing: 2) {
                Text(times + room + teacher)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if focused > 0 {
                    Text("\(focused) focused minute\(focused == 1 ? "" : "s") recorded")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.brand(store.profile.accent))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One note: its title and day, a line of preview, and its bin. The bin
    /// sits beside the link rather than inside it, so tapping it can't also
    /// open the note.
    private func noteRow(_ note: Note) -> some View {
        let preview = notePreview(note.body)
        return HStack(spacing: 0) {
            NavigationLink(value: NoteLink(id: note.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(noteTitle(title: note.title, body: note.body))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(dayLabel(note.date))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.faint)
                    }
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                deleting = note
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface2, in: Circle())
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete note")
        }
        .cardStyle()
    }
}
```

### Not typed: the tests, and one word in your store script

`NotesTests.swift` is in `docs/ios/reference/Tests/Logic/` and `NoteStoreTests.swift` in `docs/ios/reference/Tests/Persistence/`. To run them with your own scripts:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/NotesTests.swift Tests/Logic/
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Persistence/NoteStoreTests.swift Tests/Store/
```

Then add `Store+Notes` to the end of the `for source in ...` list in `scripts/test-store.sh`, and run both scripts.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 8a: notes you can write and find"
```

On the phone:

1. **The tab.** Notes: your classes, each with its timetable, and "Pick one to open its notes." Pull the list down a little: the search field.
2. **A quick note.** Tap **Quick note**: an empty note opens with the keyboard up. Title "Ping note"; in the note, `# Cells` and, on the next line, `- mitochondria`. The bar at the bottom says "Saving…", then "Saved". Tap **Done** above the keyboard, then go back: under the classes, "Ping note" with "Quick note · Today".
3. **A class's note.** Open a class, tap **New note**, and type only `# Osmosis` and `water moves in`. Go back: the row says "Osmosis" (no title typed, so its first line, without the `#`), "Today", and "water moves in". The class's row on the tab now says "· 1 note".
4. **Search.** On the tab, search `mito`: Ping note. Search the class's name: its notes. Search `zzz`: "No notes match "zzz"."
5. **Delete and Undo.** In the class, tap a note's bin: "Delete this note?", **Delete**. The Undo bar appears; tap **Undo** and it's back. Now open the note and tap the bin at the top right: back to the list, Undo waiting.
6. **It stays.** Close ClassPing from the app switcher and open it again: both notes, their titles and their text are there.
7. **During a class** (if one is on, or add a test class that's on now): its row has a green **NOW**, and the class screen says **Take notes, this class is on now**. Tap it, type a line, go back, and tap it again: the same note opens, not a new one.
8. Delete the test notes.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] Quick note and New note open straight into a new note, and it appears in the right list when you go back.
- [ ] "Saving…" becomes "Saved" after you stop typing, and the text survives closing the app.
- [ ] Titles fall back to the first line, previews show the next lines, days read Today / Yesterday / "Tue, Sep 1".
- [ ] Search finds notes by their words and by their class's name.
- [ ] Deleting from the list (after the question) and from the note both offer Undo, and Undo works.
- [ ] During a class, the NOW tag and "Take notes, this class is on now" show, and it reopens today's note.

## 7. If it breaks

- **`type 'PendingUndo.Item' has no member 'note'`** (in `Store+Notes.swift`): 4.2 isn't typed yet.
- **`switch must be exhaustive`** in `Store+Assignments.swift`: the `case .note(let id):` block in `undoDelete` is missing.
- **`cannot find 'NoteLink' in scope`** in `CourseNotesView.swift`, or **`cannot find 'CourseNotesView' in scope`** in `NotesView.swift`: 4.5 and 4.6 need each other; type both, then build.
- **"Saving…" never becomes "Saved":** `save()` never runs. Check the `.task(id: Draft(title: title, body: text))` block, and that `Draft` is `Equatable`.
- **The keyboard doesn't come up on a new note:** iOS sometimes ignores focus asked for in `.onAppear` while the screen is still sliding in. Tap the note to type; nothing is lost.
- **Your `scripts/test-store.sh` fails with `cannot find 'addNote'`:** `Store+Notes` isn't in the script's list yet.

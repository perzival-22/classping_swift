---
title: "Phase 13b: Paste a timetable, and imports from the class form"
date: 2026-10-21
---

# Phase 13b: Paste a timetable, and imports from the class form

The second half of Phase 13. It builds on your committed `d74eb54`
("Phase13a"), which is identical to the 13a reference: all seven files
match, the tree builds with no warnings, and your own suites passed,
544/544 and 128/128.

**Your 13a check, recorded (2026-10-21):** everything checks out. The
import panel opens from Profile and from Today's "Import my schedule", both
with the .ics and CSV buttons. A calendar file previews its classes,
assignments and skipped events; Cancel adds nothing; Add puts the classes
on the timetable and the deadlines in Tasks. A CSV reads Course, Days, Start
and End with the optional room, instructor, credits and semester days, in
"Mon, Wed", "MWF" and "TR", 12- and 24-hour times. Bad, empty and
over-3 MB files, missing columns, cancelled, past and duplicate-looking
events all say so clearly and add nothing. The term question comes once
after a first import into an empty planner, with suggested days and Not
now. Imports survive a relaunch, and a failed save says nothing was added.

**Copy one fixed test file first (D-85).** Since 10:13 this morning your
`scripts/test-store.sh` fails three tests in `BackupStoreTests`. Nothing is
wrong with your code. The test's web backup file marks History and Reading
deleted at 2026-09-21 10:13 your time, and today they turned 30 days old,
so opening the planner (D-75) now clears them for good, exactly as it
should, and the test still expects them. The fixed file dates them a day
before each run:

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Persistence/BackupStoreTests.swift Tests/Store/
scripts/test-store.sh     # expect 128 again
```

**Start here:** Stop 1 (4.1 and 4.2), the logic: one new file, then copy
one test file and run `scripts/test-logic.sh`. Stop 2 (4.3 to 4.6), the
screens: one new file and two changed, then copy one store test file. No
script changes this time. Then section 5 on the phone.

**Verification (2026-10-21):** the reference iOS build passed with no
warnings. 568/568 logic tests passed in the default zone, New York,
Kolkata, London and Auckland (+24, `PasteScheduleTests`: the web's six
`paste-schedule.test.ts` cases, 17 parity cases whose "web:" values were
printed by the web's own `readPastedSchedule`, `parsePasteRow`, `slotKey`,
`existingSlotKeys` and `buildPastedClasses`, and `PasteSchedule.tsx`'s
preview, in node 24, and one for the row's subscript). 120/120 reference store tests
(+4, `PasteStoreTests`, and the fixed `BackupStoreTests`). The four file
blocks laid over your tree are identical to the reference, and that tree
built with no warnings. Your own suites with the new tests, against the
new source: 568/568 and 132/132. Nothing has been checked
on the phone yet.

## 1. Goal

A timetable you can copy from your school's portal or a spreadsheet goes
straight in, checked by you row by row; and the class form can take your
whole timetable instead of one class.

**On your phone:** Profile tab → IMPORT FROM YOUR SCHOOL → **Paste a
timetable** → **Use example table** → **Review classes** → two Biology
rows, both ticked → **Add selected meetings (2)**. Today's week has one
Biology class meeting Mon and Wed at 9:00 in Science 204, and Thu at 2:00
PM in Lab 3.

This phase includes:

- **Paste a timetable:** a box for cells copied from a portal or a
  spreadsheet (tabs between them) or CSV typed by hand, with or without a
  heading row. Course, Days, Start and End are needed; Room, Teacher and
  Credits are optional.
- **The review:** one card per meeting, every field editable. A meeting
  already on your planner, or one that repeats a row above it, starts
  unticked. A row that can't be read says why, and Add waits until it's
  fixed or unticked.
- **Group by course:** on to start, rows with the same course name become
  one class with several meeting times (a lecture and its lab), up to 20.
- **From the class form:** a new class has **Have your timetable? Paste or
  import it** at the top. It opens the import sheet; once something is
  added, the form closes too.
- **The term question after your first class:** the first class saved into
  an empty, never-asked planner is followed by "When does your semester
  run?", as after a first import (and after a first paste).

## 2. New Swift concepts

### A struct as a Set member: `Hashable`

A `Set` holds each value once and answers "is this in here?" at once, even
with thousands inside. To do that it needs two things from what it holds:
a way to tell two values apart (`==`) and a number to file each one under
(a hash). A struct gets both by saying `Hashable`, when every field is
Hashable already, as Strings, Ints and arrays of them are. Swift writes the
code, field by field:

```swift
struct SlotKey: Hashable {
    let name: String
    let days: [Int]
    let start: Int
}

var seen: Set<SlotKey> = []
seen.insert(SlotKey(name: "biology", days: [0, 2], start: 540)).inserted   // true: new
seen.insert(SlotKey(name: "biology", days: [0, 2], start: 540)).inserted   // false: already there
seen.contains(SlotKey(name: "chem", days: [1], start: 600))               // false
```

`insert` hands back whether the value was new, so one call both checks and
remembers. The same struct can be a Dictionary's key, `[SlotKey: ImportedClass]`.
The web builds a JSON string for each meeting to get a key it can put in a
`Set`; a struct says the same with types. `SlotKey` (4.1) is how the review
spots a meeting that's already on your planner.

### Reaching into a struct inside an array: `rows[i][.days]`

A struct is a value: `var row = rows[i]` makes a copy, and changing `row`
leaves `rows` as it was. To change the one in the array, go through the
array every time:

```swift
var row = rows[0]
row.selected = false          // only the copy changed
rows[0].selected = false      // the row in the array changed
rows[0].selected.toggle()     // the same, flipped
```

A subscript is what square brackets call, and you can write one. `get`
answers a read; `set` handles a write, with the text being written as
`newValue`:

```swift
struct PasteRow {
    var name = ""
    var days = ""

    subscript(column: PasteColumn) -> String {
        get { column == .name ? name : days }
        set { if column == .name { name = newValue } else { days = newValue } }
    }
}

rows[0][.days] = "Mon/Wed"    // through the array, then through the subscript
```

The review's text fields (4.3) each edit one cell of one row this way,
through a `Binding(get:set:)` (5b) on `rows[i][column]`.

### Building only what's on screen: `LazyVStack`

A `VStack` builds every view inside it as soon as it appears. A pasted
timetable can be 200 rows of seven fields, 1,400 text fields, most of them
far below the screen. A `LazyVStack` inside a `ScrollView` builds each piece
only as it scrolls into view:

```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: 16) {
        ForEach(rows.indices, id: \.self) { i in
            RowCard(row: rows[i])
        }
    }
}
```

It lays out like a VStack, so swapping one for the other is the whole
change. The review (4.3) is one.

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `PASTE_COLUMNS`, `PASTE_LABELS`, `PasteRow`, `readPastedSchedule`, `parsePasteRow`, `slotKey`, `existingSlotKeys`, `buildPastedClasses` in `lib/paste-schedule.ts`; the first ticks set by `preview` in `PasteSchedule.tsx` | `Logic/PasteSchedule.swift` |
| `components/PasteSchedule.tsx`, the paste half | `Screens/Import/PasteScheduleView.swift` |
| "Paste a timetable" and the paste's `onDone` in `ImportPanel`; `ImportSheet`'s `onImported` (`components/ImportCalendar.tsx`) | `Screens/Import/ImportView.swift` |
| The import button, `termAction`, `finish` and the `TermSetupSheet` in `components/ClassForm.tsx` | `Screens/Courses/CourseFormView.swift` |

Where the phone differs:

- **The paste box is its own sheet (D-84).** On the web the panel turns
  into the paste box in place. On the phone, Paste a timetable opens a
  full-height sheet over the panel, wherever the panel is, with its buttons
  pinned to the bottom and any problem just above them, so a message about
  row 140 can't be scrolled out of sight. Ticks are round check marks
  (iOS has no checkbox).
- **A long paste is refused, not cut short.** The web's box stops taking
  text at 100,000 characters, so a longer paste loses its end without a
  word. The phone's box takes it all and says "Paste up to 100,000
  characters at a time.", which is what the web's own reader says.
- **One message gets its quotation marks back (D-83).** The web shows
  "?Biology? repeats a meeting…", its curly quotes lost to an encoding
  (web fixes, 9); the phone says "“Biology” repeats a meeting…", like the
  message after it.
- **After an import from the class form, the form closes (D-84),** the
  way Save closes it. The web then opens the week, which on the phone is
  Today; the phone's Save has never switched tabs either.
- **A paste that can't be saved says so,** with 13a's message (D-81).
- **The review of a screenshot or PDF waits for Phase 15:** the web's
  `initialRows`, its page numbers, "Check this" marks and "I checked…"
  boxes ride on the AI server.
- **No XP for a paste or a first class yet:** Phase 12, which is on hold
  (D-79).

Web behavior kept on purpose: every other message, word for word; a tab
anywhere means a tab-separated table; headings are optional, found by the
first column that matches (where a CSV file takes the last), and without
them the order is Course, Days, Start, End, Room, Teacher, Credits; every
word in Days must be a day ("Mon/maybe" is refused, not read as Monday);
lengths counted as the web counts them (an emoji is two); 200 rows at most;
repeats unticked to start, but a ticked repeat is added once rather than
refused; a repeat or a grouped row that disagrees on teacher or credits
stops the add; grouping on to start, by name in any case, up to 20
meetings; every pasted class indigo with a 15-minute alarm (a file's
classes take turns of six colors); nothing said on the Profile card after a
paste, as on the web's Settings; the class form's button only on a new
class; the term question after a first class only on an empty, never-asked
planner with no semester days, with no days suggested.

## 4. Files, in the order to type them

### Stop 1: the logic

One Foundation-only file in `Logic/`. Nothing calls it yet, so the app
builds as before.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/PasteSchedule.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/PasteSchedule.swift
//  Phase:   13b (paste a timetable, and imports from the class form)
//  Ports:   lib/paste-schedule.ts (PASTE_COLUMNS, PASTE_LABELS, PasteRow,
//           readPastedSchedule, parsePasteRow, slotKey, existingSlotKeys,
//           buildPastedClasses), and the first ticks of the review
//           (`preview` in components/PasteSchedule.tsx)
//
//  Summary: Turns a timetable you paste (cells copied from a school portal
//           or a spreadsheet, or typed as CSV) into rows you can check and
//           edit, then into classes. A meeting that's already on your
//           planner, or repeats a row above it, starts unticked. Rows of one
//           course can become one class that meets several times. Nothing is
//           saved here. Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - Columns and rows

/// The seven columns a pasted timetable can have, in the order a table
/// without headings must use. `PASTE_COLUMNS` in lib/paste-schedule.ts.
enum PasteColumn: CaseIterable, Hashable {
    case name, days, start, end, room, instructor, credits

    /// The word over the column's field in the review. `PASTE_LABELS`.
    var label: String {
        switch self {
        case .name:       "Course"
        case .days:       "Days"
        case .start:      "Start"
        case .end:        "End"
        case .room:       "Room"
        case .instructor: "Teacher"
        case .credits:    "Credits"
        }
    }

    /// The headings that mean this column. The web reads a paste and a
    /// schedule CSV with one list (`HEADER_ALIASES`), so these are the CSV's
    /// (Logic/CSVImport.swift, 13a).
    var aliases: [String] {
        switch self {
        case .name:       ScheduleColumn.name.aliases
        case .days:       ScheduleColumn.days.aliases
        case .start:      ScheduleColumn.start.aliases
        case .end:        ScheduleColumn.end.aliases
        case .room:       ScheduleColumn.room.aliases
        case .instructor: ScheduleColumn.instructor.aliases
        case .credits:    ScheduleColumn.credits.aliases
        }
    }
}

/// One row of the pasted table: its seven cells as text you can still edit,
/// and whether it's ticked to be added. `PasteRow` in lib/paste-schedule.ts.
/// (The web's row also carries a page number and "Check this" marks, for a
/// screenshot or PDF read by the AI server: Phase 15.)
struct PasteRow: Equatable {
    var name = ""
    var days = ""
    var start = ""
    var end = ""
    var room = ""
    var instructor = ""
    var credits = ""
    var selected = true

    /// One cell, by its column: `row[.days]` reads it and `row[.days] = "Mon"`
    /// changes it. A subscript is what square brackets call. `get` answers a
    /// read; `set` handles a write, with the text being written as `newValue`.
    /// The web writes `row[c]` because a JavaScript object is a dictionary;
    /// here the fields stay real fields and the subscript picks one.
    subscript(column: PasteColumn) -> String {
        get {
            switch column {
            case .name:       name
            case .days:       days
            case .start:      start
            case .end:        end
            case .room:       room
            case .instructor: instructor
            case .credits:    credits
            }
        }
        set {
            switch column {
            case .name:       name = newValue
            case .days:       days = newValue
            case .start:      start = newValue
            case .end:        end = newValue
            case .room:       room = newValue
            case .instructor: instructor = newValue
            case .credits:    credits = newValue
            }
        }
    }
}

/// Why a paste can't go ahead, in the web's words. Signing up to `Error`
/// lets it be the failure half of a `Result` (Phase 11a), so nothing is
/// thrown and nothing needs catching, where the web throws these messages.
struct PasteProblem: Error, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

// MARK: - Reading the paste

/// The most text read at once. Counted in UTF-16 units, as JavaScript's
/// `length` counts, so an emoji counts two on both apps.
let MAX_PASTE_LENGTH = 100_000

/// The most rows (meetings) read at once.
let MAX_PASTE_ROWS = 200

/// The pasted text as rows, every row ticked, or why it can't be read.
/// `readPastedSchedule`. Only the text you paste is read: no clipboard, no
/// network. Headings are optional; without them the columns go in
/// `PasteColumn` order.
func readPastedSchedule(_ text: String) -> Result<[PasteRow], PasteProblem> {
    // Too much text is refused, not cut short.
    if text.utf16.count > MAX_PASTE_LENGTH {
        return .failure(PasteProblem("Paste up to 100,000 characters at a time."))
    }
    // A tab anywhere means cells copied from a portal or a spreadsheet;
    // otherwise it's CSV. The table reader is the CSV's (13a).
    let delimiter: Unicode.Scalar = text.unicodeScalars.contains("\t") ? "\t" : ","
    let read = parseRows(text.trimmed, delimiter: delimiter)
    // The web reads a paste strictly: a quote left open would swallow the rest.
    if read.unclosedQuote {
        return .failure(PasteProblem("The table has an unfinished quoted cell. Close its quotation mark and try again."))
    }
    guard let first = read.rows.first else {
        return .failure(PasteProblem("Paste a timetable first."))
    }

    // The first row is headings when one of its cells names the course.
    let header = first.map(normalizedHeader)
    let hasHeader = header.contains { PasteColumn.name.aliases.contains($0) }
    // Where each column's cell sits: under the first heading that names it
    // (the CSV takes the last, the paste the first, as on the web), or, with
    // no headings, at its place in the order. `nil` means no such column.
    // `enumerated()` pairs each column with its place: 0, 1, 2...
    let positions: [Int?] = PasteColumn.allCases.enumerated().map { place, column in
        hasHeader ? header.firstIndex(where: { column.aliases.contains($0) }) : place
    }
    // With headings, Course, Days, Start and End (the first four) must be there.
    if hasHeader && positions.prefix(4).contains(nil) {
        return .failure(PasteProblem("Include Course, Days, Start and End columns. You can copy the example below."))
    }
    let data = hasHeader ? Array(read.rows.dropFirst()) : read.rows
    if data.isEmpty {
        return .failure(PasteProblem("The table has headers but no classes."))
    }
    if data.count > MAX_PASTE_ROWS {
        return .failure(PasteProblem("Paste up to 200 meetings at a time."))
    }

    // Each row's cells into their columns; a missing cell stays empty text.
    // `zip` walks two lists side by side: each column with its position.
    let rows = data.map { cells in
        var row = PasteRow()
        for (column, position) in zip(PasteColumn.allCases, positions) {
            if let position, cells.indices.contains(position) {
                row[column] = cells[position].trimmed
            }
        }
        return row
    }
    return .success(rows)
}

// MARK: - Checking a row

/// The words of a Days cell, split the way `parseDays` (13a) splits them:
/// lower case, dots dropped, apart at spaces and , ; / &. The web's
/// `dayTokens` inside `parsePasteRow`.
private func dayTokens(_ value: String) -> [String] {
    value.lowercased()
        .replacing(".", with: "")
        .split(whereSeparator: { $0.isWhitespace || ",;/&".contains($0) })
        .map(String.init)
}

/// One row as a class, or what's wrong with it, checked in the web's order:
/// the name, the days, the times, the room and teacher, then the credits.
/// `parsePasteRow`. Lengths count UTF-16 units, as the web's do. A pasted
/// class is indigo with a 15-minute alarm, as on the web.
func parsePasteRow(_ row: PasteRow) -> Result<ImportedClass, PasteProblem> {
    let name = row.name.trimmed
    if name.isEmpty || row.name.utf16.count > 200 {
        return .failure(PasteProblem("Enter a course name (up to 200 characters)."))
    }
    // Every word in Days must be a day: "Mon/maybe" is refused, not read as
    // Monday alone (which is what `parseDays` on its own would do).
    let tokens = dayTokens(row.days)
    if tokens.isEmpty || tokens.contains(where: { parseDays($0).isEmpty }) {
        return .failure(PasteProblem("Use days such as Mon/Wed, Tue/Thu, Sat or Sun. Expand ambiguous day abbreviations."))
    }
    guard let start = parseTime(row.start), let end = parseTime(row.end), end > start else {
        return .failure(PasteProblem("Enter valid start/end times, with the end after the start (e.g. 9:00 AM, 10:00 AM)."))
    }
    if row.room.utf16.count > 200 || row.instructor.utf16.count > 200 {
        return .failure(PasteProblem("Room and teacher must each be 200 characters or fewer."))
    }

    // Credits: empty, or a number above zero. The web's `Number` ignores
    // spaces around the number, so the trimmed text is read; `Double` takes
    // "1e1", ".5" and "+2" as `Number` does. (`Number` also reads "0b11";
    // no timetable writes credits in binary.)
    var credits: Double? = nil
    if !row.credits.isEmpty {
        guard let value = Double(row.credits.trimmed), value.isFinite, value > 0 else {
            return .failure(PasteProblem("Credits must be greater than zero, or empty."))
        }
        credits = value
    }

    // Blank room or teacher is stored as none.
    let room = row.room.trimmed
    let instructor = row.instructor.trimmed
    return .success(ImportedClass(
        name: name, short: importShortName(name), color: "indigo",
        days: parseDays(row.days), start: start, end: end,
        room: room.isEmpty ? nil : room,
        instructor: instructor.isEmpty ? nil : instructor,
        credits: credits))
}

extension PasteRow {
    /// What's wrong with this row, in words, or nil when it would import.
    /// `if case` (Phase 10a) picks the failure out of the Result.
    var problem: String? {
        if case .failure(let p) = parsePasteRow(self) { return p.message }
        return nil
    }
}

// MARK: - Spotting a repeat

/// What makes two meetings the same, for spotting a repeat: the course name
/// and the room (trimmed, any case), the days in any order, and the times.
/// `slotKey` in lib/paste-schedule.ts writes this as JSON text; a struct
/// says it with types instead.
///
/// `Hashable` is what a Set needs from what it holds, and a Dictionary from
/// its keys: a way to tell two values apart (`==`) and to file one quickly
/// (a hash). Swift writes both for you, field by field, when every field is
/// Hashable itself, as Strings, Ints and arrays of Ints are. (Swift compares
/// text by how it reads, so an é typed as one code or as two counts as the
/// same; JavaScript compares codes. A timetable never mixes the two.)
struct SlotKey: Hashable {
    let name: String
    let days: [Int]
    let start: Int
    let end: Int
    let room: String

    /// Tidies as it builds, so two ways of writing one meeting give one key.
    init(name: String, days: [Int], start: Int, end: Int, room: String?) {
        self.name = name.trimmed.lowercased()
        self.days = days.sorted()
        self.start = start
        self.end = end
        self.room = (room ?? "").trimmed.lowercased()
    }
}

/// A pasted class's meeting as a key. `slotKey(value)` on the web.
func slotKey(_ c: ImportedClass) -> SlotKey {
    SlotKey(name: c.name, days: c.days, start: c.start, end: c.end, room: c.room)
}

/// Every meeting of these classes, main and extra, as keys.
/// `existingSlotKeys` in lib/paste-schedule.ts, which also leaves out
/// deleted and archived classes; here the caller hands in only the ones to
/// count (the store's `activeCourses`). `Schedulable` (5a) knows a class's
/// meetings but not its name, so `name` is a closure that reads it.
func existingSlotKeys<C: Schedulable>(_ classes: [C], name: (C) -> String) -> Set<SlotKey> {
    Set(classes.flatMap { c in
        classMeetings(c).map { m in
            SlotKey(name: name(c), days: m.days, start: m.start, end: m.end, room: m.room)
        }
    })
}

/// The rows as the review first shows them: a meeting already in `existing`,
/// or one that repeats a row above it, starts unticked; a row that can't be
/// read stays ticked, so its problem shows. `preview` in PasteSchedule.tsx.
func reviewRows(_ rows: [PasteRow], existing: Set<SlotKey>) -> [PasteRow] {
    var seen = existing
    return rows.map { row in
        guard case .success(let value) = parsePasteRow(row) else { return row }
        var reviewed = row
        // `insert` answers whether the key was new, so one call both checks
        // the Set and adds to it: new means ticked.
        reviewed.selected = seen.insert(slotKey(value)).inserted
        return reviewed
    }
}

// MARK: - Making the classes

/// The ticked rows as classes to add, or the first reason they can't be.
/// `buildPastedClasses`. A row that repeats an earlier ticked row is added
/// once, unless the two disagree on teacher or credits. With `group` on,
/// rows of one course (the same name, in any case) become one class: the
/// first row its main meeting, each later row an extra one, up to 20.
/// `newID` makes each extra meeting's id; the tests hand in their own.
func buildPastedClasses(_ rows: [PasteRow], group: Bool,
                        newID: () -> UUID = { UUID() }) -> Result<[ImportedClass], PasteProblem> {
    var classes: [ImportedClass] = []
    // Every meeting met so far, by its key, with the class its row made.
    // A Dictionary keyed by a struct: the same Hashable at work.
    var seen: [SlotKey: ImportedClass] = [:]

    for row in rows where row.selected {
        // A ticked row that can't be read stops everything, with its reason.
        let value: ImportedClass
        switch parsePasteRow(row) {
        case .failure(let problem): return .failure(problem)
        case .success(let read): value = read
        }

        // The same meeting again: added once, unless the two disagree.
        let key = slotKey(value)
        if let previous = seen[key] {
            if previous.credits != value.credits || previous.instructor != value.instructor {
                return .failure(PasteProblem("“\(value.name)” repeats a meeting with different teachers or credits. Correct or uncheck the conflicting row."))
            }
            continue
        }
        seen[key] = value

        // The class this row joins, when grouping: the first with its name.
        guard group,
              let index = classes.firstIndex(where: { $0.name.lowercased() == value.name.lowercased() }) else {
            classes.append(value)
            continue
        }
        if classes[index].additionalMeetings.count >= maxMeetings - 1 {
            return .failure(PasteProblem("A subject can have at most \(maxMeetings) meeting times."))
        }
        if classes[index].credits != value.credits || classes[index].instructor != value.instructor {
            return .failure(PasteProblem("“\(value.name)” has different teachers or credits. Correct the rows or turn off grouping."))
        }
        // `classes[index].additionalMeetings.append` changes the class
        // inside the array. A struct is a value: `var subject = classes[index]`
        // would be a copy, and appending to it would leave the array as it was.
        classes[index].additionalMeetings.append(
            ClassMeeting(id: newID(), days: value.days, start: value.start, end: value.end, room: value.room))
    }
    return .success(classes)
}
```

### 4.2 Stop 1 check: the logic tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/PasteScheduleTests.swift Tests/Logic/
scripts/test-logic.sh     # expect 568 tests passing
xtool dev build
```

A failure here points at 4.1. The parity suite compares whole rows and
whole classes with the web's, so a mismatch prints both sides. The likely
spots: a heading found by its last column instead of its first, a
`subscript` case that writes the wrong field, and the curly quotes “ ” in
the two "different teachers or credits" messages (copy them from this
page; a straight " would end the string).

### Stop 2: the screens

The paste sheet, then the panel that opens it, then the class form. The
sheet comes first because the panel shows it.

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Import/PasteScheduleView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/PasteScheduleView.swift
//  Phase:   13b (paste a timetable, and imports from the class form)
//  Ports:   components/PasteSchedule.tsx, the paste half. Its review of a
//           screenshot or PDF read by the AI server (`initialRows`, with the
//           "I checked..." boxes) is Phase 15.
//
//  Summary: Paste your timetable, check it, add it. Cells copied from a school
//           portal or a spreadsheet (or typed as CSV) become one row per
//           meeting, every field still editable. Untick what you don't want,
//           group a course's rows into one class, then Add selected meetings.
//           Nothing is added before that, and the text never leaves the phone.
//           A sheet from the import panel (D-84).
//

import SwiftUI

/// The web's example table, word for word: two Biology meetings, so
/// grouping shows what it does.
private let EXAMPLE_TABLE = "Course\tDays\tStart\tEnd\tRoom\nBiology\tMon/Wed\t9:00 AM\t10:00 AM\tScience 204\nBiology\tThu\t2:00 PM\t4:00 PM\tLab 3"

/// What the empty box shows: the example's first two lines.
private let PASTE_PLACEHOLDER = "Course\tDays\tStart\tEnd\tRoom\nBiology\tMon/Wed\t9:00 AM\t10:00 AM\tScience 204"

/// Every field here that can hold the keyboard: the paste box, or one cell
/// of one row. A case can carry values, as `CourseField.room(id)` does (9b+).
private enum PasteField: Hashable {
    case text
    case cell(Int, PasteColumn)
}

struct PasteScheduleView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Runs once the classes are added, just before the sheet closes, with
    /// whether the term question should follow (read before adding).
    let onAdded: (_ askTerm: Bool) -> Void

    /// The pasted text.
    @State private var text = ""
    /// The rows being checked, empty while you're still pasting. A good
    /// read always has at least one row, so empty means "the paste step".
    @State private var rows: [PasteRow] = []
    /// Why the last Review or Add couldn't go ahead, or nil.
    @State private var error: String? = nil
    /// "Group rows with the same course name", on to start, as on the web.
    @State private var group = true
    /// Set by Add, so a second tap while the sheet closes can't add twice.
    /// The web's `committed` ref.
    @State private var committed = false
    /// Which field has the keyboard, so Done can put it away.
    @FocusState private var focus: PasteField?

    var body: some View {
        let accent = store.profile.accent
        // The meetings already on your planner, to spot repeats.
        let existing = existingSlotKeys(store.activeCourses) { $0.name }

        NavigationStack {
            ScrollView {
                // `LazyVStack` builds each piece only as it scrolls into view,
                // where a VStack builds all of them at once. A paste can be
                // 200 rows of seven fields, so only the few on screen are made.
                LazyVStack(alignment: .leading, spacing: 16) {
                    if rows.isEmpty {
                        pasteStep(accent)
                    } else {
                        reviewIntro(accent)
                        // By index: each row is a struct inside `rows`, so
                        // its fields are changed through `rows[i]` (below).
                        ForEach(rows.indices, id: \.self) { i in
                            rowCard(i, accent, existing)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .keyboardDismissable { focus = nil }
            // The buttons stay at the bottom, as the web's sticky bar does,
            // with any problem just above them where it can't scroll away.
            .safeAreaInset(edge: .bottom) { bar(accent) }
            .navigationTitle("Paste your timetable")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - The two steps

    /// Step one: the box, the example, and what the columns are.
    @ViewBuilder
    private func pasteStep(_ accent: Profile.Accent) -> some View {
        Text("Copy cells from your school portal or spreadsheet. Include Course, Days, Start and End; Room, Teacher and Credits are optional. Tab-separated tables and CSV work here.")
            .font(.system(size: 14))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 8) {
            Text("Timetable text")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
            // A cell copied from a spreadsheet arrives with tabs between the
            // cells. Autocorrect is off, so "MWF" stays "MWF".
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focus, equals: .text)
                .scrollContentBackground(.hidden)
                // A set height, like the web's seven rows: a long paste
                // scrolls inside the box instead of stretching the screen.
                .frame(height: 170)
                // A TextEditor has no placeholder, so one sits on top while
                // it's empty, letting taps through to the box.
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(PASTE_PLACEHOLDER)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.hint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .inputField(accent)
                .accessibilityLabel("Timetable text")
        }

        Button("Use example table") {
            text = EXAMPLE_TABLE
            error = nil
        }
        .font(.system(size: 14, weight: .semibold))
        .buttonStyle(.bordered)
        .tint(Theme.brand(accent))

        Text("Without headers, use this order: Course, Days, Start, End, Room, Teacher, Credits. Your pasted text is processed on this device.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Step two's top: how the review works, and the grouping switch.
    @ViewBuilder
    private func reviewIntro(_ accent: Profile.Accent) -> some View {
        Text("Edit any field before adding. Uncheck rows you do not want. Exact duplicates are initially unchecked; repeated selected rows are added once.")
            .font(.system(size: 14))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)

        Toggle(isOn: $group) {
            Text("Group rows with the same course name into one subject with multiple meetings.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(Theme.brand(accent))

        Text("Grouping applies to these rows. Keep course codes and sections distinct; edit names to combine a lecture and lab belonging to the same subject. To add a meeting to an existing subject, use Edit class.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One row's card: its tick, its seven fields, then what's wrong with it
    /// or that it's already on your planner.
    private func rowCard(_ i: Int, _ accent: Profile.Accent, _ existing: Set<SlotKey>) -> some View {
        let row = rows[i]
        let parsed = parsePasteRow(row)

        return VStack(alignment: .leading, spacing: 10) {
            // The tick. `rows[i].selected.toggle()` changes the row inside
            // the array. A struct is a value, so `var r = rows[i]` would be
            // a copy, and ticking `r` would leave `rows` as it was.
            Button {
                rows[i].selected.toggle()
            } label: {
                Label("Row \(i + 1)", systemImage: row.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(row.selected ? Theme.brand(accent) : Theme.muted)
            .accessibilityAddTraits(row.selected ? .isSelected : [])

            // The course across the card, then the other six two by two.
            cell(i, .name, accent)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                      alignment: .leading, spacing: 8) {
                ForEach(PasteColumn.allCases.filter { $0 != .name }, id: \.self) { column in
                    cell(i, column, accent)
                }
            }

            if case .failure(let problem) = parsed {
                Text(problem.message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .success(let value) = parsed, existing.contains(slotKey(value)) {
                Text("This meeting already exists. Keep it unchecked to avoid adding another copy.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// One field of one row: its name over an editable well.
    private func cell(_ i: Int, _ column: PasteColumn, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(column.label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            TextField(column.label, text: field(i, column))
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focus, equals: .cell(i, column))
                .inputField(accent)
                .accessibilityLabel("Row \(i + 1) \(column.label)")
        }
    }

    /// A binding to one cell of one row, for its text field: `Binding(get:set:)`
    /// (5b) through the index and the row's subscript, so typing changes the
    /// row in `rows` itself. Editing clears the last problem, as on the web.
    /// The index is checked, since Back empties `rows` under the fields.
    private func field(_ i: Int, _ column: PasteColumn) -> Binding<String> {
        Binding(
            get: { rows.indices.contains(i) ? rows[i][column] : "" },
            set: { newText in
                guard rows.indices.contains(i) else { return }
                rows[i][column] = newText
                error = nil
            }
        )
    }

    // MARK: - The buttons

    /// How many rows are ticked.
    private var selectedCount: Int {
        rows.filter(\.selected).count
    }

    /// True when a ticked row can't be read: Add waits until it's fixed or unticked.
    private var anyProblem: Bool {
        rows.contains { $0.selected && $0.problem != nil }
    }

    /// The bar along the bottom: Cancel and Review classes while pasting,
    /// Back and Add selected meetings while checking.
    private func bar(_ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if rows.isEmpty {
                    Button { dismiss() } label: { wide("Cancel") }
                        .buttonStyle(.bordered)
                        .tint(Theme.muted)
                    Button { review() } label: { wide("Review classes") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand(accent))
                } else {
                    // Back keeps the text, so a fix to the paste is one tap away.
                    Button {
                        rows = []
                        error = nil
                    } label: {
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(minWidth: 70, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.muted)
                    Button { add() } label: { wide("Add selected meetings (\(selectedCount))") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand(accent))
                        .disabled(anyProblem || selectedCount == 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    /// A button's text, full width, at least 48 points tall, shrinking a
    /// little rather than cutting off a long count.
    private func wide(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    // MARK: - Doing it

    /// Review classes: the text as rows, repeats unticked, or why it can't
    /// be read. The web's `preview`.
    private func review() {
        focus = nil
        switch readPastedSchedule(text) {
        case .success(let read):
            rows = reviewRows(read, existing: existingSlotKeys(store.activeCourses) { $0.name })
            error = nil
        case .failure(let problem):
            error = problem.message
        }
    }

    /// Add selected meetings: the ticked rows as classes, added in one save,
    /// then the sheet closes. The web's `confirm`, with 13a's message when the
    /// phone can't save (D-81).
    private func add() {
        guard !committed, selectedCount > 0, !anyProblem else { return }
        focus = nil
        switch buildPastedClasses(rows, group: group) {
        case .failure(let problem):
            error = problem.message
        case .success(let classes):
            guard !classes.isEmpty else { return }
            committed = true
            // Asked before adding: adding is what makes the planner non-empty.
            let ask = store.shouldOfferTermSetup
            guard store.importItems(classes, []) else {
                committed = false
                error = "Couldn't save on this device, so nothing was added. Try again."
                return
            }
            onAdded(ask)
            dismiss()
        }
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Import/ImportView.swift` (replaces your 13a file: Paste a timetable, and the sheet's onImported)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/ImportView.swift
//  Phase:   13a (import a calendar or schedule file), changed in 13b (Paste
//           a timetable; the sheet's `onImported`, for the class form)
//  Ports:   components/ImportCalendar.tsx (ImportPanel, ImportCalendar and
//           ImportSheet), the file and paste halves
//
//  Summary: Bringing your schedule over from what your school gives you: a
//           calendar (.ics), a schedule spreadsheet (CSV), or a timetable you
//           paste (13b). It's all read on the phone, and you see what it
//           found before anything is added. One panel worn two ways, as on
//           the web: a card on Profile, and a sheet from Today's first-run
//           card and the class form. The live feed link waits for sign-in
//           (Phase 14), a screenshot or PDF for Phase 15 (D-79).
//

import SwiftUI
import UniformTypeIdentifiers

/// Which kind of file the Files picker is open for.
private enum ImportFileKind {
    case calendar      // a .ics file
    case schedule      // a .csv file

    /// The kinds of file the picker offers. `UTType` names a kind of file
    /// (Phase 11b+c). A .ics is a "calendar event" file; its extension is
    /// named as well, in case an app labels a download only by that.
    var types: [UTType] {
        switch self {
        case .calendar: [.calendarEvent] + [UTType(filenameExtension: "ics")].compactMap { $0 }
        case .schedule: [.commaSeparatedText]
        }
    }
}

/// The biggest file read, 3 MB, as on the web. A real school calendar is
/// far smaller.
private let MAX_IMPORT_BYTES = 3 * 1024 * 1024

/// The panel itself: Paste a timetable and the two upload buttons, then a
/// file's preview and Add. `ImportPanel` in components/ImportCalendar.tsx.
struct ImportPanel: View {
    @Environment(Store.self) private var store

    /// Runs once an import, and the term question after it, are finished.
    /// The sheet passes its own close; on Profile it's nil and the card stays.
    var onDone: (() -> Void)? = nil

    /// The Files picker is open, for `kind`.
    @State private var picking = false
    @State private var kind = ImportFileKind.calendar
    /// Why the last file couldn't be used, or nil.
    @State private var error: String? = nil
    /// What the picked file holds, waiting for Add; nil when there's none.
    @State private var found: ImportResult? = nil
    /// How many items the last import added, for the "Added" line.
    @State private var added: Int? = nil
    /// The term question is showing, with the days the file suggested.
    @State private var askingTerm = false
    @State private var suggestion: TermDateSuggestion? = nil

    // NEW in Phase 13b
    /// The paste sheet is open.
    @State private var pasting = false
    /// What the paste sheet reported: added, and whether the term question
    /// follows. nil when it closed without adding anything.
    @State private var pasteAsk: Bool? = nil

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 12) {
            Text("Upload a calendar (.ics) or schedule CSV from your school. We'll pull out your classes and deadlines, then you review everything before it's added.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("CSV columns: Course, Days, Start, End. Room, Instructor, Credits, and Semester Start/End are optional.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted2)
                .fixedSize(horizontal: false, vertical: true)

            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.danger)
            }
            if let added {
                Text("Added \(added) \(added == 1 ? "item" : "items"), find them on your timetable and in Tasks. 🎉")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.brand(accent))
            }

            // A file waiting to be added shows its preview instead of the buttons.
            if let found {
                preview(found, accent)
            } else {
                // NEW in Phase 13b: first, as on the web.
                Button { paste() } label: { wide("Paste a timetable", size: 14) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand(accent))
                Button { pick(.calendar) } label: { wide("Upload an .ics file", size: 15) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand(accent))
                Button { pick(.schedule) } label: { wide("Upload a schedule CSV", size: 14) }
                    .buttonStyle(.bordered)
                    .tint(Theme.brand(accent))
            }
        }
        // The Files app's picker, for whichever kind was tapped.
        .fileImporter(isPresented: $picking, allowedContentTypes: kind.types) { result in
            if case .success(let url) = result { open(url) }
        }
        // The term question, after the first import into an empty planner.
        // `onDismiss` runs however it closes, so the panel's job ends there.
        .sheet(isPresented: $askingTerm, onDismiss: { onDone?() }) {
            TermSetupSheet(suggestion: suggestion)
        }
        // NEW in Phase 13b: the paste sheet. It reports back before it closes;
        // `afterPaste` runs once it's gone, so the term question can rise next.
        .sheet(isPresented: $pasting, onDismiss: afterPaste) {
            PasteScheduleView { ask in pasteAsk = ask }
        }
    }

    // MARK: - Pieces

    /// A button's text, full width, at least 48 points tall.
    private func wide(_ title: String, size: CGFloat) -> some View {
        Text(title)
            .font(.system(size: size, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    /// What the file holds, in two lines, then Cancel and Add.
    @ViewBuilder
    private func preview(_ result: ImportResult, _ accent: Profile.Accent) -> some View {
        let total = result.classes.count + result.tasks.count
        VStack(alignment: .leading, spacing: 2) {
            Text("Ready to import \(total) \(total == 1 ? "item" : "items")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(counts(result))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 15))

        HStack(spacing: 10) {
            Button { found = nil } label: { wide("Cancel", size: 15) }
                .buttonStyle(.bordered)
                .tint(Theme.muted)
            Button { confirm(result) } label: { wide("Add \(total)", size: 15) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand(accent))
                .disabled(total == 0)
        }
    }

    /// "1 class · 2 assignments · 3 skipped", the skipped part only when
    /// something was.
    private func counts(_ result: ImportResult) -> String {
        let classes = result.classes.count
        let tasks = result.tasks.count
        var line = "\(classes) \(classes == 1 ? "class" : "classes") · \(tasks) \(tasks == 1 ? "assignment" : "assignments")"
        if result.skipped > 0 { line += " · \(result.skipped) skipped" }
        return line
    }

    // MARK: - Doing it

    /// Opens the picker for one kind of file, clearing the last result.
    private func pick(_ which: ImportFileKind) {
        kind = which
        error = nil
        added = nil
        picking = true
    }

    /// Reads the picked file and finds what's in it, or says why not. The
    /// web's `handleFile` and `handleCsvFile`, with their words. A picked file
    /// lives outside the app, so reading it is wrapped in start and stop
    /// (Phase 11b+c); `defer` makes sure the stop happens.
    private func open(_ url: URL) {
        let reading = url.startAccessingSecurityScopedResource()
        defer { if reading { url.stopAccessingSecurityScopedResource() } }
        let calendar = kind == .calendar

        guard let data = try? Data(contentsOf: url) else {
            error = calendar ? "Couldn't read that file. Try another." : "Couldn't read that CSV. Try another schedule export."
            return
        }
        if data.count > MAX_IMPORT_BYTES {
            error = calendar ? "That file is too large to be a calendar." : "That schedule file is too large."
            return
        }
        // The bytes as UTF-8 text. A byte that isn't valid UTF-8 becomes �,
        // as it does when a browser reads the file, rather than failing.
        let text = String(decoding: data, as: UTF8.self)

        if calendar {
            guard text.contains("BEGIN:VCALENDAR") else {
                error = "That file isn't a calendar (.ics) file."
                return
            }
            let result = parseICS(text)
            guard result.classes.count + result.tasks.count > 0 else {
                error = "No classes or deadlines were found in that file."
                return
            }
            found = result
        } else {
            let result = parseCSVSchedule(text)
            guard !result.classes.isEmpty else {
                error = "No classes were found. Include Course, Days, Start, and End columns."
                return
            }
            found = result
        }
    }

    // NEW in Phase 13b
    /// Paste a timetable: opens the paste sheet, clearing the last result.
    private func paste() {
        error = nil
        added = nil
        pasting = true
    }

    // NEW in Phase 13b
    /// After the paste sheet closes: if it added classes, the term question
    /// follows (a paste suggests no days) or the panel is done, as after a
    /// file. Closed without adding, nothing happens. The web says nothing
    /// after a paste, so neither does the card.
    private func afterPaste() {
        guard let ask = pasteAsk else { return }
        pasteAsk = nil
        if ask {
            suggestion = nil
            askingTerm = true
        } else {
            onDone?()
        }
    }

    /// Add: everything in the preview goes in, in one save. Into an empty,
    /// never-asked planner, the term question follows, with the file's days;
    /// otherwise the panel is done. `confirm` in ImportCalendar.tsx.
    private func confirm(_ result: ImportResult) {
        // Asked before adding: adding is what makes the planner non-empty.
        let ask = store.shouldOfferTermSetup
        guard store.importItems(result.classes, result.tasks) else {
            error = "Couldn't save on this device, so nothing was added. Try again."
            return
        }
        added = result.classes.count + result.tasks.count
        found = nil
        if ask {
            suggestion = result.term
            askingTerm = true
        } else {
            onDone?()
        }
    }
}

/// The Profile tab's card around the panel. `ImportCalendar`.
struct ImportCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IMPORT FROM YOUR SCHOOL")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)
            ImportPanel()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// The same panel as a sheet, from the one screen where it matters most:
/// Today with no classes yet, and (13b) the class form. `ImportSheet`. It
/// closes itself once the import (and the term question) are done.
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    // NEW in Phase 13b
    /// Runs when an import finished, just before the sheet closes. The class
    /// form passes "close the form too", as the web's `onImported` leaves it.
    var onImported: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                // CHANGED in Phase 13b: tells the form first, then closes.
                ImportPanel(onDone: {
                    onImported?()
                    dismiss()
                })
                    .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Import your schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift` (replaces your 9b+ file: the import button, the term question, and finish and close moved out of save)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift
//  Phase:   5b (classes: add and edit), changed in 7a (the reminder footer),
//           9b+ (accent fields and keyboard, D-55) and 13b (the import
//           button, and the term question after your first class)
//  Ports:   components/ClassForm.tsx, app/class/new/page.tsx and
//           app/class/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new class, and for editing one. Only a name is
//           required. A class meets at one or more times (MeetingFields), or
//           "Schedule not known yet" saves it with no times. New classes can
//           be saved one after another with "Save & add another". Since
//           9b+ every field wears your accent, and Done or a swipe down puts
//           the keyboard away (the credit hours pad has no return key). Since
//           13b a new class can come from your timetable instead (the import
//           sheet), and your very first class is followed by the term question.
//

import SwiftUI

// NEW in Phase 9b+
/// Every field in the class form that can hold the keyboard. The meetings'
/// label and room fields live in MeetingFields, one pair per meeting, so their
/// cases carry the meeting's id: `.room(id)` is one meeting's room field.
/// An enum case can carry a value like this (5b's sheet enum did the same).
enum CourseField: Hashable {
    case name, instructor, credits, notes
    case label(UUID), room(UUID)
}

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

    // NEW in Phase 13b
    /// The import sheet is open, and whether it added anything (then the
    /// form closes once the sheet has gone).
    @State private var importing = false
    @State private var imported = false
    /// The term question is up after your first class, and whether "Save &
    /// add another" sent it (then the form clears for the next class after).
    @State private var askingTerm = false
    @State private var anotherAfterTerm = false

    // NEW in Phase 9b+: which field has the keyboard, so Done can put it away.
    // MeetingFields gets `$focus` too, so Done also works in a room or label.
    @FocusState private var focus: CourseField?

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
            // NEW in Phase 13b: a new class can come from your timetable.
            if editing == nil {
                Section {
                    Button("Have your timetable? Paste or import it") { importing = true }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .listRowBackground(Theme.brandSoft(accent))
            }

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
                    .focused($focus, equals: .name)     // NEW in Phase 9b+
                    .inputField(accent)                 // NEW in Phase 9b+
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
                // CHANGED in Phase 9b+: MeetingFields shares the form's focus.
                MeetingFields(meetings: $meetings, accent: accent, focus: $focus)
            }

            // MARK: More details
            // CHANGED in Phase 9b+: each field has a focus id and the accent well.
            Section("More details (optional)") {
                TextField("Teacher", text: $instructor)
                    .focused($focus, equals: .instructor)
                    .inputField(accent)
                TextField("Credit hours", text: $credits)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .credits)
                    .inputField(accent)
                TextField("Notes: office hours, what to bring…", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($focus, equals: .notes)
                    .inputField(accent)
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
        // NEW in Phase 9b+: swipe down, or tap Done above the keys.
        .keyboardDismissable { focus = nil }
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
        // NEW in Phase 13b: the import sheet. Once it has gone, having added
        // your timetable, the form closes too, the way Save closes it.
        .sheet(isPresented: $importing, onDismiss: {
            if imported {
                imported = false
                close()
            }
        }) {
            ImportSheet(onImported: { imported = true })
        }
        // NEW in Phase 13b: the term question after your very first class.
        // However it closes (Save, Not now, a swipe), the form carries on.
        .sheet(isPresented: $askingTerm, onDismiss: { finish(another: anotherAfterTerm) }) {
            TermSetupSheet(suggestion: nil)
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

        // NEW in Phase 13b: a first class on an empty, never-asked planner is
        // followed by the term question. Read before adding, since adding is
        // what makes the planner non-empty. `shouldOfferTerm` in ClassForm.tsx.
        let askTerm = editing == nil && store.shouldOfferTermSetup

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

        // CHANGED in Phase 13b: the term question first, when it's due; the
        // form finishes once it closes. Otherwise it finishes now.
        if askTerm {
            anotherAfterTerm = another
            askingTerm = true
        } else {
            finish(another: another)
        }
    }

    // NEW in Phase 13b: moved out of `save`, so the term question can run
    // first. `finish` in ClassForm.tsx.
    /// After a save: ready for the next class, or the form closes.
    private func finish(another: Bool) {
        if another {
            // Clear the subject's own fields; the reminder choice carries over
            // to the next class, which is the point of typing a timetable in a row.
            let savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            name = ""
            draftID = UUID()
            unscheduled = false
            meetings = [newMeeting(primaryMeetingID)]
            color = .indigo
            instructor = ""
            credits = ""
            notes = ""
            added = "\(savedName) added. Ready for the next class."
        } else {
            close()
        }
    }

    // NEW in Phase 13b
    /// Closes the form: the Add menu's whole sheet when it passed `onFinish`,
    /// or just this screen.
    private func close() {
        if let onFinish {
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

### 4.6 Stop 2 check: the store tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Persistence/PasteStoreTests.swift Tests/Store/
scripts/test-store.sh     # expect 132
xtool dev build
```

`scripts/test-store.sh` needs no new word: a paste goes in through 13a's
`importItems`, and the script already copies every `Logic/` file.

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 568
scripts/test-store.sh     # expect 132
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

1. **The button:** Profile tab, IMPORT FROM YOUR SCHOOL. **Paste a
   timetable** is first now, above the two upload buttons. Tap it: the
   sheet "Paste your timetable" rises with the box, **Use example table**,
   and Cancel and Review classes along the bottom.
2. **The example:** tap **Use example table**, then **Review classes**. Two
   cards, Row 1 and Row 2, both ticked, each with Course, Days, Start, End,
   Room, Teacher and Credits. The grouping switch is on. The bottom says
   **Add selected meetings (2)**. Tap it: the sheet closes. On Today,
   Biology is on Mon and Wed at 9:00 and on Thu at 2:00 PM; My Classes has
   one Biology, and its Edit shows both meeting times, Science 204 and
   Lab 3.
3. **Repeats:** Paste a timetable again, Use example table, Review
   classes. Both rows start unticked, each saying "This meeting already
   exists. Keep it unchecked to avoid adding another copy.", and the button
   reads Add selected meetings (0), greyed. **Back**: the text is still in
   the box.
4. **A row with a problem:** Review classes again and tick Row 1: the
   button reads Add selected meetings (1). Change Row 1's Days to
   `Mon/maybe`. Under the row: "Use days such as Mon/Wed, Tue/Thu, Sat or
   Sun. Expand ambiguous day abbreviations.", and Add greys out. Untick
   Row 1 and swipe the sheet down: nothing was added.
5. **Your own timetable:** copy a few rows from a spreadsheet on the phone
   (Numbers, Google Sheets, or Excel: select the cells, Copy) and paste
   them into the box. Copied cells arrive with tabs between them, which is
   the format the box expects; this is the one part that couldn't be tried
   before your phone. A heading row (Course, Days, Start, End) is optional.
   Check the review, untick what you don't want, and add, or swipe down.
6. **From the class form:** + → Class. At the top: **Have your timetable?
   Paste or import it**. Tap it: the "Import your schedule" sheet, with
   Paste a timetable and the two uploads. Upload `classping-sample.csv`
   (13a's sample) and **Add 3**: the import sheet closes and the form
   closes with it. Chemistry (sample), History (sample) and Studio Art
   (sample) are on Today. Delete them, and the example's Biology, from My
   Classes.
7. **Optional, the term question after a first class:** this needs an
   empty planner, so **Back up my data**, then **Clear all data**. On
   Today, tap Add a class manually, name it `Test`, give it a day, and tap
   **Save & add another**. "When does your semester run?" rises halfway.
   Tap **Not now**: the form stays, saying "Test added. Ready for the next
   class.", ready for the next one. Cancel the form. The question won't
   come back after the next class. (A first paste or import into an empty
   planner asks the same question.) Then **Restore a backup** with
   **Replace** to put your real planner back.

Say what you saw, above all step 5 (cells copied from a spreadsheet app)
and whether the sheets in step 6 close together cleanly.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] 568 logic and 132 store tests pass; the tree builds without warnings.
- [ ] The example pastes as one Biology with two meeting times.
- [ ] Pasting it again starts with both rows unticked as repeats.
- [ ] A row that can't be read says why, and Add waits for it.
- [ ] The class form's button imports, and the form closes after.
- [ ] (Optional) Your first class on an empty planner is followed by the
      term question, once.

## 7. If it breaks

- **Cannot find 'readPastedSchedule', 'SlotKey' or 'PasteRow':** 4.1 isn't
  in `Logic/`, or its file name differs.
- **'parseRows', 'normalizedHeader', 'ScheduleColumn' or 'importShortName'
  not found:** those are 13a's (`CSVImport.swift`, `ICSImport.swift`);
  check they're still in `Logic/`.
- **"Type 'SlotKey' does not conform to protocol 'Hashable'":** a field
  that isn't Hashable itself, or a typo in `Hashable`. All five fields are
  Strings, Ints or `[Int]`.
- **"Cannot assign through subscript: 'row' is a 'let' constant":** a
  subscript write needs a `var`. In `readPastedSchedule` it's `var row =
  PasteRow()`; in the screen, `rows` is `@State private var`.
- **Typing in a cell does nothing:** the `set:` half of `field(_:_:)` (4.3)
  must write `rows[i][column] = newText`, through the array.
- **'ImportSheet' has no member 'onImported', or an extra argument
  'onImported':** 4.4's `var onImported` isn't typed yet; 4.5 needs it.
- **The term question never follows a first class:** it only comes for a
  new class on a planner with no classes, never asked before and no
  semester days set. `askTerm` must be read before `addCourse`.

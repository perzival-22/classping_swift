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

//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/CSVImport.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   lib/csv-import.ts (HEADER_ALIASES, parseRows, normalizedHeader,
//           parseDays, parseTime, parseCsvSchedule)
//
//  Summary: Reads the small schedule spreadsheets (CSV) student portals
//           export: a row per class with Course, Days, Start and End, and
//           optionally Room, Instructor, Credits and the semester's dates. The
//           pasted timetable (13b) reuses the table reader, the column names
//           and the day and time readers. Foundation only.
//

import Foundation

// MARK: - Columns

/// The columns a schedule may have, and every heading each one goes by
/// (after `normalizedHeader`). `HEADER_ALIASES` in lib/csv-import.ts.
/// `CaseIterable` gives `ScheduleColumn.allCases`, every case in order.
enum ScheduleColumn: CaseIterable {
    case name, days, start, end, room, instructor, credits, termStart, termEnd

    /// The headings that mean this column, most usual first.
    var aliases: [String] {
        switch self {
        case .name:       ["course", "course name", "course title", "class", "class name", "title"]
        case .days:       ["days", "meeting days", "meeting day", "day"]
        case .start:      ["start", "start time", "meeting start", "class start"]
        case .end:        ["end", "end time", "meeting end", "class end"]
        case .room:       ["room", "location", "meeting location"]
        case .instructor: ["instructor", "teacher", "professor", "faculty"]
        case .credits:    ["credits", "credit", "credit hours", "units"]
        case .termStart:  ["semester start", "term start", "semester begins", "term begins"]
        case .termEnd:    ["semester end", "term end", "semester ends", "term ends"]
        }
    }
}

// MARK: - The table

/// The cells of a CSV (or, with `delimiter: "\t"`, a tab-separated table),
/// row by row, each cell trimmed, empty rows dropped. `parseRows`.
/// A cell in quotes may hold commas and line breaks; "" inside quotes is one
/// quote mark. `unclosedQuote` is true when the text ends inside quotes: the
/// web's strict mode refuses that, and so does the paste box (13b).
///
/// It walks the text one scalar at a time (see `textLines` for why not one
/// Character), by position, so it can look one ahead for "" and "\r\n".
/// A tuple, `(rows: ..., unclosedQuote: ...)`, hands back two things at once.
func parseRows(_ csv: String, delimiter: Unicode.Scalar = ",") -> (rows: [[String]], unclosedQuote: Bool) {
    let scalars = Array(csv.unicodeScalars)
    var rows: [[String]] = []
    var row: [String] = []
    var value = String.UnicodeScalarView()
    var quoted = false
    var i = 0

    // A row counts only if some cell in it has something.
    func endRow() {
        row.append(String(value).trimmed)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        row = []
        value = String.UnicodeScalarView()
    }

    while i < scalars.count {
        let c = scalars[i]
        let next: Unicode.Scalar? = i + 1 < scalars.count ? scalars[i + 1] : nil
        if c == "\"" {
            // "" inside quotes is a quote mark; any other quote opens or closes.
            if quoted && next == "\"" {
                value.append("\"")
                i += 1
            } else {
                quoted.toggle()
            }
        } else if c == delimiter && !quoted {
            row.append(String(value).trimmed)
            value = String.UnicodeScalarView()
        } else if (c == "\n" || c == "\r") && !quoted {
            // "\r\n" is one line break, not two.
            if c == "\r" && next == "\n" { i += 1 }
            endRow()
        } else {
            value.append(c)
        }
        i += 1
    }
    endRow()
    return (rows, quoted)
}

/// A heading as the aliases spell it: no byte-order mark, trimmed, lower
/// case, "_" and "-" as spaces, one space at a time. `normalizedHeader`.
func normalizedHeader(_ value: String) -> String {
    var v = value
    if v.unicodeScalars.first == "\u{FEFF}" { v = String(v.unicodeScalars.dropFirst()) }
    return v.trimmed.lowercased()
        .replacing(/[_-]+/, with: " ")
        .replacing(/\s+/, with: " ")
}

/// Where each heading sits in the first row. A heading used twice points at
/// its last column, as the web's `new Map(...)` does.
func headerColumns(_ header: [String]) -> [String: Int] {
    Dictionary(header.enumerated().map { (normalizedHeader($0.element), $0.offset) },
               uniquingKeysWith: { _, later in later })
}

/// One row's cell for a column, by the first alias the table has, or "".
/// `lookup` in lib/csv-import.ts.
private func lookup(_ row: [String], _ columns: [String: Int], _ column: ScheduleColumn) -> String {
    guard let index = column.aliases.compactMap({ columns[$0] }).first,
          row.indices.contains(index) else { return "" }
    return row[index].trimmed
}

// MARK: - Days and times

/// Every way a day is written, in lower case, as ClassPing's day number.
/// R is Thursday, the registrar's way of keeping it apart from Tuesday.
private let DAY_WORDS: [String: Int] = [
    "m": 0, "mo": 0, "mon": 0, "monday": 0,
    "t": 1, "tu": 1, "tue": 1, "tues": 1, "tuesday": 1,
    "w": 2, "we": 2, "wed": 2, "wednesday": 2,
    "r": 3, "th": 3, "thu": 3, "thur": 3, "thurs": 3, "thursday": 3,
    "f": 4, "fr": 4, "fri": 4, "friday": 4,
    "sa": 5, "sat": 5, "saturday": 5,
    "su": 6, "sun": 6, "sunday": 6,
]

/// "Mon, Wed", "MWF" or "TR" as days, Monday first. `parseDays`.
/// Anything it can't read is left out, so the result may be empty.
func parseDays(_ value: String) -> [Int] {
    var days = Set<Int>()
    let tokens = value.lowercased()
        .replacing(".", with: "")
        .split(whereSeparator: { $0.isWhitespace || ",;/&".contains($0) })
    for token in tokens {
        let word = String(token)
        if let day = DAY_WORDS[word] {
            days.insert(day)
        } else {
            // Run-together letters: "mwf", or "tth" (Tue and Thu) as "tr".
            let compact = word.replacing("th", with: "r")
            if compact.wholeMatch(of: /[mtwrf]+/) != nil {
                for letter in compact {
                    if let day = DAY_WORDS[String(letter)] { days.insert(day) }
                }
            }
        }
    }
    return days.sorted()
}

/// "9:00 AM", "2 PM", "13:45" or "9" as minutes from midnight, or nil.
/// `parseTime`. With AM or PM the hour must be 1 to 12; without, 0 to 23.
func parseTime(_ value: String) -> Int? {
    guard let m = value.trimmed.wholeMatch(of: /([0-9]{1,2})(?::([0-9]{2}))?\s*(a\.?(?:m)?\.?|p\.?(?:m)?\.?)?/.ignoresCase()),
          var hour = Int(m.1) else { return nil }
    // `m.2` and `m.3` are optional: those brackets may have matched nothing.
    let minute = m.2.flatMap { Int($0) } ?? 0
    if minute > 59 { return nil }
    if let suffix = m.3 {
        let half = suffix.replacing(".", with: "").lowercased()
        if hour < 1 || hour > 12 { return nil }
        if half.hasPrefix("p") && hour != 12 { hour += 12 }
        if half.hasPrefix("a") && hour == 12 { hour = 0 }
    } else if hour > 23 {
        return nil
    }
    return hour * 60 + minute
}

/// A semester date written "2026-08-31" or "08/31/2026" (month first), as
/// "yyyy-MM-dd", or nil when it isn't a real day. `parseDate`. The web's check
/// builds a JavaScript date, which can't hold a year below 100, so neither
/// does this; `isValidDate` (Phase 2) catches days like February 30.
func parseScheduleDate(_ value: String) -> String? {
    let v = value.trimmed
    var year = 0, month = 0, day = 0
    if let m = v.wholeMatch(of: /([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})/) {
        year = Int(m.1) ?? 0; month = Int(m.2) ?? 0; day = Int(m.3) ?? 0
    } else if let m = v.wholeMatch(of: /([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})/) {
        year = Int(m.3) ?? 0; month = Int(m.1) ?? 0; day = Int(m.2) ?? 0
    }
    guard year >= 100 else { return nil }
    let iso = String(format: "%04d-%02d-%02d", year, month, day)
    return isValidDate(iso) ? iso : nil
}

// MARK: - The whole file

/// A schedule CSV as import candidates: classes only (a CSV has no
/// deadlines), and the semester from the first class row when it has one.
/// `parseCsvSchedule` in lib/csv-import.ts.
func parseCSVSchedule(_ csv: String, limit: Int = 200) -> ImportResult {
    let rows = parseRows(csv).rows
    var result = ImportResult()
    // A heading row and at least one class, or there's nothing to import.
    guard rows.count >= 2 else { return result }
    let columns = headerColumns(rows[0])

    // `where` on a `for` loop skips the rows it rules out, so once the cap is
    // reached the rest are passed over without a `break`.
    for row in rows.dropFirst() where result.classes.count < limit {
        let name = lookup(row, columns, .name)
        let days = parseDays(lookup(row, columns, .days))
        // A class needs a name, a day, and an end after its start.
        if let start = parseTime(lookup(row, columns, .start)),
           let end = parseTime(lookup(row, columns, .end)),
           !name.isEmpty, !days.isEmpty, end > start {
            let room = lookup(row, columns, .room)
            let instructor = lookup(row, columns, .instructor)
            // Credits only when they're a real number above zero.
            let credits = Double(lookup(row, columns, .credits)).flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            result.classes.append(ImportedClass(
                name: name, short: importShortName(name),
                color: IMPORT_COLORS[result.classes.count % IMPORT_COLORS.count],
                days: days, start: start, end: end,
                room: room.isEmpty ? nil : room,
                instructor: instructor.isEmpty ? nil : instructor,
                credits: credits))
        } else {
            result.skipped += 1
        }
    }

    // The semester dates are read from the first class row only.
    if let start = parseScheduleDate(lookup(rows[1], columns, .termStart)) {
        result.term = TermDateSuggestion(start: start,
                                         end: parseScheduleDate(lookup(rows[1], columns, .termEnd)))
    }
    // A CSV is a snapshot with no ids, so it never cancels anything.
    return result
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ICSImport.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   lib/ics-import.ts (parseIcs, ImportResult, TermDateSuggestion and
//           their helpers). Its planImport, the free plan's class ceiling,
//           stays on the web: the phone has no plans (D-80).
//
//  Summary: Reads a school calendar file (.ics) into classes and assignments
//           for you to check before anything is added. A weekly repeating
//           event becomes a class; a one-off event becomes an assignment due
//           when it starts (an exam, if its title says so). Nothing is saved
//           here. Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - What an import finds

/// A class an import found, before it becomes a Course. Logic/ can't see the
/// Course model (the Linux tests compile this folder on its own), so this
/// holds the web's fields in plain types, and the store turns it into a
/// Course when you confirm (Store+Import.swift). The web's
/// `Omit<ClassItem, "id">`.
struct ImportedClass: Equatable {
    var name: String
    var short: String
    var color: String                 // a SubjectColor name, like "indigo"
    var days: [Int]                   // 0 = Monday ... 6 = Sunday
    var start: Int                    // minutes from midnight
    var end: Int
    var remindBefore = 15             // every import asks for 15 minutes
    var alarm = true
    var room: String? = nil
    var instructor: String? = nil
    var credits: Double? = nil
    /// The calendar's own id for the event (its UID), kept so a later feed
    /// refresh (Phase 14) can tell a moved lecture from a new one.
    var sourceUID: String? = nil
    /// Extra meeting times. Only a pasted timetable fills these (13b).
    var additionalMeetings: [ClassMeeting] = []
}

/// An assignment an import found, before it becomes an Assignment. Always
/// unfiled (the store files it, see `importItems`) and always with its
/// reminder on, as on the web.
struct ImportedTask: Equatable {
    var title: String
    var due: String?                  // "yyyy-MM-dd"
    var dueTime: String?              // "HH:mm", or nil for all-day
    var kind: String                  // "exam" or "assignment"
    var sourceUID: String? = nil
}

/// The semester an import suggests, for you to confirm (the term setup
/// sheet). `TermDateSuggestion`. Never written without your say-so.
struct TermDateSuggestion: Equatable {
    /// The first weekly class's first day, "yyyy-MM-dd".
    var start: String
    /// The weekly rule's last day, or else the latest dated item; nil when
    /// the file never says.
    var end: String?
}

/// Everything one file produced. `ImportResult` in lib/ics-import.ts.
struct ImportResult: Equatable {
    var classes: [ImportedClass] = []
    var tasks: [ImportedTask] = []
    /// Events understood but left out (cancelled, moved, past, unreadable).
    var skipped = 0
    /// UIDs the calendar marked cancelled, each once. Phase 14's feed
    /// refresh uses them; a file import only counts them as skipped.
    var cancelled: [String] = []
    var term: TermDateSuggestion? = nil
}

/// The colors imported classes take in turn, so they don't all arrive the
/// same. `COLORS` in lib/ics-import.ts and lib/csv-import.ts (one list here).
let IMPORT_COLORS = ["indigo", "coral", "teal", "amber", "violet", "ocean"]

// MARK: - Small text helpers

extension String {
    /// The text without spaces, tabs or line breaks at either end, like
    /// JavaScript's `trim()`, which also drops the invisible byte-order mark
    /// (U+FEFF) some spreadsheet apps put at the very start of a file.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
    }
}

/// The text's lines, split exactly where the web's `split(/\r?\n/)` splits.
///
/// Why not `split(separator: "\n")`? In Swift a `Character` is what you'd
/// call one letter, and the Windows line ending "\r\n" counts as ONE
/// Character, which is neither "\n" nor "\r". A calendar file uses "\r\n",
/// so splitting on "\n" would hand back the whole file as one line.
/// `unicodeScalars` is the same text as its separate code points, where
/// "\r" and "\n" are two. `String.UnicodeScalarView` is that list, which can
/// grow one scalar at a time and turn back into a String.
func textLines(_ text: String) -> [String] {
    var lines: [String] = []
    var line = String.UnicodeScalarView()
    for scalar in text.unicodeScalars {
        if scalar == "\n" {
            // The "\r" of a "\r\n" ending isn't part of the line.
            if line.last == "\r" { line.removeLast() }
            lines.append(String(line))
            line = String.UnicodeScalarView()
        } else {
            line.append(scalar)
        }
    }
    lines.append(String(line))
    return lines
}

/// The first word of a name, at most 5 characters, or "Class": the short code
/// grid blocks show ("Organic Chemistry" -> "Organ"). The web cuts at 5 UTF-16
/// units (`slice(0, 5)`), so this does too, as Phase 9a's letter grades do.
func importShortName(_ name: String) -> String {
    let word = name.trimmed.split(whereSeparator: \.isWhitespace).first ?? ""
    let cut = String(decoding: Array(word.utf16.prefix(5)), as: UTF16.self)
    return cut.isEmpty ? "Class" : cut
}

/// True when a title names an exam: exam, midterm, final, test or quiz as a
/// word, in any case. `EXAM_RE` in lib/ics-import.ts.
///
/// `/.../` is a Swift regex literal, checked as the app builds, so a typo in
/// the pattern is a build error rather than a crash. Swift's defaults are
/// wider than JavaScript's: there `\b` sees only A-Z, a-z, 0-9 and _ as word
/// letters, so "Examé" still counts. `.asciiOnlyWordCharacters()` and a
/// `.simple` word boundary ask Swift for the same rule.
func isExamTitle(_ title: String) -> Bool {
    title.contains(/\b(exam|midterm|final|test|quiz)\b/
        .ignoresCase()
        .asciiOnlyWordCharacters()
        .wordBoundaryKind(.simple))
}

// MARK: - Reading the file's lines

/// One line of a calendar, split into its parts: DTSTART;TZID=America/New_York:20260810T090000
/// is the name "DTSTART", the parameter TZID and the value after the colon.
struct ICSProperty {
    let name: String
    let params: [String: String]
    let value: String
}

/// Undoes the calendar's escapes: \n, \, \; and \\. `unescape`. Done one after
/// another, exactly as the web does, so both apps read any title the same.
func icsUnescape(_ v: String) -> String {
    v.replacing(/\\n/.ignoresCase(), with: "\n")
        .replacing("\\,", with: ",")
        .replacing("\\;", with: ";")
        .replacing("\\\\", with: "\\")
}

/// The file's records: a line that starts with a space or a tab continues the
/// one before it (calendars fold long lines at 75 characters). `unfold`.
private func unfold(_ ics: String) -> [String] {
    var out: [String] = []
    for line in textLines(ics) {
        let first = line.unicodeScalars.first
        if (first == " " || first == "\t") && !out.isEmpty {
            // Drop that one space and join the rest on.
            out[out.count - 1] += String(line.unicodeScalars.dropFirst())
        } else {
            out.append(line)
        }
    }
    return out
}

/// Splits one record into name, parameters and value, or nil when it has no
/// colon. `parseProp`. Names and parameter names are read in capitals.
private func parseProperty(_ line: String) -> ICSProperty? {
    guard let colon = line.firstIndex(of: ":") else { return nil }
    let head = line[..<colon]
    let value = String(line[line.index(after: colon)...])
    // `omittingEmptySubsequences: false` keeps empty pieces, as JavaScript's
    // `split` does, so the parameters stay where they were.
    let parts = head.split(separator: ";", omittingEmptySubsequences: false)
    var params: [String: String] = [:]
    for part in parts.dropFirst() {
        if let eq = part.firstIndex(of: "=") {
            params[part[..<eq].uppercased()] = String(part[part.index(after: eq)...])
        }
    }
    return ICSProperty(name: (parts.first ?? "").uppercased(), params: params, value: value)
}

/// A date or date-time from the file: the moment, whether it's all-day, and
/// its time as minutes from midnight. `ParsedDate`.
struct ICSDate {
    let date: Date
    let allDay: Bool
    let mins: Int
}

/// A local date from numbers, rolling over the way JavaScript's
/// `new Date(y, m - 1, d, h, min)` does: month 13 is next January, and a time
/// that doesn't exist (the hour clocks skip in spring) moves forward.
private func localDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date? {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.autoupdatingCurrent.date(from: c)
}

/// Reads a DTSTART, DTEND or UNTIL value, or nil when it isn't a date.
/// `parseIcsDate`. The clock time is read as YOUR local time and any time zone
/// is ignored, as on the web: a student importing their own school's
/// calendar wants their own clock, and classes are stored without a zone.
///
/// `wholeMatch(of:)` succeeds only when the pattern covers the whole text
/// (the web's `^...$`); `prefixMatch(of:)` only needs the start (`^...`).
/// The result's `.1`, `.2` ... are the parts in brackets, as Substrings.
/// `[0-9]` and not `\d`: in Swift `\d` also takes other scripts' digits.
func parseICSDate(_ prop: ICSProperty) -> ICSDate? {
    let v = prop.value.trimmed

    // All-day: just eight digits, or anything marked VALUE=DATE.
    let dateOnly = v.wholeMatch(of: /([0-9]{4})([0-9]{2})([0-9]{2})/)
    if dateOnly != nil || prop.params["VALUE"] == "DATE" {
        guard let m = dateOnly ?? v.prefixMatch(of: /([0-9]{4})([0-9]{2})([0-9]{2})/),
              let date = localDate(Int(m.1) ?? 0, Int(m.2) ?? 0, Int(m.3) ?? 0) else { return nil }
        return ICSDate(date: date, allDay: true, mins: 0)
    }

    // Timed: 20260810T090000, with anything after the seconds (a Z) ignored.
    guard let m = v.prefixMatch(of: /([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})/) else {
        return nil
    }
    let hh = Int(m.4) ?? 0
    let mm = Int(m.5) ?? 0
    guard let date = localDate(Int(m.1) ?? 0, Int(m.2) ?? 0, Int(m.3) ?? 0, hh, mm) else { return nil }
    return ICSDate(date: date, allDay: false, mins: hh * 60 + mm)
}

/// The later of two dates, either of which may be missing. `laterDate`.
private func laterDate(_ current: Date?, _ candidate: Date?) -> Date? {
    guard let candidate else { return current }
    guard let current else { return candidate }
    return candidate > current ? candidate : current
}

/// The UNTIL day inside a repeat rule, if it has one. `recurrenceUntil`.
private func recurrenceUntil(_ rrule: String) -> Date? {
    guard let m = rrule.firstMatch(of: /(?:^|;)UNTIL=([^;]+)/.ignoresCase()) else { return nil }
    return parseICSDate(ICSProperty(name: "UNTIL", params: [:], value: String(m.1)))?.date
}

/// The calendar's two-letter day codes as ClassPing's days, Monday = 0.
private let BYDAY_TO_INDEX = ["MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6]

/// The days a weekly event meets, Monday first. `recurringDays`. With no
/// BYDAY list, a weekly event repeats on the weekday it starts.
private func recurringDays(_ rrule: String, _ start: ICSDate) -> [Int] {
    guard let byday = rrule.firstMatch(of: /BYDAY=([^;]+)/.ignoresCase()) else {
        return [dayIndex(of: start.date)]
    }
    let days = byday.1
        .split(separator: ",", omittingEmptySubsequences: false)
        // "2MO" (the second Monday) is still a Monday: drop the number.
        .map { String($0).replacing(/^[+-]?[0-9]+/, with: "").uppercased() }
        .compactMap { BYDAY_TO_INDEX[$0] }
    // A Set drops repeats; sorting puts Monday first.
    return Set(days).sorted()
}

// MARK: - One event at a time

/// What one VEVENT turned out to be. Each case carries what the loop in
/// `parseICS` needs from it.
private enum ICSEvent {
    /// Understood but left out.
    case skipped
    /// Marked cancelled. The uid is "" when the event had none.
    case cancelled(uid: String)
    /// A weekly class (still without its color), when it first meets, and the
    /// rule's last day if it says.
    case weekly(ImportedClass, firstMeeting: Date, until: Date?)
    /// A one-off assignment, when it starts, and when it ends if it says.
    case oneOff(ImportedTask, start: Date, end: Date?)
}

/// Decides what one event is. The middle of the web's loop in `parseIcs`.
private func readEvent(_ props: [ICSProperty], now: Date) -> ICSEvent {
    // The first property with a name, like the web's `by(name)`.
    func prop(_ name: String) -> ICSProperty? {
        props.first(where: { $0.name == name })
    }
    let uid = prop("UID")?.value.trimmed ?? ""

    // The school withdrew it. Noted, so a feed refresh can offer to remove it.
    if prop("STATUS")?.value.trimmed.uppercased() == "CANCELLED" {
        return .cancelled(uid: uid)
    }
    // One week of a series, moved. ClassPing keeps a weekly pattern, so there
    // is nowhere to put it, and importing it would make a fake assignment
    // named after your lecture.
    if prop("RECURRENCE-ID") != nil { return .skipped }

    // It needs a title and a start.
    guard let summary = prop("SUMMARY"), let dtstart = prop("DTSTART") else { return .skipped }
    let title = icsUnescape(summary.value).trimmed
    guard !title.isEmpty, let start = parseICSDate(dtstart) else { return .skipped }

    let rrule = prop("RRULE")?.value ?? ""
    let end = parseICSDate(prop("DTEND") ?? dtstart)

    // A timed event that repeats weekly is a class.
    if rrule.contains(/FREQ=WEEKLY/.ignoresCase()) && !start.allDay {
        let days = recurringDays(rrule, start)
        if days.isEmpty { return .skipped }
        // An hour long unless the file gives a later end.
        var endMins = start.mins + 60
        if let end, end.mins > start.mins { endMins = end.mins }
        let room = prop("LOCATION").map { icsUnescape($0.value).trimmed } ?? ""
        let course = ImportedClass(name: title, short: importShortName(title), color: "",
                                   days: days, start: start.mins, end: endMins,
                                   room: room.isEmpty ? nil : room,
                                   sourceUID: uid.isEmpty ? nil : uid)
        // A weekly rule's UNTIL is its real last day. Without one, DTEND is
        // only the end of the first meeting, so it says nothing about the term.
        return .weekly(course, firstMeeting: start.date, until: recurrenceUntil(rrule))
    }

    // Anything else is a one-off deadline. More than a day in the past is
    // left out, so an old calendar doesn't fill Tasks with dead deadlines.
    if start.date < now.addingTimeInterval(-86_400) { return .skipped }
    // All-day stays all-day; a timed one keeps its time.
    let task = ImportedTask(title: title, due: dayOf(start.date),
                            dueTime: start.allDay ? nil : timeOf(start.date),
                            kind: isExamTitle(title) ? "exam" : "assignment",
                            sourceUID: uid.isEmpty ? nil : uid)
    return .oneOff(task, start: start.date, end: end?.date)
}

// MARK: - The whole file

/// Reads calendar text into import candidates. `parseIcs` in lib/ics-import.ts.
/// `now` decides what's in the past (tests pass their own); `limit` caps how
/// much one file can add.
func parseICS(_ ics: String, now: Date = .now, limit: Int = 200) -> ImportResult {
    var result = ImportResult()
    var colorIndex = 0
    var firstWeeklyStart: Date? = nil
    var latestDate: Date? = nil
    var inEvent = false
    var props: [ICSProperty] = []

    // Collect each event's lines between BEGIN and END, then read it.
    for line in unfold(ics) {
        if line == "BEGIN:VEVENT" {
            inEvent = true
            props = []
        } else if line == "END:VEVENT" {
            inEvent = false
            // Once the cap is reached, later events are passed over uncounted.
            if result.classes.count + result.tasks.count < limit {
                // `case .weekly(var course, ...)` binds the class as a `var`,
                // so its color can be filled in right here.
                switch readEvent(props, now: now) {
                case .skipped:
                    result.skipped += 1
                case .cancelled(let uid):
                    result.skipped += 1
                    if !uid.isEmpty && !result.cancelled.contains(uid) {
                        result.cancelled.append(uid)
                    }
                case .weekly(var course, let first, let until):
                    course.color = IMPORT_COLORS[colorIndex % IMPORT_COLORS.count]
                    colorIndex += 1
                    result.classes.append(course)
                    firstWeeklyStart = min(firstWeeklyStart ?? first, first)
                    latestDate = laterDate(latestDate, until)
                case .oneOff(let task, let start, let end):
                    result.tasks.append(task)
                    // One-off items mark the term's end when the weekly rules
                    // don't (a final in December).
                    latestDate = laterDate(laterDate(latestDate, start), end)
                }
            }
        } else if inEvent, let prop = parseProperty(line) {
            props.append(prop)
        }
    }

    // The suggested term: from the first weekly class to the latest date,
    // when that's not before the start.
    if let first = firstWeeklyStart {
        let end = latestDate.flatMap { $0 >= first ? dayOf($0) : nil }
        result.term = TermDateSuggestion(start: dayOf(first), end: end)
    }
    return result
}

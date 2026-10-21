//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/CalendarExport.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/calendar.ts (buildCalendarFile and its helpers)
//
//  Summary: Writes your timetable and open deadlines as an iCalendar (.ics)
//           file, the format every calendar app can import. Each class repeats
//           weekly inside the term, with its alarms; each dated piece of open
//           work gets an event, and a warning if its reminder is on. Times are
//           "floating" (no time zone), so a calendar reads them as local time.
//           Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - What goes in

/// A class the calendar file can describe. It builds on `Alarmable` (7a),
/// which already gives the name, the alarm switch, `remindBefore` and the
/// meetings, and adds the three details the file writes. `Course` signs up
/// in Models+Reminders.swift. Open work needs nothing new: `Remindable` (7a)
/// already has the title, deadline, kind, `done` and `reminder`.
protocol CalendarClass: Alarmable {
    var instructor: String? { get }
    var notes: String? { get }
    var extraReminders: [Int] { get }
}

/// The semester as two "yyyy-MM-dd" days, either of which may be missing.
/// `TermWindow` in lib/calendar.ts. A half-set term still bounds its half.
struct TermWindow: Equatable {
    var start: String?
    var end: String?
}

// MARK: - Building the file

/// The whole .ics file as text. `buildCalendarFile`. `className` names the
/// class a piece of work belongs to (nil for Inbox work), `now` is "today"
/// for the weekly rules and the file's stamp, and `term` stops the
/// timetable at the end of the semester.
func buildCalendarFile<C: CalendarClass, T: Remindable>(
    _ classes: [C], _ tasks: [T], className: (UUID?) -> String?,
    now: Date, term: TermWindow? = nil
) -> String {
    // When the file was made, in UTC: "20261021T030405Z". Every event carries it.
    let stamp = utcStamp(now)
    let range = termRange(term)

    // The header every calendar file starts with.
    var lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//ClassPing//Timetable//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-CALNAME:ClassPing",
    ]
    // One weekly event per meeting (a lab is its own event), then one event
    // per open, dated piece of work. Each helper gives back no lines for
    // something that doesn't belong in the file, so nothing is skipped by hand.
    for slot in expandClassMeetings(classes) {
        lines += classEvent(slot, stamp: stamp, now: now, range: range)
    }
    for task in tasks {
        lines += taskEvent(task, stamp: stamp, className: className)
    }
    lines.append("END:VCALENDAR")

    // Long lines folded, every line ended with CR LF, as RFC 5545 asks.
    return lines.map(foldICS).joined(separator: "\r\n") + "\r\n"
}

/// The lines for one meeting of one class, or none: none when it meets on
/// no day, or when the whole term is already behind us.
private func classEvent<C: CalendarClass>(
    _ slot: MeetingSlot<C>, stamp: String, now: Date, range: (from: Date?, until: Date?)?
) -> [String] {
    let c = slot.course
    let m = slot.meeting
    guard !m.days.isEmpty else { return [] }

    // Start at the first meeting inside the term: its opening week before
    // the semester begins, otherwise from today.
    let anchor = range?.from.flatMap { $0 > now ? $0 : nil } ?? now
    let start = nextMeeting(m.days, m.start, after: anchor)
    if let until = range?.until, start > until { return [] }
    let end = atMinute(start, m.end)

    // "MO,WE". `byDay.indices.contains` keeps a bad day number from crashing.
    let byday = m.days.sorted()
        .filter { byDay.indices.contains($0) }
        .map { byDay[$0] }
        .joined(separator: ",")
    // UNTIL is floating local time, like DTSTART: RFC 5545 wants the two to
    // agree, and a UTC "Z" here could add or drop the last week.
    let until = range?.until.map { ";UNTIL=\(icsLocal($0))" } ?? ""

    // The meeting's key, lower case, so the UID is the one the web writes
    // for the same class: re-importing then updates instead of duplicating.
    var lines = [
        "BEGIN:VEVENT",
        "UID:classping-class-\(meetingKey(slot).lowercased())@classping",
        "DTSTAMP:\(stamp)",
        "DTSTART:\(icsLocal(start))",
        "DTEND:\(icsLocal(end))",
        "RRULE:FREQ=WEEKLY;BYDAY=\(byday)\(until)",
        "SUMMARY:\(escapeICS(c.name))",
    ]
    // The room becomes a tappable place on the phone. An empty one is none.
    if let room = m.room, !room.isEmpty {
        lines.append("LOCATION:\(escapeICS(room))")
    }
    // The teacher and your notes about the class, on two lines of one field.
    let detail = [c.instructor.flatMap { $0.isEmpty ? nil : "With \($0)" },
                  c.notes.flatMap { $0.isEmpty ? nil : $0 }]
        .compactMap { $0 }
    if !detail.isEmpty {
        lines.append("DESCRIPTION:\(escapeICS(detail.joined(separator: "\n")))")
    }
    // One alarm per distinct lead time, the earliest heads-up first.
    // `Set` drops a lead given twice; `sorted(by: >)` puts the biggest first.
    if c.alarm {
        for mins in Set([c.remindBefore] + c.extraReminders).sorted(by: >) {
            lines += [
                "BEGIN:VALARM",
                "ACTION:DISPLAY",
                "TRIGGER:-PT\(mins)M",
                "DESCRIPTION:\(escapeICS("\(c.name) starts in \(alarmLead(mins))"))",
                "END:VALARM",
            ]
        }
    }
    lines.append("END:VEVENT")
    return lines
}

/// The lines for one piece of work, or none when it's done or has no day
/// (Inbox work has nowhere to go on a calendar).
private func taskEvent<T: Remindable>(
    _ t: T, stamp: String, className: (UUID?) -> String?
) -> [String] {
    guard !t.done, let due = dueAt(t) else { return [] }
    let isExam = t.kindName == "exam"
    // An exam blocks out a sitting; anything else is a short marker.
    let end = due.addingTimeInterval(Double(isExam ? 90 : 30) * 60)

    var lines = [
        "BEGIN:VEVENT",
        "UID:classping-task-\(webID(t.id))@classping",
        "DTSTAMP:\(stamp)",
        "DTSTART:\(icsLocal(due))",
        "DTEND:\(icsLocal(end))",
        "SUMMARY:\(escapeICS(isExam ? "📝 \(t.title)" : "\(t.title) due"))",
    ]
    if let name = className(t.courseID), !name.isEmpty {
        lines.append("DESCRIPTION:\(escapeICS(name))")
    }
    // With its reminder on: a day's warning, and a week's too for an exam.
    if t.reminder {
        let warnings = isExam
            ? [("-P7D", "in a week"), ("-PT24H", "in 24 hours")]
            : [("-PT24H", "in 24 hours")]
        for (trigger, label) in warnings {
            lines += [
                "BEGIN:VALARM",
                "ACTION:DISPLAY",
                "TRIGGER:\(trigger)",
                "DESCRIPTION:\(escapeICS("\(t.title) is \(isExam ? "" : "due ")\(label)"))",
                "END:VALARM",
            ]
        }
    }
    lines.append("END:VEVENT")
    return lines
}

// MARK: - Helpers

/// The weekday codes, Monday first, matching ClassPing's 0 = Monday. `BYDAY`.
private let byDay = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

/// The term as two moments: its first day's midnight and its last day at
/// 11:59 PM. Nil when neither day is set, or when the end comes before the
/// start (a typo, not a term). `resolveWindow`.
private func termRange(_ term: TermWindow?) -> (from: Date?, until: Date?)? {
    // `dayStart` (11a) is local midnight of a real "yyyy-MM-dd", else nil.
    let from = dayStart(term?.start)
    let lastDay = dayStart(term?.end)
    if let from, let lastDay, lastDay < from { return nil }
    if from == nil && lastDay == nil { return nil }
    return (from, lastDay.map { atMinute($0, 23 * 60 + 59) })
}

/// The first day from `base` on (today counts) that is one of `days`, at the
/// class's start time. `nextOccurrence`. A `while` with a counter looks at
/// most seven days ahead, as the web's loop does.
private func nextMeeting(_ days: [Int], _ startMin: Int, after base: Date) -> Date {
    let cal = Calendar.autoupdatingCurrent
    var day = base
    var looked = 0
    while looked < 7 && !days.contains(dayIndex(of: day)) {
        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        looked += 1
    }
    // `atMinute` (7a) sets the clock time on that day, safe across a
    // daylight-saving change.
    return atMinute(day, startMin)
}

/// "1 day", "3 hours", "15 minutes", the words in a class alarm.
/// `leadLabel` in lib/calendar.ts, which spells minutes out in full
/// (Logic/Reminders.swift has its own `leadLabel`, which says "min").
private func alarmLead(_ mins: Int) -> String {
    if mins % 1440 == 0 {
        let d = mins / 1440
        return "\(d) day\(d == 1 ? "" : "s")"
    }
    if mins % 60 == 0 {
        let h = mins / 60
        return "\(h) hour\(h == 1 ? "" : "s")"
    }
    return "\(mins) minute\(mins == 1 ? "" : "s")"
}

/// A moment as floating local time, seconds always 00: "20261021T093000".
/// `fmtLocal`.
private func icsLocal(_ d: Date) -> String {
    let c = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    return String(format: "%04d%02d%02dT%02d%02d00",
                  c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
}

/// A moment in UTC with a "Z": "20261021T030405Z". `fmtUtcNow`, except that
/// it stamps the `now` it's given, so the tests can predict it.
private func utcStamp(_ d: Date) -> String {
    var utc = Calendar(identifier: .gregorian)
    // `?? .current` can't happen (UTC always exists); it keeps this crash-free.
    utc.timeZone = TimeZone(identifier: "UTC") ?? .current
    let c = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
    return String(format: "%04d%02d%02dT%02d%02d%02dZ",
                  c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
}

/// Text made safe for a calendar field: a backslash, semicolon or comma gets
/// a backslash in front, and a line break becomes the two characters `\n`.
/// `esc`. The backslash goes first, or it would double the others' escapes.
/// "\r\n" is replaced before "\n" because Swift counts "\r\n" as a single
/// character, which a search for "\n" alone wouldn't find.
func escapeICS(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: ";", with: "\\;")
        .replacingOccurrences(of: ",", with: "\\,")
        .replacingOccurrences(of: "\r\n", with: "\\n")
        .replacingOccurrences(of: "\n", with: "\\n")
}

/// Splits a line longer than 74 into pieces, each continuation starting with
/// a space (RFC 5545 section 3.1). `fold`. The web counts JavaScript string
/// units (UTF-16), so this does too, on `line.utf16`. An emoji is two of those
/// units, and a cut between them would break it, so such a cut moves one
/// unit earlier.
func foldICS(_ line: String) -> String {
    let units = Array(line.utf16)
    guard units.count > 74 else { return line }
    var pieces: [String] = []
    var start = 0
    var width = 74   // the first piece; each continuation has 73 plus its space
    while units.count - start > width {
        var end = start + width
        if UTF16.isTrailSurrogate(units[end]) { end -= 1 }
        pieces.append(String(decoding: units[start..<end], as: UTF16.self))
        start = end
        width = 73
    }
    pieces.append(String(decoding: units[start...], as: UTF16.self))
    // `dropFirst` skips the first piece, which keeps no leading space.
    return ([pieces[0]] + pieces.dropFirst().map { " " + $0 }).joined(separator: "\r\n")
}

/// What the Calendar card says under its button: the web's footer line.
/// "Exports 5 classes and 3 open assignments. Re-add after you change your
/// schedule." Undated open work counts, as on the web, though it has no day
/// to go on.
func calendarSummary(classes: Int, openTasks: Int) -> String {
    if classes == 0 && openTasks == 0 { return "Add a class or assignment first." }
    return "Exports \(classes) \(classes == 1 ? "class" : "classes") and \(openTasks) open \(openTasks == 1 ? "assignment" : "assignments"). Re-add after you change your schedule."
}

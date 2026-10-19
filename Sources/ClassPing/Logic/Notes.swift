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

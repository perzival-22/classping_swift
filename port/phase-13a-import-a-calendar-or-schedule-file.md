---
title: "Phase 13a: Import a calendar or schedule file"
date: 2026-10-21
---

# Phase 13a: Import a calendar or schedule file

The first half of Phase 13. It builds on your committed `65aedf2`
("Phase11bandc"), which is identical to the 11b+c reference: all sixteen
files match, the tree builds with no warnings, and your own suites pass,
506/506 and 120/120.

**Your 11b+c check, recorded:** backup and restore read back as Already
Here; Merge and Undo; Replace and Undo; Recently Deleted, Restore and the
two-step Delete now; a class coming back with its work; `classping.ics`
saved to Files and opened into Calendar, repeating weekly inside the term
with its alarm; and Clear all data keeping your name and theme, with Merge
bringing the planner back. Step 6 (a bad file) and step 10 (a web backup)
weren't mentioned, and neither blocks anything.

**Phase 12 is on hold, at your request (D-79).** You're reworking the
gamification first, so progress and the pet wait for your changes. Nothing
here needs them. One thing to know for that rework: the web gives XP when
you import (the same as typing the classes in, under the same daily
ceiling), and the phone's import gives none yet, just like every class and
assignment you've added so far. Phase 12 only credits what's created after
it, unless your new design backfills. The `game` blobs 11b+c keeps in
planner.json are untouched.

**What Phase 13 is now (D-79):** 13a (this guide) reads a calendar file
(.ics) or a schedule spreadsheet (CSV), shows what it found, adds it on
your say-so, and asks the term question the web asks after a first import.
13b adds pasting a timetable, and the class form's import button and term
question after your first class. The web's live feed link needs its server,
which needs sign-in, so it moves to Phase 14 with the refresh preview. A
screenshot or PDF needs the AI server: Phase 15.

**Start here:** Stop 1 (4.1 to 4.3), the logic: two new files, then copy
two test files and run `scripts/test-logic.sh`. Stop 2 (4.4 and 4.5), the
store: one new file, one test file copied, one word added to
`scripts/test-store.sh`. Stop 3 (4.6 to 4.9), the screens: two new files,
two changed. Then section 5 on the phone, with the two sample files in
`docs/ios/samples/`.

**Verification (2026-10-21):** the reference iOS build passed with no
warnings. 544/544 logic tests passed in the default zone, New York,
Kolkata, London and Auckland (+38: `ICSImportTests` 28, every case of the
web's `ics-import.test.ts` but the six `planImport` ones (D-80), and
`CSVImportTests` 10, every case of `csv-import.test.ts`; the extra cases'
"web:" values were printed by the web's own `parseIcs`, `parseCsvSchedule`,
`parseRows`, `parseDays`, `parseTime` and `normalizedHeader` in node 24).
116/116 reference store tests (+8, `ImportStoreTests`). Both sample files
give the same classes, work, colors, days, times and term in the phone's
parser and the web's. The seven file blocks laid over your tree are
identical to the reference, and that tree built with no warnings. Your own
suites with the new tests and script word, against the new source:
544/544 and 128/128. Nothing has been checked on the
phone yet.

## 1. Goal

Your school's schedule comes in from a file, checked by you before
anything is added.

**On your phone:** Profile tab → IMPORT FROM YOUR SCHOOL → **Upload an .ics
file** → pick `classping-sample.ics` → "Ready to import 5 items", "2 classes
· 3 assignments · 2 skipped" → **Add 5**. Today's week has Biology (sample)
and Statistics (sample); Tasks has three new deadlines.

This phase includes:

- **Upload an .ics file:** the calendar file Canvas, Brightspace, Blackboard,
  Moodle or Google Classroom lets you download. A weekly event becomes a
  class; a one-off event becomes an assignment due when it starts (an exam,
  when the title says exam, midterm, final, test or quiz).
- **Upload a schedule CSV:** the spreadsheet a student portal exports, with
  Course, Days, Start and End columns (Room, Instructor, Credits and the
  semester's days optional).
- **The preview:** how many classes and assignments, and how many were
  skipped, then Cancel or Add. Nothing is written before Add.
- **The term question:** after the first import into an empty planner,
  "We found a term" (with the file's days) or "When does your semester
  run?", in a half-height sheet. Asked once.
- **Skip the typing:** Today's first-run card now leads with **Import my
  schedule**, as the web's does, with Add a class manually under it.

## 2. New Swift concepts

### One letter can be two codes: `unicodeScalars`

A Swift `String` is a list of `Character`s, and a Character is what you'd
call one letter, even when it's made of several codes. The Windows line
ending "\r\n" is one Character. That's usually what you want, but it means
a calendar file, which ends every line with "\r\n", has no "\n" Character
in it at all:

```swift
let text = "Biology\r\nChemistry"
text.split(separator: "\n").count   // 1: the "\r\n" isn't a "\n"
text.count                          // 17 Characters
text.unicodeScalars.count           // 18 codes: "\r" and "\n" are two
```

`unicodeScalars` is the same text as its separate codes, the way
JavaScript's `split(/\r?\n/)` and its `for` loops see it. A
`String.UnicodeScalarView` is that list on its own: it can grow one code
at a time and turn back into a String:

```swift
var line = String.UnicodeScalarView()
for scalar in text.unicodeScalars where scalar != "\r" {
    line.append(scalar)
}
String(line)   // "Biology\nChemistry"
```

`textLines` (4.1) and the table reader `parseRows` (4.2) both work this way.

### Regex literals: `/.../`, `wholeMatch` and the bracketed parts

Phase 2 matched patterns with `range(of:options: .regularExpression)`, a
pattern in a String that's only checked when it runs. A pattern between
slashes is a regex literal: Swift checks it as the app builds, and it knows
how many bracketed parts it has, so you can read them by number:

```swift
let value = "20260810T090000"
if let m = value.prefixMatch(of: /([0-9]{4})([0-9]{2})([0-9]{2})T/) {
    m.1          // "2026", the first bracket, as a Substring
    Int(m.2)     // Optional(8)
}
"9:00 AM".wholeMatch(of: /[0-9]{1,2}:[0-9]{2} ?(AM|PM)/)   // the whole text, or nil
"Midterm Exam".contains(/exam/.ignoresCase())              // true
```

`wholeMatch(of:)` must cover all of the text (the web's `^...$`),
`prefixMatch(of:)` only its start (`^...`), `firstMatch(of:)` anywhere.
Swift's defaults are wider than JavaScript's, so this phase asks for the
web's: `[0-9]` instead of `\d` (Swift's `\d` takes Arabic and other digits
too), and `.asciiOnlyWordCharacters()` with a `.simple` word boundary for
the exam test, so "Examé" counts as an exam on both apps.

### A sheet that stops halfway: `.presentationDetents`

A sheet normally covers the screen. A detent is a height it can rest at;
`.medium` is about half, `.large` full. Put it on the sheet's own view:

```swift
.sheet(isPresented: $askingTerm) {
    TermSetupSheet(suggestion: suggestion)
}

// inside TermSetupSheet's body:
VStack { … }
    .presentationDetents([.medium, .large])   // starts at half, can be pulled up
    .presentationDragIndicator(.visible)      // the little bar at the top
```

The term question (4.6) rises halfway, like the web's bottom sheet, with
the screen it follows still in view behind it.

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `parseIcs`, `ImportResult`, `TermDateSuggestion` and their helpers in `lib/ics-import.ts` | `Logic/ICSImport.swift` |
| `HEADER_ALIASES`, `parseRows`, `normalizedHeader`, `parseDays`, `parseTime`, `parseCsvSchedule` in `lib/csv-import.ts` | `Logic/CSVImport.swift` |
| `importItems` in `lib/store.tsx`; `shouldOfferTerm` in `ImportCalendar.tsx`; the writes in `TermSetupSheet.tsx` | `Store+Import.swift` |
| `components/TermSetupSheet.tsx` | `Screens/Import/TermSetupSheet.swift` |
| `ImportPanel`, `ImportCalendar` and `ImportSheet` in `components/ImportCalendar.tsx`, the file half | `Screens/Import/ImportView.swift` |
| `<ImportCalendar />` on `app/settings/page.tsx`, after the calendar export | `Screens/ProfileView.swift` |
| The first-run card in `app/home/page.tsx` ("Skip the typing") | `Screens/Today/TodayView.swift` |

Where the phone differs:

- **No live feed link yet (D-79).** The web's "Paste a live feed link"
  fetches through `/api/import/ics`, which needs sign-in (D-7), so it comes
  in Phase 14 with the refresh preview (`lib/feeds.ts`,
  `lib/ics-reconcile.ts`, `FeedRefresh.tsx`). "Import a screenshot or PDF"
  is Phase 15; "Paste a timetable" is 13b. The panel shows the web's
  file-only layout and its words.
- **No class ceiling (D-80).** The web's `planImport` holds back classes
  past the free plan's five. Pro is legacy (D-77) and the phone's class form
  has never had the limit, so an import adds every class it found.
- **Three sets of words (D-81).** "find them on your timetable and in
  Tasks" (the web says Assignments, an older name for the tab); "You can
  change it later on the Profile tab" (the web says Settings, which on a
  phone is Apple's Settings app); and a save that fails says so, which the
  web never has to.
- **Read the way the web reads (D-82).** Line endings and table cells are
  split on codes, not Characters; digits are 0 to 9; the exam test uses
  the web's word rule; trimming also drops the byte-order mark, as
  JavaScript's `trim()` does. The tests hold both apps to the same answers,
  down to a date like month 13 day 40 rolling over the same way.
- **A swipe down on the term question counts as Not now,** as the web's
  Escape key does, so it doesn't come back.
- **The term question's sentence** uses the days in its two pickers. The
  web's would fail if you cleared one (it formats an empty date); the
  phone can't clear one and shows the other sentence if it ever had to
  (web fixes, 7).
- **No XP for an import yet:** Phase 12, which is on hold (D-79).

Web behavior kept on purpose: every message, word for word; deadlines
filed under the first class the same import added (a calendar's deadlines
rarely name their class); every import's 15-minute class alarm and
deadline reminders on; anything more than a day in the past, cancelled, or
a moved single week (RECURRENCE-ID) left out; the term only from the first
weekly class and the rule's UNTIL or the latest date; a CSV's semester read
from its first class row; the 3 MB and 200-item limits; the term question
only for a planner with no classes, never asked, and no semester days.

## 4. Files, in the order to type them

### Stop 1: the logic

Two Foundation-only files in `Logic/`. Nothing calls them yet, so the app
builds as before after each one.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/ICSImport.swift` (new file)

```swift
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
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/CSVImport.swift` (new file)

```swift
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
```

### 4.3 Stop 1 check: the logic tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/ICSImportTests.swift $R/Logic/CSVImportTests.swift Tests/Logic/
scripts/test-logic.sh     # expect 544 tests passing
xtool dev build
```

A failure here points at 4.1 or 4.2. The parity suites compare whole
results with the web's, so a mismatch prints both sides: a "\r\n" that
wasn't split, or a heading used twice that should point at its last
column, are the likely spots.

### Stop 2: the store

One new file, then its tests.

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Import.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Import.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   importItems in lib/store.tsx; the term question's test
//           (shouldOfferTerm in components/ImportCalendar.tsx) and its
//           writes (components/TermSetupSheet.tsx)
//
//  Summary: Turns what an import found into real classes and assignments once
//           you confirm, in one save, and answers the "When does your
//           semester run?" question. Like the other actions since 9a, a
//           change only counts once planner.json has it.
//

import Foundation

extension Course {
    /// A class made from an import candidate (Logic/ICSImport.swift). A color
    /// name the app doesn't know becomes indigo. `init` in an extension keeps
    /// the memberwise `Course(name:short:...)` working too.
    init(imported c: ImportedClass) {
        self.init(name: c.name, short: c.short, color: SubjectColor(rawValue: c.color) ?? .indigo,
                  days: c.days, additionalMeetings: c.additionalMeetings,
                  startMin: c.start, endMin: c.end, remindBefore: c.remindBefore, alarm: c.alarm,
                  credits: c.credits, room: c.room, instructor: c.instructor,
                  sourceUID: c.sourceUID)
    }
}

extension Assignment {
    /// An assignment made from an import candidate, filed under `courseID`
    /// (nil for the Inbox), with its reminder on, as every import's is.
    init(imported t: ImportedTask, courseID: UUID?) {
        self.init(courseID: courseID, title: t.title, due: t.due, dueTime: t.dueTime,
                  kind: Assignment.Kind(rawValue: t.kind) ?? .assignment,
                  reminder: true, sourceUID: t.sourceUID)
    }
}

extension Store {
    // MARK: - Adding an import

    /// Adds every class and assignment you confirmed, each with a new id, in
    /// one save. `importItems` in lib/store.tsx. A calendar file's deadlines
    /// rarely name their class, so, like the web, they're filed under the
    /// first class this import added, which gives them a color and a home;
    /// with no class in the import they go to the Inbox. Gives back false,
    /// and changes nothing, when the save fails. (The web's XP for an import
    /// arrives with Phase 12.)
    @discardableResult
    func importItems(_ newClasses: [ImportedClass], _ newTasks: [ImportedTask]) -> Bool {
        let added = newClasses.map { Course(imported: $0) }
        let home = added.first?.id
        let work = newTasks.map { Assignment(imported: $0, courseID: home) }

        // Keep the lists as they were, to put back if the save fails.
        let before = (courses, assignments)
        courses += added
        assignments += work
        save()
        if lastSaveFailed {
            (courses, assignments) = before
            return false
        }
        return true
    }

    // MARK: - The term question

    /// True when the "When does your semester run?" sheet should follow an
    /// import or your first class: no classes yet, never asked, and no
    /// semester days set. The web's `shouldOfferTerm`. Read it BEFORE adding,
    /// since adding makes the planner non-empty.
    var shouldOfferTermSetup: Bool {
        liveCourses.isEmpty && !profile.termSetupPrompted
            && profile.termStart == nil && profile.termEnd == nil
    }

    /// The sheet's answer. With both days ("yyyy-MM-dd") it sets the semester;
    /// with none (Not now) it only records that you were asked. Either way it
    /// never asks again; Profile's Semester card changes the days later.
    /// A day that isn't real is refused; the sheet checks the order.
    @discardableResult
    func finishTermSetup(start: String? = nil, end: String? = nil) -> Bool {
        if let start, !isValidDate(start) { return false }
        if let end, !isValidDate(end) { return false }
        let before = profile
        profile.termSetupPrompted = true
        if let start, let end {
            profile.termStart = start
            profile.termEnd = end
        }
        save()
        if lastSaveFailed {
            profile = before
            return false
        }
        return true
    }
}
```

### 4.5 Stop 2 check: the store tests and the script (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Persistence/ImportStoreTests.swift Tests/Store/
```

Then add one word to the end of the `for source in …` list in
`scripts/test-store.sh`, so it reads `… Models+Backup Store+Backup
Store+Trash Store+Import; do`. Without it the store tests can't find
`importItems`.

```bash
scripts/test-store.sh     # expect 128
xtool dev build
```

### Stop 3: the screens

Two new screens in a new `Screens/Import/` folder, then the Profile tab and
Today, which show them. The term sheet comes first because the panel opens
it.

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Import/TermSetupSheet.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/TermSetupSheet.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   components/TermSetupSheet.tsx
//
//  Summary: The one-time question after your first import (and, from 13b,
//           your first class): when does your semester run? When the file
//           suggested days, it asks you to confirm them. Not now, or a swipe
//           down, means it won't ask again; the Semester card on Profile
//           changes the days any time.
//

import SwiftUI

struct TermSetupSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The days the import suggested, or nil (a first class suggests none).
    let suggestion: TermDateSuggestion?

    /// The two days as "yyyy-MM-dd", nil until set.
    @State private var start: String?
    @State private var end: String?
    /// Why Save can't go ahead, or nil.
    @State private var error: String? = nil

    /// The days start as the suggestion's. `_start` is the State itself,
    /// so `State(initialValue:)` gives it its first value (Phase 4a).
    init(suggestion: TermDateSuggestion?) {
        self.suggestion = suggestion
        _start = State(initialValue: suggestion?.start)
        _end = State(initialValue: suggestion?.end)
    }

    var body: some View {
        let accent = store.profile.accent
        // A whole range was suggested: confirm it rather than ask for it.
        let foundRange = suggestion?.end != nil

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.brand(accent))
                    .frame(width: 40, height: 40)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(foundRange ? "We found a term" : "When does your semester run?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(explanation(foundRange))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 6) {
                dateRow("SEMESTER STARTS", $start, accent)
                dateRow("SEMESTER ENDS", $end, accent)
            }

            if let error {
                Text(error)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.danger)
            }

            HStack(spacing: 10) {
                Button {
                    store.finishTermSetup()
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(Theme.muted)

                Button { save() } label: {
                    Text("Save semester dates")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand(accent))
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        // A sheet that rises only halfway, like the web's bottom sheet, and
        // can be pulled up to full height. Each "detent" is a height it rests at.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // A swipe down counts as Not now, as the web's Escape key does. Save
        // and Not now have already recorded it, so this only fills the gap.
        .onDisappear {
            if !store.profile.termSetupPrompted { store.finishTermSetup() }
        }
    }

    /// The line under the title: the found range, or why to set one.
    private func explanation(_ foundRange: Bool) -> String {
        if foundRange, let first = dayStart(start), let last = dayStart(end) {
            return "We found a term from \(label(first)) to \(label(last)). Use these dates?"
        }
        return "Set this once to keep your timetable and grade report in the right term. You can change it later on the Profile tab."
    }

    /// "Aug 31", in your phone's language. The web's `dateLabel`.
    private func label(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// One of the two days: a date picker once set, "Add date" before. The
    /// same row as the Semester card's (11a).
    private func dateRow(_ title: String, _ day: Binding<String?>, _ accent: Profile.Accent) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted2)
            Spacer()
            if let date = dayStart(day.wrappedValue) {
                DatePicker(title, selection: Binding(
                    get: { date },
                    set: { picked in
                        day.wrappedValue = dayOf(picked)
                        error = nil
                    }
                ), displayedComponents: .date)
                .labelsHidden()
                .tint(Theme.brand(accent))
            } else {
                Button("Add date") {
                    day.wrappedValue = dayOf(.now)
                    error = nil
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(minHeight: 44)
                .tint(Theme.brand(accent))
            }
        }
    }

    /// Save: both days, the end not before the start, in the web's words.
    /// "yyyy-MM-dd" text sorts the way the days do, so `<` compares them.
    private func save() {
        guard let start, let end else {
            error = "Add both dates, or choose Not now."
            return
        }
        if end < start {
            error = "Your semester end date needs to be after its start date."
            return
        }
        if store.finishTermSetup(start: start, end: end) {
            dismiss()
        } else {
            error = "Couldn't save on this device. Try again."
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Import/ImportView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/ImportView.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   components/ImportCalendar.tsx (ImportPanel, ImportCalendar and
//           ImportSheet), the file half
//
//  Summary: Bringing your schedule over from a file your school gives you: a
//           calendar (.ics) or a schedule spreadsheet (CSV). The file is read
//           on the phone, and you see what it found before anything is added.
//           One panel worn two ways, as on the web: a card on Profile, and a
//           sheet from Today's first-run card. The live feed link waits for
//           sign-in (Phase 14), a screenshot or PDF for Phase 15 (D-79).
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

/// The panel itself: the two upload buttons, then the preview and Add.
/// `ImportPanel` in components/ImportCalendar.tsx.
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
/// Today with no classes yet. `ImportSheet`. It closes itself once the
/// import (and the term question) are done.
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ImportPanel(onDone: { dismiss() })
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

### 4.8 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (replaces your 11b+c file: one card added)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card),
//           11a (the settings: profile, grading scale, semester), 11b+c
//           (the calendar file, and your data: backups, Recently Deleted,
//           clearing) and 13a (importing from your school)
//  Ports:   app/settings/page.tsx, moved into its own tab (D-19): the
//           Profile, Appearance, Reminders (with its calendar export), Import
//           from your school, Grading scale and Semester cards, and the backup
//           rows of the Account card
//
//  Summary: The Profile tab is ClassPing's settings: you, the look, your
//           reminders and calendar, importing from your school, how letters
//           are worked out, the term, and your data. Your account arrives
//           with sync, your level in Phase 12.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` lets the pickers write into the store (Phase 3).
        @Bindable var store = store

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
                // CHANGED in Phase 11a: your photo and name, editable.
                ProfileCard()

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

                // MARK: Appearance
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("APPEARANCE")
                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)
                    // NEW in Phase 11a: the web's line under each choice.
                    footnote(store.profile.theme == .dark
                             ? "Warm charcoal, with the same soft surfaces and your app color."
                             : "Switch to warm charcoal for late-night planning.")

                    sectionLabel("APP COLOR")
                        .padding(.top, 6)
                    Picker("App color", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                    footnote("Baby Pink or Ocean, for your highlights and primary actions.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // MARK: Reminders
                RemindersSection()

                // MARK: Calendar
                // NEW in Phase 11b+c: the timetable as a .ics file. The web
                // puts this inside its Reminders card; here it's its own card.
                CalendarCard()

                // MARK: Import from your school
                // NEW in Phase 13a: a calendar or schedule file, as on the
                // web's Settings, between the calendar and the grading scale.
                ImportCard()

                // MARK: Grading scale
                // NEW in Phase 11a: moved here from the Grades screen (D-67).
                GradingSection()

                // MARK: Semester
                // NEW in Phase 11a.
                SemesterSection()

                // MARK: Your data
                // NEW in Phase 11b+c: back up, restore, Recently Deleted, clear.
                DataSection()

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    // CHANGED in Phase 11b+c: backups, Recently Deleted and
                    // the calendar are here now. Only your account is left.
                    comingRow("person.crop.circle", "Your account and sync")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        // NEW in Phase 11a: a swipe down the page puts the keyboard away.
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
        .navigationTitle("Profile")
        // Save whenever a profile field changes, so the choice survives a
        // relaunch. CHANGED in Phase 5a: this moved here from TodayView.
        .onChange(of: store.profile) { store.save() }
        // NEW in Phase 11b+c: "Backup restored" with its Undo shows here,
        // where the restore happened, as well as on the other tabs.
        .undoBar()
    }

    /// The small spaced-out caps over each card, like the web's section labels.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// The small grey line under a control. NEW in Phase 11a.
    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)
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

/// A round avatar: your photo if you've chosen one, otherwise up to two
/// initials on the brand gradient, or a person symbol before you've set a
/// name. The tab bar uses a small one, the Profile tab a big one. Phase 12
/// adds the pet-tier ring.
struct AvatarBadge: View {
    // NEW in Phase 11a: the photo comes from the store, so every badge
    // shows it without each caller passing it in.
    @Environment(Store.self) private var store

    let name: String
    let size: CGFloat
    let accent: Profile.Accent

    var body: some View {
        ZStack {
            Circle().fill(Theme.brandGradient(accent))
            // CHANGED in Phase 11a: two initials, as on the web ("KM").
            let letters = avatarInitials(name.trimmingCharacters(in: .whitespaces))
            if letters.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            } else {
                Text(letters)
                    .font(.system(size: size * (letters.count > 1 ? 0.36 : 0.42), weight: .bold))
                    .foregroundStyle(.white)
            }
            // NEW in Phase 11a: the photo, laid over the initials.
            if let uri = store.profile.avatarURL, uri.hasPrefix("data:image/") {
                AvatarPhoto(uri: uri)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // The tab's own label says "Profile", so VoiceOver skips the picture.
        .accessibilityHidden(true)
    }
}

/// A stored `data:` picture, turned back into an image once per picture
/// rather than on every redraw. NEW in Phase 11a.
private struct AvatarPhoto: View {
    let uri: String
    /// The decoded picture, or nil until it's ready (the initials show).
    @State private var image: UIImage? = nil

    var body: some View {
        // `Color.clear` takes the badge's size; the photo fills it, cropped.
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            // Runs when the badge appears and again when the picture changes.
            .task(id: uri) {
                image = avatarImageData(uri).flatMap { UIImage(data: $0) }
            }
    }
}
```

### 4.9 `~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift` (replaces your timezonefix file: the sheet case and the first-run card)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift
//  Phase:   6b (your work and your classes), after 6a (the picked day),
//           5a (the week) and 5b (class details); changed in 7c (the
//           just-ended banner) and 13a (Import my schedule)
//  Ports:   app/home/page.tsx (the greeting, the quote, the just-ended
//           banner, the picked day's classes, every "nothing here" message,
//           the term glance, the assignments and My Classes) and
//           app/week/page.tsx (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Below it, the quote
//           banner, a "just finished" banner for half an hour after a class,
//           the picked day's classes, and then your term at a glance, your
//           next assignments and your classes, with Edit and Delete. Before
//           your first class, "Skip the typing" offers the import (13a).
//

import SwiftUI

/// One presentation at a time: a tapped meeting's details, a class's editor,
/// the form for a new class, or the import. Each case carries what its sheet needs.
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)
    case newCourse                    // NEW in Phase 6a: "Add a class manually"
    case importSchedule               // NEW in Phase 13a: "Import my schedule"

    var id: String {
        switch self {
        case .meeting(let opened):
            "meeting-\(opened.courseID)-\(opened.meetingID)-\(dayOf(opened.date))"
        case .editCourse(let course):
            "course-\(course.id)"
        case .newCourse:              // NEW in Phase 6a
            "new-course"
        case .importSchedule:         // NEW in Phase 13a
            "import"
        }
    }
}

/// The days' full English names, Monday first. `DAY_NAMES` in
/// app/home/page.tsx, for "View Thursday's schedule" and the title.
// NEW in Phase 6a
private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The selected tab, owned by RootView. A binding, so "View all" in the
    /// assignments can switch to the Tasks tab from in here.
    // NEW in Phase 6b
    @Binding var tab: MainTab

    // MARK: Screen state
    // None of this is saved: Today always opens on this week, folded,
    // with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    /// The sheet currently presented, or nil when none is open.
    @State private var sheet: TodaySheet?
    /// NEW in Phase 7c: the class whose just-ended banner you closed with ×.
    /// The web's `promptDismissed`. Only that class: a later one still shows.
    @State private var dismissedBanner: UUID?

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the Now tag moves on and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // `activeClasses` in lib/store.tsx.
            let courses = store.activeCourses

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Class deletion and Undo save here too. Report a failed
                    // write even if deleting the last class shows first run.
                    if store.lastSaveFailed {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                    }

                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)

                    // NEW in Phase 6a: the quote, then the picked day. Before
                    // the first class there is nothing to show for any day, so
                    // the setup steps take the day's place (the web's isFirstRun).
                    QuoteBanner(now: now)
                    if courses.isEmpty {
                        firstRun(accent)
                    } else {
                        daySection(courses, now, accent)

                        // NEW in Phase 6b: the lists under the day
                        // (TodaySections.swift). Like the web, they wait
                        // until there's a first class.
                        TermGlance(now: now)
                            .padding(.top, 8)
                        AssignmentsPreview(now: now, onViewAll: { tab = .tasks })
                            .padding(.top, 8)
                        MyClassesSection(onAdd: { sheet = .newCourse },
                                         onEdit: { course in sheet = .editCourse(course) })
                            .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            // Browsing weeks keeps the picked weekday inside the visible week.
            .onChange(of: weekOffset) { _, offset in
                selectedDay = weekDates(now, offset)[dayIndex(of: selectedDay)]
            }
            // Keep following today across midnight until another day is picked.
            .onChange(of: Calendar.autoupdatingCurrent.startOfDay(for: now)) { previous, current in
                if weekOffset == 0 && selectedDay == previous {
                    selectedDay = current
                }
            }
        }
        .background(Theme.canvas)
        // NEW in Phase 6b: the Undo bar after deleting a class (or an
        // assignment from its detail screen), the same one Tasks uses.
        .undoBar()
        // Where a tapped assignment goes, as on the Tasks tab.
        .navigationDestination(for: AssignmentLink.self) { link in
            AssignmentDetailView(assignmentID: link.id)
        }
        // CHANGED in Phase 6a: "Today", or the picked day's name, like the
        // web's heading.
        .navigationTitle(Calendar.autoupdatingCurrent.isDateInToday(selectedDay)
                         ? "Today" : dayNames[dayIndex(of: selectedDay)])
        // The calendar button where the web's gear used to be (the gear's
        // job moved to the Profile tab). It opens and folds the week.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWeek()
                } label: {
                    Image(systemName: weekOpen ? "calendar.circle.fill" : "calendar")
                }
                .accessibilityLabel(weekOpen ? "Fold the week away" : "Show the whole week")
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .meeting(let opened):
                CourseSheet(opened: opened)
            case .editCourse(let course):
                NavigationStack {
                    CourseFormView(editing: course)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            case .newCourse:          // NEW in Phase 6a
                NavigationStack {
                    CourseFormView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            case .importSchedule:     // NEW in Phase 13a
                ImportSheet()
            }
        }
    }

    // MARK: - The week

    /// The card holding the week: the grid when open, the strip when folded,
    /// and the handle underneath either way.
    private func weekCard(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let start = store.profile.termStart
        let end = store.profile.termEnd

        return VStack(spacing: 6) {
            // `$weekOffset` hands the child a binding: the strip and the grid
            // both read and change the same week.
            if weekOpen {
                WeekGrid(courses: courses, termStart: start, termEnd: end, now: now,
                         weekOffset: $weekOffset, accent: accent,
                         onOpen: { slot, day, date in
                             sheet = .meeting(OpenedMeeting(courseID: slot.course.id,
                                                            meetingID: slot.meeting.id,
                                                            day: day, date: date))
                         },
                         onSchedule: { course in
                             sheet = .editCourse(course)
                         })
                    .transition(.opacity)
            } else {
                WeekStrip(courses: courses, termStart: start, termEnd: end, now: now,
                          weekOffset: $weekOffset, selected: $selectedDay, accent: accent)
                    .transition(.opacity)
            }
            handle
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// The little bar under the week. Tap it, or drag it down to open and up
    /// to fold. `highPriorityGesture` means a drag that starts on the handle
    /// moves the week instead of scrolling the page.
    private var handle: some View {
        Capsule()
            .fill(Theme.lineStrong)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .onTapGesture { toggleWeek() }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10).onEnded { drag in
                    // Down by 24 points or more opens; up by 24 or more folds.
                    if drag.translation.height > 24 && !weekOpen { toggleWeek() }
                    if drag.translation.height < -24 && weekOpen { toggleWeek() }
                }
            )
            // To VoiceOver this is a button with a clear name.
            .accessibilityElement()
            .accessibilityLabel(weekOpen ? "Fold the week away" : "Open the whole week")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggleWeek() }
    }

    /// Opens or folds the week. `withAnimation` animates every change the
    /// toggle causes: the card grows or shrinks smoothly, and the strip and
    /// grid cross-fade because each has `.transition(.opacity)`.
    private func toggleWeek() {
        withAnimation(reduceMotion ? nil : .snappy) {
            weekOpen.toggle()
        }
    }

    // MARK: - The picked day
    // NEW in Phase 6a: replaces the one-line day card from Phase 5a.

    /// The picked day: its class cards, then whichever message explains an
    /// empty day, then the way on to the next day. The middle of the web's
    /// home page. `@ViewBuilder` lets one function return different views
    /// depending on the `if`s, and allows the `let`s at the top.
    @ViewBuilder
    private func daySection(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let day = selectedDay
        let col = dayIndex(of: day)
        let start = store.profile.termStart
        let end = store.profile.termEnd
        let isToday = Calendar.autoupdatingCurrent.isDate(day, inSameDayAs: now)
        let dayName = dayNames[col]

        // A timetable only exists inside its semester. Outside it, nothing is
        // listed and the screen says so instead of "you're free".
        let inTerm = isWithinTerm(start, end, day)
        let slots = expandClassMeetings(courses)
        // This day's meetings, earliest first.
        let dayClasses = inTerm
            ? slots.filter { $0.meeting.days.contains(col) }.sorted { $0.meeting.start < $1.meeting.start }
            : []

        // "You're all free this week!" only once you've looked six or more
        // days ahead and nothing in the picked day's week falls in the term.
        // (The web's `checkedAll`: an empty day alone doesn't mean a free week.)
        let dates = weekDates(day, 0)
        let weekHasClasses = slots.contains { slot in
            slot.meeting.days.contains { d in
                dates.indices.contains(d) && isWithinTerm(start, end, dates[d])
            }
        }
        let checkedAll = daysAhead(of: now) >= 6 && dayClasses.isEmpty && !weekHasClasses

        // Today gets Now / Done tags; any other day gets -1, which turns them off.
        let nowMin = isToday ? minuteOfDay(now) : -1
        let nextName = dayNames[(col + 1) % 7]

        // NEW in Phase 7c: a class that finished in the last half hour gets a
        // banner asking about homework, above the day's classes. Today only,
        // inside the term, and not once you've closed it for that class.
        if isToday && inTerm, let ended = justEnded(courses, now: now),
           dismissedBanner != ended.course.id {
            justEndedBanner(ended.course, accent)
        }

        // The classes, one card each. ForEach gives every card its slot's id,
        // which is how each ClassCard keeps its own open/folded state.
        if !dayClasses.isEmpty {
            VStack(spacing: 12) {
                ForEach(dayClasses) { slot in
                    ClassCard(slot: slot, nowMin: nowMin)
                }
            }
            // A recurring meeting keeps its slot id across dates. Reset the
            // cards for a newly picked day so they always start expanded.
            .id(dayOf(day))
        }

        // At most one message: outside the term, a free day, or a free week.
        if !inTerm {
            let label = termRangeLabel(start, end)
            emptyState(emoji: "📅", title: "Outside your semester",
                       message: label.map { "Your term runs \($0), so nothing is timetabled for \(isToday ? "today" : dayName)." }
                           ?? "Nothing is timetabled for this date.")
        } else if checkedAll {
            emptyState(emoji: "🎉", title: "You're all free this week!",
                       message: "No classes scheduled this week. Enjoy your time!")
            Button {
                showDay(Calendar.autoupdatingCurrent.startOfDay(for: now), now)
            } label: {
                Text("Back to Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else if dayClasses.isEmpty {
            emptyState(emoji: "🌿", title: "Looks like you're free!",
                       message: isToday ? "Nothing scheduled for today." : "Nothing on \(dayName).")
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack(spacing: 8) {
                    Text("View \(nextName)'s schedule")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Theme.brand(accent).opacity(0.32), radius: 12, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }

        // On a day with classes, or outside the term, a quieter way on.
        if !dayClasses.isEmpty || !inTerm {
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack {
                    Text("View \(nextName)'s schedule")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.brand(accent).opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.brand(accent).opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// "Calculus III just finished · Did it come with an assignment?", with
    /// Log it (opens the post-class prompt) and × (hides it for this class).
    /// The just-ended banner in app/home/page.tsx. NEW in Phase 7c
    private func justEndedBanner(_ course: Course, _ accent: Profile.Accent) -> some View {
        HStack(spacing: 12) {
            Text("✍️")
                .font(.system(size: 17))
                .frame(width: 38, height: 38)
                .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(course.name) just finished")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("Did it come with an assignment?")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Opens the prompt the same way a tapped notification does: by
            // leaving a route in the store for RootView to take.
            Button {
                store.route = .postClass(course.id)
            } label: {
                Text("Log it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.brand(accent), in: Capsule())
                    // The pill stays small; the tap area is 44 points tall.
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                dismissedBanner = course.id
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.hint)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(Theme.brand(accent).opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Theme.brand(accent).opacity(0.14), lineWidth: 1))
    }

    /// The big emoji tile, a heading and a line of explanation, centred.
    /// The web repeats this block for each of its three messages.
    private func emptyState(emoji: String, title: String, message: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 38))
                .frame(width: 80, height: 80)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.bottom, 14)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    // MARK: - First run
    // NEW in Phase 6a

    /// Before the first class: one job, get a class in. The web's first-run
    /// card: "Skip the typing" leads with Import my schedule, and the manual
    /// route stays one tap away under it, because for three classes typing
    /// them in is genuinely faster. Then the three steps.
    // CHANGED in Phase 13a: the card, with the import
    private func firstRun(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Skip the typing")
                    .font(.system(size: 22, weight: .semibold))
                Text("Your school already has your timetable. Bring it over and ClassPing takes it from there, your week, your deadlines, and a nudge before each one.")
                    .font(.system(size: 14))
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                // White on the gradient in both themes, as on the web.
                Button {
                    sheet = .importSchedule
                } label: {
                    Text("Import my schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                Button {
                    sheet = .newCourse
                } label: {
                    Text("Add a class manually")
                        .font(.system(size: 14.5, weight: .semibold))
                        .opacity(0.9)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.brand(accent).opacity(0.3), radius: 10, x: 0, y: 6)
            .padding(.bottom, 6)

            onboardStep(1, "Import or add your classes",
                        "Drop in your school's calendar file, or type a class in, about 20 seconds each.", accent)
            // The web says "on the Week tab"; on the phone the week lives
            // behind Today's calendar button (D-19).
            onboardStep(2, "Your week fills in",
                        "See today at a glance, and the whole week from the calendar button.", accent)
            onboardStep(3, "Get reminded",
                        "A heads-up before class starts, and before work is due.", accent)
        }
    }

    /// One numbered step. `OnboardStep` in app/home/page.tsx.
    private func onboardStep(_ n: Int, _ title: String, _ body: String, _ accent: Profile.Accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 26, height: 26)
                .background(Theme.brandSoft(accent), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }

    // MARK: - Moving between days
    // NEW in Phase 6a

    /// Picks `day` and moves the strip to the week that holds it, so "View
    /// Monday's schedule" on a Sunday lands on next week's Monday.
    private func showDay(_ day: Date, _ now: Date) {
        // Whole weeks between this week's Monday and the day, rounded down,
        // so a day in last week is -1 and not 0.
        let monday = weekDates(now, 0)[0]
        let days = Calendar.autoupdatingCurrent.dateComponents([.day], from: monday, to: day).day ?? 0
        selectedDay = day
        weekOffset = Int((Double(days) / 7).rounded(.down))
    }

    /// How many days after today the picked day is (0 = today, -1 = yesterday).
    /// The web's `offset`. Counted in calendar days, so a daylight-saving
    /// change can't make it off by one.
    private func daysAhead(of now: Date) -> Int {
        let today = Calendar.autoupdatingCurrent.startOfDay(for: now)
        return Calendar.autoupdatingCurrent.dateComponents([.day], from: today, to: selectedDay).day ?? 0
    }

    /// "Good morning, Kelvin 👋". The web's `greeting(hour)` plus the first
    /// part of your username; just the greeting until you've set a name.
    // CHANGED in Phase 6a: the wave, as on the web.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? "\(hello) 👋" : "\(hello), \(first) 👋"
    }
}
```

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 544
scripts/test-store.sh     # expect 128
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

**First, the sample files.** `docs/ios/samples/` in the web folder has
`classping-sample.ics` and `classping-sample.csv`; every class and
assignment in them ends in "(sample)", so they're easy to spot and delete.
Get both onto the phone: iCloud Drive for Windows, or email them to
yourself and use **Save to Files**. (Your own school's calendar file works
too, and is the real test: Brightspace's calendar can export one.)

1. **The card:** Profile tab. After CALENDAR there's IMPORT FROM YOUR
   SCHOOL: two lines of text, then **Upload an .ics file** and **Upload a
   schedule CSV**.
2. **Preview a calendar:** tap **Upload an .ics file** and pick
   `classping-sample.ics`. Files should only let you pick calendar files.
   The card says "Ready to import 5 items" and "2 classes · 3 assignments
   · 2 skipped" (the skipped two are a quiz in October and a cancelled
   seminar). Tap **Cancel**: the two buttons are back and nothing was added.
3. **Add it:** pick the file again and tap **Add 5**. "Added 5 items, find
   them on your timetable and in Tasks. 🎉" On Today, Biology (sample) is on
   Mon, Wed and Fri at 9:00 in Science Hall, 204, and Statistics (sample) on
   Tue and Thu at 1:30 PM. On Tasks, all three sit under Biology (sample),
   the first class the file added: Essay draft (sample) due Nov 3 at 11:59
   PM, Midterm (sample) as an exam on Nov 12 at 10:00 AM, and Final project
   (sample) as an exam, all day, on Dec 15. Each has its reminder on.
4. **A schedule CSV:** tap **Upload a schedule CSV**, pick
   `classping-sample.csv`: "Ready to import 3 items", "3 classes · 0
   assignments". **Add 3**: Chemistry (sample) Mon/Wed/Fri 10:00, History
   (sample) Tue/Thu 2:00 PM, Studio Art (sample) on Saturday 9 to 12, with
   their rooms, instructors and credits (Edit in My Classes shows them).
5. **Tidy up:** delete the five sample classes from Today's My Classes;
   their work goes with them, and Recently Deleted has it all if you need it.
6. **Optional, the first run and the term question:** this needs an empty
   planner, so **Back up my data** first. Then **Clear all data**. Today
   shows "Skip the typing" with **Import my schedule** (white) and Add a
   class manually under it. Tap **Import my schedule**: the sheet "Import
   your schedule" has the same panel. Upload the .ics, **Add 5**: the term
   question rises halfway, "We found a term", "We found a term from Aug 31
   to Dec 18. Use these dates?", with both dates set. Tap **Save semester
   dates**: both sheets close, and Profile's SEMESTER shows Aug 31 to Dec
   18. Then **Restore a backup** with **Replace** to put your real planner
   back exactly (the sample items go; the question won't come back).
   Instead of Save you can swipe the term question down: that counts as Not
   now, and it won't ask again either.

Say what you saw, above all whether Files let you pick the .ics (step 2):
which kinds of file an app may open is the one part that couldn't be tried
before your phone.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] 544 logic and 128 store tests pass; the tree builds without warnings.
- [ ] A calendar file previews its counts, Cancel adds nothing, and Add puts
      its classes on Today and its deadlines on Tasks.
- [ ] A schedule CSV adds its classes with rooms, instructors and credits.
- [ ] Today's first-run card leads with Import my schedule.
- [ ] (Optional) After a first import into an empty planner, the term
      question appears once, and its dates land in Semester.

## 7. If it breaks

- **Cannot find 'parseICS', 'ImportResult' or 'textLines':** 4.1 isn't in
  `Logic/`, or its file name differs. `CSVImport.swift` uses its types.
- **An error inside a `/.../` pattern:** a regex literal is checked as it
  builds, and the error points at the column; compare that pattern with
  4.1 or 4.2 character for character (`\\n` and `\/` keep their backslash).
- **'asciiOnlyWordCharacters' or 'wordBoundaryKind' not found:** the dot
  before each is missing, or they're not chained onto the regex in
  `isExamTitle` (4.1).
- **The store tests can't find 'importItems':** `Store+Import` is missing
  from `scripts/test-store.sh` (4.5).
- **'ImportSheet' or 'ImportCard' not found:** 4.7 isn't typed yet. Swift
  doesn't mind which folder a file is in, only that it's somewhere inside
  `Sources/ClassPing/`.
- **Files greys out the .ics:** the picker didn't take it for a calendar.
  Say so: the fix is one more type in `ImportFileKind.types` (4.7).
- **The term question never appears:** it only follows a first import into
  a planner with no classes, never asked before and no semester days set.
  Clear all data resets all three.

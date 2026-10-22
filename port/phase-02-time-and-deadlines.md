# Phase 2: Time and deadline logic

*Replaces part of old Milestone 3. Checked on 2026-10-14: `build-check.sh` gave `BUILD_OK` with no warnings, and `logic-test.sh` passed 43 tests in 2 suites on Linux (the Swift twins of `lib/time.test.ts` and `lib/deadline.test.ts`). The Phase 1 `persistence-test.sh` still passes 4 of 4.*

**Before you start:** Phase 1 must be typed, building and committed.

## 1. Goal

The app gets the first of its ported logic: the rules for what a deadline *is*, when one has passed, and how to say it in plain words. **On your phone:** the Tasks list now reads like a planner, not a database dump. "Midterm 2" shows **In 5 days · 10:00 AM**, the Inbox item shows **No deadline**, and anything whose day has gone by shows **3 days overdue**. Nothing else changes yet; the real Tasks screen is Phase 4.

This phase also adds the project's first unit tests. You do **not** type them: they live in the reference copy and run on Linux, and they prove the Swift port behaves exactly like the web app's own test suite.

## 2. New Swift concepts

**`Calendar` and `DateComponents`.** A `Date` is just an instant, a number of seconds. To ask "what day is this?" or to build "the 7th at 09:15 local", you go through a `Calendar`, which knows about months, time zones and daylight saving. `DateComponents` is the bag of parts (year, month, day, hour…) you read out or put in:

```swift
var c = DateComponents()
c.year = 2026; c.month = 9; c.day = 7; c.hour = 9; c.minute = 15
let date = Calendar.current.date(from: c)          // build an instant from parts
let day  = Calendar.current.component(.day, from: date!) // read one part back -> 7
```

`Calendar.current` carries the phone's own time zone, so these parts always mean local wall-clock time. That is the whole reason the web app never let a deadline become a UTC timestamp, and it is why the ports read local components everywhere.

**Protocols.** A protocol is Swift's version of a TypeScript `interface`: a list of properties or methods a type promises to have. A function can then accept "anything that keeps a deadline" without caring whether it is an `Assignment`, a grade, or a test fixture:

```swift
protocol Dated { var due: String? { get }; var dueTime: String? { get } }
func deadlineOf(_ t: Dated) -> Deadline { Deadline(date: t.due, time: t.dueTime) }
extension Assignment: Dated {}   // Assignment already has due/dueTime, so: nothing to add
```

That empty `extension Assignment: Dated {}` is all it takes to say "an Assignment is Dated", because it already has the two properties the protocol asks for.

**Swift Testing (you don't type these).** The tests use Apple's `Testing` framework: `@Test` marks a function as a test, and `#expect(x == y)` checks a result the way `expect(x).toBe(y)` does in the web app's vitest files. `logic-test.sh` compiles the `Logic/` files on their own and runs these against them. They are the proof the port is correct; Claude keeps them in the reference copy.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/deadline.ts` (whole file) | `Logic/Deadline.swift` | A near line-for-line port. `Deadline` becomes a struct, the `Dated` interface becomes a protocol, and `Date.parse`/`new Date(y,m,d)` become `Calendar` + `DateComponents`. Same behaviour, same test cases |
| `lib/time.ts` (the device-side half) | `Logic/Time.swift` | Ports `fmtTime`, `scheduleDate`, `dayNumber`, `todayNumber`, `termProgress`. See the note below on the two functions left out |
| `taskDeadline`, `taskDueAt`, `byDeadline` (`lib/store.tsx`) | `Assignment+Deadline.swift` | In the web app these wrap the deadline helpers for a `TaskItem`. In Swift they become small conveniences on `Assignment` (`.deadline`, `.dueInstant`) plus a free `byDeadline` for sorting |
| the raw "due 2026-10-14 at 10:00" text in `AssignmentsView` | `formatDeadline(...)` | The hand-rolled Phase 1 text is replaced by the ported helper, so the list now shows the same labels the web app shows |

**Two `lib/time.ts` functions are deliberately not ported: `localClock` and `zonedInstant`.** They convert a UTC instant to and from a *named other* time zone, and they exist only because the web app's notification cron runs on a server in UTC and has to work out what the clock reads for a student elsewhere. The phone is always in its own zone, so `Calendar.current` already *is* the student's wall clock, and Phase 7 will schedule local notifications straight from `DateComponents`. Porting them now would be dead code. This is recorded as **decision D-16**; if a device feature ever needs cross-zone maths, they get ported then with their test cases.

**The store's small display helpers travel with their screens, not here.** `dueLabel` and `longDeadline` land in Phase 4 (Tasks), `weekInfo` and `fmtMD` in Phase 5 (Planner), `longDate` in Phase 9 (Grades), and `justEndedClass` in Phase 7 (the post-class prompt, where it also needs `expandClassMeetings` from Phase 5). Keeping each with the screen that first shows it avoids code no view uses yet.

## 4. Files, in the order to type them

First make the new folder `~/ClassPing/Sources/ClassPing/Logic/`. Swift Package Manager picks up `.swift` files in subfolders automatically, so the two logic files can live there. Type `Deadline.swift` first, because `Time.swift` is independent and the last two files build on `Deadline`.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Deadline.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Deadline.swift
//  Phase:   2 (time and deadline logic)
//  Ports:   lib/deadline.ts (the whole file)
//
//  Summary: What a deadline is, and the one place that decides when one has
//           passed. A deadline is a point on the student's own calendar, a day
//           and an optional time, never a UTC instant. Converting to an instant
//           happens here, against the device's current zone, only at the moment
//           something asks "is it late?".
//
//  This file imports only Foundation on purpose: it carries no SwiftUI and no
//  models, so the Linux test runner (tools/logic-test.sh) can compile it on its
//  own and run the Swift twins of lib/deadline.test.ts.
//

import Foundation

/// A calendar day ("yyyy-MM-dd") plus an optional local time ("HH:mm").
/// Three meaningful states, exactly as `Deadline` in lib/deadline.ts:
///   date nil              -> undated, an Inbox capture with no deadline yet
///   date set, time nil    -> all-day, "some time that day" (never faked as 23:59)
///   date set, time set    -> an exact wall-clock deadline
/// Equatable so the tests (and later the sort) can compare two deadlines.
struct Deadline: Equatable {
    var date: String?
    var time: String?
}

/// Anything that carries a deadline as the two stored fields `due` and `dueTime`.
/// `Dated` in lib/deadline.ts. A protocol is Swift's version of a TypeScript
/// interface: it says "a type is Dated if it has these properties", without
/// caring which type. `Assignment` conforms to it in Assignment+Deadline.swift,
/// so these pure functions never have to import the model.
protocol Dated {
    var due: String? { get }
    var dueTime: String? { get }
}

/// The deadline of a `Dated` value, as one value rather than two loose fields.
/// `deadlineOf` in lib/deadline.ts. Every screen, sort and reminder goes through
/// here rather than touching `due` and `dueTime` apart.
func deadlineOf(_ t: Dated) -> Deadline {
    Deadline(date: t.due, time: t.dueTime)
}

/// The instant a `Dated` value stops being on time, or nil when it is undated.
/// `dueAt` in lib/deadline.ts.
func dueAt(_ t: Dated) -> Date? {
    deadlineInstant(deadlineOf(t))
}

/// The deadline of something nobody has scheduled yet. `UNDATED` in the web app.
let UNDATED = Deadline(date: nil, time: nil)

/// The sentinel the old web task forms wrote when the time picker was left empty.
/// A legacy `due` that ends at 23:59 local was never an 11:59pm deadline, it was
/// "no time given", so `parseLegacyDue` reads it back as all-day, not exact.
private let legacyAllDaySentinel = "23:59"

/// True when `s` matches `pattern` anywhere. The patterns below are anchored with
/// `^...$`, so this is really a whole-string test.
/// `range(of:options:.regularExpression)` is Foundation's regex match: it gives
/// back the matched range, or nil when there is no match.
private func matches(_ s: String, _ pattern: String) -> Bool {
    s.range(of: pattern, options: .regularExpression) != nil
}

/// True when `v` is a real "yyyy-MM-dd" date. `isValidDate` in lib/deadline.ts.
/// Rejects impossible days that still have the right shape, like "2026-02-31".
func isValidDate(_ v: String?) -> Bool {
    // First the shape: four digits, a dash, two, a dash, two.
    guard let v, matches(v, #"^\d{4}-\d{2}-\d{2}$"#) else { return false }

    // Then the reality check. Build the date in a fixed Gregorian/UTC calendar so
    // no time zone or daylight-saving edge can move it, then read the components
    // back. If Feb 31 was asked for, the calendar rolls it to Mar 3 and the read
    // back no longer matches, which is how an impossible day is caught.
    let p = v.split(separator: "-").map { Int($0) ?? -1 }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    var c = DateComponents()
    c.year = p[0]; c.month = p[1]; c.day = p[2]
    guard let date = cal.date(from: c) else { return false }
    let back = cal.dateComponents([.year, .month, .day], from: date)
    return back.year == p[0] && back.month == p[1] && back.day == p[2]
}

/// True when `v` is a 24-hour "HH:mm". `isValidTime` in lib/deadline.ts.
func isValidTime(_ v: String?) -> Bool {
    guard let v else { return false }
    return matches(v, #"^([01]\d|2[0-3]):([0-5]\d)$"#)
}

/// "yyyy-MM-dd" for a Date, read in the device's own zone. `dayOf` in the web app.
/// Reading local components (not UTC) is the whole point: 00:30 local on the 7th
/// is still the 7th, even though UTC already thinks it is the 8th.
func dayOf(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
    // String(format:) pads with zeros, the way padStart(2, "0") does in the web app.
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

/// "HH:mm" for a Date, read in the device's own zone. `timeOf` in the web app.
func timeOf(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

/// Build a deadline, dropping anything malformed rather than guessing at it.
/// `makeDeadline` in lib/deadline.ts. No valid day means no deadline at all, and
/// a day with a malformed time becomes all-day rather than an invented time.
func makeDeadline(_ date: String?, _ time: String?) -> Deadline {
    guard isValidDate(date) else { return UNDATED }
    return Deadline(date: date, time: isValidTime(time) ? time : nil)
}

/// Read whatever an older `due` string held and say what it actually meant.
/// `parseLegacyDue` in lib/deadline.ts. The phone never wrote the legacy shapes
/// itself, but a restored web backup can still contain them, so the meaning has
/// to be recovered the same way the web app recovers it.
func parseLegacyDue(_ due: String?) -> Deadline {
    // Nothing, or only spaces, means undated.
    guard let raw0 = due else { return UNDATED }
    let raw = raw0.trimmingCharacters(in: .whitespaces)
    if raw.isEmpty { return UNDATED }

    // Already a bare calendar day: all-day, with no time to recover.
    if matches(raw, #"^\d{4}-\d{2}-\d{2}$"#) { return makeDeadline(raw, nil) }

    // Otherwise it should be a full ISO timestamp the old form built in local time
    // with `new Date(...).toISOString()`. Parse it back to the instant it names,
    // then read its local day and time, which is exactly what the student typed.
    guard let parsed = parseISOInstant(raw) else { return UNDATED }
    let date = dayOf(parsed)
    let time = timeOf(parsed)
    // The old "no time picked" sentinel means all-day, not an 11:59pm deadline.
    if time == legacyAllDaySentinel { return makeDeadline(date, nil) }
    return makeDeadline(date, time)
}

/// Parse an ISO-8601 instant like "2026-09-07T23:30:00.000Z". `new Date(raw)` in
/// the web app did this. Tries with fractional seconds first (what toISOString
/// always writes), then without, and gives back nil for anything else.
private func parseISOInstant(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

/// Postgres hands back "HH:mm:ss"; the app only ever cares about "HH:mm".
/// `fromDbTime` in lib/deadline.ts. Used when sync lands (Phase 14).
func fromDbTime(_ v: String?) -> String? {
    guard let v else { return nil }
    let short = String(v.prefix(5))
    return isValidTime(short) ? short : nil
}

/// The instant a deadline expires, in the device's current zone. `deadlineInstant`
/// in lib/deadline.ts, the one choke point every "is it late?" question goes through.
/// An all-day deadline is not overdue until its day is over, so it resolves to the
/// last moment of the day, not to midnight. An undated deadline has no instant.
func deadlineInstant(_ d: Deadline) -> Date? {
    // Validate here rather than trust the caller: rubbish in a stored row becomes
    // "no deadline" instead of a date that silently compares wrong.
    guard isValidDate(d.date), let date = d.date else { return nil }

    // Build the instant from explicit local components. `Calendar.current` carries
    // the device's zone, so these numbers mean local wall-clock time.
    let p = date.split(separator: "-").map { Int($0) ?? 0 }
    var c = DateComponents()
    c.year = p[0]; c.month = p[1]; c.day = p[2]

    if isValidTime(d.time), let time = d.time {
        // An exact deadline: the time the student picked, on the second.
        let t = time.split(separator: ":").map { Int($0) ?? 0 }
        c.hour = t[0]; c.minute = t[1]; c.second = 0
    } else {
        // All-day: the last moment of the day (23:59:59.999, like the web app).
        c.hour = 23; c.minute = 59; c.second = 59; c.nanosecond = 999_000_000
    }
    return Calendar.current.date(from: c)
}

/// Local midnight that starts the deadline's day. Nil when undated.
/// `deadlineDayStart` in lib/deadline.ts. The anchor for whole-day counting.
func deadlineDayStart(_ d: Deadline) -> Date? {
    guard isValidDate(d.date), let date = d.date else { return nil }
    let p = date.split(separator: "-").map { Int($0) ?? 0 }
    var c = DateComponents()
    c.year = p[0]; c.month = p[1]; c.day = p[2]
    c.hour = 0; c.minute = 0; c.second = 0
    return Calendar.current.date(from: c)
}

/// True when a deadline has no day at all. `isUndated` in the web app.
func isUndated(_ d: Deadline) -> Bool { d.date == nil }

/// True when a deadline has a day but no time. `isAllDay` in the web app.
func isAllDay(_ d: Deadline) -> Bool { d.date != nil && d.time == nil }

/// Has the deadline already passed, as of `now`? `isOverdue` in lib/deadline.ts.
/// Undated work can never be overdue, there is nothing to be late for.
func isOverdue(_ d: Deadline, _ now: Date) -> Bool {
    guard let at = deadlineInstant(d) else { return false }
    return at < now
}

/// Which section of the Tasks screen a deadline belongs in. `DueBucket` in the web app.
enum DueBucket { case overdue, today, upcoming, none }

/// Sort a deadline into its Tasks-screen section. `dueBucket` in lib/deadline.ts.
func dueBucket(_ d: Deadline, _ now: Date) -> DueBucket {
    guard let date = d.date else { return .none }
    if isOverdue(d, now) { return .overdue }
    // Compared as strings, so no time-zone arithmetic can move the "today" boundary.
    return date == dayOf(now) ? .today : .upcoming
}

/// Earliest deadline first, undated last. `compareDeadlines` in lib/deadline.ts.
/// Returns a negative number when `a` comes first, positive when `b` does, zero
/// when neither is earlier. Within one day an exact time sorts before all-day on
/// that same day: "hand in at 09:00" really does come before "some time Tuesday".
func compareDeadlines(_ a: Deadline, _ b: Deadline) -> Int {
    // Undated sorts last; two undated are equal.
    guard let ad = a.date else { return b.date == nil ? 0 : 1 }
    guard let bd = b.date else { return -1 }
    // Different days: the earlier string is the earlier day.
    if ad != bd { return ad < bd ? -1 : 1 }
    // Same day: an exact time beats all-day, which sorts after it.
    if a.time == b.time { return 0 }
    guard let at = a.time else { return 1 }
    guard let bt = b.time else { return -1 }
    return at < bt ? -1 : 1
}

/// Whole calendar days from `now`'s day to the deadline's day. `daysUntil` in the
/// web app. Negative once the day has passed, nil when undated. Counts calendar
/// days, not 24-hour blocks: 1am tomorrow is one day away even if it is two hours off.
func daysUntil(_ d: Deadline, _ now: Date) -> Int? {
    guard let start = deadlineDayStart(d) else { return nil }
    let today = Calendar.current.startOfDay(for: now)
    // Round, do not floor: across a daylight-saving change a day is 23 or 25 hours
    // long, and rounding keeps the count whole instead of drifting to 0 or 2.
    let days = start.timeIntervalSince(today) / 86_400
    return Int(days.rounded())
}

/// "13:05" -> "1:05 PM". `formatTime` in lib/deadline.ts, the 12-hour clock the
/// rest of the app shows.
func formatTime(_ time: String) -> String {
    let p = time.split(separator: ":").map { Int($0) ?? 0 }
    let hh = p[0]
    let mm = p.count > 1 ? p[1] : 0
    let suffix = hh < 12 ? "AM" : "PM"
    let h12 = hh % 12 == 0 ? 12 : hh % 12
    return "\(h12):\(String(format: "%02d", mm)) \(suffix)"
}

/// The short human label: "Today · 11:30 PM", "Tomorrow", "In 3 days", "Oct 20",
/// "3 days overdue". `formatDeadline` in lib/deadline.ts. Says "No deadline"
/// rather than inventing one for undated work: the Inbox exists so a student can
/// write something down before deciding when to do it.
func formatDeadline(_ d: Deadline, _ now: Date) -> String {
    guard d.date != nil else { return "No deadline" }
    let days = daysUntil(d, now) ?? 0
    // The time, shown only when the student gave one. `Optional.map` runs the
    // closure when `time` is present and yields nil when it is not, so `?? ""`
    // leaves an all-day deadline with no clock beside it.
    let clock = d.time.map { " · \(formatTime($0))" } ?? ""

    if isOverdue(d, now) {
        if days == 0 { return "Overdue\(clock)" }
        let n = abs(days)
        return "\(n) day\(n == 1 ? "" : "s") overdue"
    }
    if days == 0 { return "Today\(clock)" }
    if days == 1 { return "Tomorrow\(clock)" }
    if days > 1 && days < 7 { return "In \(days) days\(clock)" }

    // A week or more out: a short date, with the year only when it is not this year.
    guard let start = deadlineDayStart(d) else { return "No deadline" }
    return "\(shortDate(start, relativeTo: now))\(clock)"
}

/// "Oct 20", or "Jan 5, 2027" when the date is in a different year from `now`.
/// Matches the web app's `toLocaleDateString("en-US", { month: "short", day: ... })`.
private func shortDate(_ date: Date, relativeTo now: Date) -> String {
    let cal = Calendar.current
    let sameYear = cal.component(.year, from: date) == cal.component(.year, from: now)
    let f = DateFormatter()
    // POSIX locale: English month names, stable whatever the phone's language is.
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
    return f.string(from: date)
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/Time.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Time.swift
//  Phase:   2 (time and deadline logic)
//  Ports:   lib/time.ts (the device-side helpers)
//
//  Summary: Minutes-from-midnight formatting, day-by-day calendar browsing, and
//           the term-progress maths the Today and Grades screens will show. Like
//           Deadline.swift this imports only Foundation, so the Linux test runner
//           can compile it alone against lib/time.test.ts.
//
//  Not ported here (and why): `localClock` and `zonedInstant` from lib/time.ts
//  convert between a UTC instant and a named time zone's wall clock. They exist
//  only because the web app's notification cron runs in UTC and has to work out
//  what time it is for a student somewhere else. The phone is always in its own
//  zone: `Calendar.current` already is the student's wall clock, and Phase 7
//  schedules local notifications straight from DateComponents, so neither helper
//  has a caller on the device. See DECISIONS.md D-16. If a device feature ever
//  needs cross-zone maths, port them then, with their lib/time.test.ts cases.
//

import Foundation

/// 510 -> "8:30 AM". `fmtTime` in lib/time.ts. Turns a "minutes from midnight"
/// number (the unit Course.startMin / endMin use) into a 12-hour clock string.
func fmtTime(_ mins: Int) -> String {
    let h24 = mins / 60
    let m = mins % 60
    let ampm = h24 >= 12 ? "PM" : "AM"
    let h12 = h24 % 12 == 0 ? 12 : h24 % 12
    return "\(h12):\(String(format: "%02d", m)) \(ampm)"
}

/// Local midnight `offset` calendar days from `now`. `scheduleDate` in lib/time.ts.
/// Used to browse the planner forward and back a day at a time. Calendar
/// arithmetic, not "+ 86400 seconds", so it lands on the right day across a
/// daylight-saving change or a year boundary. `now` is never changed: a Swift
/// `Date` is a value, so callers keep their own copy untouched.
func scheduleDate(_ now: Date, _ offset: Int) -> Date {
    let cal = Calendar.current
    let midnight = cal.startOfDay(for: now)
    // `date(byAdding:value:to:)` is the calendar-aware "+ N days".
    return cal.date(byAdding: .day, value: offset, to: midnight) ?? midnight
}

/// Days since the Unix epoch for a "yyyy-MM-dd" date, or nil if it is not one.
/// `dayNumber` in lib/time.ts. Anchored to UTC so the arithmetic is pure calendar
/// days: a term that starts on the 25th starts on the 25th wherever it is read,
/// and no daylight-saving change can shorten a week and round a day off the count.
func dayNumber(_ iso: String) -> Int? {
    // Shape first, so a string like "25/08/2025" is rejected outright.
    guard iso.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
        return nil
    }
    // Build the date in a fixed Gregorian/UTC calendar.
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    let p = iso.split(separator: "-").map { Int($0) ?? -1 }
    var c = DateComponents()
    c.year = p[0]; c.month = p[1]; c.day = p[2]
    guard let date = cal.date(from: c) else { return nil }
    // Reject impossible dates that still match the shape (2025-13-45): the calendar
    // would roll them over, so a read-back that no longer matches means "not a date".
    let back = cal.dateComponents([.year, .month, .day], from: date)
    guard back.year == p[0], back.month == p[1], back.day == p[2] else { return nil }
    // UTC midnight is an exact multiple of a day, so this division is whole.
    return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
}

/// Days since the epoch for a local Date's calendar day. `todayNumber` in lib/time.ts.
/// Reads `now`'s local year/month/day, then counts to that day as if it were UTC
/// midnight, so it lines up with the UTC-anchored `dayNumber` above.
func todayNumber(_ now: Date) -> Int {
    let local = Calendar.current.dateComponents([.year, .month, .day], from: now)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    var c = DateComponents()
    c.year = local.year; c.month = local.month; c.day = local.day
    guard let date = cal.date(from: c) else { return 0 }
    return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
}

/// How far through the semester we are. `TermProgress` in lib/time.ts.
struct TermProgress: Equatable {
    /// "before" the term starts, "during" it, or "after" it ends.
    enum Phase: String { case before, during, after }
    var phase: Phase
    /// Whole days in the term, both endpoints counted.
    var totalDays: Int
    /// Days elapsed including today, clamped to the term's length.
    var elapsedDays: Int
    /// Days left including today, clamped to the term's length.
    var remainingDays: Int
    /// 0 to 1, for a progress bar.
    var fraction: Double
    /// 1-based teaching week, clamped to the term's length.
    var week: Int
    /// Total weeks the term spans.
    var totalWeeks: Int
}

/// Where `now` falls inside a semester. `termProgress` in lib/time.ts. Returns nil
/// unless both dates are set the right way round: a half-configured term has
/// nothing meaningful to report, and an inverted one (end before start) is a typo.
func termProgress(_ start: String?, _ end: String?, _ now: Date) -> TermProgress? {
    // `flatMap` runs dayNumber only when the string is present, and keeps the nil
    // when it is absent or not a real date.
    let s = start.flatMap(dayNumber)
    let e = end.flatMap(dayNumber)
    guard let s, let e, e >= s else { return nil }

    let today = todayNumber(now)
    let totalDays = e - s + 1
    let totalWeeks = Int((Double(totalDays) / 7).rounded(.up))

    // Keep every count inside the term's own length.
    func clamp(_ v: Int) -> Int { min(max(v, 0), totalDays) }
    let elapsedDays = clamp(today - s + 1)

    // `week` can only be read once today is on or after the start, so the integer
    // division below is never negative in the "during"/"after" cases; the `max(_, 1)`
    // covers the "before" case, where the number is meaningless and is pinned to 1.
    let phase: TermProgress.Phase = today < s ? .before : (today > e ? .after : .during)
    return TermProgress(
        phase: phase,
        totalDays: totalDays,
        elapsedDays: elapsedDays,
        remainingDays: clamp(e - today + 1),
        fraction: Double(elapsedDays) / Double(totalDays),
        week: min(max((today - s) / 7 + 1, 1), totalWeeks),
        totalWeeks: totalWeeks
    )
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Assignment+Deadline.swift` (new file)

This one lives **outside** `Logic/`, because it needs the `Assignment` model. Keeping the model out of `Logic/` is what lets the two files above test on Linux on their own.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Assignment+Deadline.swift
//  Phase:   2 (time and deadline logic)
//  Ports:   lib/store.tsx (taskDeadline, taskDueAt, byDeadline)
//
//  Summary: Teaches the Assignment model to speak the Deadline logic's language.
//           This lives outside Logic/ because it needs the model; the pure
//           functions in Logic/Deadline.swift stay model-free so they test on Linux.
//

import Foundation

/// Assignment already stores `due` and `dueTime`, so it satisfies the `Dated`
/// protocol with nothing to add. This empty extension just declares that it does,
/// which lets every function in Deadline.swift accept an Assignment directly.
extension Assignment: Dated {}

extension Assignment {
    /// The assignment's deadline as one value. `taskDeadline(task)` in lib/store.tsx:
    /// screens read this instead of poking at `due` and `dueTime` separately.
    var deadline: Deadline { deadlineOf(self) }

    /// The instant it stops being on time, or nil when undated. `taskDueAt` in the web app.
    var dueInstant: Date? { dueAt(self) }
}

/// Earliest deadline first, undated last, ties broken by title so the order is
/// stable. `byDeadline` in lib/store.tsx. Shaped for `sorted(by:)`, which wants a
/// closure that answers "does a come before b?", so it returns a Bool, not the
/// -1/0/1 that `compareDeadlines` returns. The Tasks screen (Phase 4) sorts with it.
func byDeadline(_ a: Assignment, _ b: Assignment) -> Bool {
    let order = compareDeadlines(a.deadline, b.deadline)
    if order != 0 { return order < 0 }
    // Same deadline: fall back to the title, compared the way a person reads it.
    return a.title.localizedCompare(b.title) == .orderedAscending
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/AssignmentsView.swift` (replaces the file)

Only `deadlineText` changes. The whole file is shown so nothing lands in the wrong place.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/AssignmentsView.swift
//  Phase:   2 (time and deadline logic)  [was Phase 1]
//  Ports:   app/tasks/page.tsx (a first, plain list; Phase 4 builds the real screen)
//
//  Summary: Lists every assignment with its class and deadline. Tapping a row
//           completes it, and the change is saved on the phone. The deadline is
//           now friendly text ("Tomorrow", "In 5 days · 10:00 AM") from the
//           ported lib/deadline.ts helper, instead of the raw stored strings.
//

import SwiftUI

/// The Tasks tab, for now a simple list.
struct AssignmentsView: View {
    /// Reads the shared store that ClassPingApp put into the environment.
    @Environment(Store.self) private var store

    var body: some View {
        List {
            // Only shown when the last save failed. Never hide a failed save.
            if store.lastSaveFailed {
                Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                    .foregroundStyle(.red)
            }

            // One row per assignment. A Button makes the whole row tappable.
            ForEach(store.assignments) { assignment in
                Button {
                    store.toggleAssignment(assignment.id)
                } label: {
                    row(for: assignment)
                }
                .foregroundStyle(.primary)   // keep the text black/white, not button blue
            }
        }
    }

    /// What one row shows: the title, then the class and the deadline.
    private func row(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assignment.title)
                .font(.headline)
                // Completed work is struck through, like the web's done rows.
                .strikethrough(assignment.done)
            Text("\(courseName(for: assignment)) · \(deadlineText(for: assignment))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// The short name of the class an assignment belongs to, or "Inbox" when it has none.
    private func courseName(for assignment: Assignment) -> String {
        // `first(where:)` walks the courses and stops at the first match. It returns
        // an optional, because there might be no match.
        let course = store.courses.first(where: { $0.id == assignment.courseID })
        // `?.short ?? "Inbox"`: use the course's short name if there is a course,
        // otherwise the word the web app uses for unfiled work.
        return course?.short ?? "Inbox"
    }

    /// The deadline in friendly words.
    /// CHANGED in Phase 2: the hand-rolled "due <date>" text is gone. The row now
    /// asks the ported lib/deadline.ts helper, through the model's `deadline`
    /// property, for the same label the web app shows. `.now` is the current
    /// instant, so "Today" and "Overdue" are judged against the real clock.
    private func deadlineText(for assignment: Assignment) -> String {
        formatDeadline(assignment.deadline, .now)
    }
}
```

## 5. Run it

```bash
xtool dev build
xtool dev
git add . && git commit -m "Phase 2: time and deadline logic"
```

On the phone, open **Tasks** and read the second line of each row:

- "Midterm 2" shows **In 5 days · 10:00 AM** (it is five days out with an exact time).
- "Email advisor about spring classes" shows **Inbox · No deadline**.
- The two completed items ("Midterm study guide", "Reflection journal") are dated in the past, so they show **2 days overdue** / **1 day overdue** (completing them doesn't change the label yet; that's Phase 4).
- The near ones read **Tomorrow**, **In 2 days**, **In 3 days**.

(The exact day counts shift as real time passes, because the sample dates are built relative to today.)

## 6. Done when

- [ ] `xtool dev build` finishes with no warnings.
- [ ] Each Tasks row shows a friendly deadline: "Tomorrow", "In 3 days", "In 5 days · 10:00 AM", "No deadline", or "N days overdue".
- [ ] The Inbox item reads "No deadline", never "Today" and never a made-up time.
- [ ] A task due earlier today with a time reads "Overdue · <time>", while an all-day task due today reads "Today".
- [ ] `Logic/` holds exactly two files, `Deadline.swift` and `Time.swift`, and neither imports SwiftUI.

(Claude's side, already done for you: `logic-test.sh` passes 43 tests, `build-check.sh` is `BUILD_OK` with no warnings, and Phase 1's `persistence-test.sh` still passes.)

## 7. If it breaks

- **`cannot find 'Deadline' in scope`** in `Assignment+Deadline.swift` or the view: `Deadline.swift` wasn't typed yet, or the folder name is wrong. The file must be under `Sources/ClassPing/Logic/`, and SwiftPM only sees it once it is saved there.
- **`type 'Assignment' does not conform to protocol 'Dated'`**: check that `Assignment` in `Models.swift` still has both `var due: String?` and `var dueTime: String?`. The protocol needs those two exact names.
- **`value of optional type 'String?' must be unwrapped`** around `d.time`: you likely wrote `formatTime(d.time)` directly. Keep the `d.time.map { ... } ?? ""` form, which only formats the time when there is one.
- **Every deadline prints as "No deadline":** the row is building a `Deadline` with an empty `date`. Make sure `deadlineText` calls `formatDeadline(assignment.deadline, .now)`, and that `assignment.deadline` comes from the `Assignment+Deadline.swift` extension.

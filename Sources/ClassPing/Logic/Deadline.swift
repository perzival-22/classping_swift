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
/// 
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

//the deadline if something nobody has schedule yet.
 let UNDATED = Deadline(date: nil, time: nil)

 /// The sentinel the old web task forms wrote when the time picker was left empty.
/// A legacy `due` that ends at 23:59 local was never an 11:59pm deadline, it was
/// "no time given", so `parseLegacyDue` reads it back as all-day, not exact.

private let legacyAllDaySentinel = "23:59"
/// True when `s` matches `pattern` anywhere. The patterns below are anchored with
/// `^...$`, so this is really a whole-string test.
/// `range(of:options:.regularExpression)` is Foundation's regex match: it gives
/// back the matched range, or nil when there is no match.
/// 
private func matches(_ s: String, _ pattern: String) -> Bool {
    s.range(of: pattern, options: .regularExpression) != nil
}

/// True when `v` is a real "yyyy-MM-dd" date. `isValidDate` in lib/deadline.ts.
/// Rejects impossible days that still have the right shape, like "2026-02-31".
/// 
func isValidDate(_ v: String?) -> Bool {
    //First the shape: four digits, a dash, two, a dash, two
guard let v, matches(v, #"^\d{4}-\d{2}-\d{2}$"#) else { return false }
    // Then the reality check. Build the date in a fixed Gregorian/UTC calendar so
    // no time zone or daylight-saving edge can move it, then read the components
    // back. If Feb 31 was asked for, the calendar rolls it to Mar 3 and the read
    // back no longer matches, which is how an impossible day is caught.

    let p = v.split(separator: "-").map {Int($0) ?? -1}
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    var c = DateComponents()
    c.year = p[0]; c.month = p[1]; c.day = p[2]
    guard let date = cal.date(from: c) else { return false}
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
    guard isValidDate(date) else { return UNDATED}
    return Deadline(date: date, time: isValidTime(time) ? time : nil)
}

/// Read whatever an older `due` string held and say what it actually meant.
/// `parseLegacyDue` in lib/deadline.ts. The phone never wrote the legacy shapes
/// itself, but a restored web backup can still contain them, so the meaning has
/// to be recovered the same way the web app recovers it.
/// 
func parseLegacyDue(_ due: String?) -> Deadline {
    //nothing, or only spaces, means undated
    guard let raw0 = due else { return UNDATED}
    let raw = raw0.trimmingCharacters(in: .whitespaces)
    if raw.isEmpty { return UNDATED}
    // Already a bare calender day: all-day, with no time to recover
    if matches(raw, #"^\d{4}-\d{2}-\d{2}$"#) { return makeDeadline(raw, nil) }

    // Otherwise it should be a full ISO timestamp the old form built in local time
    // with `new Date(...).toISOString()`. Parse it back to the instant it names,
    // then read its local day and time, which is exactly what the student typed.

    guard let parsed = parseISOInstant(raw) else { return UNDATED}
    let date = dayOf(parsed)
    let time = timeOf(parsed)
    //The old 'no time picked' sentinel means all day

    if time == legacyAllDaySentinel { return makeDeadline(date, nil) }
    return makeDeadline(date, time)
}

/// Parse an ISO-8601 instant like "2026-09-07T23:30:00.000Z". `new Date(raw)` in
/// the web app did this. Tries with fractional seconds first (what toISOString
/// always writes), then without, and gives back nil for anything else.
/// 
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
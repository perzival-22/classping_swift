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
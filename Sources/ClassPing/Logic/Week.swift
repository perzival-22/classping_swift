//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Week.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   weekInfo and fmtMD from lib/store.tsx; isWithinTerm and
//           termRangeLabel from lib/time.ts; the week labels, hour labels
//           and grid bounds from app/week/page.tsx
//
//  Summary: Monday-to-Sunday week maths for the strip and the grid on Today:
//           which seven days a week holds, whether a day is inside the
//           semester, and the labels the week shows. Also home to the one
//           helper that turns Apple's weekday numbers into ClassPing's.
//

import Foundation

// MARK: - Days of the week

/// A date's day of the week in ClassPing's numbering: 0 = Monday ... 6 = Sunday.
/// This is the ONE place Apple's numbering is converted (IOS_APP.md 3.4):
/// `Calendar` says 1 = Sunday, 2 = Monday ... 7 = Saturday. Adding 5 and
/// taking the remainder after 7 shifts that so Monday lands on 0:
/// Monday 2 -> 0, Saturday 7 -> 5, Sunday 1 -> 6. The web writes the same
/// shift as `(getDay() + 6) % 7`, because JavaScript counts Sunday as 0.
func dayIndex(of date: Date) -> Int {
    let apple = Calendar.autoupdatingCurrent.component(.weekday, from: date)
    return (apple + 5) % 7
}

/// A time of day as minutes from midnight: 10:40 AM -> 640. The unit every
/// class time uses, so the grid can compare "now" with a class's start.
func minuteOfDay(_ date: Date) -> Int {
    let c = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

// MARK: - Weeks

/// The week the planner shows: its seven days and which column is today.
/// `weekInfo` in lib/store.tsx.
struct WeekInfo: Equatable {
    var dates: [Date]     // seven local midnights, Monday first
    var todayCol: Int     // 0 = Monday ... 6 = Sunday
}

/// The Monday-to-Sunday week that contains `now`. `weekInfo` in lib/store.tsx.
func weekInfo(_ now: Date) -> WeekInfo {
    WeekInfo(dates: weekDates(now, 0), todayCol: dayIndex(of: now))
}

/// The seven days of the week `offset` weeks away from `now`'s week:
/// 0 = this week, 1 = next week, -1 = last week. Each is local midnight.
/// The week page builds this from weekInfo's Monday plus 7 × offset days.
/// `scheduleDate` (Phase 2) does the calendar-aware day steps, so a
/// daylight-saving change can't knock a day off.
func weekDates(_ now: Date, _ offset: Int) -> [Date] {
    // Step back to this week's Monday, then whole weeks forward or back.
    let monday = scheduleDate(now, offset * 7 - dayIndex(of: now))
    // `(0..<7).map` makes the seven days, Monday + 0 ... Monday + 6.
    return (0..<7).map { scheduleDate(monday, $0) }
}

/// The week's big heading. `weekLabel` in app/week/page.tsx.
func weekTitle(_ offset: Int) -> String {
    // A `switch` can hand back a value directly. `case let n where n > 0`
    // matches any remaining number above zero and names it `n`.
    switch offset {
    case 0: "This Week"
    case 1: "Next Week"
    case -1: "Last Week"
    case let n where n > 0: "In \(n) Weeks"
    default: "\(-offset) Weeks Ago"
    }
}

/// The small caps line above it: "OCT 19 – 25", or "OCT 26 – NOV 1" when the
/// week crosses into a new month. `rangeLabel` in app/week/page.tsx.
func weekRangeLabel(_ dates: [Date]) -> String {
    guard let first = dates.first, let last = dates.last else { return "" }
    let cal = Calendar.autoupdatingCurrent
    // "Oct", in English whatever the phone's language, like the web's "en-US".
    let month = DateFormatter()
    month.locale = Locale(identifier: "en_US_POSIX")
    month.dateFormat = "MMM"
    let startMonth = month.string(from: first).uppercased()
    // The month only repeats after the dash when it changes.
    let sameMonth = cal.component(.month, from: first) == cal.component(.month, from: last)
    let endMonth = sameMonth ? "" : month.string(from: last).uppercased() + " "
    return "\(startMonth) \(cal.component(.day, from: first)) – \(endMonth)\(cal.component(.day, from: last))"
}

/// "Jul 6" for a date. `fmtMD` in lib/store.tsx.
func fmtMD(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d"
    return f.string(from: d)
}

// MARK: - The semester

/// Does `date` fall inside the semester? `isWithinTerm` in lib/time.ts.
/// True when no term is set, and true for whichever half is set: the dates
/// exist to *bound* a timetable, never to hide one by accident. An inverted
/// range (end before start) is a typo, so it's ignored too.
func isWithinTerm(_ start: String?, _ end: String?, _ date: Date) -> Bool {
    // `flatMap` runs dayNumber (Phase 2) only on a present string, and keeps
    // nil for a missing or broken date.
    let s = start.flatMap(dayNumber)
    let e = end.flatMap(dayNumber)
    if let s, let e, e < s { return true }
    let day = todayNumber(date)
    if let s, day < s { return false }
    if let e, day > e { return false }
    return true
}

/// "Sep 1 – Dec 15", for telling you which window you're outside of.
/// "from Sep 1" or "until Dec 15" when only one end is set, nil when neither.
/// `termRangeLabel` in lib/time.ts.
func termRangeLabel(_ start: String?, _ end: String?) -> String? {
    let s = start.flatMap(monthDay)
    let e = end.flatMap(monthDay)
    // Switching on a pair. `s?` matches "s has a value" and unwraps it.
    switch (s, e) {
    case let (s?, e?): return "\(s) – \(e)"
    case let (s?, nil): return "from \(s)"
    case let (nil, e?): return "until \(e)"
    default: return nil
    }
}

/// "2026-09-01" -> "Sep 1". Read as a calendar day in UTC (like the web's
/// `timeZone: "UTC"`), so no time zone can move it to the 31st. Nil when the
/// string isn't a real date.
private func monthDay(_ iso: String) -> String? {
    guard let n = dayNumber(iso) else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "MMM d"
    // dayNumber counts days since 1 Jan 1970, so this is that day's UTC midnight.
    return f.string(from: Date(timeIntervalSince1970: Double(n) * 86_400))
}

// MARK: - The grid

/// The grid's usual hours: 8 AM to 5 PM. `DEFAULT_START_HOUR` / `DEFAULT_END_HOUR`.
let defaultStartHour = 8
let defaultEndHour = 17

/// The first and last hour lines the grid draws. It hugs the timetable: a
/// 7:30 AM lecture or a 6 PM seminar stretches it, so nothing is drawn off
/// the grid. `startHour` / `endHour` in app/week/page.tsx.
func gridHours(_ meetings: [ClassMeeting]) -> ClosedRange<Int> {
    // The earliest start, rounded down to its hour; the latest end, rounded up.
    // `.min()` and `.max()` are nil for an empty list, hence the defaults.
    let earliest = meetings.map { $0.start / 60 }.min() ?? defaultStartHour
    let latest = meetings.map { ($0.end + 59) / 60 }.max() ?? defaultEndHour
    return min(defaultStartHour, earliest)...max(defaultEndHour, latest)
}

/// The number beside an hour line: 8, 9 ... 12, then 1, 2 for the afternoon.
func hourLabel(_ hour: Int) -> String {
    "\(hour % 12 == 0 ? 12 : hour % 12)"
}

/// A class block's start time without AM/PM, "9:00", the way the grid
/// prints it (the web cuts " AM" / " PM" off `fmtHM`).
func fmtClock(_ mins: Int) -> String {
    // fmtTime (Phase 2) always ends in " AM" or " PM": drop those 3 characters.
    String(fmtTime(mins).dropLast(3))
}

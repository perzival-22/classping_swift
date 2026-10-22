//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ServerValues.swift
//  Phase:   14b (the row mapping)
//  Ports:   the helpers of lib/supabase/map.ts (`toDate`, the `toISOString`
//           and `Date.parse` it does on every moment) and of lib/feeds.ts
//           (`feedLabelFromUrl`, `MAX_FEEDS`, the feed URL check)
//
//  Summary: The small conversions every server row needs. A moment goes to
//           the server as text like "2026-09-21T14:13:20.000Z" and comes back
//           as "2026-09-21T14:13:20.123456+00:00"; a day goes as "yyyy-MM-dd".
//           Moments keep whole seconds on the phone (D-73), so a row read and
//           written again says the same thing. Foundation only.
//

import Foundation

// MARK: - Moments

/// A moment the way the web sends one: `new Date(ms).toISOString()`, always
/// UTC, always three decimals. The phone keeps whole seconds (D-73), so the
/// decimals are always ".000"; the fraction a `Date` may carry is dropped
/// toward the past, as `webMillis` (11b+c) drops it.
func serverInstant(_ date: Date) -> String {
    let seconds = Int(date.timeIntervalSince1970.rounded(.down))
    // Whole days since 1970 and the seconds left in the day. Dividing a
    // negative number rounds toward zero in Swift, so the `if` pulls a moment
    // before 1970 back into the day it belongs to.
    var days = seconds / 86_400
    var rest = seconds % 86_400
    if rest < 0 {
        days -= 1
        rest += 86_400
    }
    let (year, month, day) = civilFromDays(days)
    return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))T"
        + "\(pad(rest / 3600, 2)):\(pad(rest / 60 % 60, 2)):\(pad(rest % 60, 2)).000Z"
}

/// A moment read from the server, to the whole second, or nil when the text
/// isn't one. The web reads these with `Date.parse`; this accepts the same
/// shapes the server and the web write: a day and a time joined by "T" or a
/// space, any number of decimals (dropped), and "Z", "+05:30", "+0530" or
/// "+00" for the zone. Like `Date.parse` it also takes a bare day (midnight
/// UTC) and a time with no zone (your own clock), and lets an impossible day
/// such as February 30 roll into the next month instead of refusing it.
func instantFromServer(_ text: String?) -> Date? {
    guard let text else { return nil }
    // A regex literal with captures, as in 13a. `(?:...)` groups without
    // capturing, `?` after a group makes it optional.
    let shape = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|[+-]\d{2}(?::?\d{2})?)?)?$/
    guard let m = text.wholeMatch(of: shape),
          let year = Int(m.1), let month = Int(m.2), let day = Int(m.3),
          (1...12).contains(month), (1...31).contains(day) else { return nil }
    let hour = m.4.flatMap { Int($0) } ?? 0
    let minute = m.5.flatMap { Int($0) } ?? 0
    let second = m.6.flatMap { Int($0) } ?? 0
    guard (0...24).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { return nil }
    let clock = hour * 3600 + minute * 60 + second

    // A bare day is midnight UTC; so is a time with a "Z".
    if m.4 == nil || m.7 == "Z" {
        return Date(timeIntervalSince1970: Double(daysFromCivil(year, month, day) * 86_400 + clock))
    }
    // An offset like "-04:00" says how far that clock was from UTC.
    if let zone = m.7 {
        let digits = zone.dropFirst().filter(\.isNumber)
        let hours = Int(digits.prefix(2)) ?? 0
        let minutes = Int(digits.dropFirst(2)) ?? 0
        let offset = (hours * 3600 + minutes * 60) * (zone.hasPrefix("-") ? -1 : 1)
        return Date(timeIntervalSince1970: Double(daysFromCivil(year, month, day) * 86_400 + clock - offset))
    }
    // No zone at all: your own clock, as `Date.parse` reads it. Calendar is
    // lenient, so day 30 of February rolls over here too.
    let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    return Calendar.autoupdatingCurrent.date(from: parts)
}

/// Days since 1970-01-01 for a calendar day, the well-known "days from
/// civil" sum: it counts years from March so February's length only matters
/// at the end. A day past the month's end just keeps counting, which is how
/// an impossible day rolls into the next month.
private func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
    let y = m <= 2 ? y0 - 1 : y0
    let era = (y >= 0 ? y : y - 399) / 400
    let yearOfEra = y - era * 400
    let dayOfYear = (153 * ((m + 9) % 12) + 2) / 5 + d - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    return era * 146_097 + dayOfEra - 719_468
}

/// The calendar day for a count of days since 1970: the sum above, backwards.
private func civilFromDays(_ z0: Int) -> (Int, Int, Int) {
    let z = z0 + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let dayOfEra = z - era * 146_097
    let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
    let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
    let mp = (5 * dayOfYear + 2) / 153
    let day = dayOfYear - (153 * mp + 2) / 5 + 1
    let month = mp < 10 ? mp + 3 : mp - 9
    return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
}

/// A number with zeros in front, `pad(7, 2)` is "07".
private func pad(_ n: Int, _ width: Int) -> String {
    let digits = String(n)
    return String(repeating: "0", count: max(0, width - digits.count)) + digits
}

// MARK: - Days

/// A day the way a Postgres `date` column holds it: the first ten characters
/// ("2026-09-01T12:00:00.000Z" becomes "2026-09-01"), or nil for nothing.
/// The web's `toDate` in lib/supabase/map.ts.
func serverDay(_ text: String?) -> String? {
    guard let text, !text.isEmpty else { return nil }
    return String(text.prefix(10))
}

// MARK: - Calendar feeds

/// How many calendar feeds one account may save. `MAX_FEEDS`.
let MAX_FEEDS = 5

/// A feed link the app will keep: it starts "http://" or "https://", in any
/// case. The web's `/^https?:\/\//i`.
func isFeedURL(_ url: String) -> Bool {
    let lower = url.lowercased()
    return lower.hasPrefix("http://") || lower.hasPrefix("https://")
}

/// A readable name for a feed link: its host, without "www.", in lower case
/// (a browser's URL does that), or "Calendar feed". Never the whole link,
/// which often carries a private token. `feedLabelFromUrl` in lib/feeds.ts.
func feedLabelFromURL(_ url: String) -> String {
    guard let host = URL(string: url)?.host?.lowercased(), !host.isEmpty else { return "Calendar feed" }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
}

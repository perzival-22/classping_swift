//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Planning.swift
//  Phase:   4a (task logic and the add form), changed in 7b (study minutes)
//  Ports:   lib/planning.ts (`nextRepeatDate`, and since 7b `studyMinutes`)
//
//  Summary: Works out the next due day of a repeating assignment: a week
//           later, or the same day next month, clamped to the month's last day
//           (Jan 31 repeats on Feb 28, or Feb 29 in a leap year). Since 7b it
//           also totals the minutes of focused work recorded against a task.
//
//  Foundation only, so tools/logic-test.sh can test it on Linux.
//
//  Not ported (and why, D-31): `localDateKey` is `dayOf` in Deadline.swift.
//  `normalizeTaskPlans` and `normalizeStudySessions` repair merged or
//  restored data, so they arrive with backup restore (Phase 11) and sync
//  (Phase 14). `plansForDate` and `priorityPlans` have no caller (D-23).
//

import Foundation
// The next due day after `date` ("yyyy-MM-dd") for a task that repeats
/// `rule` ("weekly" or "monthly"), or nil when the date is broken or the rule
/// is unknown. `nextRepeatDate` in lib/planning.ts.
/// The rule arrives as text because `Assignment.RepeatRule` lives in
/// Models.swift; the store passes `rule.rawValue`.
func nextRepeatDate(_ date: String, _ rule: String) -> String? {
    //refusing anything that isnt a real calender date
    guard isValidDate(date) else {return nil}

    //pull out the three numbers. 'isValidDate' proves there are three

    let p = date.split(separator: "-").map { Int($0) ?? 0}
    let (year, month, day) = (p[0], p[1], p[2])
    // Do the calendar maths in a fixed Gregorian calendar on UTC, so no time
    // zone or daylight-saving change can nudge the day (a pure day count,
    // the way the web avoids UTC parsing).

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current

    //weekly: seven dats on : date(byAdding:) handles month and year ends.
    if rule == "weekly" {
        let start = cal.date(from: DateComponents(year: year, month: month, day: day))
        guard let start, let next = cal.date(byAdding: .day, value: 7, to: start) else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: next)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // Monthly: the same day number next month, or that month's last day if the
    // month is shorter. December rolls into January of the next year.
    if rule == "monthly" {
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        // How many days the next month has: ask the calendar for the range of
        // day numbers in the month containing its 1st.
        let first = cal.date(from: DateComponents(year: nextYear, month: nextMonth, day: 1))
        guard let first, let days = cal.range(of: .day, in: .month, for: first) else { return nil }
        return String(format: "%04d-%02d-%02d", nextYear, nextMonth, min(day, days.count))
    }

    // Any other rule: no next date.
    return nil
}

// MARK: - Study records
// NEW in Phase 7b

/// Anything that records one finished block of focused work. `StudySession`
/// (Records.swift) signs up in Models+Reminders.swift: Logic files can't see
/// the models, so `studyMinutes` asks for this instead, the same trick as
/// `Dated` in Phase 2.
protocol StudyRecord {
    var assignmentID: UUID? { get }
    var courseID: UUID? { get }
    var minutes: Int { get }
    var completedAt: Date { get }
}

/// Minutes of focused work in `sessions`, optionally only for one task, one
/// class, or since a moment. `studyMinutes` in lib/planning.ts. A filter
/// left as nil lets everything through.
func studyMinutes<S: StudyRecord>(_ sessions: [S], taskID: UUID? = nil,
                                  courseID: UUID? = nil, since: Date? = nil) -> Int {
    sessions
        .filter { s in
            // `taskID.map { ... } ?? true` reads: if there is a taskID, does
            // this session match it? If there's none, it passes.
            (taskID.map { s.assignmentID == $0 } ?? true)
                && (courseID.map { s.courseID == $0 } ?? true)
                && (since.map { s.completedAt >= $0 } ?? true)
        }
        // Add up what's left. `reduce` starts at 0 and adds each session's minutes.
        .reduce(0) { total, s in total + s.minutes }
}

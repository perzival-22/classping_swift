//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Streak.swift
//  Phase:   6b (Today: your work and your classes)
//  Ports:   lib/streak.ts (termStats, the "term at a glance" numbers)
//
//  Summary: Four gentle numbers for the top of Today's lists: how much you've
//           completed, how much is due in the next week, how much is overdue,
//           and how many days in a row nothing has been overdue. Worked out
//           from the assignments alone, so nothing new is stored or synced.
//

import Foundation

/// Anything with a deadline that can be completed. A protocol can build on
/// another one: `Completable: Dated` means "everything `Dated` asks for
/// (`due` and `dueTime`), plus `done`". Logic files can't see the
/// Assignment model (they compile alone for the Linux tests), so termStats
/// asks for this instead, and Assignment+Deadline.swift says Assignment fits.
protocol Completable: Dated {
    var done: Bool { get }
}

/// The four numbers. `TermStats` in lib/streak.ts.
struct TermStats: Equatable {
    /// Assignments ticked off, ever.
    var completed: Int
    /// Open items already past their deadline.
    var overdue: Int
    /// Open items due in the next 7 days.
    var dueThisWeek: Int
    /// Days in a row, up to today, with nothing overdue. At most 365.
    var streak: Int
}

/// A day and a week in seconds. The web counts fixed 24-hour days in
/// milliseconds (`DAY_MS`); this does the same in seconds so both apps get
/// the same answer, daylight-saving days included.
private let daySeconds: TimeInterval = 86_400

/// Looking further back than a school year tells us nothing. `MAX_STREAK_DAYS`.
private let maxStreakDays = 365

/// Was anything overdue when `dayEnd` arrived? Something counts if it was due
/// before then and is still not done. Completion times aren't recorded, so a
/// finished task counts as never having been late: generous on purpose.
/// `hadOverdue` in lib/streak.ts.
private func hadOverdue<T: Completable>(_ tasks: [T], _ dayEnd: Date) -> Bool {
    tasks.contains { t in
        // `guard` inside a closure: leave this one item early with `false`.
        guard !t.done, let at = dueAt(t) else { return false }
        return at < dayEnd
    }
}

/// The glance numbers for a list of work at `now`. `termStats` in lib/streak.ts.
/// The streak counts days with nothing overdue, not days of perfect work, so
/// a student who has fallen behind can always restart it by catching up.
func termStats<T: Completable>(_ tasks: [T], _ now: Date) -> TermStats {
    let today = Calendar.current.startOfDay(for: now)

    // Count the first three numbers in one pass. Undated work (Inbox) is
    // neither overdue nor due this week: it's waiting to be scheduled, and
    // counting it either way would misreport the term.
    var completed = 0
    var overdue = 0
    var dueThisWeek = 0
    for t in tasks {
        if t.done {
            completed += 1
        } else if let at = dueAt(t) {
            if at < now {
                overdue += 1
            } else if at.timeIntervalSince(now) <= 7 * daySeconds {
                dueThisWeek += 1
            }
        }
    }

    // Only count back as far as you've actually been using the app: from the
    // earliest deadline on any task. Without this, two finished tasks would
    // claim a year of clear days. `compactMap` keeps only the non-nil dates,
    // and `.min()` is the earliest, or nil when nothing has a deadline.
    let daysInUse: Int
    if let earliest = tasks.compactMap({ dueAt($0) }).min() {
        let span = (today.addingTimeInterval(daySeconds).timeIntervalSince(earliest)) / daySeconds
        daysInUse = max(1, Int(span.rounded(.up)))
    } else {
        daysInUse = 0
    }
    let limit = min(maxStreakDays, daysInUse)

    // Walk back a day at a time while each day ended clean. The web stops
    // its loop with `break`; here the `while` condition does the stopping,
    // so the loop simply ends at the first day that ended with work overdue.
    var streak = 0
    while streak < limit
            && !hadOverdue(tasks, today.addingTimeInterval(daySeconds - Double(streak) * daySeconds)) {
        streak += 1
    }

    return TermStats(completed: completed, overdue: overdue,
                     dueThisWeek: dueThisWeek, streak: streak)
}

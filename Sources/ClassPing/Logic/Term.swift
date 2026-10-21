//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Term.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the lines under the dates in `CurrentTerm` (app/settings/page.tsx)
//
//  Summary: What the Semester card says under the two dates: whether your
//           classes are limited to the window, how far through the term you
//           are, or what's missing. Foundation only, so it can be tested.
//           Fixes the web's "Starts in" count, which always said 1 day (D-69).
//

import Foundation

/// The words and the bar under the Semester card's dates.
struct TermNote: Equatable {
    /// Show "Your classes only appear inside this window…".
    var showsWindow: Bool
    /// The bar's fill, 0 to 1, or nil when there's no bar.
    var fraction: Double?
    /// The line under the bar, or under the dates when there's no bar.
    var line: String
}

/// The line the window note uses, word for word from the web.
let TERM_WINDOW_NOTE = "Your classes only appear inside this window, on Today, on the week grid, and in the calendar you export to your phone."

/// What to say for these dates ("yyyy-MM-dd" or nil) on the day `now` falls.
func termNote(start: String?, end: String?, now: Date) -> TermNote {
    let progress = termProgress(start, end, now)
    // Both dates there but no progress means the end is before the start.
    let inverted = start != nil && end != nil && progress == nil
    let showsWindow = (start != nil || end != nil) && !inverted

    guard let progress else {
        let line = inverted
            ? "The end date is before the start date, check the dates."
            : "Set both dates to see how far through the semester you are. They're printed on your grade report too."
        return TermNote(showsWindow: showsWindow, fraction: nil, line: line)
    }

    let line: String
    switch progress.phase {
    case .before:
        // Days from today to the first day. The web counts
        // `totalDays - remainingDays + 1`, which is 1 whenever the term
        // hasn't started, so it always said "Starts in 1 day" (D-69).
        let days = (start.flatMap(dayNumber) ?? 0) - todayNumber(now)
        line = "Starts in \(days) \(days == 1 ? "day" : "days"), \(progress.totalWeeks) \(progress.totalWeeks == 1 ? "week" : "weeks") long."
    case .after:
        line = "This term has ended. Archive it below to clear your timetable."
    case .during:
        let left = progress.remainingDays
        line = "Week \(progress.week) of \(progress.totalWeeks) \u{00B7} \(left) \(left == 1 ? "day" : "days") to go."
    }
    return TermNote(showsWindow: showsWindow, fraction: progress.fraction, line: line)
}

/// A "yyyy-MM-dd" day as the start of that day here, for a date picker, or
/// nil when it isn't a real day.
func dayStart(_ day: String?) -> Date? {
    deadlineDayStart(makeDeadline(day, nil))
}

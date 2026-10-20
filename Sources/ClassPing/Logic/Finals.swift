//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Finals.swift
//  Phase:   9c (finals countdown and the CSV report)
//  Ports:   the countdown maths and words of components/FinalsCountdown.tsx
//
//  Summary: How many days until finals, and what the card says about it:
//           "51 days", "Today" or "Done", each with the web's sentence.
//           Counts calendar days on your own clock, so finals day is always
//           "Today" (D-56).
//

import Foundation

/// What the Days to Finals card shows for one finals date on one day.
/// The web works these out inline in its markup. One value keeps the number,
/// its word and the sentence from disagreeing.
struct FinalsStatus: Equatable {
    /// Whole calendar days from today to finals: 0 on the day, negative after.
    var days: Int
    /// The big text: the number of days, "Today" or "Done".
    var headline: String
    /// "days" or "day" beside the number. Nil for "Today" and "Done".
    var unit: String?
    /// The line under it, like "Finals begin Thursday, Dec 10. You've got this."
    var message: String
}

/// The countdown for a stored finals date ("yyyy-MM-dd") as of `now`, or nil
/// when there's no usable date, so the card asks for one instead.
///
/// The web's card has its own `daysUntil`, which reads "2026-12-10" with
/// `new Date(iso)`. That's midnight in London, so anywhere west of it (Maine
/// included) the count comes out a day short, and finals day itself says
/// "Done". This uses `daysUntil` from Logic/Deadline.swift instead: the same
/// calendar-day count a task's deadline uses (D-56).
func finalsStatus(_ finalsDate: String?, _ now: Date) -> FinalsStatus? {
    // The finals date as an all-day deadline. makeDeadline drops anything
    // that isn't a real day, and then daysUntil answers nil.
    let finals = makeDeadline(finalsDate, nil)
    guard let days = daysUntil(finals, now) else { return nil }
    // "Thursday, Dec 10": a task's long date, which has no time to add here.
    let day = longDeadline(finals)

    // A `switch` can match a number against ranges. `2...` means "2 or
    // more". Cases are tried top to bottom, and the first match wins.
    switch days {
    case 2...:
        return FinalsStatus(days: days, headline: "\(days)", unit: "days",
                            message: "Finals begin \(day). You've got this.")
    case 1:
        return FinalsStatus(days: 1, headline: "1", unit: "day",
                            message: "Finals are tomorrow, \(day).")
    case 0:
        return FinalsStatus(days: 0, headline: "Today", unit: nil,
                            message: "Finals are today. Good luck! 🍀")
    default:
        // Everything left is below zero: finals have been and gone.
        return FinalsStatus(days: days, headline: "Done", unit: nil,
                            message: "Finals were \(day). Set a new date for next term.")
    }
}

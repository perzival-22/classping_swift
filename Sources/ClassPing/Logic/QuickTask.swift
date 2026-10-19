//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/QuickTask.swift
//  Phase:   8d (notes that connect)
//  Ports:   QuickTaskCard in app/classes/page.tsx (the small card a note's
//           bell and plus open: which kinds it offers, the day it starts on,
//           when Add is allowed, and the title it files)
//
//  Summary: The rules behind filing a reminder or an assignment from a note
//           without leaving it. The class is already known (it's the note's),
//           so only the words, the day, a time if it matters and, for an
//           assignment, assignment, quiz or exam are left to choose.
//           Foundation only, so the Linux tests can run it.
//

import Foundation

/// Which card is open: the bell's (a reminder) or the plus's (an assignment).
/// The web's `mode`. `Identifiable` so a sheet can be opened with one:
/// `.sheet(item: $quick)` shows the sheet while `quick` holds a mode. An
/// enum with no values attached is already `Hashable`, so it can be its own
/// id: `var id: Self { self }`.
enum QuickTaskMode: Identifiable {
    case reminder, assignment

    var id: Self { self }
}

/// The three kinds the assignment card offers, in the web's order.
/// `ASSIGNMENT_TYPES`. The raw values are `Assignment.Kind`'s, and the web's
/// ids, which the fallback title uses as they are ("Chemistry quiz").
enum QuickTaskType: String, CaseIterable {
    case assignment, quiz, exam

    /// The segment's label: "Assignment", "Quiz", "Exam".
    var label: String { rawValue.capitalized }
}

/// How many days from today the card's date starts on. Reminders skew soon
/// (tomorrow), assignments a few days out. `dateInputValue(isReminder ? 1 : 3)`.
func quickTaskDaysAhead(_ mode: QuickTaskMode) -> Int {
    mode == .reminder ? 1 : 3
}

/// Whether Add can be tapped. A reminder needs its own words ("Bring
/// goggles"); an assignment can go without and take a made-up title. The
/// web's `canSave` also needs a date, which the phone's date picker can't
/// leave empty, so that half always holds here.
func quickTaskCanSave(_ mode: QuickTaskMode, title: String) -> Bool {
    mode == .assignment || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

/// The title that gets filed: what was typed, trimmed, or for a blank
/// assignment the class and the kind, "Chemistry quiz". `finalTitle` in
/// QuickTaskCard. A note with no class passes "Quick note", the name the
/// note's header shows, so a blank one is "Quick note assignment", as on the
/// web. ("Reminder" is the web's fallback for a reminder, which `canSave`
/// never lets through blank; kept so the two read alike.)
func quickTaskTitle(_ mode: QuickTaskMode, title: String, className: String,
                    type: QuickTaskType) -> String {
    let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    // Typed words always win.
    if !typed.isEmpty { return typed }
    return mode == .reminder ? "Reminder" : "\(className) \(type.rawValue)"
}

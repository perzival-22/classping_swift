//
//  File:    ~/ClassPing/Sources/ClassPing/Assignment+Deadline.swift
//  Phase:   2 (time and deadline logic), changed in 6b (Completable)
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

/// The same trick for Logic/Streak.swift: Assignment already has `done`, so
/// it is `Completable` too, and `termStats` can count real assignments.
// NEW in Phase 6b
extension Assignment: Completable {}

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

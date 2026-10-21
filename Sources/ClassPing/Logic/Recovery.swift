//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Recovery.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/recovery.ts (RECOVERY_RETENTION_DAYS, EntityKind,
//           TrashEntry, daysUntilPurge, isPurgeable) and the countdown line
//           of app/settings/deleted/page.tsx
//
//  Summary: The rules of Recently Deleted: a deleted item waits 30 days,
//           then it's gone for good. This file knows how long is left, what
//           one row of the list holds, and the order rows go in. Foundation
//           only, so the Linux tests can run it.
//

import Foundation

/// How long a deleted item can still be restored. `RECOVERY_RETENTION_DAYS`.
/// The web's server purges at the same age, so the two must stay equal.
let RECOVERY_RETENTION_DAYS = 30

/// The same window in seconds, the unit `Date` arithmetic uses.
/// The web counts in real 24-hour days (`86_400_000` ms), not calendar days,
/// so this does too.
let RECOVERY_RETENTION: TimeInterval = Double(RECOVERY_RETENTION_DAYS) * 86_400

/// The four kinds of thing that can be deleted. `EntityKind` in
/// lib/recovery.ts. The raw values are the web's words; Swift won't take
/// `class` as a case name, so that case is `course` with the raw value "class".
enum EntityKind: String, CaseIterable, Sendable {
    case course = "class"
    case assignment = "task"
    case grade
    case note

    /// The word on a Recently Deleted row. `KIND_META` in the web's page.
    var label: String {
        switch self {
        case .course: "Class"
        case .assignment: "Assignment"
        case .grade: "Grade"
        case .note: "Note"
        }
    }
}

/// One row of Recently Deleted. `TrashEntry` in lib/recovery.ts.
struct TrashEntry: Identifiable, Equatable, Sendable {
    let kind: EntityKind
    /// The deleted item's own id.
    let itemID: UUID
    /// What you'll recognise it by: the class name, the assignment's title.
    let title: String
    /// The class it belonged to, or a class's term, when there is one.
    let detail: String?
    let deletedAt: Date
    /// True when it went with its class. Restoring the class brings it back
    /// too, and the row says so instead of offering a Restore of its own.
    let viaClass: Bool

    /// Unique across kinds, as the web's React key `kind:id` is.
    var id: String { "\(kind.rawValue):\(itemID.uuidString)" }
}

/// Whole days left before a deleted item is gone, 0 meaning "today".
/// `daysUntilPurge`: what's left of the 30 days, rounded up, never below 0.
func daysUntilPurge(_ deletedAt: Date, now: Date) -> Int {
    let left = RECOVERY_RETENTION - now.timeIntervalSince(deletedAt)
    return max(0, Int((left / 86_400).rounded(.up)))
}

/// True once the 30 days are over. `isPurgeable`.
func isPurgeable(_ deletedAt: Date, now: Date) -> Bool {
    now.timeIntervalSince(deletedAt) >= RECOVERY_RETENTION
}

/// The countdown at the end of a row: "12 days left", "1 day left", or
/// "Deleted for good today". From `TrashRow` in the web's page.
func purgeLine(_ deletedAt: Date, now: Date) -> String {
    let left = daysUntilPurge(deletedAt, now: now)
    return left == 0 ? "Deleted for good today" : "\(left) \(left == 1 ? "day" : "days") left"
}

/// Newest first, the order `buildTrash` gives. A class and the work that
/// went with it share one moment, so ties go class, assignment, grade, note
/// (the web's order of adding them), then by title, so the list never
/// shuffles between two looks.
func sortTrash(_ entries: [TrashEntry]) -> [TrashEntry] {
    // `allCases` lists the kinds in the order they're written above, and
    // `firstIndex(of:)` gives each one's place in that list.
    let order = EntityKind.allCases
    return entries.sorted { a, b in
        if a.deletedAt != b.deletedAt { return a.deletedAt > b.deletedAt }
        let ka = order.firstIndex(of: a.kind) ?? 0
        let kb = order.firstIndex(of: b.kind) ?? 0
        if ka != kb { return ka < kb }
        return a.title.localizedCompare(b.title) == .orderedAscending
    }
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Assignments.swift
//  Phase:   1 (save and load)
//  Ports:   lib/store.tsx (toggleTask, the simple part; Phase 4 adds the rest)
//
//  Summary: Actions that change assignments. Each one changes the store and
//           then saves straight away.

import Foundation

extension Store {
    /// Marks an assignment completed, or back to open. In lib/store.tsx this is
    /// `toggleTask`, which also spawns the next repeat and awards XP (later phases).
    func toggleAssignment(_ id: UUID) {
        // Find the assignment's position in the array. `firstIndex(where:)` gives
        // back nil when there's no match, and `guard` leaves early in that case.
        guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }

        // Change it in place, then save before anything else happens.
        assignments[index].done.toggle()
        save()
    }
}
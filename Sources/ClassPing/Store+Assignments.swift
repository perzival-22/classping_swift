//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Assignments.swift
//  Phase:   1 (save and load), rewritten in 4a (every task action)
//  Ports:   lib/store.tsx (addTask, updateTask, deleteTask, undoDelete,
//           dismissUndo, toggleTask, taskById, classById, liveTasks, and the
//           checklist edits the task detail screen makes through updateTask)
//
//  Summary: Everything that changes an assignment. Each action changes the
//           store and then saves to the phone straight away, before anything
//           else can happen, so "Saved on this device" is always true.
//

import Foundation

/// A delete that can still be taken back. `PendingUndo` in lib/recovery.ts,
/// cut down to assignments for now (Phase 11 widens it to classes, grades and
/// notes). `at` is when the delete happened; the Undo bar gives up 8 seconds
/// later, the web's `UNDO_WINDOW_MS`.
// NEW in Phase 4a
struct PendingUndo: Equatable {
    let assignmentID: UUID
    let label: String          // "Problem Set 4 deleted"
    let at: Date
}

extension Store {
    // MARK: - Reading

    /// Every assignment that hasn't been deleted. `liveTasks` in lib/store.tsx.
    /// Screens read this, never the raw `assignments` array, so a deleted item
    /// vanishes everywhere at once.
    // NEW in Phase 4a
    var liveAssignments: [Assignment] {
        assignments.filter { $0.deletedAt == nil }
    }

    /// One live assignment by id, or nil. `taskById` in lib/store.tsx.
    // NEW in Phase 4a
    func assignment(_ id: UUID) -> Assignment? {
        liveAssignments.first(where: { $0.id == id })
    }

    /// The live class an assignment is filed under, or nil for Inbox work.
    /// `classById` in lib/store.tsx. (Phase 5 moves this to Store+Courses.swift.)
    // NEW in Phase 4a
    func course(_ id: UUID?) -> Course? {
        // No class id means Inbox: nothing to look up.
        guard let id else { return nil }
        return courses.first(where: { $0.id == id && $0.deletedAt == nil })
    }

    // MARK: - Adding and editing

    /// Adds a new assignment. `addTask` in lib/store.tsx (its XP credit comes in Phase 12).
    // NEW in Phase 4a
    func addAssignment(_ assignment: Assignment) {
        assignments.append(assignment)
        save()
    }

    /// Replaces an assignment with an edited copy, matched by id. `updateTask`
    /// in the web app takes only the changed fields; here the form hands back
    /// the whole edited value, which is simpler and can't half-apply.
    // NEW in Phase 4a
    func updateAssignment(_ edited: Assignment) {
        guard let index = assignments.firstIndex(where: { $0.id == edited.id }) else { return }
        assignments[index] = edited
        save()
    }

    // MARK: - Completing

    /// Marks an assignment completed, or back to open. `toggleTask` in lib/store.tsx.
    /// Completing a repeating assignment also adds its next copy, once.
    /// (XP and trophies for completing come in Phase 12.)
    // CHANGED in Phase 4a: repeats, and deleted items can't be toggled
    func toggleAssignment(_ id: UUID) {
        // Find the live assignment. `firstIndex(where:)` gives nil when there's
        // no match, and `guard` leaves early in that case.
        guard let index = assignments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let task = assignments[index]
        let nextDone = !task.done
        assignments[index].done = nextDone

        // A repeating assignment that was just completed spawns its next copy.
        // Every condition must hold, and a comma in an `if` means "and":
        //   - it was completed (not reopened), repeats, and has a due day,
        //   - no copy already points back at it (completing, reopening and
        //     completing again must not stack up duplicates),
        //   - the next day exists and isn't past the "repeat until" day.
        if nextDone,
           let rule = task.repeatRule,
           let due = task.due,
           !liveAssignments.contains(where: { $0.recurrenceParentID == task.id }),
           let nextDue = nextRepeatDate(due, rule.rawValue),
           task.repeatUntil.map({ nextDue <= $0 }) ?? true {
            // `var next = task` makes a full copy (structs are values), which
            // is then changed into the next occurrence.
            var next = task
            next.id = UUID()
            next.due = nextDue
            next.done = false
            next.recurrenceParentID = task.id
            next.deletedAt = nil
            // The checklist comes along, unticked.
            next.subtasks = task.subtasks.map { step in
                var fresh = step
                fresh.done = false
                return fresh
            }
            assignments.append(next)
        }
        save()
    }

    // MARK: - Checklist

    /// Adds a step to an assignment's checklist. The web does this with
    /// `updateTask(id, { subtasks: [...] })`. Blank steps are ignored, and a
    /// step is capped at 200 characters like the web input.
    // NEW in Phase 4a
    func addSubtask(_ title: String, to id: UUID) {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !clean.isEmpty,
              let index = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[index].subtasks.append(Subtask(title: clean))
        save()
    }

    /// Ticks a checklist step, or unticks it.
    // NEW in Phase 4a
    func toggleSubtask(_ stepID: UUID, in id: UUID) {
        // Two lookups: the assignment, then the step inside its checklist.
        guard let index = assignments.firstIndex(where: { $0.id == id }),
              let step = assignments[index].subtasks.firstIndex(where: { $0.id == stepID }) else { return }
        assignments[index].subtasks[step].done.toggle()
        save()
    }

    // MARK: - Deleting and undo

    /// Moves an assignment to Recently Deleted. `deleteTask` in lib/store.tsx.
    /// Nothing is erased: `deletedAt` is set, so it can come back for 30 days.
    /// Its day plan goes (as on the web), and the Undo bar is offered.
    // NEW in Phase 4a
    func deleteAssignment(_ id: UUID) {
        guard let index = assignments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = Date.now
        assignments[index].deletedAt = now
        taskPlans.removeAll(where: { $0.assignmentID == id })

        // "Problem Set 4 deleted", or "Assignment deleted" for a blank title.
        let title = assignments[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(assignmentID: id,
                                  label: "\(title.isEmpty ? "Assignment" : title) deleted",
                                  at: now)
        save()
    }

    /// Brings back the assignment the Undo bar is offering. `undoDelete`.
    // NEW in Phase 4a
    func undoDelete() {
        guard let undo = pendingUndo,
              let index = assignments.firstIndex(where: { $0.id == undo.assignmentID }) else { return }
        assignments[index].deletedAt = nil
        pendingUndo = nil
        save()
    }

    /// Lets the Undo offer go without acting on it. `dismissUndo`.
    // NEW in Phase 4a
    func dismissUndo() {
        pendingUndo = nil
    }
}
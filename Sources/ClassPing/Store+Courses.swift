//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Courses.swift
//  Phase:   5b (classes: add and edit), changed in 6b (delete, with Undo)
//  Ports:   lib/store.tsx (liveClasses, activeClasses, classById, addClass,
//           updateClass, deleteClass, and the class half of restoreItems)
//
//  Summary: Reading and changing classes. Like the assignment actions, each
//           change saves to the phone straight away. Deleting a class takes
//           its assignments, grades and notes with it, all stamped with the
//           same moment, so Undo brings back exactly that set (D-21).
//

import Foundation

extension Store {
    // MARK: - Reading

    /// Every class that hasn't been deleted. `liveClasses` in lib/store.tsx.
    // CHANGED in Phase 6b: comment only, `course(_:)` now lives below
    var liveCourses: [Course] {
        courses.filter { $0.deletedAt == nil }
    }

    /// The live classes on this term's timetable: archived ones left out.
    /// `activeClasses` in lib/store.tsx. Today's week draws these.
    var activeCourses: [Course] {
        liveCourses.filter { !$0.archived }
    }

    /// The live class with this id, or nil (also for Inbox work, which has
    /// no class). `classById` in lib/store.tsx.
    // NEW in Phase 6b: moved here from Store+Assignments.swift, unchanged
    func course(_ id: UUID?) -> Course? {
        // No class id means Inbox: nothing to look up.
        guard let id else { return nil }
        return courses.first(where: { $0.id == id && $0.deletedAt == nil })
    }

    // MARK: - Adding and editing

    /// Adds a new class. `addClass` in lib/store.tsx (its XP credit comes in Phase 12).
    func addCourse(_ course: Course) {
        courses.append(course)
        save()
    }

    /// Replaces a class with an edited copy, matched by id. `updateClass` on the
    /// web takes only the changed fields; the form here hands back the whole
    /// edited class, the same choice `updateAssignment` made in Phase 4a.
    func updateCourse(_ edited: Course) {
        guard let index = courses.firstIndex(where: { $0.id == edited.id }) else { return }
        courses[index] = edited
        save()
    }

    // MARK: - Deleting
    // NEW in Phase 6b

    /// Moves a class, and everything filed under it, to Recently Deleted.
    /// `deleteClass` in lib/store.tsx. Nothing is erased: every item gets
    /// the SAME `deletedAt`, which is what makes Undo exact. Work you had
    /// already deleted keeps its own older stamp, so it stays deleted.
    /// The children keep their `courseID`, so the links survive the trip.
    func deleteCourse(_ id: UUID) {
        guard let index = courses.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = Date.now
        courses[index].deletedAt = now

        // Stamp the class's live work. `for i in list.indices where ...`
        // visits only the positions that match the condition, so there's
        // nothing to skip or stop: it changes exactly the items that belong.
        for i in assignments.indices where assignments[i].courseID == id && assignments[i].deletedAt == nil {
            assignments[i].deletedAt = now
        }
        for i in grades.indices where grades[i].courseID == id && grades[i].deletedAt == nil {
            grades[i].deletedAt = now
        }
        for i in notes.indices where notes[i].courseID == id && notes[i].deletedAt == nil {
            notes[i].deletedAt = now
        }

        // Offer Undo: "Biology deleted".
        pendingUndo = PendingUndo(item: .course(id),
                                  label: "\(courses[index].name) deleted",
                                  at: now)
        save()
    }

    /// Brings a deleted class back with exactly the work that went with it:
    /// the items whose `deletedAt` matches the class's own. The class half of
    /// `restoreItems` in lib/store.tsx. It doesn't save by itself, because its
    /// caller (`undoDelete`, and Recently Deleted in Phase 11) saves once at
    /// the end.
    func restoreCourse(_ id: UUID) {
        // The class must exist and be deleted; its stamp is the key.
        guard let index = courses.firstIndex(where: { $0.id == id }),
              let stamp = courses[index].deletedAt else { return }
        courses[index].deletedAt = nil

        // Only the work stamped at that same moment. Something deleted on its
        // own last week has a different stamp and stays in Recently Deleted.
        for i in assignments.indices where assignments[i].courseID == id && assignments[i].deletedAt == stamp {
            assignments[i].deletedAt = nil
        }
        for i in grades.indices where grades[i].courseID == id && grades[i].deletedAt == stamp {
            grades[i].deletedAt = nil
        }
        for i in notes.indices where notes[i].courseID == id && notes[i].deletedAt == stamp {
            notes[i].deletedAt = nil
        }
    }
}

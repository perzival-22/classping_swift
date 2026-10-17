//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Courses.swift
//  Phase:   5b (classes: add and edit)
//  Ports:   lib/store.tsx (liveClasses, activeClasses, addClass, updateClass)
//
//  Summary: Reading and changing classes. Like the assignment actions, each
//           change saves to the phone straight away. Deleting a class comes in
//           Phase 6, together with an Undo that brings back its work too (D-21).
//

import Foundation

extension Store {
    // MARK: - Reading

    /// Every class that hasn't been deleted. `liveClasses` in lib/store.tsx.
    /// (Looking one up by id is `course(_:)`, which sits in
    /// Store+Assignments.swift until Phase 6 reworks that file.)
    var liveCourses: [Course] {
        courses.filter { $0.deletedAt == nil }
    }

    /// The live classes on this term's timetable: archived ones left out.
    /// `activeClasses` in lib/store.tsx. Today's week draws these.
    var activeCourses: [Course] {
        liveCourses.filter { !$0.archived }
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
}

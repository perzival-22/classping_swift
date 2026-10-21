//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Trash.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/store.tsx (trash, restoreItems, purgeItems, emptyTrash)
//           and lib/recovery.ts (buildTrash)
//
//  Summary: Recently Deleted: the list, bringing something back, deleting
//           it for good now, emptying the lot, and the 30-day clear-out when
//           the app opens. Deleting for good also unhooks what pointed at the
//           item, so no plan or note is left pointing at nothing.
//

import Foundation

extension Store {
    // MARK: - The list

    /// Everything in Recently Deleted, newest first. `buildTrash`. A class's
    /// name is looked up among all classes, deleted ones included, so work
    /// that went with its class still says which class it was.
    var trash: [TrashEntry] {
        let deletedCourses = Set(courses.filter { $0.deletedAt != nil }.map(\.id))
        let names = Dictionary(courses.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        /// The class an item belonged to: its name, and whether it's deleted
        /// too (then the item went with it). A function inside a property is
        /// fine in Swift; nothing outside can see it.
        func parent(_ courseID: UUID?) -> (name: String?, gone: Bool) {
            guard let courseID else { return (nil, false) }
            return (names[courseID], deletedCourses.contains(courseID))
        }

        var rows: [TrashEntry] = []
        for c in courses {
            if let at = c.deletedAt {
                rows.append(TrashEntry(kind: .course, itemID: c.id, title: c.name,
                                       detail: c.term, deletedAt: at, viaClass: false))
            }
        }
        for a in assignments {
            if let at = a.deletedAt {
                let owner = parent(a.courseID)
                rows.append(TrashEntry(kind: .assignment, itemID: a.id, title: a.title,
                                       detail: owner.name, deletedAt: at, viaClass: owner.gone))
            }
        }
        for g in grades {
            if let at = g.deletedAt {
                let owner = parent(g.courseID)
                rows.append(TrashEntry(kind: .grade, itemID: g.id, title: g.title,
                                       detail: owner.name, deletedAt: at, viaClass: owner.gone))
            }
        }
        for n in notes {
            if let at = n.deletedAt {
                let owner = parent(n.courseID)
                let title = n.title.trimmingCharacters(in: .whitespacesAndNewlines)
                rows.append(TrashEntry(kind: .note, itemID: n.id,
                                       title: title.isEmpty ? "Untitled note" : title,
                                       detail: owner.name, deletedAt: at, viaClass: owner.gone))
            }
        }
        return sortTrash(rows)
    }

    // MARK: - Bringing back

    /// Puts a deleted item back. `restoreItems`. A class comes back with the
    /// work deleted at the same moment (Phase 6b's `restoreCourse`), not with
    /// something you'd deleted on its own before. False when the write failed;
    /// then it stays in Recently Deleted.
    @discardableResult
    func restoreFromTrash(_ entry: TrashEntry) -> Bool {
        let before = document
        let id = entry.itemID
        switch entry.kind {
        case .course:
            restoreCourse(id)
        case .assignment:
            if let i = assignments.firstIndex(where: { $0.id == id }) { assignments[i].deletedAt = nil }
        case .grade:
            if let i = grades.firstIndex(where: { $0.id == id }) { grades[i].deletedAt = nil }
        case .note:
            if let i = notes.firstIndex(where: { $0.id == id }) { notes[i].deletedAt = nil }
        }
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }

    // MARK: - Deleting for good

    /// Deletes one item for good, now. `purgeItems`. A class takes all its
    /// work with it, as on the web, since nothing can belong to a class
    /// that's gone.
    @discardableResult
    func purgeFromTrash(_ entry: TrashEntry) -> Bool {
        let one: Set<UUID> = [entry.itemID]
        let before = document
        switch entry.kind {
        case .course: purge(courses: one)
        case .assignment: purge(assignments: one)
        case .grade: purge(grades: one)
        case .note: purge(notes: one)
        }
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }

    /// Empties Recently Deleted. `emptyTrash`. No Undo; the screen asks first.
    @discardableResult
    func emptyTrash() -> Bool {
        let before = document
        purge(courses: Set(courses.filter { $0.deletedAt != nil }.map(\.id)),
              assignments: Set(assignments.filter { $0.deletedAt != nil }.map(\.id)),
              grades: Set(grades.filter { $0.deletedAt != nil }.map(\.id)),
              notes: Set(notes.filter { $0.deletedAt != nil }.map(\.id)))
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }

    /// Deletes for good whatever has waited 30 days. The web leaves this to
    /// its server each night; there's no server yet, so the phone does it
    /// when the app opens (D-75). It saves only when something went.
    func purgeExpired(now: Date) {
        // The ids of deleted items whose 30 days are up.
        func expired<T: Identifiable>(_ items: [T], _ deletedAt: (T) -> Date?) -> Set<T.ID> {
            Set(items.filter { item in deletedAt(item).map { isPurgeable($0, now: now) } ?? false }.map(\.id))
        }
        let oldCourses = expired(courses) { $0.deletedAt }
        let oldAssignments = expired(assignments) { $0.deletedAt }
        let oldGrades = expired(grades) { $0.deletedAt }
        let oldNotes = expired(notes) { $0.deletedAt }
        guard !(oldCourses.isEmpty && oldAssignments.isEmpty && oldGrades.isEmpty && oldNotes.isEmpty)
        else { return }
        purge(courses: oldCourses, assignments: oldAssignments, grades: oldGrades, notes: oldNotes)
        save()
    }

    /// The one place things are deleted for good. It removes the items and
    /// whatever belongs to a removed class, then unhooks what pointed at them:
    /// a removed assignment's day plan goes, and study sessions and notes
    /// that named it (or a removed class) forget the link but stay. The
    /// default `[]` lets each caller name only the kinds it has.
    private func purge(courses goneCourses: Set<UUID> = [], assignments goneTasks: Set<UUID> = [],
                       grades goneGrades: Set<UUID> = [], notes goneNotes: Set<UUID> = []) {
        // A removed class's work goes with it: `belongs` says whether an item
        // points at one. `union` joins two sets.
        let belongs: (UUID?) -> Bool = { id in id.map { goneCourses.contains($0) } ?? false }
        let tasks = goneTasks.union(assignments.filter { belongs($0.courseID) }.map(\.id))
        let marks = goneGrades.union(grades.filter { belongs($0.courseID) }.map(\.id))
        let pages = goneNotes.union(notes.filter { belongs($0.courseID) }.map(\.id))

        assignments.removeAll { tasks.contains($0.id) }
        grades.removeAll { marks.contains($0.id) }
        notes.removeAll { pages.contains($0.id) }
        courses.removeAll { goneCourses.contains($0.id) }
        taskPlans.removeAll { tasks.contains($0.assignmentID) }

        // Unhook links to what's gone, keeping the items that held them.
        for i in studySessions.indices {
            if let task = studySessions[i].assignmentID, tasks.contains(task) { studySessions[i].assignmentID = nil }
            if belongs(studySessions[i].courseID) { studySessions[i].courseID = nil }
        }
        for i in notes.indices {
            if let task = notes[i].assignmentID, tasks.contains(task) { notes[i].assignmentID = nil }
        }

        // An Undo offer for something that's gone has nothing to bring back.
        // `case .a(let id), .b(let id)` matches any of these cases and names
        // the id each one carries the same way.
        if let undo = pendingUndo {
            let id: UUID
            switch undo.item {
            case .assignment(let x), .course(let x), .note(let x), .grade(let x): id = x
            }
            if tasks.contains(id) || marks.contains(id) || pages.contains(id) || goneCourses.contains(id) {
                pendingUndo = nil
            }
        }
    }
}

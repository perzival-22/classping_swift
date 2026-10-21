// TrashStoreTests.swift: Recently Deleted through the store (lib/store.tsx's
// trash, restoreItems, purgeItems and emptyTrash, and buildTrash in
// lib/recovery.ts), plus the phone's 30-day clear-out when the app opens
// (D-75). Uses an isolated Documents path, never the real planner file.
// Run: tools/persistence-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct TrashStoreTests {
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    /// Biology with an assignment (planned, studied, linked from a note) and
    /// a grade, plus an Inbox task. Saved, so a reload sees it.
    private func planner() -> (store: Store, bio: Course, lab: Assignment) {
        let store = fresh()
        let bio = Course(name: "Biology", short: "Bio", color: .mint, days: [1], startMin: 600, endMin: 650,
                         term: "Fall 2026")
        let lab = Assignment(courseID: bio.id, title: "Lab report", due: "2026-10-30")
        store.courses = [bio]
        store.assignments = [lab, Assignment(title: "Email advisor")]
        store.grades = [Grade(courseID: bio.id, title: "Quiz 1", score: 9, max: 10, weight: 10, date: "2026-10-01")]
        store.notes = [Note(courseID: bio.id, date: "2026-10-02", title: "Cells", assignmentID: lab.id)]
        store.taskPlans = [TaskPlan(assignmentID: lab.id, date: "2026-10-28")]
        store.studySessions = [StudySession(assignmentID: lab.id, courseID: bio.id, minutes: 25, completedAt: .now)]
        store.save()
        return (store, bio, lab)
    }

    private func blockWrites() -> Bool {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return (try? FileManager.default.createDirectory(at: Store.fileURL,
                                                         withIntermediateDirectories: false)) != nil
    }

    private func unblock() {
        try? FileManager.default.removeItem(at: Store.fileURL)
    }

    // MARK: - The list

    @Test func theListNamesTheClassAndMarksWhatWentWithIt() {
        let (store, bio, _) = planner()
        // An Inbox task deleted on its own first, then the whole class.
        store.deleteAssignment(store.assignments[1].id)
        store.deleteCourse(bio.id)
        let trash = store.trash
        // Newest first: the class, then what went with it (assignment, grade,
        // note), then the older Inbox delete.
        #expect(trash.map(\.title) == ["Biology", "Lab report", "Quiz 1", "Cells", "Email advisor"])
        #expect(trash.map(\.kind) == [.course, .assignment, .grade, .note, .assignment])
        #expect(trash[0].detail == "Fall 2026")       // a class's detail is its term
        #expect(trash[1].detail == "Biology")         // its work names it, though it's deleted
        #expect(trash[1].viaClass && trash[2].viaClass && trash[3].viaClass)
        #expect(!trash[0].viaClass)
        #expect(trash[4].detail == nil && !trash[4].viaClass)
    }

    @Test func aNoteWithNoTitleIsUntitled() {
        let store = fresh()
        store.notes = [Note(courseID: nil, date: "2026-10-02", title: "   ")]
        store.deleteNote(store.notes[0].id)
        #expect(store.trash.first?.title == "Untitled note")
    }

    // MARK: - Bringing back

    @Test func aClassComesBackWithWhatWentWithItAndNothingElse() {
        let (store, bio, lab) = planner()
        // Deleted on its own a moment before the class: a different stamp.
        store.deleteNote(store.notes[0].id)
        store.deleteCourse(bio.id)
        guard let row = store.trash.first(where: { $0.kind == .course }) else {
            Issue.record("no class row"); return
        }
        #expect(store.restoreFromTrash(row))
        let saved = Store.load()
        #expect(saved.liveCourses.map(\.id) == [bio.id])
        #expect(saved.liveAssignments.contains { $0.id == lab.id })
        #expect(saved.liveGrades.count == 1)
        // The note was binned separately, so it stays in Recently Deleted.
        #expect(saved.liveNotes.isEmpty)
        #expect(saved.trash.map(\.title) == ["Cells"])
    }

    @Test func oneItemComesBackOnItsOwn() {
        let (store, _, lab) = planner()
        store.deleteAssignment(lab.id)
        guard let row = store.trash.first else { Issue.record("empty trash"); return }
        #expect(store.restoreFromTrash(row))
        #expect(Store.load().liveAssignments.contains { $0.id == lab.id })
        #expect(store.trash.isEmpty)
    }

    @Test func aFailedSaveLeavesItDeleted() {
        let (store, _, lab) = planner()
        store.deleteAssignment(lab.id)
        guard let row = store.trash.first else { Issue.record("empty trash"); return }
        #expect(blockWrites())
        #expect(!store.restoreFromTrash(row))
        #expect(store.trash.count == 1)
        unblock()
    }

    // MARK: - Deleting for good

    @Test func deletingWorkForGoodUnhooksWhatPointedAtIt() {
        let (store, bio, lab) = planner()
        store.deleteAssignment(lab.id)   // its plan goes now, as on the web
        guard let row = store.trash.first else { Issue.record("empty trash"); return }
        #expect(store.purgeFromTrash(row))
        let saved = Store.load()
        #expect(!saved.assignments.contains { $0.id == lab.id })
        #expect(saved.taskPlans.isEmpty)
        // The note and the study session stay, without the link.
        #expect(saved.notes.first?.assignmentID == nil)
        #expect(saved.studySessions.first?.assignmentID == nil)
        #expect(saved.studySessions.first?.courseID == bio.id)
    }

    @Test func deletingAClassForGoodTakesItsWork() {
        let (store, bio, lab) = planner()
        store.deleteCourse(bio.id)
        guard let row = store.trash.first(where: { $0.kind == .course }) else {
            Issue.record("no class row"); return
        }
        #expect(store.purgeFromTrash(row))
        let saved = Store.load()
        #expect(saved.courses.isEmpty)
        #expect(saved.assignments.map(\.title) == ["Email advisor"])
        #expect(saved.grades.isEmpty && saved.notes.isEmpty)
        // Phone-only (D-75): the class's work's day plans go too, and the
        // session forgets both links instead of pointing at nothing.
        #expect(saved.taskPlans.isEmpty)
        #expect(saved.studySessions.first?.courseID == nil)
        #expect(saved.studySessions.first?.assignmentID == nil)
        #expect(!saved.studySessions.isEmpty)
        _ = lab
    }

    @Test func anUndoForSomethingDeletedForGoodIsDropped() {
        let (store, _, lab) = planner()
        store.deleteAssignment(lab.id)
        #expect(store.pendingUndo != nil)
        guard let row = store.trash.first else { Issue.record("empty trash"); return }
        #expect(store.purgeFromTrash(row))
        #expect(store.pendingUndo == nil)
    }

    @Test func emptyingClearsEverythingAtOnce() {
        let (store, bio, _) = planner()
        store.deleteAssignment(store.assignments[1].id)
        store.deleteCourse(bio.id)
        #expect(store.trash.count == 5)
        #expect(store.emptyTrash())
        #expect(store.trash.isEmpty)
        let saved = Store.load()
        #expect(saved.courses.isEmpty && saved.assignments.isEmpty)
        #expect(saved.grades.isEmpty && saved.notes.isEmpty && saved.taskPlans.isEmpty)
        #expect(saved.studySessions.count == 1)   // kept, unhooked
    }

    // MARK: - The 30 days

    @Test func openingTheAppClearsWhatHasWaitedThirtyDays() {
        let store = fresh()
        var old = Assignment(title: "Old")
        old.deletedAt = Date.now.addingTimeInterval(-31 * 86_400)
        var recent = Assignment(title: "Recent")
        recent.deletedAt = Date.now.addingTimeInterval(-29 * 86_400)
        store.assignments = [old, recent, Assignment(title: "Live")]
        store.save()
        let opened = Store.load()
        #expect(opened.assignments.map(\.title) == ["Recent", "Live"])
        // It saved the clear-out, so the next open agrees.
        #expect(Store.load().assignments.map(\.title) == ["Recent", "Live"])
    }

    @Test func aClassPastThirtyDaysGoesWithItsWork() {
        let store = fresh()
        let gone = Date.now.addingTimeInterval(-40 * 86_400)
        var bio = Course(name: "Biology", short: "Bio", color: .mint, days: [1], startMin: 600, endMin: 650)
        bio.deletedAt = gone
        var lab = Assignment(courseID: bio.id, title: "Lab")
        lab.deletedAt = gone
        store.courses = [bio]
        store.assignments = [lab]
        store.taskPlans = [TaskPlan(assignmentID: lab.id, date: "2026-10-28")]
        store.save()
        let opened = Store.load()
        #expect(opened.courses.isEmpty)
        #expect(opened.assignments.isEmpty)
        #expect(opened.taskPlans.isEmpty)
    }

    @Test func nothingExpiredMeansNoWrite() {
        let (store, _, _) = planner()
        _ = store
        let before = (try? FileManager.default.attributesOfItem(atPath: Store.fileURL.path))?[.modificationDate] as? Date
        _ = Store.load()
        let after = (try? FileManager.default.attributesOfItem(atPath: Store.fileURL.path))?[.modificationDate] as? Date
        #expect(before != nil)
        #expect(before == after)
    }
}

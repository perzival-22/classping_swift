// Phase 6b: class deletion, the exact cascade and both Undo cases.
// All planner files are isolated by scripts/test-store.sh.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct CourseDeletionTests {
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    private func course(_ name: String = "Biology") -> Course {
        Course(name: name, short: "Bio", color: .teal,
               days: [0, 2], startMin: 600, endMin: 660)
    }

    /// Mix live and previously deleted children with unrelated and Inbox work.
    private func populate(_ store: Store) -> Course {
        let biology = course()
        let chemistry = course("Chemistry")
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        store.courses = [biology, chemistry]
        store.assignments = [
            Assignment(courseID: biology.id, title: "Open", due: "2026-10-20"),
            Assignment(courseID: biology.id, title: "Done", due: "2026-10-16", done: true),
            Assignment(courseID: biology.id, title: "Previously deleted", deletedAt: old),
            Assignment(courseID: chemistry.id, title: "Unrelated"),
            Assignment(title: "Inbox"),
        ]
        store.grades = [
            Grade(courseID: biology.id, title: "Quiz", score: 8, max: 10, weight: 1, date: "2026-10-17"),
            Grade(courseID: biology.id, title: "Old", score: 7, max: 10, weight: 1,
                  date: "2026-10-10", deletedAt: old),
            Grade(courseID: chemistry.id, title: "Other", score: 9, max: 10, weight: 1, date: "2026-10-17"),
        ]
        store.notes = [
            Note(courseID: biology.id, date: "2026-10-17", assignmentID: store.assignments[0].id),
            Note(courseID: biology.id, date: "2026-10-10", deletedAt: old),
            Note(courseID: chemistry.id, date: "2026-10-17"),
        ]
        store.taskPlans = [TaskPlan(assignmentID: store.assignments[0].id, date: "2026-10-19")]
        store.studySessions = [StudySession(assignmentID: store.assignments[0].id,
                                           courseID: biology.id, minutes: 25,
                                           completedAt: old)]
        return biology
    }

    @Test func deletionStampsLiveChildrenAndPersistsVisibility() {
        let store = freshStore()
        let biology = populate(store)
        let oldTaskStamp = store.assignments[2].deletedAt
        let oldGradeStamp = store.grades[1].deletedAt
        let oldNoteStamp = store.notes[1].deletedAt
        let plans = store.taskPlans
        let sessions = store.studySessions
        store.deleteCourse(biology.id)
        let stamp = store.courses[0].deletedAt
        #expect(stamp != nil)
        #expect(store.assignments[0].deletedAt == stamp)
        #expect(store.assignments[1].deletedAt == stamp)
        #expect(store.grades[0].deletedAt == stamp)
        #expect(store.notes[0].deletedAt == stamp)
        #expect(store.assignments[2].deletedAt == oldTaskStamp)
        #expect(store.grades[1].deletedAt == oldGradeStamp)
        #expect(store.notes[1].deletedAt == oldNoteStamp)
        #expect(store.assignments[3].deletedAt == nil)
        #expect(store.assignments[4].deletedAt == nil)
        #expect(store.grades[2].deletedAt == nil)
        #expect(store.notes[2].deletedAt == nil)
        #expect(store.taskPlans == plans)
        #expect(store.studySessions == sessions)
        #expect(store.pendingUndo?.item == .course(biology.id))
        #expect(store.pendingUndo?.label == "Biology deleted")
        #expect(store.pendingUndo?.at == stamp)
        #expect(!store.lastSaveFailed)
        let loaded = Store.load()
        #expect(loaded.course(biology.id) == nil)
        #expect(loaded.activeCourses.count == 1)
        #expect(loaded.liveAssignments.map(\.title) == ["Unrelated", "Inbox"])
        #expect(loaded.assignments.count == 5)
        #expect(loaded.grades.count == 3)
        #expect(loaded.notes.count == 3)
        #expect(loaded.assignments[0].deletedAt == loaded.courses[0].deletedAt)
        #expect(loaded.notes[0].assignmentID == loaded.assignments[0].id)
    }

    @Test func undoRestoresExactlyTheCascadeAndSavesIt() {
        let store = freshStore()
        let biology = populate(store)
        let tasks = store.assignments
        let grades = store.grades
        let notes = store.notes
        store.deleteCourse(biology.id)
        store.undoDelete()
        #expect(store.course(biology.id) == biology)
        #expect(store.assignments == tasks)
        #expect(store.grades == grades)
        #expect(store.notes == notes)
        #expect(store.pendingUndo == nil)
        #expect(!store.lastSaveFailed)
        let loaded = Store.load()
        #expect(loaded.course(biology.id) == biology)
        #expect(loaded.liveAssignments.map(\.title) == ["Open", "Done", "Unrelated", "Inbox"])
        #expect(loaded.grades[0].deletedAt == nil)
        #expect(loaded.notes[0].deletedAt == nil)
        #expect(loaded.assignments[2].deletedAt != nil)
        #expect(loaded.grades[1].deletedAt != nil)
        #expect(loaded.notes[1].deletedAt != nil)
    }

    @Test func restoreAfterReloadUsesTheSavedStampAndDoesNotSaveByItself() {
        let store = freshStore()
        let biology = populate(store)
        store.deleteCourse(biology.id)
        let loaded = Store.load()
        #expect(loaded.pendingUndo == nil)
        loaded.restoreCourse(biology.id)
        #expect(loaded.course(biology.id) == biology)
        #expect(loaded.assignments[0].deletedAt == nil)
        #expect(loaded.assignments[2].deletedAt != nil)
        #expect(loaded.grades[0].deletedAt == nil)
        #expect(loaded.grades[1].deletedAt != nil)
        #expect(loaded.notes[0].deletedAt == nil)
        #expect(loaded.notes[1].deletedAt != nil)
        #expect(Store.load().course(biology.id) == nil)
        loaded.save()
        #expect(Store.load().course(biology.id) == biology)
    }

    @Test func dismissLeavesTheClassAndChildrenDeleted() {
        let store = freshStore()
        let biology = populate(store)
        store.deleteCourse(biology.id)
        store.dismissUndo()
        store.undoDelete()
        #expect(store.pendingUndo == nil)
        #expect(store.course(biology.id) == nil)
        #expect(Store.load().liveAssignments.map(\.title) == ["Unrelated", "Inbox"])
    }

    @Test func missingAndRepeatedDeletesDoNotReplaceTheUndoOffer() {
        let store = freshStore()
        let biology = populate(store)
        store.deleteCourse(UUID())
        #expect(store.pendingUndo == nil)
        store.restoreCourse(UUID())
        store.restoreCourse(biology.id)
        #expect(store.course(biology.id) == biology)
        store.deleteCourse(biology.id)
        let undo = store.pendingUndo
        store.deleteCourse(biology.id)
        store.deleteCourse(UUID())
        #expect(store.pendingUndo == undo)
        store.undoDelete()
        #expect(store.course(biology.id) == biology)
    }

    @Test func newestDeleteSelectsTheCorrectUndoKind() {
        let store = freshStore()
        let biology = populate(store)
        store.deleteCourse(biology.id)
        let unrelated = store.assignments[3]
        store.deleteAssignment(unrelated.id)
        #expect(store.pendingUndo?.item == .assignment(unrelated.id))
        store.undoDelete()
        #expect(store.assignment(unrelated.id) == unrelated)
        #expect(store.course(biology.id) == nil)
        #expect(store.assignments[0].deletedAt != nil)
    }

    @Test func failedCascadeSaveIsReportedAndUndoCanSaveRecovery() {
        let store = freshStore()
        let biology = populate(store)
        let created = (try? FileManager.default.createDirectory(
            at: Store.fileURL, withIntermediateDirectories: false)) != nil
        #expect(created)
        guard created else { return }
        store.deleteCourse(biology.id)
        #expect(store.lastSaveFailed)
        #expect(store.course(biology.id) == nil)
        #expect(store.pendingUndo?.item == .course(biology.id))
        try? FileManager.default.removeItem(at: Store.fileURL)
        store.undoDelete()
        #expect(!store.lastSaveFailed)
        #expect(Store.load().course(biology.id) == biology)
        #expect(Store.load().assignments[0].deletedAt == nil)
    }
}

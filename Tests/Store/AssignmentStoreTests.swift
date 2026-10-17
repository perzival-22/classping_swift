// Verify the real Assignment model's list adapter and the actions exposed by
// the Tasks screen. scripts/test-store.sh isolates the saved planner file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct AssignmentStoreTests {
    /// Begin each integration test without a previously saved planner.
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    @Test func groupsRealAssignmentsWithoutMixingInboxAndDatedWork() {
        let now = Calendar.current.date(from: DateComponents(
            year: 2026, month: 10, day: 21, hour: 12)) ?? .now
        let tasks = [
            Assignment(title: "Inbox"),
            Assignment(title: "Upcoming", due: "2026-10-22", kind: .exam),
            Assignment(title: "Today", due: "2026-10-21"),
            Assignment(title: "Overdue", due: "2026-10-20"),
        ]
        let groups = groupTasks(tasks, now)
        #expect(groups.map(\.id) == [.overdue, .today, .upcoming, .none])
        #expect(groups.map { $0.tasks[0].title } == ["Overdue", "Today", "Upcoming", "Inbox"])
        #expect(tasks[1].kindName == "exam")
        #expect(tasks[1].kind.label == "Exam")
        #expect(Assignment.Kind.quiz.pluralLabel == "Quizzes")
    }

    @Test func savedFiltersWorkWithArchivedClassesAndInbox() {
        let store = freshStore()
        var archived = Course(name: "Biology", short: "Bio", color: .teal,
                              days: [0], startMin: 600, endMin: 660)
        archived.archived = true
        store.courses = [archived]
        let tasks = [
            Assignment(courseID: archived.id, title: "Exam", due: "2026-10-22", kind: .exam),
            Assignment(courseID: archived.id, title: "Essay"),
            Assignment(title: "Inbox"),
        ]
        let prefs = normalizeViewPrefs(tab: "open", subject: archived.id.uuidString,
                                       kind: "exam", includeArchived: true)
        let filtered = filterTasks(tasks, prefs.filters) { store.course($0)?.archived ?? false }
        #expect(filtered.map(\.title) == ["Exam"])
        #expect(filterTasks(tasks, TaskFilters(includeArchived: false)) {
            store.course($0)?.archived ?? false
        }.map(\.title) == ["Inbox"])
    }

    @Test func completeAndReopenPersistWithoutChangingDeadline() {
        let store = freshStore()
        let task = Assignment(title: "Report", due: "2026-10-21", dueTime: "14:30")
        store.addAssignment(task)
        store.toggleAssignment(task.id)
        #expect(Store.load().assignment(task.id)?.done == true)
        store.toggleAssignment(task.id)
        #expect(Store.load().assignment(task.id) == task)
        #expect(!store.lastSaveFailed)
    }

    @Test func checklistAndEditSurviveRelaunch() {
        let store = freshStore()
        let task = Assignment(title: "Report")
        store.addAssignment(task)
        store.addSubtask("   ", to: task.id)
        store.addSubtask("  Draft  ", to: task.id)
        let steps = store.assignment(task.id)?.subtasks ?? []
        #expect(steps.count == 1)
        guard let step = steps.first else { return }
        store.toggleSubtask(step.id, in: task.id)
        var edited = store.assignment(task.id) ?? task
        edited.title = "Revised report"
        edited.notes = "Include references."
        store.updateAssignment(edited)
        let loaded = Store.load().assignment(task.id)
        #expect(loaded?.title == "Revised report")
        #expect(loaded?.notes == "Include references.")
        #expect(loaded?.subtasks == [Subtask(id: step.id, title: "Draft", done: true)])
        #expect(loaded?.due == nil)
    }

    @Test func softDeleteUndoAndDismissPersistTheRightVisibility() {
        let store = freshStore()
        let task = Assignment(title: "Report", due: "2026-10-21")
        store.addAssignment(task)
        store.deleteAssignment(task.id)
        #expect(store.assignment(task.id) == nil)
        #expect(Store.load().liveAssignments.isEmpty)
        #expect(store.assignments[0].deletedAt != nil)
        #expect(store.pendingUndo?.assignmentID == task.id)
        #expect(store.pendingUndo?.label == "Report deleted")
        store.undoDelete()
        #expect(Store.load().assignment(task.id) == task)
        #expect(store.pendingUndo == nil)
        store.deleteAssignment(task.id)
        store.dismissUndo()
        #expect(store.pendingUndo == nil)
        #expect(Store.load().liveAssignments.isEmpty)
        #expect(Store.load().assignments.count == 1)
    }
}

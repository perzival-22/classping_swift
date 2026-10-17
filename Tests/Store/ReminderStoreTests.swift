// Phase 7a: real models, local persistence and deletion feed the reminder plan.
// scripts/test-store.sh isolates these tests from the app's Documents folder.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct ReminderStoreTests {
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    private let now = atMinute(Date(timeIntervalSince1970: 1_800_000_000), 12 * 60)

    private func plan(_ store: Store) -> [PlannedReminder] {
        reminderPlan(courses: store.liveCourses, tasks: store.liveAssignments,
                     postClass: store.profile.postClassNudge,
                     quiet: normalizeQuietHours(start: store.profile.quietStart,
                                                end: store.profile.quietEnd),
                     fired: [], now: now)
    }

    @Test func deletingAClassCancelsItsAlarmsAndHomeworkAndUndoRestoresThem() {
        let store = freshStore()
        let course = Course(name: "Biology", short: "Bio", color: .teal,
                            days: [0, 2], startMin: 600, endMin: 660)
        store.addCourse(course)
        store.addAssignment(Assignment(courseID: course.id, title: "Lab",
                                       due: dayOf(now), dueTime: "14:00", reminder: true))
        let before = plan(store)
        #expect(before.contains { $0.kind == .classAlarm })
        #expect(before.contains { $0.kind == .postClass })
        #expect(before.contains { $0.kind == .taskNag })
        store.deleteCourse(course.id)
        #expect(plan(store).isEmpty)
        #expect(plan(Store.load()).isEmpty)
        store.undoDelete()
        #expect(plan(store) == before)
        #expect(plan(Store.load()) == before)
    }

    @Test func completingOrDisablingAnAssignmentRemovesItsPendingWarnings() {
        let store = freshStore()
        let assignment = Assignment(title: "Final", due: dayOf(scheduleDate(now, 3)),
                                    dueTime: "14:00", kind: .exam, reminder: true)
        store.addAssignment(assignment)
        #expect(plan(store).contains { $0.kind == .taskLead })
        store.toggleAssignment(assignment.id)
        #expect(plan(store).isEmpty)
        store.toggleAssignment(assignment.id)
        var off = store.assignments[0]
        off.reminder = false
        store.updateAssignment(off)
        #expect(plan(store).isEmpty)
        #expect(plan(Store.load()).isEmpty)
    }

    @Test func quietHoursAndTheAfterClassSwitchSurviveReloadAndAffectThePlan() {
        let store = freshStore()
        store.addCourse(Course(name: "Biology", short: "Bio", color: .teal,
                               days: [0], startMin: 600, endMin: 660))
        store.addAssignment(Assignment(title: "Lab", due: dayOf(now), dueTime: "15:00",
                                       reminder: true))
        store.profile.postClassNudge = false
        store.profile.quietStart = 11 * 60
        store.profile.quietEnd = 14 * 60
        store.save()
        let loaded = Store.load()
        #expect(!loaded.profile.postClassNudge)
        #expect(loaded.profile.quietStart == 11 * 60)
        #expect(loaded.profile.quietEnd == 14 * 60)
        let reminders = plan(loaded)
        #expect(!reminders.contains { $0.kind == .postClass })
        #expect(reminders.contains { $0.kind == .classAlarm })
        #expect(reminders.first { $0.kind == .taskNag }?.firstDate == atMinute(now, 14 * 60))
        loaded.profile.quietStart = nil
        loaded.profile.quietEnd = nil
        loaded.save()
        #expect(plan(Store.load()).first { $0.kind == .taskNag }?.firstDate == now)
    }
}

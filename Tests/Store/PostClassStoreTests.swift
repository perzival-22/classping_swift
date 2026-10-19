// Phase 7c: notification routes share live data but never survive a launch.
// scripts/test-store.sh isolates the planner from the app's Documents folder.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct PostClassStoreTests {
    @Test func launchAndBackgroundTapsWaitForAnActiveScreen() {
        let store = Store()
        let courseID = UUID()
        // iOS can deliver the response before the first screen is ready.
        store.route = notificationRoute(["kind": "post-class", "course": courseID.uuidString])
        #expect(store.takeRoute(whenActive: false) == nil)
        #expect(store.route == .postClass(courseID))
        #expect(store.takeRoute(whenActive: true) == .postClass(courseID))
        #expect(store.route == nil)
        #expect(store.takeRoute(whenActive: true) == nil)

        // An existing background scene also waits, then opens Today once.
        store.route = notificationRoute(["kind": "class", "course": courseID.uuidString])
        #expect(store.takeRoute(whenActive: false) == nil)
        #expect(store.route == .today)
        #expect(store.takeRoute(whenActive: true) == .today)

        // The same destination remains usable after the previous tap.
        store.route = notificationRoute(["kind": "class", "course": courseID.uuidString])
        #expect(store.takeRoute(whenActive: true) == .today)

        // Repeated after-class taps must open the question each time too.
        for _ in 0..<2 {
            store.route = notificationRoute(["kind": "post-class", "course": courseID.uuidString])
            #expect(store.takeRoute(whenActive: true) == .postClass(courseID))
            #expect(store.route == nil)
        }
    }

    @Test func theLatestTapBeforeActivationDeterminesTheDestination() {
        let store = Store()
        let courseID = UUID()
        let taskID = UUID()
        store.route = notificationRoute(["kind": "task-nag", "assignment": taskID.uuidString])
        #expect(store.takeRoute(whenActive: false) == nil)

        store.route = notificationRoute(["kind": "post-class", "course": courseID.uuidString])
        #expect(store.takeRoute(whenActive: false) == nil)
        #expect(store.takeRoute(whenActive: true) == .postClass(courseID))
        #expect(store.takeRoute(whenActive: true) == nil)
    }

    @Test func aNotificationRouteIsTransientWhileItsAssignmentSurvivesReload() {
        try? FileManager.default.removeItem(at: Store.fileURL)
        let store = Store()
        let course = Course(name: "Biology", short: "Bio", color: .teal,
                            days: [0], startMin: 600, endMin: 660)
        store.addCourse(course)
        let task = Assignment(courseID: course.id, title: "Lab report")
        store.addAssignment(task)

        // A tap can arrive before RootView exists. Saving other data must
        // neither consume it nor make it replay on the next launch.
        store.route = notificationRoute(["kind": "task-nag", "assignment": task.id.uuidString])
        store.save()
        #expect(!store.lastSaveFailed)
        #expect(store.route == .task(task.id))
        let loaded = Store.load()
        #expect(loaded.route == nil)
        #expect(loaded.assignment(task.id)?.courseID == course.id)
        #expect(loaded.course(course.id)?.name == "Biology")

        // Clearing a consumed request makes the same destination usable again.
        store.route = nil
        store.route = notificationRoute(["kind": "post-class", "course": course.id.uuidString])
        #expect(store.route == .postClass(course.id))
    }

    @Test func thePromptUsesActiveCoursesAndDeletedNotificationTargetsAreMissing() {
        try? FileManager.default.removeItem(at: Store.fileURL)
        let store = Store()
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9,
                                                             day: 14, hour: 11, minute: 10))!
        let ended = Course(name: "Biology", short: "Bio", color: .teal,
                           days: [0], startMin: 600, endMin: 660)
        var archived = Course(name: "Old class", short: "Old", color: .coral,
                              days: [0], startMin: 660, endMin: 720)
        archived.archived = true
        let next = Course(name: "Calculus", short: "Calc", color: .indigo,
                          days: [0], startMin: 780, endMin: 840)
        store.courses = [ended, archived, next]
        let task = Assignment(courseID: ended.id, title: "Lab report")
        store.addAssignment(task)
        #expect(justEnded(store.activeCourses, now: now)?.course.id == ended.id)
        #expect(nextClassToday(store.activeCourses, now: now)?.course.id == next.id)

        // Notification payloads can outlive their class and its homework.
        store.deleteCourse(ended.id)
        let loaded = Store.load()
        #expect(loaded.course(ended.id) == nil)
        #expect(loaded.assignment(task.id) == nil)
        #expect(justEnded(loaded.activeCourses, now: now) == nil)
    }
}

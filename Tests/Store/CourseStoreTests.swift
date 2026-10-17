// Class actions and their saved-data contract, exercised with an isolated
// Documents directory by scripts/test-store.sh.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct CourseStoreTests {
    /// Each test starts with an empty disposable planner location.
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    /// A lecture with a separate lab, plus details that must survive an edit.
    private func biology() -> Course {
        var course = Course(name: "Biology", short: "Biolo", color: .teal,
                            days: [1, 3], startMin: 660, endMin: 750)
        course.room = "Science 204"
        course.additionalMeetings = [ClassMeeting(days: [4], start: 840, end: 900,
                                                  room: "Lab 3", label: "Lab")]
        course.instructor = "Dr. Lee"
        course.credits = 3.5
        course.notes = "Bring a lab coat."
        course.remindBefore = 15
        course.extraReminders = [30]
        course.goal = 90
        course.term = "Fall 2026"
        course.sourceUID = "imported-course"
        return course
    }

    @Test func addsAndPersistsEveryMeetingAndClassDetail() {
        let store = freshStore()
        let course = biology()
        store.addCourse(course)
        #expect(!store.lastSaveFailed)
        let loaded = Store.load()
        #expect(loaded.courses == [course])
        let slots = expandClassMeetings(loaded.activeCourses)
        #expect(slots.count == 2)
        #expect(slots[0].meeting.days == [1, 3])
        #expect(slots[1].meeting.label == "Lab")
        #expect(slots[0].id != slots[1].id)
    }

    @Test func editingPreservesRelatedWorkAndUnshownFields() {
        let store = freshStore()
        let course = biology()
        store.addCourse(course)
        let assignment = Assignment(courseID: course.id, title: "Report",
                                    due: "2026-10-21", dueTime: "14:30")
        store.addAssignment(assignment)
        var edited = course
        edited.name = "Biology II"
        edited.days = [0, 2]
        edited.additionalMeetings[0].room = "Lab 4"
        store.updateCourse(edited)
        let loaded = Store.load()
        #expect(loaded.courses == [edited])
        #expect(loaded.assignments == [assignment])
        #expect(loaded.courses[0].extraReminders == [30])
        #expect(loaded.courses[0].goal == 90)
        #expect(loaded.courses[0].sourceUID == "imported-course")
    }

    @Test func unscheduledClassCanBeScheduledAndReturnedToUnscheduled() {
        let store = freshStore()
        var course = Course(name: "Chemistry", short: "Chemi", color: .ocean,
                            days: [], startMin: 600, endMin: 660)
        store.addCourse(course)
        #expect(Store.load().activeCourses.count == 1)
        #expect(isUnscheduled(Store.load().courses[0]))
        course.days = [0, 2]
        course.additionalMeetings = [ClassMeeting(days: [4], start: 840, end: 900)]
        store.updateCourse(course)
        #expect(!isUnscheduled(Store.load().courses[0]))
        #expect(expandClassMeetings(Store.load().activeCourses).count == 2)
        course.days = []
        course.additionalMeetings = []
        course.room = nil
        store.updateCourse(course)
        #expect(isUnscheduled(Store.load().courses[0]))
        #expect(Store.load().courses.count == 1)
    }

    @Test func timetableExcludesArchivedAndDeletedClasses() {
        let store = freshStore()
        let active = biology()
        var archived = biology()
        archived.archived = true
        var deleted = biology()
        deleted.deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
        store.courses = [active, archived, deleted]
        #expect(store.liveCourses.map(\.id) == [active.id, archived.id])
        #expect(store.activeCourses.map(\.id) == [active.id])
        #expect(store.course(deleted.id) == nil)
        #expect(store.course(archived.id) == archived)
    }

    @Test func updateDoesNotRecreateAMissingClass() {
        let store = freshStore()
        store.updateCourse(biology())
        #expect(store.courses.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: Store.fileURL.path))
    }

    @Test func reportsFailedWriteAndAllowsRetryWithSameIdentity() {
        let store = freshStore()
        // A directory at the file's location makes an atomic file write fail.
        let created = (try? FileManager.default.createDirectory(
            at: Store.fileURL, withIntermediateDirectories: false)) != nil
        #expect(created)
        guard created else { return }
        let course = biology()
        store.addCourse(course)
        #expect(store.lastSaveFailed)
        #expect(store.courses == [course])
        try? FileManager.default.removeItem(at: Store.fileURL)
        var retry = course
        retry.room = "Science 205"
        store.updateCourse(retry)
        #expect(!store.lastSaveFailed)
        #expect(Store.load().courses == [retry])
    }
}

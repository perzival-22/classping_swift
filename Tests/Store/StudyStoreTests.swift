// StudyStoreTests.swift: Phase 10a's study sessions in the store, through a
// reload. Uses an isolated Documents path, never the real planner file.
// Run: tools/persistence-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct StudyStoreTests {
    private func fresh() -> (Store, Assignment) {
        try? FileManager.default.removeItem(at: Store.fileURL)
        let store = Store()
        let course = Course(name: "Biology", short: "Bio", color: .teal,
                            days: [0], startMin: 600, endMin: 660)
        store.addCourse(course)
        let essay = Assignment(courseID: course.id, title: "Essay", due: "2026-11-02")
        store.addAssignment(essay)
        return (store, essay)
    }

    @Test func aFinishedBlockIsSavedWithItsRealEndAndCountsAsFocused() {
        let (store, essay) = fresh()
        let ended = Date(timeIntervalSince1970: 1_800_000_000)
        store.addStudySession(minutes: 25, assignmentID: essay.id, courseID: essay.courseID,
                              mode: .pomodoro, completedAt: ended)
        store.addStudySession(minutes: 25, assignmentID: essay.id, courseID: essay.courseID,
                              mode: .pomodoro, completedAt: ended.addingTimeInterval(1800))
        let loaded = Store.load()
        #expect(loaded.studySessions.count == 2)
        #expect(loaded.studySessions.first?.completedAt == ended)
        #expect(loaded.studySessions.first?.mode == .pomodoro)
        #expect(loaded.studySessions.first?.courseID == essay.courseID)
        #expect(loaded.focusedMinutes(essay.id) == 50)
    }

    @Test func minutesStayBetweenOneAndTwoHundredForty() {
        let (store, essay) = fresh()
        store.addStudySession(minutes: 0, assignmentID: essay.id, courseID: nil, mode: .timer)
        store.addStudySession(minutes: 999, assignmentID: essay.id, courseID: nil, mode: .timer)
        #expect(Store.load().studySessions.map(\.minutes) == [1, 240])
    }

    /// No rollback: a block that ended is kept in memory and saved by the
    /// next write that works.
    @Test func aFailedWriteKeepsTheSessionForTheNextSave() {
        let (store, essay) = fresh()
        try? FileManager.default.removeItem(at: Store.fileURL)
        let blocked = (try? FileManager.default.createDirectory(at: Store.fileURL,
                                                                withIntermediateDirectories: false)) != nil
        #expect(blocked); guard blocked else { return }
        store.addStudySession(minutes: 25, assignmentID: essay.id, courseID: nil, mode: .timer)
        #expect(store.lastSaveFailed)
        #expect(store.studySessions.count == 1)
        try? FileManager.default.removeItem(at: Store.fileURL)
        store.save()
        #expect(Store.load().studySessions.count == 1)
    }
}

// ImportStoreTests.swift: an import through the store (importItems in
// lib/store.tsx) and the term question (ImportCalendar.tsx's shouldOfferTerm,
// TermSetupSheet.tsx's writes). Uses an isolated Documents path, never the
// real planner file.
// Run: tools/persistence-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct ImportStoreTests {
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    private func blockWrites() -> Bool {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return (try? FileManager.default.createDirectory(at: Store.fileURL,
                                                         withIntermediateDirectories: false)) != nil
    }

    private func unblock() {
        try? FileManager.default.removeItem(at: Store.fileURL)
    }

    private let chem = ImportedClass(name: "Organic Chemistry", short: "Organ", color: "teal",
                                     days: [0, 2], start: 600, end: 680, room: "Science 204",
                                     sourceUID: "chem@u.edu")
    private let essay = ImportedTask(title: "Essay draft", due: "2026-10-30", dueTime: "23:59",
                                     kind: "assignment", sourceUID: "essay@u.edu")
    private let midterm = ImportedTask(title: "Midterm", due: "2026-11-02", dueTime: nil, kind: "exam")

    @Test func classesAndWorkArriveAndSurviveARelaunch() {
        let store = fresh()
        let other = ImportedClass(name: "Art", short: "Art", color: "coral", days: [4], start: 840, end: 900)
        #expect(store.importItems([chem, other], [essay, midterm]))

        // Classes keep what the file said, as Courses.
        #expect(store.courses.map(\.name) == ["Organic Chemistry", "Art"])
        let c = store.courses[0]
        #expect(c.color == .teal && c.days == [0, 2] && c.startMin == 600 && c.endMin == 680)
        #expect(c.remindBefore == 15 && c.alarm && c.room == "Science 204" && c.sourceUID == "chem@u.edu")

        // Work goes under the first imported class, reminders on.
        #expect(store.assignments.map(\.courseID) == [c.id, c.id])
        #expect(store.assignments.allSatisfy { $0.reminder && !$0.done })
        #expect(store.assignments.map(\.kind) == [.assignment, .exam])
        #expect(store.assignments[0].dueTime == "23:59" && store.assignments[1].dueTime == nil)
        #expect(store.assignments[0].sourceUID == "essay@u.edu")

        // Saved once, read back the same.
        let loaded = Store.load()
        #expect(loaded.courses == store.courses)
        #expect(loaded.assignments == store.assignments)
    }

    @Test func workWithNoClassInTheImportGoesToTheInbox() {
        let store = fresh()
        store.courses = [Course(name: "Biology", short: "Bio", color: .mint, days: [1], startMin: 600, endMin: 650)]
        #expect(store.importItems([], [essay]))
        #expect(store.assignments.count == 1)
        #expect(store.assignments[0].courseID == nil)
    }

    @Test func anUnknownColorIsIndigoAndMeetingsComeAlong() {
        let store = fresh()
        var lab = chem
        lab.color = "not-a-color"
        lab.additionalMeetings = [ClassMeeting(days: [3], start: 840, end: 960, room: "Lab")]
        lab.credits = 4
        lab.instructor = "Dr. Awuor"
        #expect(store.importItems([lab], []))
        let c = store.courses[0]
        #expect(c.color == .indigo)
        #expect(c.additionalMeetings.map(\.room) == ["Lab"])
        #expect(c.credits == 4 && c.instructor == "Dr. Awuor")
    }

    @Test func aFailedSaveAddsNothing() {
        let store = fresh()
        #expect(blockWrites())
        #expect(!store.importItems([chem], [essay]))
        #expect(store.courses.isEmpty && store.assignments.isEmpty)
        #expect(store.lastSaveFailed)
        unblock()
    }

    @Test func theTermQuestionIsOnlyForAnEmptyUnsetPlanner() {
        let store = fresh()
        #expect(store.shouldOfferTermSetup)
        // A class: no.
        store.courses = [Course(name: "Biology", short: "Bio", color: .mint, days: [1], startMin: 600, endMin: 650)]
        #expect(!store.shouldOfferTermSetup)
        // A deleted class doesn't count; an archived one does (the web's `classes`).
        store.courses[0].deletedAt = .now
        #expect(store.shouldOfferTermSetup)
        store.courses[0].deletedAt = nil
        store.courses[0].archived = true
        #expect(!store.shouldOfferTermSetup)
        // Asked before, or a semester day already set: no.
        store.courses = []
        store.profile.termSetupPrompted = true
        #expect(!store.shouldOfferTermSetup)
        store.profile.termSetupPrompted = false
        store.profile.termEnd = "2026-12-18"
        #expect(!store.shouldOfferTermSetup)
    }

    @Test func notNowAndSaveBothStopTheQuestion() {
        let store = fresh()
        // Not now: asked, nothing set.
        #expect(store.finishTermSetup())
        #expect(store.profile.termSetupPrompted)
        #expect(store.profile.termStart == nil && store.profile.termEnd == nil)

        // Saving the days.
        let other = fresh()
        #expect(other.finishTermSetup(start: "2026-08-31", end: "2026-12-18"))
        let loaded = Store.load()
        #expect(loaded.profile.termSetupPrompted)
        #expect(loaded.profile.termStart == "2026-08-31" && loaded.profile.termEnd == "2026-12-18")
        #expect(!loaded.shouldOfferTermSetup)
    }

    @Test func aDayThatIsntRealIsRefused() {
        let store = fresh()
        #expect(!store.finishTermSetup(start: "2026-02-30", end: "2026-12-18"))
        #expect(!store.profile.termSetupPrompted)
        #expect(store.profile.termStart == nil)
    }

    @Test func aFailedSaveKeepsTheQuestion() {
        let store = fresh()
        #expect(blockWrites())
        #expect(!store.finishTermSetup(start: "2026-08-31", end: "2026-12-18"))
        #expect(!store.profile.termSetupPrompted && store.profile.termStart == nil)
        unblock()
    }
}

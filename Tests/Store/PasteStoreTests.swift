// PasteStoreTests.swift: a pasted timetable through the store (13b). The
// paste is read and built by Logic/PasteSchedule.swift and added with 13a's
// importItems; the planner's meetings are what the review checks repeats
// against. Uses an isolated Documents path, never the real planner file.
// Run: tools/persistence-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct PasteStoreTests {
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    /// The web's "Use example table", plus a teacher and credits.
    private let example = "Course\tDays\tStart\tEnd\tRoom\tTeacher\tCredits\n"
        + "Biology\tMon/Wed\t9:00 AM\t10:00 AM\tScience 204\tDr. Awuor\t4\n"
        + "Biology\tThu\t2:00 PM\t4:00 PM\tLab 3\tDr. Awuor\t4"

    private let lab = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!

    /// The example read and built into classes, grouped.
    private func classes(_ text: String) -> [ImportedClass] {
        guard case .success(let rows) = readPastedSchedule(text),
              case .success(let built) = buildPastedClasses(rows, group: true, newID: { lab }) else {
            Issue.record("the paste didn't build")
            return []
        }
        return built
    }

    /// The review's first ticks against what the store holds now.
    private func ticks(_ store: Store, _ text: String) -> [Bool] {
        guard case .success(let rows) = readPastedSchedule(text) else { return [] }
        return reviewRows(rows, existing: existingSlotKeys(store.activeCourses) { $0.name }).map(\.selected)
    }

    @Test func aGroupedPasteIsOneClassThatSurvivesARelaunch() {
        let store = fresh()
        #expect(store.importItems(classes(example), []))
        #expect(store.courses.count == 1)
        let c = store.courses[0]
        #expect(c.name == "Biology" && c.short == "Biolo" && c.color == .indigo)
        #expect(c.days == [0, 2] && c.startMin == 540 && c.endMin == 600 && c.room == "Science 204")
        #expect(c.instructor == "Dr. Awuor" && c.credits == 4)
        #expect(c.remindBefore == 15 && c.alarm)
        #expect(c.additionalMeetings == [ClassMeeting(id: lab, days: [3], start: 840, end: 960, room: "Lab 3")])
        // Both meetings on the week: the main one and the lab.
        #expect(classMeetings(c).count == 2)

        let loaded = Store.load()
        #expect(loaded.courses == store.courses)
    }

    @Test func pastingTheSameTimetableAgainStartsUnticked() {
        let store = fresh()
        #expect(ticks(store, example) == [true, true])
        #expect(store.importItems(classes(example), []))
        #expect(ticks(store, example) == [false, false])
        // A relaunch remembers them.
        #expect(ticks(Store.load(), example) == [false, false])
    }

    @Test func deletedAndArchivedClassesArentRepeats() {
        let store = fresh()
        store.courses = [
            Course(name: "Biology", short: "Biolo", color: .mint, days: [0, 2], startMin: 540, endMin: 600,
                   room: "Science 204"),
            Course(name: "Biology", short: "Biolo", color: .mint, days: [3], startMin: 840, endMin: 960,
                   room: "Lab 3"),
        ]
        store.courses[0].archived = true
        store.courses[1].deletedAt = .now
        #expect(ticks(store, example) == [true, true])
        // Live again, both count.
        store.courses[0].archived = false
        store.courses[1].deletedAt = nil
        #expect(ticks(store, example) == [false, false])
    }

    @Test func theTermQuestionFollowsOnlyAFirstPasteOrAFirstClass() {
        // A paste into an empty planner: asked (read before adding).
        let store = fresh()
        #expect(store.shouldOfferTermSetup)
        #expect(store.importItems(classes(example), []))
        #expect(!store.shouldOfferTermSetup)

        // A first class typed in the form: the same test, read before Save.
        let typed = fresh()
        #expect(typed.shouldOfferTermSetup)
        typed.addCourse(Course(name: "Art", short: "Art", color: .coral, days: [4], startMin: 840, endMin: 900))
        #expect(!typed.lastSaveFailed)
        #expect(!typed.shouldOfferTermSetup)
        // Answered Not now, a later empty planner isn't asked again.
        #expect(typed.finishTermSetup())
        typed.courses = []
        #expect(!typed.shouldOfferTermSetup)
    }
}

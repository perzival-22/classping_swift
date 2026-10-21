// Phase 11a: your name and picture, the term's name and dates, and "Start a
// new term". Uses an isolated Documents path, never the real planner file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct ProfileStoreTests {
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    private func course(_ name: String) -> Course {
        Course(name: name, short: String(name.prefix(3)), color: .teal,
               days: [0], startMin: 600, endMin: 660)
    }

    /// Puts a folder where planner.json goes, so the next save fails.
    private func blockWrites() -> Bool {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return (try? FileManager.default.createDirectory(at: Store.fileURL,
                                                         withIntermediateDirectories: false)) != nil
    }

    private func unblock() {
        try? FileManager.default.removeItem(at: Store.fileURL)
    }

    @Test func aNameIsTrimmedAndABlankOneKeepsTheOld() {
        let store = fresh()
        #expect(store.setUsername("  kelvin.m  "))
        #expect(Store.load().profile.username == "kelvin.m")
        #expect(store.setUsername("   "))
        #expect(store.profile.username == "kelvin.m")
        #expect(Store.load().profile.username == "kelvin.m")
    }

    @Test func aPictureIsKeptAndCanBeRemoved() {
        let store = fresh()
        let uri = "data:image/jpeg;base64,/9j/4AAQ"
        #expect(store.setAvatar(uri))
        #expect(Store.load().profile.avatarURL == uri)
        #expect(store.setAvatar("https://blob.vercel-storage.com/a.jpg"))
        #expect(store.setAvatar(nil))
        #expect(Store.load().profile.avatarURL == nil)
    }

    @Test func picturesThatCantComeBackAreRefused() {
        let store = fresh()
        #expect(!store.setAvatar("blob:https://classping.app/1234"))
        #expect(!store.setAvatar("data:text/plain;base64,AAAA"))
        let huge = "data:image/jpeg;base64," + String(repeating: "A", count: AVATAR_MAX_ENCODED_CHARS)
        #expect(!store.setAvatar(huge))
        #expect(store.profile.avatarURL == nil)
        #expect(Store.load().profile.avatarURL == nil)
    }

    @Test func theTermNameIsTrimmedCappedAndBlankMeansNone() {
        let store = fresh()
        #expect(store.setTermName("  Fall 2026 "))
        #expect(Store.load().profile.termName == "Fall 2026")
        #expect(store.setTermName(String(repeating: "x", count: 80)))
        #expect(Store.load().profile.termName?.count == 64)
        #expect(store.setTermName("  "))
        #expect(Store.load().profile.termName == nil)
    }

    @Test func termDatesSaveClearAndRefuseImpossibleDays() {
        let store = fresh()
        #expect(store.setTermDates(start: "2026-09-01", end: "2026-12-18"))
        var loaded = Store.load().profile
        #expect(loaded.termStart == "2026-09-01")
        #expect(loaded.termEnd == "2026-12-18")
        #expect(!store.setTermDates(start: "2026-02-30", end: "2026-12-18"))
        #expect(!store.setTermDates(start: "2026-09-01", end: "18/12/2026"))
        #expect(store.profile.termStart == "2026-09-01")
        // An end before the start is kept: the card says so instead.
        #expect(store.setTermDates(start: "2026-12-18", end: "2026-09-01"))
        #expect(store.setTermDates(start: nil, end: "2026-12-18"))
        loaded = Store.load().profile
        #expect(loaded.termStart == nil)
        #expect(loaded.termEnd == "2026-12-18")
    }

    @Test func startingANewTermFilesEveryClassUnderItsName() {
        let store = fresh()
        let bio = course("Biology")
        let chem = course("Chemistry")
        let gone = course("Drama")
        var old = course("History")
        old.archived = true
        old.term = "Spring 2026"
        for c in [bio, chem, gone, old] { store.addCourse(c) }
        store.deleteCourse(gone.id)
        store.setTermName("Fall 2026")
        store.setTermDates(start: "2026-09-01", end: "2026-12-18")

        #expect(store.archiveTerm("  Fall 2026 "))
        #expect(store.activeCourses.isEmpty)
        let loaded = Store.load()
        let term = { (id: UUID) in loaded.courses.first(where: { $0.id == id })?.term }
        #expect(loaded.courses.allSatisfy { $0.archived })
        #expect(term(bio.id) == "Fall 2026")
        #expect(term(chem.id) == "Fall 2026")
        // Deleted classes too, so one restored later knows its term.
        #expect(term(gone.id) == "Fall 2026")
        // A class from an earlier term keeps that term.
        #expect(term(old.id) == "Spring 2026")
        // The name and dates described the term just archived.
        #expect(loaded.profile.termName == nil)
        #expect(loaded.profile.termStart == nil)
        #expect(loaded.profile.termEnd == nil)
    }

    @Test func aTermNeedsAName() {
        let store = fresh()
        store.addCourse(course("Biology"))
        #expect(!store.archiveTerm("   "))
        #expect(store.activeCourses.count == 1)
        #expect(Store.load().activeCourses.count == 1)
    }

    @Test func aFailedSavePutsEverythingBack() {
        let store = fresh()
        let bio = course("Biology")
        store.addCourse(bio)
        store.setUsername("kelvin")
        store.setTermName("Fall 2026")
        store.setTermDates(start: "2026-09-01", end: "2026-12-18")
        #expect(blockWrites())

        #expect(!store.setUsername("someone else"))
        #expect(store.profile.username == "kelvin")
        #expect(!store.setAvatar("data:image/jpeg;base64,AAAA"))
        #expect(store.profile.avatarURL == nil)
        #expect(!store.setTermName("Winter"))
        #expect(store.profile.termName == "Fall 2026")
        #expect(!store.setTermDates(start: nil, end: nil))
        #expect(store.profile.termStart == "2026-09-01")
        #expect(!store.archiveTerm("Fall 2026"))
        #expect(store.activeCourses.map(\.id) == [bio.id])
        #expect(store.profile.termName == "Fall 2026")
        #expect(store.lastSaveFailed)

        unblock()
        #expect(store.archiveTerm("Fall 2026"))
        #expect(!store.lastSaveFailed)
        #expect(Store.load().activeCourses.isEmpty)
    }
}

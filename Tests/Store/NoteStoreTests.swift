// NoteStoreTests.swift: Phase 8a. The note actions in Store+Notes.swift
// against a real save and reload, like PlanningStoreTests.
// Run: scripts/test-store.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct NoteStoreTests {
    /// An empty store on a fresh planner file.
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    @Test func addEditAndReloadANote() {
        let store = freshStore()
        let bio = Course(name: "Biology", short: "Bio", color: .teal, days: [0], startMin: 600, endMin: 660)
        store.addCourse(bio)
        let id = store.addNote(courseID: bio.id, date: "2026-09-14")
        #expect(store.note(id)?.body == "")
        #expect(store.updateNote(id, body: "# Cells\nMitochondria"))
        #expect(store.updateNote(id, title: "Week 3"))

        let loaded = Store.load()
        #expect(loaded.note(id)?.title == "Week 3")
        #expect(loaded.note(id)?.body == "# Cells\nMitochondria")
        #expect(loaded.note(id)?.courseID == bio.id)
        #expect(loaded.noteCount(for: bio.id) == 1)
        #expect(loaded.notes(for: nil).isEmpty)
    }

    @Test func anEditPastTheLimitIsRefusedAndChangesNothing() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-09-14")
        store.updateNote(id, body: "kept")
        let before = store.note(id)?.updatedAt
        #expect(!store.updateNote(id, body: String(repeating: "x", count: maxNoteChars + 1)))
        #expect(store.note(id)?.body == "kept")
        #expect(store.note(id)?.updatedAt == before)
        // The title alone still saves.
        #expect(store.updateNote(id, title: "Still named"))
        #expect(Store.load().note(id)?.title == "Still named")
    }

    @Test func anUnchangedSaveWritesNothing() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-09-14")
        store.updateNote(id, title: "Same", body: "Same")
        let stamp = store.note(id)?.updatedAt
        // A fixed file date detects a rewrite even if the note's stamp is kept.
        let fileStamp = Date(timeIntervalSince1970: 1_700_000_000)
        try? FileManager.default.setAttributes([.modificationDate: fileStamp],
                                               ofItemAtPath: Store.fileURL.path)
        #expect(store.updateNote(id, title: "Same", body: "Same"))
        #expect(store.note(id)?.updatedAt == stamp)
        let attributes = try? FileManager.default.attributesOfItem(atPath: Store.fileURL.path)
        #expect(attributes?[.modificationDate] as? Date == fileStamp)
    }

    @Test func notesComeNewestDayFirstAndQuickNotesStandApart() {
        let store = freshStore()
        let bio = Course(name: "Biology", short: "Bio", color: .teal, days: [0], startMin: 600, endMin: 660)
        store.addCourse(bio)
        let older = store.addNote(courseID: bio.id, date: "2026-09-07")
        let newer = store.addNote(courseID: bio.id, date: "2026-09-14")
        let quick = store.addNote(courseID: nil, date: "2026-09-10")
        #expect(store.notes(for: bio.id).map(\.id) == [newer, older])
        #expect(store.notes(for: nil).map(\.id) == [quick])
        #expect(store.todaysNote(for: bio.id, now: Calendar.current.date(
            from: DateComponents(year: 2026, month: 9, day: 14, hour: 10))!)?.id == newer)
        #expect(store.todaysNote(for: bio.id, now: Calendar.current.date(
            from: DateComponents(year: 2026, month: 9, day: 15, hour: 10))!) == nil)
    }

    @Test func searchFindsByWordsAndByClassName() {
        let store = freshStore()
        let bio = Course(name: "Biology", short: "Bio", color: .teal, days: [0], startMin: 600, endMin: 660)
        store.addCourse(bio)
        let cells = store.addNote(courseID: bio.id, date: "2026-09-14")
        store.updateNote(cells, body: "**Osmosis** and diffusion")
        let quick = store.addNote(courseID: nil, date: "2026-09-14")
        store.updateNote(quick, body: "Call the lab")
        #expect(store.searchNotes("osmosis").map(\.id) == [cells])
        #expect(store.searchNotes("biology").map(\.id) == [cells])
        #expect(store.searchNotes("quick note").map(\.id) == [quick])
        #expect(store.searchNotes("").isEmpty)
    }

    @Test func deleteOffersUndoAndUndoBringsItBack() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-09-14")
        store.updateNote(id, title: "Week 3")
        store.deleteNote(id)
        #expect(store.note(id) == nil)
        #expect(store.pendingUndo?.item == .note(id))
        #expect(store.pendingUndo?.label == "Week 3 deleted")
        // Still in the file, marked deleted, for Recently Deleted (Phase 11).
        #expect(Store.load().notes.first { $0.id == id }?.deletedAt != nil)
        // An edit to a deleted note is refused.
        #expect(!store.updateNote(id, body: "late typing"))

        store.undoDelete()
        #expect(store.note(id)?.title == "Week 3")
        #expect(store.pendingUndo == nil)
        #expect(Store.load().note(id) != nil)
    }

    @Test func anUntitledNoteIsDeletedAsNote() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-09-14")
        store.deleteNote(id)
        #expect(store.pendingUndo?.label == "Note deleted")
    }

    @Test func theBudgetCountsEmojiAndRefusesTheWholeEdit() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-09-14")
        let body = String(repeating: "😀", count: maxNoteChars / 2)
        #expect(store.updateNote(id, title: "Kept", body: body))
        let stamp = store.note(id)?.updatedAt
        #expect(!store.updateNote(id, title: "Rejected too", body: body + "😀"))
        #expect(store.note(id)?.updatedAt == stamp)
        #expect(Store.load().note(id)?.title == "Kept")
        #expect(Store.load().note(id)?.body == body)
    }

    @Test func retryingTheSameDraftAfterAFailedWritePersistsIt() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-09-14")
        try? FileManager.default.removeItem(at: Store.fileURL)
        let blocked = (try? FileManager.default.createDirectory(
            at: Store.fileURL, withIntermediateDirectories: false)) != nil
        #expect(blocked)
        guard blocked else { return }
        #expect(store.updateNote(id, title: "Lecture", body: "Latest words"))
        #expect(store.lastSaveFailed)
        let stamp = store.note(id)?.updatedAt
        try? FileManager.default.removeItem(at: Store.fileURL)

        // Retry, backgrounding and leaving all submit the same draft again.
        #expect(store.updateNote(id, title: "Lecture", body: "Latest words"))
        #expect(!store.lastSaveFailed)
        #expect(store.note(id)?.updatedAt == stamp)
        #expect(Store.load().note(id)?.body == "Latest words")
    }

    @Test func sameDayNotesUseTheLatestEditAndKeepTheirAssignmentLink() {
        let store = freshStore()
        let courseID = UUID()
        let assignmentID = UUID()
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        let first = Note(courseID: courseID, date: dayOf(now), title: "Latest edit",
                         assignmentID: assignmentID, updatedAt: now.addingTimeInterval(10))
        let second = Note(courseID: courseID, date: dayOf(now), title: "Earlier edit", updatedAt: now)
        store.notes = [second, first]
        store.save()
        let loaded = Store.load()
        #expect(loaded.notes(for: courseID).map(\.id) == [first.id, second.id])
        #expect(loaded.todaysNote(for: courseID, now: now)?.id == first.id)
        #expect(loaded.note(first.id)?.assignmentID == assignmentID)
    }

    @Test func archivedCoursesRemainSearchableAndDeletedNotesStayOut() {
        let store = freshStore()
        var bio = Course(name: "Biology", short: "Bio", color: .teal,
                         days: [0], startMin: 600, endMin: 660)
        bio.archived = true
        store.addCourse(bio)
        let id = store.addNote(courseID: bio.id, date: "2026-09-14")
        #expect(store.activeCourses.isEmpty)
        #expect(store.searchNotes("biology").map(\.id) == [id])
        store.deleteNote(id)
        #expect(store.searchNotes("biology").isEmpty)
        #expect(store.noteCount(for: bio.id) == 0)
        #expect(store.todaysNote(for: bio.id) == nil)
        store.undoDelete()
        #expect(Store.load().searchNotes("biology").map(\.id) == [id])
    }
}

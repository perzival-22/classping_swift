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

    @Test func formattingPersistsAndTheReaderKeepsItsMeaning() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-10-19")
        let bold = toggleMark(.bold, in: NoteEdit(text: "cell", selection: 0..<4))
        let marked = highlight(in: bold)
        store.updateNote(id, title: "Biology", body: marked.text)
        let loaded = Store.load()
        let runs = noteRuns(loaded.note(id)?.body ?? "")
        #expect(runs == [InlineRun(text: "cell", bold: true, highlight: true)])
        #expect(loaded.note(id)?.title == "Biology")
    }

    @Test func tidyPreviewApplyAndUndoPreserveTheNoteAndItsLinks() {
        let store = freshStore()
        let courseID = UUID()
        let assignmentID = UUID()
        let id = store.addNote(courseID: courseID, date: "2026-10-19", assignmentID: assignmentID)
        let source = "BIOLOGY 101\nCell parts:\nnucleus\nmitochondria\nribosome"
        store.updateNote(id, title: "Lecture", body: source)
        let tidy = tidyNote(source)
        #expect(tidy.changed)
        // Previewing or discarding a pure tidy has no store side effect.
        #expect(Store.load().note(id)?.body == source)
        #expect(store.saveNoteBody(id, body: tidy.body))
        let applied = Store.load().note(id)
        #expect(applied?.body == tidy.body)
        #expect(applied?.title == "Lecture")
        #expect(applied?.courseID == courseID)
        #expect(applied?.assignmentID == assignmentID)
        #expect(parseBlocks(applied?.body ?? "").map(\.kind) == [.h2, .p, .h2, .ul, .ul, .ul])
        #expect(store.saveNoteBody(id, body: source))
        #expect(Store.load().note(id)?.body == source)
    }

    @Test func failedTidyApplyOrUndoKeepsTheOriginalAndCanBeRetried() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-10-19")
        let source = "NOTES\nfirst point\nsecond point"
        store.updateNote(id, body: source)
        let tidy = tidyNote(source)
        let original = store.note(id)

        // Use an unwritable planner destination without touching real files.
        try? FileManager.default.removeItem(at: Store.fileURL)
        let blocked = (try? FileManager.default.createDirectory(
            at: Store.fileURL, withIntermediateDirectories: false)) != nil
        #expect(blocked)
        guard blocked else { return }
        #expect(!store.saveNoteBody(id, body: tidy.body))
        #expect(store.lastSaveFailed)
        #expect(store.note(id) == original)
        try? FileManager.default.removeItem(at: Store.fileURL)
        #expect(store.saveNoteBody(id, body: tidy.body))
        #expect(!store.lastSaveFailed)
        #expect(Store.load().note(id)?.body == tidy.body)

        let applied = store.note(id)
        try? FileManager.default.removeItem(at: Store.fileURL)
        let undoBlocked = (try? FileManager.default.createDirectory(
            at: Store.fileURL, withIntermediateDirectories: false)) != nil
        #expect(undoBlocked)
        guard undoBlocked else { return }
        #expect(!store.saveNoteBody(id, body: source))
        #expect(store.note(id) == applied)
        try? FileManager.default.removeItem(at: Store.fileURL)
        #expect(store.saveNoteBody(id, body: source))
        #expect(Store.load().note(id)?.body == source)
    }

    @Test func previewedBodyChangesCannotReplaceDeletedOrOverBudgetNotes() {
        let store = freshStore()
        let id = store.addNote(courseID: nil, date: "2026-10-19")
        store.updateNote(id, body: "Kept")
        let original = store.note(id)
        #expect(!store.saveNoteBody(id, body: String(repeating: "x", count: maxNoteChars + 1)))
        #expect(store.note(id) == original)
        #expect(Store.load().note(id)?.body == "Kept")
        store.deleteNote(id)
        #expect(!store.saveNoteBody(id, body: "Late tidy"))
        store.undoDelete()
        #expect(Store.load().note(id)?.body == "Kept")
    }
    // MARK: - Phase 8d: notes linked to a task, and a task from a note

    /// Two classes and a task in the first, saved, for the link tests.
    private func bioChemAndALab(_ store: Store) -> (bio: Course, chem: Course, lab: Assignment) {
        let bio = Course(name: "Biology", short: "Bio", color: .teal, days: [0], startMin: 600, endMin: 660)
        let chem = Course(name: "Chemistry", short: "Chem", color: .ocean, days: [1], startMin: 600, endMin: 660)
        store.addCourse(bio)
        store.addCourse(chem)
        let lab = Assignment(courseID: bio.id, title: "Lab report", due: "2026-10-23")
        store.addAssignment(lab)
        return (bio, chem, lab)
    }

    @Test func linkingAndUnlinkingANoteSurvivesAReload() {
        let store = freshStore()
        let (bio, _, lab) = bioChemAndALab(store)
        let id = store.addNote(courseID: bio.id, date: "2026-10-19")
        store.linkNote(id, to: lab.id)
        #expect(store.linkedNotes(for: lab.id).map(\.id) == [id])
        #expect(Store.load().note(id)?.assignmentID == lab.id)

        store.linkNote(id, to: nil)
        #expect(store.linkedNotes(for: lab.id).isEmpty)
        let loaded = Store.load()
        #expect(loaded.note(id)?.assignmentID == nil)
        // Unlinking keeps the note itself.
        #expect(loaded.note(id)?.courseID == bio.id)
    }

    @Test func aLinkMovesTheNoteStampButTheSameLinkAgainWritesNothing() {
        let store = freshStore()
        let (bio, _, lab) = bioChemAndALab(store)
        let id = store.addNote(courseID: bio.id, date: "2026-10-19")
        let made = store.note(id)?.updatedAt ?? .distantFuture
        store.linkNote(id, to: lab.id)
        let linked = store.note(id)?.updatedAt ?? .distantPast
        #expect(linked >= made)

        // A fixed file date shows whether the planner was written again.
        let fileStamp = Date(timeIntervalSince1970: 1_700_000_000)
        try? FileManager.default.setAttributes([.modificationDate: fileStamp],
                                               ofItemAtPath: Store.fileURL.path)
        store.linkNote(id, to: lab.id)
        #expect(store.note(id)?.updatedAt == linked)
        let attributes = try? FileManager.default.attributesOfItem(atPath: Store.fileURL.path)
        #expect(attributes?[.modificationDate] as? Date == fileStamp)
    }

    @Test func linkableNotesAreUnlinkedOnesFromTheTasksClass() {
        let store = freshStore()
        let (bio, chem, lab) = bioChemAndALab(store)
        let other = Assignment(courseID: bio.id, title: "Reading", due: "2026-10-24")
        store.addAssignment(other)
        let free = store.addNote(courseID: bio.id, date: "2026-10-19")
        let taken = store.addNote(courseID: bio.id, date: "2026-10-19", assignmentID: other.id)
        let chemNote = store.addNote(courseID: chem.id, date: "2026-10-19")
        let quick = store.addNote(courseID: nil, date: "2026-10-19")
        let gone = store.addNote(courseID: bio.id, date: "2026-10-19")
        store.deleteNote(gone)

        // A class's task: that class's unlinked notes only.
        #expect(store.linkableNotes(for: lab).map(\.id) == [free])
        // An Inbox task: any unlinked note, in the order they were made.
        let inbox = Assignment(title: "Email advisor")
        store.addAssignment(inbox)
        #expect(store.linkableNotes(for: inbox).map(\.id) == [free, chemNote, quick])
        // The taken one shows on its own task instead.
        #expect(store.linkedNotes(for: other.id).map(\.id) == [taken])
    }

    @Test func aDeletedLinkedNoteLeavesTheTaskAndComesBackWithUndo() {
        let store = freshStore()
        let (bio, _, lab) = bioChemAndALab(store)
        let id = store.addNote(courseID: bio.id, date: "2026-10-19", assignmentID: lab.id)
        store.deleteNote(id)
        #expect(store.linkedNotes(for: lab.id).isEmpty)
        store.undoDelete()
        #expect(store.linkedNotes(for: lab.id).map(\.id) == [id])
    }

    @Test func deletingATaskKeepsItsLinksSoUndoBringsThemBack() {
        let store = freshStore()
        let (bio, _, lab) = bioChemAndALab(store)
        let id = store.addNote(courseID: bio.id, date: "2026-10-19", assignmentID: lab.id)
        store.deleteAssignment(lab.id)
        // The note stays, still pointing at the task, as on the web.
        #expect(store.note(id)?.assignmentID == lab.id)
        store.undoDelete()
        #expect(Store.load().linkedNotes(for: lab.id).map(\.id) == [id])
    }

    @Test func aQuickAssignmentIsFiledForTheNotesClass() {
        let store = freshStore()
        let (_, chem, _) = bioChemAndALab(store)
        let id = store.addQuickTask(.assignment, title: "", type: .quiz, courseID: chem.id,
                                    due: "2026-10-22", dueTime: nil)
        #expect(id != nil)
        let filed = Store.load().assignment(id ?? UUID())
        #expect(filed?.title == "Chemistry quiz")
        #expect(filed?.kind == .quiz)
        #expect(filed?.courseID == chem.id)
        #expect(filed?.due == "2026-10-22")
        #expect(filed?.dueTime == nil)
        #expect(filed?.reminder == true)
        #expect(filed?.done == false)
    }

    @Test func aQuickReminderNeedsWordsAndKeepsItsTime() {
        let store = freshStore()
        let (bio, _, _) = bioChemAndALab(store)
        let before = store.liveAssignments.count
        // Blank: nothing filed. The type is ignored for a reminder.
        #expect(store.addQuickTask(.reminder, title: "  ", type: .exam, courseID: bio.id,
                                   due: "2026-10-20", dueTime: nil) == nil)
        #expect(store.liveAssignments.count == before)

        let id = store.addQuickTask(.reminder, title: " Bring goggles ", type: .exam,
                                    courseID: bio.id, due: "2026-10-20", dueTime: "08:30")
        let filed = Store.load().assignment(id ?? UUID())
        #expect(filed?.title == "Bring goggles")
        #expect(filed?.kind == .reminder)
        #expect(filed?.dueTime == "08:30")
        #expect(filed?.reminder == true)
    }

    @Test func aQuickTaskFromAQuickNoteGoesToTheInbox() {
        let store = freshStore()
        let id = store.addQuickTask(.assignment, title: "", type: .exam, courseID: nil,
                                    due: "2026-10-22", dueTime: nil)
        let filed = store.assignment(id ?? UUID())
        #expect(filed?.courseID == nil)
        #expect(filed?.title == "Quick note exam")
    }
}

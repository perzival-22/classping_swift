//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Notes.swift
//  Phase:   8a (notes you can write and find), changed in 8c (tidy saves)
//  Ports:   lib/store.tsx (liveNotes, notesForClass, addNote, updateNote,
//           deleteNote, noteById) and, from app/classes/page.tsx, the note
//           counts, the search and today's note for a class that's on
//
//  Summary: Everything that reads or changes a note. A note belongs to a
//           class, or to none (a quick note), and to the day it was taken.
//           Each change saves to the phone straight away, and a delete can
//           be undone, like an assignment's.
//

import Foundation

/// Newest day first; on the same day, the latest edit first. "yyyy-MM-dd"
/// text sorts like the dates it names. The sort in `notesForClass`.
private func newestFirst(_ a: Note, _ b: Note) -> Bool {
    a.date != b.date ? a.date > b.date : a.updatedAt > b.updatedAt
}

extension Store {
    // MARK: - Reading

    /// Every note that hasn't been deleted. `liveNotes` in lib/store.tsx.
    var liveNotes: [Note] {
        notes.filter { $0.deletedAt == nil }
    }

    /// One live note by id, or nil. `noteById`.
    func note(_ id: UUID) -> Note? {
        liveNotes.first { $0.id == id }
    }

    /// A class's notes, newest first. Nil asks for the quick notes, the ones
    /// with no class. `notesForClass`.
    func notes(for courseID: UUID?) -> [Note] {
        liveNotes.filter { $0.courseID == courseID }.sorted(by: newestFirst)
    }

    /// How many notes a class holds, for its row on the Notes tab.
    func noteCount(for courseID: UUID) -> Int {
        liveNotes.filter { $0.courseID == courseID }.count
    }

    /// Today's note for a class, if one was started: what "Take notes, this
    /// class is on now" reopens, so a second visit mid-lecture keeps typing
    /// instead of filing a blank twin. `startTodaysNote` in app/classes.
    func todaysNote(for courseID: UUID, now: Date = .now) -> Note? {
        notes(for: courseID).first { $0.date == dayOf(now) }
    }

    /// The notes a search finds, newest first. A note with no class is
    /// searched as "Quick note". The search in app/classes/page.tsx.
    func searchNotes(_ query: String) -> [Note] {
        liveNotes
            .filter { n in
                noteMatches(query, title: n.title, body: n.body,
                            subject: course(n.courseID)?.name ?? "Quick note")
            }
            .sorted(by: newestFirst)
    }

    // MARK: - Writing

    /// Starts an empty note and hands back its id, so the screen can open it
    /// at once. `addNote(classId, date, taskId)`. `@discardableResult` lets a
    /// caller ignore the id without a warning.
    @discardableResult
    func addNote(courseID: UUID?, date: String, assignmentID: UUID? = nil) -> UUID {
        let note = Note(courseID: courseID, date: date, assignmentID: assignmentID)
        notes.append(note)
        save()
        return note.id
    }

    /// Saves an edit to a note's title, body, or both (nil leaves one as it
    /// is). False, with nothing saved, when the body would pass the 20,000
    /// character limit, so the screen can say so instead of losing words
    /// quietly. `updateNote` in lib/store.tsx.
    @discardableResult
    func updateNote(_ id: UUID, title: String? = nil, body: String? = nil) -> Bool {
        guard let i = notes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return false }
        if let body, !fitsBudget(noteLength(body)) { return false }

        // A save that changes nothing writes nothing, unless the last write
        // failed and the same draft is now being retried. The screen saves
        // on a timer, when you leave it and when the app goes away, so the
        // same text often arrives more than once.
        let newTitle = title ?? notes[i].title
        let newBody = body ?? notes[i].body
        guard newTitle != notes[i].title || newBody != notes[i].body else {
            if lastSaveFailed { save() }
            return true
        }

        notes[i].title = newTitle
        notes[i].body = newBody
        notes[i].updatedAt = .now
        save()
        return true
    }

    /// Applies a previewed body change only if it reaches the planner file.
    /// Tidy's preview and Undo retain the proposed text for retry; on failure,
    /// restore the original in-memory note so Discard really changes nothing.
    /// Ordinary editor drafts keep using updateNote and its save feedback.
    func saveNoteBody(_ id: UUID, body: String) -> Bool {
        guard let original = note(id), updateNote(id, body: body) else { return false }
        guard lastSaveFailed else { return true }
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index] = original
        }
        return false
    }

    /// Moves a note to Recently Deleted and offers Undo, "Week 3 deleted"
    /// (or "Note deleted" when it has no title). `deleteNote`.
    func deleteNote(_ id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = Date.now
        notes[i].deletedAt = now
        let title = notes[i].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(item: .note(id),
                                  label: "\(title.isEmpty ? "Note" : title) deleted",
                                  at: now)
        save()
    }
}

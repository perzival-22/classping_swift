//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift
//  Phase:   8a (notes you can write and find), changed in 8b (read first)
//           and 8c (the formatting bar and tidy)
//  Ports:   NotePane in app/classes/page.tsx (the title, "class · day", the
//           bin), the saving half of components/NoteEditor.tsx (save half
//           a second after you stop typing, "Saving…" / "Saved", the 20,000
//           character limit and New page), since 8b the phone's view of a
//           note, components/NoteReader.tsx, and since 8c the Tidy note
//           button and its Undo (components/NoteTidyButton.tsx)
//
//  Summary: One note. A note with words in it opens to read, drawn by
//           NoteReaderView, with Tidy note above it; Edit switches to typing
//           it as plain markdown, with the formatting bar over the keyboard,
//           and Done goes back to reading (D-37). An empty note opens
//           straight for typing. Typing saves by itself a moment after you
//           stop, when you leave, and when the app goes to the background.
//

import SwiftUI

struct NoteView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss   // NEW in Phase 8b

    /// Which note to show. The note itself is looked up in the store.
    let noteID: UUID

    /// NEW in Phase 8b: true while typing, false while reading. Nil until the
    /// screen first appears, then settled once: an empty note opens for
    /// typing, one with words opens to read. Settled once, so typing a note's
    /// first words doesn't flip the screen over to reading.
    @State private var editing: Bool? = nil

    /// NEW in Phase 8c: a tidy waiting in its sheet for Apply or Discard.
    @State private var tidyPreview: TidyPreview? = nil

    /// NEW in Phase 8c: what Undo tidy puts back, and what Apply wrote. Undo
    /// shows while the note still holds exactly what Apply wrote; any edit
    /// after that and it's gone, as on the web.
    @State private var undoTidy: (original: String, applied: String)? = nil

    var body: some View {
        if let note = store.note(noteID) {
            // CHANGED in Phase 8b: reading or typing.
            let typing = editing ?? (note.title.isEmpty && note.body.isEmpty)
            Group {
                if typing {
                    NoteEditorView(note: note, onDone: { editing = false })
                } else {
                    reader(note)
                }
            }
            .toolbar {
                // The editor owns Done so it can flush its draft before the
                // reader appears, and retain the draft if saving fails.
                if !typing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { editing = true }
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear {
                if editing == nil { editing = typing }
            }
        } else {
            // Just deleted (the screen is on its way back), or never existed.
            ContentUnavailableView("Note not found.", systemImage: "note.text")
        }
    }

    /// NEW in Phase 8b: the note to read. Its title and where it lives, then
    /// the note drawn. Nothing here takes the keyboard, the web phone's point:
    /// a thumb brushing the page can't change a word.
    private func reader(_ note: Note) -> some View {
        let course = store.course(note.courseID)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                        .padding(.bottom, 12)
                }
                Text(noteTitle(title: note.title, body: note.body))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
                tidyRow(note)   // NEW in Phase 8c
                    .padding(.top, 12)
                Divider()
                    .padding(.vertical, 14)
                if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // The web's empty-note line, as in the editor.
                    Text("Start typing: # for a heading, - for a bullet, - [ ] for a checkbox")
                        .font(.system(size: 15.5))
                        .foregroundStyle(Theme.hint)
                } else {
                    NoteReaderView(markdown: note.body)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        // NEW in Phase 8c: the preview, until Apply or Discard. The note can't
        // change under it while it's up (nothing syncs yet, Phase 14), so
        // the web's "this note changed" check isn't needed.
        .sheet(item: $tidyPreview) { preview in
            NoteTidySheet(preview: preview) { tidied in
                guard store.saveNoteBody(note.id, body: tidied) else { return false }
                undoTidy = (original: preview.source, applied: tidied)
                return true
            }
        }
        .toolbar {
            // The bin, as in the editor: delete, and back to the list's Undo.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
        }
    }

    /// NEW in Phase 8c: Tidy note, and Undo tidy while it lasts. Tidy is off
    /// for a note with nothing in it.
    private func tidyRow(_ note: Note) -> some View {
        let accent = store.profile.accent
        let empty = note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 6) {
            Button {
                tidyPreview = TidyPreview(source: note.body)
            } label: {
                Label("Tidy note", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Theme.brandSoft(accent), in: Capsule())
            }
            .disabled(empty)
            .opacity(empty ? 0.5 : 1)

            if let undo = undoTidy, note.body == undo.applied {
                Button("Undo tidy") {
                    if store.saveNoteBody(note.id, body: undo.original) { undoTidy = nil }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
            }
        }
    }
}

/// The writing surface. A separate view so its scratch copy of the text can
/// start from the note once, in `init` (4a's `_title = State(...)`), and then
/// belong to the typing rather than to the store.
private struct NoteEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// The note as it was when the screen opened: its id, class and day.
    let note: Note

    /// Return to the reader after the whole draft has been saved.
    let onDone: () -> Void

    /// What's typed, which can run ahead of what's saved by half a second.
    @State private var title: String
    @State private var text: String

    /// NEW in Phase 8c: what's selected in the note, or where the caret is.
    /// Nil until the editor first reports one. The formatting bar reads it
    /// to know which words to change, and sets it to select what changed.
    @State private var selection: TextSelection? = nil

    /// The note started by New page, while it's open.
    @State private var nextPage: UUID?

    /// Which field has the keyboard, or nil for none. `@FocusState` is
    /// `@State` for the keyboard: set it to move the caret, set it to nil to
    /// put the keyboard away.
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    init(note: Note, onDone: @escaping () -> Void) {
        self.note = note
        self.onDone = onDone
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.body)
    }

    var body: some View {
        let course = store.course(note.courseID)
        let length = noteLength(text)
        let full = !fitsBudget(length)
        // Saved only when the draft matches and the file write succeeded.
        let saved = !store.lastSaveFailed
            && (store.note(note.id).map { $0.title == title && $0.body == text } ?? false)

        VStack(spacing: 0) {
            // MARK: Title, and where the note lives
            VStack(alignment: .leading, spacing: 2) {
                // The grey text is what the list would call it untitled.
                TextField(noteTitle(title: "", body: text), text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .title)
                    .accessibilityLabel("Note title")
                    // Return in the title moves down into the note.
                    .submitLabel(.next)
                    .onSubmit { focus = .body }
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // MARK: The note
            // `TextEditor` is a multi-line text field that scrolls by itself.
            // It has no placeholder, so one sits behind it while it's empty.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Start typing: # for a heading, - for a bullet, - [ ] for a checkbox")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.hint)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                // CHANGED in Phase 8c: `selection:` keeps `selection` up to date
                // as you move the caret, and moves it when `selection` is set.
                TextEditor(text: $text, selection: $selection)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .body)
                    .accessibilityLabel("Note body")
                    // Let the canvas show through instead of a white box.
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
            }

            // MARK: Saving
            // "Saving…" until the store has it, then "Saved". Near the limit,
            // the count and New page, so a long lecture goes on in a new note
            // instead of stopping at the ceiling.
            VStack(alignment: .leading, spacing: 6) {
                if store.lastSaveFailed {
                    HStack(spacing: 10) {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                        Button("Retry") { save() }
                            .font(.footnote.weight(.semibold))
                    }
                }
                Text(full ? "This note is full, start a new page to keep writing"
                          : (saved ? "Saved" : "Saving…"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
                if length > maxNoteChars * 9 / 10 {
                    HStack(spacing: 10) {
                        Text("\(length.formatted()) / \(maxNoteChars.formatted())")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(full ? Theme.dangerInk : Theme.warnInk)
                        Spacer(minLength: 0)
                        Button("New page") {
                            save()
                            nextPage = store.addNote(courseID: note.courseID, date: note.date,
                                                     assignmentID: note.assignmentID)
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }

            // MARK: The formatting bar
            // NEW in Phase 8c: last in the column, so with the keyboard up it
            // sits right on top of it. Hidden while you type the title,
            // since every button changes the note's words.
            if focus != .title {
                NoteFormatBar(apply: apply)
            }
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete goes straight back, where the Undo bar is waiting.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Flush the debounce first, so Undo restores the latest typing.
                    save()
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
            // Flush before replacing the editor. A refused body or failed
            // file write must leave the draft available to fix or retry.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    save()
                    guard fitsBudget(noteLength(text)), !store.lastSaveFailed else { return }
                    focus = nil
                    onDone()
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
        // Save half a second after the typing stops (the web's 500 ms).
        // Every keystroke changes the id, which cancels the waiting save and
        // starts a new wait: only the last one survives its sleep (4b, 7a).
        .task(id: Draft(title: title, body: text)) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
        // And straight away when you leave, or the app goes to the background.
        .onDisappear { save() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { save() }
        }
        // A new note and Edit both open intentionally for typing.
        .onAppear {
            focus = .body
        }
        .navigationDestination(item: $nextPage) { id in
            NoteView(noteID: id)
        }
    }

    /// What `.task(id:)` watches: the title and the body together.
    private struct Draft: Equatable {
        let title: String
        let body: String
    }

    /// NEW in Phase 8c: one of the bar's changes, run on what's typed and
    /// what's selected. The new text goes into `text`, so it saves the way
    /// typing does, and the new selection into the editor. The keyboard
    /// comes back too, for a tap made while it was away.
    private func apply(_ change: (NoteEdit) -> NoteEdit) {
        let before = NoteEdit(text: text, selection: selection)
        let after = change(before)
        if after != before {
            text = after.text
            selection = after.textSelection
        }
        focus = .body
    }

    /// Hands the store what's on screen. Past the limit, the title still
    /// saves and the body waits until it fits again, so nothing is cut off.
    private func save() {
        let fits = fitsBudget(noteLength(text))
        store.updateNote(note.id, title: title, body: fits ? text : nil)
    }
}

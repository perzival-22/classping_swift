//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/CourseNotesView.swift
//  Phase:   8a (notes you can write and find)
//  Ports:   NoteListPane in app/classes/page.tsx (one class's notes)
//
//  Summary: One class's notes, newest first: its book, timetable, room and
//           teacher at the top, then New note (or, while the class is on,
//           "Take notes, this class is on now", which reopens today's note),
//           then each note with its day and a line of preview. The pencil
//           edits the class; the bin deletes a note, with Undo.
//

import SwiftUI

struct CourseNotesView: View {
    @Environment(Store.self) private var store

    /// The class whose notes these are. Looked up in the store on every
    /// redraw, so an edit to the class shows straight away.
    let courseID: UUID

    /// The note New note just started, while it's open (as on the Notes tab).
    @State private var startedNote: UUID?
    /// The class open in the edit form, or nil.
    @State private var editingCourse: Course?
    /// The note waiting for "Delete this note?", or nil.
    @State private var deleting: Note?

    var body: some View {
        if let course = store.course(courseID) {
            content(course)
        } else {
            // Deleted from Today while this screen was open.
            ContentUnavailableView("Class not found.", systemImage: "book.closed")
        }
    }

    /// The screen for a class that exists.
    private func content(_ course: Course) -> some View {
        let accent = store.profile.accent
        let notes = store.notes(for: course.id)

        return TimelineView(.everyMinute) { context in
            let live = liveCourseID(store.activeCourses, now: context.date) == course.id

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Keep a failed deletion visible alongside its Undo offer.
                    if store.lastSaveFailed {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                    }
                    header(course)

                    // While the class is on, one tap reopens today's lecture
                    // note (or starts it); otherwise a fresh note, a new topic.
                    Button {
                        startedNote = live
                            ? (store.todaysNote(for: course.id)?.id
                               ?? store.addNote(courseID: course.id, date: dayOf(.now)))
                            : store.addNote(courseID: course.id, date: dayOf(.now))
                    } label: {
                        Label(live ? "Take notes, this class is on now" : "New note",
                              systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.brandGradient(accent),
                                        in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if notes.isEmpty {
                        Text("No notes yet for this class.\nStart one for today's lecture or a new topic, the date fills itself in.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(notes) { note in
                                noteRow(note)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.canvas)
        .navigationTitle(course.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCourse = course
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit class")
            }
        }
        .navigationDestination(item: $startedNote) { id in
            NoteView(noteID: id)
        }
        .sheet(item: $editingCourse) { original in
            NavigationStack {
                CourseFormView(editing: original)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editingCourse = nil }
                        }
                    }
            }
        }
        // The "are you sure?" for a note's bin (6b's confirmationDialog).
        // `presenting:` hands the waiting note to the buttons.
        .confirmationDialog("Delete this note?",
                            isPresented: Binding(get: { deleting != nil },
                                                 set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible,
                            presenting: deleting) { note in
            Button("Delete", role: .destructive) {
                store.deleteNote(note.id)
            }
        }
        .undoBar()
    }

    // MARK: - Pieces

    /// The book, then the class's times, room and teacher, and the focused
    /// minutes recorded for it once there are any. The name is the screen's
    /// title above.
    private func header(_ course: Course) -> some View {
        // One meeting: its times. More: the web's one-line summary of them all.
        let times = course.additionalMeetings.isEmpty
            ? "\(fmtTime(course.startMin)) – \(fmtTime(course.endMin))"
            : meetingSummary(course)
        let room = course.room.map { $0.isEmpty ? "" : " · \($0)" } ?? ""
        let teacher = course.instructor.map { $0.isEmpty ? "" : " · \($0)" } ?? ""
        let focused = studyMinutes(store.studySessions, courseID: course.id)

        return HStack(alignment: .top, spacing: 12) {
            SubjectBook(color: course.color, short: course.short)
            VStack(alignment: .leading, spacing: 2) {
                Text(times + room + teacher)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if focused > 0 {
                    Text("\(focused) focused minute\(focused == 1 ? "" : "s") recorded")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.brand(store.profile.accent))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One note: its title and day, a line of preview, and its bin. The bin
    /// sits beside the link rather than inside it, so tapping it can't also
    /// open the note.
    private func noteRow(_ note: Note) -> some View {
        let preview = notePreview(note.body)
        return HStack(spacing: 0) {
            NavigationLink(value: NoteLink(id: note.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(noteTitle(title: note.title, body: note.body))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(dayLabel(note.date))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.faint)
                    }
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                deleting = note
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface2, in: Circle())
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete note")
        }
        .cardStyle()
    }
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/NotesView.swift
//  Phase:   3 (app shell), rebuilt in 8a (notes you can write and find)
//  Ports:   app/classes/page.tsx (the first pane: Quick note, the search,
//           your classes with their note counts and Now tag, quick notes)
//
//  Summary: The Notes tab. Your classes, each with its timetable, how many
//           notes it holds and a Now tag while it's on; under them your quick
//           notes, the ones with no class; and a search across every note.
//           A class opens its notes; Quick note starts one with no class.
//

import SwiftUI

/// Pushes one class's notes. A small Hashable value, like 4b's AssignmentLink.
// NEW in Phase 8a
struct CourseNotesLink: Hashable {
    let id: UUID
}

/// Pushes one note.
// NEW in Phase 8a
struct NoteLink: Hashable {
    let id: UUID
}

private enum NotesLayout: Hashable {
    case widgets
    case list
}

struct NotesView: View {
    @Binding var tabBarCompact: Bool
    @Environment(Store.self) private var store

    /// What's typed in the search field. `.searchable` below draws the field
    /// and keeps this up to date.
    @State private var search = ""

    /// The note Quick note just started. Setting it opens that note
    /// (`navigationDestination(item:)` below); going back sets it to nil.
    @State private var startedNote: UUID?

    /// Whether the new-class form is open, for "Add your first class".
    @State private var addingCourse = false
    /// Widget cards are the default; the list remains available on demand.
    @State private var layout: NotesLayout = .widgets

    var body: some View {
        // Redrawn each minute, so the Now tag moves with the timetable.
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // Adding or deleting can fail to reach the planner file.
                    if store.lastSaveFailed {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                    }
                    // A search replaces the list until it's cleared.
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        classList(context.date)
                    } else {
                        results
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .onScrollPhaseChange { _, phase in
                tabBarCompact = phase.isScrolling
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Notes")
        // A search field under the title. Pull the list down a little to
        // reveal it; `prompt` is the grey text inside it.
        .searchable(text: $search, prompt: "Search every note")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Quick note") {
                    startedNote = store.addNote(courseID: nil, date: dayOf(.now))
                }
                .font(.system(size: 15, weight: .semibold))
            }
        }
        // Where each kind of row goes. Registered here, at the bottom of the
        // tab's stack, they also work for rows on the screens pushed above.
        .navigationDestination(for: CourseNotesLink.self) { link in
            CourseNotesView(courseID: link.id)
        }
        .navigationDestination(for: NoteLink.self) { link in
            NoteView(noteID: link.id)
        }
        // A push from code: while `startedNote` holds an id, that note is open.
        .navigationDestination(item: $startedNote) { id in
            NoteView(noteID: id)
        }
        .sheet(isPresented: $addingCourse) {
            NavigationStack {
                CourseFormView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { addingCourse = false }
                        }
                    }
            }
        }
        // A note deleted from its own screen comes back to here, Undo waiting.
        .undoBar()
    }

    // MARK: - The list

    /// The classes, then the quick notes. Before the first class (and with no
    /// quick notes either), one button to add a class instead.
    @ViewBuilder
    private func classList(_ now: Date) -> some View {
        let courses = store.activeCourses
        let quick = store.notes(for: nil)
        let live = liveCourseID(courses, now: now)

        Text(courses.isEmpty ? "Add a class to start taking notes." : "Pick one to open its notes.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

        Picker("Notes layout", selection: $layout) {
            Label("Widgets", systemImage: "square.grid.2x2")
                .tag(NotesLayout.widgets)
            Label("List", systemImage: "list.bullet")
                .tag(NotesLayout.list)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Notes layout")
        .padding(.bottom, 6)

        if courses.isEmpty && quick.isEmpty {
            Button {
                addingCourse = true
            } label: {
                Text("Add your first class")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.brandGradient(store.profile.accent),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }

        if layout == .widgets {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(courses) { course in
                    NavigationLink(value: CourseNotesLink(id: course.id)) {
                        courseWidget(course, live: course.id == live)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(quick) { note in
                    NavigationLink(value: NoteLink(id: note.id)) {
                        quickNoteWidget(note)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            ForEach(courses) { course in
                NavigationLink(value: CourseNotesLink(id: course.id)) {
                    courseRow(course, live: course.id == live)
                }
                .buttonStyle(.plain)
            }
            ForEach(quick) { note in
                NavigationLink(value: NoteLink(id: note.id)) {
                    noteRow(noteTitle(title: note.title, body: note.body),
                            "Quick note · \(dayLabel(note.date))")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func courseWidget(_ course: Course, live: Bool) -> some View {
        let count = store.noteCount(for: course.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                SubjectBook(color: course.color, short: course.short, compact: true)
                Spacer(minLength: 0)
                if live {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.good, in: Capsule())
                }
            }
            Text(course.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(meetingSummary(course))
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack {
                Text("\(count) note\(count == 1 ? "" : "s")")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.hint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .cardStyle()
        .contentShape(Rectangle())
    }

    private func quickNoteWidget(_ note: Note) -> some View {
        let preview = notePreview(note.body)
        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.brand(store.profile.accent))
            Text(noteTitle(title: note.title, body: note.body))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(preview.isEmpty ? "Quick note" : preview)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Text("Quick note · \(dayLabel(note.date))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.hint)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .cardStyle()
        .contentShape(Rectangle())
    }

    /// One class: its book, its name (Now while it's on), its timetable and
    /// how many notes it holds. `ClassRow` in app/classes/page.tsx.
    private func courseRow(_ course: Course, live: Bool) -> some View {
        let count = store.noteCount(for: course.id)
        return HStack(spacing: 12) {
            SubjectBook(color: course.color, short: course.short, compact: true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(course.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if live {
                        Text("NOW")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.good, in: Capsule())
                    }
                }
                Text(meetingSummary(course) + (count > 0 ? " · \(count) note\(count == 1 ? "" : "s")" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.hint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// A note's row: what it's called, and one quieter line under it.
    private func noteRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Search

    /// Every note the search finds, or a line saying none did.
    @ViewBuilder
    private var results: some View {
        let found = store.searchNotes(search)
        if found.isEmpty {
            Text("No notes match “\(search)”.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
        ForEach(found) { note in
            NavigationLink(value: NoteLink(id: note.id)) {
                // The preview, or the day when there's nothing after the title.
                let preview = notePreview(note.body)
                noteRow(noteTitle(title: note.title, body: note.body),
                        preview.isEmpty ? dayLabel(note.date) : preview)
            }
            .buttonStyle(.plain)
        }
    }
}

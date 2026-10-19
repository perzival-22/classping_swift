//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentDetailView.swift
//  Phase:   4b (the Tasks screen), changed in 7b (the planning cards) and
//           8d (linked notes, and Open the class)
//  Ports:   app/tasks/[id]/page.tsx (header, Complete, notes, details,
//           exam prep, reminders, Plan the work, checklist, linked notes,
//           Open the class, delete)
//
//  Summary: One assignment in full: its class, title and deadline, a big
//           Complete / Mark as open button, the brief, the details, and its
//           checklist. Since 7b, while it's open, also its exam prep (for a
//           dated exam), its reminder controls and the day you plan to work
//           on it. Since 8d, the notes linked to it (open, unlink, link one
//           more or start a new one) and a row that opens its class's notes.
//           Edit opens the form in a sheet; Delete moves it to Recently
//           Deleted and returns to the list, where Undo is offered. The
//           study timer and grade prompt join later.
//

import SwiftUI

struct AssignmentDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Which assignment to show. Only the id is kept; the assignment itself
    /// is looked up in the store on every redraw, so this screen is never stale.
    let assignmentID: UUID

    /// The assignment open in the edit sheet, or nil when no sheet is showing.
    /// `.sheet(item:)` shows the sheet whenever this is non-nil, hands the
    /// value to the sheet's content, and sets it back to nil when the sheet closes.
    @State private var editing: Assignment? = nil

    /// What's typed in the "Add a smaller step" field.
    @State private var newStep = ""

    /// NEW in Phase 8d: the note New note just started, while it's open
    /// (the Notes tab's `startedNote`, 8a).
    @State private var startedNote: UUID?

    var body: some View {
        // Gone (just deleted, or never existed): a short note instead of a crash.
        if let a = store.assignment(assignmentID) {
            content(a)
        } else {
            ContentUnavailableView("Assignment not found.", systemImage: "doc.questionmark")
        }
    }

    /// The screen for an assignment that exists.
    private func content(_ a: Assignment) -> some View {
        let accent = store.profile.accent
        let course = store.course(a.courseID)
        let due = dueLabel(a.deadline, .now)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Task and checklist changes save here, so failures must be
                // visible before the student returns to the list.
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                }

                // MARK: What it is
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(course.map { Theme.subject($0.color) } ?? Theme.lineStrong)
                            .frame(width: 9, height: 9)
                        Text(course?.name ?? "Inbox")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        if course?.archived == true {
                            Text("Archived")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .foregroundStyle(Theme.faint)
                                .background(Theme.surface2, in: Capsule())
                        }
                    }
                    Text(a.title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .strikethrough(a.done)
                    // "Due tomorrow · Tuesday, Sep 8 · 2:30 PM", red when urgent.
                    Text(a.due == nil ? due.text : "\(due.text) · \(longDeadline(a.deadline))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(due.urgent ? Theme.dangerInk : Theme.muted)
                }
                .padding(.horizontal, 4)

                // MARK: What to do about it
                // Brand gradient while open; a quiet grey "Mark as open" once done.
                Button {
                    store.toggleAssignment(a.id)
                } label: {
                    Label(a.done ? "Mark as open" : "Complete", systemImage: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(a.done ? Theme.muted : Color.white)
                        .background {
                            if a.done {
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface2)
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.brandGradient(accent))
                            }
                        }
                }
                .buttonStyle(.plain)

                // MARK: The brief
                if let notes = a.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    card {
                        sectionLabel("Notes")
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // MARK: Details
                card {
                    detailRow("Type", a.kind.label)
                    Divider()
                    detailRow("Due", a.due == nil ? "No deadline yet" : longDeadline(a.deadline))
                    // NEW in Phase 7b: minutes recorded against it (the study
                    // timer, Phase 10, is what records them).
                    Divider()
                    let focused = store.focusedMinutes(a.id)
                    detailRow("Focused", focused > 0 ? "\(focused) min recorded" : "No sessions yet")
                    if let rule = a.repeatRule {
                        Divider()
                        detailRow("Repeats", "\(rule == .weekly ? "Weekly" : "Monthly")"
                                  + (a.repeatUntil.map { " through \($0)" } ?? ""))
                    }
                    Divider()
                    // Keep the summary in step with the card when a snooze expires.
                    TimelineView(.everyMinute) { context in
                        detailRow("Reminder", reminderSummary(a, now: context.date))
                    }
                }

                // MARK: Planning
                // NEW in Phase 7b: the three planning cards, in the web's
                // order, only while the work is still open.
                if !a.done {
                    // An undated exam has no week before it to plan (D-32).
                    if a.kind == .exam && a.due != nil {
                        ExamPrepCard(assignment: a)
                    }
                    TaskReminderCard(assignment: a)
                    PlanWorkCard(assignment: a, plannedDay: store.taskPlan(for: a.id)?.date)
                }

                // MARK: Checklist
                card {
                    HStack {
                        sectionLabel("Checklist")
                        Spacer()
                        Text("\(a.subtasks.filter { $0.done }.count)/\(a.subtasks.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(a.subtasks) { step in
                        Button {
                            store.toggleSubtask(step.id, in: a.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.done ? Theme.brand(accent) : Theme.lineStrong)
                                Text(step.title)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Theme.ink)
                                    .strikethrough(step.done)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    // Type a step and press return (or +) to add it.
                    HStack(spacing: 8) {
                        TextField("Add a smaller step", text: $newStep)
                            .font(.system(size: 13.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onSubmit { addStep(to: a.id) }
                        Button {
                            addStep(to: a.id)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.brand(accent))
                                .frame(width: 40, height: 40)
                                .background(Theme.brand(accent).opacity(0.16),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add checklist item")
                    }
                }

                // MARK: Linked notes
                // NEW in Phase 8d: the notes about this work, then a way to
                // link one more or start one. Always shown, done or not, as
                // on the web.
                linkedNotesCard(a)

                // NEW in Phase 8d: the class's notes, one tap away. Only for
                // work that has a class; the Inbox has no notes page.
                if let course {
                    NavigationLink(value: CourseNotesLink(id: course.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "book")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.muted)
                            Text("Open \(course.name)")
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.hint)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }

                // MARK: Delete
                // One tap, as on the web detail page: it's a soft delete, Undo
                // shows on the list, and nothing is erased.
                Button {
                    store.deleteAssignment(a.id)
                    dismiss()   // back to the list, where the Undo bar is waiting
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(Theme.dangerInk)
                        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                Text("Deleted assignments are kept for 30 days and can be restored.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = a }
            }
        }
        // The edit form in its own sheet, with its own navigation bar for the
        // title, Save and Cancel. Saving closes the sheet (the form's dismiss).
        .sheet(item: $editing) { original in
            NavigationStack {
                AssignmentFormView(editing: original)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editing = nil }
                        }
                    }
            }
        }
        // NEW in Phase 8d: where the note links lead. This screen is pushed
        // on the Tasks tab and on Today, whose stacks don't know about notes,
        // so it registers the two note screens itself. A destination works
        // for the whole stack while the screen that registered it is in it,
        // so a class's notes opened from here can open their notes too.
        .navigationDestination(for: NoteLink.self) { link in
            NoteView(noteID: link.id)
        }
        .navigationDestination(for: CourseNotesLink.self) { link in
            CourseNotesView(courseID: link.id)
        }
        // And New note: open the note it just started.
        .navigationDestination(item: $startedNote) { id in
            NoteView(noteID: id)
        }
        // NEW in Phase 8d: a linked note deleted from its own screen comes
        // back to here, so Undo waits here, as on the Notes tab.
        .undoBar()
    }

    // MARK: - Pieces

    /// A rounded card holding a section, with the app's card surface.
    private func card<Content: View>(@ViewBuilder _ inside: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { inside() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }

    /// A small capital-letter section label, like the web's "NOTES".
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// One "label ... value" line in the details card. `DetailRow` on the web.
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 13.5))
    }

    /// What the Reminder row says. It names a snooze first: someone asking
    /// "why did this go quiet?" is looking right here. `reminderSummary`.
    // CHANGED in Phase 7b: snoozes and early warnings
    private func reminderSummary(_ a: Assignment, now: Date) -> String {
        if !a.reminder { return "Off" }
        if isSnoozed(a.snoozedUntil, now) { return "Snoozed" }
        if a.due == nil { return "On once it has a deadline" }
        let leads = effectiveLeads(a)
        // `leads.first` is the longest warning, since they're sorted longest first.
        if let first = leads.first { return "Nudging, from \(leadLabel(first)) before" }
        return "Nudging until it's done"
    }

    /// Adds the typed step to the checklist and clears the field.
    private func addStep(to id: UUID) {
        store.addSubtask(newStep, to: id)
        newStep = ""
    }

    /// NEW in Phase 8d: the Linked notes card. Each linked note opens on
    /// tap, with Unlink beside it (which only takes the link away, the note
    /// stays). Under them, a menu of the notes that could be linked, and New
    /// note, which starts one for this work's class, linked from the start.
    /// The "Linked notes" section of app/tasks/[id]/page.tsx.
    private func linkedNotesCard(_ a: Assignment) -> some View {
        let accent = store.profile.accent
        let linked = store.linkedNotes(for: a.id)
        let linkable = store.linkableNotes(for: a)

        return card {
            sectionLabel("Linked notes")

            // One row per linked note: the note, then Unlink. Side by side,
            // not one inside the other, so Unlink can't also open the note.
            ForEach(linked) { note in
                let title = noteTitle(title: note.title, body: note.body)
                HStack(spacing: 0) {
                    NavigationLink(value: NoteLink(id: note.id)) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button("Unlink") {
                        store.linkNote(note.id, to: nil)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    // "Unlink Week 3", the web's label, so VoiceOver says which.
                    .accessibilityLabel("Unlink \(title)")
                }
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 8) {
                // A `Menu` (8c) whose buttons come from the data: one per
                // note that could be linked. Picking one links it, and it
                // moves up into the list above. Greyed out when none could.
                Menu {
                    ForEach(linkable) { note in
                        Button(noteTitle(title: note.title, body: note.body)) {
                            store.linkNote(note.id, to: a.id)
                        }
                    }
                } label: {
                    HStack {
                        Text("Link an existing note")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(linkable.isEmpty)
                .opacity(linkable.isEmpty ? 0.5 : 1)

                // Today's date, this work's class (none for the Inbox, which
                // makes a quick note) and the link, then straight into it.
                Button {
                    startedNote = store.addNote(courseID: a.courseID, date: dayOf(.now),
                                                assignmentID: a.id)
                } label: {
                    Text("New note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(Theme.brandSoft(accent),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

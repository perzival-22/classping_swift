//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift
//  Phase:   5b (classes: add and edit)
//  Ports:   components/ClassForm.tsx, app/class/new/page.tsx and
//           app/class/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new class, and for editing one. Only a name is
//           required. A class meets at one or more times (MeetingFields), or
//           "Schedule not known yet" saves it with no times. New classes can
//           be saved one after another with "Save & add another".
//

import SwiftUI

struct CourseFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The class being edited, or nil for a new one.
    let editing: Course?

    /// What to do after Save. The Add menu passes "close the whole sheet";
    /// when nil, the form closes itself with `dismiss()`.
    let onFinish: (() -> Void)?

    // MARK: Form state
    // The form's own scratch copy of every field (the 4a pattern): nothing
    // reaches the store until Save.
    @State private var name: String
    @State private var unscheduled: Bool        // "Schedule not known yet"
    @State private var meetings: [ClassMeeting] // main meeting first
    @State private var color: SubjectColor
    @State private var instructor: String
    @State private var credits: String          // text, so it can be left empty
    @State private var notes: String
    @State private var alarm: Bool              // the pre-class reminder
    @State private var remindBefore: Int        // minutes before class
    @State private var problem: String? = nil   // what stopped the last Save
    @State private var added: String? = nil     // "Biology added. Ready for the next class."
    /// Keep a new class's identity across a failed save, so Retry updates the
    /// in-memory copy instead of adding a duplicate.
    @State private var draftID = UUID()

    /// Starting values, from the class being edited or the web's defaults for
    /// a new one (indigo, a 15-minute reminder, one empty meeting).
    init(editing: Course? = nil, onFinish: (() -> Void)? = nil) {
        self.editing = editing
        self.onFinish = onFinish
        _name = State(initialValue: editing?.name ?? "")
        // `.map` on an optional runs only when there is a value.
        _unscheduled = State(initialValue: editing.map { isUnscheduled($0) } ?? false)
        _meetings = State(initialValue: editing.map { classMeetings($0) } ?? [newMeeting(primaryMeetingID)])
        _color = State(initialValue: editing?.color ?? .indigo)
        _instructor = State(initialValue: editing?.instructor ?? "")
        _credits = State(initialValue: editing?.credits.map(creditText) ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _alarm = State(initialValue: editing?.alarm ?? true)
        _remindBefore = State(initialValue: editing?.remindBefore ?? 15)
    }

    var body: some View {
        let accent = store.profile.accent

        Form {
            // After "Save & add another": a quiet confirmation at the top.
            if let added {
                Section {
                    Text(added)
                        .foregroundStyle(Theme.brand(accent))
                }
            }

            // MARK: Name
            Section {
                TextField("e.g. Biology", text: $name)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Class name (required)")
            }

            // MARK: When it meets
            Section {
                Toggle(isOn: $unscheduled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schedule not known yet")
                        Text("Add the subject now and set its meeting times later.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                if unscheduled {
                    Text("No meeting times yet. Add them with Edit once you have your timetable; this subject is ready for tasks, notes and grades in the meantime.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            // `$meetings` hands MeetingFields a binding to the whole list.
            if !unscheduled {
                MeetingFields(meetings: $meetings, accent: accent)
            }

            // MARK: More details
            Section("More details (optional)") {
                TextField("Teacher", text: $instructor)
                TextField("Credit hours", text: $credits)
                    .keyboardType(.decimalPad)
                TextField("Notes: office hours, what to bring…", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Subject color") {
                colorRow
            }

            // MARK: Reminder
            Section {
                Toggle("Pre-class reminder", isOn: $alarm)
                Picker("Remind me before class", selection: $remindBefore) {
                    ForEach(remindChoices, id: \.self) { mins in
                        Text("\(mins) minutes").tag(mins)
                    }
                }
            } footer: {
                // Honest about today: Phase 7 is when reminders actually ring.
                Text(alarm
                     ? "Preference saved: \(remindBefore) minutes before each meeting. Reminder notifications are coming soon."
                     : "Pre-class reminders are off.")
            }

            // What's wrong, in the web's words.
            if let problem {
                Section {
                    Text(problem)
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            // A timetable is usually typed in one class after another.
            if editing == nil {
                Section {
                    Button("Save & add another") { save(another: true) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(editing == nil ? "New Class" : "Edit Class")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(another: false) }
            }
        }
        // The web's length caps: 200 for the name, 1000 for the notes.
        .onChange(of: name) {
            if name.count > 200 { name = String(name.prefix(200)) }
        }
        .onChange(of: notes) {
            if notes.count > 1000 { notes = String(notes.prefix(1000)) }
        }
    }

    // MARK: - Pieces

    /// The nine colors as round swatches; the picked one gets a ring.
    /// `ColorPicker.tsx` on the web.
    private var colorRow: some View {
        HStack(spacing: 0) {
            ForEach(SubjectColor.allCases, id: \.self) { c in
                Button {
                    color = c
                } label: {
                    Circle()
                        .fill(Theme.subject(c))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Theme.ink, lineWidth: 2)
                                .padding(-4)
                                .opacity(color == c ? 0.8 : 0)
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(c.rawValue.capitalized)
                .accessibilityAddTraits(color == c ? .isSelected : [])
            }
        }
    }

    /// The reminder choices: 10, 15, 30 and 60 minutes, plus whatever the class
    /// already uses, in order. A `Set` drops the duplicate when it's one of those.
    private var remindChoices: [Int] {
        Set([10, 15, 30, 60, remindBefore]).sorted()
    }

    // MARK: - Saving

    /// What stops Save, in the web form's order, or nil when it can go ahead.
    private func validationProblem(_ cleanName: String, _ creditInput: String) -> String? {
        if cleanName.isEmpty { return "Enter a class name." }
        // Meeting times only matter when the class has a schedule.
        if !unscheduled, let meetingProblem = meetingError(meetings) {
            return meetingProblem
        }
        if !creditInput.isEmpty {
            // `Double("abc")` is nil; a real number must also be above zero.
            guard let value = Double(creditInput), value.isFinite, value > 0 else {
                return "Credit hours must be greater than zero, or left empty."
            }
        }
        return nil
    }

    /// Checks the fields, builds the class and hands it to the store.
    /// `save` in components/ClassForm.tsx.
    private func save(another: Bool) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let creditInput = credits.trimmingCharacters(in: .whitespaces)
        problem = validationProblem(cleanName, creditInput)
        guard problem == nil else { return }

        // Tidy every meeting: a blank room or label is stored as nothing.
        let tidy = meetings.map { m in
            var t = m
            t.room = cleaned(m.room)
            t.label = cleaned(m.label)
            return t
        }
        // The main meeting lives on the class itself; the rest are extras.
        let main = tidy.first ?? newMeeting(primaryMeetingID)

        // Start from the class being edited, so fields this form doesn't show
        // (extra reminders, term, goal, feed ids...) survive the edit.
        var c = editing ?? Course(name: "", short: "", color: .indigo,
                                  days: [], startMin: 600, endMin: 660)
        if editing == nil { c.id = draftID }
        c.name = cleanName
        c.short = shortCode(cleanName)
        c.color = color
        // "Schedule not known yet" stores no days at all: every schedule
        // screen skips the class, but it's there for tasks, notes and grades.
        c.days = unscheduled ? [] : main.days
        c.startMin = main.start
        c.endMin = main.end
        c.room = unscheduled ? nil : main.room
        c.additionalMeetings = unscheduled ? [] : Array(tidy.dropFirst())
        c.instructor = cleaned(instructor)
        c.credits = Double(creditInput)
        c.notes = cleaned(notes)
        c.remindBefore = remindBefore
        c.alarm = alarm

        // New or edited: the store saves to the phone either way.
        if editing == nil && store.course(c.id) == nil {
            store.addCourse(c)
        } else {
            store.updateCourse(c)
        }

        // Keep the draft and its identity available until the local write works.
        guard !store.lastSaveFailed else {
            added = nil
            problem = "Couldn't save on this device. Keep this form open and try Save again."
            return
        }

        if another {
            // Clear the subject's own fields; the reminder choice carries over
            // to the next class, which is the point of typing a timetable in a row.
            name = ""
            draftID = UUID()
            unscheduled = false
            meetings = [newMeeting(primaryMeetingID)]
            color = .indigo
            instructor = ""
            credits = ""
            notes = ""
            added = "\(cleanName) added. Ready for the next class."
        } else if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

// MARK: - Helpers

/// The short code on grid blocks: the name's first word, at most 5 letters
/// ("Calculus III" -> "Calcu"). The web works it out on every save the same way.
private func shortCode(_ name: String) -> String {
    let firstWord = name.split(whereSeparator: { $0.isWhitespace }).first ?? ""
    return String(firstWord.prefix(5))
}

/// Trimmed text, or nil when nothing is left.
private func cleaned(_ text: String?) -> String? {
    let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
}

/// 3.0 -> "3", 1.5 -> "1.5", for showing stored credits in the text field.
private func creditText(_ value: Double) -> String {
    // Double's text round-trips without locale-dependent separators or Int overflow.
    let text = String(value)
    return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
}

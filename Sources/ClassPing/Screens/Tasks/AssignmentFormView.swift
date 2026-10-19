//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift
//  Phase:   4a (task logic and the add form), changed in 7c (start on a class)
//  Ports:   app/tasks/new/page.tsx and app/tasks/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new assignment, exam or reminder, and for editing
//           one. Only a title is required: no class means Inbox, no date means
//           "No deadline", and no time means all-day. Since 7c a new one can
//           start with its class already picked, as the post-class prompt does.
//

import SwiftUI

struct AssignmentFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The assignment being edited, or nil for a new one.
    let editing: Assignment?

    /// What to do after Save. The Add menu passes "close the whole sheet";
    /// when nil, the form just closes itself with `dismiss()`.
    let onFinish: (() -> Void)?

    // MARK: Form state
    // `@State` is the form's own scratch copy of every field. Nothing reaches
    // the store until Save, so Cancel or Back throws the edits away.
    @State private var title: String
    @State private var courseID: UUID?
    @State private var kind: Assignment.Kind
    @State private var hasDate: Bool          // off = No deadline (Inbox)
    @State private var dueDay: Date           // only the day part is used
    @State private var hasTime: Bool          // off = all-day
    @State private var dueClock: Date         // only the hour and minute are used
    @State private var reminder: Bool
    @State private var notes: String
    @State private var repeatRule: Assignment.RepeatRule?
    @State private var hasRepeatEnd: Bool
    @State private var repeatEnd: Date

    /// Sets the starting value of every field. A view's `@State` normally starts
    /// from a fixed value; to start it from the assignment being edited, the
    /// init writes to the underscore version (`_title`), which is the State box
    /// itself, wrapping the value in `State(initialValue:)`.
    /// New work starts like the web form: due in 3 days, all-day, reminder on.
    /// CHANGED in Phase 7c: `courseID` is a preset, the class new work starts
    /// on (the web's `/tasks/new?class=…`). It has a default, nil (Inbox), so
    /// every existing call still compiles unchanged. An edit ignores it.
    init(kind: Assignment.Kind = .assignment, courseID: UUID? = nil,
         editing: Assignment? = nil, onFinish: (() -> Void)? = nil) {
        self.editing = editing
        self.onFinish = onFinish

        // Where the dates start: the stored day if there is one, else 3 days out.
        let inThreeDays = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let storedDay = editing.flatMap { parseDay($0.due) }
        let storedClock = editing.flatMap { parseClock($0.dueTime) }
        let storedEnd = editing.flatMap { parseDay($0.repeatUntil) }

        _title = State(initialValue: editing?.title ?? "")
        // CHANGED in Phase 7c: an edit keeps its own class; new work takes the preset.
        _courseID = State(initialValue: editing == nil ? courseID : editing?.courseID)
        _kind = State(initialValue: editing?.kind ?? kind)
        _hasDate = State(initialValue: editing == nil ? true : storedDay != nil)
        _dueDay = State(initialValue: storedDay ?? inThreeDays)
        _hasTime = State(initialValue: storedClock != nil)
        _dueClock = State(initialValue: storedClock ?? parseClock("17:00") ?? .now)
        _reminder = State(initialValue: editing?.reminder ?? true)
        _notes = State(initialValue: editing?.notes ?? "")
        _repeatRule = State(initialValue: editing?.repeatRule)
        _hasRepeatEnd = State(initialValue: storedEnd != nil)
        _repeatEnd = State(initialValue: storedEnd ?? storedDay ?? inThreeDays)
    }

    var body: some View {
        Form {
            // MARK: Class
            // `selection: $courseID` binds the picker to the form's state: the
            // `$` hands the picker a two-way connection, so picking a row
            // writes straight into `courseID`. Each row's `.tag` is the value
            // it stands for; nil is Inbox, a real choice, not "nothing chosen".
            Section("Class") {
                Picker("Class", selection: $courseID) {
                    Text("Inbox, no class").tag(UUID?.none)
                    ForEach(store.courses.filter { $0.deletedAt == nil }) { course in
                        Text(course.name).tag(UUID?.some(course.id))
                    }
                }
            }

            // MARK: Type
            Section("Type") {
                Picker("Type", selection: $kind) {
                    ForEach(kindChoices, id: \.self) { k in
                        Text(kindTitle(k)).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: Name
            Section(nameHeading) {
                TextField(namePlaceholder, text: $title)
                    .textInputAutocapitalization(.sentences)
            }

            // MARK: Due
            Section {
                // The web's shortcut chips. A horizontal scroller, because seven
                // chips don't fit across a phone.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.label) { preset in
                            presetChip(preset)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // A switch for "has a day at all"; off is the Inbox.
                Toggle("Has a due date", isOn: $hasDate)
                if hasDate {
                    // New work can't be due in the past (the web's `min` is today).
                    // An edit keeps any day, so an overdue task isn't moved by accident.
                    DatePicker("Date", selection: $dueDay, in: earliestDay...,
                               displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $dueClock, displayedComponents: .hourAndMinute)
                    }
                }
            } header: {
                Text("Due")
            } footer: {
                // The plain-words summary under the web form: "Due Monday, Sep 7".
                Text("Due \(longDeadline(draftDeadline))")
            }

            // MARK: Repeat
            // Only for dated graded work, like the web: a reminder doesn't repeat.
            if hasDate && kind != .reminder {
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatRule) {
                        Text("None").tag(Assignment.RepeatRule?.none)
                        Text("Weekly").tag(Assignment.RepeatRule?.some(.weekly))
                        Text("Monthly").tag(Assignment.RepeatRule?.some(.monthly))
                    }
                    .pickerStyle(.segmented)
                    if repeatRule != nil {
                        Toggle("Repeat until a date", isOn: $hasRepeatEnd)
                        if hasRepeatEnd {
                            DatePicker("Until", selection: $repeatEnd, in: dueDay...,
                                       displayedComponents: .date)
                        }
                    }
                }
            }

            // MARK: Reminder
            Section {
                Toggle(isOn: $reminder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder")
                        Text("Nudge me until it's done")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }

            // MARK: Notes
            Section("Notes (optional)") {
                // `axis: .vertical` lets the field grow onto new lines as you type.
                TextField("What the brief asks for, pages to read, what to bring…",
                          text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        // Let the warm canvas show through instead of the system grey.
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(editing == nil ? "New Assignment" : "Edit Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        // The web caps notes at 2000 characters; trim anything pasted past that.
        .onChange(of: notes) {
            if notes.count > 2000 { notes = String(notes.prefix(2000)) }
        }
    }

    // MARK: - Pieces

    /// A due-date shortcut: a label and how many days from today (nil = No deadline).
    private struct Preset {
        let label: String
        let days: Int?
    }

    /// The web form's `DUE_PRESETS`, in the same order.
    private var presets: [Preset] {
        [Preset(label: "No deadline", days: nil), Preset(label: "Today", days: 0),
         Preset(label: "Tomorrow", days: 1), Preset(label: "2 days", days: 2),
         Preset(label: "3 days", days: 3), Preset(label: "1 week", days: 7),
         Preset(label: "2 weeks", days: 14)]
    }

    /// One shortcut chip. Filled with the brand color when it matches the
    /// current choice, the way the web lights up the active preset.
    private func presetChip(_ preset: Preset) -> some View {
        // The day this chip stands for, or nil for "No deadline".
        let target = preset.days.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }
        let on = target.map { hasDate && dayOf($0) == dayOf(dueDay) } ?? !hasDate
        let accent = store.profile.accent

        return Button {
            // Tapping sets (or clears) the date in one go.
            if let target {
                hasDate = true
                dueDay = target
            } else {
                hasDate = false
            }
        } label: {
            Text(preset.label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(on ? Color.white : Theme.muted)
                .background(on ? Theme.brand(accent) : Theme.canvas,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)   // stops the Form row treating the whole row as one button
    }

    // MARK: - Derived values

    /// The kinds the Type picker offers. Quizzes are made from a class card on
    /// the web, so a new task offers three; editing a quiz keeps Quiz on offer
    /// so saving never quietly turns it into an assignment.
    private var kindChoices: [Assignment.Kind] {
        let base: [Assignment.Kind] = [.assignment, .exam, .reminder]
        return editing?.kind == .quiz ? base + [.quiz] : base
    }

    /// The name each kind shows in the picker.
    private func kindTitle(_ k: Assignment.Kind) -> String {
        switch k {
        case .assignment: "Assignment"
        case .quiz:       "Quiz"
        case .exam:       "Exam"
        case .reminder:   "Reminder"
        }
    }

    /// The heading over the title field changes with the kind, as on the web.
    private var nameHeading: String {
        switch kind {
        case .exam:     "Exam"
        case .reminder: "Reminder"
        default:        "Assignment"
        }
    }

    /// The example text in the empty title field.
    private var namePlaceholder: String {
        switch kind {
        case .exam:     "e.g. Midterm, Chapters 1–6"
        case .reminder: "e.g. Bring safety goggles"
        default:        "e.g. Reading response: Rawls, Ch. 3"
        }
    }

    /// The first day the date picker allows: today for new work, any day for an edit.
    private var earliestDay: Date {
        editing == nil ? Calendar.current.startOfDay(for: .now) : .distantPast
    }

    /// The deadline the form currently describes, in the stored shape.
    private var draftDeadline: Deadline {
        Deadline(date: hasDate ? dayOf(dueDay) : nil,
                 time: hasDate && hasTime ? timeOf(dueClock) : nil)
    }

    /// Only a title is required. `canSave` in the web form.
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Saving

    /// Builds the assignment from the fields and hands it to the store.
    /// `save` in app/tasks/new/page.tsx and the edit page.
    private func save() {
        guard canSave else { return }

        // Start from the edited assignment so fields this form doesn't show
        // (checklist, done, feed ids...) survive; a new one starts blank.
        var a = editing ?? Assignment(title: "")
        let deadline = draftDeadline
        a.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        a.courseID = courseID
        a.kind = kind
        a.due = deadline.date
        a.dueTime = deadline.time
        a.reminder = reminder

        // Empty notes are stored as nothing, not as "".
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        a.notes = cleanNotes.isEmpty ? nil : cleanNotes

        // A repeat needs a date and isn't for reminders. "Until" only counts
        // when it is on or after the due day (string order is date order here).
        let rule = (deadline.date != nil && kind != .reminder) ? repeatRule : nil
        a.repeatRule = rule
        let until = dayOf(repeatEnd)
        a.repeatUntil = (rule != nil && hasRepeatEnd && until >= (deadline.date ?? "")) ? until : nil

        // New or edited: the store saves to the phone either way.
        if editing == nil {
            store.addAssignment(a)
        } else {
            store.updateAssignment(a)
        }

        // Close: the caller's way if it gave one, otherwise just this screen.
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

// MARK: - Turning stored text into picker dates

/// "2026-09-07" -> local midnight that day, for a DatePicker. Nil when empty or broken.
/// Reuses Deadline.swift, which already knows how to read a stored day.
private func parseDay(_ day: String?) -> Date? {
    deadlineDayStart(Deadline(date: day, time: nil))
}

/// "14:30" -> today at 2:30 PM, for a time-only DatePicker. Only the hour and
/// minute are ever read back out (with `timeOf`), so the day doesn't matter.
private func parseClock(_ time: String?) -> Date? {
    guard isValidTime(time) else { return nil }
    return deadlineInstant(Deadline(date: dayOf(.now), time: time))
}

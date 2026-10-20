//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/QuickTaskSheet.swift
//  Phase:   8d (notes that connect), changed in 9b+ (accent field, D-55)
//  Ports:   QuickTaskCard in app/classes/page.tsx
//
//  Summary: The small form a note's bell and plus open. It files a reminder
//           (the bell) or an assignment, quiz or exam (the plus) for the
//           note's class without leaving the note: only the words, the day
//           and a time if it matters are left to fill in. A reminder needs
//           its words; a blank assignment is named after its class.
//           Since 9b+ the title wears your accent, and Done or a swipe down
//           puts the keyboard away.
//

import SwiftUI

struct QuickTaskSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Which card this is: the bell's or the plus's.
    let mode: QuickTaskMode

    /// The note's class, which the new task takes. Nil for a quick note,
    /// so the task goes to the Inbox.
    let courseID: UUID?

    // MARK: Form state
    // The sheet's own scratch copy of each field, as in the task form (4a):
    // nothing reaches the store until Add.
    @State private var title = ""
    @State private var type = QuickTaskType.assignment
    @State private var day: Date
    @State private var hasTime = false      // off = all-day, the web's empty time
    @State private var clock: Date

    /// Whether the title field has the keyboard. The web's `autoFocus`.
    @FocusState private var titleFocused: Bool

    /// Starts the date where the web card does: tomorrow for a reminder,
    /// three days out for an assignment. The time, once switched on, starts
    /// at 5:00 PM, as in the task form.
    init(mode: QuickTaskMode, courseID: UUID?) {
        self.mode = mode
        self.courseID = courseID
        let ahead = Calendar.current.date(byAdding: .day, value: quickTaskDaysAhead(mode), to: .now)
        _day = State(initialValue: ahead ?? .now)
        let five = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now)
        _clock = State(initialValue: five ?? .now)
    }

    var body: some View {
        let isReminder = mode == .reminder

        NavigationStack {
            Form {
                // MARK: What it is
                // The header names the class, the web card's pill.
                Section {
                    TextField(isReminder ? "Reminder, e.g. Bring goggles" : "Title (optional)",
                              text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Title")
                        // Return adds it, when it can be added.
                        .submitLabel(.done)
                        .onSubmit { add() }
                        .inputField(store.profile.accent)   // NEW in Phase 9b+
                    // Assignment, quiz or exam. Not for a reminder.
                    if !isReminder {
                        Picker("Type", selection: $type) {
                            ForEach(QuickTaskType.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text(store.course(courseID)?.name ?? "Quick note")
                }

                // MARK: When
                // A day always; a time only when it matters (the web's time
                // field starts empty, and empty means all-day).
                Section {
                    DatePicker("Due date", selection: $day, displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $clock, displayedComponents: .hourAndMinute)
                    }
                }
            }
            // The warm canvas instead of the system grey, as in the task form.
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            // NEW in Phase 9b+: swipe down, or tap Done above the keys.
            .keyboardDismissable { titleFocused = false }
            .navigationTitle(isReminder ? "Quick reminder" : "Quick assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(!quickTaskCanSave(mode, title: title))
                }
            }
            // Straight into the title, like the web card.
            .onAppear { titleFocused = true }
        }
        // About half the screen, room enough for the keyboard; drag for more.
        .presentationDetents([.medium, .large])
    }

    /// Files the task and closes. Nothing happens while it can't be saved
    /// (a reminder with no words), which also covers Return in the title.
    private func add() {
        let filed = store.addQuickTask(mode, title: title, type: type, courseID: courseID,
                                       due: dayOf(day), dueTime: hasTime ? timeOf(clock) : nil)
        if filed != nil { dismiss() }
    }
}

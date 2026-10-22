---
title: "Phase 9b+: Fields everywhere, and two 9c fixes"
date: 2026-10-20
---

# Phase 9b+: Fields everywhere, and two 9c fixes

*Typed as `b08680f`. Its Clear fix (D-58) didn't hold on the phone and is replaced by [the finals card fix](phase-09b-plus-fix-finals-card.md) (D-60).*

The short pass D-55 promised: the accent field look and the keyboard's Done
bar (D-54) on every other form, plus two fixes from your 9c phone check. It
builds on your typed 9c, commit `10718e9`. Your Sources are identical to the
9c reference; in throwaway copies `test-logic.sh` passed 371/371 (also on New
York time), `test-store.sh` 79/79, and the tree built with no warnings. On
2026-10-20 you confirmed on the phone: the countdown matches the calendar,
the report is good, and light and dark both look right.

**Start here:** seven files, all replacing ones you have. Most changes are a
line or two, marked `// NEW in Phase 9b+` or `// CHANGED in Phase 9b+`, and
listed before each file, so you can edit the marked spots instead of retyping
the whole file. No test files and no script changes this time.

**Verification (2026-10-20):** the reference iOS build passed with no
warnings. No logic or store file changed, so the 371 logic and 67 reference
store tests stand as they were. The seven guide blocks laid over your current
tree are identical to the reference, and that tree built with no warnings. No
9b+ phone check has happened yet.

## 1. Goal

Every field you type into looks like a field and lets the keyboard go, and
the two things you noticed in 9c are fixed.

**On your phone:** **+ → Assignment**: the title and notes sit in soft accent
wells, and with the keyboard up, **Done** sits above the keys (swiping down
works too). **+ → Class**: the name, each meeting's room and label, teacher,
credit hours and notes all do the same, and **Done** works from any of them.
A note's bell or plus opens the quick sheet with its title in a well. On
Grades, **Clear** on the finals card sets the picker back to today. A report
opened in Excel on Windows shows accented names correctly.

This part includes:

- D-55: `AssignmentFormView`, `CourseFormView`, `MeetingFields` and
  `QuickTaskSheet` get `inputField` and `keyboardDismissable` from 9b's
  `Theme+Fields.swift`. The notes editor and the quote editor keep their own
  look, as D-55 said.
- **Clear looked like it hadn't worked (D-58).** After Clear, the card asked
  for a date again but the picker still showed the date you'd just cleared.
  [Likely] that's what you saw: the store test proves a cleared date is saved
  and stays cleared after a reload, and if the app was only sent to the
  background (not swiped away), the card comes back exactly as you left it,
  old date in the picker. Now Clear resets the picker to today. If the big
  countdown number itself came back after a full close, tell me: that would
  be a different bug.
- **A byte-order mark on the CSV** (your yes to question 22), three bytes at
  the start of the file so Excel on Windows reads it as UTF-8. The web's
  download gets the same.
- **The class form from Add grade gets a navigation bar.** "Add your first
  class" on the grade sheet (shown only when you have no classes) opened the
  class form with no bar, so no Save, no Cancel and no Done. Every other
  place wraps it in a `NavigationStack`; now this one does too.

## 2. New Swift concepts

None. Two things you already know, stretched a little:

**Handing focus to a child view.** The class form owns one `@FocusState`, but
the room and label fields live in `MeetingFields`, a separate view. `$focus`
passed down works like a `@Binding`: the child marks its fields with it, and
when the form's Done sets the focus to nil, the keyboard leaves those fields
too. With a separate `@FocusState` in the child, Done would set the form's
focus to nil (it already was) and the keyboard would stay up.

```swift
// In the form:
@FocusState private var focus: CourseField?
MeetingFields(meetings: $meetings, accent: accent, focus: $focus)

// In MeetingFields:
var focus: FocusState<CourseField?>.Binding
TextField("Room", text: room).focused(focus, equals: .room(meeting.id))
```

**An enum case that carries a value.** One form, many meetings, and each
meeting has its own room field. `case room(UUID)` gives every one of them its
own focus id, the way 5b's sheet enum carried the class it opened.

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `--bg-input` wells in `app/globals.css` (D-54) | `inputField` on the fields of `AssignmentFormView`, `CourseFormView`, `MeetingFields` and `QuickTaskSheet` |
| (the web has a keyboard you can close) | `keyboardDismissable` on the same four forms |
| `gradeReportBlob` in `lib/report.ts` (new on the web today, with your go-ahead) | The byte-order mark in `TermReportCard.swift` |
| `clear` in `components/FinalsCountdown.tsx` | `clear` in `FinalsCountdown.swift`, which now also resets the picker (D-58) |

Where the phone deliberately differs: the web's Clear keeps the old date in
its date field, the phone starts it on today (D-58).

## 4. Files, in the order to type them

Seven files, all replaced. Build once all seven are in: 4.1 declares
`CourseField`, and 4.2 can't compile without it (and 4.1 can't compile
without 4.2's new `focus` parameter).

### 4.1 `~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift` (replaces your 5b/7a file)

Changed spots:

- **Header** (changed).
- **`enum CourseField`** (new, above the struct): one focus id per field,
  meetings told apart by id.
- **`@FocusState private var focus`** (new, after `draftID`).
- **The name field** (`.focused`, `.inputField`, new).
- **`MeetingFields(...)`** (changed): passes `focus: $focus`.
- **More details** (changed): teacher, credit hours and notes each get
  `.focused` and `.inputField`.
- **`.keyboardDismissable { focus = nil }`** (new, after `.background`).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift
//  Phase:   5b (classes: add and edit), changed in 7a (the reminder footer)
//           and 9b+ (accent fields and keyboard, D-55)
//  Ports:   components/ClassForm.tsx, app/class/new/page.tsx and
//           app/class/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new class, and for editing one. Only a name is
//           required. A class meets at one or more times (MeetingFields), or
//           "Schedule not known yet" saves it with no times. New classes can
//           be saved one after another with "Save & add another". Since
//           9b+ every field wears your accent, and Done or a swipe down puts
//           the keyboard away (the credit hours pad has no return key).
//

import SwiftUI

// NEW in Phase 9b+
/// Every field in the class form that can hold the keyboard. The meetings'
/// label and room fields live in MeetingFields, one pair per meeting, so their
/// cases carry the meeting's id: `.room(id)` is one meeting's room field.
/// An enum case can carry a value like this (5b's sheet enum did the same).
enum CourseField: Hashable {
    case name, instructor, credits, notes
    case label(UUID), room(UUID)
}

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

    // NEW in Phase 9b+: which field has the keyboard, so Done can put it away.
    // MeetingFields gets `$focus` too, so Done also works in a room or label.
    @FocusState private var focus: CourseField?

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
                    .focused($focus, equals: .name)     // NEW in Phase 9b+
                    .inputField(accent)                 // NEW in Phase 9b+
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
                // CHANGED in Phase 9b+: MeetingFields shares the form's focus.
                MeetingFields(meetings: $meetings, accent: accent, focus: $focus)
            }

            // MARK: More details
            // CHANGED in Phase 9b+: each field has a focus id and the accent well.
            Section("More details (optional)") {
                TextField("Teacher", text: $instructor)
                    .focused($focus, equals: .instructor)
                    .inputField(accent)
                TextField("Credit hours", text: $credits)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .credits)
                    .inputField(accent)
                TextField("Notes: office hours, what to bring…", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($focus, equals: .notes)
                    .inputField(accent)
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
                // CHANGED in Phase 7a: the alarm really rings now. The web
                // form says the same, minus its "More details" pointer.
                Text(alarm
                     ? "Reminder: \(remindBefore) minutes before each meeting. It rings even in quiet hours."
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
        // NEW in Phase 9b+: swipe down, or tap Done above the keys.
        .keyboardDismissable { focus = nil }
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
```

### 4.2 `~/ClassPing/Sources/ClassPing/Components/MeetingFields.swift` (replaces your 5b file)

Changed spots:

- **Header** (changed).
- **`var focus: FocusState<CourseField?>.Binding`** (new, after `accent`).
- **The label and room fields** (changed): `.focused(focus, equals: …)` and
  `.inputField(accent)`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/MeetingFields.swift
//  Phase:   5b (classes: add and edit), changed in 9b+ (accent fields, D-55)
//  Ports:   components/MeetingFields.tsx (newMeeting, MeetingFields)
//
//  Summary: The "when does this class meet?" part of the class form, one
//           section per meeting: day buttons with shortcuts, start and end
//           times with duration shortcuts, and a room. Extra meetings get a
//           name ("Lab") and a Remove button. Edits go straight back into the
//           form's list through a binding. Since 9b+ the label and room
//           fields wear your accent and share the class form's focus.
//

import SwiftUI

/// A blank meeting: no days yet, 10 to 11 AM. `newMeeting` in
/// MeetingFields.tsx. Pass `primaryMeetingID` for a class's main meeting;
/// an extra meeting gets a fresh id.
func newMeeting(_ id: UUID = UUID()) -> ClassMeeting {
    ClassMeeting(id: id, days: [], start: 600, end: 660)
}

struct MeetingFields: View {
    /// The form's list of meetings, main meeting first. A `@Binding` because the
    /// class form owns the list: this view edits it in place.
    @Binding var meetings: [ClassMeeting]
    let accent: Profile.Accent

    // NEW in Phase 9b+
    /// The class form's focus, handed down as `$focus`. It works like a
    /// `@Binding`: this view marks its own fields with it, and when the form's
    /// Done sets the focus to nil, the keyboard leaves these fields too.
    var focus: FocusState<CourseField?>.Binding

    /// One day shortcut: what the button says and the days it picks.
    private struct DayPreset: Hashable {
        let label: String
        let days: [Int]
    }

    /// The web's day shortcuts, in its order.
    private let dayPresets = [
        DayPreset(label: "Mon/Wed/Fri", days: [0, 2, 4]),
        DayPreset(label: "Tue/Thu", days: [1, 3]),
        DayPreset(label: "Weekdays", days: [0, 1, 2, 3, 4]),
    ]

    var body: some View {
        // `ForEach($meetings)` loops over the list *as bindings*: inside, the
        // `$meeting` is a two-way connection to one element, so typing a room
        // or tapping a day writes straight into `meetings`. `meeting` (no $)
        // is that element's current value. ForEach tells the rows apart by
        // their `id`, so removing one can't mix up the others.
        ForEach($meetings) { $meeting in
            Section {
                // Extra meetings have a name field and a Remove button.
                if meetings.count > 1 {
                    if meeting.id == primaryMeetingID {
                        Text("Main meeting")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    } else {
                        HStack {
                            // CHANGED in Phase 9b+: a focus id and the accent well.
                            TextField("Meeting label (optional), e.g. Lab",
                                      text: optionalText($meeting.label, limit: 80))
                                .focused(focus, equals: .label(meeting.id))
                                .inputField(accent)
                            // `.borderless` keeps this button from turning the
                            // whole row into one big tap target.
                            Button("Remove", role: .destructive) {
                                let gone = meeting.id
                                meetings.removeAll { $0.id == gone }
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove meeting \(position(of: meeting) + 1)")
                        }
                    }
                }

                // Seven day buttons, Monday to Sunday.
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        dayButton(day, $meeting)
                    }
                }

                // The shortcuts: one tap sets the whole pattern.
                HStack(spacing: 14) {
                    ForEach(dayPresets, id: \.label) { preset in
                        Button(preset.label) { meeting.days = preset.days }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }

                // Times. A DatePicker shows a clock but works with full dates;
                // `clock(_:)` (below) converts to and from minutes.
                DatePicker("Starts", selection: clock($meeting.start),
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .accessibilityLabel("Meeting \(position(of: meeting) + 1) starts")
                DatePicker("Ends", selection: clock($meeting.end),
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .accessibilityLabel("Meeting \(position(of: meeting) + 1) ends")

                // Duration shortcuts set the end from the start. A length that
                // would run past midnight is greyed out, like the web.
                HStack(spacing: 14) {
                    Text("Duration")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    ForEach([50, 60, 90], id: \.self) { mins in
                        Button("\(mins) min") { meeting.end = meeting.start + mins }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .disabled(meeting.start + mins >= 1440)
                    }
                }

                // CHANGED in Phase 9b+: a focus id and the accent well.
                TextField("Room (optional), e.g. Science 204",
                          text: optionalText($meeting.room, limit: 200))
                    .focused(focus, equals: .room(meeting.id))
                    .inputField(accent)
            } header: {
                Text(meetings.count > 1 ? "Meeting \(position(of: meeting) + 1)" : "When does this class meet?")
            } footer: {
                // Said straight away, not only when you press Save.
                if meeting.end <= meeting.start {
                    Text("End time must be after the start time.")
                        .foregroundStyle(Theme.danger)
                }
            }
        }

        // Adding another meeting time, up to the web's limit of 20.
        Section {
            Button("+ Add another meeting time") {
                meetings.append(newMeeting())
            }
            .disabled(meetings.count >= maxMeetings)
        } footer: {
            Text("Add a lecture, lab or another time. They share this subject's notes and grades.")
        }
    }

    // MARK: - Pieces

    /// Where a meeting sits in the list, for its "Meeting 2" heading.
    private func position(of meeting: ClassMeeting) -> Int {
        meetings.firstIndex(where: { $0.id == meeting.id }) ?? 0
    }

    /// One day button: filled with the brand color when the meeting is on that
    /// day. Tapping adds or removes the day, keeping the list in order.
    private func dayButton(_ day: Int, _ meeting: Binding<ClassMeeting>) -> some View {
        let on = meeting.wrappedValue.days.contains(day)
        let brand = Theme.brand(accent)
        return Button {
            if on {
                meeting.wrappedValue.days.removeAll { $0 == day }
            } else {
                meeting.wrappedValue.days = (meeting.wrappedValue.days + [day]).sorted()
            }
        } label: {
            Text(dayLabels[day])
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(on ? Color.white : Theme.muted)
                .background(on ? brand : Theme.surface2,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        // `.plain` lets each of the seven buttons take its own taps.
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A bridge between "minutes from midnight" (what a meeting stores) and a
    /// Date (what a DatePicker needs). `Binding(get:set:)` (Phase 4b) builds a
    /// binding from two closures: `get` turns the minutes into today at that
    /// time; `set` turns the picked time back into minutes with `minuteOfDay`.
    private func clock(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                let m = minutes.wrappedValue
                // Today at that wall-clock time. Setting the hour and minute
                // (rather than adding minutes to midnight) stays right on the
                // two days a year the clocks change.
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60,
                                             second: 0, of: .now) ?? .now
            },
            set: { picked in
                minutes.wrappedValue = minuteOfDay(picked)
            }
        )
    }
}

/// A TextField needs a `String`, but a meeting's room and label are `String?`
/// (nothing = not set). This shows nothing as empty text and caps the length
/// the way the web's `maxLength` does. The form tidies blanks into nil on Save.
func optionalText(_ value: Binding<String?>, limit: Int) -> Binding<String> {
    Binding(
        get: { value.wrappedValue ?? "" },
        set: { value.wrappedValue = String($0.prefix(limit)) }
    )
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift` (replaces your 7c file)

Changed spots:

- **Header** (changed).
- **`enum Field` and `@FocusState private var focus`** (new, after
  `repeatEnd`).
- **`let accent`** (new, first line of `body`).
- **The title and notes fields** (new modifiers: `.focused`, `.inputField`).
- **`.keyboardDismissable { focus = nil }`** (new, after `.background`).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift
//  Phase:   4a (task logic and the add form), changed in 7c (start on a class)
//           and 9b+ (accent fields and keyboard, D-55)
//  Ports:   app/tasks/new/page.tsx and app/tasks/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new assignment, exam or reminder, and for editing
//           one. Only a title is required: no class means Inbox, no date means
//           "No deadline", and no time means all-day. Since 7c a new one can
//           start with its class already picked, as the post-class prompt does.
//           Since 9b+ the title and notes wear your accent, and Done or a
//           swipe down puts the keyboard away.
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

    // NEW in Phase 9b+: which field has the keyboard, so Done can put it away.
    // The notes field grows onto new lines, so its Return key types a new
    // line instead of closing the keyboard: Done is the way out.
    private enum Field { case title, notes }
    @FocusState private var focus: Field?

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
        let accent = store.profile.accent   // NEW in Phase 9b+

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
                    .focused($focus, equals: .title)     // NEW in Phase 9b+
                    .inputField(accent)                  // NEW in Phase 9b+
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
                    .focused($focus, equals: .notes)     // NEW in Phase 9b+
                    .inputField(accent)                  // NEW in Phase 9b+
            }
        }
        // Let the warm canvas show through instead of the system grey.
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        // NEW in Phase 9b+: swipe down, or tap Done above the keys.
        .keyboardDismissable { focus = nil }
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
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Notes/QuickTaskSheet.swift` (replaces your 8d file)

It already had a focus (`titleFocused`), so only two lines are new:

- **Header** (changed).
- **`.inputField(store.profile.accent)`** on the title (new).
- **`.keyboardDismissable { titleFocused = false }`** (new, after
  `.background`).

```swift
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
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift` (replaces your 9b file)

Changed spots:

- **Header** (the Phase line).
- **The class sheet** (changed): `CourseFormView()` inside a
  `NavigationStack`, with a Cancel button, like `NotesView` opens it.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift
// Phase: 9a, changed in 9b (D-54) and 9b+ (the class sheet)
// Ports: app/grades/new, app/grades/[id]/edit and components/GradeFields.
// Summary: One sheet for adding and editing. A failed save keeps the draft.
// Since 9b the fields wear your accent, and the keyboard can be swiped away
// or put down with Done, so Save & add another is never stuck under it.
//
import SwiftUI

struct GradeFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let editing: Grade?
    @State private var draftID: UUID
    @State private var courseID: UUID?
    @State private var title: String
    @State private var kind: Grade.Kind?
    @State private var score: String
    @State private var maximum: String
    @State private var weight: String
    @State private var date: Date
    @State private var message: String? = nil
    @State private var addedCount = 0
    @State private var showCourseForm = false

    // NEW in Phase 9b: which field has the keyboard, so Done can put it away
    // and Return on the title can move on to the score. `@FocusState` (6a).
    private enum Field { case title, score, maximum, weight }
    @FocusState private var focus: Field?

    /// State is seeded once per sheet, never overwritten by a store redraw.
    init(editing: Grade? = nil, courseID: UUID? = nil) {
        self.editing = editing
        _draftID = State(initialValue: editing?.id ?? UUID())
        _courseID = State(initialValue: editing?.courseID ?? courseID)
        _title = State(initialValue: editing?.title ?? "")
        _kind = State(initialValue: editing == nil ? .assignment : editing?.kind)
        _score = State(initialValue: editing.map { String($0.score) } ?? "")
        _maximum = State(initialValue: editing.map { String($0.max) } ?? "100")
        _weight = State(initialValue: editing.map { String($0.weight) } ?? "20")
        _date = State(initialValue: editing.flatMap {
            deadlineDayStart(Deadline(date: $0.date, time: nil))
        } ?? .now)
    }

    /// Match Number("") == 0 on the web. Decimal commas follow the device locale.
    private func number(_ text: String) -> Double {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        return Double(value.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".",
                                                 with: ".")) ?? .nan
    }

    private var draft: Grade {
        Grade(id: draftID, courseID: courseID, title: title, score: number(score),
              max: number(maximum), weight: number(weight), date: dayOf(date), kind: kind)
    }

    /// Exclude the item being edited, so its weight is not counted twice.
    private var otherGrades: [Grade] {
        store.liveGrades.filter { $0.courseID == courseID && $0.id != editing?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section { Text(message).foregroundStyle(Theme.danger) }
                }
                if addedCount > 0 {
                    Section { Text("\(addedCount) saved on this device.") }
                }
                if store.liveCourses.isEmpty {
                    Section {
                        Text("You need a class before you can log a grade.")
                        Button("Add your first class") { showCourseForm = true }
                    }
                } else {
                    Section("Class") {
                        Picker("Class", selection: $courseID) {
                            Text("Choose a class").tag(nil as UUID?)
                            ForEach(store.liveCourses) { course in
                                Text(course.name).tag(Optional(course.id))
                            }
                        }
                    }
                    Section("What was graded?") {
                        Picker("Type", selection: $kind) {
                            Text("No type").tag(nil as Grade.Kind?)
                            ForEach([Grade.Kind.assignment, .quiz, .exam, .project], id: \.self) {
                                Text($0.rawValue.capitalized).tag(Optional($0))
                            }
                        }
                        // CHANGED in Phase 9b: the accent well, and Return goes to Score.
                        TextField("Title", text: $title)
                            .focused($focus, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focus = .score }
                            .inputField(store.profile.accent)
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                    Section("Result") {
                        numberField("Score", text: $score, field: .score)
                        numberField("Out of", text: $maximum, field: .maximum)
                        if let hint = extraCreditHint(number(score), number(maximum)) {
                            Text(hint).font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                    Section("Weight in this class") {
                        numberField("Weight (%)", text: $weight, field: .weight)
                        budget
                    }
                    if editing == nil {
                        Section {
                            Button("Save & add another") { commit(another: true) }
                                .disabled(!store.validGrade(draft))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .tint(Theme.brand(store.profile.accent))
            // NEW in Phase 9b: swipe down or tap Done to see the buttons again.
            .keyboardDismissable { focus = nil }
            .navigationTitle(editing == nil ? "New Grade" : "Edit Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit(another: false) }
                        .disabled(!store.validGrade(draft))
                }
            }
            .onChange(of: kind) { _, next in
                // The new form's type buttons fill an empty/default title.
                // Editing an existing result never renames it unexpectedly.
                let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasLabel = Grade.Kind.allCases.contains { $0.rawValue.capitalized == clean }
                if editing == nil, let next, clean.isEmpty || wasLabel {
                    title = next.rawValue.capitalized
                }
            }
            // CHANGED in Phase 9b+: in its own NavigationStack, like every
            // other place that opens the class form. Without one the sheet had
            // no bar, so no Save, no Cancel, and no Done over the keyboard.
            .sheet(isPresented: $showCourseForm) {
                NavigationStack {
                    CourseFormView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showCourseForm = false }
                            }
                        }
                }
            }
        }
    }

    /// Keep labels visible after typing, including for VoiceOver.
    // CHANGED in Phase 9b: the accent well, at most 120 points wide so it
    // reads as a box for a number, and a focus id for Done.
    private func numberField(_ label: String, text: Binding<String>,
                             field: Field) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focus, equals: field)
                .accessibilityLabel(label)
                .frame(maxWidth: 120)
                .inputField(store.profile.accent)
        }
    }

    /// Warn above 100%, but allow saving: weighted averages still make sense.
    private var budget: some View {
        let used = usedWeight(otherGrades)
        let entered = number(weight)
        let pending = entered.isFinite && entered > 0 ? entered : 0
        let total = used + pending
        let left = remainingWeight(otherGrades)
        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: min(total, 100), total: 100)
                .tint(total > 100 ? Theme.danger : Theme.brand(store.profile.accent))
                .accessibilityLabel("Allocated grade weight")
                .accessibilityValue("\(total.formatted()) percent")
            Text(total > 100
                 ? "This puts the class at \(total.formatted())% of its weight. The average still works, but what do I still need can't be answered past 100%."
                 : "\(used.formatted())% already logged. This takes \(pending.formatted())% more, leaving \((100 - total).formatted())%.")
                .font(.footnote)
                .foregroundStyle(total > 100 ? Theme.danger : Theme.muted)
            if left > 0 && pending != left {
                Button("Use remaining \(left.formatted())%") { weight = String(left) }
            }
        }
    }

    /// Advance only after durable success. A failed attempt keeps its UUID,
    /// values and sheet; a successful next entry gets a fresh UUID.
    private func commit(another: Bool) {
        let saved = editing == nil ? store.addGrade(draft) : store.updateGrade(draft)
        guard saved else {
            message = store.lastSaveFailed
                ? "Couldn't save on this device. Your draft is still here. Tap Save to retry."
                : "This grade or its class is no longer available, or a field is invalid."
            return
        }
        message = nil
        if another {
            addedCount += 1
            let left = remainingWeight(store.liveGrades.filter { $0.courseID == courseID })
            title = ""
            score = ""
            maximum = "100"
            weight = String(left > 0 ? min(20, left) : 20)
            draftID = UUID()
        } else {
            dismiss()
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift` (replaces your 9c file)

Changed spots:

- **Header** (the Phase line).
- **`clear()`** (changed): on success it also sets `draft = .now` (D-58).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift
//  Phase:   9c (finals countdown and the CSV report), changed in 9b+ (D-58)
//  Ports:   components/FinalsCountdown.tsx
//
//  Summary: The Days to Finals card on Grades: a live count of the days left
//           until your finals date, and a small form to set, change or clear
//           it. The date is saved on your profile, as on the web.
//

import SwiftUI

struct FinalsCountdown: View {
    @Environment(Store.self) private var store

    /// True while you're changing a date that's already set.
    @State private var editing = false
    /// The day in the picker, before you tap Save.
    @State private var draft = Date.now
    /// True when the last Save or Clear couldn't be written to the phone.
    @State private var failed = false

    var body: some View {
        let accent = store.profile.accent
        let saved = store.profile.finalsDate
        // A saved date that isn't a real day counts as none, so the card asks again.
        let hasDate = isValidDate(saved)

        VStack(alignment: .leading, spacing: 12) {
            // The label, with Edit beside it while the countdown shows.
            HStack {
                Text("DAYS TO FINALS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if hasDate && !editing {
                    Button("Edit") { openEditor(saved) }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.brandDeep(accent))
                        .frame(minHeight: 44)
                        .accessibilityLabel("Edit finals date")
                }
            }

            if hasDate && !editing {
                // TimelineView (5a) redraws once a minute, so the count turns
                // over at midnight even if this screen stays open.
                TimelineView(.everyMinute) { context in
                    if let status = finalsStatus(saved, context.date) {
                        countdown(status, accent)
                    }
                }
            } else {
                editor(hasDate: hasDate)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// The big number (or Today, or Done) and the sentence under it.
    private func countdown(_ status: FinalsStatus, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(status.headline)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.brandDeep(accent))
                if let unit = status.unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(status.message)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        // One VoiceOver stop: "51, days, Finals begin Thursday, Dec 10. …"
        .accessibilityElement(children: .combine)
    }

    /// Ask for a date (none yet), or change or clear the one you have.
    /// The web shows Clear and Cancel only when there's a date to go back to.
    private func editor(hasDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasDate ? "Update your finals date."
                 : "Add your finals date to see a live countdown.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            // Date only, like the planner's picker in 7b. The compact style
            // shows the day as a button that opens a calendar.
            DatePicker("Finals date", selection: $draft, displayedComponents: .date)

            HStack(spacing: 8) {
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                if hasDate {
                    Button("Clear", action: clear)
                        .buttonStyle(.bordered)
                    Button("Cancel") {
                        editing = false
                        failed = false
                    }
                }
            }

            // The screen's own banner sits far above this card, so say it here too.
            if failed {
                Text("Couldn't save on this device. Try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    /// Start the picker on the saved day: the web's `openEdit`.
    private func openEditor(_ saved: String?) {
        // `deadlineDayStart` turns "2026-12-10" into local midnight that day.
        draft = deadlineDayStart(makeDeadline(saved, nil)) ?? .now
        failed = false
        editing = true
    }

    /// Save the picked day as "yyyy-MM-dd" (`dayOf`: your own calendar day,
    /// never UTC's). The form stays open with a red line if the phone
    /// couldn't write it.
    private func save() {
        failed = !store.setFinalsDate(dayOf(draft))
        if !failed { editing = false }
    }

    /// Remove the date. The card goes back to asking for one.
    /// CHANGED in Phase 9b+ (D-58): the picker goes back to today as well.
    /// It used to keep showing the date you'd just cleared, which looked as
    /// if Clear hadn't worked. (The web keeps it; here it reads better fresh.)
    private func clear() {
        failed = !store.setFinalsDate(nil)
        if !failed {
            editing = false
            draft = .now
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Grades/TermReportCard.swift` (replaces your 9c file)

Changed spots:

- **Header** (the Phase line).
- **`let data`** (changed): `"\u{FEFF}"` goes in front of the CSV.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/TermReportCard.swift
//  Phase:   9c (finals countdown and the CSV report), changed in 9b+
//           (a byte-order mark for Excel)
//  Ports:   ExportReportButton in app/grades/page.tsx (its CSV half) and
//           downloadGradeReport in lib/report.ts
//
//  Summary: The Term report card on Grades. One button opens the share sheet
//           with classping-grades.csv, built on the phone from this term's
//           classes and results: save it to Files, mail it, or AirDrop it.
//           The printable PDF is made by the server, so it waits for sign-in
//           (D-6).
//

import SwiftUI
import UniformTypeIdentifiers

/// The report as something the share sheet can send: a .csv file.
/// `Transferable` is how a value tells iOS what it can become (text, an
/// image, a file). On the web, `downloadBlob` in lib/report.ts does this job.
struct GradeReportFile: Transferable {
    /// This term's classes, results and scale, copied when the card was drawn.
    let report: TermReport

    /// The one form it can take: a file of type CSV (`.commaSeparatedText`).
    static var transferRepresentation: some TransferRepresentation {
        // FileRepresentation runs this only once you pick where the report
        // goes, so the file is built, and dated, at the moment you share it.
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            // The app's temporary folder, which iOS empties on its own. The
            // file name is the one the web downloads.
            let url = URL.temporaryDirectory.appending(path: "classping-grades.csv")
            // CHANGED in Phase 9b+: "\u{FEFF}" first, the byte-order mark.
            // Excel on Windows reads a CSV without it in the old local code
            // page and garbles accented names; Numbers and Sheets skip it.
            // The web's `gradeReportBlob` adds the same three bytes.
            let data = Data(("\u{FEFF}" + file.report.csv(at: .now)).utf8)
            // `try?` turns a failed write into nil. This closure is allowed to
            // throw, and throwing tells the share sheet the file couldn't be
            // made, instead of handing over one that isn't there.
            guard (try? data.write(to: url, options: .atomic)) != nil else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

struct TermReportCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TERM REPORT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            // ShareLink is a button that opens the share sheet with `item`.
            // SharePreview is the title and icon at the top of that sheet.
            ShareLink(item: GradeReportFile(report: store.termReport),
                      preview: SharePreview("ClassPing grade report",
                                            image: Image(systemName: "tablecells"))) {
                Label("Share as a spreadsheet (CSV)", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)

            Text("Every result with its class, a summary for each class and your GPA. Opens in Numbers, Google Sheets or Excel.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Text("The printable PDF report needs sign-in, which comes later.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
```

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # still 371
scripts/test-store.sh     # still 79
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

1. **Assignment:** + → Assignment. The title has the accent well. Type a few
   lines in Notes (Return adds a line there), then tap **Done** above the
   keys: the keyboard goes and Save is in view. Tap the title again and
   swipe down the form: the keyboard follows your finger away.
2. **Class:** + → Class. Name, Room, Teacher, Credit hours and Notes are all
   wells. Tap **+ Add another meeting time**: its label and room are wells
   too. Tap into a **room** field and tap **Done**: the keyboard must go
   (this is the shared focus at work). Tap **Credit hours**: the number pad
   has no return key, and Done is how you leave it.
3. **Edit a class:** from Today's My Classes, Edit. Same look, same Done.
4. **Quick sheet:** open a note and tap the bell or the plus. The title sits
   in a well and the sheet opens at half height with Done over the keys.
5. **Finals Clear:** on Grades, Edit → **Clear**. The card asks for a date
   and the picker shows **today**. Then fully close the app (swipe up from
   the bottom edge, pause, and flick ClassPing off the top) and reopen: the
   card still asks for a date.
6. **Excel:** rename a throwaway class to "Français" (or log a grade called
   "Café quiz"), share the report, mail it to yourself and open it in Excel
   on the laptop: the ç or é shows correctly. Put the name back afterwards.
7. **Presentation:** both accents, light and dark: the text in every well
   stays easy to read.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] The tree builds without warnings; 371 logic and 79 store tests pass.
- [ ] Every field in the assignment, class and quick forms wears the accent.
- [ ] Done and swipe-down put the keyboard away on all of them, room fields
      included.
- [ ] Clear resets the picker, and a cleared date stays cleared after a full
      close.
- [ ] An accented name shows correctly in Excel.

## 7. If it breaks

- **Cannot find type 'CourseField' in scope (in MeetingFields):** 4.1 isn't
  in yet, or the enum ended up inside `struct CourseFormView`. It sits above
  it, at the top level of the file.
- **Missing argument for parameter 'focus' in call:** `CourseFormView` still
  calls `MeetingFields(meetings:accent:)`. Add `focus: $focus`.
- **Done does nothing in a room field:** `MeetingFields` has its own
  `@FocusState` instead of the `focus` it's handed. It must use
  `.focused(focus, equals: .room(meeting.id))`, with no `$` (it's already a
  binding).
- **No Done bar at all on a form:** `.keyboardDismissable` has to be on the
  `Form`, and the form has to be inside a `NavigationStack`. All four are.
- **Tapping a meeting's label field removes the meeting:** the Remove button
  next to it lost `.buttonStyle(.borderless)`, so the whole row became one
  big button.

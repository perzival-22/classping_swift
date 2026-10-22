---
title: "Phase 5b: Classes, added and edited"
date: 2026-10-17
generated_by: skills-for-architects
---

# Phase 5b: Classes, added and edited

*Second half of Phase 5 (D-20). Typed and building in Kelvin's project (commit `3fd880f`, `BUILD_OK` with no warnings, checked 2026-10-17). His copy has a few extra changes beyond this doc, listed in PROGRESS.md and mirrored in `reference/`.*

**Before you start:** Phase 5a is typed, building, committed and tried on the phone.

## 1. Goal

You can add your real classes and fix them, and tapping the week shows a class's details.

**On your phone:** **+ → Class** slides in the class form. Type a name, tap the days it meets (or a shortcut like **Mon/Wed/Fri**), set the start and end with the time wheels (or a **50 / 60 / 90 min** shortcut), add a room. **+ Add another meeting time** adds a second meeting, say a Friday lab, with its own name and room. **Schedule not known yet** saves a class with no times; it shows under "Not yet scheduled" on the week. **More details** has teacher, credits and notes, then a row of nine colors and the reminder choice. Save, open the week on Today, and your class is there. Tap its block: a sheet with the time, room, teacher, other days, credits and reminder, your note, and **Edit** at the top. Tap a "Not yet scheduled" chip and its form opens so you can add its times.

Deleting a class comes in Phase 6, with an Undo that brings back its tasks too (D-21). Until then, fix a wrong class with Edit.

## 2. New Swift concepts

**`ForEach` over a binding.** `ForEach($meetings) { $meeting in ... }` loops over a list *as bindings*. Inside, `$meeting` is a two-way connection to one element, so a TextField or a button writes straight back into the array, and `meeting` (no `$`) is its current value. Rows are told apart by `id`, so removing one leaves the others alone.

```swift
@Binding var meetings: [ClassMeeting]
ForEach($meetings) { $meeting in
    TextField("Room", text: optionalText($meeting.room, limit: 200))
}
```

**A `DatePicker` for a time that isn't a `Date`.** A meeting stores minutes from midnight (600 = 10:00 AM), but a DatePicker works with `Date`s. Phase 4b's `Binding(get:set:)` builds the bridge: `get` turns the minutes into today at that time, `set` turns the picked time back into minutes.

```swift
DatePicker("Starts", selection: Binding(
    get: { Calendar.current.date(bySettingHour: start / 60, minute: start % 60, second: 0, of: .now) ?? .now },
    set: { start = minuteOfDay($0) }
), displayedComponents: .hourAndMinute)
```

**An enum with associated values driving one sheet.** Today can show two different sheets: a class's details or its form. Each enum case carries what its sheet needs, and a single `.sheet(item:)` switches on the case. Only one sheet can be up at a time, and the enum says so in the type.

```swift
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)
    var id: String { ... }
}
.sheet(item: $sheet) { which in
    switch which {
    case .meeting(let opened):    CourseSheet(opened: opened)
    case .editCourse(let course): NavigationStack { CourseFormView(editing: course) }
    }
}
```

You'll also meet `NavigationLink { destination } label: { ... }`, the simplest way to push a screen when there's no value to pass along, and an empty `struct NewCourseLink: Hashable {}` used as a marker for `.navigationDestination`.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `addClass`, `updateClass`, `liveClasses`, `activeClasses` in `lib/store.tsx` | `Store+Courses.swift` | Same actions, whole edited class in, save straight away. `deleteClass` waits for Phase 6 (D-21). XP for a new class comes in Phase 12 |
| `components/ClassForm.tsx`, `app/class/new`, `app/class/[id]/edit` | `Screens/Courses/CourseFormView.swift` | Same fields, defaults, checks and messages, and the same "short" code (first word, 5 letters). Not here yet: the import button (Phase 13), the term setup sheet after your first class (Phase 11), extra calendar alerts (Phase 7), the half-typed draft kept when you leave (the web's `useDraft`) |
| `components/MeetingFields.tsx` | `Components/MeetingFields.swift` | One form section per meeting. Time wheels instead of the browser's time inputs |
| `components/ColorPicker.tsx` | the color row in `CourseFormView` | All nine colors (the web's Pro gate doesn't exist on the phone) |
| `ClassSheet` in `app/week/page.tsx` | `Screens/Week/CourseSheet.swift` | Same rows and note. Edit pushes the form inside the sheet instead of leaving the page |
| the Class row of `components/AddMenu.tsx` | `Components/AddMenu.swift` | Pushes the class form, the way Assignment pushes the task form |

## 4. Files, in the order to type them

```bash
cd ~/ClassPing/Sources/ClassPing
mkdir -p Screens/Courses
```

### 4.1 `~/ClassPing/Sources/ClassPing/Store+Courses.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Courses.swift
//  Phase:   5b (classes: add and edit)
//  Ports:   lib/store.tsx (liveClasses, activeClasses, addClass, updateClass)
//
//  Summary: Reading and changing classes. Like the assignment actions, each
//           change saves to the phone straight away. Deleting a class comes in
//           Phase 6, together with an Undo that brings back its work too (D-21).
//

import Foundation

extension Store {
    // MARK: - Reading

    /// Every class that hasn't been deleted. `liveClasses` in lib/store.tsx.
    /// (Looking one up by id is `course(_:)`, which sits in
    /// Store+Assignments.swift until Phase 6 reworks that file.)
    var liveCourses: [Course] {
        courses.filter { $0.deletedAt == nil }
    }

    /// The live classes on this term's timetable: archived ones left out.
    /// `activeClasses` in lib/store.tsx. Today's week draws these.
    var activeCourses: [Course] {
        liveCourses.filter { !$0.archived }
    }

    // MARK: - Adding and editing

    /// Adds a new class. `addClass` in lib/store.tsx (its XP credit comes in Phase 12).
    func addCourse(_ course: Course) {
        courses.append(course)
        save()
    }

    /// Replaces a class with an edited copy, matched by id. `updateClass` on the
    /// web takes only the changed fields; the form here hands back the whole
    /// edited class, the same choice `updateAssignment` made in Phase 4a.
    func updateCourse(_ edited: Course) {
        guard let index = courses.firstIndex(where: { $0.id == edited.id }) else { return }
        courses[index] = edited
        save()
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Components/MeetingFields.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/MeetingFields.swift
//  Phase:   5b (classes: add and edit)
//  Ports:   components/MeetingFields.tsx (newMeeting, MeetingFields)
//
//  Summary: The "when does this class meet?" part of the class form, one
//           section per meeting: day buttons with shortcuts, start and end
//           times with duration shortcuts, and a room. Extra meetings get a
//           name ("Lab") and a Remove button. Edits go straight back into the
//           form's list through a binding.
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
                            TextField("Meeting label (optional), e.g. Lab",
                                      text: optionalText($meeting.label, limit: 80))
                            // `.borderless` keeps this button from turning the
                            // whole row into one big tap target.
                            Button("Remove", role: .destructive) {
                                let gone = meeting.id
                                meetings.removeAll { $0.id == gone }
                            }
                            .buttonStyle(.borderless)
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
                DatePicker("Ends", selection: clock($meeting.end),
                           displayedComponents: .hourAndMinute)

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

                TextField("Room (optional), e.g. Science 204",
                          text: optionalText($meeting.room, limit: 200))
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

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Courses/CourseFormView.swift` (new file)

```swift
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
                     ? "Reminder: \(remindBefore) minutes before each meeting. Reminders start ringing in Phase 7."
                     : "Pre-class reminders are off.")
            }

            // What's wrong, in the web's words.
            if let problem {
                Section {
                    Text(problem)
                        .foregroundStyle(Theme.danger)
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
                        .frame(maxWidth: .infinity, minHeight: 40)
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
        if editing == nil {
            store.addCourse(c)
        } else {
            store.updateCourse(c)
        }

        if another {
            // Clear the subject's own fields; the reminder choice carries over
            // to the next class, which is the point of typing a timetable in a row.
            name = ""
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
    value == value.rounded() ? String(Int(value)) : String(value)
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Week/CourseSheet.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Week/CourseSheet.swift
//  Phase:   5b (classes: add and edit)
//  Ports:   ClassSheet and DetailRow in app/week/page.tsx
//
//  Summary: The details of one class, opened by tapping its block on the week:
//           when and where it meets, who teaches it, the reminder, and the note
//           you left on it. Edit opens the class form right here.
//

import SwiftUI

/// What the week hands over when a block is tapped: which class, which of its
/// meetings, and which day column (a class can meet on several days, and the
/// sheet says which one you opened). Only ids are kept, so the sheet always
/// reads the latest version of the class from the store.
struct OpenedMeeting: Hashable {
    let courseID: UUID
    let meetingID: UUID
    let day: Int        // 0 = Monday ... 6 = Sunday
    let date: Date      // that column's date
}

struct CourseSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let opened: OpenedMeeting

    var body: some View {
        NavigationStack {
            // Look the class and meeting up fresh on every redraw, so a change
            // saved with Edit shows the moment you come back. (The web resolves
            // it from the store for the same reason.) Both must still exist:
            // an edit can remove that meeting, or give the class no times.
            if let course = store.course(opened.courseID),
               let meeting = classMeetings(course).first(where: { $0.id == opened.meetingID }) {
                details(course, meeting)
            } else {
                ContentUnavailableView("This class has changed",
                                       systemImage: "calendar.badge.exclamationmark",
                                       description: Text("Close this and tap it again on the week."))
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - The details

    private func details(_ course: Course, _ meeting: ClassMeeting) -> some View {
        let accent = store.profile.accent
        let brand = Theme.brand(accent)
        // The meeting's other days, by short name: "Also on Mon · Fri".
        let otherDays = meeting.days.sorted()
            .filter { $0 != opened.day && dayLabels.indices.contains($0) }
            .map { dayLabels[$0] }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // The class's badge, its name, and the day you tapped.
                HStack(alignment: .top, spacing: 12) {
                    badge(course)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(opened.date.formatted(.dateTime.weekday(.wide))), \(fmtMD(opened.date))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                        // An extra meeting's name, like "Lab".
                        if let label = meeting.label, !label.isEmpty {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(brand)
                        }
                    }
                }

                // The facts, one row each. Missing ones say "Not set".
                VStack(spacing: 0) {
                    row("Time", "\(fmtTime(meeting.start)) – \(fmtTime(meeting.end))",
                        hint: "\(meeting.end - meeting.start) min")
                    row("Room", meeting.room ?? "Not set", muted: meeting.room == nil)
                    row("Teacher", course.instructor ?? "Not set", muted: course.instructor == nil)
                    if !otherDays.isEmpty {
                        row("Also on", otherDays.joined(separator: " · "))
                    }
                    if let credits = course.credits {
                        row("Credits", credits.formatted())
                    }
                    row("Reminder", course.alarm ? "\(course.remindBefore) min before" : "Off",
                        muted: !course.alarm)
                }
                .padding(.horizontal, 14)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                // The note you left on this class, or a way to add one.
                if let note = course.notes, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR NOTE")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.faint)
                        Text(note)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    NavigationLink {
                        CourseFormView(editing: course)
                    } label: {
                        Text("+ Add a note for this class, office hours, what to bring…")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(brand.opacity(0.16), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // `NavigationLink { destination } label: { ... }` pushes the form
            // inside this sheet. Saving there pops back here (the form's dismiss).
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CourseFormView(editing: course)
                } label: {
                    Label("Edit class", systemImage: "pencil")
                }
            }
        }
    }

    /// A small hardcover in the class's colors with its short code, like the
    /// web's SubjectBook: a soft cover and a darker spine down the left.
    private func badge(_ course: Course) -> some View {
        Text(course.short)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.subjectInk(course.color))
            .lineLimit(1)
            .padding(.leading, 8)
            .frame(width: 64, height: 36)
            .background(Theme.subjectSoft(course.color))
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.subject(course.color)).frame(width: 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityHidden(true)
    }

    /// One fact: a label, its value, and an optional hint on the right.
    /// `DetailRow` in app/week/page.tsx.
    private func row(_ label: String, _ value: String, hint: String? = nil,
                     muted: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted2)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(muted ? Theme.hint : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.vertical, 11)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Components/AddMenu.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AddMenu.swift
//  Phase:   3 (app shell), changed in 4a (the first three rows open the
//           task form) and 5b (Class opens the class form)
//  Ports:   components/AddMenu.tsx (the five labelled choices)
//
//  Summary: The sheet the Add button opens: the five things you can add, named,
//           in the same order as the web app. Assignment, Exam and Reminder
//           slide in the task form, Class slides in the class form; Note still
//           just closes (Phase 8).
//

import SwiftUI

/// The value pushed when you pick Class. An empty marker type: it carries no
/// data, it just tells `.navigationDestination` below which form to show.
// NEW in Phase 5b
struct NewCourseLink: Hashable {}

struct AddMenu: View {
    /// `dismiss` closes the sheet, the way `onClose()` does in the web component.
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store

    /// How tall the sheet is. Starts at half height; jumps to full when a
    /// form slides in, because a form needs the room.
    @State private var detent: PresentationDetent = .medium   // NEW in Phase 4a

    /// One choice in the menu. `symbol` is an SF Symbol name (the native icon set
    /// that replaces components/icons.tsx). `kind` is set for the three rows
    /// that open the task form; `addsCourse` for the Class row.
    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let symbol: String
        var kind: Assignment.Kind? = nil       // NEW in Phase 4a
        var addsCourse = false                 // NEW in Phase 5b
    }

    /// The five choices, matching AddMenu.tsx's list and wording.
    private let options = [
        Option(label: "Assignment", detail: "Homework, essays, lab reports", symbol: "doc.text", kind: .assignment),
        Option(label: "Exam", detail: "A test or quiz to revise for", symbol: "graduationcap", kind: .exam),
        Option(label: "Reminder", detail: "Something to bring or do, not graded", symbol: "bell", kind: .reminder),
        Option(label: "Note", detail: "Write down a lecture or a thought", symbol: "pencil"),
        // CHANGED in Phase 5b: Class now opens the class form.
        Option(label: "Class", detail: "Add a subject to your timetable", symbol: "book", addsCourse: true),
    ]

    var body: some View {
        NavigationStack {
            List(options) { opt in
                // A row with a kind pushes that kind; the Class row pushes the
                // marker. Each value type has its own destination below.
                if let kind = opt.kind {
                    NavigationLink(value: kind) {
                        label(for: opt)
                    }
                } else if opt.addsCourse {
                    // NEW in Phase 5b
                    NavigationLink(value: NewCourseLink()) {
                        label(for: opt)
                    }
                } else {
                    // Note (Phase 8) still just closes the menu.
                    Button {
                        dismiss()
                    } label: {
                        label(for: opt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // What to show when a kind is pushed. Saving closes the whole Add
            // sheet (not just the form), so `onFinish` is our dismiss.
            .navigationDestination(for: Assignment.Kind.self) { kind in
                AssignmentFormView(kind: kind, onFinish: { dismiss() })
                    .onAppear { detent = .large }
            }
            // NEW in Phase 5b: and when Class is picked.
            .navigationDestination(for: NewCourseLink.self) { _ in
                CourseFormView(onFinish: { dismiss() })
                    .onAppear { detent = .large }
            }
        }
        // A sheet that opens to about half height, draggable to full. The
        // `selection:` lets the code above change the height too.
        .presentationDetents([.medium, .large], selection: $detent)   // CHANGED in Phase 4a
    }

    /// One row's look: a brand-soft rounded square holding the icon, then the
    /// name and a one-line description, like the web rows.
    // NEW in Phase 4a (moved out of `body`, so both row types can share it)
    private func label(for opt: Option) -> some View {
        let accent = store.profile.accent
        return HStack(spacing: 14) {
            Image(systemName: opt.symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 38, height: 38)
                .background(Theme.brand(accent).opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(opt.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(opt.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/TodayView.swift` (replaces the file)

The 5a file with three changes, all marked: the `TodaySheet` enum at the top, the `sheet` state and its `.sheet(item:)`, and the two closures handed to `WeekGrid`. `courses` now comes from `store.activeCourses`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/TodayView.swift
//  Phase:   3 (app shell), rewritten in 5a (the week lives here now, D-19),
//           changed in 5b (tapping the week opens class details and the form)
//  Ports:   app/home/page.tsx (the greeting and day picking) and
//           app/week/page.tsx (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Tap a class block
//           for its details. Phase 6 adds the picked day's classes,
//           priorities and planned work below.
//

import SwiftUI

/// The one sheet Today can show. An enum with associated values: each case
/// carries what its sheet needs (the tapped meeting, or the class to edit).
/// One `.sheet(item:)` then covers both, because only one sheet can be up at
/// a time anyway. `Identifiable` asks for an `id`, made from each case's data.
// NEW in Phase 5b
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)

    var id: String {
        // `case .meeting(let o)` matches that case and names what it carries.
        switch self {
        case .meeting(let o): "meeting-\(o.courseID)-\(o.meetingID)-\(o.day)"
        case .editCourse(let c): "course-\(c.id)"
        }
    }
}

struct TodayView: View {
    @Environment(Store.self) private var store

    // MARK: Screen state
    // NEW in Phase 5a. None of this is saved: Today always opens on this
    // week, folded, with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    /// The sheet that's up, or nil for none. NEW in Phase 5b
    @State private var sheet: TodaySheet? = nil

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the now line moves and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // CHANGED in Phase 5b: now a store property (Store+Courses.swift).
            let courses = store.activeCourses

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)
                    dayCard(courses)
                }
                .padding(16)
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Today")
        // The calendar button where the web's gear used to be (the gear's
        // job moved to the Profile tab). It opens and folds the week.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWeek()
                } label: {
                    Image(systemName: weekOpen ? "calendar.circle.fill" : "calendar")
                }
                .accessibilityLabel(weekOpen ? "Fold the week away" : "Show the whole week")
            }
        }
        // NEW in Phase 5b: whichever sheet `sheet` names. A `switch` inside
        // picks the view for each case.
        .sheet(item: $sheet) { which in
            switch which {
            case .meeting(let opened):
                CourseSheet(opened: opened)
            case .editCourse(let course):
                NavigationStack {
                    CourseFormView(editing: course)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - The week

    /// The card holding the week: the grid when open, the strip when folded,
    /// and the handle underneath either way.
    private func weekCard(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let start = store.profile.termStart
        let end = store.profile.termEnd

        return VStack(spacing: 6) {
            // `$weekOffset` hands the child a binding: the strip and the grid
            // both read and change the same week.
            if weekOpen {
                // CHANGED in Phase 5b: the two closures say what a tap does.
                WeekGrid(courses: courses, termStart: start, termEnd: end, now: now,
                         weekOffset: $weekOffset, accent: accent,
                         onOpen: { slot, day, date in
                             sheet = .meeting(OpenedMeeting(courseID: slot.course.id,
                                                            meetingID: slot.meeting.id,
                                                            day: day, date: date))
                         },
                         onSchedule: { course in
                             sheet = .editCourse(course)
                         })
                    .transition(.opacity)
            } else {
                WeekStrip(courses: courses, termStart: start, termEnd: end, now: now,
                          weekOffset: $weekOffset, selected: $selectedDay, accent: accent)
                    .transition(.opacity)
            }
            handle
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// The little bar under the week. Tap it, or drag it down to open and up
    /// to fold. `highPriorityGesture` means a drag that starts on the handle
    /// moves the week instead of scrolling the page.
    private var handle: some View {
        Capsule()
            .fill(Theme.lineStrong)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .onTapGesture { toggleWeek() }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10).onEnded { drag in
                    // Down by 24 points or more opens; up by 24 or more folds.
                    if drag.translation.height > 24 && !weekOpen { toggleWeek() }
                    if drag.translation.height < -24 && weekOpen { toggleWeek() }
                }
            )
            // To VoiceOver this is a button with a clear name.
            .accessibilityElement()
            .accessibilityLabel(weekOpen ? "Fold the week away" : "Open the whole week")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggleWeek() }
    }

    /// Opens or folds the week. `withAnimation` animates every change the
    /// toggle causes: the card grows or shrinks smoothly, and the strip and
    /// grid cross-fade because each has `.transition(.opacity)`.
    private func toggleWeek() {
        withAnimation(.snappy) {
            weekOpen.toggle()
        }
    }

    // MARK: - The picked day

    /// A one-line look at the day picked in the strip. Phase 6 replaces this
    /// card with that day's class cards, priorities and planned work.
    private func dayCard(_ courses: [Course]) -> some View {
        let col = dayIndex(of: selectedDay)
        let inTerm = isWithinTerm(store.profile.termStart, store.profile.termEnd, selectedDay)
        let count = inTerm
            ? expandClassMeetings(courses).filter { $0.meeting.days.contains(col) }.count
            : 0
        // "Wednesday", in the phone's language.
        let dayName = selectedDay.formatted(.dateTime.weekday(.wide))
        let headline = switch count {
        case 0: "No classes on \(dayName)"
        case 1: "\(dayName) · 1 class"
        default: "\(dayName) · \(count) classes"
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Phase 6 lists that day's classes here, with your priorities and planned work.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "Good morning, Kelvin". The web's `greeting(hour)` plus the first part
    /// of your username; just the greeting until you've set a name.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? hello : "\(hello), \(first)"
    }
}
```

## 5. Run it

```bash
cd ~/ClassPing
xtool dev
```

Then on the phone:

1. **+ → Class.** Name it "Biology", tap **Tue/Thu**, pick 11:00 for Starts, tap **90 min**. Room "Science 204". Save. The Add sheet closes.
2. Open the week on Today. Biology sits on Tuesday and Thursday from 11:00.
3. Tap a Biology block. The sheet shows "11:00 AM – 12:30 PM, 90 min", the room, "Also on Thu" (or Tue), and "15 min before".
4. Tap **Edit**, then **+ Add another meeting time**: Friday, 14:00, **60 min**, label "Lab". Save. You're back on the sheet; close it. Friday has a Biology block now, and tapping it shows "Lab".
5. **+ → Class** again, name "Chemistry", turn on **Schedule not known yet**, Save. On the open week, "Chemistry" is under **Not yet scheduled**. Tap it: its form opens. Turn the switch off, pick days and times, Save. It's on the grid.
6. Try to save a class with no name, then one with an end time before its start: each shows its message and nothing is saved.
7. Close the app completely and reopen it: your classes are still there.

When it works: `git add -A && git commit -m "phase 5b"`.

## 6. Done when

- [ ] + → Class opens the form; Save adds the class and closes the sheet.
- [ ] Days, shortcuts, time wheels, duration shortcuts and room all work; the end-before-start warning appears straight away.
- [ ] A second meeting can be added, labelled and removed.
- [ ] "Schedule not known yet" saves a class under Not yet scheduled, and tapping it opens the form.
- [ ] Tapping a block opens its details; Edit saves and comes back to the sheet with the change showing.
- [ ] "Save & add another" clears the form and says "<name> added. Ready for the next class."
- [ ] New and edited classes survive a relaunch, and they show up in the task form's Class picker.

## 7. If it breaks

- **`cannot find 'OpenedMeeting' in scope`** in TodayView: 4.4 (`CourseSheet.swift`) isn't typed yet; `OpenedMeeting` lives at its top.
- **Tapping one day button ticks all seven** (or a shortcut sets the wrong days): a missing `.buttonStyle(.plain)` on `dayButton`, or `.buttonStyle(.borderless)` on the shortcuts. Inside a Form, buttons without a style share the whole row's tap.
- **The class saves but isn't on the week**: check the Today card is reading `store.activeCourses`, and that the class isn't "Schedule not known yet".
- **The time wheel jumps back after you pick a time**: the `set:` side of `clock(_:)` isn't writing `minuteOfDay(picked)` into `minutes.wrappedValue`.

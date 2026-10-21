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
                return Calendar.autoupdatingCurrent.date(bySettingHour: m / 60, minute: m % 60,
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

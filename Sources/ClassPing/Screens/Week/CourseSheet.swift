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
    /// Keep form navigation outside the conditional details, since an edit can
    /// remove the opened meeting while the form is still on the stack.
    @State private var editing = false
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            Group {
                // Resolve fresh details after Edit. A removed meeting or an
                // unscheduled class no longer has a block on the opened day.
                if let course = store.course(opened.courseID),
                   let meeting = classMeetings(course).first(where: {
                       $0.id == opened.meetingID && $0.days.contains(opened.day)
                   }) {
                    details(course, meeting)
                } else {
                    ContentUnavailableView("This class has changed",
                                           systemImage: "calendar.badge.exclamationmark",
                                           description: Text("Close this and tap it again on the week."))
                }
            }
            .navigationDestination(isPresented: $editing) {
                if let course = store.course(opened.courseID) {
                    CourseFormView(editing: course)
                        .onAppear { detent = .large }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
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
                    Button {
                        editing = true
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
            // Push the form inside this sheet; Save pops back to fresh details.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = true
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

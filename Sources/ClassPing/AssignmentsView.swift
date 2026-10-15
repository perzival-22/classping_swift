//
//  File:    ~/ClassPing/Sources/ClassPing/AssignmentsView.swift
//  Phase:   2 (time and deadline logic)  [was Phase 1]
//  Ports:   app/tasks/page.tsx (a first, plain list; Phase 4 builds the real screen)
//
//  Summary: Lists every assignment with its class and deadline. Tapping a row
//           completes it, and the change is saved on the phone. The deadline is
//           now friendly text ("Tomorrow", "In 5 days · 10:00 AM") from the
//           ported lib/deadline.ts helper, instead of the raw stored strings.
//

import SwiftUI

/// The Tasks tab, for now a simple list.
struct AssignmentsView: View {
    /// Reads the shared store that ClassPingApp put into the environment.
    @Environment(Store.self) private var store

    var body: some View {
        List {
            // Only shown when the last save failed. Never hide a failed save.
            if store.lastSaveFailed {
                Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                    .foregroundStyle(.red)
            }

            // One row per assignment. A Button makes the whole row tappable.
            ForEach(store.assignments) { assignment in
                Button {
                    store.toggleAssignment(assignment.id)
                } label: {
                    row(for: assignment)
                }
                .foregroundStyle(.primary)   // keep the text black/white, not button blue
            }
        }
    }

    /// What one row shows: the title, then the class and the deadline.
    private func row(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assignment.title)
                .font(.headline)
                // Completed work is struck through, like the web's done rows.
                .strikethrough(assignment.done)
            Text("\(courseName(for: assignment)) · \(deadlineText(for: assignment))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// The short name of the class an assignment belongs to, or "Inbox" when it has none.
    private func courseName(for assignment: Assignment) -> String {
        // `first(where:)` walks the courses and stops at the first match. It returns
        // an optional, because there might be no match.
        let course = store.courses.first(where: { $0.id == assignment.courseID })
        // `?.short ?? "Inbox"`: use the course's short name if there is a course,
        // otherwise the word the web app uses for unfiled work.
        return course?.short ?? "Inbox"
    }

    /// The deadline in friendly words.
    /// CHANGED in Phase 2: the hand-rolled "due <date>" text is gone. The row now
    /// asks the ported lib/deadline.ts helper, through the model's `deadline`
    /// property, for the same label the web app shows. `.now` is the current
    /// instant, so "Today" and "Overdue" are judged against the real clock.
    private func deadlineText(for assignment: Assignment) -> String {
        formatDeadline(assignment.deadline, .now)
    }
}
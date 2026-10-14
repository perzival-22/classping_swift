//
//  File:    ~/ClassPing/Sources/ClassPing/AssignmentsView.swift
//  Phase:   0 (housekeeping)
//  Ports:   app/tasks/page.tsx (a first, plain list; Phase 4 builds the real screen)
//
//  Summary: Lists every assignment in the store with its class and due date, so you
//           can see on the phone that the store reached the screen.
//
import SwiftUI

/// The Tasks tab, for now a simple list.
struct AssignmentsView: View {
    /// Reads the shared store that ClassPingApp put into the environment.
    @Environment(Store.self) private var store

    var body: some View {
        // CHANGED in Phase 1: `List { ... }` with `ForEach` inside, so the list can
        // hold a warning row as well as the assignment rows.
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
    /// NEW in Phase 1 (moved out of `body` to keep it readable)
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

    /// The deadline in words, for now the raw stored text. Phase 2 makes it friendly
    /// ("Tomorrow, 10:00 AM") with the ported lib/deadline.ts helpers.
    /// NEW in Phase 1: `due` is optional now, so "no date" needs its own case.
    private func deadlineText(for assignment: Assignment) -> String {
        // `if let` unwraps the optional: inside the braces, `due` is a plain String.
        if let due = assignment.due {
            // A time is only meaningful when there's a date.
            if let time = assignment.dueTime {
                return "due \(due) at \(time)"
            }
            return "due \(due), all day"
        }
        return "no date"
    }
}

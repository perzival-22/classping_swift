//
//  File:    ~/ClassPing/Sources/ClassPing/AssignmentsView.swift
//  Phase:   0 (housekeeping)
//  Ports:   app/tasks/page.tsx (a first, plain list; Phase 4 builds the real screen)
//
//  Summary: Lists every assignment in the store with its class and due date, so you
//           can see on the phone that the store reached the screen.
//

import SwiftUI

struct AssignmentsView: View {
    /// Reads the shared store that ClassPingApp put into the environment
    
    @Environment(Store.self) private var store
    var body: some View {
        // NEW in Phase 0: `List` draws one row per item. It can do that because
        // Assignment is Identifiable (it has an `id`), so SwiftUI can tell rows apart.
        List(store.assignments) { assignment in
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.headline)
                    // Completed work is struck through, like the web's done rows.
                    .strikethrough(assignment.done)
                // The second line: which class, and when it's due.
                Text("\(courseName(for: assignment)) · due \(assignment.due)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
///The short name of the class as assingment belongs to, or Inbox when it has none.
private func courseName(for assignment: Assignment) -> String {
    //first (where:) walks the course and stops at the first match. it 
    // returns an optional, because there might be no match
    let course = store.courses.first(where: { $0.id == assignment.courseID})
    // '?.short ?? "Inbox"': use the course short name if there is a course, 
    // otherwise the word the webapp usesd for unfiolled work.
    return course?.short ?? "Inbox"
    }
}

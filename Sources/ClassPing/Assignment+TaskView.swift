//
//  File:    ~/ClassPing/Sources/ClassPing/Assignment+TaskView.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   lib/task-view.ts (`taskKind`), app/tasks/page.tsx (`typeLabel`)
//
//  Summary: Signs Assignment up for the Tasks logic in Logic/TaskView.swift,
//           and gives each kind its on-screen name. Like Assignment+Deadline,
//           this lives outside Logic/ because it needs the model.
//

import Foundation

/// Assignment already has `title`, `courseID`, `due` and `dueTime`, so the
/// only thing missing for `TaskListable` is the kind as plain text. With this,
/// `groupTasks`, `filterTasks` and `sortsBefore` all accept assignments.
extension Assignment: TaskListable {
    var kindName: String { kind.rawValue }
}

extension Assignment.Kind {
    /// The spelled-out type for the detail screen. `typeLabel` in app/tasks/page.tsx.
    var label: String {
        switch self {
        case .assignment: "Assignment"
        case .quiz:       "Quiz"
        case .exam:       "Exam"
        case .reminder:   "Reminder"
        }
    }

    /// The plural the filter chips use: "Assignments", "Quizzes"...
    /// `KINDS` in components/TaskFilterBar.tsx.
    var pluralLabel: String {
        switch self {
        case .assignment: "Assignments"
        case .quiz:       "Quizzes"
        case .exam:       "Exams"
        case .reminder:   "Reminders"
        }
    }
}

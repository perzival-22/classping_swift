//
//  File:    ~/ClassPing/Sources/ClassPing/Records.swift
//  Phase:   1 (complete data models), two field names fixed in 6a
//  Ports:   lib/store.tsx (GradeItem), lib/notes.ts (NoteItem),
//           lib/planning.ts (TaskPlan, StudySession), lib/supabase/map.ts
//
//  Summary: The four smaller record types: grades, notes, planned work days and
//           finished study blocks. Each mirrors its Supabase table.
//
import Foundation

/// One graded resuilt., mirrors the grades table

struct Grade: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {case exam, quiz, assignment, project}

    var id = UUID()
    var courseID: UUID?
    var title: String
    var score: Double
    var max: Double
    var weight: Double
    var date: String
    var kind: Kind? = nil
    var deletedAt: Date? = nil
}

///Once lecture not or quiz note, mirrors the 'notes' table
struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var courseID: UUID?
    var date: String
    var title = ""
    var body = ""
    var assignmentID: UUID? = nil

    var updatedAt = Date()
    var deletedAt:  Date? = nil
}

/// An assignment placed on a work day. Mirrors `task_plans`.
/// Planning never touches the deadline: this date is when you'll work on it.

struct TaskPlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var assignmentID: UUID       // required: a plan is always for one assignment
    var date: String             // "yyyy-MM-dd"
    var priority: Int? = nil     // 1 to 3 when it's one of the day's top three
    var updatedAt = Date()
}
///One finished focus black. 

struct StudySession: Identifiable, Codable, Hashable {
    //which timer recorded it

    enum Mode: String, Codable {case timer, pomodoro}

    var id = UUID()
    var assignmentID: UUID?
    var courseID: UUID?
    var minutes: Int             // 1 to 240
    var completedAt: Date        // an instant: when the block finished
    var mode = Mode.timer
}
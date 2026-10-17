//
//  File:    ~/ClassPing/Sources/ClassPing/Models.swift
//  Phase:   5a (ClassMeeting moved into Logic; Course adopts Schedulable)
//  Ports:   docs/SCHEMA.md, lib/supabase/map.ts (classes and tasks rows)
//
//  Summary: The two core data types: a Course (one class you take) and an
//           Assignment (one piece of work). Meeting helpers live in Logic/.
//

import Foundation
/// One class taken mirrors the 'classes' table in supabase for sync
/// Identifiable: lists can tell items apart, Codable: saved as JSON
/// Hashable can be compared and stored in sets
/// The nine subject colors, by name. The web app stores the name ("teal"), not a
/// hex code, so the same name works in light and dark mode and syncs as-is.
enum SubjectColor: String, Codable, CaseIterable {
    case amber, indigo, coral, teal, pink, violet, mint, ocean, slate
}

// ClassMeeting lives beside its validation helpers in Logic/ClassMeetings.swift.
///Identifiable means: Lists can tell items apart
/// Codable means: Saved as JSON
/// Hashable: can be compared and stored in sets
struct Course: Identifiable, Codable, Hashable {
    var id = UUID()  //a unique ID made automatically
    var name: String //Course names 'Machine Learning'
    var short: String // "ML" 
    var color: SubjectColor // stored subject color name
    var days: [Int] // meeting days 0 = Monday .... 6 = Sunday 
    var additionalMeetings: [ClassMeeting] = []
    
    //Reminders Before class
    var startMin: Int //min from midnight 600= 10:00am
    var endMin: Int 
    var remindBefore = 10
    var alarm = true
    var extraReminders: [Int] = []
    // Details. `String?` means "a String, or nothing": a class may have no room yet
    var credits: Double? = nil
    var room: String? = nil
    var instructor: String? = nil
    var notes: String? = nil
    var term: String? = nil
    var archived = false
    var goal: Double? = nil

    // Optional provenance preserves compatibility with existing saved courses.
    var sourceFeed: String? = nil
    var sourceUID: String? = nil
    var sourceHash: String? = nil

    //When it was moved to Recently deleted, Nothing means its live
    //Deleting only sets this, so it can be restored for 30 days

    var deletedAt: Date? = nil

}

/// Lets the week helpers read a course’s primary and additional meetings.
extension Course: Schedulable {}

struct Subtask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var done = false
}

///One assignemnt, quiz or exam. Mirrors the task tables in Supabase
struct Assignment: Identifiable, Codable, Hashable {
    ///The Kinds of work Classping tracks. String raw values saves as plain text
    enum Kind: String, Codable, CaseIterable {case assignment, quiz, exam, reminder}

    var subtasks: [Subtask] = []

    var snoozedUntil: Date? = nil

    ///How a task repeats once its completed
    enum RepeatRule: String, Codable, CaseIterable {case weekly, monthly}

    var id = UUID()
    var courseID: UUID? //can be empty
    var title: String

    // The deadline: local wall-clock time, never an instant.
    //   due nil                -> undated (Inbox)
    //   due set, dueTime nil   -> all-day (never pretend it's 23:59)
    //   due set, dueTime set   -> exact time
    var due: String?
    var dueTime: String? = nil

    var kind = Kind.assignment         // a plain assignment unless you pick another kind
    var reminder = false               // "nudge me until it's done", daily from 24 h out
    var done = false                   // on screen this is "Complete" / "Completed"

    var notes: String? = nil
    
    var remindLeads: [Int] = []

    var repeatRule: RepeatRule? = nil
    var repeatUntil: String? = nil
    var recurrenceParentID: UUID? = nil

    var sourceFeed: String? = nil
    var sourceUID: String? = nil
    var sourceHash: String? = nil

    var deletedAt: Date? = nil
    }

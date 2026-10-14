import Foundation
/// One class taken mirrors the 'classes' table in supabase for sync
/// Identifiable: lists can tell items apart, Codable: saved as JSON
/// Hashable can be compared and stored in sets

struct Course: Identifiable, Codable, Hashable {
    var id = UUID()  //a unique ID made automatically
    var name: String //Course names 'Machine Learning'
    var short: String // "ML" 
    var color: String // hex color code
    var days: [Int] // meeting days 0 = Monday .... 6 = Sunday 
    var startMin: Int //min from midnight 600= 10:00am
    var endMin: Int 
    var remindBefore = 10
    var alarm = true
    var room: String? = nil
}

///One assignemnt, quiz or exam. Mirrors the task tables in Supabase
struct Assignment: Identifiable, Codable, Hashable {
    ///The Kinds of work Classping tracks. String raw values saves as plain text
    enum Kind: String, Codable {case assignment, quiz, exam, reminder}

    var id = UUID()
    var courseID: UUID? //can be empty
    var title: String
    var due: String
    var dueTime: String? = nil
    var kind = Kind.assignment //a plain assignemnt unless user picks another kind
    var reminder = false
    var done = false
}
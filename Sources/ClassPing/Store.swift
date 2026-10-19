//
//  File:    ~/ClassPing/Sources/ClassPing/Store.swift
//  Ports:   lib/store.tsx (the shared state) and the sample week from your designs
//
//  Summary: The one place the app's data lives while it runs, plus a sample
//           store to show until you add your own classes. Since 7c it also
//           holds where a tapped notification wants to take you.
//


import Foundation
import Observation

/// The single place your app's data lives while it runs.
/// @Observable: any screen showing this data redraws by itself when it changes.
/// @MainActor: only used from the main (UI) thread, which Swift 6 checks for you.
@MainActor @Observable
final class Store {
    var courses: [Course] = []           // every class you take
    var assignments: [Assignment] = []   // every assignment, open or done
    var grades: [Grade] = []             // NEW in Phase 1
    var notes: [Note] = []               // NEW in Phase 1
    var taskPlans: [TaskPlan] = []       // NEW in Phase 1
    var studySessions: [StudySession] = [] // NEW in Phase 1
    var profile = Profile()

    /// True when the last save to the phone failed. The screens must say so,
    /// because "Saved on this device" has to be true when the app claims it.
    var lastSaveFailed = false           // NEW in Phase 1

    /// The latest assignment or class deletion, available to undo this session.
    var pendingUndo: PendingUndo? = nil

    /// Where the app should go next: set by a tapped notification or by
    /// Today's "Log it", taken by RootView, which goes there and sets it back
    /// to nil. Never saved: a tap is about now, not the next launch.
    var route: AppRoute? = nil           // NEW in Phase 7c
}

extension Store {
    /// A store filled with the classes and assignments from your design screens 02 and 06.
    /// The app uses it until you add your own. End times are made up.
    static var sample: Store {
        // Times are minutes from midnight: 510 = 8:30 AM, 560 = 9:20 AM.
        // CHANGED in Phase 1: colors are names now, not hex codes.
        let calc = Course(name: "Calculus III", short: "Calc", color: .coral,
                          days: [0, 2, 4], startMin: 510, endMin: 560)
        let ml = Course(name: "Foundations of Machine Learning", short: "ML", color: .indigo,
                        days: [0, 2], startMin: 600, endMin: 680, remindBefore: 15, room: "Friend 101")
        let poli = Course(name: "Modern Political Theory", short: "Poli", color: .teal,
                          days: [0, 2], startMin: 810, endMin: 885)
        let ochem = Course(name: "Organic Chemistry II", short: "OChem", color: .ocean,
                           days: [1, 3], startMin: 540, endMin: 615)
        let psych = Course(name: "Introduction to Psychology", short: "Psych", color: .amber,
                           days: [1, 3], startMin: 900, endMin: 975)


        let store = Store()
        store.courses = [calc, ml, poli, ochem, psych]
        // Each assignment points at its class through that class's id.
        store.assignments = [
            Assignment(courseID: ochem.id, title: "Lab report: Aldol condensation", due: day(1)),
            Assignment(courseID: ml.id, title: "Problem Set 4", due: day(2)),
            Assignment(courseID: poli.id, title: "Reading response: Rawls, Ch. 3", due: day(3), reminder: true),
            Assignment(courseID: calc.id, title: "Midterm study guide", due: day(-2), done: true),
            Assignment(courseID: psych.id, title: "Reflection journal", due: day(-1), done: true),
            // NEW in Phase 1: an exam with an exact time, and an undated Inbox item.
            Assignment(courseID: calc.id, title: "Midterm 2", due: day(5), dueTime: "10:00", kind: .exam),
            Assignment(title: "Email advisor about spring classes"),
        ]
        return store
    }

    /// The date `offset` days from today, as "yyyy-MM-dd": day(1) is tomorrow, day(-1) yesterday.
    private static func day(_ offset: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   // same format whatever your phone's language
        f.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        return f.string(from: date)
    }
}

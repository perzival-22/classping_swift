//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Import.swift
//  Phase:   13a (import a calendar or schedule file)
//  Ports:   importItems in lib/store.tsx; the term question's test
//           (shouldOfferTerm in components/ImportCalendar.tsx) and its
//           writes (components/TermSetupSheet.tsx)
//
//  Summary: Turns what an import found into real classes and assignments once
//           you confirm, in one save, and answers the "When does your
//           semester run?" question. Like the other actions since 9a, a
//           change only counts once planner.json has it.
//

import Foundation

extension Course {
    /// A class made from an import candidate (Logic/ICSImport.swift). A color
    /// name the app doesn't know becomes indigo. `init` in an extension keeps
    /// the memberwise `Course(name:short:...)` working too.
    init(imported c: ImportedClass) {
        self.init(name: c.name, short: c.short, color: SubjectColor(rawValue: c.color) ?? .indigo,
                  days: c.days, additionalMeetings: c.additionalMeetings,
                  startMin: c.start, endMin: c.end, remindBefore: c.remindBefore, alarm: c.alarm,
                  credits: c.credits, room: c.room, instructor: c.instructor,
                  sourceUID: c.sourceUID)
    }
}

extension Assignment {
    /// An assignment made from an import candidate, filed under `courseID`
    /// (nil for the Inbox), with its reminder on, as every import's is.
    init(imported t: ImportedTask, courseID: UUID?) {
        self.init(courseID: courseID, title: t.title, due: t.due, dueTime: t.dueTime,
                  kind: Assignment.Kind(rawValue: t.kind) ?? .assignment,
                  reminder: true, sourceUID: t.sourceUID)
    }
}

extension Store {
    // MARK: - Adding an import

    /// Adds every class and assignment you confirmed, each with a new id, in
    /// one save. `importItems` in lib/store.tsx. A calendar file's deadlines
    /// rarely name their class, so, like the web, they're filed under the
    /// first class this import added, which gives them a color and a home;
    /// with no class in the import they go to the Inbox. Gives back false,
    /// and changes nothing, when the save fails. (The web's XP for an import
    /// arrives with Phase 12.)
    @discardableResult
    func importItems(_ newClasses: [ImportedClass], _ newTasks: [ImportedTask]) -> Bool {
        let added = newClasses.map { Course(imported: $0) }
        let home = added.first?.id
        let work = newTasks.map { Assignment(imported: $0, courseID: home) }

        // Keep the lists as they were, to put back if the save fails.
        let before = (courses, assignments)
        courses += added
        assignments += work
        save()
        if lastSaveFailed {
            (courses, assignments) = before
            return false
        }
        return true
    }

    // MARK: - The term question

    /// True when the "When does your semester run?" sheet should follow an
    /// import or your first class: no classes yet, never asked, and no
    /// semester days set. The web's `shouldOfferTerm`. Read it BEFORE adding,
    /// since adding makes the planner non-empty.
    var shouldOfferTermSetup: Bool {
        liveCourses.isEmpty && !profile.termSetupPrompted
            && profile.termStart == nil && profile.termEnd == nil
    }

    /// The sheet's answer. With both days ("yyyy-MM-dd") it sets the semester;
    /// with none (Not now) it only records that you were asked. Either way it
    /// never asks again; Profile's Semester card changes the days later.
    /// A day that isn't real is refused; the sheet checks the order.
    @discardableResult
    func finishTermSetup(start: String? = nil, end: String? = nil) -> Bool {
        if let start, !isValidDate(start) { return false }
        if let end, !isValidDate(end) { return false }
        let before = profile
        profile.termSetupPrompted = true
        if let start, let end {
            profile.termStart = start
            profile.termEnd = end
        }
        save()
        if lastSaveFailed {
            profile = before
            return false
        }
        return true
    }
}

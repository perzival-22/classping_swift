//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Persistence.swift
//  Phase:   1 (save and load)
//  Ports:   lib/store.tsx (the localStorage cache, key "classping.v1:<user>")
//
//  Summary: Saves everything to Documents/planner.json after each change and
//           reads it back when the app opens. A file that can't be read is set
//           aside, never overwritten, so a bug can't erase users planner.
//
import Foundation

/// Everything that gets saved, in one value. Codable turns it into JSON and back.
/// Rule for later phases: a property added here (or to any model) must be
/// Optional, or old files on the phone won't load. Optional properties that are
/// missing from the file simply come back as nil.
struct PlannerDocument: Codable {
    var courses: [Course]
    var assignments: [Assignment]
    var grades: [Grade]
    var notes: [Note]
    var taskPlans: [TaskPlan]
    var studySessions: [StudySession]
    var profile: Profile
}

extension Store {
    /// The app's private Documents folder on the phone. Deleting the app deletes
    /// this folder too, which is how you reset to the sample.
    /// `urls(for:in:)` gives back a list; `.first` takes its only entry, and
    /// `?? temporaryDirectory` is a fallback so this can never crash.
    static var documentsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Where the planner is saved.
    static var fileURL: URL {
        documentsFolder.appending(path: "planner.json")
    }

    /// Where an unreadable planner.json is moved, so nothing ever writes over it.
    static var unreadableURL: URL {
        documentsFolder.appending(path: "planner.unreadable.json")
    }

    /// The store's contents packed into one saveable value.
    var document: PlannerDocument {
        PlannerDocument(courses: courses, assignments: assignments, grades: grades,
                        notes: notes, taskPlans: taskPlans, studySessions: studySessions,
                        profile: profile)
    }

    /// Writes the planner to the phone. Call it after every change, before any
    /// network call: that's what makes "Saved on this device" honest.
    func save() {
        // Set up the encoder. Dates become text like "2026-10-13T20:00:00Z".
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // readable if you open the file

        // `try?` turns a failure into nil instead of crashing (no do/catch needed).
        // `guard let ... else` leaves the function early when encoding fails.
        guard let data = try? encoder.encode(document) else {
            lastSaveFailed = true
            return
        }

        // `.atomic` writes to a temporary file first and swaps it in, so a crash
        // mid-save can't leave half a file. The write gives back nil on failure.
        let written = (try? data.write(to: Store.fileURL, options: .atomic)) != nil
        lastSaveFailed = !written
    }

    /// Builds the store when the app opens: your saved planner if there is one,
    /// otherwise the sample.
    static func load() -> Store {
        // No file yet (first launch): start from the sample.
        guard let data = try? Data(contentsOf: fileURL) else {
            return .sample
        }

        // Read the JSON back into a PlannerDocument.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let saved = try? decoder.decode(PlannerDocument.self, from: data) else {
            // The file exists but can't be read. Treating that as "empty" is how
            // planners get wiped (the web app's backup rules say the same). Move it
            // aside first, replacing any older unreadable copy, then use the sample.
            try? FileManager.default.removeItem(at: unreadableURL)
            try? FileManager.default.moveItem(at: fileURL, to: unreadableURL)
            return .sample
        }

        // Copy each saved list into a fresh store.
        let store = Store()
        store.courses = saved.courses
        store.assignments = saved.assignments
        store.grades = saved.grades
        store.notes = saved.notes
        store.taskPlans = saved.taskPlans
        store.studySessions = saved.studySessions
        store.profile = saved.profile
        return store
    }
}
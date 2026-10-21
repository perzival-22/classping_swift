//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Backup.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/store.tsx (exportBackup, restoreBackup, preRestoreSnapshot,
//           undoRestore, dismissRestoreSnapshot, clearData) and the clear
//           summary of app/settings/page.tsx
//
//  Summary: Backing up everything to a file in the web's format, restoring
//           one (merge or replace) with an Undo, and Clear all data. Like the
//           other store actions since 9a, each one only counts once
//           planner.json has it; a failed write puts everything back.
//

import Foundation

/// A checked backup, its items read into the app's own models: what the
/// restore sheet shows and the store restores. Items a model can't read
/// (no id, a plan with no real day) are left out, as the web's checks do.
struct BackupContents: Equatable {
    var courses: [Course]
    var assignments: [Assignment]
    var grades: [Grade]
    var notes: [Note]
    var taskPlans: [TaskPlan]
    var studySessions: [StudySession]
    /// The profile values the file has, still as JSON: only those are applied.
    var profile: [String: JSONValue]
    var progress: GameBlobs
    var warnings: [String]

    /// Reads every list of a checked file. `compactMap(Course.init(web:))`
    /// runs the failable init on each item and keeps only the ones it made.
    init(_ file: BackupFile) {
        courses = file.classes.compactMap(Course.init(web:))
        assignments = file.tasks.compactMap(Assignment.init(web:))
        grades = file.grades.compactMap(Grade.init(web:))
        notes = file.notes.compactMap(Note.init(web:))
        taskPlans = onePlanPerAssignment(file.taskPlans.compactMap(TaskPlan.init(web:)))
        studySessions = file.studySessions.compactMap(StudySession.init(web:))
        profile = file.profile
        progress = file.progress
        warnings = file.warnings
    }

    /// Checks a file's bytes and reads them, or says why it can't.
    /// `Result.map` changes the success value and passes a failure straight
    /// through, so a bad file's message reaches the sheet untouched.
    static func open(_ data: Data) -> Result<BackupContents, BackupError> {
        checkBackup(data).map(BackupContents.init)
    }
}

/// One day plan per assignment, the first one winning, as the web's
/// `normalizeTaskPlans` keeps it. `insert` gives back whether the id was new,
/// so `filter` keeps an assignment's first plan and drops any later one.
private func onePlanPerAssignment(_ plans: [TaskPlan]) -> [TaskPlan] {
    var seen = Set<UUID>()
    return plans.filter { seen.insert($0.assignmentID).inserted }
}

extension Store {
    // MARK: - Backing up

    /// Everything, deleted items and progress included, as a backup file's
    /// bytes. `exportBackup` plus `JSON.stringify`. Deleted items travel too,
    /// so a restored Recently Deleted looks the way it did.
    func backupData(now: Date = .now) -> Data? {
        backupFileData(classes: courses.map(\.webJSON),
                       tasks: assignments.map(\.webJSON),
                       grades: grades.map(\.webJSON),
                       notes: notes.map(\.webJSON),
                       taskPlans: taskPlans.map(\.webJSON),
                       studySessions: studySessions.map(\.webJSON),
                       profile: profile.webBackupJSON,
                       progress: game,
                       now: now)
    }

    // MARK: - Restoring

    /// What restoring would do here, before anything moves. `planRestore`.
    /// It compares against everything on the phone, deleted items too, the
    /// same lists the restore itself changes, so the preview is the outcome.
    func restorePlan(_ backup: BackupContents, mode: RestoreMode) -> RestorePlan {
        RestorePlan(mode: mode,
                    classes: planEntity(backup.courses, courses),
                    tasks: planEntity(backup.assignments, assignments),
                    grades: planEntity(backup.grades, grades),
                    notes: planEntity(backup.notes, notes),
                    taskPlans: planEntity(backup.taskPlans, taskPlans),
                    studySessions: planEntity(backup.studySessions, studySessions),
                    restoresPreferences: !backup.profile.isEmpty,
                    restoresProgress: !backup.progress.isEmpty || !backup.studySessions.isEmpty,
                    warnings: backup.warnings)
    }

    /// Restores a backup: `restoreBackup`. Merge adds and updates, Replace
    /// makes the phone match the file. Your profile takes the file's values
    /// and progress is set to the file's, never earned again. What was here
    /// before is kept for Undo. False when the write failed: then nothing
    /// changed at all.
    @discardableResult
    func restoreBackup(_ backup: BackupContents, mode: RestoreMode) -> Bool {
        let before = document
        courses = restoreEntity(backup.courses, courses, mode)
        assignments = restoreEntity(backup.assignments, assignments, mode)
        grades = restoreEntity(backup.grades, grades, mode)
        notes = restoreEntity(backup.notes, notes, mode)
        // A merge can bring a second plan for an assignment that has one.
        taskPlans = onePlanPerAssignment(restoreEntity(backup.taskPlans, taskPlans, mode))
        studySessions = restoreEntity(backup.studySessions, studySessions, mode)
        profile.adoptBackup(backup.profile)
        game.adopt(backup.progress)
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        // Undo the restore, not a delete from before it.
        preRestore = before
        pendingUndo = nil
        return true
    }

    /// Puts back exactly what was here before the last restore. `undoRestore`.
    @discardableResult
    func undoRestore() -> Bool {
        guard let snapshot = preRestore else { return false }
        let restored = document
        replaceAll(with: snapshot)
        save()
        if lastSaveFailed {
            replaceAll(with: restored)
            return false
        }
        preRestore = nil
        return true
    }

    /// Lets the restore's Undo go. `dismissRestoreSnapshot`.
    func dismissRestoreSnapshot() {
        preRestore = nil
    }

    // MARK: - Clearing

    /// What Clear all data would erase, in words, or nil when there's nothing.
    /// Archived classes count: they're off the timetable but still yours.
    var clearSummary: String? {
        describeClear(classes: liveCourses.count, assignments: liveAssignments.count,
                      grades: liveGrades.count, notes: liveNotes.count)
    }

    /// Empties the planner and keeps your preferences. `clearData`: every
    /// class, assignment, grade and note (Recently Deleted too), day plans and
    /// study sessions, trophies, XP and the boss, plus the term it was all in.
    /// Your pet stays, as on the web: its best tier was earned for good.
    /// There's no Undo; the screen asks first.
    @discardableResult
    func clearData() -> Bool {
        let before = document
        courses = []
        assignments = []
        grades = []
        notes = []
        taskPlans = []
        studySessions = []
        game.trophies = nil
        game.xp = nil
        game.boss = nil
        profile.termStart = nil
        profile.termEnd = nil
        profile.termName = nil
        profile.termSetupPrompted = false
        profile.finalsDate = nil
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        pendingUndo = nil
        preRestore = nil
        return true
    }
}

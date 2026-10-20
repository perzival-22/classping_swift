//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Planning.swift
//  Phase:   7b (one task's reminders, and planning the work), changed in
//           10a (study sessions)
//  Ports:   lib/store.tsx (planTask, removeTaskPlan) and the updateTask calls
//           made by TaskReminderCard and ExamPrepCard in
//           components/TaskReminders.tsx
//
//  Summary: Everything the task detail's three planning cards change: the
//           reminder switch, early warnings and snooze; the exam plan's
//           checklist steps; and the day you mean to work on it. Each action
//           saves straight away, and 7a's reminder sync notices the change
//           by itself, so a snooze silences the phone within a second.
//           Since 10a it also records the study timer's finished blocks.
//

import Foundation

extension Store {
    // MARK: - Reminders

    /// Turns a task's daily nudge on or off. Off also ends any snooze, so
    /// switching back on starts fresh. The switch in TaskReminderCard.
    func setReminder(_ on: Bool, for id: UUID) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].reminder = on
        if !on { assignments[i].snoozedUntil = nil }
        save()
    }

    /// Adds or removes one early warning. `toggleLead` in TaskReminderCard.
    /// It starts from the warnings in force, so the first tap on an exam edits
    /// its default ladder instead of starting from nothing. Removing the last
    /// one leaves an empty list, which means "not chosen", so an exam gets its
    /// ladder back. The web does exactly the same.
    func toggleLead(_ minutes: Int, for id: UUID) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        var next = Set(effectiveLeads(assignments[i]))
        if next.contains(minutes) {
            next.remove(minutes)
        } else {
            next.insert(minutes)
        }
        assignments[i].remindLeads = next.sorted(by: >)
        save()
    }

    /// Puts a task down until the preset's moment: nothing about it rings
    /// before then. `snooze` in TaskReminderCard.
    func snooze(_ id: UUID, _ preset: SnoozePreset, now: Date = .now) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].snoozedUntil = snoozeUntil(preset, now)
        save()
    }

    /// Ends a snooze early. "Wake it" on the web.
    func wake(_ id: UUID) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].snoozedUntil = nil
        save()
    }

    // MARK: - Exam prep

    /// Writes the exam's plan onto its checklist, after any steps already
    /// there, and only once. `onAddSteps` in app/tasks/[id]/page.tsx.
    func addPrepSteps(to id: UUID, now: Date = .now) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        // Already carries a plan, or there's nothing left to plan: no change.
        guard !hasPrepLadder(assignments[i].subtasks.map(\.title)) else { return }
        let steps = prepLadder(assignments[i].due, now)
        guard !steps.isEmpty else { return }
        // `+=` adds the new rows to the end of the checklist.
        assignments[i].subtasks += steps.map { Subtask(title: $0.title) }
        save()
    }

    /// Minutes of focused work recorded against a task. The detail's
    /// "Focused" row, `studyMinutes(studySessions, { taskId })` on the web.
    func focusedMinutes(_ id: UUID) -> Int {
        studyMinutes(studySessions, taskID: id)
    }

    // NEW in Phase 10a
    /// Records one finished focus block: `addStudySession` in lib/store.tsx.
    /// Minutes are kept between 1 and 240, as the web does. `completedAt` is
    /// when the block really ended, which can be a while before the phone
    /// noticed (D-62). Unlike a grade, nothing rolls back if the write fails:
    /// there's no form to retry from, so the session stays in memory, the
    /// screen shows the save-failure line, and the next save that works keeps it.
    func addStudySession(minutes: Int, assignmentID: UUID?, courseID: UUID?,
                         mode: StudySession.Mode, completedAt: Date = .now) {
        studySessions.append(StudySession(assignmentID: assignmentID, courseID: courseID,
                                          minutes: min(240, max(1, minutes)),
                                          completedAt: completedAt, mode: mode))
        save()
    }

    // MARK: - Planning the work

    /// The day a task is planned for, if it has one. A task has at most one.
    func taskPlan(for id: UUID) -> TaskPlan? {
        taskPlans.first(where: { $0.assignmentID == id })
    }

    /// Plans a task onto a work day, or moves its plan there. `planTask` in
    /// lib/store.tsx. Moving clears any "top three" priority (the web does
    /// too). The deadline is never touched: this is when, not by when.
    func planTask(_ id: UUID, on date: String) {
        guard isValidDate(date) else { return }
        if let i = taskPlans.firstIndex(where: { $0.assignmentID == id }) {
            taskPlans[i].date = date
            taskPlans[i].priority = nil
            taskPlans[i].updatedAt = .now
        } else {
            taskPlans.append(TaskPlan(assignmentID: id, date: date))
        }
        save()
    }

    /// Takes a task off its work day. `removeTaskPlan` in lib/store.tsx.
    func removeTaskPlan(_ id: UUID) {
        taskPlans.removeAll(where: { $0.assignmentID == id })
        save()
    }
}

// PlanningStoreTests.swift: the store actions behind the task detail's
// planning cards (Phase 7b): reminder switch, early warnings, snooze, the exam
// plan on the checklist, and the day plan, each saved and read back.
// Run: scripts/test-store.sh (uses an isolated planner file).
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct PlanningStoreTests {
    /// A store with nothing saved yet.
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    /// An exam 10 days from now, so the whole ladder is still ahead.
    private func exam(_ store: Store) -> Assignment {
        let a = Assignment(title: "Physics final", due: dayOf(scheduleDate(.now, 10)),
                           dueTime: "09:00", kind: .exam, reminder: true)
        store.addAssignment(a)
        return a
    }

    @Test func plansMovesAndRemovesAWorkDayWithoutTouchingTheDeadline() {
        let store = freshStore()
        let a = exam(store)
        store.planTask(a.id, on: "2026-09-15")
        let first = store.taskPlan(for: a.id)
        #expect(first?.date == "2026-09-15")

        // Moving keeps the one plan (same id) and clears any priority.
        store.taskPlans[0].priority = 2
        store.planTask(a.id, on: "2026-09-16")
        #expect(store.taskPlans.count == 1)
        #expect(store.taskPlan(for: a.id)?.id == first?.id)
        #expect(store.taskPlan(for: a.id)?.priority == nil)
        #expect(Store.load().taskPlan(for: a.id)?.date == "2026-09-16")
        #expect(store.assignment(a.id)?.due == a.due)

        // A broken day is refused; Remove takes it off.
        store.planTask(a.id, on: "tomorrow")
        #expect(store.taskPlan(for: a.id)?.date == "2026-09-16")
        store.removeTaskPlan(a.id)
        #expect(Store.load().taskPlans.isEmpty)
    }

    @Test func buildsTheExamPlanOnceAfterTheStepsAlreadyThere() {
        let store = freshStore()
        let a = exam(store)
        store.addSubtask("Email the TA", to: a.id)
        store.addPrepSteps(to: a.id)
        store.addPrepSteps(to: a.id)   // a second tap changes nothing
        let titles = Store.load().assignment(a.id)?.subtasks.map(\.title) ?? []
        #expect(titles.count == 6)
        #expect(titles.first == "Email the TA")
        #expect(titles.dropFirst().first?.hasPrefix("7 days before · ") == true)
    }

    @Test func editsAnExamsDefaultWarningsFromTheLadder() {
        let store = freshStore()
        let a = exam(store)
        store.toggleLead(10_080, for: a.id)
        #expect(store.assignment(a.id)?.remindLeads == [4_320, 2_880])
        store.toggleLead(10_080, for: a.id)
        #expect(Store.load().assignment(a.id)?.remindLeads == [10_080, 4_320, 2_880])

        // An empty selection means "use the defaults", including after reload.
        for minutes in [10_080, 4_320, 2_880] {
            store.toggleLead(minutes, for: a.id)
        }
        let loaded = Store.load().assignment(a.id)
        #expect(loaded?.remindLeads == [])
        #expect(loaded.map(effectiveLeads) == [10_080, 4_320, 2_880])
    }

    @Test func snoozesWakesAndClearsTheSnoozeWhenSwitchedOff() {
        let store = freshStore()
        let a = exam(store)
        let now = Date.now
        store.snooze(a.id, .threeHours, now: now)
        // planner.json keeps whole seconds (ISO 8601), so compare to the second.
        let saved = Store.load().assignment(a.id)?.snoozedUntil
        #expect(saved.map { abs($0.timeIntervalSince(snoozeUntil(.threeHours, now))) < 1 } == true)
        store.wake(a.id)
        #expect(store.assignment(a.id)?.snoozedUntil == nil)

        store.snooze(a.id, .tomorrow, now: now)
        store.setReminder(false, for: a.id)
        let off = Store.load().assignment(a.id)
        #expect(off?.reminder == false)
        #expect(off?.snoozedUntil == nil)
    }

    @Test func totalsFocusedMinutesForOneTaskOnly() {
        let store = freshStore()
        let a = exam(store)
        store.studySessions = [
            StudySession(assignmentID: a.id, minutes: 25, completedAt: .now),
            StudySession(assignmentID: UUID(), minutes: 50, completedAt: .now),
            StudySession(minutes: 15, completedAt: .now),
        ]
        #expect(store.focusedMinutes(a.id) == 25)
        store.save()
        #expect(Store.load().focusedMinutes(a.id) == 25)
    }

    @Test func reminderActionsChangeThePersistedNotificationPlan() {
        let store = freshStore()
        let now = Calendar.current.date(from: DateComponents(
            year: 2026, month: 10, day: 18, hour: 12))!
        let a = Assignment(title: "Essay", due: dayOf(scheduleDate(now, 3)),
                           dueTime: "14:00", reminder: true)
        store.addAssignment(a)

        // Exercise the same planner the iOS sync reads, using saved real models.
        func reminders() -> [PlannedReminder] {
            let loaded = Store.load()
            return reminderPlan(courses: loaded.liveCourses, tasks: loaded.liveAssignments,
                                postClass: false, quiet: nil, fired: [], now: now)
        }

        #expect(!reminders().contains { $0.kind == .taskLead })
        store.toggleLead(4_320, for: a.id)
        let awake = reminders()
        #expect(awake.first { $0.kind == .taskLead }?.firstDate == atMinute(now, 14 * 60))
        #expect(awake.contains { $0.kind == .taskNag })

        store.snooze(a.id, .threeHours, now: now)
        let until = snoozeUntil(.threeHours, now)
        #expect(!reminders().isEmpty)
        #expect(reminders().allSatisfy { $0.firstDate >= until })
        #expect(reminders().first { $0.kind == .taskLead }?.firstDate == until)
        store.wake(a.id)
        #expect(reminders() == awake)
        store.setReminder(false, for: a.id)
        #expect(reminders().isEmpty)
        store.setReminder(true, for: a.id)
        #expect(reminders() == awake)
    }

    @Test func completeAndReopenKeepTheExamStepsPlanAndSnooze() {
        let store = freshStore()
        let now = Calendar.current.date(from: DateComponents(
            year: 2026, month: 10, day: 18, hour: 12))!
        let a = Assignment(title: "Final", due: dayOf(scheduleDate(now, 6)),
                           kind: .exam, reminder: true)
        store.addAssignment(a)
        store.addSubtask("Ask about chapter 4", to: a.id)
        store.addPrepSteps(to: a.id, now: now)
        let next = nextPrepDate(prepLadder(a.due, now), now)!
        store.planTask(a.id, on: next)
        store.snooze(a.id, .tomorrow, now: now)
        let planned = Store.load().taskPlan(for: a.id)
        let prepared = store.assignment(a.id)
        #expect(prepared?.subtasks.count == 5) // Existing step plus four reachable rungs.

        store.toggleAssignment(a.id)
        let completed = Store.load()
        #expect(completed.assignment(a.id)?.done == true)
        #expect(completed.assignment(a.id)?.subtasks == prepared?.subtasks)
        #expect(completed.taskPlan(for: a.id) == planned)

        completed.toggleAssignment(a.id)
        let reopened = Store.load()
        #expect(reopened.assignment(a.id) == prepared)
        #expect(reopened.taskPlan(for: a.id) == planned)
        reopened.addPrepSteps(to: a.id, now: now)
        #expect(reopened.assignment(a.id)?.subtasks == prepared?.subtasks)
    }
}

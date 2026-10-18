//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/PlanningCards.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   ExamPrepCard in components/TaskReminders.tsx, and the "Plan the
//           work" section of app/tasks/[id]/page.tsx
//
//  Summary: The two cards on a task's detail that plan when you'll work on
//           it. Exam prep counts back from an exam: a five-step plan for the
//           checklist, minutes focused against minutes planned, and a button
//           to plan the next session. Plan the work puts any task on a day
//           of your choosing without touching its deadline.
//

import SwiftUI

// MARK: - Exam prep

struct ExamPrepCard: View {
    @Environment(Store.self) private var store

    /// The exam, freshly looked up by the detail screen. Always dated: the
    /// detail only shows this card for an exam with a date (D-32).
    let assignment: Assignment

    var body: some View {
        // Recompute reachable steps and days left if this screen stays open overnight.
        TimelineView(.everyMinute) { context in
            content(context.date)
        }
    }

    /// The exam's remaining plan and progress at the current local day.
    private func content(_ now: Date) -> some View {
        let a = assignment
        let accent = store.profile.accent
        let steps = prepLadder(a.due, now)
        let progress = prepProgress(examID: a.id, examDate: a.due,
                                    sessions: store.studySessions, now: now)
        let built = hasPrepLadder(a.subtasks.map(\.title))
        let next = nextPrepDate(steps, now)
        let planned = store.taskPlan(for: a.id)?.date

        return VStack(alignment: .leading, spacing: 12) {
            if steps.isEmpty {
                // Today or already sat: nothing left to plan. Saying so beats
                // an empty card that looks like something failed to load.
                cardLabel("Exam prep")
                Text(progress.daysLeft == 0
                     ? "It's today. \(progress.logged > 0 ? "\(progress.logged) minutes logged." : "Good luck.")"
                     : "This exam has passed.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    cardLabel("Exam prep")
                    Spacer()
                    Text("\(progress.daysLeft) day\(progress.daysLeft == 1 ? "" : "s") to go")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted2)
                }

                Text(built
                     ? "\(steps.count) session\(steps.count == 1 ? "" : "s") left on your plan, \(minutesPerStep) minutes each."
                     : "A \(steps.count)-step plan working back from the exam, \(minutesPerStep) minutes a session.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                // Logged against planned, as a bar: "am I behind?" is a
                // shape, not a total. `ProgressView(value:)` draws a bar
                // filled to `value`, from 0 (empty) to 1 (full).
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress.ratio)
                        .tint(Theme.brand(accent))
                    Text("\(progress.logged) of \(progress.target) minutes focused")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }

                HStack(spacing: 8) {
                    // Write the steps onto the checklist, once.
                    if !built {
                        Button {
                            store.addPrepSteps(to: a.id, now: now)
                        } label: {
                            Text("Build the plan")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(Theme.brandGradient(accent),
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    // Plan the next session, unless the plan is already on that day.
                    if let next, planned != next {
                        Button {
                            store.planTask(a.id, on: next)
                        } label: {
                            Text("Study on \(shortDay(next))")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.brand(accent))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(Theme.brandSoft(accent),
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if built {
                    Text("The steps are on the checklist below, tick them off as you go.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "Sep 15" for a "2026-09-15" day. The web writes "09/15"; the phone
    /// writes dates the way it does everywhere else.
    private func shortDay(_ day: String) -> String {
        deadlineDayStart(Deadline(date: day, time: nil)).map(fmtMD) ?? day
    }
}

// MARK: - Plan the work

struct PlanWorkCard: View {
    @Environment(Store.self) private var store

    /// The task, freshly looked up by the detail screen.
    let assignment: Assignment

    /// The day in the picker, as "yyyy-MM-dd". The card's own scratch value
    /// (a child view with its own state, 6a): nothing is planned until you
    /// tap Plan or Move.
    @State private var day: String

    /// Starts the picker on the planned day, or today. `@State` set from
    /// `init` through `_day` (4a), as the web's `useState(existingPlan?.date ?? today)`.
    init(assignment: Assignment, plannedDay: String?) {
        self.assignment = assignment
        _day = State(initialValue: plannedDay ?? dayOf(.now))
    }

    var body: some View {
        let accent = store.profile.accent
        let plan = store.taskPlan(for: assignment.id)

        VStack(alignment: .leading, spacing: 10) {
            cardLabel("Plan the work")
            Text("Pick when you want to work on this. Its deadline stays unchanged.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                // A date-only picker. It works in Dates; the plan stores a
                // "yyyy-MM-dd" day, so the binding converts both ways.
                DatePicker("Work day", selection: dayBinding, displayedComponents: .date)
                    .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    store.planTask(assignment.id, on: day)
                } label: {
                    Text(plan == nil ? "Plan" : "Move")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.brand(accent))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Theme.brandSoft(accent),
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let plan {
                Button("Remove from \(longDeadline(Deadline(date: plan.date, time: nil)))") {
                    store.removeTaskPlan(assignment.id)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.muted2)
                .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // "Study on" changes the plan from the other card. State's initial
        // value only runs once, so keep the picker on the newly planned day.
        .onChange(of: plan?.date) { _, plannedDay in
            if let plannedDay { day = plannedDay }
        }
    }

    /// The picker's Date, made from and written back to `day`. Local
    /// midnight of the stored day in; just the day part out (`dayOf`).
    private var dayBinding: Binding<Date> {
        Binding(get: { deadlineDayStart(Deadline(date: day, time: nil)) ?? .now },
                set: { day = dayOf($0) })
    }
}

// MARK: - Shared

/// The small capital-letter label at the top of both cards. `private` at the
/// top level of a file means "only this file can see it", so both cards share
/// it without adding a name to the rest of the app.
private func cardLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(Theme.faint)
}

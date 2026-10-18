//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ExamPrep.swift
//  Phase:   7b (one task's reminders, and planning the work)
//  Ports:   lib/exam-prep.ts (the whole file)
//
//  Summary: Turns an exam's date into a plan for the week before it: up to
//           five dated steps, each with something specific to do, counted back
//           from the exam. The steps become lines on the exam's own checklist,
//           so there's nothing new to store or sync. Also measures how the
//           preparation is going. Foundation only, for the Linux tests.
//

import Foundation

/// One rung of the ladder before it's pinned to a date.
private struct StepTemplate {
    let daysBefore: Int
    let focus: String
}

/// The ladder, furthest from the exam first. Five steps rather than seven: a
/// plan a student finishes beats one that's honest about how much revision is
/// possible. The gaps shrink near the exam, because those days get used.
/// `LADDER` in lib/exam-prep.ts.
private let ladder = [
    StepTemplate(daysBefore: 7, focus: "Gather everything, notes, slides, past papers"),
    StepTemplate(daysBefore: 5, focus: "First full pass through the material"),
    StepTemplate(daysBefore: 3, focus: "Practice questions under time"),
    StepTemplate(daysBefore: 2, focus: "Fix the weak spots that pass found"),
    StepTemplate(daysBefore: 1, focus: "Final review, formulas, definitions, dates"),
]

/// Minutes of focused work each step is meant to take. `MINUTES_PER_STEP`.
let minutesPerStep = 45

/// One step of the plan, pinned to a day. `PrepStep` in the web.
struct PrepStep: Equatable {
    let daysBefore: Int
    let date: String     // "yyyy-MM-dd", the local day it falls on
    let focus: String    // what to do that day
    let title: String    // the checklist line it becomes
}

/// Moves a "yyyy-MM-dd" day by whole days, as pure calendar days on a fixed
/// UTC calendar, so no time zone or daylight-saving change can nudge it (the
/// same way `nextRepeatDate` counts). `shiftDay` in lib/exam-prep.ts.
private func shiftDay(_ date: String, _ days: Int) -> String? {
    guard isValidDate(date) else { return nil }
    let p = date.split(separator: "-").map { Int($0) ?? 0 }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    guard let start = cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])),
          let moved = cal.date(byAdding: .day, value: days, to: start) else { return nil }
    let c = cal.dateComponents([.year, .month, .day], from: moved)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

/// The plan for an exam on `examDate`, as seen from `now`. `prepLadder`.
/// Steps already in the past are left out rather than back-dated: a plan that
/// opens with "seven days before" three days out tells the student they've
/// already failed. An exam that's today, past or undated gets nothing.
func prepLadder(_ examDate: String?, _ now: Date) -> [PrepStep] {
    guard isValidDate(examDate), let examDate else { return [] }
    let today = dayOf(now)
    // Day strings compare like dates, so this means "the exam is after today".
    guard examDate > today else { return [] }

    // `compactMap` keeps what the closure returns and drops each `nil`, so
    // the steps whose day has gone simply disappear: no loop, no skipping.
    return ladder.compactMap { step in
        guard let date = shiftDay(examDate, -step.daysBefore), date >= today else { return nil }
        let days = "\(step.daysBefore) day\(step.daysBefore == 1 ? "" : "s")"
        return PrepStep(daysBefore: step.daysBefore, date: date, focus: step.focus,
                        title: "\(days) before · \(step.focus)")
    }
}

/// Does this checklist already carry a plan? `hasPrepLadder`. Checked from
/// the line titles rather than a stored flag: the checklist is the student's
/// to edit, and a flag would keep claiming a plan after every line was deleted.
/// The web passes the task; this takes its checklist's titles.
func hasPrepLadder(_ titles: [String]) -> Bool {
    ladder.contains { step in
        titles.contains { $0.hasPrefix("\(step.daysBefore) day") && $0.contains(step.focus) }
    }
}

/// The day of the next step still ahead (or today), or nil. `nextPrepDate`:
/// where "Study on ..." plans the next session.
func nextPrepDate(_ steps: [PrepStep], _ now: Date) -> String? {
    let today = dayOf(now)
    return steps.first(where: { $0.date >= today })?.date
}

/// How the preparation is going. `PrepProgress` in the web.
struct PrepProgress: Equatable {
    /// Whole days from today to the exam. Negative once it has passed.
    var daysLeft: Int
    /// Minutes of focused work recorded against this exam.
    var logged: Int
    /// Minutes the steps still ahead are meant to take.
    var target: Int
    /// 0 to 1. Exactly 1 when the target is met or nothing is left to do.
    var ratio: Double
}

/// Time left, time logged, and what the plan asks for. `prepProgress`. The
/// target counts only the steps still ahead: measuring against steps that
/// can no longer be climbed would report failure for time that simply passed.
/// The web takes the task; this takes its id and date.
func prepProgress<S: StudyRecord>(examID: UUID, examDate: String?,
                                  sessions: [S], now: Date) -> PrepProgress {
    let target = prepLadder(examDate, now).count * minutesPerStep
    let logged = studyMinutes(sessions, taskID: examID)
    // Days between two calendar days: their day numbers (Time.swift) apart.
    let daysLeft: Int
    if let examDate, let exam = dayNumber(examDate) {
        daysLeft = exam - todayNumber(now)
    } else {
        daysLeft = 0
    }
    // `min(1, max(0, ...))` holds the ratio between 0 and 1.
    let ratio = target == 0 ? 1 : min(1, max(0, Double(logged) / Double(target)))
    return PrepProgress(daysLeft: daysLeft, logged: logged, target: target, ratio: ratio)
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Reminders.swift
//  Phase:   7a (reminders ring), changed in 7b (StudySession)
//  Ports:   nothing new: it connects the models to Logic/Reminders.swift,
//           Logic/ReminderPlan.swift and, since 7b, Logic/Planning.swift
//
//  Summary: Signs Course and Assignment up for the reminder logic, and
//           StudySession for the study-minute totals. Each already has every
//           field its protocol asks for, so the extensions are empty, like
//           `extension Assignment: Dated {}`.
//

import Foundation

/// Course has a name, `alarm`, `remindBefore` and `archived`, plus the
/// meetings `Schedulable` already covers, so the planner can read it.
extension Course: Alarmable {}

/// Assignment has `id`, `reminder`, `done`, `remindLeads` and
/// `snoozedUntil`, and is already `TaskListable` (Assignment+TaskView.swift).
extension Assignment: Remindable {}

/// StudySession has `assignmentID`, `courseID`, `minutes` and `completedAt`,
/// so `studyMinutes` can total real sessions. (They start arriving with the
/// study timer in Phase 10; until then every total is 0.)
// NEW in Phase 7b
extension StudySession: StudyRecord {}

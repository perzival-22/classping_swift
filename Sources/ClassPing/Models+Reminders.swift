//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Reminders.swift
//  Phase:   7a (reminders ring)
//  Ports:   nothing new: it connects the models to Logic/Reminders.swift and
//           Logic/ReminderPlan.swift
//
//  Summary: Signs Course and Assignment up for the reminder logic. Both
//           already have every field the protocols ask for, so the
//           extensions are empty, like `extension Assignment: Dated {}`.
//

import Foundation

/// Course has a name, `alarm`, `remindBefore` and `archived`, plus the
/// meetings `Schedulable` already covers, so the planner can read it.
extension Course: Alarmable {}

/// Assignment has `id`, `reminder`, `done`, `remindLeads` and
/// `snoozedUntil`, and is already `TaskListable` (Assignment+TaskView.swift).
extension Assignment: Remindable {}

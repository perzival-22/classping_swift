//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Backup.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   the item shapes of lib/store.tsx (ClassItem, TaskItem,
//           GradeItem, Profile), lib/notes.ts (NoteItem) and lib/planning.ts
//           (TaskPlan, StudySession), with the checks of normalizeTask,
//           normalizeNotes, normalizeTaskPlans and normalizeStudySessions
//
//  Summary: Teaches each model to write itself the way the web's backup file
//           does, and to read itself back from one. The web keeps its own
//           names (`start` not `startMin`, `classId` "" for the Inbox,
//           moments in milliseconds), so this is where the two meet (D-73).
//           Lives outside Logic/ because it needs the models.
//

import Foundation

// MARK: - Small helpers for this file

/// A link to another item: nil for "" or missing (the web's Inbox ""),
/// otherwise its UUID. `private` keeps these to this file.
private func link(_ value: JSONValue?) -> UUID? {
    uuid(fromWebID: value?.stringValue)
}

/// How a link is written: the id, or "" for none, as the web's `classId` is.
private func linkJSON(_ id: UUID?) -> JSONValue {
    .string(id.map(webID) ?? "")
}

/// The whole numbers in a list, skipping anything else.
private func ints(_ value: JSONValue?) -> [Int] {
    (value?.arrayValue ?? []).compactMap(\.intValue)
}

/// A number rounded to a whole one, the web's `Math.round(Number(v))`.
/// `Int(exactly:)` is nil for a number too big for an Int, so a silly value
/// in a file can't crash the app.
private func roundedInt(_ value: JSONValue?) -> Int? {
    value?.numberValue.flatMap { Int(exactly: $0.rounded()) }
}

/// A moment as the file writes it: whole milliseconds.
private func millis(_ date: Date) -> JSONValue {
    .number(webMillis(date))
}

/// A moment read back from milliseconds, to the whole second like `webDate`
/// (D-73), or 1970 when it's missing (the web's `typeof v === "number" ? v : 0`).
private func moment(_ value: JSONValue?) -> Date {
    Date(timeIntervalSince1970: ((value?.numberValue ?? 0) / 1000).rounded(.down))
}

// MARK: - Classes

extension Course: BackupItem {
    /// This class as the web's `ClassItem`. Optional details are left out
    /// when they're empty, the way the web's own file leaves them out.
    var webJSON: JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(webID(id)),
            "name": .string(name),
            "short": .string(short),
            "color": .string(color.rawValue),
            "days": .array(days.map(JSONValue.int)),
            "additionalMeetings": .array(additionalMeetings.map(\.webJSON)),
            "start": .int(startMin),
            "end": .int(endMin),
            "remindBefore": .int(remindBefore),
            "alarm": .bool(alarm),
            "reminders": .array(extraReminders.map(JSONValue.int)),
        ]
        object["credits"] = credits.map(JSONValue.number)
        object["room"] = room.map(JSONValue.string)
        object["instructor"] = instructor.map(JSONValue.string)
        object["notes"] = notes.map(JSONValue.string)
        object["term"] = term.map(JSONValue.string)
        if archived { object["archived"] = .bool(true) }
        object["goal"] = goal.map(JSONValue.number)
        object["sourceFeed"] = sourceFeed.map(JSONValue.string)
        object["sourceUid"] = sourceUID.map(JSONValue.string)
        object["sourceHash"] = sourceHash.map(JSONValue.string)
        object["deletedAt"] = deletedAt.map(millis)
        return .object(object)
    }

    /// A class read from a backup, or nil without an id. `init?` can fail:
    /// it gives back nil instead of a class. The web takes a class as the file
    /// has it; missing pieces get the same defaults as a new class here.
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue) else { return nil }
        // Days 0 (Mon) to 6 (Sun), each once. `for … where` visits only the
        // values that pass, so there's nothing to skip by hand.
        var days: [Int] = []
        for day in ints(v["days"]) where (0...6).contains(day) && !days.contains(day) {
            days.append(day)
        }
        // An initializer in an extension can hand over to the memberwise one,
        // then fill in the rest of the fields one by one.
        self.init(id: id,
                  name: v["name"]?.stringValue ?? "",
                  short: v["short"]?.stringValue ?? "",
                  color: SubjectColor(rawValue: v["color"]?.stringValue ?? "") ?? .indigo,
                  days: days,
                  startMin: v["start"]?.intValue ?? 0,
                  endMin: v["end"]?.intValue ?? 0)
        additionalMeetings = v["additionalMeetings"].flatMap(meetingsFromWeb) ?? []
        remindBefore = v["remindBefore"]?.intValue ?? 10
        alarm = v["alarm"]?.boolValue ?? true
        extraReminders = ints(v["reminders"])
        credits = v["credits"]?.numberValue
        room = v["room"]?.stringValue
        instructor = v["instructor"]?.stringValue
        notes = v["notes"]?.stringValue
        term = v["term"]?.stringValue
        archived = v["archived"]?.boolValue ?? false
        goal = v["goal"]?.numberValue
        sourceFeed = v["sourceFeed"]?.stringValue
        sourceUID = v["sourceUid"]?.stringValue
        sourceHash = v["sourceHash"]?.stringValue
        deletedAt = webDate(v["deletedAt"])
    }
}

// MARK: - Assignments

extension Subtask {
    /// One checklist step as the web writes it: `{ id, title, done }`.
    var webJSON: JSONValue {
        .object(["id": .string(webID(id)), "title": .string(title), "done": .bool(done)])
    }

    /// A step from a file: it needs an id and a title. `normalizeTask`.
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue),
              let title = v["title"]?.stringValue else { return nil }
        self.init(id: id, title: String(title.prefix(200)), done: v["done"]?.boolValue == true)
    }
}

extension Assignment: BackupItem {
    /// This assignment as the web's `TaskItem`: `classId` is "" for the
    /// Inbox, and the deadline is the two fields, `null` when unset.
    var webJSON: JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(webID(id)),
            "title": .string(title),
            "classId": linkJSON(courseID),
            "due": due.map(JSONValue.string) ?? .null,
            "dueTime": dueTime.map(JSONValue.string) ?? .null,
            "reminder": .bool(reminder),
            "done": .bool(done),
            "kind": .string(kind.rawValue),
        ]
        object["notes"] = notes.map(JSONValue.string)
        if !remindLeads.isEmpty { object["remindLeads"] = .array(remindLeads.map(JSONValue.int)) }
        object["snoozedUntil"] = snoozedUntil.map(millis)
        if !subtasks.isEmpty { object["subtasks"] = .array(subtasks.map(\.webJSON)) }
        object["repeat"] = repeatRule.map { .string($0.rawValue) }
        object["repeatUntil"] = repeatUntil.map(JSONValue.string)
        object["recurrenceParentId"] = recurrenceParentID.map { .string(webID($0)) }
        object["sourceFeed"] = sourceFeed.map(JSONValue.string)
        object["sourceUid"] = sourceUID.map(JSONValue.string)
        object["sourceHash"] = sourceHash.map(JSONValue.string)
        object["deletedAt"] = deletedAt.map(millis)
        return .object(object)
    }

    /// An assignment from a file, checked the way `normalizeTask` checks
    /// one, including the oldest files' deadlines (one full timestamp).
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue) else { return nil }
        // A file that has `dueTime` (even null) uses the two-field deadline.
        // Anything older kept a whole timestamp in `due`, read back by
        // Phase 2's parseLegacyDue as the day and time you typed.
        let rawDue = v["due"]?.stringValue
        let rawTime = v["dueTime"]?.stringValue
        let hasTime = v.objectValue?.keys.contains("dueTime") ?? false
        let migrated = hasTime && (v["due"] == .null || isValidDate(rawDue))
        let deadline = migrated
            ? Deadline(date: isValidDate(rawDue) ? rawDue : nil,
                       time: isValidTime(rawTime) ? rawTime : nil)
            : parseLegacyDue(rawDue)

        self.init(id: id, courseID: link(v["classId"]), title: v["title"]?.stringValue ?? "",
                  due: deadline.date, dueTime: deadline.time)
        reminder = v["reminder"]?.boolValue == true
        done = v["done"]?.boolValue == true
        kind = Kind(rawValue: v["kind"]?.stringValue ?? "") ?? .assignment
        notes = v["notes"]?.stringValue
        // Phase 7a's normalizeLeads keeps real lead times, longest first.
        remindLeads = normalizeLeads((v["remindLeads"]?.arrayValue ?? []).compactMap { roundedInt($0) }) ?? []
        snoozedUntil = webDate(v["snoozedUntil"])
        subtasks = (v["subtasks"]?.arrayValue ?? []).compactMap(Subtask.init(web:))
        repeatRule = RepeatRule(rawValue: v["repeat"]?.stringValue ?? "")
        repeatUntil = isValidDate(v["repeatUntil"]?.stringValue) ? v["repeatUntil"]?.stringValue : nil
        recurrenceParentID = link(v["recurrenceParentId"])
        sourceFeed = v["sourceFeed"]?.stringValue
        sourceUID = v["sourceUid"]?.stringValue
        sourceHash = v["sourceHash"]?.stringValue
        deletedAt = webDate(v["deletedAt"])
    }
}

// MARK: - Grades and notes

extension Grade: BackupItem {
    /// This grade as the web's `GradeItem`.
    var webJSON: JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(webID(id)),
            "classId": linkJSON(courseID),
            "title": .string(title),
            "score": .number(score),
            "max": .number(self.max),   // `self.` so it can't be read as Swift's max()
            "weight": .number(weight),
            "date": .string(date),
        ]
        object["kind"] = kind.map { .string($0.rawValue) }
        object["deletedAt"] = deletedAt.map(millis)
        return .object(object)
    }

    /// A grade from a file. The web takes grades as they are.
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue) else { return nil }
        self.init(id: id, courseID: link(v["classId"]), title: v["title"]?.stringValue ?? "",
                  score: v["score"]?.numberValue ?? 0, max: v["max"]?.numberValue ?? 0,
                  weight: v["weight"]?.numberValue ?? 0, date: v["date"]?.stringValue ?? "")
        kind = Kind(rawValue: v["kind"]?.stringValue ?? "")
        deletedAt = webDate(v["deletedAt"])
    }
}

extension Note: BackupItem {
    /// This note as the web's `NoteItem`: `classId` "" for a quick note,
    /// `taskId` for a linked assignment.
    var webJSON: JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(webID(id)),
            "classId": linkJSON(courseID),
            "date": .string(date),
            "title": .string(title),
            "body": .string(body),
            "updatedAt": millis(updatedAt),
        ]
        object["taskId"] = assignmentID.map { .string(webID($0)) }
        object["deletedAt"] = deletedAt.map(millis)
        return .object(object)
    }

    /// A note from a file, cut to the web's limits. `normalizeNotes`.
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue) else { return nil }
        self.init(id: id, courseID: link(v["classId"]), date: v["date"]?.stringValue ?? "",
                  title: String((v["title"]?.stringValue ?? "").prefix(200)),
                  body: String((v["body"]?.stringValue ?? "").prefix(maxNoteChars)),
                  assignmentID: link(v["taskId"]), updatedAt: moment(v["updatedAt"]))
        deletedAt = webDate(v["deletedAt"])
    }
}

// MARK: - Planned days and study sessions

extension TaskPlan: BackupItem {
    /// This plan as the web's `TaskPlan`: priority 1 to 3, or null.
    var webJSON: JSONValue {
        .object([
            "id": .string(webID(id)),
            "taskId": .string(webID(assignmentID)),
            "date": .string(date),
            "priority": priority.map(JSONValue.int) ?? .null,
            "updatedAt": millis(updatedAt),
        ])
    }

    /// A plan from a file: it needs an id, its assignment and a real day.
    /// `normalizeTaskPlans`.
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue),
              let task = uuid(fromWebID: v["taskId"]?.stringValue),
              let date = v["date"]?.stringValue, isValidDate(date) else { return nil }
        let priority = v["priority"]?.intValue.flatMap { (1...3).contains($0) ? $0 : nil }
        self.init(id: id, assignmentID: task, date: date, priority: priority,
                  updatedAt: moment(v["updatedAt"]))
    }
}

extension StudySession: BackupItem {
    /// This finished focus block as the web's `StudySession`.
    var webJSON: JSONValue {
        .object([
            "id": .string(webID(id)),
            "taskId": assignmentID.map { .string(webID($0)) } ?? .null,
            "classId": courseID.map { .string(webID($0)) } ?? .null,
            "minutes": .int(minutes),
            "completedAt": millis(completedAt),
            "mode": .string(mode.rawValue),
        ])
    }

    /// A session from a file: 1 to 240 minutes and a finish time.
    /// `normalizeStudySessions`.
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue),
              let minutes = roundedInt(v["minutes"]), (1...240).contains(minutes),
              let finished = v["completedAt"]?.numberValue else { return nil }
        self.init(id: id, assignmentID: link(v["taskId"]), courseID: link(v["classId"]),
                  minutes: minutes, completedAt: moment(.number(finished)),
                  mode: v["mode"]?.stringValue == "pomodoro" ? .pomodoro : .timer)
    }
}

// MARK: - The profile

extension Profile {
    /// The profile values a backup carries, and only these: the web's
    /// `PORTABLE_PROFILE_KEYS`. Feeds, quotes and the term question stay put.
    var webBackupJSON: [String: JSONValue] {
        var object: [String: JSONValue] = [
            "username": .string(username),
            "avatarUrl": avatarURL.map(JSONValue.string) ?? .null,
            "theme": .string(theme.rawValue),
            "accent": .string(accent.rawValue),
            "postClassNudge": .bool(postClassNudge),
            "finalsDate": finalsDate.map(JSONValue.string) ?? .null,
            "termStart": termStart.map(JSONValue.string) ?? .null,
            "termEnd": termEnd.map(JSONValue.string) ?? .null,
        ]
        // Quiet hours are one object on the web, two numbers here (Phase 1).
        if let quiet = normalizeQuietHours(start: quietStart, end: quietEnd) {
            object["quietHours"] = .object(["start": .int(quiet.start), "end": .int(quiet.end)])
        } else {
            object["quietHours"] = .null
        }
        object["gradeScale"] = gradeScale.map { .string($0.rawValue) }
        if !customScale.isEmpty {
            object["customScale"] = .array(customScale.map { band in
                .object(["min": .number(band.min), "letter": .string(band.letter),
                         "points": .number(band.points)])
            })
        }
        object["termName"] = termName.map(JSONValue.string)
        return object
    }

    /// Takes a backup's profile values. A key the file doesn't have keeps
    /// yours, as the web's `{ ...prev, ...result.profile }` does, and a value
    /// that makes no sense here is ignored rather than saved.
    /// `mutating` because it changes the profile it's called on.
    mutating func adoptBackup(_ values: [String: JSONValue]) {
        if let name = values["username"]?.stringValue,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            username = name
        }
        // The web's `cleanAvatar(file ?? yours)`: null keeps your picture, and
        // one that couldn't be shown after a relaunch (or is too big) clears it.
        if let value = values["avatarUrl"], value != .null {
            let url = value.stringValue
            let fits = (url?.count ?? 0) <= AVATAR_MAX_ENCODED_CHARS
            avatarURL = isPersistableAvatar(url) && fits ? url : nil
        }
        // Inside `extension Profile`, `Theme` means Profile.Theme, not the
        // app's colors: the nearer name wins.
        if let theme = values["theme"]?.stringValue.flatMap(Theme.init(rawValue:)) {
            self.theme = theme
        }
        // `normalizeAccent`: Ocean, or Baby Pink for anything else.
        if let value = values["accent"], value != .null {
            accent = value.stringValue == "ocean" ? .ocean : .babypink
        }
        if let nudge = values["postClassNudge"]?.boolValue { postClassNudge = nudge }
        if let value = values["quietHours"] {
            let quiet = normalizeQuietHours(start: value["start"]?.intValue, end: value["end"]?.intValue)
            quietStart = quiet?.start
            quietEnd = quiet?.end
        }
        finalsDate = adoptDay(values["finalsDate"], finalsDate)
        termStart = adoptDay(values["termStart"], termStart)
        termEnd = adoptDay(values["termEnd"], termEnd)
        if let scale = values["gradeScale"]?.stringValue.flatMap(GradeScale.init(rawValue:)) {
            gradeScale = scale
        }
        if let list = values["customScale"]?.arrayValue {
            let bands = list.compactMap { v -> ScaleBand? in
                guard let min = v["min"]?.numberValue, let letter = v["letter"]?.stringValue,
                      let points = v["points"]?.numberValue else { return nil }
                return ScaleBand(min: min, letter: letter, points: points)
            }
            // Phase 9a's checks; nothing usable falls back to the standard scale.
            customScale = normalizeScale(bands) ?? []
        }
        if let value = values["termName"] {
            let clean = String((value.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
            termName = clean.isEmpty ? nil : clean
        }
    }
}

/// A day from a backup's profile: a real day sets it, null clears it, and
/// anything else leaves yours alone.
private func adoptDay(_ value: JSONValue?, _ current: String?) -> String? {
    guard let value else { return current }
    if value == .null { return nil }
    if let day = value.stringValue, isValidDate(day) { return day }
    return current
}

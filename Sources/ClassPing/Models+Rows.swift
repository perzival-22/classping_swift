//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Rows.swift
//  Phase:   14b (the row mapping)
//  Ports:   lib/supabase/map.ts (classToRow / rowToClass, taskToRow /
//           rowToTask, gradeToRow / rowToGrade, noteToRow / rowToNote,
//           taskPlanToRow / rowToTaskPlan, studySessionToRow /
//           rowToStudySession, profileToRow / rowToProfile, gameStateToRow)
//           and lib/feeds.ts (normalizeFeeds); its tests are
//           lib/supabase/columns.test.ts
//
//  Summary: The one place that knows both names for every field. The server
//           keeps snake_case columns (`start_min`, `extra_reminders`,
//           `deleted_at`); the app keeps its own names (`startMin`,
//           `extraReminders`, `deletedAt`). Every row that goes to or comes
//           from the server in Phase 14 passes through here, so a renamed
//           column is learned in one file. Lives outside Logic/ because it
//           needs the models, like Models+Backup.swift (11b+c).
//

import Foundation

// MARK: - Small helpers for this file

/// Text, or the server's null. `x ?? null` on the web.
private func text(_ value: String?) -> JSONValue {
    value.map(JSONValue.string) ?? .null
}

/// A number, or null.
private func number(_ value: Double?) -> JSONValue {
    value.map(JSONValue.number) ?? .null
}

/// A link to another item: its id the web's way (lower case), or null for
/// none. The web writes `t.classId || null`: "" (the Inbox) becomes null.
private func link(_ id: UUID?) -> JSONValue {
    id.map { .string(webID($0)) } ?? .null
}

/// A moment, or null. `deletedAtToRow` and the `toISOString()` calls.
private func instant(_ date: Date?) -> JSONValue {
    date.map { .string(serverInstant($0)) } ?? .null
}

/// The UUID a row's link column names, or nil for null or "". The web reads
/// `r.class_id ?? ""`, and "" is the Inbox. 11b+c's `uuid(fromWebID:)`
/// turns an old short id into the same UUID every time.
private func linked(_ value: JSONValue?) -> UUID? {
    uuid(fromWebID: value?.stringValue)
}

/// A number the way JavaScript's `Number(v)` reads one: a number as it is,
/// text with a number in it ("80.5", which is how Postgres can send a
/// `numeric`), and null or empty text as 0. Anything else is nil.
private func jsNumber(_ value: JSONValue?) -> Double? {
    switch value {
    case .number(let n)?:
        return n.isFinite ? n : nil
    case .string(let s)?:
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? 0 : Double(trimmed)
    case .null?:
        return 0
    case .bool(let flag)?:
        return flag ? 1 : 0
    default:
        return nil
    }
}

/// `Math.round(Number(v))` as a whole number, or nil when it isn't one.
private func jsRounded(_ value: JSONValue?) -> Int? {
    jsNumber(value).flatMap { Int(exactly: $0.rounded()) }
}

/// The whole numbers in a list, skipping anything else.
private func ints(_ value: JSONValue?) -> [Int] {
    (value?.arrayValue ?? []).compactMap(\.intValue)
}

// MARK: - Classes

extension Course {
    /// This class as a `classes` row. `classToRow`. Every column is present,
    /// with null for an empty detail: a present null is what tells the server
    /// to clear a column, and `deleted_at: null` is how a restore lands.
    func serverRow(userID: String) -> ServerRow {
        [
            "id": .string(webID(id)),
            "user_id": .string(userID),
            "name": .string(name),
            "short": .string(short),
            "color": .string(color.rawValue),
            "days": .array(days.map(JSONValue.int)),
            "additional_meetings": .array(additionalMeetings.map(\.webJSON)),
            "start_min": .int(startMin),
            "end_min": .int(endMin),
            "remind_before": .int(remindBefore),
            "alarm": .bool(alarm),
            "extra_reminders": .array(extraReminders.map(JSONValue.int)),
            "credits": number(credits),
            "room": text(room),
            "instructor": text(instructor),
            "notes": text(notes),
            "term": text(term),
            "archived": .bool(archived),
            "goal": number(goal),
            "source_feed": text(sourceFeed),
            "source_uid": text(sourceUID),
            "source_hash": text(sourceHash),
            "deleted_at": instant(deletedAt),
        ]
    }

    /// A class from a `classes` row, or nil without an id. `rowToClass`.
    /// Extra meetings that break the web's rules are dropped as a group, as
    /// the web does; a color the phone doesn't know becomes indigo, and days
    /// outside Monday to Sunday are dropped (the web takes them as they are,
    /// but the phone's weekday helper can't hold them).
    init?(serverRow r: ServerRow) {
        guard let id = uuid(fromWebID: r["id"]?.stringValue) else { return nil }
        // `for … where` keeps each real day once, as 11b+c's reader does.
        var days: [Int] = []
        for day in ints(r["days"]) where (0...6).contains(day) && !days.contains(day) {
            days.append(day)
        }
        self.init(id: id,
                  name: r["name"]?.stringValue ?? "",
                  short: r["short"]?.stringValue ?? "",
                  color: SubjectColor(rawValue: r["color"]?.stringValue ?? "") ?? .indigo,
                  days: days,
                  startMin: r["start_min"]?.intValue ?? 0,
                  endMin: r["end_min"]?.intValue ?? 0)
        additionalMeetings = r["additional_meetings"].flatMap(meetingsFromWeb) ?? []
        remindBefore = r["remind_before"]?.intValue ?? 10
        alarm = r["alarm"]?.boolValue ?? true
        extraReminders = ints(r["extra_reminders"])
        credits = r["credits"]?.numberValue
        room = r["room"]?.stringValue
        instructor = r["instructor"]?.stringValue
        notes = r["notes"]?.stringValue
        term = r["term"]?.stringValue
        archived = r["archived"]?.boolValue == true
        goal = r["goal"]?.numberValue
        sourceFeed = r["source_feed"]?.stringValue
        sourceUID = r["source_uid"]?.stringValue
        sourceHash = r["source_hash"]?.stringValue
        deletedAt = instantFromServer(r["deleted_at"]?.stringValue)
    }
}

// MARK: - Assignments

extension Assignment {
    /// This assignment as a `tasks` row. `taskToRow`. The deadline goes as
    /// two columns and neither is a moment: the day as the "yyyy-MM-dd" it
    /// already is, the time beside it. A day that isn't real makes the row
    /// undated rather than a guess, and a time with no day is dropped.
    func serverRow(userID: String) -> ServerRow {
        let dated = isValidDate(due)
        return [
            "id": .string(webID(id)),
            "user_id": .string(userID),
            "class_id": link(courseID),
            "title": .string(title),
            "due": dated ? text(due) : .null,
            "due_time": dated && isValidTime(dueTime) ? text(dueTime) : .null,
            "reminder": .bool(reminder),
            "done": .bool(done),
            "kind": .string(kind.rawValue),
            "notes": text(notes),
            "subtasks": .array(subtasks.map(\.webJSON)),
            // Phase 7a's normalizeLeads: real lead times, longest first.
            "remind_leads": .array((normalizeLeads(remindLeads) ?? []).map(JSONValue.int)),
            "snoozed_until": instant(snoozedUntil),
            "repeat_rule": text(repeatRule?.rawValue),
            "repeat_until": text(repeatUntil),
            "recurrence_parent_id": link(recurrenceParentID),
            "source_feed": text(sourceFeed),
            "source_uid": text(sourceUID),
            "source_hash": text(sourceHash),
            "deleted_at": instant(deletedAt),
        ]
    }

    /// An assignment from a `tasks` row, or nil without an id. `rowToTask`.
    /// Postgres sends the time as "23:30:00"; Phase 2's `fromDbTime` cuts it
    /// to "23:30". A kind the phone doesn't know becomes a plain assignment.
    init?(serverRow r: ServerRow) {
        guard let id = uuid(fromWebID: r["id"]?.stringValue) else { return nil }
        let rawDue = r["due"]?.stringValue
        let due = isValidDate(rawDue) ? rawDue : nil
        self.init(id: id, courseID: linked(r["class_id"]), title: r["title"]?.stringValue ?? "",
                  due: due,
                  // A time without a day means nothing, so it's dropped.
                  dueTime: due == nil ? nil : fromDbTime(r["due_time"]?.stringValue))
        reminder = r["reminder"]?.boolValue == true
        done = r["done"]?.boolValue == true
        kind = Kind(rawValue: r["kind"]?.stringValue ?? "") ?? .assignment
        notes = r["notes"]?.stringValue
        subtasks = (r["subtasks"]?.arrayValue ?? []).compactMap(Subtask.init(web:))
        remindLeads = normalizeLeads((r["remind_leads"]?.arrayValue ?? []).compactMap { jsRounded($0) }) ?? []
        snoozedUntil = instantFromServer(r["snoozed_until"]?.stringValue)
        repeatRule = RepeatRule(rawValue: r["repeat_rule"]?.stringValue ?? "")
        repeatUntil = r["repeat_until"]?.stringValue
        recurrenceParentID = linked(r["recurrence_parent_id"])
        sourceFeed = r["source_feed"]?.stringValue
        sourceUID = r["source_uid"]?.stringValue
        sourceHash = r["source_hash"]?.stringValue
        deletedAt = instantFromServer(r["deleted_at"]?.stringValue)
    }
}

// MARK: - Grades and notes

extension Grade {
    /// This grade as a `grades` row. `gradeToRow`. A date holding a whole
    /// timestamp is cut to its day, which is all a `date` column keeps.
    func serverRow(userID: String) -> ServerRow {
        [
            "id": .string(webID(id)),
            "user_id": .string(userID),
            "class_id": link(courseID),
            "title": .string(title),
            "score": .number(score),
            "max": .number(self.max),   // `self.` so it can't be read as Swift's max()
            "weight": .number(weight),
            "date": .string(serverDay(date) ?? date),
            "kind": text(kind?.rawValue),
            "deleted_at": instant(deletedAt),
        ]
    }

    /// A grade from a `grades` row, or nil without an id. `rowToGrade`.
    /// Score, max and weight go through `Number()` on the web, because a
    /// Postgres `numeric` can arrive as text ("80.5").
    init?(serverRow r: ServerRow) {
        guard let id = uuid(fromWebID: r["id"]?.stringValue) else { return nil }
        self.init(id: id, courseID: linked(r["class_id"]), title: r["title"]?.stringValue ?? "",
                  score: jsNumber(r["score"]) ?? 0, max: jsNumber(r["max"]) ?? 0,
                  weight: jsNumber(r["weight"]) ?? 0, date: r["date"]?.stringValue ?? "")
        kind = Kind(rawValue: r["kind"]?.stringValue ?? "")
        deletedAt = instantFromServer(r["deleted_at"]?.stringValue)
    }
}

extension Note {
    /// This note as a `notes` row. `noteToRow`. There's no `updated_at`:
    /// the server's `touch_row` trigger owns it, and a column the server
    /// rewrites on every write could never match what was last sent.
    func serverRow(userID: String) -> ServerRow {
        [
            "id": .string(webID(id)),
            "user_id": .string(userID),
            "class_id": link(courseID),
            "date": .string(serverDay(date) ?? date),
            "title": .string(title),
            "body": .string(body),
            "task_id": link(assignmentID),
            "deleted_at": instant(deletedAt),
        ]
    }

    /// A note from a `notes` row, or nil without an id. `rowToNote`. Its
    /// "updated" moment is the server's `updated_at`, or 1970 without one.
    init?(serverRow r: ServerRow) {
        guard let id = uuid(fromWebID: r["id"]?.stringValue) else { return nil }
        self.init(id: id, courseID: linked(r["class_id"]), date: r["date"]?.stringValue ?? "",
                  title: r["title"]?.stringValue ?? "", body: r["body"]?.stringValue ?? "",
                  assignmentID: linked(r["task_id"]),
                  updatedAt: instantFromServer(r["updated_at"]?.stringValue) ?? Date(timeIntervalSince1970: 0))
        deletedAt = instantFromServer(r["deleted_at"]?.stringValue)
    }
}

// MARK: - Planned days and study sessions

extension TaskPlan {
    /// This plan as a `task_plans` row. `taskPlanToRow`.
    func serverRow(userID: String) -> ServerRow {
        [
            "id": .string(webID(id)),
            "user_id": .string(userID),
            "task_id": .string(webID(assignmentID)),
            "date": .string(date),
            "priority": priority.map(JSONValue.int) ?? .null,
        ]
    }

    /// A plan from a `task_plans` row, or nil without an id or its
    /// assignment. `rowToTaskPlan`: a priority other than 1, 2 or 3 is none.
    init?(serverRow r: ServerRow) {
        guard let id = uuid(fromWebID: r["id"]?.stringValue),
              let task = uuid(fromWebID: r["task_id"]?.stringValue) else { return nil }
        let priority = r["priority"]?.intValue.flatMap { (1...3).contains($0) ? $0 : nil }
        self.init(id: id, assignmentID: task, date: r["date"]?.stringValue ?? "", priority: priority,
                  updatedAt: instantFromServer(r["updated_at"]?.stringValue) ?? Date(timeIntervalSince1970: 0))
    }
}

extension StudySession {
    /// This finished focus block as a `study_sessions` row.
    /// `studySessionToRow`.
    func serverRow(userID: String) -> ServerRow {
        [
            "id": .string(webID(id)),
            "user_id": .string(userID),
            "task_id": link(assignmentID),
            "class_id": link(courseID),
            "minutes": .int(minutes),
            "completed_at": .string(serverInstant(completedAt)),
            "mode": .string(mode.rawValue),
        ]
    }

    /// A session from a `study_sessions` row, or nil without an id.
    /// `rowToStudySession`: "pomodoro" or else the timer.
    init?(serverRow r: ServerRow) {
        guard let id = uuid(fromWebID: r["id"]?.stringValue) else { return nil }
        self.init(id: id, assignmentID: linked(r["task_id"]), courseID: linked(r["class_id"]),
                  minutes: jsRounded(r["minutes"]) ?? 0,
                  completedAt: instantFromServer(r["completed_at"]?.stringValue) ?? Date(timeIntervalSince1970: 0),
                  mode: r["mode"]?.stringValue == "pomodoro" ? .pomodoro : .timer)
    }
}

// MARK: - Calendar feeds

extension SavedFeed {
    /// One saved feed as the web keeps it inside the profile's
    /// `import_feeds`: never synced is 0, not null.
    var webJSON: JSONValue {
        .object([
            "id": .string(webID(id)),
            "url": .string(url),
            "label": .string(label),
            "lastSyncedAt": .number(lastSyncedAt.map(webMillis) ?? 0),
        ])
    }
}

/// Whatever the profile holds as feeds, as a usable list: each one needs an
/// id and an http(s) link, an id counts once, a blank name becomes the
/// link's host, and at most five are kept. `normalizeFeeds` in lib/feeds.ts.
func normalizeFeeds(_ raw: JSONValue?) -> [SavedFeed] {
    var out: [SavedFeed] = []
    var seen: Set<String> = []
    // `where` stops taking feeds at five, so the loop needs no `break`.
    for value in raw?.arrayValue ?? [] where out.count < MAX_FEEDS {
        // `continue` skips to the next feed.
        guard let key = value["id"]?.stringValue, !key.isEmpty, !seen.contains(key),
              let id = uuid(fromWebID: key),
              let url = value["url"]?.stringValue, isFeedURL(url) else { continue }
        seen.insert(key)
        let name = (value["label"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        out.append(SavedFeed(id: id, url: url,
                             label: name.isEmpty ? feedLabelFromURL(url) : String(name.prefix(60)),
                             lastSyncedAt: webDate(value["lastSyncedAt"])))
    }
    return out
}

// MARK: - The profile

extension Profile {
    /// Your profile as a `profiles` row. `profileToRow`. `style` is always
    /// "soft" (an old column the web keeps filled), and `tz` is never here:
    /// it goes in its own two-column write (`TZ_COLUMNS`, 14a).
    func serverRow(userID: String) -> ServerRow {
        let quiet = normalizeQuietHours(start: quietStart, end: quietEnd)
        let feeds = normalizeFeeds(.array(importFeeds.map(\.webJSON)))
        let bands = normalizeScale(customScale) ?? []
        return [
            "user_id": .string(userID),
            "username": .string(username),
            "avatar_url": text(avatarURL),
            "theme": .string(theme.rawValue),
            "accent": .string(accent.rawValue),
            "style": .string("soft"),
            "post_class_nudge": .bool(postClassNudge),
            "quiet_start": quiet.map { JSONValue.int($0.start) } ?? .null,
            "quiet_end": quiet.map { JSONValue.int($0.end) } ?? .null,
            "finals_date": text(serverDay(finalsDate)),
            "grade_scale": text(gradeScale?.rawValue),
            "term_start": text(serverDay(termStart)),
            "term_end": text(serverDay(termEnd)),
            "term_name": text(termName),
            "term_setup_prompted": .bool(termSetupPrompted),
            "import_feeds": .array(feeds.map(\.webJSON)),
            "custom_scale": .array(bands.map { band in
                JSONValue.object(["letter": .string(band.letter), "min": .number(band.min),
                         "points": .number(band.points)])
            }),
            "quotes": .array(normalizeQuotes(quotes).map(JSONValue.string)),
        ]
    }

    /// Your profile from a `profiles` row: `rowToProfile` laid over the
    /// defaults, with `cleanAvatar` on the picture, as the web's store does.
    /// A grade scale the phone doesn't know reads as none (the standard one).
    init(serverRow r: ServerRow) {
        self.init()
        username = r["username"]?.stringValue ?? ""
        let picture = r["avatar_url"]?.stringValue
        avatarURL = isPersistableAvatar(picture) ? picture : nil
        // Inside `extension Profile`, `Theme` means Profile.Theme.
        theme = r["theme"]?.stringValue == "dark" ? .dark : .light
        accent = r["accent"]?.stringValue == "ocean" ? .ocean : .babypink
        postClassNudge = r["post_class_nudge"]?.boolValue ?? true
        // The web reads both ends with `Math.round(Number(v))`, and
        // `Number(null)` is 0: a lone null end means midnight.
        let quiet = normalizeQuietHours(start: jsRounded(r["quiet_start"]), end: jsRounded(r["quiet_end"]))
        quietStart = quiet?.start
        quietEnd = quiet?.end
        finalsDate = r["finals_date"]?.stringValue
        gradeScale = GradeScale(rawValue: r["grade_scale"]?.stringValue ?? "")
        termStart = r["term_start"]?.stringValue
        termEnd = r["term_end"]?.stringValue
        termName = r["term_name"]?.stringValue
        termSetupPrompted = r["term_setup_prompted"]?.boolValue == true
        importFeeds = normalizeFeeds(r["import_feeds"])
        let bands = (r["custom_scale"]?.arrayValue ?? []).compactMap { v -> ScaleBand? in
            guard let letter = v["letter"]?.stringValue, let min = jsNumber(v["min"]),
                  let points = jsNumber(v["points"]) else { return nil }
            return ScaleBand(min: min, letter: letter, points: points)
        }
        customScale = normalizeScale(bands) ?? []
        quotes = normalizeQuotes((r["quotes"]?.arrayValue ?? []).compactMap(\.stringValue))
    }
}

// MARK: - Progress

extension GameBlobs {
    /// Your trophies, XP, pet and boss as the `game_state` row: one `data`
    /// object holding whichever pieces exist, untouched (D-74).
    /// `gameStateToRow`.
    func serverRow(userID: String) -> ServerRow {
        var data: [String: JSONValue] = [:]
        // Setting a dictionary entry to nil leaves it out, the way
        // `JSON.stringify` leaves out an undefined piece.
        data["trophies"] = trophies
        data["xp"] = xp
        data["pet"] = pet
        data["boss"] = boss
        return ["user_id": .string(userID), "data": .object(data)]
    }

    /// The pieces a `game_state` row holds, kept exactly as they are.
    init(serverRow r: ServerRow) {
        self.init(trophies: r["data"]?["trophies"], xp: r["data"]?["xp"],
                  pet: r["data"]?["pet"], boss: r["data"]?["boss"])
    }
}

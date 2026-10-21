//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Backup.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/backup.ts (BACKUP_VERSION, UNSUPPORTED_ON_PURPOSE,
//           backupFilename, validateBackup, planRestore, applyRestore's
//           merge, describePlan) and the clear-data summary of
//           app/settings/page.tsx
//
//  Summary: The backup file's rules, in the web's own format (version 4,
//           D-66), so a file from either app restores in the other. Reading a
//           file checks it before anything moves; planning a restore counts
//           what's new, what's already here and what would change; the merge
//           adds and never quietly takes away. Foundation only.
//

import Foundation

// MARK: - The format

/// The version of the files this app writes. `BACKUP_VERSION`.
/// 1 was the old four-list export, 2 added every kind of item, 3 day plans
/// and study sessions, 4 a class's extra meeting times.
let BACKUP_VERSION = 4

/// The oldest file still readable. `MIN_SUPPORTED_VERSION`.
let MIN_SUPPORTED_VERSION = 1

/// One thing a backup leaves out on purpose, and why.
struct BackupLeftOut: Equatable, Sendable {
    let what: String
    let why: String
}

/// What a backup never carries. `UNSUPPORTED_ON_PURPOSE`, word for word.
let BACKUP_LEAVES_OUT = [
    BackupLeftOut(what: "Sign-in details",
                  why: "Your account lives with Clerk, not in this file."),
    BackupLeftOut(what: "Push notification subscriptions",
                  why: "These belong to a specific browser or device and can't move."),
    BackupLeftOut(what: "Email preferences and entitlements",
                  why: "These are stored against your account on the server."),
]

/// "classping-backup-2026-10-21.json", by your own calendar day.
/// `backupFilename`. `dayOf` (Phase 2) gives the local "yyyy-MM-dd".
func backupFilename(_ now: Date) -> String {
    "classping-backup-\(dayOf(now)).json"
}

// MARK: - Ids and moments, the web's way

/// A UUID the way a backup file writes it: lower case, as the web's
/// `crypto.randomUUID()` does. Swift's `uuidString` is upper case.
func webID(_ id: UUID) -> String {
    id.uuidString.lowercased()
}

/// The UUID for an id read from a file, or nil when there isn't one.
/// A real UUID is used as it is, in any case. Anything else (the web's
/// oldest items had short random ids) gets a UUID made from its letters by
/// `stableUUID`, the same one every time, so links between items survive
/// and restoring one file twice can't make copies.
func uuid(fromWebID text: String?) -> UUID? {
    guard let text, !text.isEmpty else { return nil }
    return UUID(uuidString: text) ?? stableUUID(text)
}

/// The same text always gives the same UUID. It runs FNV-1a, a tiny
/// well-known hash, twice with different starting values, which makes the
/// 16 bytes. `&*` multiplies and lets the result wrap around instead of
/// crashing on overflow, which is exactly what this hash wants.
func stableUUID(_ text: String) -> UUID {
    var a: UInt64 = 0xcbf2_9ce4_8422_2325
    var b: UInt64 = 0x6c62_272e_07bb_0142
    for byte in text.utf8 {
        a = (a ^ UInt64(byte)) &* 0x100_0000_01b3
        b = (b ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    // Eight bytes from each, highest first. `>>` shifts the bits right and
    // `truncatingIfNeeded` keeps the lowest eight of what's left.
    var bytes = (0..<8).map { UInt8(truncatingIfNeeded: a >> (56 - 8 * $0)) }
        + (0..<8).map { UInt8(truncatingIfNeeded: b >> (56 - 8 * $0)) }
    // Mark it as a version-4 UUID so every reader takes it for a normal one.
    bytes[6] = (bytes[6] & 0x0F) | 0x40
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
}

/// A moment as the web stores one: milliseconds since 1970. The phone keeps
/// whole seconds (planner.json writes "2026-10-21T03:04:05Z", no fraction),
/// so the fraction is dropped here too: a file this phone writes says the
/// same thing before and after the app restarts (D-73). `.down` rounds
/// toward the past, the way planner.json's dates do.
func webMillis(_ date: Date) -> Double {
    date.timeIntervalSince1970.rounded(.down) * 1000
}

/// A moment from a file's milliseconds, to the whole second, or nil when it's
/// missing, not a number, or 0 or less (the web's `typeof x === "number" &&
/// x > 0`). Whole seconds for the same reason as `webMillis`: an item restored
/// from a file must match that file again after a relaunch.
func webDate(_ value: JSONValue?) -> Date? {
    guard let ms = value?.numberValue, ms > 0 else { return nil }
    return Date(timeIntervalSince1970: (ms / 1000).rounded(.down))
}

// MARK: - Progress

/// Your trophies, XP, pet and weekly boss, kept exactly as a file had them.
/// The phone shows none of them until Phase 12, but it keeps them (D-74), so
/// a web backup that passes through the phone still has them.
/// `Codable` writes them into planner.json as they are.
struct GameBlobs: Codable, Hashable, Sendable {
    var trophies: JSONValue? = nil
    var xp: JSONValue? = nil
    var pet: JSONValue? = nil
    var boss: JSONValue? = nil

    /// True when there's nothing at all.
    var isEmpty: Bool { trophies == nil && xp == nil && pet == nil && boss == nil }

    /// Takes the pieces a backup has and keeps the rest: the web only sets
    /// what the file defines (`if (result.xp !== undefined) setXp(…)`).
    mutating func adopt(_ other: GameBlobs) {
        if let trophies = other.trophies { self.trophies = trophies }
        if let xp = other.xp { self.xp = xp }
        if let pet = other.pet { self.pet = pet }
        if let boss = other.boss { self.boss = boss }
    }
}

// MARK: - A class's extra meetings

/// Extra meetings read from a file, or nil when the list breaks the web's
/// rules (`validAdditionalMeetings`): fewer than 20, each one valid, none
/// called "primary", no id twice. One bad meeting fails the whole list,
/// as on the web, and then the whole file is refused.
func meetingsFromWeb(_ value: JSONValue) -> [ClassMeeting]? {
    guard let list = value.arrayValue, list.count < maxMeetings else { return nil }
    let meetings = list.compactMap(meetingFromWeb)
    let ids = list.compactMap { $0["id"]?.stringValue }
    guard meetings.count == list.count, !ids.contains("primary"),
          Set(ids).count == ids.count else { return nil }
    return meetings
}

/// One meeting from a file, checked the way `validMeeting` checks it on the
/// web: an id of letters, digits and dashes, whole-number days and times,
/// and a room or label that, when present, is text.
private func meetingFromWeb(_ v: JSONValue) -> ClassMeeting? {
    guard let text = v["id"]?.stringValue,
          text.range(of: #"^[a-zA-Z0-9-]{1,80}$"#, options: .regularExpression) != nil,
          let id = uuid(fromWebID: text),
          let rawDays = v["days"]?.arrayValue,
          let start = v["start"]?.intValue,
          let end = v["end"]?.intValue else { return nil }
    let days = rawDays.compactMap(\.intValue)
    let room = v["room"]
    let label = v["label"]
    // Every day a whole number; room and label missing or text, never null.
    guard days.count == rawDays.count,
          room == nil || room?.stringValue != nil,
          label == nil || label?.stringValue != nil else { return nil }
    let meeting = ClassMeeting(id: id, days: days, start: start, end: end,
                               room: room?.stringValue, label: label?.stringValue)
    // Phase 5a's checks do the rest: days, times and lengths.
    return validMeeting(meeting) ? meeting : nil
}

extension ClassMeeting {
    /// The meeting as the web writes it inside a class.
    var webJSON: JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(webID(id)),
            "days": .array(days.map(JSONValue.int)),
            "start": .int(start),
            "end": .int(end),
        ]
        // Setting a dictionary entry to nil leaves it out, the way the web
        // leaves out a missing room.
        object["room"] = room.map(JSONValue.string)
        object["label"] = label.map(JSONValue.string)
        return .object(object)
    }
}

// MARK: - Reading a file

/// Why a file can't be restored, in words for someone trying to get their
/// semester back. `Error` lets it be the failure side of a `Result` (11a).
struct BackupError: Error, Equatable {
    let message: String
}

/// A file that passed the checks: each list as raw items in the web's
/// shape, the profile's values, the progress, and what to warn about. The
/// app's own models are made from these in Store+Backup.swift.
struct BackupFile: Equatable {
    var schemaVersion: Int
    var exportedAt: String
    var classes: [JSONValue]
    var tasks: [JSONValue]
    var grades: [JSONValue]
    var notes: [JSONValue]
    var taskPlans: [JSONValue]
    var studySessions: [JSONValue]
    var profile: [String: JSONValue]
    var progress: GameBlobs
    var warnings: [String]
}

/// Reads a backup's bytes and decides whether to trust them.
/// `validateBackup` in lib/backup.ts, check for check and message for
/// message. Nothing is changed by reading; a bad file only gets a reason.
func checkBackup(_ data: Data) -> Result<BackupFile, BackupError> {
    // It must be JSON, and a JSON object.
    guard let parsed = try? JSONDecoder().decode(JSONValue.self, from: data) else {
        return .failure(BackupError(message: "That file isn't valid JSON, it may be damaged."))
    }
    guard let top = parsed.objectValue else {
        return .failure(BackupError(message: "That file doesn't look like a ClassPing backup."))
    }
    guard top["app"]?.stringValue == "ClassPing" else {
        return .failure(BackupError(message: "That file wasn't exported from ClassPing."))
    }

    // Too old or from the future: refuse rather than guess.
    let version = schemaVersion(top["schemaVersion"])
    guard version.isFinite, version >= Double(MIN_SUPPORTED_VERSION) else {
        return .failure(BackupError(message: "That backup is too old for this version of ClassPing."))
    }
    guard version <= Double(BACKUP_VERSION) else {
        return .failure(BackupError(message: "That backup was made by a newer version of ClassPing. Update the app, then try again."))
    }

    // Version 1 had no "data" wrapper: the lists sat at the top.
    let body = top["data"]?.objectValue ?? top
    var warnings: [String] = []
    if version < 2 {
        warnings.append("This is an older backup. It doesn't contain lecture notes or progress, those were added to backups later.")
    }

    // Extra meetings that break the rules refuse the whole file.
    let classes = objects(body["classes"])
    let badMeetings = classes.contains { item in
        guard let meetings = item["additionalMeetings"] else { return false }
        return meetingsFromWeb(meetings) == nil
    }
    if badMeetings {
        return .failure(BackupError(message: "This backup contains invalid class meeting times. Correct the file before restoring."))
    }

    let tasks = objects(body["tasks"])
    let grades = objects(body["grades"])
    let notes = objects(body["notes"]).filter(hasID)   // the web's normalizeNotes drops these quietly
    if classes.isEmpty && tasks.isEmpty && grades.isEmpty && notes.isEmpty {
        return .failure(BackupError(message: "That backup is empty, there's nothing to restore."))
    }

    // Items with no id can't be addressed, so they're skipped, and counted.
    // The web's words exactly, "1 item ... have" included (D-76).
    let withoutIDs = (classes + tasks + grades).filter { !hasID($0) }.count
    if withoutIDs > 0 {
        warnings.append("\(withoutIDs) item\(withoutIDs == 1 ? "" : "s") in this file have no identifier and will be skipped.")
    }

    return .success(BackupFile(
        schemaVersion: Int(version),
        exportedAt: top["exportedAt"]?.stringValue ?? "",
        classes: classes.filter(hasID),
        tasks: tasks.filter(hasID),
        grades: grades.filter(hasID),
        notes: notes,
        taskPlans: objects(body["taskPlans"]),
        studySessions: objects(body["studySessions"]),
        profile: body["profile"]?.objectValue ?? [:],
        progress: GameBlobs(trophies: present(body["trophies"]), xp: present(body["xp"]),
                            pet: present(body["pet"]), boss: present(body["boss"])),
        warnings: warnings))
}

/// The file's version: `Number(parsed.schemaVersion ?? 1)`. Missing or
/// null means 1, text is read as a number, true and false are 1 and 0 (as
/// JavaScript's `Number` reads them), anything else isn't a version.
private func schemaVersion(_ value: JSONValue?) -> Double {
    switch value {
    case .none, .some(.null): return 1
    case .some(.number(let number)): return number
    case .some(.bool(let flag)): return flag ? 1 : 0
    case .some(.string(let text)):
        // `Number("")` is 0 in JavaScript, which then reads as "too old".
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? 0 : Double(trimmed) ?? .nan
    default: return .nan
    }
}

/// The objects in a list, skipping anything else. `arr(v).filter(isObj)`.
private func objects(_ value: JSONValue?) -> [JSONValue] {
    (value?.arrayValue ?? []).filter { $0.objectValue != nil }
}

/// True when an item has an id worth using: text that isn't empty.
private func hasID(_ item: JSONValue) -> Bool {
    !(item["id"]?.stringValue ?? "").isEmpty
}

/// A value that's really there: missing and JSON null both mean "none".
private func present(_ value: JSONValue?) -> JSONValue? {
    value == .null ? nil : value
}

// MARK: - Writing a file

/// Every list and the profile as one version-4 file's bytes, pretty-printed
/// like the web's `JSON.stringify(payload, null, 2)`. `buildBackup`.
/// Nil only if encoding fails, which plain JSON values don't.
func backupFileData(classes: [JSONValue], tasks: [JSONValue], grades: [JSONValue],
                    notes: [JSONValue], taskPlans: [JSONValue], studySessions: [JSONValue],
                    profile: [String: JSONValue], progress: GameBlobs, now: Date) -> Data? {
    var data: [String: JSONValue] = [
        "classes": .array(classes),
        "tasks": .array(tasks),
        "grades": .array(grades),
        "notes": .array(notes),
        "taskPlans": .array(taskPlans),
        "studySessions": .array(studySessions),
        "profile": .object(profile),
    ]
    // Progress only when there is some, as the web leaves out `undefined`.
    data["trophies"] = progress.trophies
    data["xp"] = progress.xp
    data["pet"] = progress.pet
    data["boss"] = progress.boss

    // `toISOString()`: "2026-10-21T03:04:05.123Z", always in UTC.
    let stamp = ISO8601DateFormatter()
    stamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let file: JSONValue = .object([
        "app": .string("ClassPing"),
        "schemaVersion": .int(BACKUP_VERSION),
        "exportedAt": .string(stamp.string(from: now)),
        "data": .object(data),
    ])

    // `.withoutEscapingSlashes` keeps "https://" and photo addresses readable.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try? encoder.encode(file)
}

// MARK: - Planning a restore

/// Merge adds what's missing and keeps everything here; Replace makes this
/// phone match the file. `RestoreMode`.
enum RestoreMode: Equatable, Sendable {
    case merge, replace
}

/// What a restore would do to one kind of item. `EntityPlan`.
struct EntityPlan: Equatable, Sendable {
    /// Not here yet: will be added.
    var added = 0
    /// Here already and the same: nothing to do.
    var identical = 0
    /// Here, but different: the file's version would win.
    var conflicting = 0
    /// Here but not in the file: only Replace removes these.
    var onlyHere = 0

    /// How many items would change in `mode`.
    func changes(_ mode: RestoreMode) -> Int {
        added + conflicting + (mode == .replace ? onlyHere : 0)
    }
}

/// Anything a backup carries: it has an id, and it knows how the file writes
/// it. The six models sign up in Models+Backup.swift; the tests use a tiny
/// stand-in, the same trick as `Dated` in Phase 2.
protocol BackupItem: Identifiable {
    var webJSON: JSONValue { get }
}

/// Counts what a restore would do to one list. `planEntity` in lib/backup.ts.
/// "The same" compares the two items as the file would write them, so a
/// file this phone made matches what's on it, whatever order its keys are in.
func planEntity<T: BackupItem>(_ incoming: [T], _ current: [T]) -> EntityPlan {
    // What's here, by id, in file form. `uniquingKeysWith` says what to do
    // if one id appeared twice: keep the later one, as the web's Map does.
    let here = Dictionary(current.map { ($0.id, $0.webJSON) }, uniquingKeysWith: { _, later in later })
    let fileIDs = Set(incoming.map(\.id))
    var plan = EntityPlan()
    for item in incoming {
        if let mine = here[item.id] {
            if mine == item.webJSON { plan.identical += 1 } else { plan.conflicting += 1 }
        } else {
            plan.added += 1
        }
    }
    plan.onlyHere = current.filter { !fileIDs.contains($0.id) }.count
    return plan
}

/// One list after a restore. Merge: everything here stays where it is, the
/// file's version replaces a different one, and new items go on the end
/// (the web's `mergeEntity`). Replace: exactly the file's items. Either way an
/// item that's already the same keeps this phone's copy, so nothing moves.
func restoreEntity<T: BackupItem>(_ incoming: [T], _ current: [T], _ mode: RestoreMode) -> [T] {
    switch mode {
    case .replace:
        let mine = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { _, later in later })
        return incoming.map { item in
            if let have = mine[item.id], have.webJSON == item.webJSON { return have }
            return item
        }
    case .merge:
        var result = current
        // Where each id sits in `result`, so a collision is replaced in place.
        var position: [T.ID: Int] = [:]
        for (index, item) in result.enumerated() { position[item.id] = index }
        for item in incoming {
            if let index = position[item.id] {
                if result[index].webJSON != item.webJSON { result[index] = item }
            } else {
                position[item.id] = result.count
                result.append(item)
            }
        }
        return result
    }
}

/// Everything a restore would do, before it does any of it. `RestorePlan`.
struct RestorePlan: Equatable, Sendable {
    var mode: RestoreMode
    var classes = EntityPlan()
    var tasks = EntityPlan()
    var grades = EntityPlan()
    var notes = EntityPlan()
    var taskPlans = EntityPlan()
    var studySessions = EntityPlan()
    /// The file has profile values (your name, the look, the term…).
    var restoresPreferences = false
    /// The file has progress or study sessions.
    var restoresProgress = false
    var warnings: [String] = []

    /// How many items would change on this phone. `totalChanges`.
    var totalChanges: Int {
        [classes, tasks, grades, notes, taskPlans, studySessions]
            .reduce(0) { $0 + $1.changes(mode) }
    }
}

/// The plan in lines a person can read: "classes: 1 new, 2 already here".
/// `describePlan`, the same words in the same order.
func describePlan(_ plan: RestorePlan) -> [String] {
    let rows = [
        (plan.classes, "class", "classes"),
        (plan.tasks, "assignment", "assignments"),
        (plan.grades, "grade", "grades"),
        (plan.notes, "note", "notes"),
        (plan.taskPlans, "planned task", "planned tasks"),
        (plan.studySessions, "focus session", "focus sessions"),
    ]
    var lines: [String] = []
    // A `for` over a list of tuples can name each part: `(e, one, many)`.
    for (e, one, many) in rows {
        var bits: [String] = []
        if e.added > 0 { bits.append("\(e.added) new") }
        if e.conflicting > 0 { bits.append("\(e.conflicting) updated") }
        if e.identical > 0 { bits.append("\(e.identical) already here") }
        if plan.mode == .replace && e.onlyHere > 0 { bits.append("\(e.onlyHere) removed") }
        if !bits.isEmpty {
            let total = e.added + e.conflicting + e.identical
            lines.append("\(total == 1 ? one : many): \(bits.joined(separator: ", "))")
        }
    }
    return lines.isEmpty ? ["Nothing in this file differs from what's here."] : lines
}

// MARK: - Clearing

/// What Clear all data names: "6 classes, 23 assignments and 14 grades",
/// or nil when there's nothing to clear. `clearSummary` in the web's settings,
/// with notes counted too, since they go as well (the web leaves them out).
func describeClear(classes: Int, assignments: Int, grades: Int, notes: Int) -> String? {
    let parts = [
        (classes, "class", "classes"),
        (assignments, "assignment", "assignments"),
        (grades, "grade", "grades"),
        (notes, "note", "notes"),
    ]
    .filter { $0.0 > 0 }
    .map { "\($0.0) \($0.0 == 1 ? $0.1 : $0.2)" }
    guard let last = parts.last else { return nil }
    if parts.count == 1 { return last }
    return parts.dropLast().joined(separator: ", ") + " and " + last
}

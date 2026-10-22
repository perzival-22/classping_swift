---
title: "Phase 11b+c: Backups, Recently Deleted and the calendar"
date: 2026-10-21
---

# Phase 11b+c: Backups, Recently Deleted and the calendar

The rest of Phase 11, as one guide because you asked for 11b and 11c
together (D-72). It builds on your committed `875fac8` ("timezonefix"): your
fourteen `Calendar.autoupdatingCurrent` changes are now in the reference too,
so the files below that you already have start from your versions.

**Your 11a check, recorded:** steps 4 to 9 all work (name, the appearance
lines, the scale card in Profile, the semester, Start a new term up to
Cancel). **Your D-69 answer, recorded:** the web keeps its "Starts in 1 day"
until the app is done (D-78). Every web fix found from now on goes on one
list in PROGRESS.md, "Web fixes for after the app", instead of a question.

**How this was made:** another session started this phase at 11:38 PM on the
20th and stopped before testing it or writing a guide. With your OK, this
guide took that draft over: it was reviewed line by line against the web,
fixed in five places, finished with the calendar export the draft had left
out, and given 116 new tests (D-72).

**Left for later:** the term setup sheet (the "When does your semester run?"
question the web asks after an import or your first class) moves to Phase 13,
next to the imports that suggest its dates. Your Semester card already sets
the dates (D-72).

**This is a big one:** eleven new files, about 2,600 lines, and five files
you already have, changed in a few places each. It's split into three stops.
At each stop the app builds and a test suite passes, so a typo shows up close
to where you made it.

**Start here:** Stop 1 (4.1 to 4.5), the logic: four new files, then copy
three test files and run `scripts/test-logic.sh`. Stop 2 (4.6 to 4.12),
models and store: three new files, three changed, two test files copied,
three words added to `scripts/test-store.sh`, and one line changed in your
own `CourseDeletionTests.swift`. Stop 3 (4.13 to 4.18), the screens:
four new files, two changed. Then section 5 on the phone.

**Verification (2026-10-21):** the reference iOS build passed with no
warnings. 506/506 logic tests passed in the default zone, New York, Kolkata,
London and Auckland (+86: `BackupTests` 39, `RecoveryTests` 10,
`CalendarExportTests` 37; every "web:" value was printed by the web's own
code in node, and two whole calendar files match the web's line for line).
108/108 reference store tests (+30: `BackupStoreTests` 18, `TrashStoreTests`
12), restoring a real backup file made by the web's `buildBackup`. The other
way round, a backup made by this phone's code was read by the web's own
`validateBackup`: valid, no warnings, and every item the two share has the
same content (section 3 lists the four small differences). The sixteen
file blocks laid over your tree are identical to the reference, and that
tree built with no warnings. Your own suites with the new tests and script
line, against the new source: 506/506 and 120/120, once the one line in
your `CourseDeletionTests.swift` is changed (4.12). Nothing
has been checked on the phone yet.

## 1. Goal

Your planner can leave the phone and come back: as a backup file the web can
read too, as a calendar file, and out of Recently Deleted.

**On your phone:** Profile tab → YOUR DATA → **Back up my data** saves
`classping-backup-2026-10-21.json` to Files. **Restore a backup** opens that
file and says, before anything changes, "Classes: 5 Already Here". Delete an
assignment, and **Recently Deleted** has it, with "30 days left" and Restore.

This phase includes:

- **Back up my data:** everything, deleted items and progress included, in
  the web's version-4 file format (D-66), saved where you choose in Files.
- **Restore a backup:** the file is checked first; a bad one only gets a
  reason. Then a preview, Merge or Replace, and the button. **Undo** sits in
  the bar afterwards until you close it.
- **Recently Deleted:** what you deleted in the last 30 days, newest first,
  with Restore and Delete now. A class comes back with exactly the work that
  went with it. After 30 days, items go for good when the app opens.
- **Clear all data:** names what would go, offers a backup first, and keeps
  your preferences.
- **Add to phone calendar:** your timetable and open work as `classping.ics`,
  through the share sheet, the way 9c shares the grade report.

## 2. New Swift concepts

### Files in and out: `.fileExporter` and `.fileImporter`

Both open the Files app's own sheet over your screen. `.fileExporter` saves a
file where you choose; it wants the file as a `FileDocument`, a small type
that knows its content type and hands over its bytes:

```swift
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

.fileExporter(isPresented: $exporting, document: backup, contentType: .json,
              defaultFilename: "classping-backup-2026-10-21") { result in … }
```

`.fileImporter` is the other direction. It gives back the address of the file
you picked, and because that file belongs to the Files app, not to ClassPing,
you say when you start and stop reading it. `defer` runs its block when the
function ends, however it ends, so the stop can't be forgotten:

```swift
.fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
    if case .success(let url) = result { open(url) }
}

func open(_ url: URL) {
    let reading = url.startAccessingSecurityScopedResource()
    defer { if reading { url.stopAccessingSecurityScopedResource() } }
    let data = try? Data(contentsOf: url)
}
```

### One type for any JSON: an enum that contains itself

A backup can hold anything, so it's read into a value that can be anything
JSON can be. Each case of an enum can carry a value of its own, and a case
can carry more of the same enum, so a list of values or a set of named values
fits too:

```swift
enum JSONValue: Codable, Hashable {
    case null, bool(Bool), number(Double), string(String)
    case array([JSONValue])             // a list of more values
    case object([String: JSONValue])    // names, each with a value
}
```

`Codable` usually writes itself. Here `init(from:)` is written by hand: it
tries each kind in turn with `try?`, and the first that fits wins. The
protocol allows a version that never throws, so there's no `do`/`catch`.

### Initializers that can say no: `init?`

A class read from a file might not have an id. An `init?` can fail: it gives
back nil instead of a value, and `compactMap` keeps only the ones it made:

```swift
extension Course {
    init?(web v: JSONValue) {
        guard let id = uuid(fromWebID: v["id"]?.stringValue) else { return nil }
        self.init(id: id, name: v["name"]?.stringValue ?? "", …)
    }
}

let courses = file.classes.compactMap(Course.init(web:))
```

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `BACKUP_VERSION`, `UNSUPPORTED_ON_PURPOSE`, `backupFilename`, `validateBackup`, `planRestore`, `applyRestore`'s merge, `describePlan` in `lib/backup.ts`; the clear summary in `app/settings/page.tsx` | `Logic/Backup.swift` (with `Logic/JSONValue.swift` for the file's raw values) |
| `RECOVERY_RETENTION_DAYS`, `EntityKind`, `TrashEntry`, `daysUntilPurge`, `isPurgeable` in `lib/recovery.ts`; the row's countdown in `app/settings/deleted/page.tsx` | `Logic/Recovery.swift` |
| `buildCalendarFile` and its helpers in `lib/calendar.ts` | `Logic/CalendarExport.swift` |
| `ClassItem`, `TaskItem`, `GradeItem`, `NoteItem`, `TaskPlan`, `StudySession`, `Profile` as a file writes them; `normalizeTask`, `normalizeNotes`, `normalizeTaskPlans`, `normalizeStudySessions` | `Models+Backup.swift` |
| `exportBackup`, `restoreBackup`, `preRestoreSnapshot`, `undoRestore`, `dismissRestoreSnapshot`, `clearData` in `lib/store.tsx` | `Store+Backup.swift` |
| `trash`, `restoreItems`, `purgeItems`, `emptyTrash` in `lib/store.tsx`; `buildTrash` in `lib/recovery.ts` | `Store+Trash.swift` |
| The restore half of `components/StatusChrome.tsx` | `Components/UndoBar.swift` |
| `components/RestoreSheet.tsx` | `Screens/Profile/RestoreSheet.swift` |
| `app/settings/deleted/page.tsx` | `Screens/Profile/RecentlyDeletedView.swift` |
| The backup rows of the Account card in `app/settings/page.tsx` | `Screens/Profile/DataSection.swift` |
| "Add to phone calendar" in the Reminders card; `downloadCalendarFile` | `Screens/Profile/CalendarCard.swift` |

Where the phone differs:

- **The preview compares with everything on the phone, Recently Deleted
  included (D-73).** The web's preview compares with live items only, so a
  deleted item shows as "new" and is then replaced anyway. Here the preview
  is the outcome.
- **Moments are whole seconds (D-73).** planner.json has always kept whole
  seconds, so a file's milliseconds are dropped as it's read; otherwise the
  same file would say "updated" after a relaunch. A tested case caught this.
- **Progress is kept, not shown (D-74).** Trophies, XP, your pet and the boss
  ride along in planner.json and in your backups; Phase 12 shows them.
- **The 30 days are enforced on the phone (D-75).** The web's server deletes
  for good each night; here it happens when the app opens. Deleting a class
  for good also removes its work's day plans, which the web leaves behind.
- **No cloud, no account, in the words (D-76):** "Saved on this device",
  "Keeps your preferences", and Clear counts your notes (they go too).
- **The calendar file is made on the phone, with no Pro check (D-77).** The
  web makes it on its server for Pro accounts. It's a Calendar card of its
  own, just after Reminders.

What the web reads in a phone backup (checked with its own code): every
shared item has the same content, apart from four things that don't matter.
A snooze and a note's last edit lose their milliseconds. A class with no
extra meetings says `"additionalMeetings": []` where an old web class said
nothing. An assignment of the default kind says `"kind": "assignment"`. The
web's preview will still call the items "updated", because it compares them
by the order of their fields. That's on the web-fixes list.

Web behavior kept on purpose: the file format and every check and message,
"1 item in this file have" included (D-76); Merge chosen to start with; the
restore's Undo staying until you close it; deleted items travelling in the
backup; the profile allowlist (no feeds, quotes or the term question); Clear
keeping the pet; two taps for Delete now and Empty; the 30-day countdown
rounding up.

## 4. Files, in the order to type them

### Stop 1: the logic

Four Foundation-only files in `Logic/`. None of them touches the screens, so
the app builds as before after each one.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/JSONValue.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/JSONValue.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   nothing on its own: it's how Swift holds the `unknown` values
//           lib/backup.ts reads before it trusts them
//
//  Summary: One type that can hold anything a JSON file holds: nothing,
//           true/false, a number, text, a list or a set of named values. A
//           backup file is read into this first, checked, and only then
//           turned into classes and assignments. Foundation only.
//

import Foundation

/// Any JSON value. The web reads a backup with `JSON.parse`, which gives back
/// `unknown`, and then checks each piece (`typeof x === "string"`). Swift has
/// no `unknown`, so this enum is the stand-in: each case is one kind of JSON
/// value and carries the value itself. A list holds more `JSONValue`s and an
/// object maps names to them, so one value can describe a whole file.
///
/// Hashable gives `==`, which compares two values piece by piece. Two
/// objects with the same names and values are equal whatever order the file
/// wrote them in. Sendable means it can be handed between threads safely.
enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)       // JSON has one number type; so does JavaScript
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Reads one value of any kind. `Codable` asks for an `init(from:)` that
    /// may throw, but a version that never throws is allowed to stand in for
    /// it, so there's no `do`/`catch` here. Each `try?` attempt either gives
    /// a value or nil, and the first kind that fits wins. Bool goes first
    /// because a JSON `true` must never be read as the number 1.
    init(from decoder: any Decoder) {
        guard let box = try? decoder.singleValueContainer() else {
            self = .null
            return
        }
        if box.decodeNil() {
            self = .null
        } else if let flag = try? box.decode(Bool.self) {
            self = .bool(flag)
        } else if let number = try? box.decode(Double.self) {
            self = .number(number)
        } else if let text = try? box.decode(String.self) {
            self = .string(text)
        } else if let list = try? box.decode([JSONValue].self) {
            self = .array(list)
        } else if let object = try? box.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            self = .null
        }
    }

    /// Writes the value back out, the same way round: never throws, and a
    /// value the encoder refuses (it won't happen for these kinds) is left out.
    func encode(to encoder: any Encoder) {
        var box = encoder.singleValueContainer()
        switch self {
        case .null: try? box.encodeNil()
        case .bool(let flag): try? box.encode(flag)
        case .number(let number): try? box.encode(number)
        case .string(let text): try? box.encode(text)
        case .array(let list): try? box.encode(list)
        case .object(let object): try? box.encode(object)
        }
    }
}

// MARK: - Reading a value

extension JSONValue {
    /// The value under `key` when this is an object, otherwise nil. Lets the
    /// readers write `item["title"]`, like the web's `t.title`.
    subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    /// The text, when this is text. `typeof v === "string" ? v : …`.
    /// `if case` checks one case of an enum and pulls its value out.
    var stringValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }

    /// The number, when this is a number that isn't infinity or NaN.
    /// `Number.isFinite(v)` on the web.
    var numberValue: Double? {
        if case .number(let number) = self, number.isFinite { return number }
        return nil
    }

    /// The number when it's a whole one, like `Number.isInteger(v)`:
    /// 600 gives 600, 600.5 and "600" give nil. `Int(exactly:)` refuses
    /// anything with a fraction or too big for an Int.
    var intValue: Int? {
        numberValue.flatMap { Int(exactly: $0) }
    }

    /// true or false, when this is one. `v === true` is `boolValue == true`.
    var boolValue: Bool? {
        if case .bool(let flag) = self { return flag }
        return nil
    }

    /// The list, when this is one. `Array.isArray(v) ? v : …`.
    var arrayValue: [JSONValue]? {
        if case .array(let list) = self { return list }
        return nil
    }

    /// The named values, when this is an object (not a list, not null).
    /// The web's `isObj`.
    var objectValue: [String: JSONValue]? {
        if case .object(let object) = self { return object }
        return nil
    }
}

// MARK: - Making a value

extension JSONValue {
    /// A whole number as a JSON number: `.int(600)`. Lists of numbers read
    /// well this way: `days.map(JSONValue.int)`.
    static func int(_ number: Int) -> JSONValue {
        .number(Double(number))
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/Backup.swift` (new file)

```swift
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
```

### 4.3 `~/ClassPing/Sources/ClassPing/Logic/Recovery.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Recovery.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/recovery.ts (RECOVERY_RETENTION_DAYS, EntityKind,
//           TrashEntry, daysUntilPurge, isPurgeable) and the countdown line
//           of app/settings/deleted/page.tsx
//
//  Summary: The rules of Recently Deleted: a deleted item waits 30 days,
//           then it's gone for good. This file knows how long is left, what
//           one row of the list holds, and the order rows go in. Foundation
//           only, so the Linux tests can run it.
//

import Foundation

/// How long a deleted item can still be restored. `RECOVERY_RETENTION_DAYS`.
/// The web's server purges at the same age, so the two must stay equal.
let RECOVERY_RETENTION_DAYS = 30

/// The same window in seconds, the unit `Date` arithmetic uses.
/// The web counts in real 24-hour days (`86_400_000` ms), not calendar days,
/// so this does too.
let RECOVERY_RETENTION: TimeInterval = Double(RECOVERY_RETENTION_DAYS) * 86_400

/// The four kinds of thing that can be deleted. `EntityKind` in
/// lib/recovery.ts. The raw values are the web's words; Swift won't take
/// `class` as a case name, so that case is `course` with the raw value "class".
enum EntityKind: String, CaseIterable, Sendable {
    case course = "class"
    case assignment = "task"
    case grade
    case note

    /// The word on a Recently Deleted row. `KIND_META` in the web's page.
    var label: String {
        switch self {
        case .course: "Class"
        case .assignment: "Assignment"
        case .grade: "Grade"
        case .note: "Note"
        }
    }
}

/// One row of Recently Deleted. `TrashEntry` in lib/recovery.ts.
struct TrashEntry: Identifiable, Equatable, Sendable {
    let kind: EntityKind
    /// The deleted item's own id.
    let itemID: UUID
    /// What you'll recognise it by: the class name, the assignment's title.
    let title: String
    /// The class it belonged to, or a class's term, when there is one.
    let detail: String?
    let deletedAt: Date
    /// True when it went with its class. Restoring the class brings it back
    /// too, and the row says so instead of offering a Restore of its own.
    let viaClass: Bool

    /// Unique across kinds, as the web's React key `kind:id` is.
    var id: String { "\(kind.rawValue):\(itemID.uuidString)" }
}

/// Whole days left before a deleted item is gone, 0 meaning "today".
/// `daysUntilPurge`: what's left of the 30 days, rounded up, never below 0.
func daysUntilPurge(_ deletedAt: Date, now: Date) -> Int {
    let left = RECOVERY_RETENTION - now.timeIntervalSince(deletedAt)
    return max(0, Int((left / 86_400).rounded(.up)))
}

/// True once the 30 days are over. `isPurgeable`.
func isPurgeable(_ deletedAt: Date, now: Date) -> Bool {
    now.timeIntervalSince(deletedAt) >= RECOVERY_RETENTION
}

/// The countdown at the end of a row: "12 days left", "1 day left", or
/// "Deleted for good today". From `TrashRow` in the web's page.
func purgeLine(_ deletedAt: Date, now: Date) -> String {
    let left = daysUntilPurge(deletedAt, now: now)
    return left == 0 ? "Deleted for good today" : "\(left) \(left == 1 ? "day" : "days") left"
}

/// Newest first, the order `buildTrash` gives. A class and the work that
/// went with it share one moment, so ties go class, assignment, grade, note
/// (the web's order of adding them), then by title, so the list never
/// shuffles between two looks.
func sortTrash(_ entries: [TrashEntry]) -> [TrashEntry] {
    // `allCases` lists the kinds in the order they're written above, and
    // `firstIndex(of:)` gives each one's place in that list.
    let order = EntityKind.allCases
    return entries.sorted { a, b in
        if a.deletedAt != b.deletedAt { return a.deletedAt > b.deletedAt }
        let ka = order.firstIndex(of: a.kind) ?? 0
        let kb = order.firstIndex(of: b.kind) ?? 0
        if ka != kb { return ka < kb }
        return a.title.localizedCompare(b.title) == .orderedAscending
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Logic/CalendarExport.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/CalendarExport.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/calendar.ts (buildCalendarFile and its helpers)
//
//  Summary: Writes your timetable and open deadlines as an iCalendar (.ics)
//           file, the format every calendar app can import. Each class repeats
//           weekly inside the term, with its alarms; each dated piece of open
//           work gets an event, and a warning if its reminder is on. Times are
//           "floating" (no time zone), so a calendar reads them as local time.
//           Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - What goes in

/// A class the calendar file can describe. It builds on `Alarmable` (7a),
/// which already gives the name, the alarm switch, `remindBefore` and the
/// meetings, and adds the three details the file writes. `Course` signs up
/// in Models+Reminders.swift. Open work needs nothing new: `Remindable` (7a)
/// already has the title, deadline, kind, `done` and `reminder`.
protocol CalendarClass: Alarmable {
    var instructor: String? { get }
    var notes: String? { get }
    var extraReminders: [Int] { get }
}

/// The semester as two "yyyy-MM-dd" days, either of which may be missing.
/// `TermWindow` in lib/calendar.ts. A half-set term still bounds its half.
struct TermWindow: Equatable {
    var start: String?
    var end: String?
}

// MARK: - Building the file

/// The whole .ics file as text. `buildCalendarFile`. `className` names the
/// class a piece of work belongs to (nil for Inbox work), `now` is "today"
/// for the weekly rules and the file's stamp, and `term` stops the
/// timetable at the end of the semester.
func buildCalendarFile<C: CalendarClass, T: Remindable>(
    _ classes: [C], _ tasks: [T], className: (UUID?) -> String?,
    now: Date, term: TermWindow? = nil
) -> String {
    // When the file was made, in UTC: "20261021T030405Z". Every event carries it.
    let stamp = utcStamp(now)
    let range = termRange(term)

    // The header every calendar file starts with.
    var lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//ClassPing//Timetable//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-CALNAME:ClassPing",
    ]
    // One weekly event per meeting (a lab is its own event), then one event
    // per open, dated piece of work. Each helper gives back no lines for
    // something that doesn't belong in the file, so nothing is skipped by hand.
    for slot in expandClassMeetings(classes) {
        lines += classEvent(slot, stamp: stamp, now: now, range: range)
    }
    for task in tasks {
        lines += taskEvent(task, stamp: stamp, className: className)
    }
    lines.append("END:VCALENDAR")

    // Long lines folded, every line ended with CR LF, as RFC 5545 asks.
    return lines.map(foldICS).joined(separator: "\r\n") + "\r\n"
}

/// The lines for one meeting of one class, or none: none when it meets on
/// no day, or when the whole term is already behind us.
private func classEvent<C: CalendarClass>(
    _ slot: MeetingSlot<C>, stamp: String, now: Date, range: (from: Date?, until: Date?)?
) -> [String] {
    let c = slot.course
    let m = slot.meeting
    guard !m.days.isEmpty else { return [] }

    // Start at the first meeting inside the term: its opening week before
    // the semester begins, otherwise from today.
    let anchor = range?.from.flatMap { $0 > now ? $0 : nil } ?? now
    let start = nextMeeting(m.days, m.start, after: anchor)
    if let until = range?.until, start > until { return [] }
    let end = atMinute(start, m.end)

    // "MO,WE". `byDay.indices.contains` keeps a bad day number from crashing.
    let byday = m.days.sorted()
        .filter { byDay.indices.contains($0) }
        .map { byDay[$0] }
        .joined(separator: ",")
    // UNTIL is floating local time, like DTSTART: RFC 5545 wants the two to
    // agree, and a UTC "Z" here could add or drop the last week.
    let until = range?.until.map { ";UNTIL=\(icsLocal($0))" } ?? ""

    // The meeting's key, lower case, so the UID is the one the web writes
    // for the same class: re-importing then updates instead of duplicating.
    var lines = [
        "BEGIN:VEVENT",
        "UID:classping-class-\(meetingKey(slot).lowercased())@classping",
        "DTSTAMP:\(stamp)",
        "DTSTART:\(icsLocal(start))",
        "DTEND:\(icsLocal(end))",
        "RRULE:FREQ=WEEKLY;BYDAY=\(byday)\(until)",
        "SUMMARY:\(escapeICS(c.name))",
    ]
    // The room becomes a tappable place on the phone. An empty one is none.
    if let room = m.room, !room.isEmpty {
        lines.append("LOCATION:\(escapeICS(room))")
    }
    // The teacher and your notes about the class, on two lines of one field.
    let detail = [c.instructor.flatMap { $0.isEmpty ? nil : "With \($0)" },
                  c.notes.flatMap { $0.isEmpty ? nil : $0 }]
        .compactMap { $0 }
    if !detail.isEmpty {
        lines.append("DESCRIPTION:\(escapeICS(detail.joined(separator: "\n")))")
    }
    // One alarm per distinct lead time, the earliest heads-up first.
    // `Set` drops a lead given twice; `sorted(by: >)` puts the biggest first.
    if c.alarm {
        for mins in Set([c.remindBefore] + c.extraReminders).sorted(by: >) {
            lines += [
                "BEGIN:VALARM",
                "ACTION:DISPLAY",
                "TRIGGER:-PT\(mins)M",
                "DESCRIPTION:\(escapeICS("\(c.name) starts in \(alarmLead(mins))"))",
                "END:VALARM",
            ]
        }
    }
    lines.append("END:VEVENT")
    return lines
}

/// The lines for one piece of work, or none when it's done or has no day
/// (Inbox work has nowhere to go on a calendar).
private func taskEvent<T: Remindable>(
    _ t: T, stamp: String, className: (UUID?) -> String?
) -> [String] {
    guard !t.done, let due = dueAt(t) else { return [] }
    let isExam = t.kindName == "exam"
    // An exam blocks out a sitting; anything else is a short marker.
    let end = due.addingTimeInterval(Double(isExam ? 90 : 30) * 60)

    var lines = [
        "BEGIN:VEVENT",
        "UID:classping-task-\(webID(t.id))@classping",
        "DTSTAMP:\(stamp)",
        "DTSTART:\(icsLocal(due))",
        "DTEND:\(icsLocal(end))",
        "SUMMARY:\(escapeICS(isExam ? "📝 \(t.title)" : "\(t.title) due"))",
    ]
    if let name = className(t.courseID), !name.isEmpty {
        lines.append("DESCRIPTION:\(escapeICS(name))")
    }
    // With its reminder on: a day's warning, and a week's too for an exam.
    if t.reminder {
        let warnings = isExam
            ? [("-P7D", "in a week"), ("-PT24H", "in 24 hours")]
            : [("-PT24H", "in 24 hours")]
        for (trigger, label) in warnings {
            lines += [
                "BEGIN:VALARM",
                "ACTION:DISPLAY",
                "TRIGGER:\(trigger)",
                "DESCRIPTION:\(escapeICS("\(t.title) is \(isExam ? "" : "due ")\(label)"))",
                "END:VALARM",
            ]
        }
    }
    lines.append("END:VEVENT")
    return lines
}

// MARK: - Helpers

/// The weekday codes, Monday first, matching ClassPing's 0 = Monday. `BYDAY`.
private let byDay = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

/// The term as two moments: its first day's midnight and its last day at
/// 11:59 PM. Nil when neither day is set, or when the end comes before the
/// start (a typo, not a term). `resolveWindow`.
private func termRange(_ term: TermWindow?) -> (from: Date?, until: Date?)? {
    // `dayStart` (11a) is local midnight of a real "yyyy-MM-dd", else nil.
    let from = dayStart(term?.start)
    let lastDay = dayStart(term?.end)
    if let from, let lastDay, lastDay < from { return nil }
    if from == nil && lastDay == nil { return nil }
    return (from, lastDay.map { atMinute($0, 23 * 60 + 59) })
}

/// The first day from `base` on (today counts) that is one of `days`, at the
/// class's start time. `nextOccurrence`. A `while` with a counter looks at
/// most seven days ahead, as the web's loop does.
private func nextMeeting(_ days: [Int], _ startMin: Int, after base: Date) -> Date {
    let cal = Calendar.autoupdatingCurrent
    var day = base
    var looked = 0
    while looked < 7 && !days.contains(dayIndex(of: day)) {
        day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        looked += 1
    }
    // `atMinute` (7a) sets the clock time on that day, safe across a
    // daylight-saving change.
    return atMinute(day, startMin)
}

/// "1 day", "3 hours", "15 minutes", the words in a class alarm.
/// `leadLabel` in lib/calendar.ts, which spells minutes out in full
/// (Logic/Reminders.swift has its own `leadLabel`, which says "min").
private func alarmLead(_ mins: Int) -> String {
    if mins % 1440 == 0 {
        let d = mins / 1440
        return "\(d) day\(d == 1 ? "" : "s")"
    }
    if mins % 60 == 0 {
        let h = mins / 60
        return "\(h) hour\(h == 1 ? "" : "s")"
    }
    return "\(mins) minute\(mins == 1 ? "" : "s")"
}

/// A moment as floating local time, seconds always 00: "20261021T093000".
/// `fmtLocal`.
private func icsLocal(_ d: Date) -> String {
    let c = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    return String(format: "%04d%02d%02dT%02d%02d00",
                  c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
}

/// A moment in UTC with a "Z": "20261021T030405Z". `fmtUtcNow`, except that
/// it stamps the `now` it's given, so the tests can predict it.
private func utcStamp(_ d: Date) -> String {
    var utc = Calendar(identifier: .gregorian)
    // `?? .current` can't happen (UTC always exists); it keeps this crash-free.
    utc.timeZone = TimeZone(identifier: "UTC") ?? .current
    let c = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
    return String(format: "%04d%02d%02dT%02d%02d%02dZ",
                  c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
}

/// Text made safe for a calendar field: a backslash, semicolon or comma gets
/// a backslash in front, and a line break becomes the two characters `\n`.
/// `esc`. The backslash goes first, or it would double the others' escapes.
/// "\r\n" is replaced before "\n" because Swift counts "\r\n" as a single
/// character, which a search for "\n" alone wouldn't find.
func escapeICS(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: ";", with: "\\;")
        .replacingOccurrences(of: ",", with: "\\,")
        .replacingOccurrences(of: "\r\n", with: "\\n")
        .replacingOccurrences(of: "\n", with: "\\n")
}

/// Splits a line longer than 74 into pieces, each continuation starting with
/// a space (RFC 5545 section 3.1). `fold`. The web counts JavaScript string
/// units (UTF-16), so this does too, on `line.utf16`. An emoji is two of those
/// units, and a cut between them would break it, so such a cut moves one
/// unit earlier.
func foldICS(_ line: String) -> String {
    let units = Array(line.utf16)
    guard units.count > 74 else { return line }
    var pieces: [String] = []
    var start = 0
    var width = 74   // the first piece; each continuation has 73 plus its space
    while units.count - start > width {
        var end = start + width
        if UTF16.isTrailSurrogate(units[end]) { end -= 1 }
        pieces.append(String(decoding: units[start..<end], as: UTF16.self))
        start = end
        width = 73
    }
    pieces.append(String(decoding: units[start...], as: UTF16.self))
    // `dropFirst` skips the first piece, which keeps no leading space.
    return ([pieces[0]] + pieces.dropFirst().map { " " + $0 }).joined(separator: "\r\n")
}

/// What the Calendar card says under its button: the web's footer line.
/// "Exports 5 classes and 3 open assignments. Re-add after you change your
/// schedule." Undated open work counts, as on the web, though it has no day
/// to go on.
func calendarSummary(classes: Int, openTasks: Int) -> String {
    if classes == 0 && openTasks == 0 { return "Add a class or assignment first." }
    return "Exports \(classes) \(classes == 1 ? "class" : "classes") and \(openTasks) open \(openTasks == 1 ? "assignment" : "assignments"). Re-add after you change your schedule."
}
```

### 4.5 Stop 1 check: the logic tests (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/BackupTests.swift $R/Logic/RecoveryTests.swift $R/Logic/CalendarExportTests.swift Tests/Logic/
scripts/test-logic.sh     # expect 506 tests passing
xtool dev build
```

A failure here points at 4.1 to 4.4. The calendar tests compare a whole file
with the web's, line by line, so a missing escape or a wrong time shows
exactly which line differs.

### Stop 2: the models and the store

Three new files and three changed ones. 4.9 and 4.10 need each other (each
calls something the other adds), so build after 4.11, not in between.

### 4.6 `~/ClassPing/Sources/ClassPing/Models+Reminders.swift` (replaces your 7b file: one sign-up added)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Models+Reminders.swift
//  Phase:   7a (reminders ring), changed in 7b (StudySession) and 11b+c
//           (the calendar file)
//  Ports:   nothing new: it connects the models to Logic/Reminders.swift,
//           Logic/ReminderPlan.swift, since 7b Logic/Planning.swift and,
//           since 11b+c, Logic/CalendarExport.swift
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

/// Course also has `instructor`, `notes` and `extraReminders`, the three
/// details the calendar file writes, so the calendar can read it too.
// NEW in Phase 11b+c
extension Course: CalendarClass {}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Models+Backup.swift` (new file)

```swift
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
```

### 4.8 `~/ClassPing/Sources/ClassPing/Store.swift` (replaces your timezonefix file: two properties added)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store.swift
//  Ports:   lib/store.tsx (the shared state) and the sample week from your designs
//
//  Summary: The one place the app's data lives while it runs, plus a sample
//           store to show until you add your own classes. Since 7c it also
//           holds where a tapped notification wants to take you, and since
//           11b+c your progress from a backup and the copy a restore can undo.
//


import Foundation
import Observation

/// The single place your app's data lives while it runs.
/// @Observable: any screen showing this data redraws by itself when it changes.
/// @MainActor: only used from the main (UI) thread, which Swift 6 checks for you.
@MainActor @Observable
final class Store {
    var courses: [Course] = []           // every class you take
    var assignments: [Assignment] = []   // every assignment, open or done
    var grades: [Grade] = []             // NEW in Phase 1
    var notes: [Note] = []               // NEW in Phase 1
    var taskPlans: [TaskPlan] = []       // NEW in Phase 1
    var studySessions: [StudySession] = [] // NEW in Phase 1
    var profile = Profile()

    /// Trophies, XP, your pet and the weekly boss, exactly as a backup had
    /// them. Nothing shows them until Phase 12; keeping them means a web
    /// backup that passes through the phone loses nothing (D-74).
    var game = GameBlobs()               // NEW in Phase 11b+c

    /// True when the last save to the phone failed. The screens must say so,
    /// because "Saved on this device" has to be true when the app claims it.
    var lastSaveFailed = false           // NEW in Phase 1

    /// The latest assignment, class or note deletion, available to undo this session.
    var pendingUndo: PendingUndo? = nil

    /// Where the app should go next: set by a tapped notification or by
    /// Today's "Log it", taken by RootView, which goes there and sets it back
    /// to nil. Never saved: a tap is about now, not the next launch.
    var route: AppRoute? = nil           // NEW in Phase 7c

    /// Everything as it was just before the last backup restore, so the Undo
    /// bar can put it back exactly. Kept only while the app runs, like the
    /// web's `preRestoreSnapshot`; nil when there's nothing to undo.
    var preRestore: PlannerDocument? = nil   // NEW in Phase 11b+c
}

extension Store {
    /// A launch or background tap waits for the screen to become active.
    /// Clear only a consumed route, so tapping the same reminder works again.
    func takeRoute(whenActive isActive: Bool) -> AppRoute? {
        guard isActive, let route else { return nil }
        self.route = nil
        return route
    }


    /// A store filled with the classes and assignments from your design screens 02 and 06.
    /// The app uses it until you add your own. End times are made up.
    static var sample: Store {
        // Times are minutes from midnight: 510 = 8:30 AM, 560 = 9:20 AM.
        // CHANGED in Phase 1: colors are names now, not hex codes.
        let calc = Course(name: "Calculus III", short: "Calc", color: .coral,
                          days: [0, 2, 4], startMin: 510, endMin: 560)
        let ml = Course(name: "Foundations of Machine Learning", short: "ML", color: .indigo,
                        days: [0, 2], startMin: 600, endMin: 680, remindBefore: 15, room: "Friend 101")
        let poli = Course(name: "Modern Political Theory", short: "Poli", color: .teal,
                          days: [0, 2], startMin: 810, endMin: 885)
        let ochem = Course(name: "Organic Chemistry II", short: "OChem", color: .ocean,
                           days: [1, 3], startMin: 540, endMin: 615)
        let psych = Course(name: "Introduction to Psychology", short: "Psych", color: .amber,
                           days: [1, 3], startMin: 900, endMin: 975)


        let store = Store()
        store.courses = [calc, ml, poli, ochem, psych]
        // Each assignment points at its class through that class's id.
        store.assignments = [
            Assignment(courseID: ochem.id, title: "Lab report: Aldol condensation", due: day(1)),
            Assignment(courseID: ml.id, title: "Problem Set 4", due: day(2)),
            Assignment(courseID: poli.id, title: "Reading response: Rawls, Ch. 3", due: day(3), reminder: true),
            Assignment(courseID: calc.id, title: "Midterm study guide", due: day(-2), done: true),
            Assignment(courseID: psych.id, title: "Reflection journal", due: day(-1), done: true),
            // NEW in Phase 1: an exam with an exact time, and an undated Inbox item.
            Assignment(courseID: calc.id, title: "Midterm 2", due: day(5), dueTime: "10:00", kind: .exam),
            Assignment(title: "Email advisor about spring classes"),
        ]
        return store
    }

    /// The date `offset` days from today, as "yyyy-MM-dd": day(1) is tomorrow, day(-1) yesterday.
    private static func day(_ offset: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   // same format whatever your phone's language
        f.dateFormat = "yyyy-MM-dd"
        let date = Calendar.autoupdatingCurrent.date(byAdding: .day, value: offset, to: .now) ?? .now
        return f.string(from: date)
    }
}
```

### 4.9 `~/ClassPing/Sources/ClassPing/Store+Trash.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Trash.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   lib/store.tsx (trash, restoreItems, purgeItems, emptyTrash)
//           and lib/recovery.ts (buildTrash)
//
//  Summary: Recently Deleted: the list, bringing something back, deleting
//           it for good now, emptying the lot, and the 30-day clear-out when
//           the app opens. Deleting for good also unhooks what pointed at the
//           item, so no plan or note is left pointing at nothing.
//

import Foundation

extension Store {
    // MARK: - The list

    /// Everything in Recently Deleted, newest first. `buildTrash`. A class's
    /// name is looked up among all classes, deleted ones included, so work
    /// that went with its class still says which class it was.
    var trash: [TrashEntry] {
        let deletedCourses = Set(courses.filter { $0.deletedAt != nil }.map(\.id))
        let names = Dictionary(courses.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        /// The class an item belonged to: its name, and whether it's deleted
        /// too (then the item went with it). A function inside a property is
        /// fine in Swift; nothing outside can see it.
        func parent(_ courseID: UUID?) -> (name: String?, gone: Bool) {
            guard let courseID else { return (nil, false) }
            return (names[courseID], deletedCourses.contains(courseID))
        }

        var rows: [TrashEntry] = []
        for c in courses {
            if let at = c.deletedAt {
                rows.append(TrashEntry(kind: .course, itemID: c.id, title: c.name,
                                       detail: c.term, deletedAt: at, viaClass: false))
            }
        }
        for a in assignments {
            if let at = a.deletedAt {
                let owner = parent(a.courseID)
                rows.append(TrashEntry(kind: .assignment, itemID: a.id, title: a.title,
                                       detail: owner.name, deletedAt: at, viaClass: owner.gone))
            }
        }
        for g in grades {
            if let at = g.deletedAt {
                let owner = parent(g.courseID)
                rows.append(TrashEntry(kind: .grade, itemID: g.id, title: g.title,
                                       detail: owner.name, deletedAt: at, viaClass: owner.gone))
            }
        }
        for n in notes {
            if let at = n.deletedAt {
                let owner = parent(n.courseID)
                let title = n.title.trimmingCharacters(in: .whitespacesAndNewlines)
                rows.append(TrashEntry(kind: .note, itemID: n.id,
                                       title: title.isEmpty ? "Untitled note" : title,
                                       detail: owner.name, deletedAt: at, viaClass: owner.gone))
            }
        }
        return sortTrash(rows)
    }

    // MARK: - Bringing back

    /// Puts a deleted item back. `restoreItems`. A class comes back with the
    /// work deleted at the same moment (Phase 6b's `restoreCourse`), not with
    /// something you'd deleted on its own before. False when the write failed;
    /// then it stays in Recently Deleted.
    @discardableResult
    func restoreFromTrash(_ entry: TrashEntry) -> Bool {
        let before = document
        let id = entry.itemID
        switch entry.kind {
        case .course:
            restoreCourse(id)
        case .assignment:
            if let i = assignments.firstIndex(where: { $0.id == id }) { assignments[i].deletedAt = nil }
        case .grade:
            if let i = grades.firstIndex(where: { $0.id == id }) { grades[i].deletedAt = nil }
        case .note:
            if let i = notes.firstIndex(where: { $0.id == id }) { notes[i].deletedAt = nil }
        }
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }

    // MARK: - Deleting for good

    /// Deletes one item for good, now. `purgeItems`. A class takes all its
    /// work with it, as on the web, since nothing can belong to a class
    /// that's gone.
    @discardableResult
    func purgeFromTrash(_ entry: TrashEntry) -> Bool {
        let one: Set<UUID> = [entry.itemID]
        let before = document
        switch entry.kind {
        case .course: purge(courses: one)
        case .assignment: purge(assignments: one)
        case .grade: purge(grades: one)
        case .note: purge(notes: one)
        }
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }

    /// Empties Recently Deleted. `emptyTrash`. No Undo; the screen asks first.
    @discardableResult
    func emptyTrash() -> Bool {
        let before = document
        purge(courses: Set(courses.filter { $0.deletedAt != nil }.map(\.id)),
              assignments: Set(assignments.filter { $0.deletedAt != nil }.map(\.id)),
              grades: Set(grades.filter { $0.deletedAt != nil }.map(\.id)),
              notes: Set(notes.filter { $0.deletedAt != nil }.map(\.id)))
        save()
        if lastSaveFailed {
            replaceAll(with: before)
            return false
        }
        return true
    }

    /// Deletes for good whatever has waited 30 days. The web leaves this to
    /// its server each night; there's no server yet, so the phone does it
    /// when the app opens (D-75). It saves only when something went.
    func purgeExpired(now: Date) {
        // The ids of deleted items whose 30 days are up.
        func expired<T: Identifiable>(_ items: [T], _ deletedAt: (T) -> Date?) -> Set<T.ID> {
            Set(items.filter { item in deletedAt(item).map { isPurgeable($0, now: now) } ?? false }.map(\.id))
        }
        let oldCourses = expired(courses) { $0.deletedAt }
        let oldAssignments = expired(assignments) { $0.deletedAt }
        let oldGrades = expired(grades) { $0.deletedAt }
        let oldNotes = expired(notes) { $0.deletedAt }
        guard !(oldCourses.isEmpty && oldAssignments.isEmpty && oldGrades.isEmpty && oldNotes.isEmpty)
        else { return }
        purge(courses: oldCourses, assignments: oldAssignments, grades: oldGrades, notes: oldNotes)
        save()
    }

    /// The one place things are deleted for good. It removes the items and
    /// whatever belongs to a removed class, then unhooks what pointed at them:
    /// a removed assignment's day plan goes, and study sessions and notes
    /// that named it (or a removed class) forget the link but stay. The
    /// default `[]` lets each caller name only the kinds it has.
    private func purge(courses goneCourses: Set<UUID> = [], assignments goneTasks: Set<UUID> = [],
                       grades goneGrades: Set<UUID> = [], notes goneNotes: Set<UUID> = []) {
        // A removed class's work goes with it: `belongs` says whether an item
        // points at one. `union` joins two sets.
        let belongs: (UUID?) -> Bool = { id in id.map { goneCourses.contains($0) } ?? false }
        let tasks = goneTasks.union(assignments.filter { belongs($0.courseID) }.map(\.id))
        let marks = goneGrades.union(grades.filter { belongs($0.courseID) }.map(\.id))
        let pages = goneNotes.union(notes.filter { belongs($0.courseID) }.map(\.id))

        assignments.removeAll { tasks.contains($0.id) }
        grades.removeAll { marks.contains($0.id) }
        notes.removeAll { pages.contains($0.id) }
        courses.removeAll { goneCourses.contains($0.id) }
        taskPlans.removeAll { tasks.contains($0.assignmentID) }

        // Unhook links to what's gone, keeping the items that held them.
        for i in studySessions.indices {
            if let task = studySessions[i].assignmentID, tasks.contains(task) { studySessions[i].assignmentID = nil }
            if belongs(studySessions[i].courseID) { studySessions[i].courseID = nil }
        }
        for i in notes.indices {
            if let task = notes[i].assignmentID, tasks.contains(task) { notes[i].assignmentID = nil }
        }

        // An Undo offer for something that's gone has nothing to bring back.
        // `case .a(let id), .b(let id)` matches any of these cases and names
        // the id each one carries the same way.
        if let undo = pendingUndo {
            let id: UUID
            switch undo.item {
            case .assignment(let x), .course(let x), .note(let x), .grade(let x): id = x
            }
            if tasks.contains(id) || marks.contains(id) || pages.contains(id) || goneCourses.contains(id) {
                pendingUndo = nil
            }
        }
    }
}
```

### 4.10 `~/ClassPing/Sources/ClassPing/Store+Persistence.swift` (replaces your Phase 1 file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Persistence.swift
//  Phase:   1 (save and load), changed in 11b+c (progress, replaceAll,
//           and Recently Deleted's 30 days)
//  Ports:   lib/store.tsx (the localStorage cache, key "classping.v1:<user>")
//
//  Summary: Saves everything to Documents/planner.json after each change and
//           reads it back when the app opens. A file that can't be read is set
//           aside, never overwritten, so a bug can't erase users planner.
//           Since 11b+c opening the app also clears out deleted items older
//           than 30 days.
//
import Foundation

/// Everything that gets saved, in one value. Codable turns it into JSON and back.
/// Rule for later phases: a property added here (or to any model) must be
/// Optional, or old files on the phone won't load. Optional properties that are
/// missing from the file simply come back as nil.
// CHANGED in Phase 11b+c: Equatable, so a test can check an Undo put back
// exactly what was there.
struct PlannerDocument: Codable, Equatable {
    var courses: [Course]
    var assignments: [Assignment]
    var grades: [Grade]
    var notes: [Note]
    var taskPlans: [TaskPlan]
    var studySessions: [StudySession]
    var profile: Profile
    /// Progress from a backup (D-74). Optional, by the rule above: every
    /// planner.json saved before 11b+c has no `game`, and still loads.
    var game: GameBlobs?                 // NEW in Phase 11b+c
}

extension Store {
    /// The app's private Documents folder on the phone. Deleting the app deletes
    /// this folder too, which is how you reset to the sample.
    /// `urls(for:in:)` gives back a list; `.first` takes its only entry, and
    /// `?? temporaryDirectory` is a fallback so this can never crash.
    static var documentsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Where the planner is saved.
    static var fileURL: URL {
        documentsFolder.appending(path: "planner.json")
    }

    /// Where an unreadable planner.json is moved, so nothing ever writes over it.
    static var unreadableURL: URL {
        documentsFolder.appending(path: "planner.unreadable.json")
    }

    /// The store's contents packed into one saveable value.
    // CHANGED in Phase 11b+c: progress goes in too, when there is some.
    var document: PlannerDocument {
        PlannerDocument(courses: courses, assignments: assignments, grades: grades,
                        notes: notes, taskPlans: taskPlans, studySessions: studySessions,
                        profile: profile, game: game.isEmpty ? nil : game)
    }

    /// Puts a whole saved planner into the store: what opening the app does,
    /// and what undoing a restore or a failed save does. The other half of
    /// `document`.
    // NEW in Phase 11b+c (it used to be written out inside `load()`)
    func replaceAll(with saved: PlannerDocument) {
        courses = saved.courses
        assignments = saved.assignments
        grades = saved.grades
        notes = saved.notes
        taskPlans = saved.taskPlans
        studySessions = saved.studySessions
        profile = saved.profile
        game = saved.game ?? GameBlobs()
    }

    /// Writes the planner to the phone. Call it after every change, before any
    /// network call: that's what makes "Saved on this device" honest.
    func save() {
        // Set up the encoder. Dates become text like "2026-10-13T20:00:00Z".
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // readable if you open the file

        // `try?` turns a failure into nil instead of crashing (no do/catch needed).
        // `guard let ... else` leaves the function early when encoding fails.
        guard let data = try? encoder.encode(document) else {
            lastSaveFailed = true
            return
        }

        // `.atomic` writes to a temporary file first and swaps it in, so a crash
        // mid-save can't leave half a file. The write gives back nil on failure.
        let written = (try? data.write(to: Store.fileURL, options: .atomic)) != nil
        lastSaveFailed = !written
    }

    /// Builds the store when the app opens: your saved planner if there is one,
    /// otherwise the sample.
    static func load() -> Store {
        // No file yet (first launch): start from the sample.
        guard let data = try? Data(contentsOf: fileURL) else {
            return .sample
        }

        // Read the JSON back into a PlannerDocument.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let saved = try? decoder.decode(PlannerDocument.self, from: data) else {
            // The file exists but can't be read. Treating that as "empty" is how
            // planners get wiped (the web app's backup rules say the same). Move it
            // aside first, replacing any older unreadable copy, then use the sample.
            try? FileManager.default.removeItem(at: unreadableURL)
            try? FileManager.default.moveItem(at: fileURL, to: unreadableURL)
            return .sample
        }

        // Copy the saved planner into a fresh store.
        // CHANGED in Phase 11b+c: one call instead of a line per list.
        let store = Store()
        store.replaceAll(with: saved)
        // NEW in Phase 11b+c: anything deleted over 30 days ago goes for good
        // now (Store+Trash.swift), as the web's server does each night.
        store.purgeExpired(now: .now)
        return store
    }
}
```

### 4.11 `~/ClassPing/Sources/ClassPing/Store+Backup.swift` (new file)

```swift
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
```

### 4.12 Stop 2 check: the store tests and the script (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Persistence/BackupStoreTests.swift $R/Persistence/TrashStoreTests.swift Tests/Store/
```

Then add three words to the end of the `for source in …` list in
`scripts/test-store.sh`, so it reads `… Store+Grades Store+Profile
Models+Backup Store+Backup Store+Trash; do`. Without them the store tests
can't find `purgeExpired` or `restoreBackup`.

**One line in your own test file.** Line 23 of your
`Tests/Store/CourseDeletionTests.swift` stamps an "earlier delete" with
`Date(timeIntervalSince1970: 1_700_000_000)`, which is November 2023. Opening
the app now deletes for good anything that has waited 30 days (4.9), so
those items vanish on reload and three of your tests fail, correctly. Make
the earlier delete yesterday instead:

```swift
let old = Date.now.addingTimeInterval(-86_400)   // CHANGED in Phase 11b+c
```

```bash
scripts/test-store.sh     # expect 120
xtool dev build
```

### Stop 3: the screens

Four new screens, then the Undo bar and the Profile tab, which show them.

### 4.13 `~/ClassPing/Sources/ClassPing/Components/UndoBar.swift` (replaces your 4b file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/UndoBar.swift
//  Phase:   4b (the Tasks screen); Today uses it too from Phase 6b;
//           changed in 11b+c (a restore can be undone here too)
//  Ports:   components/StatusChrome.tsx (the undo strip) and the
//           UNDO_WINDOW_MS timer in lib/store.tsx
//
//  Summary: The bar that offers to take a delete back, packaged as a view
//           modifier. A screen that can delete things adds `.undoBar()`: the
//           bar sits above the tab bar while there's a delete to undo, and
//           goes away by itself 8 seconds later. After a backup restore it
//           says "Backup restored" instead, and waits until you close it.
//

import SwiftUI

/// The Undo bar and its 8-second timer. In Phase 3, `.cardStyle()` was a
/// modifier written as a plain function; this one is a `ViewModifier`
/// struct instead, because it needs things a function can't hold: the store
/// from the environment, and a `.task` that lives as long as the screen.
/// `body(content:)` gets the screen it's attached to as `content` and
/// returns that screen with the bar and the timer added.
struct UndoBar: ViewModifier {
    @Environment(Store.self) private var store

    func body(content: Content) -> some View {
        content
            // The bar sits just above the tab bar while there's a delete to undo.
            // CHANGED in Phase 11b+c: a restore takes the bar while it can be
            // undone. It's the bigger, rarer event, so it wins when both are
            // waiting, and it has no timer: undoing a Replace isn't something
            // to lose by looking away (the web's StatusChrome says the same).
            .safeAreaInset(edge: .bottom) {
                if store.preRestore != nil {
                    bar("Backup restored", store.profile.accent,
                        undo: { _ = store.undoRestore() },
                        dismiss: { store.dismissRestoreSnapshot() })
                } else if let undo = store.pendingUndo {
                    bar(undo.label, store.profile.accent,
                        undo: { store.undoDelete() },
                        dismiss: { store.dismissUndo() })
                }
            }
            // Make the offer go away 8 seconds after the delete (UNDO_WINDOW_MS).
            // `.task(id:)` runs this async work when the view appears and again
            // whenever `id` changes, and cancels it when the view goes away.
            .task(id: store.pendingUndo?.at) {
                guard let undo = store.pendingUndo else { return }
                // Whatever is left of the 8 seconds (none, if we come back later).
                let left = max(0, 8 - Date.now.timeIntervalSince(undo.at))
                // `Task` here is Swift's own concurrency type, which is exactly why
                // the model can't be called Task. `try?` because sleeping throws
                // when the work is cancelled, and a cancel is not an error here.
                try? await Task.sleep(for: .seconds(left))
                // Cancelled (you left the screen, or a newer delete replaced this
                // one)? Leave the offer alone; the next run of this block decides.
                guard !Task.isCancelled else { return }
                if store.pendingUndo?.at == undo.at { store.dismissUndo() }
            }
    }

    /// The bar itself: what happened, Undo, and a close button.
    // CHANGED in Phase 11b+c: it takes the words and the two actions, so the
    // same bar serves a delete and a restore. `@escaping` says the closures
    // are kept and run later (when a button is tapped), not right away.
    private func bar(_ label: String, _ accent: Profile.Accent,
                     undo: @escaping () -> Void, dismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer()
            Button("Undo", action: undo)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.faint)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle()
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

extension View {
    /// Adds the Undo bar to a screen: `SomeScreen().undoBar()`. A one-line
    /// wrapper, so callers don't have to write `.modifier(UndoBar())`.
    func undoBar() -> some View {
        modifier(UndoBar())
    }
}
```

### 4.14 `~/ClassPing/Sources/ClassPing/Screens/Profile/RestoreSheet.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/RestoreSheet.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   components/RestoreSheet.tsx
//
//  Summary: Restoring a backup as a decision, not a button. You pick a file,
//           and before anything moves you see what would happen: what's new,
//           what's already here, what would be updated and, only in Replace,
//           what would go. Merge is picked to start with. Nothing changes
//           until you tap the restore button, and the Undo bar can take it
//           back afterwards.
//

import SwiftUI
import UniformTypeIdentifiers

struct RestoreSheet: View {
    @Environment(Store.self) private var store
    /// Closes this sheet. SwiftUI hands every presented screen this action.
    @Environment(\.dismiss) private var dismiss

    /// The Files app's picker is open.
    @State private var picking = false
    /// The chosen file's name, shown under the button.
    @State private var fileName = ""
    /// The checked, read backup, or nil before a good file is picked.
    @State private var backup: BackupContents? = nil
    /// Why the picked file can't be restored, or nil.
    @State private var error: String? = nil
    @State private var mode = RestoreMode.merge

    var body: some View {
        let accent = store.profile.accent

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if backup == nil && error == nil {
                        Text("Choose a ClassPing backup file. You'll see exactly what changes before anything is restored.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: Choosing the file
                    Button { picking = true } label: {
                        Text(fileName.isEmpty ? "Choose a backup file" : "Choose a different file")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.ink)

                    if !fileName.isEmpty {
                        Text(fileName)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity)
                    }

                    if let error {
                        callout(error, Theme.dangerSoft, Theme.dangerInk)
                    }

                    // MARK: What would happen
                    if let backup {
                        plan(store.restorePlan(backup, mode: mode), backup, accent)
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Restore a backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        // MARK: The picker
        // The Files app's own picker, showing only JSON files. You get back
        // the address of the file you chose, or nothing if you cancel.
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { open(url) }
        }
    }

    /// The plan for the picked file, the two modes, and the restore button.
    @ViewBuilder
    private func plan(_ plan: RestorePlan, _ backup: BackupContents, _ accent: Profile.Accent) -> some View {
        // How to restore: Merge or Replace.
        sectionLabel("HOW TO RESTORE")
        HStack(spacing: 8) {
            modeButton(.merge, "Merge", "Adds what's missing. Keeps everything already here.", accent)
            modeButton(.replace, "Replace", "Makes this device match the file exactly.", accent)
        }

        // What changes, one line per kind, the web's words.
        sectionLabel("WHAT CHANGES")
        VStack(alignment: .leading, spacing: 6) {
            // `id: \.self` uses each line as its own id; no two lines match.
            ForEach(describePlan(plan), id: \.self) { line in
                Text(line.capitalized)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
            }
            if plan.restoresPreferences {
                Text("Your preferences and progress come back as they were saved.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
            }
        }

        if !plan.warnings.isEmpty {
            callout(plan.warnings.joined(separator: "\n"), Theme.warnSoft, Theme.warnInk)
        }

        if mode == .replace {
            callout("Replace removes anything on this device that isn't in the file. You can undo it straight afterwards.",
                    Theme.dangerSoft, Theme.dangerInk)
        }

        // The web's <details>: a tap opens it.
        DisclosureGroup("What a backup doesn't include") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(BACKUP_LEAVES_OUT, id: \.what) { item in
                    // A `Text` can sit inside another's text: the name bold, the reason plain.
                    Text("\(Text(item.what).bold().foregroundStyle(Theme.ink)), \(item.why)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 6)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .tint(Theme.muted2)

        // The button says what it will do, and can't be tapped for nothing.
        Button {
            if store.restoreBackup(backup, mode: mode) {
                dismiss()
            } else {
                error = "Couldn't save on this device. Nothing was restored."
            }
        } label: {
            Text(plan.totalChanges == 0 ? "Nothing to restore"
                 : mode == .merge ? "Restore and merge" : "Replace everything")
                .font(.system(size: 15.5, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brand(accent))
        .disabled(plan.totalChanges == 0)
    }

    /// One of the two choices, highlighted when it's the one picked.
    private func modeButton(_ which: RestoreMode, _ title: String, _ detail: String,
                            _ accent: Profile.Accent) -> some View {
        let active = mode == which
        return Button { mode = which } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? Theme.brandDeep(accent) : Theme.ink)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(active ? Theme.brandSoft(accent) : Theme.surface2,
                        in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(active ? Theme.brand(accent).opacity(0.35) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        // VoiceOver hears "selected" on the chosen one, like the web's aria-pressed.
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The small spaced-out caps over each part.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
            .padding(.top, 4)
    }

    /// A tinted box for an error, a warning or the Replace caution.
    private func callout(_ text: String, _ fill: Color, _ ink: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 13))
    }

    /// Reads the chosen file and checks it. A file from the picker lives
    /// outside the app, so iOS asks the app to say when it starts and stops
    /// reading it ("security-scoped"). `defer` runs its block when this
    /// function ends, however it ends, so the stop is never forgotten.
    private func open(_ url: URL) {
        let reading = url.startAccessingSecurityScopedResource()
        defer { if reading { url.stopAccessingSecurityScopedResource() } }

        fileName = url.lastPathComponent
        backup = nil
        mode = .merge
        guard let data = try? Data(contentsOf: url) else {
            error = "That file couldn't be read. Try choosing it again."
            return
        }
        // A bad file changes nothing but the message saying why.
        switch BackupContents.open(data) {
        case .success(let contents):
            backup = contents
            error = nil
        case .failure(let problem):
            error = problem.message
        }
    }
}
```

### 4.15 `~/ClassPing/Sources/ClassPing/Screens/Profile/RecentlyDeletedView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/RecentlyDeletedView.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   app/settings/deleted/page.tsx (RecentlyDeletedScreen,
//           EmptyState, TrashRow)
//
//  Summary: Everything you've deleted in the last 30 days, newest first, with
//           the class it belonged to and how long it has left. Restore puts it
//           back; Delete now (tap twice) removes it for good. Work that went
//           with its class says so instead, because the class owns it.
//

import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(Store.self) private var store

    /// Empty was tapped once: it now says "Sure?".
    @State private var confirmEmpty = false
    /// The row whose Delete now was tapped once, by its id, or nil.
    @State private var confirmPurge: String? = nil
    /// A save that didn't reach planner.json, in words, or nil.
    @State private var problem: String? = nil
    /// The moment the countdowns are read against: when you opened the
    /// screen, as the web's `useMemo(() => new Date(), [])`.
    @State private var now = Date.now

    var body: some View {
        let accent = store.profile.accent
        let trash = store.trash

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                }
                if trash.isEmpty {
                    emptyState
                } else {
                    Text("Deleted items stay here for \(RECOVERY_RETENTION_DAYS) days, then they're gone for good. Restoring one brings back everything that went with it.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                    ForEach(trash) { entry in
                        row(entry, accent)
                    }
                }
            }
            .padding(18)
        }
        .background(Theme.canvas)
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The web's Empty button, top right, asking once more first.
            ToolbarItem(placement: .topBarTrailing) {
                Button(confirmEmpty ? "Sure?" : "Empty") {
                    if confirmEmpty {
                        report(store.emptyTrash())
                        confirmEmpty = false
                    } else {
                        confirmEmpty = true
                    }
                }
                .fontWeight(.semibold)
                .tint(Theme.dangerInk)
                .disabled(trash.isEmpty)
            }
        }
    }

    /// One deleted item: what it was, where it was, how long it has left,
    /// and what you can do about it.
    private func row(_ entry: TrashEntry, _ accent: Profile.Accent) -> some View {
        // "Assignment · Biology · 12 days left". An empty detail is left out.
        let line = [entry.kind.label, entry.detail, purgeLine(entry.deletedAt, now: now)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol(entry.kind))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted2)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface2, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(line)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            if entry.viaClass {
                // Restoring this alone would put it under a class that isn't
                // there, so the class owns the action and the row says so.
                Text("Went with its class. Restore the class to bring this back too.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.infoInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.infoSoft, in: RoundedRectangle(cornerRadius: 11))
            } else {
                HStack(spacing: 8) {
                    Button {
                        confirmPurge = nil
                        report(store.restoreFromTrash(entry))
                    } label: {
                        chip("Restore", fill: Theme.brandSoft(accent), ink: Theme.brand(accent), bold: true)
                    }
                    Button {
                        if confirmPurge == entry.id {
                            confirmPurge = nil
                            report(store.purgeFromTrash(entry))
                        } else {
                            confirmPurge = entry.id
                        }
                    } label: {
                        let asking = confirmPurge == entry.id
                        chip(asking ? "Delete for good?" : "Delete now",
                             fill: asking ? Theme.dangerSoft : .clear,
                             ink: asking ? Theme.dangerInk : Theme.muted2, bold: false)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// A small round-ended button label, like the web's pill buttons. At
    /// least 44 points tall, so it's easy to hit.
    private func chip(_ title: String, fill: Color, ink: Color, bold: Bool) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: bold ? .bold : .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(fill, in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    /// Nothing deleted: a calm card that says what this screen is for.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 22))
                .foregroundStyle(Theme.hint)
                .frame(width: 52, height: 52)
                .background(Theme.surface2, in: Circle())
                .accessibilityHidden(true)
            Text("Nothing deleted")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Anything you delete waits here for \(RECOVERY_RETENTION_DAYS) days, so an accidental tap is never the end of it.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.top, 24)
    }

    /// Each kind's little picture, close to the web's icons.
    private func symbol(_ kind: EntityKind) -> String {
        switch kind {
        case .course: "book.closed"
        case .assignment: "checklist"
        case .grade: "graduationcap"
        case .note: "pencil"
        }
    }

    /// Shows the save message when a write didn't reach planner.json.
    private func report(_ saved: Bool) {
        problem = saved ? nil : "Couldn't save on this device. Nothing changed."
    }
}
```

### 4.16 `~/ClassPing/Sources/ClassPing/Screens/Profile/DataSection.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/DataSection.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   the backup rows of app/settings/page.tsx's Account card: where
//           your work is, "Back up my data", "Restore a backup", "Recently
//           Deleted" and "Clear all data"
//
//  Summary: The Profile tab's YOUR DATA card. Back up saves a file through
//           the Files app's save sheet, Restore opens the restore sheet,
//           Recently Deleted opens its screen, and Clear all data asks once,
//           naming exactly what would go, before it empties the planner.
//

import SwiftUI
import UniformTypeIdentifiers

/// The backup file, as the save sheet needs it. `FileDocument` is SwiftUI's
/// way to hand a file to the system: it says which kinds of file it is
/// (`readableContentTypes`) and gives its bytes in a `FileWrapper`. Like
/// JSONValue, both methods may throw by the protocol's rules and don't here.
struct BackupDocument: FileDocument {
    /// A backup is JSON. `UTType` names file kinds; `.json` is "public.json".
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    /// Reading a document back in. Only exporting uses this type, but the
    /// protocol asks for it.
    init(configuration: ReadConfiguration) {
        data = configuration.file.regularFileContents ?? Data()
    }

    /// The file's bytes, for the save sheet to write where you choose.
    func fileWrapper(configuration: WriteConfiguration) -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataSection: View {
    @Environment(Store.self) private var store

    /// The file being saved, made when you tap Back up.
    @State private var backup: BackupDocument? = nil
    /// The save sheet is open.
    @State private var exporting = false
    /// "Backup saved" shows for a few seconds after it worked.
    @State private var backedUp = false
    /// The restore sheet is open.
    @State private var restoring = false
    /// Clear all data was tapped once: the confirmation is showing.
    @State private var confirmClear = false
    /// "Cleared, your planner is empty." shows for a few seconds.
    @State private var cleared = false
    /// Something didn't work, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        let summary = store.clearSummary
        let deletedCount = store.trash.count

        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR DATA")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

            // MARK: Where your work is
            // The web's sync row, in its "saved" state: there's no cloud yet.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(store.lastSaveFailed ? Theme.danger : Theme.hint)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                    Text(store.lastSaveFailed ? "Couldn't save on this device" : "Saved on this device")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(store.lastSaveFailed ? Theme.danger : Theme.ink)
                }
                Text("Your work is saved on this device.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            Divider()

            // MARK: Back up
            Button(action: startBackup) {
                rowLabel("💾", backedUp ? "Backup saved" : "Back up my data", accent)
            }
            Divider()

            // MARK: Restore
            Button { restoring = true } label: {
                rowLabel("📥", "Restore a backup", accent)
            }
            Divider()

            // MARK: Recently Deleted
            NavigationLink {
                RecentlyDeletedView()
            } label: {
                rowLabel("🗂️", "Recently Deleted", accent,
                         count: deletedCount > 0 ? deletedCount : nil)
            }
            Divider()

            // MARK: Clear all data
            if confirmClear, let summary {
                clearConfirmation(summary, accent)
            } else {
                Button { confirmClear = true } label: {
                    HStack(spacing: 12) {
                        icon("🧹", Theme.warnSoft)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Clear all data")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text(cleared ? "Cleared, your planner is empty."
                                 : summary.map { "Erase \($0). Keeps your preferences." }
                                 ?? "Nothing to clear yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .disabled(summary == nil)
                .opacity(summary == nil ? 0.5 : 1)
            }

            if let problem {
                Text(problem)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
                    .padding([.horizontal, .bottom], 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // MARK: The save sheet
        // The Files app's "save to…" sheet: you pick the folder and can rename
        // the file. The name goes in without ".json"; the sheet adds it from
        // the content type. Cancelling just closes it.
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json,
                      defaultFilename: String(backupFilename(.now).dropLast(5)),
                      onCompletion: { result in
                          // `Result` (11a): it worked, or here's why not.
                          switch result {
                          case .success:
                              backedUp = true
                              problem = nil
                          case .failure:
                              problem = "Couldn't save the backup. Try again."
                          }
                          backup = nil
                      })
        .sheet(isPresented: $restoring) {
            RestoreSheet()
        }
        // "Backup saved" for 5 seconds, as the web's "Backup downloaded".
        .task(id: backedUp) {
            guard backedUp else { return }
            try? await Task.sleep(for: .seconds(5))
            backedUp = false
        }
        // "Cleared…" for 5 seconds too.
        .task(id: cleared) {
            guard cleared else { return }
            try? await Task.sleep(for: .seconds(5))
            cleared = false
        }
    }

    /// One row: an emoji in a soft square, its words, and a count or arrow.
    /// The web uses the same emoji, so the two apps look alike here.
    private func rowLabel(_ emoji: String, _ title: String, _ accent: Profile.Accent,
                          count: Int? = nil) -> some View {
        HStack(spacing: 12) {
            icon(emoji, Theme.brandSoft(accent))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            if let count {
                Text("\(count)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.muted2)
            }
        }
        .padding(16)
        .frame(minHeight: 44)
        // The whole row is the button, not just its words.
        .contentShape(Rectangle())
    }

    /// The emoji in its 36-point rounded square.
    private func icon(_ emoji: String, _ fill: Color) -> some View {
        Text(emoji)
            .font(.system(size: 17))
            .frame(width: 36, height: 36)
            .background(fill, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    /// The second step of Clear all data: what would go, a way to back up
    /// first, then Keep it or Clear everything. The web's wording, less the
    /// cloud and account parts this phone doesn't have yet (D-76).
    private func clearConfirmation(_ summary: String, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This permanently deletes \(summary) on this device. Your preferences stay. It can't be undone.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back up first", action: startBackup)
                .font(.system(size: 13, weight: .semibold))
                .tint(Theme.brand(accent))
            HStack(spacing: 10) {
                Button {
                    confirmClear = false
                } label: {
                    Text("Keep it")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.muted)

                Button {
                    if store.clearData() {
                        confirmClear = false
                        problem = nil
                        cleared = true
                    } else {
                        problem = "Couldn't save on this device. Nothing was cleared."
                    }
                } label: {
                    Text("Clear everything")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.danger)
            }
        }
        .padding(16)
    }

    /// Makes the file and opens the save sheet. `handleExportData`.
    private func startBackup() {
        guard let data = store.backupData() else {
            problem = "Couldn't make the backup. Try again."
            return
        }
        backup = BackupDocument(data: data)
        exporting = true
    }
}
```

### 4.17 `~/ClassPing/Sources/ClassPing/Screens/Profile/CalendarCard.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/CalendarCard.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   the "Add to phone calendar" part of the Reminders card in
//           app/settings/page.tsx (handleCalendarExport) and
//           downloadCalendarFile in lib/calendar.ts
//
//  Summary: The Profile tab's Calendar card. One button opens the share sheet
//           with classping.ics: this term's timetable and your open, dated
//           work, built on the phone. The web builds the same file on its
//           server, for Pro accounts only; the phone needs neither (D-77).
//

import SwiftUI
import UniformTypeIdentifiers

/// The calendar file, as something the share sheet can send: a .ics file.
/// The same idea as `GradeReportFile` in Phase 9c: it carries what the file
/// is made from, and makes the file only when you pick where it goes.
struct CalendarFile: Transferable {
    /// The classes on the timetable now (not archived, not deleted).
    let courses: [Course]
    /// Your work (not deleted); the file leaves out what's done or undated.
    let assignments: [Assignment]
    /// The semester, so the weekly events stop when it ends.
    let term: TermWindow

    /// The file's text at `now`. A piece of work names its class only when
    /// that class is in the file, as the web's server does.
    func text(at now: Date) -> String {
        let names = Dictionary(courses.map { ($0.id, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        return buildCalendarFile(courses, assignments,
                                 className: { id in id.flatMap { names[$0] } },
                                 now: now, term: term)
    }

    /// One form: a file of type "calendar event" (`.calendarEvent`, the
    /// kind of file .ics is), named classping.ics like the web's download.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .calendarEvent) { file in
            let url = URL.temporaryDirectory.appending(path: "classping.ics")
            let data = Data(file.text(at: .now).utf8)
            // Throwing tells the share sheet the file couldn't be made, rather
            // than handing over one that isn't there (as in 9c).
            guard (try? data.write(to: url, options: .atomic)) != nil else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

struct CalendarCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let accent = store.profile.accent
        let courses = store.activeCourses
        let open = store.liveAssignments.filter { !$0.done }
        // Nothing to put in a calendar yet: the button waits, as on the web.
        let hasSchedule = !courses.isEmpty || !open.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            Text("CALENDAR")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)

            // The web's calendar icon and its sentence.
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.brand(accent))
                    .frame(width: 36, height: 36)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                Text("Prefer your own calendar? Add your schedule to it and your phone will deliver the class reminders too.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The share sheet, with the file made when you pick where it goes.
            ShareLink(item: CalendarFile(courses: courses, assignments: store.liveAssignments,
                                         term: TermWindow(start: store.profile.termStart,
                                                          end: store.profile.termEnd)),
                      preview: SharePreview("ClassPing timetable",
                                            image: Image(systemName: "calendar"))) {
                Text("Add to phone calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand(accent))
            .disabled(!hasSchedule)

            // What goes in, or why the button is waiting.
            Text(calendarSummary(classes: courses.count, openTasks: open.count))
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
```

### 4.18 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (replaces your 11a file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card),
//           11a (the settings: profile, grading scale, semester) and 11b+c
//           (the calendar file, and your data: backups, Recently Deleted,
//           clearing)
//  Ports:   app/settings/page.tsx, moved into its own tab (D-19): the
//           Profile, Appearance, Reminders (with its calendar export), Grading
//           scale and Semester cards, and the backup rows of the Account card
//
//  Summary: The Profile tab is ClassPing's settings: you, the look, your
//           reminders and calendar, how letters are worked out, the term, and
//           your data. Your account arrives with sync, your level in Phase 12.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` lets the pickers write into the store (Phase 3).
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 16) {
                // Surface a failed local save beside the controls that caused it.
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                // MARK: You
                // CHANGED in Phase 11a: your photo and name, editable.
                ProfileCard()

                // Phase 9a: Grades now opens on Profile's navigation stack.
                NavigationLink {
                    GradesView()
                } label: {
                    HStack {
                        Label("Grades & GPA", systemImage: "graduationcap")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .frame(minHeight: 44)
                    .cardStyle()
                }

                // MARK: Appearance
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("APPEARANCE")
                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)
                    // NEW in Phase 11a: the web's line under each choice.
                    footnote(store.profile.theme == .dark
                             ? "Warm charcoal, with the same soft surfaces and your app color."
                             : "Switch to warm charcoal for late-night planning.")

                    sectionLabel("APP COLOR")
                        .padding(.top, 6)
                    Picker("App color", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                    footnote("Baby Pink or Ocean, for your highlights and primary actions.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // MARK: Reminders
                RemindersSection()

                // MARK: Calendar
                // NEW in Phase 11b+c: the timetable as a .ics file. The web
                // puts this inside its Reminders card; here it's its own card.
                CalendarCard()

                // MARK: Grading scale
                // NEW in Phase 11a: moved here from the Grades screen (D-67).
                GradingSection()

                // MARK: Semester
                // NEW in Phase 11a.
                SemesterSection()

                // MARK: Your data
                // NEW in Phase 11b+c: back up, restore, Recently Deleted, clear.
                DataSection()

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    // CHANGED in Phase 11b+c: backups, Recently Deleted and
                    // the calendar are here now. Only your account is left.
                    comingRow("person.crop.circle", "Your account and sync")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        // NEW in Phase 11a: a swipe down the page puts the keyboard away.
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
        .navigationTitle("Profile")
        // Save whenever a profile field changes, so the choice survives a
        // relaunch. CHANGED in Phase 5a: this moved here from TodayView.
        .onChange(of: store.profile) { store.save() }
        // NEW in Phase 11b+c: "Backup restored" with its Undo shows here,
        // where the restore happened, as well as on the other tabs.
        .undoBar()
    }

    /// The small spaced-out caps over each card, like the web's section labels.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// The small grey line under a control. NEW in Phase 11a.
    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One upcoming feature, shown as a label until its screen is available.
    private func comingRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.faint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }
}

/// A round avatar: your photo if you've chosen one, otherwise up to two
/// initials on the brand gradient, or a person symbol before you've set a
/// name. The tab bar uses a small one, the Profile tab a big one. Phase 12
/// adds the pet-tier ring.
struct AvatarBadge: View {
    // NEW in Phase 11a: the photo comes from the store, so every badge
    // shows it without each caller passing it in.
    @Environment(Store.self) private var store

    let name: String
    let size: CGFloat
    let accent: Profile.Accent

    var body: some View {
        ZStack {
            Circle().fill(Theme.brandGradient(accent))
            // CHANGED in Phase 11a: two initials, as on the web ("KM").
            let letters = avatarInitials(name.trimmingCharacters(in: .whitespaces))
            if letters.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            } else {
                Text(letters)
                    .font(.system(size: size * (letters.count > 1 ? 0.36 : 0.42), weight: .bold))
                    .foregroundStyle(.white)
            }
            // NEW in Phase 11a: the photo, laid over the initials.
            if let uri = store.profile.avatarURL, uri.hasPrefix("data:image/") {
                AvatarPhoto(uri: uri)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // The tab's own label says "Profile", so VoiceOver skips the picture.
        .accessibilityHidden(true)
    }
}

/// A stored `data:` picture, turned back into an image once per picture
/// rather than on every redraw. NEW in Phase 11a.
private struct AvatarPhoto: View {
    let uri: String
    /// The decoded picture, or nil until it's ready (the initials show).
    @State private var image: UIImage? = nil

    var body: some View {
        // `Color.clear` takes the badge's size; the photo fills it, cropped.
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            // Runs when the badge appears and again when the picture changes.
            .task(id: uri) {
                image = avatarImageData(uri).flatMap { UIImage(data: $0) }
            }
    }
}
```

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 506
scripts/test-store.sh     # expect 120
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself. Do the
steps in order: step 2 makes the backup the later steps lean on.

1. **The cards:** Profile tab. After REMINDERS there's CALENDAR, and after
   SEMESTER there's YOUR DATA: a grey dot with "Saved on this device", then
   Back up my data, Restore a backup, Recently Deleted and Clear all data.
2. **Back up:** tap **Back up my data**. The Files save sheet opens with
   `classping-backup-` and today's date. Save it somewhere you'll find it
   (On My iPhone is fine). The row says "Backup saved" for 5 seconds. In
   Files, check the name ends in `.json`.
3. **Restore that same file:** **Restore a backup** → **Choose a backup
   file** → pick it. Under WHAT CHANGES every line says "Already Here", and
   the button is a greyed **Nothing to restore**. Close.
4. **Merge brings an edit back:** rename one assignment, then restore the
   file again. One line says "1 Updated". Tap **Restore and merge**: the old
   title is back, and the bar says "Backup restored · Undo". Tap **Undo**:
   your rename is back.
5. **Replace takes away:** add a throwaway assignment, restore the file with
   **Replace**: a red note warns, and the line says "… 1 Removed". Tap
   **Replace everything**: the throwaway is gone. **Undo**: it's back. Close
   the bar with ×.
6. **A bad file:** in Restore, pick any other .json (or skip if you have
   none): a red box says why, and nothing changes.
7. **Recently Deleted:** delete an assignment on Tasks and let the Undo bar
   go. Profile shows a count beside **Recently Deleted**. Open it: the row
   says "Assignment · <class> · 30 days left". **Restore**: it's back on
   Tasks. Delete it again, then **Delete now** → **Delete for good?** → tap
   again: gone.
8. **A class and its work:** in Today's My Classes, delete a class you can
   bring back. In Recently Deleted, the class has Restore; its work says
   "Went with its class. Restore the class to bring this back too." Restore
   the class: its work is back on Tasks and Notes.
9. **Add to phone calendar:** below "Exports N classes and M open
   assignments", tap the button. The share sheet offers the file. Calendar
   may not be in the list; if not, **Save to Files**, then open
   `classping.ics` in Files, which should offer to add the events. Check one
   class repeats weekly inside your term with its alarm. Say what you saw:
   this is the one part that couldn't be tried before your phone. Your class
   alarms then ring twice, from ClassPing and from Calendar, so delete the
   events afterwards if you don't want that.
10. **Optional, from the web:** on classping.space, Settings → Back up my
    data, get the file onto the phone (AirDrop or iCloud Drive) and Restore it
    with **Merge**. The preview says what's new. Undo if you'd rather not mix
    the two planners yet.
11. **Optional, last, Clear all data:** only after step 3 worked. Tap
    **Clear all data**: it names what would go. Tap **Back up first**, save,
    then **Clear everything**: your planner is empty and your theme and name
    stay. Now restore that backup with Merge: everything is back. Clear has
    no Undo, which is why the backup comes first.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] 506 logic and 120 store tests pass; the
      tree builds without warnings.
- [ ] A backup saves as a .json in Files and reads back as "Already Here".
- [ ] Merge restores an edit, Replace removes an extra, and Undo reverses
      both.
- [ ] Recently Deleted restores an item and a class with its work, and
      Delete now removes one for good.
- [ ] The calendar file reaches Calendar (or you've said how far it got).

## 7. If it breaks

- **Cannot find type 'JSONValue' or 'BackupItem':** 4.1 or 4.2 isn't in
  `Logic/`, or its file name differs.
- **'Course' does not conform to 'CalendarClass':** the last line of 4.6 is
  missing, or 4.4 isn't typed yet.
- **Cannot find 'replaceAll' or 'purgeExpired':** 4.9 and 4.10 need each
  other; type both before building.
- **The store tests can't find 'restoreBackup' or 'purgeExpired':** the
  three words are missing from `scripts/test-store.sh` (4.12).
- **`CourseDeletionTests` fails on `loaded.assignments.count == 5`:** line
  23's `old` is still 2023 (4.12).
- **A calendar test says the lines differ:** the failing line is printed in
  full; compare it with 4.4. An escape (`\\;`, `\\,`) or the 74/73 fold
  widths are the likely spots.
- **"Already Here" turns into "Updated" after closing the app:** a moment
  is keeping its fraction of a second; check `webMillis` and `webDate` in
  4.2 and `moment` in 4.7 all round down.
- **Restore says the file couldn't be read:** pick it again from Files; a
  file still downloading from iCloud can't be opened until it's on the phone.

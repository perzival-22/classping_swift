// BackupTests.swift: the backup file's rules (lib/backup.ts), at the level of
// the file itself: reading it, checking it, writing it, and planning and
// merging lists of items. The web's backup.test.ts cases are here where they
// test the file; the ones that need real classes and assignments are in
// Persistence/BackupStoreTests.swift, because the models live outside Logic/.
// Every message is the web's own: printed by validateBackup and describePlan
// in node 24.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

// MARK: - Helpers

/// A file's bytes around a `data` object, the way a backup is laid out.
private func file(_ data: String, version: String = "4") -> Data {
    Data(#"{"app": "ClassPing", "schemaVersion": \#(version), "exportedAt": "2026-10-21T03:04:05.678Z", "data": \#(data)}"#.utf8)
}

/// One class and one task, the smallest file that isn't empty.
private let SMALL = #"{"classes": [{"id": "c1", "name": "Chemistry"}], "tasks": [{"id": "t1", "title": "Essay"}]}"#

/// The checked file, or nil when it was refused.
private func accepted(_ bytes: Data) -> BackupFile? {
    if case .success(let f) = checkBackup(bytes) { return f }
    return nil
}

/// Why it was refused, or nil when it was accepted.
private func refused(_ bytes: Data) -> String? {
    if case .failure(let e) = checkBackup(bytes) { return e.message }
    return nil
}

/// JSON text for a value, keys sorted, as a test can compare it.
private func text(_ value: JSONValue) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: (try? encoder.encode(value)) ?? Data(), as: UTF8.self)
}

/// A stand-in item. `note` isn't in its file form, so a test can see whether
/// a merge kept this phone's copy or took the file's.
private struct Thing: BackupItem {
    var id: UUID
    var title: String
    var note = "mine"
    var webJSON: JSONValue { .object(["id": .string(webID(id)), "title": .string(title)]) }
}

private let A = UUID(), B = UUID(), C = UUID()

// MARK: - JSON values

@Suite struct JSONValueTests {
    @Test func readsEveryKindOfValue() {
        let raw = #"{"a": true, "b": 1, "c": 1.5, "d": "x/y", "e": null, "f": [1, false, "s"], "g": {"h": 2}}"#
        let v = (try? JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))) ?? .null
        #expect(v["a"] == .bool(true))          // true is never read as the number 1
        #expect(v["b"] == .number(1))
        #expect(v["c"]?.numberValue == 1.5)
        #expect(v["d"]?.stringValue == "x/y")
        #expect(v["e"] == .null)
        #expect(v["f"] == .array([.number(1), .bool(false), .string("s")]))
        #expect(v["g"]?["h"]?.intValue == 2)
        #expect(v["missing"] == nil)
    }

    @Test func wholeNumbersOnlyForIntValue() {
        #expect(JSONValue.number(600).intValue == 600)
        #expect(JSONValue.number(600.5).intValue == nil)
        #expect(JSONValue.string("600").intValue == nil)
        #expect(JSONValue.number(.infinity).numberValue == nil)
    }

    @Test func keyOrderDoesntMatter() {
        let one = try? JSONDecoder().decode(JSONValue.self, from: Data(#"{"a": 1, "b": [true]}"#.utf8))
        let two = try? JSONDecoder().decode(JSONValue.self, from: Data(#"{"b": [true], "a": 1}"#.utf8))
        #expect(one != nil)
        #expect(one == two)
    }

    @Test func writesNumbersTheWayTheWebReadsThem() {
        #expect(text(.number(600)) == "600")
        #expect(text(.number(1_790_000_123_000)) == "1790000123000")
        #expect(text(.number(1.5)) == "1.5")
        #expect(text(.object(["b": .null, "a": .array([.bool(true)])])) == #"{"a":[true],"b":null}"#)
    }
}

// MARK: - Checking a file (validateBackup)

@Suite struct CheckBackupTests {
    @Test func acceptsAFileThisAppWrote() {
        let bytes = backupFileData(classes: [.object(["id": .string("c1")])], tasks: [], grades: [], notes: [],
                                   taskPlans: [], studySessions: [], profile: ["username": .string("Kel")],
                                   progress: GameBlobs(), now: Date(timeIntervalSince1970: 1_792_551_845))
        let f = bytes.flatMap(accepted)
        #expect(f?.schemaVersion == BACKUP_VERSION)
        #expect(f?.classes.count == 1)
        #expect(f?.profile["username"] == .string("Kel"))
        #expect(f?.warnings == [])
    }

    @Test func rejectsDamagedJSONWithoutCrashing() {
        #expect(refused(Data("{ not json".utf8)) == "That file isn't valid JSON, it may be damaged.")
        #expect(refused(Data()) == "That file isn't valid JSON, it may be damaged.")
    }

    @Test func rejectsSomethingThatIsntAnObject() {
        #expect(refused(Data("[1, 2]".utf8)) == "That file doesn't look like a ClassPing backup.")
        #expect(refused(Data("\"ClassPing\"".utf8)) == "That file doesn't look like a ClassPing backup.")
    }

    @Test func rejectsAFileFromAnotherApp() {
        #expect(refused(Data(#"{"app": "SomethingElse", "data": {}}"#.utf8)) == "That file wasn't exported from ClassPing.")
    }

    @Test func refusesANewerVersionRatherThanGuessing() {
        let newer = "That backup was made by a newer version of ClassPing. Update the app, then try again."
        #expect(refused(file(SMALL, version: "5")) == newer)
        // web: 4.5 is newer too
        #expect(refused(file(SMALL, version: "4.5")) == newer)
    }

    @Test func readsTheVersionTheWayJavaScriptsNumberDoes() {
        let tooOld = "That backup is too old for this version of ClassPing."
        // web: "3" -> 3, " 4 " -> 4, true -> 1 (older backup), null -> 1
        #expect(accepted(file(SMALL, version: "\"3\""))?.schemaVersion == 3)
        #expect(accepted(file(SMALL, version: "\" 4 \""))?.schemaVersion == 4)
        #expect(accepted(file(SMALL, version: "true"))?.schemaVersion == 1)
        #expect(accepted(file(SMALL, version: "null"))?.schemaVersion == 1)
        // web: "", false, "x" and 0 are too old
        #expect(refused(file(SMALL, version: "\"\"")) == tooOld)
        #expect(refused(file(SMALL, version: "false")) == tooOld)
        #expect(refused(file(SMALL, version: "\"x\"")) == tooOld)
        #expect(refused(file(SMALL, version: "0")) == tooOld)
    }

    @Test func rejectsAnEmptyBackup() {
        let empty = #"{"classes": [], "tasks": [], "grades": [], "notes": [], "taskPlans": [{"id": "p"}]}"#
        #expect(refused(file(empty)) == "That backup is empty, there's nothing to restore.")
    }

    @Test func readsAVersionOneFileAndWarns() {
        // The old export: no wrapper, no version, no notes.
        let legacy = #"{"app": "ClassPing", "exportedAt": "2026-01-01T00:00:00.000Z", "classes": [{"id": "c1"}], "tasks": [{"id": "t1"}], "grades": [{"id": "g1"}], "profile": {"username": "kel"}}"#
        let f = accepted(Data(legacy.utf8))
        #expect(f?.schemaVersion == 1)
        #expect(f?.classes.count == 1)
        #expect(f?.notes == [])
        #expect(f?.profile["username"] == .string("kel"))
        #expect(f?.warnings == ["This is an older backup. It doesn't contain lecture notes or progress, those were added to backups later."])
    }

    @Test func skipsItemsWithNoIDAndSaysHowMany() {
        // web: "1 item in this file have no identifier and will be skipped." (sic)
        let one = accepted(file(#"{"classes": [{"id": "c1"}], "tasks": [{"id": "t1"}, {"title": "orphan"}]}"#))
        #expect(one?.tasks.count == 1)
        #expect(one?.warnings == ["1 item in this file have no identifier and will be skipped."])
        let two = accepted(file(#"{"tasks": [{"id": "t1"}, {"title": "a"}], "grades": [{"id": ""}]}"#))
        #expect(two?.warnings == ["2 items in this file have no identifier and will be skipped."])
    }

    @Test func notesWithoutAnIDGoQuietly() {
        // normalizeNotes drops them without a warning; they don't count as content.
        let f = accepted(file(#"{"classes": [{"id": "c1"}], "notes": [{"title": "x"}, {"id": "n1"}]}"#))
        #expect(f?.notes.count == 1)
        #expect(f?.warnings == [])
        #expect(refused(file(#"{"notes": [{"title": "x"}]}"#)) == "That backup is empty, there's nothing to restore.")
    }

    @Test func skipsListEntriesThatArentObjects() {
        let f = accepted(file(#"{"classes": [{"id": "c1"}, 3, "x", null, [1]]}"#))
        #expect(f?.classes.count == 1)
    }

    @Test func refusesBadMeetingTimes() {
        let message = "This backup contains invalid class meeting times. Correct the file before restoring."
        let primary = #"{"classes": [{"id": "c1", "additionalMeetings": [{"id": "primary", "days": [4], "start": 840, "end": 960}]}]}"#
        let backwards = #"{"classes": [{"id": "c1", "additionalMeetings": [{"id": "m1", "days": [4], "start": 960, "end": 840}]}]}"#
        let nullRoom = #"{"classes": [{"id": "c1", "additionalMeetings": [{"id": "m1", "days": [4], "start": 840, "end": 960, "room": null}]}]}"#
        let twice = #"{"classes": [{"id": "c1", "additionalMeetings": [{"id": "m1", "days": [4], "start": 840, "end": 960}, {"id": "m1", "days": [3], "start": 840, "end": 960}]}]}"#
        let notAList = #"{"classes": [{"id": "c1", "additionalMeetings": {"id": "m1"}}]}"#
        for bad in [primary, backwards, nullRoom, twice, notAList] {
            #expect(refused(file(bad)) == message)
        }
        let good = #"{"classes": [{"id": "c1", "additionalMeetings": [{"id": "m1", "days": [4], "start": 840, "end": 960, "room": "Lab 2", "label": "Lab"}]}]}"#
        #expect(accepted(file(good)) != nil)
    }

    @Test func keepsProgressAndTheProfileAsTheyAre() {
        let f = accepted(file(#"{"classes": [{"id": "c1"}], "xp": {"xp": 120}, "pet": null, "profile": {"theme": "dark"}}"#))
        #expect(f?.progress.xp == .object(["xp": .number(120)]))
        #expect(f?.progress.pet == nil)          // null means none
        #expect(f?.progress.trophies == nil)     // missing means none
        #expect(f?.profile == ["theme": .string("dark")])
        #expect(f?.exportedAt == "2026-10-21T03:04:05.678Z")
    }
}

// MARK: - Writing a file (buildBackup)

@Suite struct WriteBackupTests {
    @Test func namesTheFileByYourDay() {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 7; c.hour = 23; c.minute = 30
        let late = Calendar.current.date(from: c) ?? .now
        #expect(backupFilename(late) == "classping-backup-2026-09-07.json")
    }

    @Test func stampsTheVersionAndTheMomentInUTC() {
        let bytes = backupFileData(classes: [], tasks: [], grades: [], notes: [], taskPlans: [],
                                   studySessions: [], profile: [:], progress: GameBlobs(),
                                   now: Date(timeIntervalSince1970: 1_792_551_845.678))
        let top = bytes.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
        #expect(top?["app"] == .string("ClassPing"))
        #expect(top?["schemaVersion"] == .number(4))
        #expect(top?["exportedAt"] == .string("2026-10-21T03:04:05.678Z"))
        // Every list is there, even when empty, and progress only when present.
        let data = top?["data"]?.objectValue ?? [:]
        #expect(Set(data.keys) == ["classes", "tasks", "grades", "notes", "taskPlans", "studySessions", "profile"])
    }

    @Test func carriesProgressWhenThereIsSome() {
        let progress = GameBlobs(trophies: .object(["counted": .array([])]), xp: .object(["xp": .number(120)]),
                                 pet: .object(["name": .string("Bo")]), boss: nil)
        let bytes = backupFileData(classes: [], tasks: [], grades: [], notes: [], taskPlans: [],
                                   studySessions: [], profile: [:], progress: progress, now: .now)
        let data = bytes.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }?["data"]
        #expect(data?["xp"] == .object(["xp": .number(120)]))
        #expect(data?["pet"]?["name"] == .string("Bo"))
        #expect(data?["boss"] == nil)
    }

    @Test func idsAreLowerCaseLikeTheWebs() {
        let id = UUID(uuidString: "ABCDEF12-3456-4789-8ABC-DEF012345678") ?? UUID()
        #expect(webID(id) == "abcdef12-3456-4789-8abc-def012345678")
        #expect(uuid(fromWebID: "abcdef12-3456-4789-8abc-def012345678") == id)
        #expect(uuid(fromWebID: "") == nil)
        #expect(uuid(fromWebID: nil) == nil)
    }

    @Test func anOldShortIDGetsTheSameUUIDEveryTime() {
        let one = uuid(fromWebID: "k3j9x2a")
        #expect(one != nil)
        #expect(one == uuid(fromWebID: "k3j9x2a"))
        #expect(one != uuid(fromWebID: "k3j9x2b"))
        // It reads as an ordinary version-4 UUID.
        #expect(one.map { webID($0) }?.dropFirst(14).first == "4")
    }

    @Test func momentsAreWholeSeconds() {
        // The phone keeps whole seconds (planner.json), so files do too (D-73).
        #expect(webMillis(Date(timeIntervalSince1970: 1_790_000_123.456)) == 1_790_000_123_000)
        #expect(webDate(.number(1_790_000_123_456)) == Date(timeIntervalSince1970: 1_790_000_123))
        #expect(webDate(.number(0)) == nil)
        #expect(webDate(.string("1790000123456")) == nil)
        #expect(webDate(nil) == nil)
    }

    @Test func meetingsComeBackFromTheirFileForm() {
        let lab = ClassMeeting(id: UUID(), days: [4], start: 840, end: 960, room: "Lab 2", label: "Lab")
        #expect(meetingsFromWeb(.array([lab.webJSON])) == [lab])
        // Room and label are left out when there are none.
        let bare = ClassMeeting(id: UUID(), days: [1, 3], start: 600, end: 650)
        #expect(bare.webJSON["room"] == nil)
        #expect(meetingsFromWeb(.array([bare.webJSON])) == [bare])
        // Fewer than 20 (MAX_MEETINGS), as on the web.
        let many = (0..<20).map { _ in ClassMeeting(id: UUID(), days: [0], start: 600, end: 650).webJSON }
        #expect(meetingsFromWeb(.array(many)) == nil)
    }

    @Test func progressTakesOnlyWhatAFileDefines() {
        var mine = GameBlobs(trophies: .string("old"), xp: .string("old"), pet: .string("old"), boss: nil)
        mine.adopt(GameBlobs(trophies: nil, xp: .string("new"), pet: nil, boss: .string("new")))
        #expect(mine == GameBlobs(trophies: .string("old"), xp: .string("new"), pet: .string("old"), boss: .string("new")))
        #expect(GameBlobs().isEmpty)
        #expect(!mine.isEmpty)
    }

    @Test func listsWhatABackupLeavesOut() {
        #expect(BACKUP_LEAVES_OUT.map(\.what) == ["Sign-in details", "Push notification subscriptions",
                                                 "Email preferences and entitlements"])
    }
}

// MARK: - Planning and merging (planRestore, applyRestore)

@Suite struct PlanRestoreTests {
    @Test func countsAdditionsAgainstAnEmptyPhone() {
        let plan = planEntity([Thing(id: A, title: "a"), Thing(id: B, title: "b")], [Thing]())
        #expect(plan == EntityPlan(added: 2, identical: 0, conflicting: 0, onlyHere: 0))
    }

    @Test func sameContentIsAlreadyHereNotAChange() {
        // `note` differs, but it isn't part of the file, so it doesn't count.
        let plan = planEntity([Thing(id: A, title: "a", note: "file")], [Thing(id: A, title: "a")])
        #expect(plan.identical == 1)
        #expect(plan.changes(.merge) == 0)
    }

    @Test func sameIDDifferentContentIsAConflict() {
        let plan = planEntity([Thing(id: A, title: "Essay")], [Thing(id: A, title: "Essay (edited here)")])
        #expect(plan.conflicting == 1)
    }

    @Test func mergeKeepsWhatReplaceWouldRemove() {
        let plan = planEntity([Thing(id: A, title: "a")], [Thing(id: A, title: "a"), Thing(id: B, title: "only here")])
        #expect(plan.onlyHere == 1)
        #expect(plan.changes(.merge) == 0)
        #expect(plan.changes(.replace) == 1)
    }

    @Test func theTotalAddsUpEveryList() {
        var plan = RestorePlan(mode: .merge)
        plan.classes = EntityPlan(added: 1, identical: 0, conflicting: 0, onlyHere: 2)
        plan.tasks = EntityPlan(added: 0, identical: 1, conflicting: 2, onlyHere: 0)
        plan.studySessions = EntityPlan(added: 0, identical: 0, conflicting: 0, onlyHere: 3)
        #expect(plan.totalChanges == 3)
        plan.mode = .replace
        #expect(plan.totalChanges == 8)
    }

    @Test func mergeAddsAndNeverTakesAway() {
        let result = restoreEntity([Thing(id: A, title: "a")], [Thing(id: B, title: "written offline")], .merge)
        #expect(result.map(\.id) == [B, A])     // what's here stays first; new goes on the end
    }

    @Test func theFileWinsACollisionInPlace() {
        let result = restoreEntity([Thing(id: B, title: "Essay", note: "file")],
                                   [Thing(id: A, title: "x"), Thing(id: B, title: "stale"), Thing(id: C, title: "y")], .merge)
        #expect(result.map(\.title) == ["x", "Essay", "y"])
        #expect(result[1].note == "file")
    }

    @Test func anIdenticalItemKeepsThisPhonesCopy() {
        let merged = restoreEntity([Thing(id: A, title: "a", note: "file")], [Thing(id: A, title: "a")], .merge)
        #expect(merged.first?.note == "mine")
        let replaced = restoreEntity([Thing(id: A, title: "a", note: "file")], [Thing(id: A, title: "a")], .replace)
        #expect(replaced.first?.note == "mine")
    }

    @Test func replaceDropsWhatTheFileDoesntHave() {
        let result = restoreEntity([Thing(id: A, title: "a")], [Thing(id: A, title: "a"), Thing(id: B, title: "b")], .replace)
        #expect(result.map(\.id) == [A])
    }
}

// MARK: - The words (describePlan, the clear summary)

@Suite struct DescribeTests {
    /// The plan the web printed: 1 new class (2 only here), 2 updated and 1
    /// identical assignment, 1 grade only here, 1 identical note, 1 new plan,
    /// 3 sessions only here.
    private func crafted(_ mode: RestoreMode) -> RestorePlan {
        var plan = RestorePlan(mode: mode)
        plan.classes = EntityPlan(added: 1, identical: 0, conflicting: 0, onlyHere: 2)
        plan.tasks = EntityPlan(added: 0, identical: 1, conflicting: 2, onlyHere: 0)
        plan.grades = EntityPlan(added: 0, identical: 0, conflicting: 0, onlyHere: 1)
        plan.notes = EntityPlan(added: 0, identical: 1, conflicting: 0, onlyHere: 0)
        plan.taskPlans = EntityPlan(added: 1, identical: 0, conflicting: 0, onlyHere: 0)
        plan.studySessions = EntityPlan(added: 0, identical: 0, conflicting: 0, onlyHere: 3)
        return plan
    }

    @Test func mergeInTheWebsWords() {
        // web: ["class: 1 new","assignments: 2 updated, 1 already here","note: 1 already here","planned task: 1 new"]
        #expect(describePlan(crafted(.merge)) == ["class: 1 new", "assignments: 2 updated, 1 already here",
                                                  "note: 1 already here", "planned task: 1 new"])
    }

    @Test func replaceSaysWhatGoes() {
        // web: [..., "grades: 1 removed", ..., "focus sessions: 3 removed"]; the
        // plural follows what the file has, so "1 removed" can still say "grades".
        #expect(describePlan(crafted(.replace)) == ["class: 1 new, 2 removed", "assignments: 2 updated, 1 already here",
                                                    "grades: 1 removed", "note: 1 already here",
                                                    "planned task: 1 new", "focus sessions: 3 removed"])
    }

    @Test func saysPlainlyWhenNothingDiffers() {
        var plan = RestorePlan(mode: .merge)
        plan.classes = EntityPlan(added: 0, identical: 0, conflicting: 0, onlyHere: 4)
        // web: ["Nothing in this file differs from what's here."]
        #expect(describePlan(plan) == ["Nothing in this file differs from what's here."])
    }

    @Test func theClearSummaryNamesWhatWouldGo() {
        #expect(describeClear(classes: 6, assignments: 23, grades: 14, notes: 0) == "6 classes, 23 assignments and 14 grades")
        #expect(describeClear(classes: 1, assignments: 0, grades: 0, notes: 1) == "1 class and 1 note")
        #expect(describeClear(classes: 0, assignments: 1, grades: 0, notes: 0) == "1 assignment")
        #expect(describeClear(classes: 0, assignments: 0, grades: 0, notes: 0) == nil)
    }
}

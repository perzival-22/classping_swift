// BackupStoreTests.swift: backing up, restoring and clearing, through the
// store (lib/store.tsx's exportBackup, restoreBackup, undoRestore, clearData,
// and the store-level cases of lib/backup.test.ts). WEB_BACKUP below is a real
// web file: the web's own buildBackup run in node 24 on a full planner (a
// deleted class with its work, a lab, a snooze with milliseconds, quiet hours,
// progress, feeds and quotes the allowlist must keep out). The "web:" plan
// lines are the web's describePlan for the same file.
// Uses an isolated Documents path, never the real planner file.
// Run: tools/persistence-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
private let C1 = id("11111111-1111-4111-8111-111111111111")   // Chemistry
private let C2 = id("33333333-3333-4333-8333-333333333333")   // History, deleted
private let T1 = id("44444444-4444-4444-8444-444444444444")   // Essay
private let T2 = id("55555555-5555-4555-8555-555555555555")   // Email advisor, Inbox
private let T3 = id("66666666-6666-4666-8666-666666666666")   // Reading, went with History
/// The moment History and Reading were deleted: 1790000000000 ms.
private let GONE = Date(timeIntervalSince1970: 1_790_000_000)

@MainActor
@Suite(.serialized) struct BackupStoreTests {
    private func fresh() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    /// A backup's bytes, checked and read, or nil if they were refused.
    private func open(_ data: Data?) -> BackupContents? {
        guard let data, case .success(let contents) = BackupContents.open(data) else { return nil }
        return contents
    }

    private var web: BackupContents? { open(Data(WEB_BACKUP.utf8)) }

    /// A store that has restored the web file into an empty phone.
    private func restored() -> Store {
        let store = fresh()
        if let web { store.restoreBackup(web, mode: .merge) }
        return store
    }

    /// Puts a folder where planner.json goes, so the next save fails.
    private func blockWrites() -> Bool {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return (try? FileManager.default.createDirectory(at: Store.fileURL,
                                                         withIntermediateDirectories: false)) != nil
    }

    private func unblock() {
        try? FileManager.default.removeItem(at: Store.fileURL)
    }

    // MARK: - Reading a web file

    @Test func aWebFileReadsIntoThePhonesModels() {
        let b = web
        #expect(b != nil)
        #expect(b?.warnings == [])

        // Chemistry, with every detail and its lab.
        let chem = b?.courses.first { $0.id == C1 }
        #expect(chem?.name == "Chemistry")
        #expect(chem?.color == .teal)
        #expect(chem?.days == [0, 2])
        #expect(chem?.startMin == 540)
        #expect(chem?.endMin == 600)
        #expect(chem?.extraReminders == [30])
        #expect(chem?.credits == 4)
        #expect(chem?.room == "Sci 204")
        #expect(chem?.instructor == "Dr Vance")
        #expect(chem?.notes == "Bring goggles")
        #expect(chem?.term == "Fall 2026")
        #expect(chem?.goal == 90)
        #expect(chem?.additionalMeetings == [ClassMeeting(id: id("22222222-2222-4222-8222-222222222222"),
                                                          days: [4], start: 840, end: 960,
                                                          room: "Lab 2", label: "Lab")])
        // History: archived and in Recently Deleted.
        let history = b?.courses.first { $0.id == C2 }
        #expect(history?.archived == true)
        #expect(history?.deletedAt == GONE)

        // The essay: the exact deadline, leads, snooze (to the whole second),
        // checklist and repeat.
        let essay = b?.assignments.first { $0.id == T1 }
        #expect(essay?.courseID == C1)
        #expect(essay?.due == "2026-09-07")
        #expect(essay?.dueTime == "23:30")
        #expect(essay?.reminder == true)
        #expect(essay?.notes == "Two pages")
        #expect(essay?.remindLeads == [1440, 60])
        #expect(essay?.snoozedUntil == Date(timeIntervalSince1970: 1_790_000_123))
        #expect(essay?.subtasks.map(\.title) == ["Outline"])
        #expect(essay?.subtasks.first?.done == true)
        #expect(essay?.repeatRule == .weekly)
        #expect(essay?.repeatUntil == "2026-12-01")
        // Inbox work: classId "" is no class; null due is undated.
        let inbox = b?.assignments.first { $0.id == T2 }
        #expect(inbox?.courseID == nil)
        #expect(inbox?.due == nil)
        #expect(inbox?.dueTime == nil)
        // Reading went with its class: the same stamp.
        #expect(b?.assignments.first { $0.id == T3 }?.deletedAt == GONE)
        #expect(b?.assignments.first { $0.id == T3 }?.kind == .quiz)

        #expect(b?.grades.first?.kind == .exam)
        #expect(b?.grades.first?.score == 82)
        #expect(b?.notes.first?.assignmentID == T1)
        #expect(b?.notes.first?.updatedAt == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(b?.taskPlans.first?.assignmentID == T1)
        #expect(b?.taskPlans.first?.priority == 1)
        #expect(b?.studySessions.first?.mode == .pomodoro)
        #expect(b?.studySessions.first?.minutes == 25)
        #expect(b?.progress.xp?["xp"]?.intValue == 120)
        #expect(b?.progress.pet?["name"]?.stringValue == "Bo")
        // The web's allowlist kept feeds, quotes and the setup flag out.
        #expect(b?.profile["feeds"] == nil)
        #expect(b?.profile["quotes"] == nil)
        #expect(b?.profile["termSetupPrompted"] == nil)
    }

    // MARK: - Restoring

    @Test func restoringIntoAnEmptyPhoneAddsEverythingAndSavesIt() {
        let store = fresh()
        guard let b = web else { Issue.record("the web file didn't open"); return }
        let plan = store.restorePlan(b, mode: .merge)
        #expect(plan.totalChanges == 9)
        #expect(plan.restoresPreferences)
        #expect(plan.restoresProgress)
        // web: ["classes: 2 new","assignments: 3 new","grade: 1 new","note: 1 new","planned task: 1 new","focus session: 1 new"]
        #expect(describePlan(plan) == ["classes: 2 new", "assignments: 3 new", "grade: 1 new", "note: 1 new",
                                       "planned task: 1 new", "focus session: 1 new"])

        #expect(store.restoreBackup(b, mode: .merge))
        #expect(store.preRestore != nil)
        let saved = Store.load()
        #expect(saved.courses.count == 2)
        #expect(saved.assignments.count == 3)
        #expect(saved.grades.count == 1)
        #expect(saved.notes.count == 1)
        #expect(saved.taskPlans.count == 1)
        #expect(saved.studySessions.count == 1)
        // Your preferences came back.
        #expect(saved.profile.username == "Kel")
        #expect(saved.profile.theme == .dark)
        #expect(saved.profile.accent == .ocean)
        #expect(saved.profile.postClassNudge == false)
        #expect(saved.profile.quietStart == 1320)
        #expect(saved.profile.quietEnd == 420)
        #expect(saved.profile.finalsDate == "2026-12-10")
        #expect(saved.profile.gradeScale == .simple)
        #expect(saved.profile.termStart == "2026-09-01")
        #expect(saved.profile.termEnd == "2026-12-18")
        #expect(saved.profile.termName == "Fall 2026")
        // Progress is set, never earned: it's exactly the file's.
        #expect(saved.game.xp == b.progress.xp)
        #expect(saved.game.trophies == b.progress.trophies)
        #expect(saved.game.boss == b.progress.boss)
    }

    @Test func theSameFileAgainIsAlreadyHereEvenAfterARelaunch() {
        let store = restored()
        guard let b = web else { Issue.record("the web file didn't open"); return }
        let again = store.restorePlan(b, mode: .merge)
        #expect(again.totalChanges == 0)
        // web: ["classes: 2 already here","assignments: 3 already here","grade: 1 already here",
        //       "note: 1 already here","planned task: 1 already here","focus session: 1 already here"]
        #expect(describePlan(again) == ["classes: 2 already here", "assignments: 3 already here",
                                        "grade: 1 already here", "note: 1 already here",
                                        "planned task: 1 already here", "focus session: 1 already here"])
        // planner.json keeps whole seconds; the file's moments were read that way.
        #expect(Store.load().restorePlan(b, mode: .replace).totalChanges == 0)
    }

    @Test func aPhoneBackupRestoresIntoAnotherPhoneUnchanged() {
        let store = restored()
        store.courses.append(Course(name: "Psychology", short: "Psych", color: .amber,
                                    days: [1, 3], startMin: 900, endMin: 975))
        store.save()
        let file = open(store.backupData())
        #expect(file != nil)
        guard let file else { return }
        // Against itself, nothing differs.
        #expect(store.restorePlan(file, mode: .replace).totalChanges == 0)

        let other = fresh()
        #expect(other.restoreBackup(file, mode: .replace))
        #expect(other.courses == store.courses)
        #expect(other.assignments == store.assignments)
        #expect(other.grades == store.grades)
        #expect(other.notes == store.notes)
        #expect(other.taskPlans == store.taskPlans)
        #expect(other.studySessions == store.studySessions)
        #expect(other.game == store.game)
        #expect(other.profile.theme == store.profile.theme)
        #expect(other.profile.termName == store.profile.termName)
    }

    @Test func aFractionOfASecondDoesntMakeItLookChanged() {
        // Something made on the phone today has a fraction of a second, which
        // planner.json drops. The file and a relaunch must agree about it.
        let store = fresh()
        var work = Assignment(title: "Lab report", due: "2026-10-30")
        work.snoozedUntil = Date(timeIntervalSince1970: 1_790_000_999.75)
        store.assignments = [work]
        store.save()
        let file = open(store.backupData())
        #expect(file.map { store.restorePlan($0, mode: .merge).totalChanges } == 0)
        #expect(file.map { Store.load().restorePlan($0, mode: .merge).totalChanges } == 0)
    }

    @Test func mergeKeepsWhatOnlyThisPhoneHas() {
        let store = fresh()
        let mine = Assignment(title: "Written offline")
        store.assignments = [mine]
        guard let b = web else { Issue.record("the web file didn't open"); return }
        let plan = store.restorePlan(b, mode: .merge)
        #expect(plan.tasks.onlyHere == 1)
        #expect(plan.totalChanges == 9)
        #expect(store.restorePlan(b, mode: .replace).totalChanges == 10)

        #expect(store.restoreBackup(b, mode: .merge))
        #expect(store.assignments.count == 4)
        #expect(store.assignments.first?.id == mine.id)   // what was here stays first
    }

    @Test func theFileWinsWhereBothHaveTheItem() {
        let store = restored()
        guard let b = web, let i = store.assignments.firstIndex(where: { $0.id == T1 }) else {
            Issue.record("setup failed"); return
        }
        store.assignments[i].title = "Essay (edited here)"
        #expect(store.restorePlan(b, mode: .merge).tasks.conflicting == 1)
        #expect(store.restoreBackup(b, mode: .merge))
        #expect(store.assignments[i].title == "Essay")
    }

    @Test func replaceMakesThePhoneMatchTheFile() {
        let store = restored()
        store.assignments.append(Assignment(title: "Only on this phone"))
        guard let b = web else { Issue.record("the web file didn't open"); return }
        let plan = store.restorePlan(b, mode: .replace)
        #expect(plan.tasks.onlyHere == 1)
        #expect(describePlan(plan).contains("assignments: 3 already here, 1 removed"))
        #expect(store.restoreBackup(b, mode: .replace))
        #expect(store.assignments.map(\.title).sorted() == ["Email advisor", "Essay", "Reading"])
    }

    @Test func comparingIncludesRecentlyDeleted() {
        // The web compares the file with live items only, so a deleted one
        // shows as "new" there although the restore replaces it (D-73). Here
        // the preview and the outcome agree.
        let store = restored()
        guard let b = web else { Issue.record("the web file didn't open"); return }
        #expect(store.restorePlan(b, mode: .merge).classes.identical == 2)
    }

    @Test func undoPutsBackExactlyWhatWasThere() {
        let store = Store.sample
        store.profile.username = "Before"
        store.save()
        let before = store.document
        guard let b = web else { Issue.record("the web file didn't open"); return }
        #expect(store.restoreBackup(b, mode: .replace))
        #expect(store.profile.username == "Kel")
        #expect(store.undoRestore())
        #expect(store.document == before)
        #expect(store.preRestore == nil)
        #expect(Store.load().document == before)
        // Nothing left to undo.
        #expect(!store.undoRestore())
    }

    @Test func aRestoreTakesTheUndoBarFromADelete() {
        let store = Store.sample
        store.save()
        store.deleteAssignment(store.assignments[0].id)
        #expect(store.pendingUndo != nil)
        guard let b = web else { Issue.record("the web file didn't open"); return }
        #expect(store.restoreBackup(b, mode: .merge))
        #expect(store.pendingUndo == nil)
        store.dismissRestoreSnapshot()
        #expect(store.preRestore == nil)
        // Dismissing keeps the restore.
        #expect(store.courses.contains { $0.id == C1 })
    }

    @Test func aFailedSaveRestoresNothing() {
        let store = fresh()
        guard let b = web else { Issue.record("the web file didn't open"); return }
        #expect(blockWrites())
        #expect(!store.restoreBackup(b, mode: .merge))
        #expect(store.courses.isEmpty)
        #expect(store.assignments.isEmpty)
        #expect(store.preRestore == nil)
        #expect(store.profile.username == "")
        unblock()
    }

    @Test func deletedThingsStayDeletedThroughARestore() {
        let store = restored()
        let trash = store.trash
        #expect(trash.map(\.title) == ["History", "Reading"])
        #expect(trash.last?.viaClass == true)
        #expect(!store.liveCourses.contains { $0.id == C2 })
    }

    @Test func oneDayPlanPerAssignmentAfterAMerge() {
        let store = fresh()
        store.taskPlans = [TaskPlan(assignmentID: T1, date: "2026-09-10")]
        guard let b = web else { Issue.record("the web file didn't open"); return }
        #expect(store.restoreBackup(b, mode: .merge))
        let plans = store.taskPlans.filter { $0.assignmentID == T1 }
        #expect(plans.count == 1)
        #expect(plans.first?.date == "2026-09-10")   // the plan that was here first
    }

    @Test func profileValuesThatMakeNoSenseAreIgnored() {
        let store = fresh()
        store.profile.username = "Kel"
        store.profile.accent = .ocean
        store.profile.finalsDate = "2026-12-10"
        let odd = #"""
        {"app": "ClassPing", "schemaVersion": 4, "data": {"classes": [{"id": "c1", "name": "X"}],
         "profile": {"username": "   ", "theme": "purple", "accent": "neon", "finalsDate": "soon",
                     "quietHours": {"start": 9999, "end": 5}, "termName": "  ", "secretToken": "nope"}}}
        """#
        guard let file = open(Data(odd.utf8)) else { Issue.record("the file didn't open"); return }
        #expect(store.restoreBackup(file, mode: .merge))
        #expect(store.profile.username == "Kel")          // a blank name keeps yours (D-68)
        #expect(store.profile.theme == .light)            // not a theme: yours stays
        #expect(store.profile.accent == .babypink)        // normalizeAccent: anything but ocean
        #expect(store.profile.finalsDate == "2026-12-10") // not a day: yours stays
        #expect(store.profile.quietStart == nil)          // not real quiet hours
        #expect(store.profile.termName == nil)
        // An old short id still makes a class, with the same id every time.
        #expect(store.courses.first?.id == uuid(fromWebID: "c1"))
    }

    @Test func aPhoneFileLeavesOutWhatTheWebLeavesOut() {
        let store = restored()
        store.profile.quotes = ["Keep going"]
        store.profile.termSetupPrompted = true
        let top = store.backupData().flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
        let profile = top?["data"]?["profile"]?.objectValue ?? [:]
        #expect(Set(profile.keys) == ["username", "avatarUrl", "theme", "accent", "postClassNudge",
                                      "quietHours", "finalsDate", "gradeScale", "termStart", "termEnd", "termName"])
        #expect(profile["quietHours"] == .object(["start": .number(1320), "end": .number(420)]))
        // Deleted items travel too.
        #expect(top?["data"]?["classes"]?.arrayValue?.count == 2)
    }

    // MARK: - Clearing

    @Test func clearingEmptiesThePlannerAndKeepsPreferences() {
        let store = restored()
        // Live only: Chemistry; Essay and Email advisor; Midterm; Lecture 1.
        #expect(store.clearSummary == "1 class, 2 assignments, 1 grade and 1 note")
        #expect(store.clearData())
        #expect(store.courses.isEmpty && store.assignments.isEmpty && store.grades.isEmpty)
        #expect(store.notes.isEmpty && store.taskPlans.isEmpty && store.studySessions.isEmpty)
        #expect(store.trash.isEmpty)
        #expect(store.clearSummary == nil)
        // Progress goes, except the pet (as on the web).
        #expect(store.game.xp == nil && store.game.trophies == nil && store.game.boss == nil)
        #expect(store.game.pet?["name"]?.stringValue == "Bo")
        // The term goes; the rest of your preferences stay.
        #expect(store.profile.termStart == nil && store.profile.termEnd == nil && store.profile.termName == nil)
        #expect(store.profile.finalsDate == nil)
        #expect(store.profile.termSetupPrompted == false)
        #expect(store.profile.username == "Kel")
        #expect(store.profile.theme == .dark)
        #expect(store.preRestore == nil)
        let saved = Store.load()
        #expect(saved.courses.isEmpty)
        #expect(saved.profile.theme == .dark)
        #expect(saved.game.pet != nil)
    }

    @Test func aFailedClearChangesNothing() {
        let store = restored()
        let before = store.document
        #expect(blockWrites())
        #expect(!store.clearData())
        #expect(store.document == before)
        unblock()
    }
}

/// web: buildBackup(fixture) then JSON.stringify(file, null, 2), node 24.
private let WEB_BACKUP = #"""
{
  "app": "ClassPing",
  "schemaVersion": 4,
  "exportedAt": "2026-10-21T03:04:05.678Z",
  "data": {
    "classes": [
      {
        "id": "11111111-1111-4111-8111-111111111111",
        "name": "Chemistry",
        "short": "Chem",
        "color": "teal",
        "days": [
          0,
          2
        ],
        "start": 540,
        "end": 600,
        "remindBefore": 10,
        "alarm": true,
        "reminders": [
          30
        ],
        "credits": 4,
        "room": "Sci 204",
        "instructor": "Dr Vance",
        "notes": "Bring goggles",
        "term": "Fall 2026",
        "goal": 90,
        "additionalMeetings": [
          {
            "id": "22222222-2222-4222-8222-222222222222",
            "days": [
              4
            ],
            "start": 840,
            "end": 960,
            "room": "Lab 2",
            "label": "Lab"
          }
        ]
      },
      {
        "id": "33333333-3333-4333-8333-333333333333",
        "name": "History",
        "short": "Hist",
        "color": "amber",
        "days": [
          1
        ],
        "start": 600,
        "end": 650,
        "remindBefore": 10,
        "alarm": false,
        "reminders": [],
        "archived": true,
        "deletedAt": 1790000000000
      }
    ],
    "tasks": [
      {
        "id": "44444444-4444-4444-8444-444444444444",
        "title": "Essay",
        "classId": "11111111-1111-4111-8111-111111111111",
        "due": "2026-09-07",
        "dueTime": "23:30",
        "reminder": true,
        "done": false,
        "kind": "assignment",
        "notes": "Two pages",
        "remindLeads": [
          1440,
          60
        ],
        "snoozedUntil": 1790000123456,
        "subtasks": [
          {
            "id": "77777777-7777-4777-8777-777777777777",
            "title": "Outline",
            "done": true
          }
        ],
        "repeat": "weekly",
        "repeatUntil": "2026-12-01"
      },
      {
        "id": "55555555-5555-4555-8555-555555555555",
        "title": "Email advisor",
        "classId": "",
        "due": null,
        "dueTime": null,
        "reminder": false,
        "done": false
      },
      {
        "id": "66666666-6666-4666-8666-666666666666",
        "title": "Reading",
        "classId": "33333333-3333-4333-8333-333333333333",
        "due": "2026-09-02",
        "dueTime": null,
        "reminder": false,
        "done": true,
        "kind": "quiz",
        "deletedAt": 1790000000000
      }
    ],
    "grades": [
      {
        "id": "88888888-8888-4888-8888-888888888888",
        "classId": "11111111-1111-4111-8111-111111111111",
        "title": "Midterm",
        "score": 82,
        "max": 100,
        "weight": 30,
        "date": "2026-09-01",
        "kind": "exam"
      }
    ],
    "notes": [
      {
        "id": "99999999-9999-4999-8999-999999999999",
        "classId": "11111111-1111-4111-8111-111111111111",
        "taskId": "44444444-4444-4444-8444-444444444444",
        "date": "2026-09-01",
        "title": "Lecture 1",
        "body": "Ionic bonds",
        "updatedAt": 1790000000500
      }
    ],
    "taskPlans": [
      {
        "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "taskId": "44444444-4444-4444-8444-444444444444",
        "date": "2026-09-06",
        "priority": 1,
        "updatedAt": 1790000000000
      }
    ],
    "studySessions": [
      {
        "id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        "taskId": "44444444-4444-4444-8444-444444444444",
        "classId": "11111111-1111-4111-8111-111111111111",
        "minutes": 25,
        "completedAt": 1790000100000,
        "mode": "pomodoro"
      }
    ],
    "profile": {
      "username": "Kel",
      "avatarUrl": null,
      "theme": "dark",
      "accent": "ocean",
      "postClassNudge": false,
      "quietHours": {
        "start": 1320,
        "end": 420
      },
      "finalsDate": "2026-12-10",
      "gradeScale": "simple",
      "termStart": "2026-09-01",
      "termEnd": "2026-12-18",
      "termName": "Fall 2026"
    },
    "trophies": {
      "counted": [
        "44444444-4444-4444-8444-444444444444"
      ]
    },
    "xp": {
      "xp": 120,
      "seenLevel": 3
    },
    "pet": {
      "name": "Bo"
    },
    "boss": {
      "wins": 1
    }
  }
}
"""#

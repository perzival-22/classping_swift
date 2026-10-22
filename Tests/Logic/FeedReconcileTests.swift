// FeedReconcileTests.swift: refreshing a saved calendar feed
// (Logic/FeedReconcile.swift, lib/ics-reconcile.ts). The suites up to
// "applying the plan" are the web's own ics-reconcile.test.ts, case for
// case, with its fixtures as FeedLocalRow and ImportResult values. The
// fingerprint cases check the phone against WebValues14e.swift, written by
// the web's own classFingerprint and taskFingerprint in node.
// Run: tools/logic-test.sh (CI: scripts/test-logic.sh). Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private let FEED = "feed-1"

/// The web test's `incomingClass`: Physics 101, Mon and Wed, 9:00 to 10:00.
private func incomingClass(name: String = "Physics 101", days: [Int] = [0, 2],
                           start: Int = 540, end: Int = 600, color: String = "indigo",
                           uid: String? = "uid-physics") -> ImportedClass {
    ImportedClass(name: name, short: "Physi", color: color, days: days, start: start, end: end,
                  remindBefore: 15, alarm: true, sourceUID: uid)
}

/// The web test's `localClass`: that class, imported from FEED, untouched.
private func localClass(id: String = "c1", name: String = "Physics 101",
                        feed: String? = FEED, uid: String? = "uid-physics",
                        hash: String? = classFingerprint(incomingClass().owned),
                        deleted: Bool = false) -> FeedLocalRow<OwnedClass> {
    var owned = incomingClass().owned
    owned.name = name
    return FeedLocalRow(id: id, owned: owned, sourceFeed: feed, sourceUID: uid,
                        sourceHash: hash, deleted: deleted)
}

/// The web test's `incomingTask`: Lab report 3, due 1 Oct at 23:59.
private func incomingTask(title: String = "Lab report 3", due: String? = "2026-10-01",
                          dueTime: String? = "23:59", uid: String? = "uid-lab3") -> ImportedTask {
    ImportedTask(title: title, due: due, dueTime: dueTime, kind: "assignment", sourceUID: uid)
}

/// The web test's `localTask`: that assignment, imported from FEED, untouched.
private func localTask(id: String = "t1") -> FeedLocalRow<OwnedTask> {
    FeedLocalRow(id: id, owned: incomingTask().owned, sourceFeed: FEED, sourceUID: "uid-lab3",
                 sourceHash: taskFingerprint(incomingTask().owned))
}

/// The web test's `run`.
private func run(_ found: ImportResult = ImportResult(),
                 classes: [FeedLocalRow<OwnedClass>] = [],
                 tasks: [FeedLocalRow<OwnedTask>] = []) -> FeedPlan {
    reconcileFeed(feedID: FEED, found: found, classes: classes, tasks: tasks)
}

/// Every row's key: ticking everything.
private func everything(_ plan: FeedPlan) -> Set<String> {
    Set(plan.classes.map(\.key) + plan.tasks.map(\.key))
}

@Suite struct FeedFirstSightTests {
    @Test func addsWhatThePlannerHasNeverSeen() {
        let plan = run(ImportResult(classes: [incomingClass()]))
        #expect(plan.classes.count == 1)
        #expect(plan.classes[0].action == .add)
        #expect(plan.classes[0].checked)
        #expect(plan.totals[.add] == 1)
    }

    @Test func leavesAnIdenticalRowAlone() {
        let plan = run(ImportResult(classes: [incomingClass()]), classes: [localClass()])
        #expect(plan.classes[0].action == .unchanged)
        #expect(!plan.classes[0].checked)
    }
}

@Suite struct FeedNoClonesTests {
    @Test func adoptsARowImportedBeforeUIDsWereRecorded() {
        let legacy = localClass(feed: nil, uid: nil, hash: nil)
        let plan = run(ImportResult(classes: [incomingClass()]), classes: [legacy])
        #expect(plan.classes.count == 1)
        #expect(plan.classes[0].action == .adopt)
        #expect(plan.classes[0].localID == "c1")
        #expect(plan.classes[0].checked)
        #expect(plan.totals[.add] == 0)
    }

    @Test func stampsProvenanceOnTheAdoptedRow() {
        let legacy = localClass(feed: nil, uid: nil, hash: nil)
        let plan = run(ImportResult(classes: [incomingClass()]), classes: [legacy])
        let write = planWrites(plan, accepted: plan.defaultPicks)
        #expect(write.addClasses.isEmpty)
        #expect(write.updateClasses[0].stamp.sourceFeed == FEED)
        #expect(write.updateClasses[0].stamp.sourceUID == "uid-physics")
        #expect(write.updateClasses[0].stamp.sourceHash == classFingerprint(incomingClass().owned))
    }

    @Test func doesNotAdoptARowAnotherFeedOwns() {
        let other = localClass(feed: "feed-2", uid: "elsewhere")
        let plan = run(ImportResult(classes: [incomingClass()]), classes: [other])
        #expect(plan.classes.map(\.action).contains(.add))
    }
}

@Suite struct FeedWhoChangedItTests {
    @Test func updatesAnUntouchedRowAndNamesTheFieldsThatMoved() {
        let moved = incomingClass(days: [1, 3], start: 600, end: 660)
        let plan = run(ImportResult(classes: [moved]), classes: [localClass()])
        let entry = plan.classes[0]
        #expect(entry.action == .update)
        #expect(entry.checked)
        #expect(entry.changes.map(\.label) == ["Days", "Time"])
        #expect(entry.changes[0].from == "Mon Wed")
        #expect(entry.changes[0].to == "Tue Thu")
    }

    @Test func callsItAConflictWhenTheStudentEditedTheSameRow() {
        let edited = localClass(name: "Physics, Dr Ade")
        let moved = incomingClass(start: 600, end: 660)
        let plan = run(ImportResult(classes: [moved]), classes: [edited])
        #expect(plan.classes[0].action == .conflict)
        #expect(!plan.classes[0].checked)
    }

    @Test func treatsARowWithNoFingerprintAsEdited() {
        let unknown = localClass(hash: nil)
        let plan = run(ImportResult(classes: [incomingClass(start: 600, end: 660)]), classes: [unknown])
        #expect(plan.classes[0].action == .conflict)
    }

    @Test func ignoresChangesToFieldsTheFeedDoesNotOwn() {
        // Color, reminders and alarm aren't in the owned fields at all, so a
        // feed that differs only there is "unchanged".
        let plan = run(ImportResult(classes: [incomingClass(color: "coral")]), classes: [localClass()])
        #expect(plan.classes[0].action == .unchanged)
    }

    @Test func neverWritesBackAFieldTheFeedDoesNotOwn() {
        let moved = incomingClass(start: 600, end: 660, color: "violet")
        let plan = run(ImportResult(classes: [moved]), classes: [localClass()])
        let write = planWrites(plan, accepted: plan.defaultPicks)
        // A class update carries only name, days, start, end, room and the stamp.
        let update = write.updateClasses[0]
        #expect(update.start == 600)
        #expect(update.end == 660)
        #expect(update.name == "Physics 101")
        #expect(update.room == nil)
    }
}

@Suite struct FeedTaskTests {
    @Test func aRepublishedDeadlineCarriesNoDoneAndNoClass() {
        // FeedTaskUpdate has no `done` and no class: they can't be written.
        let plan = run(ImportResult(tasks: [incomingTask(dueTime: "17:00")]), tasks: [localTask()])
        let write = planWrites(plan, accepted: plan.defaultPicks)
        #expect(write.updateTasks.count == 1)
        #expect(write.updateTasks[0].dueTime == "17:00")
    }

    @Test func reportsAMovedDeadlineInWordsAStudentCanCheck() {
        let plan = run(ImportResult(tasks: [incomingTask(due: "2026-10-03")]), tasks: [localTask()])
        #expect(plan.tasks[0].changes[0] == FieldChange(field: "due", label: "Due",
                                                        from: "2026-10-01 23:59", to: "2026-10-03 23:59"))
    }

    @Test func aRenamedDeadlineIsAnUpdate() {
        let plan = run(ImportResult(tasks: [incomingTask(title: "Lab report 3 (revised)")]), tasks: [localTask()])
        #expect(plan.tasks[0].action == .update)
        #expect(plan.tasks[0].changes.map(\.label) == ["Title"])
    }
}

@Suite struct FeedLeavingTests {
    @Test func separatesACancellationFromAnAbsence() {
        let plan = run(ImportResult(cancelled: ["uid-physics"]),
                       classes: [localClass(), localClass(id: "c2", uid: "uid-maths")])
        let byID = Dictionary(uniqueKeysWithValues: plan.classes.map { ($0.localID ?? "", $0.action) })
        #expect(byID["c1"] == .withdrawn)
        #expect(byID["c2"] == .missing)
    }

    @Test func neverPreTicksARemoval() {
        let plan = run(ImportResult(cancelled: ["uid-physics"]), classes: [localClass()])
        #expect(!plan.classes[0].checked)
        #expect(planWrites(plan, accepted: plan.defaultPicks).removeClassIDs.isEmpty)
    }

    @Test func removesOnlyWhatWasTickedAndByTheRightKind() {
        let plan = run(ImportResult(cancelled: ["uid-physics", "uid-lab3"]),
                       classes: [localClass()], tasks: [localTask()])
        let write = planWrites(plan, accepted: everything(plan))
        #expect(write.removeClassIDs == ["c1"])
        #expect(write.removeTaskIDs == ["t1"])
    }

    @Test func neverReAddsSomethingTheStudentDeleted() {
        let binned = localClass(deleted: true)
        let plan = run(ImportResult(classes: [incomingClass()]), classes: [binned])
        #expect(plan.classes.map(\.action) == [.unchanged])
        #expect(planWrites(plan, accepted: plan.defaultPicks).addClasses.isEmpty)
    }

    @Test func doesNotOfferToRemoveSomethingAlreadyDeleted() {
        let binned = localClass(deleted: true)
        let plan = run(ImportResult(cancelled: ["uid-physics"]), classes: [binned])
        #expect(plan.classes.isEmpty)
    }

    @Test func leavesADeletedRowAloneEvenWhenTheFeedChangedIt() {
        let binned = localClass(deleted: true)
        let plan = run(ImportResult(classes: [incomingClass(start: 600, end: 660)]), classes: [binned])
        #expect(plan.classes[0].action == .unchanged)
        #expect(planWrites(plan, accepted: plan.defaultPicks).updateClasses.isEmpty)
    }

    @Test func ignoresRowsThatCameFromSomewhereElse() {
        let typedByHand = localClass(id: "c3", name: "Choir", feed: nil, uid: nil, hash: nil)
        let plan = run(ImportResult(), classes: [typedByHand])
        #expect(plan.classes.isEmpty)
    }
}

@Suite struct FeedApplyTests {
    @Test func writesNothingTheStudentDidNotTick() {
        let plan = run(ImportResult(classes: [incomingClass()]))
        #expect(planWrites(plan, accepted: []) == FeedWrite())
    }

    @Test func stampsAFreshFingerprintOnEveryAdd() {
        let plan = run(ImportResult(classes: [incomingClass()]))
        let added = planWrites(plan, accepted: plan.defaultPicks).addClasses[0]
        #expect(added.stamp.sourceFeed == FEED)
        #expect(added.stamp.sourceHash == classFingerprint(added.item.owned))
    }

    @Test func letsTheStudentAcceptAConflict() {
        let edited = localClass(name: "Physics, Dr Ade")
        let plan = run(ImportResult(classes: [incomingClass(start: 600, end: 660)]), classes: [edited])
        let write = planWrites(plan, accepted: everything(plan))
        #expect(write.updateClasses[0].start == 600)
        #expect(write.updateClasses[0].name == "Physics 101")
    }

    @Test func givesEveryRowAKeyThatSurvivesReSorting() {
        let plan = run(ImportResult(classes: [incomingClass(), incomingClass(uid: "b")]))
        let keys = plan.classes.map(\.key)
        #expect(Set(keys).count == keys.count)
    }
}

// MARK: - The phone's own checks

@Suite struct FeedFingerprintTests {
    @Test func classFingerprintsMatchTheWeb() {
        for c in WEB_CLASS_FINGERPRINTS {
            let owned = OwnedClass(name: c.name, days: c.days, start: c.start, end: c.end, room: c.room)
            #expect(classFingerprint(owned) == c.hash, "\(c.name)")
        }
    }

    @Test func taskFingerprintsMatchTheWeb() {
        for t in WEB_TASK_FINGERPRINTS {
            let owned = OwnedTask(title: t.title, due: t.due, dueTime: t.dueTime, kind: t.kind)
            #expect(taskFingerprint(owned) == t.hash, "\(t.title)")
        }
    }

    @Test func writesStringsTheWayJavaScriptDoes() {
        #expect(jsJSONString("a/b") == #""a/b""#)
        #expect(jsJSONString("say \"hi\"\\") == #""say \"hi\"\\""#)
        #expect(jsJSONString("\u{1}\u{1f}\t\n") == #""\u0001\u001f\t\n""#)
        #expect(jsJSONString("café ☕️") == "\"café ☕️\"")
    }

    @Test func classJSONLeavesOutAnEmptyRoomAndSortsTheDays() {
        let owned = OwnedClass(name: "Bio", days: [3, 1], start: 540, end: 600, room: "")
        #expect(ownedClassJSON(owned) == #"{"name":"Bio","days":[1,3],"start":540,"end":600}"#)
    }

    @Test func extraMeetingsMakeAClassLookEdited() {
        var owned = incomingClass().owned
        let plain = classFingerprint(owned)
        owned.additionalMeetings = [ClassMeeting(days: [4], start: 600, end: 660)]
        #expect(classFingerprint(owned) != plain)
    }

    @Test func showsTimesAndDaysAsTheWebDoes() {
        #expect(feedTimeText(545) == "09:05")
        #expect(feedDaysText([]) == "-")
        let change = classChanges(OwnedClass(name: "A", days: [0], start: 540, end: 600, room: nil),
                                  OwnedClass(name: "A", days: [0], start: 540, end: 600, room: "B12"))
        #expect(change == [FieldChange(field: "room", label: "Room", from: "-", to: "B12")])
    }

    @Test func identitiesIgnoreCaseAndSpaces() {
        #expect(classIdentity(OwnedClass(name: "  Physics 101 ", days: [2, 0], start: 540, end: 600))
                == "physics 101|0,2|540")
        #expect(taskIdentity(OwnedTask(title: "Essay", due: nil, dueTime: nil, kind: "assignment")) == "essay|")
    }
}

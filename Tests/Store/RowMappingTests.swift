// RowMappingTests.swift: the Swift twin of lib/supabase/columns.test.ts's
// "the mappers and the column lists agree" and "scoping a batch" cases, now
// that 14b has the mappers, plus parity with the web's own map.ts: each item
// below is the one gen.ts gave the web, and WebRows14b.swift holds what the
// web's mapper wrote for it ("web:"). The round trips take a row as the
// server sends it (rev, updated_at, "23:30:00", "80.5", "+00:00") through the
// phone's model and back, and expect the web's `xToRow(rowToX(row))`.
// Run: tools/persistence-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
private let UID = "user_123"
private let C1 = id("11111111-1111-4111-8111-111111111111")
private let T1 = id("22222222-2222-4222-8222-222222222222")
private let T2 = id("22222222-2222-4222-8222-2222222222b2")
private let G1 = id("33333333-3333-4333-8333-333333333333")
private let N1 = id("44444444-4444-4444-8444-444444444444")
private let P1 = id("55555555-5555-4555-8555-555555555555")
private let S1 = id("66666666-6666-4666-8666-666666666666")
private let M1 = id("77777777-7777-4777-8777-777777777777")
private let ST1 = id("88888888-8888-4888-8888-888888888888")
private let F1 = id("99999999-9999-4999-8999-999999999999")
private let F2 = id("99999999-9999-4999-8999-9999999999f2")
private let F1_TEXT = "99999999-9999-4999-8999-999999999999"
private let MOMENT = Date(timeIntervalSince1970: 1_790_000_000)   // 2026-09-21 14:13:20 UTC
private let EPOCH = Date(timeIntervalSince1970: 0)

/// JSON text from WebRows14b.swift as a value.
private func json(_ text: String) -> JSONValue? {
    try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
}

/// A row as a dictionary, from JSON text.
private func row(_ text: String) -> ServerRow {
    json(text)?.objectValue ?? [:]
}

// MARK: - The items gen.ts gave the web, built the phone's way

private func aClass() -> Course {
    var c = Course(id: C1, name: "Physics", short: "Phys", color: .indigo, days: [0, 2], startMin: 540, endMin: 600)
    c.remindBefore = 15
    c.alarm = true
    return c
}

private func fullClass() -> Course {
    var c = Course(id: C1, name: "Chemistry", short: "CHEM", color: .teal, days: [1, 3], startMin: 600, endMin: 675)
    c.additionalMeetings = [ClassMeeting(id: M1, days: [4], start: 780, end: 900, room: "Lab 2", label: "Lab")]
    c.remindBefore = 10
    c.alarm = false
    c.extraReminders = [30, 5]
    c.credits = 3
    c.room = "B12"
    c.instructor = "Dr. Ade"
    c.notes = "bring goggles"
    c.term = "Fall 2026"
    c.archived = true
    c.goal = 90
    c.sourceFeed = F1_TEXT
    c.sourceUID = "uid-1@school"
    c.sourceHash = "h1"
    c.deletedAt = MOMENT
    return c
}

private func aTask() -> Assignment {
    var t = Assignment(id: T1, courseID: C1, title: "Essay", due: "2026-09-10", dueTime: "23:30")
    t.reminder = true
    t.kind = .assignment
    return t
}

private func fullTask() -> Assignment {
    var t = Assignment(id: T1, courseID: C1, title: "Final exam", due: "2026-12-10", dueTime: "09:00")
    t.done = true
    t.kind = .exam
    t.notes = "Ch 1 to 9"
    t.subtasks = [Subtask(id: ST1, title: "Outline", done: true)]
    t.remindLeads = [4320, 60, 60, 0, 30000]
    t.snoozedUntil = MOMENT.addingTimeInterval(3600)
    t.repeatRule = .weekly
    t.repeatUntil = "2026-12-01"
    t.recurrenceParentID = T2
    t.sourceFeed = F1_TEXT
    t.sourceUID = "uid-2@school"
    t.sourceHash = "h2"
    t.deletedAt = MOMENT
    return t
}

private func undatedTask() -> Assignment {
    var t = Assignment(id: T2, courseID: nil, title: "Read ch 3", due: nil, dueTime: "10:00")
    t.kind = .reminder
    return t
}

private func badDueTask() -> Assignment {
    var t = Assignment(id: T2, courseID: C1, title: "Lab report", due: "2026-13-45", dueTime: "10:00")
    t.reminder = true
    t.kind = .quiz
    return t
}

private func grade() -> Grade {
    var g = Grade(id: G1, courseID: C1, title: "Midterm", score: 80.5, max: 100, weight: 30, date: "2026-09-01T12:00:00.000Z")
    g.kind = .exam
    return g
}

private func inboxGrade() -> Grade {
    var g = Grade(id: G1, courseID: nil, title: "Quiz", score: 9, max: 10, weight: 5, date: "2026-09-02")
    g.deletedAt = MOMENT
    return g
}

private func note() -> Note {
    Note(id: N1, courseID: C1, date: "2026-09-01", title: "Week 1", body: "Notes", assignmentID: T1, updatedAt: MOMENT)
}

private func quickNote() -> Note {
    var n = Note(id: N1, courseID: nil, date: "2026-09-03", title: "", body: "", assignmentID: nil, updatedAt: EPOCH)
    n.deletedAt = MOMENT
    return n
}

private func fullProfile() -> Profile {
    var p = Profile()
    p.username = "Kelvin"
    p.avatarURL = "https://img.example/a.jpg"
    p.theme = .dark
    p.accent = .ocean
    p.postClassNudge = false
    p.quietStart = 1320
    p.quietEnd = 420
    p.finalsDate = "2026-12-10"
    p.gradeScale = .custom
    p.termStart = "2026-09-02"
    p.termEnd = "2026-12-18"
    p.termName = "Fall 2026"
    p.termSetupPrompted = true
    p.importFeeds = [
        SavedFeed(id: F1, url: "https://Canvas.Example.edu/feed.ics?token=abc", label: "  ", lastSyncedAt: MOMENT),
        SavedFeed(id: F1, url: "https://twice.example.edu/x.ics", label: "Twice", lastSyncedAt: nil),
        SavedFeed(id: F2, url: "ftp://files.example.edu/x.ics", label: "FTP", lastSyncedAt: nil),
    ]
    p.customScale = [ScaleBand(min: 80.04, letter: "B", points: 3.333), ScaleBand(min: 90, letter: "A", points: 4)]
    p.quotes = ["  Keep going  ", "", String(repeating: "x", count: 250)]
    return p
}

private func plainProfile() -> Profile {
    var p = Profile()
    p.username = "student"
    return p
}

/// Every item gen.ts mapped, by the name WebRows14b.swift uses, as the
/// phone's own row.
private func phoneRow(_ name: String) -> ServerRow? {
    switch name {
    case "aClass": return aClass().serverRow(userID: UID)
    case "fullClass": return fullClass().serverRow(userID: UID)
    case "aTask": return aTask().serverRow(userID: UID)
    case "fullTask": return fullTask().serverRow(userID: UID)
    case "undatedTask": return undatedTask().serverRow(userID: UID)
    case "badDueTask": return badDueTask().serverRow(userID: UID)
    case "grade": return grade().serverRow(userID: UID)
    case "inboxGrade": return inboxGrade().serverRow(userID: UID)
    case "note": return note().serverRow(userID: UID)
    case "quickNote": return quickNote().serverRow(userID: UID)
    case "plan": return TaskPlan(id: P1, assignmentID: T1, date: "2026-09-08", priority: 1, updatedAt: EPOCH).serverRow(userID: UID)
    case "plainPlan": return TaskPlan(id: P1, assignmentID: T1, date: "2026-09-09", priority: nil, updatedAt: EPOCH).serverRow(userID: UID)
    case "session": return StudySession(id: S1, assignmentID: T1, courseID: C1, minutes: 25, completedAt: MOMENT, mode: .pomodoro).serverRow(userID: UID)
    case "looseSession": return StudySession(id: S1, assignmentID: nil, courseID: nil, minutes: 50, completedAt: MOMENT, mode: .timer).serverRow(userID: UID)
    case "profile": return plainProfile().serverRow(userID: UID)
    case "fullProfile": return fullProfile().serverRow(userID: UID)
    case "game":
        return GameBlobs(trophies: .object([:]), xp: .object(["total": .number(120)]),
                         pet: .object(["tier": .number(2)]), boss: .null).serverRow(userID: UID)
    case "emptyGame": return GameBlobs().serverRow(userID: UID)
    default: return nil
    }
}

/// A server row through the phone's model and back, by the round trip's name.
private func phoneRoundTrip(_ name: String, _ r: ServerRow) -> ServerRow? {
    if name.hasPrefix("classRow") { return Course(serverRow: r)?.serverRow(userID: UID) }
    if name.hasPrefix("taskRow") { return Assignment(serverRow: r)?.serverRow(userID: UID) }
    if name.hasPrefix("gradeRow") { return Grade(serverRow: r)?.serverRow(userID: UID) }
    if name.hasPrefix("noteRow") { return Note(serverRow: r)?.serverRow(userID: UID) }
    if name.hasPrefix("planRow") { return TaskPlan(serverRow: r)?.serverRow(userID: UID) }
    if name.hasPrefix("sessionRow") { return StudySession(serverRow: r)?.serverRow(userID: UID) }
    if name.hasPrefix("profileRow") { return Profile(serverRow: r).serverRow(userID: UID) }
    if name.hasPrefix("gameRow") { return GameBlobs(serverRow: r).serverRow(userID: UID) }
    return nil
}

/// The row each table's mapper writes, for the column checks. The web's
/// `MAPPED` record: one per table, and a missing table fails here too.
private func mapped(_ table: ScopedTable) -> ServerRow {
    switch table {
    case .classes: return aClass().serverRow(userID: UID)
    case .tasks: return aTask().serverRow(userID: UID)
    case .grades: return grade().serverRow(userID: UID)
    case .notes: return note().serverRow(userID: UID)
    case .taskPlans: return phoneRow("plan") ?? [:]
    case .studySessions: return phoneRow("session") ?? [:]
    case .profiles: return plainProfile().serverRow(userID: UID)
    case .gameState: return GameBlobs().serverRow(userID: UID)
    }
}

@Suite struct RowMappingTests {
    // MARK: the mappers and the column lists agree (columns.test.ts)

    @Test(arguments: ScopedTable.allCases)
    func theMapperWritesExactlyTheDeclaredColumns(_ table: ScopedTable) {
        #expect(mapped(table).keys.sorted() == table.columns.sorted(), "table: \(table.rawValue)")
    }

    @Test func noMapperWritesAColumnTheDatabaseOwns() {
        for table in ScopedTable.allCases {
            #expect(mapped(table)["rev"] == nil)
            #expect(mapped(table)["updated_at"] == nil)
        }
        #expect(mapped(.profiles)["tz"] == nil)
    }

    // MARK: scoping a batch of real rows (columns.test.ts)

    @Test func aBatchOfTasksKeepsOneSetOfColumns() {
        var exam = aTask()
        exam.id = T2
        exam.kind = .exam
        exam.remindLeads = [4320]
        let rows = (try? scopeRows(.tasks, [aTask().serverRow(userID: UID), exam.serverRow(userID: UID)]).get()) ?? []
        #expect(rows.count == 2)
        #expect(Set(rows[0].keys) == Set(rows[1].keys))
        #expect(rows[0].keys.sorted() == ScopedTable.tasks.columns.sorted())
    }

    @Test func keepsTheExplicitNullThatClearsDeletedAt() {
        let rows = (try? scopeRows(.tasks, [aTask().serverRow(userID: UID)]).get()) ?? []
        #expect(rows.first?["deleted_at"] == .null)
    }

    @Test func scopingTheProfileDropsTz() {
        var withZone = plainProfile().serverRow(userID: UID)
        withZone["tz"] = .string("UTC")
        let scoped = (try? scopeRow(.profiles, withZone).get()) ?? [:]
        #expect(scoped["tz"] == nil)
        #expect(scoped.keys.sorted() == ScopedTable.profiles.columns.sorted())
    }

    // MARK: parity with the web's map.ts ("web:")

    @Test(arguments: WEB_ITEM_ROWS.keys.sorted())
    func writesTheSameRowAsTheWeb(_ name: String) {
        let web = WEB_ITEM_ROWS[name].flatMap(json)
        #expect(web != nil, "web: \(name)")
        #expect(phoneRow(name).map(JSONValue.object) == web, "web: \(name)")
    }

    @Test(arguments: WEB_ROUND_TRIPS.keys.sorted())
    func readsAndWritesAServerRowAsTheWebDoes(_ name: String) {
        guard let trip = WEB_ROUND_TRIPS[name], var back = json(trip.back)?.objectValue else {
            Issue.record("no web value for \(name)")
            return
        }
        // The one known difference: the phone keeps grade scales it knows
        // ("standard", "simple", "custom"), so a made-up one reads as none.
        if name == "profileRowOdd" { back["grade_scale"] = .null }
        #expect(phoneRoundTrip(name, row(trip.row)) == back, "web: \(name)")
    }

    // MARK: the phone's own rules

    @Test func aRowWithoutAnIdIsSkipped() {
        #expect(Course(serverRow: [:]) == nil)
        #expect(Assignment(serverRow: ["id": .string("")]) == nil)
        #expect(Grade(serverRow: ["id": .null]) == nil)
        #expect(Note(serverRow: [:]) == nil)
        #expect(TaskPlan(serverRow: ["id": .string(P1.uuidString)]) == nil)   // no task
        #expect(StudySession(serverRow: [:]) == nil)
    }

    @Test func aMomentKeepsWholeSecondsOnThePhone() {
        // D-73: the web would send back "…20.500Z"; the phone keeps whole
        // seconds, so its row says what it will say again after a relaunch.
        var r = row(WEB_ROUND_TRIPS["sessionRow"]?.row ?? "")
        r["completed_at"] = .string("2026-09-21T14:13:20.5+00:00")
        let back = StudySession(serverRow: r)?.serverRow(userID: UID)
        #expect(back?["completed_at"] == .string("2026-09-21T14:13:20.000Z"))
    }

    @Test func idsGoOutInLowerCase() {
        #expect(aClass().serverRow(userID: UID)["id"] == .string("11111111-1111-4111-8111-111111111111"))
        let upper = row(#"{"id":"22222222-2222-4222-8222-2222222222B2","user_id":"u","title":"x","due":null}"#)
        #expect(Assignment(serverRow: upper)?.serverRow(userID: UID)["id"] == .string("22222222-2222-4222-8222-2222222222b2"))
    }

    @Test func daysOutsideTheWeekAreDropped() {
        var r = aClass().serverRow(userID: UID)
        r["days"] = .array([.int(0), .int(7), .int(0), .int(-1), .int(4)])
        #expect(Course(serverRow: r)?.days == [0, 4])
    }

    @Test func aRowAndTheItemItMakesAgree() {
        // Whatever the phone makes from its own row, it writes again unchanged:
        // the merge's fingerprints (14a) depend on that.
        for name in WEB_ITEM_ROWS.keys.sorted() {
            guard let first = phoneRow(name) else { continue }
            #expect(phoneRoundTrip(roundTripName(name), first) == first, "item: \(name)")
        }
    }
}

/// The round-trip name for an item's table, so `phoneRoundTrip` knows the type.
private func roundTripName(_ item: String) -> String {
    if item.hasSuffix("Class") || item == "aClass" { return "classRow" }
    if item.hasSuffix("Task") { return "taskRow" }
    if item.hasSuffix("rade") { return "gradeRow" }
    if item.hasSuffix("ote") { return "noteRow" }
    if item.hasSuffix("lan") { return "planRow" }
    if item.hasSuffix("ession") { return "sessionRow" }
    if item.hasSuffix("rofile") { return "profileRow" }
    return "gameRow"
}

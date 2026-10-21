// CalendarExportTests.swift: the .ics file (lib/calendar.ts). The first
// groups are the web's own calendar.test.ts, case for case; the class ids are
// UUIDs here, so the UIDs are checked in lower case, the way the web writes
// them. "The whole file" compares against the web's own output for the same
// classes and work: printed by buildCalendarFile in node 24, TZ=America/New_York,
// with every DTSTAMP (the moment the file was made) replaced by X.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

private func uuid(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }

/// A stand-in class: Chemistry, Mon/Wed 10:00 to 11:20, a 15-minute alarm.
private struct Klass: CalendarClass {
    var id = uuid("11111111-1111-4111-8111-111111111111")
    var name = "Chemistry"
    var days = [0, 2]
    var startMin = 600
    var endMin = 680
    var room: String? = nil
    var additionalMeetings: [ClassMeeting] = []
    var alarm = true
    var remindBefore = 15
    var archived = false
    var instructor: String? = nil
    var notes: String? = nil
    var extraReminders: [Int] = []
}

/// A stand-in piece of work: Essay, due Wed 12 Aug 2026 at 23:59, reminder on.
private struct Work: Remindable {
    var id = uuid("44444444-4444-4444-8444-444444444444")
    var title = "Essay"
    var courseID: UUID? = nil
    var kindName = "assignment"
    var due: String? = "2026-08-12"
    var dueTime: String? = "23:59"
    var reminder = true
    var done = false
    var remindLeads: [Int] = []
    var snoozedUntil: Date? = nil
}

/// Mon 10 Aug 2026, 8:00 AM, the web test's NOW.
private let NOW = at(2026, 8, 10, 8, 0)

private func build(_ classes: [Klass], _ tasks: [Work] = [], term: TermWindow? = nil) -> String {
    buildCalendarFile(classes, tasks, className: { _ in "Chemistry" }, now: NOW, term: term)
}

private func withTerm(_ start: String?, _ end: String?) -> String {
    build([Klass()], term: TermWindow(start: start, end: end))
}

/// The file's lines. Swift treats "\r\n" as one character, so it can split on it.
private func lines(_ ics: String) -> [String] {
    ics.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
}

@Suite struct CalendarStructureTests {
    @Test func wrapsEverythingAndEndsWithCRLF() {
        let ics = build([Klass()])
        #expect(ics.hasPrefix("BEGIN:VCALENDAR\r\n"))
        #expect(ics.hasSuffix("END:VCALENDAR\r\n"))
    }

    @Test func usesCRLFThroughout() {
        // Every line feed byte comes straight after a carriage return.
        let bytes = Array(build([Klass()], [Work()]).utf8)
        let bare = bytes.indices.contains { i in bytes[i] == 0x0A && (i == 0 || bytes[i - 1] != 0x0D) }
        #expect(!bare)
    }

    @Test func balancesEveryBeginWithAnEnd() {
        let all = lines(build([Klass()], [Work()]))
        let begins = all.filter { $0.hasPrefix("BEGIN:") }.count
        let ends = all.filter { $0.hasPrefix("END:") }.count
        #expect(begins == ends)
        #expect(begins > 0)
    }

    @Test func skipsAClassThatMeetsOnNoDays() {
        #expect(!build([Klass(days: [])]).contains("SUMMARY:Chemistry"))
    }

    @Test func skipsCompletedWorkAndUnreadableDates() {
        let ics = build([], [Work(title: "Done thing", done: true),
                             Work(title: "Broken thing", due: "not-a-date", dueTime: nil)])
        #expect(!ics.contains("Done thing"))
        #expect(!ics.contains("Broken thing"))
    }
}

@Suite struct CalendarClassTests {
    @Test func writesAWeeklyRuleWithTheRightDays() {
        #expect(build([Klass(days: [0, 2])]).contains("RRULE:FREQ=WEEKLY;BYDAY=MO,WE"))
        #expect(build([Klass(days: [4])]).contains("RRULE:FREQ=WEEKLY;BYDAY=FR"))
        #expect(build([Klass(days: [5, 6])]).contains("RRULE:FREQ=WEEKLY;BYDAY=SA,SU"))
        // Days stored out of order still come out Monday first.
        #expect(build([Klass(days: [3, 1])]).contains("RRULE:FREQ=WEEKLY;BYDAY=TU,TH"))
    }

    @Test func givesEachClassAStableLowerCaseUID() {
        let id = uuid("ABCDEF12-3456-4789-8ABC-DEF012345678")
        #expect(build([Klass(id: id)]).contains("UID:classping-class-abcdef12-3456-4789-8abc-def012345678@classping"))
    }

    @Test func writesFloatingLocalTimesWithNoZ() {
        let all = lines(build([Klass(startMin: 600, endMin: 680)]))
        #expect(all.contains { $0.hasPrefix("DTSTART:") && $0.hasSuffix("T100000") })
        #expect(all.contains { $0.hasPrefix("DTEND:") && $0.hasSuffix("T112000") })
        #expect(!all.contains { $0.hasPrefix("DTSTART:") && $0.hasSuffix("Z") })
    }

    @Test func oneAlarmPerDistinctLeadEarliestFirst() {
        let all = lines(build([Klass(remindBefore: 15, extraReminders: [60, 15, 1440])]))
        let triggers = all.filter { $0.hasPrefix("TRIGGER:-PT") }
        #expect(triggers == ["TRIGGER:-PT1440M", "TRIGGER:-PT60M", "TRIGGER:-PT15M"])
        #expect(all.contains("DESCRIPTION:Chemistry starts in 1 day"))
        #expect(all.contains("DESCRIPTION:Chemistry starts in 1 hour"))
        #expect(all.contains("DESCRIPTION:Chemistry starts in 15 minutes"))
    }

    @Test func noAlarmsWhenTheClassAlarmIsOff() {
        #expect(!build([Klass(alarm: false)]).contains("BEGIN:VALARM"))
    }

    @Test func roomIsTheLocationAndTheTeacherTheDescription() {
        let ics = build([Klass(room: "Sci 204", instructor: "Dr Vance")])
        #expect(ics.contains("LOCATION:Sci 204"))
        #expect(ics.contains("DESCRIPTION:With Dr Vance"))
    }

    @Test func noLocationWithoutARoom() {
        #expect(!build([Klass()]).contains("LOCATION:"))
        // An empty room is no room, as on the web (where "" is falsy).
        #expect(!build([Klass(room: "")]).contains("LOCATION:"))
    }

    /// Phone-only: a lab is its own weekly event, keyed like the web's.
    @Test func anExtraMeetingIsItsOwnEvent() {
        let lab = ClassMeeting(id: uuid("22222222-2222-4222-8222-222222222222"),
                               days: [4], start: 840, end: 960, room: "Lab 2", label: "Lab")
        let ics = build([Klass(additionalMeetings: [lab])])
        #expect(ics.contains("RRULE:FREQ=WEEKLY;BYDAY=FR"))
        #expect(ics.contains("LOCATION:Lab 2"))
        // The UID is long enough to be folded; unfolded, it's the web's key.
        #expect(ics.replacingOccurrences(of: "\r\n ", with: "").contains(
            "UID:classping-class-11111111-1111-4111-8111-111111111111:22222222-2222-4222-8222-222222222222@classping"))
    }
}

@Suite struct CalendarTermTests {
    @Test func repeatsForeverWithNoTerm() {
        #expect(!build([Klass()]).contains("UNTIL="))
    }

    @Test func stopsTheWeeklyRuleAtTheEndOfTerm() {
        #expect(withTerm("2026-08-01", "2026-12-15").contains("RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261215T235900"))
    }

    @Test func aTermThatHasntBegunStartsOnItsFirstMeeting() {
        // NOW is Mon 10 Aug; the term opens Mon 7 Sep.
        #expect(withTerm("2026-09-07", "2026-12-15").contains("DTSTART:20260907T100000"))
    }

    @Test func anchorsToTodayOnceTheTermIsUnderWay() {
        #expect(withTerm("2026-08-01", "2026-12-15").contains("DTSTART:20260810T100000"))
    }

    @Test func leavesOutAClassWhoseTermHasEnded() {
        #expect(!withTerm("2026-01-05", "2026-05-01").contains("SUMMARY:Chemistry"))
    }

    @Test func boundsTheHalfThatIsSet() {
        #expect(withTerm(nil, "2026-12-15").contains("UNTIL=20261215T235900"))
        #expect(withTerm("2026-09-07", nil).contains("DTSTART:20260907T100000"))
    }

    @Test func ignoresAnInvertedRange() {
        let ics = withTerm("2026-12-15", "2026-08-01")
        #expect(ics.contains("SUMMARY:Chemistry"))
        #expect(!ics.contains("UNTIL="))
    }

    @Test func ignoresAMalformedDate() {
        #expect(!withTerm("not-a-date", "also-not").contains("UNTIL="))
    }

    @Test func keepsDeadlinesOutsideTheTerm() {
        let ics = build([], [Work(due: "2027-01-04", dueTime: "09:00")],
                        term: TermWindow(start: "2026-08-01", end: "2026-12-15"))
        #expect(ics.contains("SUMMARY:Essay due"))
    }
}

@Suite struct CalendarWorkTests {
    @Test func anAssignmentGetsOneDayAlarm() {
        let ics = build([], [Work()])
        #expect(ics.contains("TRIGGER:-PT24H"))
        #expect(!ics.contains("TRIGGER:-P7D"))
        #expect(ics.contains("DESCRIPTION:Essay is due in 24 hours"))
    }

    @Test func anExamGetsAWeeksWarningToo() {
        let ics = build([], [Work(kindName: "exam")])
        #expect(ics.contains("TRIGGER:-P7D"))
        #expect(ics.contains("TRIGGER:-PT24H"))
        #expect(ics.contains("SUMMARY:\u{1F4DD} Essay"))
        #expect(ics.contains("DESCRIPTION:Essay is in a week"))
    }

    @Test func blocks90MinutesForAnExamAnd30ForAnAssignment() {
        let exam = build([], [Work(kindName: "exam", due: "2026-08-12", dueTime: "09:00")])
        #expect(exam.contains("DTSTART:20260812T090000"))
        #expect(exam.contains("DTEND:20260812T103000"))
        let essay = build([], [Work(due: "2026-08-12", dueTime: "09:00")])
        #expect(essay.contains("DTEND:20260812T093000"))
    }

    @Test func noAlarmWhenTheReminderIsOff() {
        #expect(!build([], [Work(reminder: false)]).contains("BEGIN:VALARM"))
    }

    /// Phone-only: the ids in the file are lower case, like the web's.
    @Test func workUIDsAreLowerCase() {
        #expect(build([], [Work()]).contains("UID:classping-task-44444444-4444-4444-8444-444444444444@classping"))
    }

    /// Inbox work (no class) gets no description line.
    @Test func workWithNoClassNameHasNoDescription() {
        let ics = buildCalendarFile([Klass](), [Work()], className: { _ in nil }, now: NOW)
        #expect(!ics.contains("DESCRIPTION:Chemistry"))
    }
}

@Suite struct CalendarTextTests {
    @Test func escapesTheCharactersRFC5545Reserves() {
        #expect(build([Klass(name: "Maths; Stats, Adv\\Core")]).contains("SUMMARY:Maths\\; Stats\\, Adv\\\\Core"))
    }

    @Test func newlinesInNotesBecomeALiteralBackslashN() {
        let ics = build([Klass(notes: "Bring:\nlab coat")])
        #expect(ics.contains("DESCRIPTION:Bring:\\nlab coat"))
        #expect(!ics.contains("DESCRIPTION:Bring:\r\nlab"))
        // Phone-only: Swift counts "\r\n" as one character, so it's handled on its own.
        #expect(escapeICS("a\r\nb\nc") == "a\\nb\\nc")
    }

    @Test func foldsLongLinesWithALeadingSpace() {
        let ics = build([Klass(name: String(repeating: "N", count: 200))])
        for line in lines(ics) {
            #expect(line.utf16.count <= 75)
        }
        #expect(ics.contains("\r\n N"))
    }

    @Test func aShortLineIsLeftAlone() {
        let line = String(repeating: "x", count: 74)
        #expect(foldICS(line) == line)
        #expect(foldICS(line + "y") == line + "\r\n y")
    }

    /// Phone-only: the web cuts at 74 UTF-16 units even inside an emoji (two
    /// units), which breaks it. The phone cuts one unit earlier instead.
    @Test func neverCutsAnEmojiInHalf() {
        let line = "SUMMARY:" + String(repeating: "A", count: 65) + "\u{1F600}" + String(repeating: "B", count: 20)
        let folded = foldICS(line)
        #expect(folded.replacingOccurrences(of: "\r\n ", with: "") == line)
        #expect(!folded.contains("\u{FFFD}"))
        #expect(lines(folded).allSatisfy { $0.utf16.count <= 75 })
    }

    /// Phone-only: the stamp is the `now` it's given, in UTC (the web uses its
    /// own clock), so a test can predict it.
    @Test func stampsTheFileInUTC() {
        let one = buildCalendarFile([Klass()], [Work](), className: { _ in nil },
                                    now: Date(timeIntervalSince1970: 86_400 + 3_661))
        #expect(one.contains("DTSTAMP:19700102T010101Z"))
    }

    @Test func theCardSaysWhatGoesIn() {
        #expect(calendarSummary(classes: 0, openTasks: 0) == "Add a class or assignment first.")
        #expect(calendarSummary(classes: 1, openTasks: 1)
                == "Exports 1 class and 1 open assignment. Re-add after you change your schedule.")
        #expect(calendarSummary(classes: 5, openTasks: 0)
                == "Exports 5 classes and 0 open assignments. Re-add after you change your schedule.")
    }
}

// MARK: - The whole file, against the web's own

private let C1 = uuid("11111111-1111-4111-8111-111111111111")
private let C2 = uuid("33333333-3333-4333-8333-333333333333")

private let fixtureClasses = [
    Klass(id: C1, name: "Chemistry", days: [0, 2], startMin: 600, endMin: 680, room: "Sci 204",
          additionalMeetings: [ClassMeeting(id: uuid("22222222-2222-4222-8222-222222222222"),
                                            days: [4], start: 840, end: 960, room: "Lab 2", label: "Lab")],
          alarm: true, remindBefore: 15, instructor: "Dr Vance", notes: "Bring:\nlab coat",
          extraReminders: [60, 15, 1440]),
    Klass(id: C2, name: "Maths; Stats, Adv\\Core and a much longer course title that needs folding",
          days: [3, 1], startMin: 540, endMin: 615, alarm: false, remindBefore: 10),
]

private let fixtureWork = [
    Work(id: uuid("44444444-4444-4444-8444-444444444444"), title: "Essay", courseID: C1,
         due: "2026-08-12", dueTime: "09:00", reminder: true),
    Work(id: uuid("55555555-5555-4555-8555-555555555555"), title: "Midterm 1", courseID: C2,
         kindName: "exam", due: "2026-10-14", dueTime: nil, reminder: true),
    Work(id: uuid("66666666-6666-4666-8666-666666666666"), title: "Done thing", courseID: C1,
         due: "2026-08-20", dueTime: nil, reminder: false, done: true),
    Work(id: uuid("77777777-7777-4777-8777-777777777777"), title: "Inbox thing",
         due: nil, dueTime: nil, reminder: true),
    Work(id: uuid("88888888-8888-4888-8888-888888888888"), title: "Quiz, ch. 3",
         kindName: "quiz", due: "2026-09-01", dueTime: "13:15", reminder: false),
]

private func fixtureFile(term: TermWindow?) -> [String] {
    let names = [C1: fixtureClasses[0].name, C2: fixtureClasses[1].name]
    let ics = buildCalendarFile(fixtureClasses, fixtureWork, className: { $0.flatMap { names[$0] } },
                                now: NOW, term: term)
    let unstamped = ics.replacingOccurrences(of: #"DTSTAMP:\d{8}T\d{6}Z"#, with: "DTSTAMP:X",
                                             options: .regularExpression)
    // Drop the empty piece after the final CR LF.
    return Array(lines(unstamped).dropLast())
}

@Suite struct CalendarWholeFileTests {
    @Test func matchesTheWebWithATerm() {
        #expect(fixtureFile(term: TermWindow(start: "2026-09-07", end: "2026-12-15")) == webWithTerm)
    }

    @Test func matchesTheWebWithNoTerm() {
        #expect(fixtureFile(term: nil) == webWithoutTerm)
    }
}

/// web: buildCalendarFile(fixture, NOW, { start: "2026-09-07", end: "2026-12-15" })
private let webWithTerm = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//ClassPing//Timetable//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "X-WR-CALNAME:ClassPing",
    "BEGIN:VEVENT",
    "UID:classping-class-11111111-1111-4111-8111-111111111111@classping",
    "DTSTAMP:X",
    "DTSTART:20260907T100000",
    "DTEND:20260907T112000",
    "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261215T235900",
    "SUMMARY:Chemistry",
    "LOCATION:Sci 204",
    "DESCRIPTION:With Dr Vance\\nBring:\\nlab coat",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT1440M",
    "DESCRIPTION:Chemistry starts in 1 day",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT60M",
    "DESCRIPTION:Chemistry starts in 1 hour",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT15M",
    "DESCRIPTION:Chemistry starts in 15 minutes",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-class-11111111-1111-4111-8111-111111111111:22222222-2222-422",
    " 2-8222-222222222222@classping",
    "DTSTAMP:X",
    "DTSTART:20260911T140000",
    "DTEND:20260911T160000",
    "RRULE:FREQ=WEEKLY;BYDAY=FR;UNTIL=20261215T235900",
    "SUMMARY:Chemistry",
    "LOCATION:Lab 2",
    "DESCRIPTION:With Dr Vance\\nBring:\\nlab coat",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT1440M",
    "DESCRIPTION:Chemistry starts in 1 day",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT60M",
    "DESCRIPTION:Chemistry starts in 1 hour",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT15M",
    "DESCRIPTION:Chemistry starts in 15 minutes",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-class-33333333-3333-4333-8333-333333333333@classping",
    "DTSTAMP:X",
    "DTSTART:20260908T090000",
    "DTEND:20260908T101500",
    "RRULE:FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20261215T235900",
    "SUMMARY:Maths\\; Stats\\, Adv\\\\Core and a much longer course title that need",
    " s folding",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-task-44444444-4444-4444-8444-444444444444@classping",
    "DTSTAMP:X",
    "DTSTART:20260812T090000",
    "DTEND:20260812T093000",
    "SUMMARY:Essay due",
    "DESCRIPTION:Chemistry",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT24H",
    "DESCRIPTION:Essay is due in 24 hours",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-task-55555555-5555-4555-8555-555555555555@classping",
    "DTSTAMP:X",
    "DTSTART:20261014T235900",
    "DTEND:20261015T012900",
    "SUMMARY:📝 Midterm 1",
    "DESCRIPTION:Maths\\; Stats\\, Adv\\\\Core and a much longer course title that ",
    " needs folding",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-P7D",
    "DESCRIPTION:Midterm 1 is in a week",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT24H",
    "DESCRIPTION:Midterm 1 is in 24 hours",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-task-88888888-8888-4888-8888-888888888888@classping",
    "DTSTAMP:X",
    "DTSTART:20260901T131500",
    "DTEND:20260901T134500",
    "SUMMARY:Quiz\\, ch. 3 due",
    "END:VEVENT",
    "END:VCALENDAR",
]

/// web: buildCalendarFile(fixture, NOW), no term
private let webWithoutTerm = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//ClassPing//Timetable//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "X-WR-CALNAME:ClassPing",
    "BEGIN:VEVENT",
    "UID:classping-class-11111111-1111-4111-8111-111111111111@classping",
    "DTSTAMP:X",
    "DTSTART:20260810T100000",
    "DTEND:20260810T112000",
    "RRULE:FREQ=WEEKLY;BYDAY=MO,WE",
    "SUMMARY:Chemistry",
    "LOCATION:Sci 204",
    "DESCRIPTION:With Dr Vance\\nBring:\\nlab coat",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT1440M",
    "DESCRIPTION:Chemistry starts in 1 day",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT60M",
    "DESCRIPTION:Chemistry starts in 1 hour",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT15M",
    "DESCRIPTION:Chemistry starts in 15 minutes",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-class-11111111-1111-4111-8111-111111111111:22222222-2222-422",
    " 2-8222-222222222222@classping",
    "DTSTAMP:X",
    "DTSTART:20260814T140000",
    "DTEND:20260814T160000",
    "RRULE:FREQ=WEEKLY;BYDAY=FR",
    "SUMMARY:Chemistry",
    "LOCATION:Lab 2",
    "DESCRIPTION:With Dr Vance\\nBring:\\nlab coat",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT1440M",
    "DESCRIPTION:Chemistry starts in 1 day",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT60M",
    "DESCRIPTION:Chemistry starts in 1 hour",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT15M",
    "DESCRIPTION:Chemistry starts in 15 minutes",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-class-33333333-3333-4333-8333-333333333333@classping",
    "DTSTAMP:X",
    "DTSTART:20260811T090000",
    "DTEND:20260811T101500",
    "RRULE:FREQ=WEEKLY;BYDAY=TU,TH",
    "SUMMARY:Maths\\; Stats\\, Adv\\\\Core and a much longer course title that need",
    " s folding",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-task-44444444-4444-4444-8444-444444444444@classping",
    "DTSTAMP:X",
    "DTSTART:20260812T090000",
    "DTEND:20260812T093000",
    "SUMMARY:Essay due",
    "DESCRIPTION:Chemistry",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT24H",
    "DESCRIPTION:Essay is due in 24 hours",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-task-55555555-5555-4555-8555-555555555555@classping",
    "DTSTAMP:X",
    "DTSTART:20261014T235900",
    "DTEND:20261015T012900",
    "SUMMARY:📝 Midterm 1",
    "DESCRIPTION:Maths\\; Stats\\, Adv\\\\Core and a much longer course title that ",
    " needs folding",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-P7D",
    "DESCRIPTION:Midterm 1 is in a week",
    "END:VALARM",
    "BEGIN:VALARM",
    "ACTION:DISPLAY",
    "TRIGGER:-PT24H",
    "DESCRIPTION:Midterm 1 is in 24 hours",
    "END:VALARM",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "UID:classping-task-88888888-8888-4888-8888-888888888888@classping",
    "DTSTAMP:X",
    "DTSTART:20260901T131500",
    "DTEND:20260901T134500",
    "SUMMARY:Quiz\\, ch. 3 due",
    "END:VEVENT",
    "END:VCALENDAR",
]

// ICSImportTests.swift: reading a calendar file (lib/ics-import.ts). The
// first suites are the web's own ics-import.test.ts, case for case (its
// planImport cases stay on the web, D-80; the dueAt check becomes the same
// check through deadlineInstant). The last suite's "web:" lines were printed
// by the web's parseIcs in node 24 with TZ=America/New_York.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// Mon 10 Aug 2026, 8:00 AM local, the web test's NOW.
private let NOW = at(2026, 8, 10, 8, 0)

/// Event bodies wrapped in a minimal calendar, lines joined with "\r\n".
private func cal(_ events: String...) -> String {
    (["BEGIN:VCALENDAR", "VERSION:2.0"] + events + ["END:VCALENDAR"]).joined(separator: "\r\n")
}

private func vevent(_ lines: String...) -> String {
    (["BEGIN:VEVENT"] + lines + ["END:VEVENT"]).joined(separator: "\r\n")
}

@Suite struct ICSImportClassTests {
    @Test func aWeeklyEventBecomesAClassOnItsDays() {
        let ics = cal(vevent("SUMMARY:Organic Chemistry", "DTSTART:20260810T100000",
                             "DTEND:20260810T112000", "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR",
                             "LOCATION:Science 204"))
        let result = parseICS(ics, now: NOW)
        #expect(result.tasks.isEmpty)
        #expect(result.classes.count == 1)
        let c = result.classes[0]
        #expect(c.name == "Organic Chemistry")
        #expect(c.days == [0, 2, 4])
        #expect(c.start == 600)
        #expect(c.end == 680)
        #expect(c.room == "Science 204")
        #expect(c.alarm)
    }

    @Test func noBydayMeansTheStartsWeekday() {
        // 2026-08-10 is a Monday.
        let ics = cal(vevent("SUMMARY:Lecture", "DTSTART:20260810T090000", "RRULE:FREQ=WEEKLY"))
        #expect(parseICS(ics, now: NOW).classes[0].days == [0])
    }

    @Test func anOrdinalLike2MOIsStillMonday() {
        let ics = cal(vevent("SUMMARY:Seminar", "DTSTART:20260810T090000",
                             "RRULE:FREQ=WEEKLY;BYDAY=2MO,3WE"))
        #expect(parseICS(ics, now: NOW).classes[0].days == [0, 2])
    }

    @Test func weekendOnlyClassesComeIn() {
        let ics = cal(vevent("SUMMARY:Sat Lab", "DTSTART:20260815T090000",
                             "RRULE:FREQ=WEEKLY;BYDAY=SA,SU"))
        let result = parseICS(ics, now: NOW)
        #expect(result.classes.count == 1)
        #expect(result.classes[0].days == [5, 6])
        #expect(result.skipped == 0)
    }

    @Test func anHourLongWhenThereIsNoEnd() {
        let ics = cal(vevent("SUMMARY:Studio", "DTSTART:20260810T140000", "RRULE:FREQ=WEEKLY"))
        let c = parseICS(ics, now: NOW).classes[0]
        #expect(c.start == 840)
        #expect(c.end == 900)
    }

    @Test func classesInARowGetDifferentColors() {
        let ics = cal(vevent("SUMMARY:A", "DTSTART:20260810T090000", "RRULE:FREQ=WEEKLY"),
                      vevent("SUMMARY:B", "DTSTART:20260811T090000", "RRULE:FREQ=WEEKLY"))
        let classes = parseICS(ics, now: NOW).classes
        #expect(classes[0].color != classes[1].color)
    }

    @Test func aTermFromTheFirstClassAndUntil() {
        let ics = cal(vevent("SUMMARY:Organic Chemistry", "DTSTART:20260831T100000",
                             "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261218T235959"),
                      vevent("SUMMARY:Final project", "DTSTART:20261212T235900"))
        #expect(parseICS(ics, now: NOW).term == TermDateSuggestion(start: "2026-08-31", end: "2026-12-18"))
    }

    @Test func noEndWhenTheFileNeverSays() {
        let ics = cal(vevent("SUMMARY:Open-ended seminar", "DTSTART:20260831T100000",
                             "RRULE:FREQ=WEEKLY;BYDAY=MO"))
        #expect(parseICS(ics, now: NOW).term == TermDateSuggestion(start: "2026-08-31", end: nil))
    }
}

@Suite struct ICSImportTaskTests {
    @Test func aOneOffEventIsDueAtItsStart() {
        let ics = cal(vevent("SUMMARY:Essay draft", "DTSTART:20260812T235900"))
        let tasks = parseICS(ics, now: NOW).tasks
        #expect(tasks.count == 1)
        #expect(tasks[0].title == "Essay draft")
        #expect(tasks[0].kind == "assignment")
        let instant = deadlineInstant(makeDeadline(tasks[0].due, tasks[0].dueTime))
        #expect(instant.map { $0 > NOW } == true)
        // A timed entry keeps its time.
        #expect(tasks[0].due == "2026-08-12")
        #expect(tasks[0].dueTime == "23:59")
    }

    @Test func examsAreKnownByTheirTitle() {
        for title in ["Midterm Exam", "Final", "Unit 3 Quiz", "Chem Test"] {
            let ics = cal(vevent("SUMMARY:\(title)", "DTSTART:20260901T090000"))
            #expect(parseICS(ics, now: NOW).tasks[0].kind == "exam", "\(title)")
        }
    }

    @Test func thePastIsLeftOut() {
        let result = parseICS(cal(vevent("SUMMARY:Old thing", "DTSTART:20260101T090000")), now: NOW)
        #expect(result.tasks.isEmpty)
        #expect(result.skipped == 1)
    }

    @Test func anAllDayEventIsATaskNotAClass() {
        let result = parseICS(cal(vevent("SUMMARY:Reading due", "DTSTART;VALUE=DATE:20260812")), now: NOW)
        #expect(result.classes.isEmpty)
        #expect(result.tasks.count == 1)
    }
}

@Suite struct ICSImportRobustnessTests {
    @Test func foldedLinesAreJoined() {
        let ics = cal(["BEGIN:VEVENT",
                       "SUMMARY:A very long class name that the feed has wrapped",
                       " across two physical lines",
                       "DTSTART:20260810T090000",
                       "RRULE:FREQ=WEEKLY",
                       "END:VEVENT"].joined(separator: "\r\n"))
        #expect(parseICS(ics, now: NOW).classes[0].name
                == "A very long class name that the feed has wrappedacross two physical lines")
    }

    @Test func escapesInTitlesAreUndone() {
        let ics = cal(vevent("SUMMARY:Maths\\, Stats\\; Adv", "DTSTART:20260901T090000"))
        #expect(parseICS(ics, now: NOW).tasks[0].title == "Maths, Stats; Adv")
    }

    @Test func aStartWithParametersIsRead() {
        let ics = cal(vevent("SUMMARY:Lecture", "DTSTART;TZID=America/New_York:20260810T090000",
                             "RRULE:FREQ=WEEKLY"))
        #expect(parseICS(ics, now: NOW).classes[0].start == 540)
    }

    @Test func noTitleOrNoStartIsSkipped() {
        let result = parseICS(cal(vevent("DTSTART:20260901T090000"), vevent("SUMMARY:No date")), now: NOW)
        #expect(result.classes.isEmpty)
        #expect(result.tasks.isEmpty)
        #expect(result.skipped == 2)
    }

    @Test func emptyOrNonCalendarTextIsHarmless() {
        #expect(parseICS("", now: NOW) == ImportResult())
        #expect(parseICS("garbage not ics", now: NOW).skipped == 0)
    }

    @Test func oneFileCanOnlyAddSoMuch() {
        let many = (0..<50).map { vevent("SUMMARY:Task \($0)", "DTSTART:20260901T090000") }
        let ics = (["BEGIN:VCALENDAR", "VERSION:2.0"] + many + ["END:VCALENDAR"]).joined(separator: "\r\n")
        let result = parseICS(ics, now: NOW, limit: 10)
        #expect(result.classes.count + result.tasks.count == 10)
    }
}

@Suite struct ICSImportIdentityTests {
    @Test func everyCandidateKeepsItsUID() {
        let ics = cal(vevent("UID:lecture-101@school.edu", "SUMMARY:Physics", "DTSTART:20260810T090000",
                             "DTEND:20260810T100000", "RRULE:FREQ=WEEKLY;BYDAY=MO"),
                      vevent("UID:assignment-7@school.edu", "SUMMARY:Problem set 7",
                             "DTSTART:20260901T235900"))
        let result = parseICS(ics, now: NOW)
        #expect(result.classes[0].sourceUID == "lecture-101@school.edu")
        #expect(result.tasks[0].sourceUID == "assignment-7@school.edu")
    }

    @Test func noUIDIsLeftEmptyNotInvented() {
        let ics = cal(vevent("SUMMARY:Physics", "DTSTART:20260810T090000", "RRULE:FREQ=WEEKLY;BYDAY=MO"))
        #expect(parseICS(ics, now: NOW).classes[0].sourceUID == nil)
    }

    @Test func aCancelledEventIsRecordedNotImported() {
        let ics = cal(vevent("UID:dropped@school.edu", "STATUS:CANCELLED", "SUMMARY:Seminar",
                             "DTSTART:20260901T090000"))
        let result = parseICS(ics, now: NOW)
        #expect(result.tasks.isEmpty)
        #expect(result.classes.isEmpty)
        #expect(result.cancelled == ["dropped@school.edu"])
        #expect(result.skipped == 1)
    }

    @Test func aMovedOccurrenceIsNotAFakeAssignment() {
        let ics = cal(vevent("UID:lecture-101@school.edu", "SUMMARY:Physics", "DTSTART:20260810T090000",
                             "DTEND:20260810T100000", "RRULE:FREQ=WEEKLY;BYDAY=MO"),
                      vevent("UID:lecture-101@school.edu", "RECURRENCE-ID:20260817T090000",
                             "SUMMARY:Physics", "DTSTART:20260817T110000", "DTEND:20260817T120000"))
        let result = parseICS(ics, now: NOW)
        #expect(result.classes.count == 1)
        #expect(result.tasks.isEmpty)
        #expect(result.skipped == 1)
    }

    @Test func eachCancelledUIDOnce() {
        let ics = cal(vevent("UID:x@s.edu", "STATUS:CANCELLED", "SUMMARY:A", "DTSTART:20260901T090000"),
                      vevent("UID:x@s.edu", "STATUS:CANCELLED", "SUMMARY:A", "DTSTART:20260908T090000"))
        #expect(parseICS(ics, now: NOW).cancelled == ["x@s.edu"])
    }
}

/// Beyond the web's tests: the same answers as the web's own code.
@Suite struct ICSImportParityTests {
    @Test func examWordsFollowTheWebsWordRule() {
        // web: assignment, exam, exam, assignment, exam, assignment, assignment, exam
        let titles = ["Final_exam", "Examé", "éExam", "Quiz2", "Exam-1", "Testing", "finals", "Pop QUIZ"]
        let kinds = titles.map { title in
            parseICS(cal(vevent("SUMMARY:\(title)", "DTSTART:20260901T090000")), now: NOW).tasks[0].kind
        }
        #expect(kinds == ["assignment", "exam", "exam", "assignment", "exam", "assignment", "assignment", "exam"])
    }

    @Test func aFileWithPlainLineBreaksAndOddCorners() {
        // "\n" line ends, a tab fold, \N, an alarm inside the event, an empty
        // BYDAY entry, a rule in lower case, an all-day end on a class, a Z
        // time 23 hours back (kept) and one two days back (skipped).
        let lf = ["BEGIN:VCALENDAR",
                  "BEGIN:VEVENT", "UID:chem@u.edu", "SUMMARY:Organic\\NChem\\, Lab",
                  "DTSTART;TZID=America/New_York:20260901T140000", "DTEND;VALUE=DATE:20260901",
                  "rrule:freq=weekly;byday=tu,,TH;until=20261211", "LOCATION:  Hall\\; 2  ",
                  "BEGIN:VALARM", "TRIGGER:-PT15M", "SUMMARY:Alarm text", "END:VALARM", "END:VEVENT",
                  "BEGIN:VEVENT", "SUMMARY:Yesterday's quiz", "DTSTART:20260809T090000Z", "END:VEVENT",
                  "BEGIN:VEVENT", "SUMMARY:Two days ago", "DTSTART:20260808T070000", "END:VEVENT",
                  "BEGIN:VEVENT", "SUMMARY:Final project", "\tpart two",
                  "DTSTART;VALUE=DATE:20261215", "DTEND;VALUE=DATE:20261216", "END:VEVENT",
                  "END:VCALENDAR"].joined(separator: "\n")
        let result = parseICS(lf, now: NOW)
        // web: one class, "Organic\nChem, Lab", Organ, indigo, Tue/Thu,
        // 840-900, room "Hall; 2", uid chem@u.edu
        #expect(result.classes == [ImportedClass(name: "Organic\nChem, Lab", short: "Organ", color: "indigo",
                                                 days: [1, 3], start: 840, end: 900, room: "Hall; 2",
                                                 sourceUID: "chem@u.edu")])
        // web: the quiz on 2026-08-09 09:00 (exam), "Final projectpart two"
        // all-day on 2026-12-15 (exam); one skipped; term 09-01 to 12-16
        #expect(result.tasks == [
            ImportedTask(title: "Yesterday's quiz", due: "2026-08-09", dueTime: "09:00", kind: "exam"),
            ImportedTask(title: "Final projectpart two", due: "2026-12-15", dueTime: nil, kind: "exam"),
        ])
        #expect(result.skipped == 1)
        #expect(result.cancelled.isEmpty)
        #expect(result.term == TermDateSuggestion(start: "2026-09-01", end: "2026-12-16"))
    }

    @Test func aDateThatRollsOverRollsLikeTheWebs() {
        // web: 2026-13-40 at 09:00 is due 2027-02-09 09:00
        let tasks = parseICS(cal(vevent("SUMMARY:Rollover", "DTSTART:20261340T090000")), now: NOW).tasks
        #expect(tasks == [ImportedTask(title: "Rollover", due: "2027-02-09", dueTime: "09:00", kind: "assignment")])
    }

    @Test func otherScriptsDigitsAreNotADate() {
        // The web's \d is 0-9 only; so is this.
        let ics = cal(vevent("SUMMARY:Arabic digits", "DTSTART:٢٠٢٦٠٩٠١T090000"))
        #expect(parseICS(ics, now: NOW).skipped == 1)
    }

    @Test func shortNamesCutLikeTheWeb() {
        #expect(importShortName("  Organic   Chemistry") == "Organ")
        #expect(importShortName("📚Biology") == "📚Bio")    // the emoji is two of the five
        #expect(importShortName("   ") == "Class")
    }
}

// PasteScheduleTests.swift: pasting a timetable (lib/paste-schedule.ts). The
// first suite is the web's own paste-schedule.test.ts, case for case; the
// rest were printed by the web's readPastedSchedule, parsePasteRow, slotKey,
// existingSlotKeys and buildPastedClasses, and PasteSchedule.tsx's preview,
// in node 24 (docs/ios/.scratch/p13b/paste.ts and review.ts).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// A stand-in class for `existingSlotKeys`: Schedulable's fields and a name.
private struct Listed: Schedulable {
    var id = UUID()
    var name: String
    var days: [Int]
    var startMin: Int
    var endMin: Int
    var room: String? = nil
    var additionalMeetings: [ClassMeeting] = []
}

/// The rows a paste reads into, or a failed test when it can't be read.
private func rows(_ text: String) -> [PasteRow] {
    guard case .success(let read) = readPastedSchedule(text) else {
        Issue.record("couldn't read: \(text.prefix(60))")
        return []
    }
    return read
}

/// The words a paste, a row or a build fails with, or nil when it works.
private func message<T>(_ result: Result<T, PasteProblem>) -> String? {
    if case .failure(let p) = result { return p.message }
    return nil
}

/// The class a row makes, or nil.
private func value(_ row: PasteRow) -> ImportedClass? {
    if case .success(let c) = parsePasteRow(row) { return c }
    return nil
}

/// Ids handed out in order, m1, m2, ... as fixed UUIDs, like the web
/// script's `() => "m" + (++n)`.
private func counter() -> () -> UUID {
    var n = 0
    return {
        n += 1
        return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }
}

private func id(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

/// The classes a build makes, or a failed test.
private func built(_ rows: [PasteRow], group: Bool) -> [ImportedClass] {
    switch buildPastedClasses(rows, group: group, newID: counter()) {
    case .success(let classes): return classes
    case .failure(let p):
        Issue.record("build failed: \(p.message)")
        return []
    }
}

/// A row with a working course, day and times, changed by `edit`.
private func row(_ edit: (inout PasteRow) -> Void = { _ in }) -> PasteRow {
    var r = PasteRow(name: "Bio", days: "Mon", start: "9", end: "10")
    edit(&r)
    return r
}

/// A class as the web's parsePasteRow makes it: indigo, 15 minutes, alarm on.
private func pasted(_ name: String, _ short: String, _ days: [Int], _ start: Int, _ end: Int,
                    room: String? = nil, instructor: String? = nil, credits: Double? = nil,
                    extra: [ClassMeeting] = []) -> ImportedClass {
    ImportedClass(name: name, short: short, color: "indigo", days: days, start: start, end: end,
                  room: room, instructor: instructor, credits: credits, additionalMeetings: extra)
}

@Suite struct PasteScheduleTests {
    @Test func readsPortalTSVAliasesWeekendDaysAndAMPM() {
        let read = rows("Course title\tMeeting days\tStart time\tEnd time\tLocation\nBiology\tSat/Sun\t2 PM\t3:30 PM\tLab 3")
        let c = read.first.flatMap(value)
        #expect(c?.name == "Biology")
        #expect(c?.days == [5, 6])
        #expect(c?.start == 840)
        #expect(c?.end == 930)
        #expect(c?.room == "Lab 3")
    }

    @Test func supportsQuotedCommasNewlinesAndHeaderlessTables() {
        let c = rows("\"Art, studio\",MWF,09:00,10:00,\"Building A, 2\"").first.flatMap(value)
        #expect(c?.name == "Art, studio")
        #expect(c?.days == [0, 2, 4])
        #expect(c?.room == "Building A, 2")
        #expect(rows("Course,Days,Start,End,Room\nBiology,Mon,9,10,\"A\nB\"").first?.room == "A\nB")
    }

    @Test func keepsInvalidRowsEditableAndRefusesToImportThem() {
        var read = rows("Biology\tMon/maybe\t9\t8")
        #expect(read.count == 1)
        #expect(read[0].problem != nil)
        #expect(message(buildPastedClasses(read, group: true, newID: { id(1) })) != nil)
        read[0].selected = false
        #expect(built(read, group: true) == [])
    }

    @Test func groupsLecturesAndLabsWithoutDuplicateSubjectsOrSlots() {
        let read = rows("Biology\tMon\t9\t10\tHall\nBiology\tThu\t14\t16\tLab\nBiology\tThu\t14\t16\tLab")
        let lab = id(99)
        guard case .success(let result) = buildPastedClasses(read, group: true, newID: { lab }) else {
            Issue.record("build failed")
            return
        }
        #expect(result.count == 1)
        #expect(result.first?.additionalMeetings == [ClassMeeting(id: lab, days: [3], start: 840, end: 960, room: "Lab")])
        #expect(built(read, group: false).count == 2)
    }

    @Test func doesNotSilentlyDiscardConflictingSubjectInformation() {
        let read = rows("Bio\tMon\t9\t10\tA\tTeacher A\t3\nBio\tThu\t14\t16\tB\tTeacher B\t4")
        let words = message(buildPastedClasses(read, group: true)) ?? ""
        #expect(words.contains("different teachers or credits"))
    }

    @Test func rejectsUnsupportedHeadersAndOversizedInputInsteadOfTruncatingIt() {
        #expect(message(readPastedSchedule("Course\tTime\nBio\t9-10"))?.contains("Include Course") == true)
        #expect(message(readPastedSchedule(String(repeating: "x", count: 100_001)))?.contains("100,000") == true)
        let many = Array(repeating: "Bio\tMon\t9\t10", count: 201).joined(separator: "\n")
        #expect(message(readPastedSchedule(many))?.contains("200") == true)
    }
}

@Suite struct PasteScheduleParityTests {
    @Test func headingsTakeTheFirstColumnThatMatches() {
        // web: room "A", from the first Room heading (a CSV takes the last)
        #expect(rows("Course,Room,Days,Start,End,Location,Room\nBio,A,MWF,9,10,L,B")
                == [PasteRow(name: "Bio", days: "MWF", start: "9", end: "10", room: "A")])
    }

    @Test func aByteOrderMarkAndWindowsLineEnds() {
        // web: one row, Bio Mon 9 10
        #expect(rows("\u{FEFF}Course\tDays\tStart\tEnd\r\nBio\tMon\t9\t10\r\n")
                == [PasteRow(name: "Bio", days: "Mon", start: "9", end: "10")])
    }

    @Test func nothingToReadAndAnOpenQuote() {
        #expect(message(readPastedSchedule("Course,Days,Start,End")) == "The table has headers but no classes.")
        #expect(message(readPastedSchedule("   \n\t \n")) == "Paste a timetable first.")
        #expect(message(readPastedSchedule("")) == "Paste a timetable first.")
        #expect(message(readPastedSchedule("Bio,\"Mon,9,10"))
                == "The table has an unfinished quoted cell. Close its quotation mark and try again.")
        #expect(message(readPastedSchedule("Course,Days,Start\nBio,Mon,9"))
                == "Include Course, Days, Start and End columns. You can copy the example below.")
    }

    @Test func withoutACourseHeadingTheFirstRowIsAClass() {
        // web: "Subject" isn't a course heading, so the first row is data
        #expect(rows("Subject,Days,Start,End\nBio,Mon,9,10") == [
            PasteRow(name: "Subject", days: "Days", start: "Start", end: "End"),
            PasteRow(name: "Bio", days: "Mon", start: "9", end: "10"),
        ])
        #expect(rows("Bio,MWF,9,10") == [PasteRow(name: "Bio", days: "MWF", start: "9", end: "10")])
    }

    @Test func otherHeadingNames() {
        // web: Title/Meeting Days/Class Start/Class End/Professor/Units, and
        // "_", "-" and doubled spaces in headings
        #expect(rows("Title,Meeting Days,Class Start,Class End,Professor,Units\nArt,TR,1 PM,2:15 PM,Dr. Lee,3")
                == [PasteRow(name: "Art", days: "TR", start: "1 PM", end: "2:15 PM", instructor: "Dr. Lee", credits: "3")])
        #expect(rows("Course_Title\tMEETING-DAYS\tStart  Time\tEnd Time\nBio\tMon\t9\t10")
                == [PasteRow(name: "Bio", days: "Mon", start: "9", end: "10")])
    }

    @Test func missingCellsExtraColumnsAndBlankLines() {
        // web: a short row leaves Days empty; a tab anywhere splits on tabs
        // only; an eighth column is ignored, cells are trimmed, blank lines go
        #expect(rows("Course,Start,End,Days\nBio,9,10") == [PasteRow(name: "Bio", start: "9", end: "10")])
        #expect(rows("a,b\tc\nd,e\tf") == [PasteRow(name: "a,b", days: "c"), PasteRow(name: "d,e", days: "f")])
        #expect(rows("  Bio , Mon , 9 , 10 , Hall 1 , Dr. X , 4  ,extra\n\n\nChem,Tue,9,10") == [
            PasteRow(name: "Bio", days: "Mon", start: "9", end: "10", room: "Hall 1", instructor: "Dr. X", credits: "4"),
            PasteRow(name: "Chem", days: "Tue", start: "9", end: "10"),
        ])
    }

    @Test func limitsCountAsTheWebCounts() {
        // web: 100,000 x's read; 50,000 emoji (100,000 units) read; 50,001
        // emoji refused; 50,001 é (one unit each) read; 200 rows read, with
        // or without headings; 201 refused either way
        #expect(rows(String(repeating: "x", count: 100_000)).count == 1)
        #expect(rows(String(repeating: "😀", count: 50_000)).count == 1)
        #expect(message(readPastedSchedule(String(repeating: "😀", count: 50_001))) == "Paste up to 100,000 characters at a time.")
        #expect(rows(String(repeating: "é", count: 50_001)).first?.name.count == 50_001)
        let line = "Bio\tMon\t9\t10"
        #expect(rows(Array(repeating: line, count: 200).joined(separator: "\n")).count == 200)
        #expect(rows("Course,Days,Start,End\n" + Array(repeating: "Bio,Mon,9,10", count: 200).joined(separator: "\n")).count == 200)
        #expect(message(readPastedSchedule("Course,Days,Start,End\n" + Array(repeating: "Bio,Mon,9,10", count: 201).joined(separator: "\n")))
                == "Paste up to 200 meetings at a time.")
    }

    @Test func eachCheckInTheWebsOrder() {
        let name = "Enter a course name (up to 200 characters)."
        let days = "Use days such as Mon/Wed, Tue/Thu, Sat or Sun. Expand ambiguous day abbreviations."
        let times = "Enter valid start/end times, with the end after the start (e.g. 9:00 AM, 10:00 AM)."
        let text = "Room and teacher must each be 200 characters or fewer."
        #expect(row { $0.name = "  " }.problem == name)
        #expect(row { $0.name = String(repeating: "x", count: 201) }.problem == name)
        #expect(row { $0.name = String(repeating: "x", count: 200) }.problem == nil)
        #expect(row { $0.name = String(repeating: "😀", count: 101) }.problem == name)   // 202 units
        #expect(row { $0.days = "" }.problem == days)
        #expect(row { $0.days = "Mon/maybe" }.problem == days)
        #expect(row { $0.end = "9" }.problem == times)
        #expect(row { $0.start = "25:00" }.problem == times)
        #expect(row { $0.room = String(repeating: "r", count: 201) }.problem == text)
        #expect(row { $0.instructor = String(repeating: "t", count: 201) }.problem == text)
        // web: MWF, Sat is Mon/Wed/Fri/Sat; T.Th is Tue/Thu
        #expect(value(row { $0.days = "MWF, Sat" })?.days == [0, 2, 4, 5])
        #expect(value(row { $0.days = "T.Th" })?.days == [1, 3])
    }

    @Test func credits() {
        // web: 3, 3.5, 4, refused x4, 10, 0.5, 5, refused, 2, refused
        let inputs = ["3", "3.5", " 4 ", "0", "-1", "abc", " ", "1e1", ".5", "5.", "Infinity", "+2", "3 credits"]
        let web: [Double?] = [3, 3.5, 4, nil, nil, nil, nil, 10, 0.5, 5, nil, 2, nil]
        #expect(inputs.map { c in value(row { $0.credits = c })?.credits } == web)
        #expect(inputs.map { c in row { $0.credits = c }.problem != nil }
                == web.map { $0 == nil })
        #expect(row { $0.credits = "0" }.problem == "Credits must be greater than zero, or empty.")
        #expect(value(row())?.credits == nil)
    }

    @Test func aWholeRow() {
        // web: trimmed name and room, a blank teacher left out, short "Organ",
        // indigo, 15 minutes, alarm on
        let c = value(PasteRow(name: "  Organic Chemistry  ", days: "tue & thu", start: "1:30 pm", end: "14:45",
                               room: "  Lab 3 ", instructor: " ", credits: "4"))
        #expect(c == pasted("Organic Chemistry", "Organ", [1, 3], 810, 885, room: "Lab 3", credits: 4))
        #expect(c?.remindBefore == 15 && c?.alarm == true)
        #expect(value(row { $0.instructor = "Dr. Awuor" }) == pasted("Bio", "Bio", [0], 540, 600, instructor: "Dr. Awuor"))
        // web: Organ, Art, Calcu, BIOL-
        let names = ["Organic Chemistry", "  Art  History ", "Calculus\tIII", "BIOL-1010 Lab"]
        #expect(names.map { n in value(row { $0.name = n })?.short } == ["Organ", "Art", "Calcu", "BIOL-"])
    }

    @Test func slotKeys() {
        // web: name and room trimmed and in any case, days in any order, a
        // missing room the same as an empty one; another room is another slot
        #expect(SlotKey(name: " Bio ", days: [2, 0], start: 540, end: 600, room: " Hall A ")
                == SlotKey(name: "bio", days: [0, 2], start: 540, end: 600, room: "hall a"))
        #expect(SlotKey(name: "Bio", days: [0], start: 540, end: 600, room: nil)
                == SlotKey(name: "Bio", days: [0], start: 540, end: 600, room: ""))
        #expect(SlotKey(name: "Bio", days: [0], start: 540, end: 600, room: "A")
                != SlotKey(name: "Bio", days: [0], start: 540, end: 600, room: "B"))
    }

    @Test func groupingJoinsByNameInAnyCase() {
        // web: one Bio, its Wed and Fri as extras m1 and m2
        #expect(built(rows("Bio\tMon\t9\t10\tHall\nbio \tWed\t9\t10\tHall\nBIO\tFri\t14\t16\tLab"), group: true) == [
            pasted("Bio", "Bio", [0], 540, 600, room: "Hall", extra: [
                ClassMeeting(id: id(1), days: [2], start: 540, end: 600, room: "Hall"),
                ClassMeeting(id: id(2), days: [4], start: 840, end: 960, room: "Lab"),
            ]),
        ])
        // web: grouping off keeps each row's own name
        #expect(built(rows("Bio\tMon\t9\t10\tHall\nbio \tWed\t9\t10\tHall"), group: false) == [
            pasted("Bio", "Bio", [0], 540, 600, room: "Hall"),
            pasted("bio", "bio", [2], 540, 600, room: "Hall"),
        ])
        // web: another course at the same time is its own class
        #expect(built(rows("Bio\tMon\t9\t10\nChem\tMon\t9\t10\nBio\tTue\t9\t10"), group: true) == [
            pasted("Bio", "Bio", [0], 540, 600, extra: [ClassMeeting(id: id(1), days: [1], start: 540, end: 600)]),
            pasted("Chem", "Chem", [0], 540, 600),
        ])
    }

    @Test func repeatsAndDisagreements() {
        let repeats = "“Bio” repeats a meeting with different teachers or credits. Correct or uncheck the conflicting row."
        // web: an exact repeat is added once
        #expect(built(rows("Bio\tMon\t9\t10\nBio\tMon\t9\t10"), group: true) == [pasted("Bio", "Bio", [0], 540, 600)])
        // web (whose quote marks are lost as "?", web fixes 9): a repeat with other credits,
        // or a teacher on one and not the other (the room matches in any case)
        #expect(message(buildPastedClasses(rows("Bio\tMon\t9\t10\tHall\tA\t3\nBio\tMon\t9\t10\tHall\tA\t4"), group: false)) == repeats)
        #expect(message(buildPastedClasses(rows("Bio\tMon\t9\t10\tHall\tA\nBio\tMon\t9\t10\thall\t\nBio\tTue\t9\t10"), group: true)) == repeats)
        // web: grouped rows with different teachers; ungrouped they're two classes
        let teachers = rows("Bio\tMon\t9\t10\tHall\tA\t3\nBio\tWed\t9\t10\tHall\tB\t3")
        #expect(message(buildPastedClasses(teachers, group: true))
                == "“Bio” has different teachers or credits. Correct the rows or turn off grouping.")
        #expect(built(teachers, group: false) == [
            pasted("Bio", "Bio", [0], 540, 600, room: "Hall", instructor: "A", credits: 3),
            pasted("Bio", "Bio", [2], 540, 600, room: "Hall", instructor: "B", credits: 3),
        ])
    }

    @Test func twentyMeetingsAtMost() {
        let lines = (0..<21).map { "Bio\tMon\t\($0):00\t\($0):30" }
        // web: 20 rows make one class with 19 extras, the last m19 at 19:00
        let twenty = built(rows(lines.prefix(20).joined(separator: "\n")), group: true)
        #expect(twenty.count == 1)
        #expect(twenty.first?.additionalMeetings.count == 19)
        #expect(twenty.first?.additionalMeetings.last == ClassMeeting(id: id(19), days: [0], start: 1140, end: 1170))
        // web: the 21st is refused
        #expect(message(buildPastedClasses(rows(lines.joined(separator: "\n")), group: true))
                == "A subject can have at most 20 meeting times.")
    }

    @Test func onlyTickedRowsCount() {
        // web: a ticked row that can't be read stops the build; unticked, it's passed over
        var mixed = rows("Bio\tMon\t9\t10\nBad\tsomeday\t9\t10\nChem\tTue\t9\t10")
        #expect(message(buildPastedClasses(mixed, group: true))
                == "Use days such as Mon/Wed, Tue/Thu, Sat or Sun. Expand ambiguous day abbreviations.")
        mixed[1].selected = false
        #expect(built(mixed, group: true) == [pasted("Bio", "Bio", [0], 540, 600), pasted("Chem", "Chem", [1], 540, 600)])
    }

    @Test func meetingsAlreadyOnThePlanner() {
        // web: the main and extra meetings, names and rooms in lower case;
        // the web also drops archived and deleted classes, which the store
        // leaves out before calling (activeCourses)
        let biology = Listed(name: "Biology", days: [0, 2], startMin: 540, endMin: 590, room: "Hall",
                             additionalMeetings: [ClassMeeting(days: [4], start: 840, end: 960, room: "Lab")])
        let chem = Listed(name: "Chem", days: [3], startMin: 600, endMin: 660)
        #expect(existingSlotKeys([biology, chem]) { $0.name } == [
            SlotKey(name: "biology", days: [0, 2], start: 540, end: 590, room: "hall"),
            SlotKey(name: "biology", days: [4], start: 840, end: 960, room: "lab"),
            SlotKey(name: "chem", days: [3], start: 600, end: 660, room: ""),
        ])
    }

    @Test func theReviewStartsWithRepeatsUnticked() {
        // web (preview): a repeat of the planner's main meeting and of its lab
        // unticked; Chem ticked and its repeat not; both unreadable rows stay
        // ticked; Old ticked, since an archived class doesn't count
        let biology = Listed(name: "Biology", days: [0, 2], startMin: 540, endMin: 600, room: "Science 204",
                             additionalMeetings: [ClassMeeting(days: [3], start: 840, end: 960, room: "Lab 3")])
        let text = "Course\tDays\tStart\tEnd\tRoom\nbiology \tWed/Mon\t9:00 AM\t10:00 AM\tscience 204\n"
            + "Biology\tThu\t2:00 PM\t4:00 PM\tLab 3\nChem\tTue\t9\t10\t\nchem\tTue\t9\t10\t\n"
            + "Bad\tsomeday\t9\t10\t\nBad\tsomeday\t9\t10\t\nOld\tTue\t10\t11\t"
        let reviewed = reviewRows(rows(text), existing: existingSlotKeys([biology]) { $0.name })
        #expect(reviewed.map(\.selected) == [false, false, true, false, true, true, true])
        // Only the ticks change; the text is as pasted.
        #expect(reviewed.map(\.name) == rows(text).map(\.name))
    }

    @Test func theSubscriptReadsAndWritesEachColumn() {
        var r = PasteRow()
        for (n, column) in PasteColumn.allCases.enumerated() { r[column] = "v\(n)" }
        #expect(r == PasteRow(name: "v0", days: "v1", start: "v2", end: "v3", room: "v4", instructor: "v5", credits: "v6"))
        #expect(PasteColumn.allCases.map { r[$0] } == ["v0", "v1", "v2", "v3", "v4", "v5", "v6"])
        #expect(PasteColumn.allCases.map(\.label) == ["Course", "Days", "Start", "End", "Room", "Teacher", "Credits"])
    }
}

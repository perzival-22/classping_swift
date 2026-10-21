// CSVImportTests.swift: reading a schedule CSV (lib/csv-import.ts). The
// first suite is the web's own csv-import.test.ts, case for case; the rest
// were printed by the web's parseCsvSchedule, parseRows, parseDays, parseTime
// and normalizedHeader in node 24.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@Suite struct CSVImportTests {
    @Test func commonColumnsAndAQuotedRoom() {
        let result = parseCSVSchedule("""
        Course,Days,Start,End,Room,Instructor,Credits,Semester Start,Semester End
        Organic Chemistry,"Mon, Wed, Fri",9:00 AM,10:15 AM,"Science, 204",Dr. Awuor,4,08/31/2026,12/18/2026
        """)
        #expect(result.classes.count == 1)
        let c = result.classes[0]
        #expect(c.name == "Organic Chemistry")
        #expect(c.days == [0, 2, 4])
        #expect(c.start == 540)
        #expect(c.end == 615)
        #expect(c.room == "Science, 204")
        #expect(c.instructor == "Dr. Awuor")
        #expect(c.credits == 4)
        #expect(result.term == TermDateSuggestion(start: "2026-08-31", end: "2026-12-18"))
    }

    @Test func compactDaysAndIncompleteRowsSkipped() {
        let result = parseCSVSchedule("""
        Class,Days,Start Time,End Time
        Programming Languages,TR,13:45,15:00
        Missing time,MWF,,11:00
        """)
        #expect(result.classes.count == 1)
        #expect(result.classes[0].days == [1, 3])
        #expect(result.skipped == 1)
    }

    @Test func meetingTimesAreNotSemesterDates() {
        let result = parseCSVSchedule("""
        Course,Days,Start,End
        Linear Algebra,MWF,09:00,10:15
        """)
        #expect(result.term == nil)
    }
}

@Suite struct CSVImportParityTests {
    @Test func aMessyRealFile() {
        // A byte-order mark, "_" and "-" in headings, Room twice (the last
        // wins), "\r\n" line ends, a quoted line break, an end before its
        // start, a blank line, zero and unreadable credits.
        let csv = "\u{FEFF}Course_Name,Meeting-Days,Start Time,End Time,Room,Room,Credits,Semester Start,Semester End\r\n"
            + "Biology,MWF,9:00 AM,9:50 AM,\"Hall A\r\nfloor 2\",B12,3.5,2026-8-31,12/18/2026\r\n"
            + "Calc,TR,13:00,12:00,R1,R2,4,,\r\n"
            + "\r\n"
            + "Art,\"Tue, Thu\",2 PM,3:15 PM,,Studio,0,,\r\n"
            + "History,Fri,10,11,,,abc,,\r\n"
        let result = parseCSVSchedule(csv)
        // web: Biology (Biolo, indigo, MWF 540-590, B12, 3.5), Art (coral, Tue/Thu
        // 840-915, Studio), History (Histo, teal, Fri 600-660); 1 skipped;
        // term 2026-08-31 to 2026-12-18
        #expect(result.classes == [
            ImportedClass(name: "Biology", short: "Biolo", color: "indigo", days: [0, 2, 4],
                          start: 540, end: 590, room: "B12", credits: 3.5),
            ImportedClass(name: "Art", short: "Art", color: "coral", days: [1, 3],
                          start: 840, end: 915, room: "Studio"),
            ImportedClass(name: "History", short: "Histo", color: "teal", days: [4],
                          start: 600, end: 660),
        ])
        #expect(result.skipped == 1)
        #expect(result.term == TermDateSuggestion(start: "2026-08-31", end: "2026-12-18"))
    }

    @Test func anImpossibleSemesterDateIsDropped() {
        // web: February 30 is no date, so no term at all
        let result = parseCSVSchedule("Course,Days,Start,End,Semester Start,Semester End\nX,M,9,10,02/30/2026,2026-12-01")
        #expect(result.classes.count == 1)
        #expect(result.term == nil)
    }

    @Test func theTableReader() {
        // web: [["a","b \"c\"","d"],["x\ny","z"],["q"]], and the text ends inside quotes
        let read = parseRows("a,\"b \"\"c\"\"\",  d  \n\n\"x\ny\",z\r\"q")
        #expect(read.rows == [["a", "b \"c\"", "d"], ["x\ny", "z"], ["q"]])
        #expect(read.unclosedQuote)
        #expect(!parseRows("a,b\nc,d").unclosedQuote)
        #expect(parseRows("a\tb, c\td", delimiter: "\t").rows == [["a", "b, c", "d"]])
    }

    @Test func headings() {
        // web: "course title", "start time", "meeting days"
        #expect(["\u{FEFF}  Course_Title ", "Start--Time", "MEETING   DAYS"].map(normalizedHeader)
                == ["course title", "start time", "meeting days"])
    }

    @Test func times() {
        // web: 540, 840, 0, 720, 30, 825, 540, nil, 0, nil, nil, nil, 1145, 540, nil, nil, 1439
        let inputs = ["9:00 AM", "2 PM", "12 a.m.", "12 PM", "12:30 am", "13:45", "9", "24:00", "0:00",
                      "13 PM", "9:60", "9 :30", " 7:05p.m. ", "9am", "09:5", "0 am", "11:59 P.M"]
        let web: [Int?] = [540, 840, 0, 720, 30, 825, 540, nil, 0, nil, nil, nil, 1145, 540, nil, nil, 1439]
        #expect(inputs.map(parseTime) == web)
    }

    @Test func days() {
        let inputs = ["MWF", "TR", "TTh", "Mon/Wed", "Tue & Thu", "M W F", "sat, sun", "Thurs.", "Mo,We",
                      "xyz", "MTWRF", "mwfx", "Su;Sa", "T.Th"]
        let web: [[Int]] = [[0, 2, 4], [1, 3], [1, 3], [0, 2], [1, 3], [0, 2, 4], [5, 6], [3], [0, 2],
                            [], [0, 1, 2, 3, 4], [], [5, 6], [1, 3]]
        #expect(inputs.map(parseDays) == web)
    }

    @Test func semesterDates() {
        #expect(parseScheduleDate("2026-8-31") == "2026-08-31")
        #expect(parseScheduleDate(" 12/18/2026 ") == "2026-12-18")
        #expect(parseScheduleDate("2024-02-29") == "2024-02-29")
        #expect(parseScheduleDate("2026-02-29") == nil)
        #expect(parseScheduleDate("31/12/2026") == nil)     // month first, so no month 31
        #expect(parseScheduleDate("0099-01-01") == nil)     // a year the web's check can't hold
        #expect(parseScheduleDate("") == nil)
    }
}

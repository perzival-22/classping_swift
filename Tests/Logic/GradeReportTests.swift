// GradeReportTests.swift: the Swift twin of the CSV half of lib/report.test.ts
// (csvField and buildGradeReport), plus the JavaScript number spellings the
// file depends on. Cases marked "web:" are lib/report.ts's own output (node 24,
// --experimental-transform-types, run from a scratch copy, 2026-10-20).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// A stand-in class: just what the report reads. The web's `klass()` helper.
private struct Klass: ReportCourse {
    var id = UUID()
    var name = "Chemistry"
    var credits: Double? = nil
}

/// A stand-in result. The web's `grade()` helper, with the same defaults.
private struct Graded: ReportGrade {
    var courseID: UUID? = nil
    var title = "Midterm"
    var score = 90.0
    var max = 100.0
    var weight = 100.0
    var date = "2026-08-01"
    var kindName: String? = nil
}

/// A local date and time, so the tests read the same in every time zone.
private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

/// The web's `AT` (2026-08-10, midday), read as a local day.
private let AT = at(2026, 8, 10)

private func build(_ courses: [Klass], _ grades: [Graded],
                   scale: [ScaleBand] = DEFAULT_SCALE, termName: String? = nil) -> String {
    buildGradeReport(courses, grades, scale: scale, termName: termName, generatedAt: AT)
}

@Suite struct GradeReportTests {

    // MARK: csvField

    @Test func leavesPlainValuesAlone() {
        #expect(csvField("Chemistry") == "Chemistry")
        #expect(csvField(jsNumber(42)) == "42")
    }

    @Test func quotesAndDoublesEmbeddedQuotes() {
        #expect(csvField("He said \"hi\"") == "\"He said \"\"hi\"\"\"")
    }

    @Test func quotesValuesContainingCommasOrNewlines() {
        #expect(csvField("Maths, Adv") == "\"Maths, Adv\"")
        #expect(csvField("a\nb") == "\"a\nb\"")
    }

    @Test func defusesSpreadsheetFormulaInjection() {
        #expect(csvField("=HYPERLINK(\"http://evil\",\"x\")")
                == "\"'=HYPERLINK(\"\"http://evil\"\",\"\"x\"\")\"")
        #expect(csvField("+1") == "'+1")
        #expect(csvField("-2") == "'-2")
        #expect(csvField("@cmd") == "'@cmd")
    }

    /// "\r\n" is one Swift Character but two code points to the web's regex.
    @Test func readsCodePointsNotCharacters() {
        // web: ["\"a\r\nb\"","'\tTab","\"'\rX\"","","\"x\"\"y\"","'-","\"Ünïcødé, ok\"","\"\n\""]
        #expect(csvField("a\r\nb") == "\"a\r\nb\"")
        #expect(csvField("\tTab") == "'\tTab")
        #expect(csvField("\rX") == "\"'\rX\"")
        #expect(csvField("") == "")
        #expect(csvField("x\"y") == "\"x\"\"y\"")
        #expect(csvField("-") == "'-")
        #expect(csvField("Ünïcødé, ok") == "\"Ünïcødé, ok\"")
        #expect(csvField("\n") == "\"\n\"")
    }

    // MARK: JavaScript numbers

    @Test func numbersAreWrittenAsJavaScriptWritesThem() {
        // web: String(8), String(8.5), String(105), String(0.1 + 0.2), String(-0), String(1.5), String(1e14), String(33.33)
        #expect(jsNumber(8) == "8")
        #expect(jsNumber(8.5) == "8.5")
        #expect(jsNumber(105) == "105")
        #expect(jsNumber(0.1 + 0.2) == "0.30000000000000004")
        #expect(jsNumber(-0.0) == "0")
        #expect(jsNumber(1.5) == "1.5")
        #expect(jsNumber(1e14) == "100000000000000")
        #expect(jsNumber(33.33) == "33.33")
    }

    @Test func fixedRoundsExactHalvesAwayFromZeroLikeJavaScript() {
        // web: 6.25.toFixed(1), 3.125.toFixed(2), 1.005.toFixed(2), 0.5.toFixed(0),
        // 1.5.toFixed(0), 2.5.toFixed(0), (-0.0001).toFixed(1), 95.0.toFixed(1),
        // 0.0.toFixed(2), (1/16*100).toFixed(1), (0.1+0.2).toFixed(1),
        // 62.25.toFixed(1), 0.35.toFixed(1), 1.45.toFixed(1)
        #expect(jsFixed(6.25, 1) == "6.3")       // printf alone says "6.2"
        #expect(jsFixed(3.125, 2) == "3.13")     // printf alone says "3.12"
        #expect(jsFixed(1.005, 2) == "1.00")     // not a tie in binary
        #expect(jsFixed(0.5, 0) == "1")
        #expect(jsFixed(1.5, 0) == "2")
        #expect(jsFixed(2.5, 0) == "3")
        #expect(jsFixed(-0.0001, 1) == "-0.0")
        #expect(jsFixed(95, 1) == "95.0")
        #expect(jsFixed(0, 2) == "0.00")
        #expect(jsFixed(1.0 / 16 * 100, 1) == "6.3")
        #expect(jsFixed(0.1 + 0.2, 1) == "0.3")
        #expect(jsFixed(62.25, 1) == "62.3")
        #expect(jsFixed(0.35, 1) == "0.3")
        #expect(jsFixed(1.45, 1) == "1.4")
    }

    // MARK: buildGradeReport

    @Test func includesAHeaderTheTermAndTheGenerationDate() {
        let c = Klass()
        let csv = build([c], [Graded(courseID: c.id)], termName: "Fall 2025")
        #expect(csv.contains("ClassPing grade report"))
        #expect(csv.contains("Fall 2025"))
        #expect(csv.contains("2026-08-10"))
    }

    @Test func writesOneRowPerGradedItem() {
        let c = Klass()
        let csv = build([c], [
            Graded(courseID: c.id, title: "Quiz 1", score: 8, max: 10, weight: 20),
            Graded(courseID: c.id, title: "Quiz 2", score: 9, max: 10, weight: 20),
        ])
        #expect(csv.contains("Chemistry,1,Quiz 1,,2026-08-01,8,10,80.0,20"))
        #expect(csv.contains("Chemistry,1,Quiz 2,,2026-08-01,9,10,90.0,20"))
    }

    @Test func carriesTheItemsTypeAndLeavesItBlankWhenUnset() {
        let c = Klass()
        let csv = build([c], [
            Graded(courseID: c.id, title: "Midterm", kindName: "exam"),
            Graded(courseID: c.id, title: "Homework", date: "2026-08-02"),
        ])
        #expect(csv.contains("Type"))
        #expect(csv.contains("Chemistry,1,Midterm,exam,2026-08-01"))
        #expect(csv.contains("Chemistry,1,Homework,,2026-08-02"))
    }

    /// `range(of:)` gives where a piece of text starts, to compare positions.
    private func position(_ text: String, in csv: String) -> String.Index? {
        csv.range(of: text)?.lowerBound
    }

    @Test func ordersItemsByDate() {
        let c = Klass()
        let csv = build([c], [
            Graded(courseID: c.id, title: "Later", date: "2026-09-01"),
            Graded(courseID: c.id, title: "Earlier", date: "2026-07-01"),
        ])
        let earlier = position("Earlier", in: csv), later = position("Later", in: csv)
        #expect(earlier != nil && later != nil)
        if let earlier, let later { #expect(earlier < later) }
    }

    @Test func keepsSameDayItemsInTheOrderTheyWereAdded() {
        let c = Klass()
        let titles = ["First", "Second", "Third", "Fourth"]
        let csv = build([c], titles.map { Graded(courseID: c.id, title: $0, date: "2026-08-01") })
        let spots = titles.compactMap { position($0, in: csv) }
        #expect(spots.count == 4)
        #expect(spots == spots.sorted())
    }

    @Test func summarisesEachClassAndTheOverallGpa() {
        let c = Klass()
        let csv = build([c], [Graded(courseID: c.id, score: 95, max: 100)])
        #expect(csv.contains("Class summary"))
        #expect(csv.contains("Chemistry,1,95.0,A,4.0"))
        #expect(csv.contains("Overall GPA,4.00"))
    }

    @Test func reportsCreditsAndWeightsTheGpaByThem() {
        let chem = Klass(credits: 4), art = Klass(name: "Art", credits: 1)
        let csv = build([chem, art], [
            Graded(courseID: chem.id, score: 95, max: 100),
            Graded(courseID: art.id, score: 85, max: 100),
        ])
        #expect(csv.contains("Chemistry,4,95.0,A,4.0"))
        #expect(csv.contains("Art,1,85.0,B,3.0"))
        #expect(csv.contains("Overall GPA,3.80"))
    }

    @Test func honoursAnAlternativeScale() {
        let c = Klass()
        let csv = build([c], [Graded(courseID: c.id, score: 90, max: 100)], scale: SIMPLE_SCALE)
        #expect(csv.contains("Chemistry,1,90.0,A,4.0"))
    }

    @Test func skipsClassesWithNoGrades() {
        let c = Klass(), empty = Klass(name: "Empty")
        let csv = build([c, empty], [Graded(courseID: c.id)])
        #expect(!csv.contains("Empty"))
    }

    @Test func saysNotApplicableRatherThanCrashingWhenNothingIsGraded() {
        #expect(build([Klass()], []).contains("Overall GPA,n/a"))
    }

    @Test func usesCrlfEndingsAndEndsWithANewline() {
        let c = Klass()
        let csv = build([c], [Graded(courseID: c.id)])
        #expect(csv.hasSuffix("\r\n"))
        // Split on "\r\n": no piece may still hold a line break of its own.
        #expect(csv.components(separatedBy: "\r\n").allSatisfy {
            !$0.unicodeScalars.contains("\n") && !$0.unicodeScalars.contains("\r")
        })
    }

    // MARK: Beyond the web's tests

    /// The whole file, against what lib/report.ts writes for the same input:
    /// a comma in a class name, a formula-looking name, fractional credits,
    /// extra credit, a quote in a title, same-day order, a class with no
    /// results, a result of a class that isn't listed, and a 6.25% tie.
    @Test func matchesTheWebsFileCharacterForCharacter() {
        let chem = Klass(name: "Chemistry, Adv", credits: 4)
        let art = Klass(name: "=Art", credits: 1.5)
        let empty = Klass(name: "Empty")
        let csv = build([chem, art, empty], [
            Graded(courseID: chem.id, title: "Quiz 1", score: 8.5, max: 10, weight: 20,
                   date: "2026-09-01", kindName: "quiz"),
            Graded(courseID: chem.id, title: "Lab \"B\"", score: 19, max: 20, weight: 30,
                   date: "2026-09-01"),
            Graded(courseID: chem.id, title: "Midterm", score: 105, max: 100, weight: 50,
                   date: "2026-08-20", kindName: "exam"),
            Graded(courseID: art.id, title: "Sketch", score: 1, max: 16, weight: 100,
                   date: "2026-09-05", kindName: "project"),
            Graded(courseID: UUID(), title: "Old term", score: 50, max: 100, weight: 100,
                   date: "2026-01-05"),
        ], termName: "Fall 2026")
        // web:
        let expected = [
            "ClassPing grade report",
            "Term,Fall 2026",
            "Generated,2026-08-10",
            "",
            "Class,Credits,Item,Type,Date,Score,Out of,Percent,Weight %",
            "\"Chemistry, Adv\",4,Midterm,exam,2026-08-20,105,100,105.0,50",
            "\"Chemistry, Adv\",4,Quiz 1,quiz,2026-09-01,8.5,10,85.0,20",
            "\"Chemistry, Adv\",4,\"Lab \"\"B\"\"\",,2026-09-01,19,20,95.0,30",
            "'=Art,1.5,Sketch,project,2026-09-05,1,16,6.3,100",
            "",
            "Class summary",
            "Class,Credits,Average %,Letter,Points",
            "\"Chemistry, Adv\",4,98.0,A,4.0",
            "'=Art,1.5,6.3,F,0.0",
            "",
            "Overall GPA,2.91",
            "",
        ].joined(separator: "\r\n")
        #expect(csv == expected)
    }

    /// Eight one-credit classes at 4, 4, 4, 4, 3, 3, 3 and 0 points: exactly
    /// 3.125. JavaScript writes "3.13"; printf on its own would write "3.12".
    @Test func anExactHalfGpaRoundsUpAsOnTheWeb() {
        let marks: [Double] = [95, 95, 95, 95, 85, 85, 85, 50]
        let courses = marks.indices.map { Klass(name: "Class \($0)") }
        let grades = marks.indices.map { Graded(courseID: courses[$0].id, score: marks[$0]) }
        // web: ["", "Overall GPA,3.13", ""] (the file's last three lines)
        #expect(build(courses, grades).hasSuffix("\r\n\r\nOverall GPA,3.13\r\n"))
    }

    /// The web's server leaves out an empty term name. The phone also trims
    /// one that's only spaces, and the spaces around one that isn't.
    @Test func aBlankTermNameGetsNoTermLine() {
        let c = Klass()
        #expect(!build([c], [], termName: nil).contains("Term,"))
        #expect(!build([c], [], termName: "").contains("Term,"))
        #expect(!build([c], [], termName: "   ").contains("Term,"))
        #expect(build([c], [], termName: "  Fall 2026 ").contains("\r\nTerm,Fall 2026\r\n"))
    }

    /// D-56: the day on your own clock. At 9:30 PM in Maine, the web's
    /// `toISOString()` already says tomorrow (web, TZ=America/New_York:
    /// "2026-12-11").
    @Test func theGeneratedLineIsYourOwnCalendarDay() {
        let late = buildGradeReport([Klass](), [Graded](), generatedAt: at(2026, 12, 10, 21, 30))
        let early = buildGradeReport([Klass](), [Graded](), generatedAt: at(2026, 12, 10, 0, 5))
        #expect(late.contains("\r\nGenerated,2026-12-10\r\n"))
        #expect(early.contains("\r\nGenerated,2026-12-10\r\n"))
    }
}

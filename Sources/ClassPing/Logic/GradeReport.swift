//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/GradeReport.swift
//  Phase:   9c (finals countdown and the CSV report)
//  Ports:   the CSV half of lib/report.ts: csvField and buildGradeReport
//
//  Summary: Builds the term report as CSV text, the same file the web's
//           "Spreadsheet instead (CSV)" button downloads: one row per graded
//           result, a summary per class, then the overall GPA. With it come
//           the two JavaScript ways of writing a number that the file uses,
//           so every number matches the web's character for character.
//

import Foundation

/// A class as the report sees it: the GPA's id and credits, plus its name.
/// It builds on GradedCourse (9a), like GoalCourse does (9b).
protocol ReportCourse: GradedCourse {
    var name: String { get }
}

/// A result as the report sees it: the GPA's numbers, plus what its row prints.
protocol ReportGrade: GradedResult {
    var title: String { get }
    var date: String { get }
    /// "exam", "quiz", "assignment" or "project". Nil when it wasn't set.
    var kindName: String? { get }
}

/// A number the way JavaScript's `String(n)` writes it, which is what the
/// web puts in its CSV: 8 -> "8", 8.5 -> "8.5". Swift's own "\(8.0)" says "8.0".
func jsNumber(_ value: Double) -> String {
    // A whole number loses its ".0". The 10^15 cap keeps `Int(value)` from
    // overflowing; no score, weight or credit gets anywhere near it.
    if value == value.rounded(), abs(value) < 1e15 {
        return String(Int(value))
    }
    // Anything else: Swift's shortest digits that read back as the same
    // number, which JavaScript uses too. 0.1 + 0.2 is "0.30000000000000004"
    // in both.
    return "\(value)"
}

/// `n.toFixed(digits)` from JavaScript: 95 -> "95.0", 3.125 -> "3.13".
///
/// Swift's `String(format: "%.2f", n)` agrees with it except on an exact
/// half. 3.125 is exactly 3.125 in binary, and printf rounds a tie to the
/// even neighbor ("3.12") where JavaScript rounds away from zero ("3.13").
/// A GPA of 3.125 is only eight one-credit classes away, so ties matter.
/// (1.005 is not a tie: in binary it's 1.00499999..., and both say "1.00".)
/// A NaN or infinity can't get here, because grades are checked when saved.
func jsFixed(_ value: Double, _ digits: Int) -> String {
    // printf writes a double's exact decimal value. Forty places reach past
    // the last nonzero digit of any number a grade report holds.
    let exact = String(format: "%.40f", value.magnitude)
    // The digits after the ones we keep. An exact half is a 5, then only zeros.
    let fraction = exact.split(separator: ".").last ?? ""
    let dropped = fraction.dropFirst(digits)
    let isHalf = dropped.first == "5" && dropped.dropFirst().allSatisfy { $0 == "0" }
    // On a half, step to the next double up, so printf picks the upper
    // neighbor the way JavaScript does. `nextUp` is the smallest step there is.
    let magnitude = isHalf ? value.magnitude.nextUp : value.magnitude
    // JavaScript writes a minus sign for anything below zero, even "-0.0".
    return (value < 0 ? "-" : "") + String(format: "%.\(digits)f", magnitude)
}

/// One CSV cell, quoted when it needs to be and defused when it could run.
/// `csvField` in lib/report.ts.
///
/// Titles are typed by you. Excel and Sheets run a cell that starts with
/// =, +, - or @ as a formula when the file opens, so a class called
/// `=HYPERLINK(...)` would turn into a live link in a file you might forward.
/// An apostrophe in front keeps it plain text and still shows what you typed.
func csvField(_ value: String) -> String {
    var cell = value
    // Unicode scalars, not Characters: Swift counts "\r\n" as one Character,
    // so checking `first == "\r"` would miss it. The web's regex sees two.
    if let first = cell.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) {
        cell = "'" + cell
    }
    // A comma, quote or line break would split the cell. Wrap it in quotes,
    // and double any quote inside, which is how CSV writes a quote.
    if cell.unicodeScalars.contains(where: { "\",\r\n".unicodeScalars.contains($0) }) {
        cell = "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return cell
}

/// One line of the file: every cell through csvField, joined by commas.
/// The web's `row` helper.
func csvRow(_ cells: [String]) -> String {
    cells.map(csvField).joined(separator: ",")
}

/// The whole report as text, ready to save as a .csv file.
/// `buildGradeReport` in lib/report.ts, line for line.
///
/// - `courses`: the classes to report on, in this order. Grades passes this
///   term's classes, as the web does.
/// - `grades`: results to pick from. Each class takes its own, so results of
///   other classes are simply never printed.
/// - `termName`: printed on a "Term" line when it has any text.
/// - `generatedAt`: when the file was made. The web writes that day in UTC;
///   this writes your own calendar day (D-56).
func buildGradeReport<C: ReportCourse, G: ReportGrade>(
    _ courses: [C], _ grades: [G], scale: [ScaleBand] = DEFAULT_SCALE,
    termName: String? = nil, generatedAt: Date = .now
) -> String {
    var lines: [String] = []

    // The heading: what this is, which term, and the day it was made.
    lines.append(csvRow(["ClassPing grade report"]))
    let term = termName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !term.isEmpty { lines.append(csvRow(["Term", term])) }
    lines.append(csvRow(["Generated", dayOf(generatedAt)]))
    lines.append("")

    // One row per result, under the column names.
    lines.append(csvRow(["Class", "Credits", "Item", "Type", "Date",
                         "Score", "Out of", "Percent", "Weight %"]))
    for course in courses {
        // Oldest first. Swift's sort is stable, so results that share a day
        // keep the order you logged them in, as the web's `localeCompare` does.
        let mine = grades.filter { $0.courseID == course.id }.sorted { $0.date < $1.date }
        for grade in mine {
            // Same order of operations as the web, so the same digits come out.
            let percent = grade.max > 0 ? grade.score / grade.max * 100 : 0
            lines.append(csvRow([course.name, jsNumber(creditsFor(course)), grade.title,
                                 grade.kindName ?? "", grade.date, jsNumber(grade.score),
                                 jsNumber(grade.max), jsFixed(percent, 1),
                                 jsNumber(grade.weight)]))
        }
    }

    // One summary line per class that has an average. A class with nothing
    // graded has none, and `if let` leaves it out.
    lines.append("")
    lines.append(csvRow(["Class summary"]))
    lines.append(csvRow(["Class", "Credits", "Average %", "Letter", "Points"]))
    for course in courses {
        if let average = classAverage(grades.filter { $0.courseID == course.id }) {
            lines.append(csvRow([course.name, jsNumber(creditsFor(course)),
                                 jsFixed(average, 1), letterFor(average, scale),
                                 jsFixed(pointsFor(average, scale), 1)]))
        }
    }

    // The overall GPA, credit-weighted, or "n/a" before anything is graded.
    let gpa = overallGpa(courses, grades, scale)
    lines.append("")
    lines.append(csvRow(["Overall GPA", gpa.map { jsFixed($0, 2) } ?? "n/a"]))

    // "\r\n" between lines, the ending CSV expects, and one more at the end so
    // the file finishes cleanly in every editor.
    return lines.joined(separator: "\r\n") + "\r\n"
}

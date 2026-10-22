---
title: "Phase 9c: Finals countdown and the term report"
date: 2026-10-20
---

# Phase 9c: Finals countdown and the term report

Last of the three parts of Phase 9 (D-48). This guide builds on your typed
9b, which isn't committed yet. I diffed your tree against the 9b reference
and all eight source files are identical. In throwaway copies your
`test-logic.sh` passed 342/342 and `test-store.sh` 75/75, and the tree built
with no warnings. On 2026-10-20 you confirmed on the phone that editing and
the grade projection work.

**Before you type anything: commit 9b.** Otherwise 9b and 9c end up in one
commit, and the next review can't tell them apart:

```bash
cd ~/ClassPing
git add -A && git commit -m "phase 9b"
```

**Then:** type the seven files in section 4, in order. Four are new and
three replace files you already have. In the replaced ones, the changed spots
are listed before each file and marked `// NEW in Phase 9c` or
`// CHANGED in Phase 9c` in the code. Then copy the three test files from
4.8. No script changes.

**Verification (2026-10-20):** the reference iOS build passed with no
warnings. 371/371 logic tests passed in three time zones (the default,
America/New_York and Asia/Kolkata), and 67/67 reference store tests. Your own
logic and store suites plus the three new test files passed 371/371 and 79/79
against the new source in disposable packages. The seven guide blocks laid
over your current tree are identical to the reference, and that tree built
with no warnings. The "web:" cases in the tests are lib/report.ts's own output
(node 24). No 9c phone check has happened yet.

## 1. Goal

See how many days are left until finals, and send this term's grades to a
spreadsheet.

**On your phone:** open **Profile → Grades & GPA**. Under the GPA card, a
**Days to Finals** card asks for your finals date. Pick it and tap **Save**:
"51 days · Finals begin Thursday, Dec 10. You've got this." Below your
classes, the **Term report** card has one button, **Share as a spreadsheet
(CSV)**. It opens the share sheet with `classping-grades.csv`: save it to
Files, mail it to yourself, open it in Numbers.

This part includes:

- The finals countdown: set, edit, clear, "Today" on finals day and "Done"
  after it, in the web's words. It turns over at midnight even if the screen
  stays open.
- The CSV report: the same columns, rows, order and numbers as the web's
  "Spreadsheet instead (CSV)" file, built on the phone with no network.
- One rounding fix on the Grades screen (D-57): the GPA and the percentages
  now round exactly like the web, so the screen and the report never
  disagree.

That finishes Phase 9. The printable PDF report stays on the server (D-6)
and comes with sign-in in Phase 14. **9b+** (the D-54 field look on the other
forms, D-55) is still queued and doesn't touch any file here, so it can come
next or later.

## 2. New Swift concepts

### `Transferable` and `FileRepresentation`

`Transferable` is the protocol for values that can leave your app: shared,
dragged or copied. A type signs up by describing the forms it can take, in
one static property. The report has one form, a file:

```swift
struct GradeReportFile: Transferable {
    let report: TermReport
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = URL.temporaryDirectory.appending(path: "classping-grades.csv")
            // ...write the CSV to url...
            return SentTransferredFile(url)
        }
    }
}
```

The closure runs only when you pick a destination in the share sheet, and
it runs off the main actor. That's why it gets a `TermReport`, a `Sendable`
copy of the classes and grades, and not the `@MainActor` store itself.
`.commaSeparatedText` is a `UTType` (from `UniformTypeIdentifiers`): it tells
iOS the file is a CSV, so Files gives it a spreadsheet icon and Numbers
offers to open it. The closure is allowed to `throw`. A `throw` isn't a
`do`/`catch` block; it just hands the failure to the share sheet.

### `ShareLink`

A button that opens the system share sheet with an item. Any `Transferable`
value works: a `String`, a `URL`, an `Image`, or your own type.
`SharePreview` is the title and icon at the top of the sheet.

```swift
ShareLink(item: GradeReportFile(report: store.termReport),
          preview: SharePreview("ClassPing grade report",
                                image: Image(systemName: "tablecells"))) {
    Label("Share as a spreadsheet (CSV)", systemImage: "square.and.arrow.up")
}
```

It's the phone's version of the web's download link. Instead of landing in
a Downloads folder, the file goes where you choose: Files, Mail, Messages,
AirDrop.

### Ranges in a `switch`

A `switch` can match a number against ranges, not just single values:

```swift
switch days {
case 2...: return "\(days) days"   // 2 or more
case 1:    return "1 day"
case 0:    return "Today"
default:   return "Done"           // whatever's left: below zero
}
```

`2...` is a one-sided range, 2 up to forever. Cases are tried top to bottom
and the first match wins. Swift insists the cases cover every possible
`Int`, which is what `default` is for. Swift cases never fall through to the
next one, so there's no `break` anywhere.

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `daysUntil` and the sentences in `components/FinalsCountdown.tsx` | `Logic/Finals.swift` (`finalsStatus`), tested in `FinalsTests.swift` |
| The rest of `components/FinalsCountdown.tsx` | `Screens/Grades/FinalsCountdown.swift`, under the GPA card |
| `setProfile({ finalsDate })` | `setFinalsDate` in `Store+Grades.swift` |
| `csvField`, `row` and `buildGradeReport` in `lib/report.ts` | `Logic/GradeReport.swift` |
| The `csvField` and `buildGradeReport` cases in `lib/report.test.ts` | `GradeReportTests.swift`, plus a whole-file comparison with the web's own output |
| `ExportReportButton` (its CSV half) in `app/grades/page.tsx`, and `downloadGradeReport` | `Screens/Grades/TermReportCard.swift`, fed by `TermReport` in `Store+Grades.swift` |
| `toFixed` on the Grades screen and in `GoalBlock` | `jsFixed` in `GradesView.swift` and `GoalCard.swift` (D-57) |
| `/api/export/grades` and `buildGradeReportPdf` | Not on the phone yet: the PDF is a Connect (D-6), Phase 14 |

Where the phone deliberately differs:

- **The CSV is made on the phone (D-6).** The web posts your classes and
  grades to `/api/export/grades`, which needs sign-in, and the server builds
  the file. `buildGradeReport` is a pure function, so the phone runs the same
  steps itself, offline. The PDF needs the server's PDF writer and sign-in,
  so it waits.
- **Finals count your own calendar days (D-56).** The web's card has its own
  `daysUntil`, which reads "2026-12-10" with `new Date(iso)`: midnight in
  London. Anywhere west of London the count comes out a day short. I ran the
  web's function in node with `TZ=America/New_York`: from Oct 20 to finals on
  Dec 10 it says 50 (the answer is 51), and on Dec 10 itself it says "Done".
  The phone uses the same count as a task's deadline. The web fix is one
  line, but the web app is read-only for iOS work, so it's an open question
  for you (PROGRESS, question 21).
- **"Generated" is your own day (D-56).** The web writes the UTC date
  (`toISOString()`), so after 8 PM in Maine (7 PM in winter) its report is
  dated tomorrow. The phone writes today.
- **A blank term name.** The web's server leaves out an empty term name (and
  one over 64 characters). The phone also leaves out a name that's only
  spaces, trims the spaces around one that isn't, and prints long names in
  full.
- **Share, not download.** Same file name, same bytes; you pick where it goes.

Web behavior kept on purpose:

- **Every character of the file.** Numbers are written the way JavaScript
  writes them: `8`, not `8.0` (`jsNumber`). Rounding is JavaScript's
  `toFixed`, including exact halves: 3.125 is "3.13" on the web, while Swift's
  own `String(format:)` would say "3.12" (`jsFixed`). A test compares a whole
  file with the web's output for the same classes and grades.
- **Formula defusing:** a cell starting with `=`, `+`, `-` or `@` gets an
  apostrophe in front, so a spreadsheet shows it instead of running it.
- **`\r\n` line endings, and no byte-order mark**, like the web's file.
  [Likely] Excel on Windows can show accented letters wrongly in a CSV with no
  byte-order mark, and the web's file has the same issue. Numbers and Google
  Sheets read it fine.
- **The report card shows as soon as this term has a class**, graded or not,
  like the web's.

**Why D-57 is in this phase:** the report puts a GPA in a file right under
the GPA card, so the two have to agree. They didn't always. screen's
`.formatted(.number.precision(.fractionLength(2)))` (9a and 9b) rounds an exact half to
the even neighbor. [Certain] I checked it with Swift's own Foundation in WSL:
3.125 shows as "3.12" and 6.25 at one place as "6.2", where the web (and now
the CSV) say "3.13" and "6.3". [Likely] iOS formats the same way. Exact
halves aren't exotic: two 3-credit classes and two 1-credit labs make 8
credits, and eighths are where they happen. So the five spots in
`GradesView` and the three in `GoalCard` where the web uses `toFixed` now
use `jsFixed`.

## 4. Files, in the order to type them

Seven source files: four new (4.1, 4.2, 4.4, 4.5) and three replaced (4.3,
4.6, 4.7). Build once all seven are in. `Store+Grades` needs `GradeReport`,
and `GradesView` needs both new cards.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Finals.swift` (new file)

The countdown's maths and words, Foundation only, so `FinalsTests` can run
on Linux. It leans on two functions you already have: `daysUntil` (Phase 2)
and `longDeadline` (Phase 4a).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Finals.swift
//  Phase:   9c (finals countdown and the CSV report)
//  Ports:   the countdown maths and words of components/FinalsCountdown.tsx
//
//  Summary: How many days until finals, and what the card says about it:
//           "51 days", "Today" or "Done", each with the web's sentence.
//           Counts calendar days on your own clock, so finals day is always
//           "Today" (D-56).
//

import Foundation

/// What the Days to Finals card shows for one finals date on one day.
/// The web works these out inline in its markup. One value keeps the number,
/// its word and the sentence from disagreeing.
struct FinalsStatus: Equatable {
    /// Whole calendar days from today to finals: 0 on the day, negative after.
    var days: Int
    /// The big text: the number of days, "Today" or "Done".
    var headline: String
    /// "days" or "day" beside the number. Nil for "Today" and "Done".
    var unit: String?
    /// The line under it, like "Finals begin Thursday, Dec 10. You've got this."
    var message: String
}

/// The countdown for a stored finals date ("yyyy-MM-dd") as of `now`, or nil
/// when there's no usable date, so the card asks for one instead.
///
/// The web's card has its own `daysUntil`, which reads "2026-12-10" with
/// `new Date(iso)`. That's midnight in London, so anywhere west of it (Maine
/// included) the count comes out a day short, and finals day itself says
/// "Done". This uses `daysUntil` from Logic/Deadline.swift instead: the same
/// calendar-day count a task's deadline uses (D-56).
func finalsStatus(_ finalsDate: String?, _ now: Date) -> FinalsStatus? {
    // The finals date as an all-day deadline. makeDeadline drops anything
    // that isn't a real day, and then daysUntil answers nil.
    let finals = makeDeadline(finalsDate, nil)
    guard let days = daysUntil(finals, now) else { return nil }
    // "Thursday, Dec 10": a task's long date, which has no time to add here.
    let day = longDeadline(finals)

    // A `switch` can match a number against ranges. `2...` means "2 or
    // more". Cases are tried top to bottom, and the first match wins.
    switch days {
    case 2...:
        return FinalsStatus(days: days, headline: "\(days)", unit: "days",
                            message: "Finals begin \(day). You've got this.")
    case 1:
        return FinalsStatus(days: 1, headline: "1", unit: "day",
                            message: "Finals are tomorrow, \(day).")
    case 0:
        return FinalsStatus(days: 0, headline: "Today", unit: nil,
                            message: "Finals are today. Good luck! 🍀")
    default:
        // Everything left is below zero: finals have been and gone.
        return FinalsStatus(days: days, headline: "Done", unit: nil,
                            message: "Finals were \(day). Set a new date for next term.")
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/GradeReport.swift` (new file)

The report itself, plus `jsNumber` and `jsFixed`. Read the comments on
`jsFixed` and `csvField`: each one covers a place where Swift and JavaScript
quietly disagree (exact halves, and `"\r\n"` being one Swift `Character`).

```swift
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
```

### 4.3 `~/ClassPing/Sources/ClassPing/Store+Grades.swift` (replaces your 9b file)

Changed spots:

- **Header** (changed).
- **Two sign-ups** under 9b's `extension Course: GoalCourse {}` (new):
  `Course` to `ReportCourse`, and `Grade` to `ReportGrade` with a computed
  `kindName`.
- **`TermReport`** (new struct, right after them).
- **`setFinalsDate` and `termReport`** (new, at the end, under
  `// MARK: - Finals and the report`).

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Store+Grades.swift
// Phase: 9a, extended in 9b and 9c
// Ports: lib/store.tsx (grade actions, and the gradeScale, customScale,
//        goal and finalsDate writes), app/grades' filtering, and what
//        ExportReportButton in app/grades/page.tsx gathers for the report.
// Summary: Grade CRUD, validation and the bridge to the pure GPA functions.
//          Since 9b also the scale choice, the custom bands and class goals,
//          and since 9c the finals date, each saved only once planner.json
//          has it. 9c also hands the term report its classes and results.
//
import Foundation

// These models already have every field the maths asks for.
extension Grade: GradedResult {}
extension Course: GradedCourse {}
// NEW in Phase 9b: Course already has `goal`, so signing up is one line.
extension Course: GoalCourse {}
// NEW in Phase 9c: Course has `name`. Grade's kind is an enum, and the
// report prints its raw value ("exam"), the word the web stores.
extension Course: ReportCourse {}
extension Grade: ReportGrade {
    var kindName: String? { kind?.rawValue }
}

// NEW in Phase 9c
/// What the term report needs, copied out of the store: the same things the
/// web's export button sends to its server. The phone builds the file itself
/// (D-6). Plain values (`Sendable`), so the file can be made off the main
/// actor, at the moment the share sheet asks for it.
struct TermReport: Sendable {
    var courses: [Course]
    var grades: [Grade]
    var scale: [ScaleBand]
    var termName: String?

    /// The CSV text, dated `now`.
    func csv(at now: Date) -> String {
        buildGradeReport(courses, grades, scale: scale, termName: termName, generatedAt: now)
    }
}

extension Store {
    var liveGrades: [Grade] { grades.filter { $0.deletedAt == nil } }

    func grade(_ id: UUID) -> Grade? { liveGrades.first { $0.id == id } }

    /// Stable newest-day order: two grades entered on one date keep their order.
    func grades(for courseID: UUID) -> [Grade] {
        liveGrades.filter { $0.courseID == courseID }.sorted { $0.date > $1.date }
    }

    var gradeScale: [ScaleBand] {
        resolveScale(profile.gradeScale?.rawValue, custom: profile.customScale)
    }

    // NEW in Phase 9b
    /// True while Custom is chosen but none of its bands are usable, so the
    /// standard scale is standing in. The Grades screen says so.
    var usesFallbackScale: Bool {
        customScaleIsEmpty(profile.gradeScale?.rawValue, custom: profile.customScale)
    }

    /// Past terms keep their own totals, in order of the courses in the store.
    var gradedPastTerms: [String] {
        var terms: [String] = []
        for course in liveCourses where course.archived && !grades(for: course.id).isEmpty {
            let term = gradeTerm(for: course)
            if !terms.contains(term) { terms.append(term) }
        }
        return terms
    }

    func gradeTerm(for course: Course) -> String {
        let term = course.term?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return term.isEmpty ? "Earlier" : term
    }

    func gradedCourses(in term: String) -> [Course] {
        liveCourses.filter {
            $0.archived && gradeTerm(for: $0) == term && !grades(for: $0.id).isEmpty
        }
    }

    /// Same form bounds as the web. More than full marks is valid. A missing
    /// or deleted class cannot receive a grade, even if a sheet was open.
    func validGrade(_ value: Grade) -> Bool {
        course(value.courseID) != nil &&
        !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        value.score.isFinite && value.score >= 0 &&
        value.max.isFinite && value.max > 0 &&
        value.weight.isFinite && value.weight > 0 && value.weight <= 100 &&
        isValidDate(value.date) && value.deletedAt == nil
    }

    /// Return true only after the file is written. A failure leaves the draft
    /// in the form and rolls back this array, so retry cannot add a duplicate.
    @discardableResult
    func addGrade(_ value: Grade) -> Bool {
        guard validGrade(value), !grades.contains(where: { $0.id == value.id }) else { return false }
        var clean = value
        clean.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let before = grades
        grades.append(clean)
        save()
        if lastSaveFailed { grades = before; return false }
        return true
    }

    @discardableResult
    func updateGrade(_ value: Grade) -> Bool {
        guard validGrade(value),
              let index = grades.firstIndex(where: { $0.id == value.id && $0.deletedAt == nil })
        else { return false }
        let before = grades[index]
        var clean = value
        clean.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        grades[index] = clean
        save()
        if lastSaveFailed { grades[index] = before; return false }
        return true
    }

    /// Soft-delete only; the shared Undo action restores this exact record.
    @discardableResult
    func deleteGrade(_ id: UUID) -> Bool {
        guard let index = grades.firstIndex(where: { $0.id == id && $0.deletedAt == nil })
        else { return false }
        let now = Date.now
        grades[index].deletedAt = now
        save()
        if lastSaveFailed { grades[index].deletedAt = nil; return false }
        let title = grades[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(item: .grade(id),
                                  label: "\(title.isEmpty ? "Grade" : title) deleted", at: now)
        return true
    }

    // MARK: - Scales and goals (NEW in Phase 9b)

    /// Switch between the standard, simple and custom scales: the web's
    /// `setProfile({ gradeScale })`. Like the grade actions, true only once
    /// planner.json has it; a failed write puts the old choice back.
    @discardableResult
    func setGradeScale(_ next: Profile.GradeScale) -> Bool {
        let before = profile.gradeScale
        profile.gradeScale = next
        save()
        if lastSaveFailed { profile.gradeScale = before; return false }
        return true
    }

    /// Save the usable part of a custom scale, high to low: what the web's
    /// editor saves on every edit (`normalizeScale(...) ?? []`). Nothing
    /// usable saves an empty list, and grading falls back to the standard scale.
    @discardableResult
    func setCustomScale(_ draft: [ScaleBand]) -> Bool {
        let clean = normalizeScale(draft) ?? []
        // Typing into a half-finished row changes nothing usable: skip the
        // write. After a failed write, always try again.
        if clean == profile.customScale && !lastSaveFailed { return true }
        let before = profile.customScale
        profile.customScale = clean
        save()
        if lastSaveFailed { profile.customScale = before; return false }
        return true
    }

    /// Set or clear a class's target percentage: `updateClass(id, { goal })`.
    /// Nil, zero or less clears it, which is how the maths reads them anyway.
    /// A missing or deleted class, or a number that isn't a percentage, is
    /// refused. A failed write keeps the old goal.
    @discardableResult
    func setGoal(_ goal: Double?, for courseID: UUID) -> Bool {
        guard let index = courses.firstIndex(where: { $0.id == courseID && $0.deletedAt == nil })
        else { return false }
        if let goal, !goal.isFinite || goal > 100 { return false }
        let before = courses[index].goal
        // `flatMap` on an optional: keep a positive goal, turn the rest into nil.
        courses[index].goal = goal.flatMap { $0 > 0 ? $0 : nil }
        save()
        if lastSaveFailed { courses[index].goal = before; return false }
        return true
    }

    // MARK: - Finals and the report (NEW in Phase 9c)

    /// Set or clear the finals date: the web's `setProfile({ finalsDate })`.
    /// A day must be a real "yyyy-MM-dd", and nil clears it. Like the scale
    /// and goals, true only once planner.json has it; a failed write puts the
    /// old date back.
    @discardableResult
    func setFinalsDate(_ day: String?) -> Bool {
        if let day, !isValidDate(day) { return false }
        let before = profile.finalsDate
        profile.finalsDate = day
        save()
        if lastSaveFailed { profile.finalsDate = before; return false }
        return true
    }

    /// This term's report: this term's classes, every live result, your
    /// scale and your term's name. Past terms and deleted results stay out,
    /// as on the web.
    var termReport: TermReport {
        TermReport(courses: activeCourses, grades: liveGrades,
                   scale: gradeScale, termName: profile.termName)
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift` (new file)

The card. The date picker and `TimelineView` are old friends (7b and 5a);
the new part is `finalsStatus` and its `switch`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift
//  Phase:   9c (finals countdown and the CSV report)
//  Ports:   components/FinalsCountdown.tsx
//
//  Summary: The Days to Finals card on Grades: a live count of the days left
//           until your finals date, and a small form to set, change or clear
//           it. The date is saved on your profile, as on the web.
//

import SwiftUI

struct FinalsCountdown: View {
    @Environment(Store.self) private var store

    /// True while you're changing a date that's already set.
    @State private var editing = false
    /// The day in the picker, before you tap Save.
    @State private var draft = Date.now
    /// True when the last Save or Clear couldn't be written to the phone.
    @State private var failed = false

    var body: some View {
        let accent = store.profile.accent
        let saved = store.profile.finalsDate
        // A saved date that isn't a real day counts as none, so the card asks again.
        let hasDate = isValidDate(saved)

        VStack(alignment: .leading, spacing: 12) {
            // The label, with Edit beside it while the countdown shows.
            HStack {
                Text("DAYS TO FINALS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if hasDate && !editing {
                    Button("Edit") { openEditor(saved) }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.brandDeep(accent))
                        .frame(minHeight: 44)
                        .accessibilityLabel("Edit finals date")
                }
            }

            if hasDate && !editing {
                // TimelineView (5a) redraws once a minute, so the count turns
                // over at midnight even if this screen stays open.
                TimelineView(.everyMinute) { context in
                    if let status = finalsStatus(saved, context.date) {
                        countdown(status, accent)
                    }
                }
            } else {
                editor(hasDate: hasDate)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// The big number (or Today, or Done) and the sentence under it.
    private func countdown(_ status: FinalsStatus, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(status.headline)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.brandDeep(accent))
                if let unit = status.unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(status.message)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        // One VoiceOver stop: "51, days, Finals begin Thursday, Dec 10. …"
        .accessibilityElement(children: .combine)
    }

    /// Ask for a date (none yet), or change or clear the one you have.
    /// The web shows Clear and Cancel only when there's a date to go back to.
    private func editor(hasDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasDate ? "Update your finals date."
                 : "Add your finals date to see a live countdown.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            // Date only, like the planner's picker in 7b. The compact style
            // shows the day as a button that opens a calendar.
            DatePicker("Finals date", selection: $draft, displayedComponents: .date)

            HStack(spacing: 8) {
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                if hasDate {
                    Button("Clear", action: clear)
                        .buttonStyle(.bordered)
                    Button("Cancel") {
                        editing = false
                        failed = false
                    }
                }
            }

            // The screen's own banner sits far above this card, so say it here too.
            if failed {
                Text("Couldn't save on this device. Try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    /// Start the picker on the saved day: the web's `openEdit`.
    private func openEditor(_ saved: String?) {
        // `deadlineDayStart` turns "2026-12-10" into local midnight that day.
        draft = deadlineDayStart(makeDeadline(saved, nil)) ?? .now
        failed = false
        editing = true
    }

    /// Save the picked day as "yyyy-MM-dd" (`dayOf`: your own calendar day,
    /// never UTC's). The form stays open with a red line if the phone
    /// couldn't write it.
    private func save() {
        failed = !store.setFinalsDate(dayOf(draft))
        if !failed { editing = false }
    }

    /// Remove the date. The card goes back to asking for one.
    private func clear() {
        failed = !store.setFinalsDate(nil)
        if !failed { editing = false }
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Grades/TermReportCard.swift` (new file)

`Transferable` and `ShareLink`, the two concepts from section 2, in one file.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/TermReportCard.swift
//  Phase:   9c (finals countdown and the CSV report)
//  Ports:   ExportReportButton in app/grades/page.tsx (its CSV half) and
//           downloadGradeReport in lib/report.ts
//
//  Summary: The Term report card on Grades. One button opens the share sheet
//           with classping-grades.csv, built on the phone from this term's
//           classes and results: save it to Files, mail it, or AirDrop it.
//           The printable PDF is made by the server, so it waits for sign-in
//           (D-6).
//

import SwiftUI
import UniformTypeIdentifiers

/// The report as something the share sheet can send: a .csv file.
/// `Transferable` is how a value tells iOS what it can become (text, an
/// image, a file). On the web, `downloadBlob` in lib/report.ts does this job.
struct GradeReportFile: Transferable {
    /// This term's classes, results and scale, copied when the card was drawn.
    let report: TermReport

    /// The one form it can take: a file of type CSV (`.commaSeparatedText`).
    static var transferRepresentation: some TransferRepresentation {
        // FileRepresentation runs this only once you pick where the report
        // goes, so the file is built, and dated, at the moment you share it.
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            // The app's temporary folder, which iOS empties on its own. The
            // file name is the one the web downloads.
            let url = URL.temporaryDirectory.appending(path: "classping-grades.csv")
            let data = Data(file.report.csv(at: .now).utf8)
            // `try?` turns a failed write into nil. This closure is allowed to
            // throw, and throwing tells the share sheet the file couldn't be
            // made, instead of handing over one that isn't there.
            guard (try? data.write(to: url, options: .atomic)) != nil else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

struct TermReportCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TERM REPORT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            // ShareLink is a button that opens the share sheet with `item`.
            // SharePreview is the title and icon at the top of that sheet.
            ShareLink(item: GradeReportFile(report: store.termReport),
                      preview: SharePreview("ClassPing grade report",
                                            image: Image(systemName: "tablecells"))) {
                Label("Share as a spreadsheet (CSV)", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)

            Text("Every result with its class, a summary for each class and your GPA. Opens in Numbers, Google Sheets or Excel.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Text("The printable PDF report needs sign-in, which comes later.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Grades/GoalCard.swift` (replaces your 9b file)

Changed spots (D-57), nothing else:

- **Header** (the Phase line).
- **`needed`**, **`finished`** and the **"points short"** sentence in
  `message` now use `jsFixed(…, 1)`.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GoalCard.swift
// Phase: 9b (scales, goals and what-if), rounding changed in 9c (D-57)
// Ports: GoalBlock in app/grades/page.tsx.
// Summary: A class's target grade and what it will take to get there. Pick a
//          goal from the top bands of your scale, then read what you need on
//          the work that's left, or why there's nothing left to work out.
//
import SwiftUI

/// Sits in a current-term class's card on the Grades screen, under its
/// average. The goal is saved on the class, not held in this view, because
/// the projected GPA at the top of the screen reads it too.
struct GoalCard: View {
    @Environment(Store.self) private var store
    let course: Course
    /// This class's live grades (its card already has them).
    let grades: [Grade]

    /// True while choosing a new goal over an existing one.
    @State private var picking = false
    /// Set when the last goal couldn't be written to planner.json.
    @State private var failed = false

    var body: some View {
        let goal = goalOf(course)
        let accent = Theme.brand(store.profile.accent)
        VStack(alignment: .leading, spacing: 8) {
            // The label, and the goal as a pill that reopens the chips.
            HStack {
                Text(goal == nil ? "Aiming for" : "Goal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                if let goal, !picking {
                    Button { picking = true } label: {
                        HStack(spacing: 6) {
                            Text("\(letterFor(goal, store.gradeScale)) · \(goal.formatted())%")
                            Image(systemName: "pencil").imageScale(.small)
                        }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accent, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Goal \(letterFor(goal, store.gradeScale)), \(goal.formatted()) percent")
                    .accessibilityHint("Change the goal")
                }
            }

            // Chips stay open until a goal exists; after that, the pill opens them.
            if picking || goal == nil {
                chips(goal)
            }

            message(goal, accent: accent)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if failed {
                Text("Couldn't save the goal on this device. Tap it again to retry.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// The top five bands of your scale as chips, so a goal reads as a real
    /// grade ("A-") rather than a bare number. Tapping the active one clears it.
    private func chips(_ goal: Double?) -> some View {
        let bands = Array(store.gradeScale.sorted { $0.min > $1.min }.prefix(5))
        // `ViewThatFits` shows the first child that fits the width it's offered:
        // one plain row when the letters are short, a row that scrolls sideways
        // when a custom scale's longer names ("First", "Third") don't fit.
        return ViewThatFits(in: .horizontal) {
            chipRow(bands, goal)
            ScrollView(.horizontal, showsIndicators: false) { chipRow(bands, goal) }
        }
    }

    private func chipRow(_ bands: [ScaleBand], _ goal: Double?) -> some View {
        HStack(spacing: 6) {
            // Letters are unique in every scale (normalizeScale sees to it),
            // so the letter can be each chip's id.
            ForEach(bands, id: \.letter) { band in
                let on = goal == band.min
                chip(band.letter, on: on) { choose(on ? nil : band.min) }
                    .accessibilityLabel("\(band.letter), \(band.min.formatted()) percent")
            }
            if goal != nil {
                chip("Clear", on: false) { choose(nil) }
            }
        }
    }

    /// One chip: brand-filled when it's the goal, the card color when not,
    /// like the Tasks filter chips. 44 points tall for the finger.
    private func chip(_ text: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(on ? Color.white : Theme.ink)
                .background(on ? Theme.brand(store.profile.accent) : Theme.card, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Save the new goal (nil clears it), then close the chips. A failed
    /// write leaves them open and says so; the class keeps its old goal.
    private func choose(_ next: Double?) {
        if store.setGoal(next, for: course.id) {
            failed = false
            picking = false
        } else {
            failed = true
        }
    }

    /// The sentence under the goal, in the web's words. `@ViewBuilder` lets
    /// each branch return its own Text. A `Text` dropped into another Text's
    /// string keeps its own bold and color, so one sentence can stress a number.
    @ViewBuilder
    private func message(_ goal: Double?, accent: Color) -> some View {
        let used = usedWeight(grades)
        // Rounded to one place, as the web's Math.round(used * 10) / 10.
        let usedText = Text("\(((used * 10).rounded() / 10).formatted())%")
            .bold()
            .foregroundStyle(Theme.dangerInk)

        if let goal {
            if let result = whatIfNeeded(grades, goal) {
                let left = result.remainingWeight.formatted()
                if result.alreadySecured {
                    Text("Already locked in, even a zero on the remaining \(left)% keeps you there. 🎉")
                } else {
                    // CHANGED in Phase 9c: toFixed(1) rounding, as on the web (D-57).
                    let needed = Text("\(jsFixed(result.needed, 1))%")
                        .bold()
                        .foregroundStyle(accent)
                    let reach = result.outOfReach
                        ? " That's above full marks, only extra credit gets you there." : ""
                    Text("You need \(needed) on the remaining \(left)% of the grade.\(reach)")
                }
            } else if used > 100 {
                // Over 100: whatIfNeeded has nothing to answer, and saying why
                // beats letting the answer quietly disappear.
                Text("Your logged weights add up to \(usedText), more than the 100% a class has. The average still works, it's scaled to fit, but there's no \u{201C}remaining\u{201D} left to work out what you need. Tap a grade to fix its weight.")
            } else if let average = classAverage(grades) {
                // Exactly 100: fully graded, so report the result.
                // CHANGED in Phase 9c: toFixed(1) rounding, as on the web (D-57).
                let finished = jsFixed(average, 1)
                if average >= goal {
                    Text("Everything's graded, you finished at \(finished)%. Goal met. 🎉")
                } else {
                    Text("Everything's graded, you finished at \(finished)%, \(jsFixed(goal - average, 1)) points short.")
                }
            } else {
                Text("Nothing graded yet.")
            }
        } else if used > 100 {
            // A data problem, not a goal problem, so it shows without a goal too.
            Text("Heads up: your logged weights add up to \(usedText), more than the 100% a class has. Tap a grade to fix its weight.")
        } else {
            Text("Set a target and we'll work out what you still need, and fold it into your projected GPA.")
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift` (replaces your 9b file)

Changed spots:

- **Header** (changed).
- **`FinalsCountdown()`** under `overview` (new).
- **`TermReportCard()`** after this term's class cards (new), only when the
  term has a class.
- **Rounding** (D-57): the GPA, the projected GPA (and its VoiceOver label),
  each class's average and each past term's GPA use `jsFixed`.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift
// Phase: 9a, extended in 9b and 9c
// Ports: app/grades/page.tsx, reached from Profile (D-19), and the grading
//        card of app/settings/page.tsx (D-51).
// Summary: This term's credit-weighted GPA, results and separate past terms.
// 9b adds the projected GPA, a goal on each class, and the three scales with
// the custom editor. 9c adds the finals countdown and the term report.
//
import SwiftUI

struct GradesView: View {
    @Environment(Store.self) private var store
    @State private var sheet: GradeSheet? = nil
    @State private var deleting: Grade? = nil

    /// One item binding avoids competing add and edit sheets.
    private struct GradeSheet: Identifiable {
        let id = UUID()
        var editing: Grade? = nil
        var courseID: UUID? = nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.lastSaveFailed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .foregroundStyle(Theme.danger)
                        Button("Retry save") { store.save() }
                    }
                    .font(.footnote)
                }
                overview
                // NEW in Phase 9c: under the GPA, where the web's phone layout
                // puts it.
                FinalsCountdown()
                scalePicker
                if store.activeCourses.isEmpty {
                    Text("No classes in this term yet. Add a class to start logging grades.")
                        .foregroundStyle(Theme.muted)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
                ForEach(store.activeCourses) { course in courseCard(course, canAdd: true) }
                // NEW in Phase 9c: the report, once there's a term to describe
                // (the web shows it as soon as a class exists, grades or not).
                if !store.activeCourses.isEmpty {
                    TermReportCard()
                }
                ForEach(store.gradedPastTerms, id: \.self) { term in
                    pastTerm(term)
                }
            }
            .padding(16)
            // Keep the wider device layout readable without hardcoding a phone width.
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .navigationTitle("Grades")
        .tint(Theme.brand(store.profile.accent))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = GradeSheet(courseID: store.liveGrades.last?.courseID)
                } label: { Label("Add grade", systemImage: "plus") }
            }
        }
        .sheet(item: $sheet) { value in
            GradeFormView(editing: value.editing, courseID: value.courseID)
        }
        .alert("Delete this grade?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleting { store.deleteGrade(deleting.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("You can undo this deletion.")
        }
        .undoBar()
    }

    private var overview: some View {
        let gpa = overallGpa(store.activeCourses, store.liveGrades, store.gradeScale)
        let count = store.activeCourses.filter { !store.grades(for: $0.id).isEmpty }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT TERM GPA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            // CHANGED in Phase 9c: rounded like the web's toFixed (D-57), so
            // the card and the CSV report always show the same GPA.
            Text(gpa.map { jsFixed($0, 2) } ?? "—")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand(store.profile.accent))
                .monospacedDigit()
                .accessibilityLabel(gpa.map { "GPA \($0.formatted())" } ?? "No GPA yet")
            Text(count == 0 ? "Log your first result to see your GPA."
                 : "Across \(count) graded \(count == 1 ? "class" : "classes"). Weighted by credits; an unset credit counts as one.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            // NEW in Phase 9b: where the term lands if every goal is met.
            // Nil until a class has a goal, so it never just repeats the GPA.
            if let projected = projectedGpa(store.activeCourses, store.liveGrades, store.gradeScale) {
                HStack(spacing: 10) {
                    Image(systemName: "target")
                        .foregroundStyle(Theme.brand(store.profile.accent))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROJECTED BY END OF TERM")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.brandDeep(store.profile.accent))
                        Text("If you hit every goal you've set.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Text(jsFixed(projected, 2))   // CHANGED in Phase 9c (D-57)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.brandDeep(store.profile.accent))
                }
                .padding(12)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                // One VoiceOver stop: "Projected by end of term, 3.50".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Projected by end of term if you hit every goal, \(jsFixed(projected, 2))")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // CHANGED in Phase 9b: all three scales, as the web's grading card has
    // them, with Custom opening its editor (D-51). The choice goes through
    // the store, which puts the old one back if the write fails.
    private var scalePicker: some View {
        let selected = store.profile.gradeScale ?? .standard
        return VStack(alignment: .leading, spacing: 10) {
            Text("GRADING SCALE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            Picker("Grade scale", selection: Binding(
                get: { store.profile.gradeScale ?? .standard },
                set: { store.setGradeScale($0) }
            )) {
                Text("A / A\u{2212}").tag(Profile.GradeScale.standard)
                Text("A / B / C").tag(Profile.GradeScale.simple)
                Text("Custom").tag(Profile.GradeScale.custom)
            }
            .pickerStyle(.segmented)

            // A line about the chosen scale; Custom adds the way into its editor.
            switch selected {
            case .standard:
                Text("93+ is an A, 90+ an A\u{2212}. The usual US scale.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            case .simple:
                Text("90+ is an A, 80+ a B. No plus or minus bands.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            case .custom:
                Text(store.usesFallbackScale
                     ? "Your custom scale is empty. Using US 4.0 for now."
                     : "Using your \(store.gradeScale.count) bands.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                NavigationLink {
                    GradeScaleEditor(saved: store.profile.customScale)
                } label: {
                    HStack {
                        Text(store.usesFallbackScale ? "Set up your scale" : "Edit your scale")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func courseCard(_ course: Course, canAdd: Bool) -> some View {
        let grades = store.grades(for: course.id)
        let average = classAverage(grades)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SubjectBook(color: course.color, short: course.short, compact: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name).font(.headline).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    // CHANGED in Phase 9c: toFixed(1) rounding (D-57).
                    Text(average.map { "\(jsFixed($0, 1))% average" }
                         ?? "No grades logged yet")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    if course.credits != nil {
                        Text("\(creditsFor(course).formatted()) cr").font(.caption)
                    }
                }
                Spacer(minLength: 0)
                if let average {
                    Text(letterFor(average, store.gradeScale))
                        .font(.title2.bold())
                        .foregroundStyle(Theme.subjectInk(course.color))
                }
            }
            // NEW in Phase 9b: this term's classes (the ones you can add to)
            // get a goal and the "what do I need?" answer. Past terms don't.
            if canAdd {
                GoalCard(course: course, grades: grades)
            }
            ForEach(grades) { grade in
                Divider()
                gradeRow(grade)
            }
            if canAdd {
                Button {
                    sheet = GradeSheet(courseID: course.id)
                } label: { Label("Add grade", systemImage: "plus") }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Add grade for \(course.name)")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func gradeRow(_ grade: Grade) -> some View {
        HStack(alignment: .top) {
            Button {
                sheet = GradeSheet(editing: grade)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(grade.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(grade.score.formatted()) / \(grade.max.formatted()) · \(grade.weight.formatted())% weight")
                    Text("\(grade.date)\(grade.kind.map { " · \($0.rawValue.capitalized)" } ?? "")")
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit grade")
            Button(role: .destructive) { deleting = grade } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Delete \(grade.title)")
        }
    }

    /// Archived courses never dilute today's headline. Their GPA is calculated
    /// with the same selected scale, matching the web's separate term sections.
    private func pastTerm(_ term: String) -> some View {
        let courses = store.gradedCourses(in: term)
        let gpa = overallGpa(courses, store.liveGrades, store.gradeScale)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Past term · \(term)")
                .font(.headline).foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            if let gpa {
                Text("\(jsFixed(gpa, 2)) GPA")   // CHANGED in Phase 9c (D-57)
                    .font(.subheadline)
            }
            ForEach(courses) { course in courseCard(course, canAdd: false) }
        }
    }
}
```

### 4.8 Tests (copy these, don't type them)

```bash
cd ~/ClassPing
REF=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $REF/Logic/GradeReportTests.swift Tests/Logic/       # new: 22 tests
cp $REF/Logic/FinalsTests.swift Tests/Logic/            # new: 7 tests
cp $REF/Persistence/GradeStoreTests.swift Tests/Store/  # replaces 9b's: +4 tests
```

Your scripts don't need changes: `test-logic.sh` copies every `Logic/*.swift`
file, and `test-store.sh` already lists `Store+Grades`.

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 371 tests passing
scripts/test-store.sh     # expect 79 tests passing
TZ=America/New_York scripts/test-logic.sh   # 371 again, on Maine's clock
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

1. **First date:** Profile → Grades & GPA. Under the GPA card, Days to
   Finals says "Add your finals date to see a live countdown." Tap the date,
   pick your first finals day, tap **Save**. The big number shows the days
   left with "days" beside it, and the line reads "Finals begin
   <weekday, Mon d>. You've got this." Check it on a calendar: today doesn't
   count and finals day does (Oct 20 to Dec 10 is 51).
2. **Edit and Cancel:** tap **Edit**. The card says "Update your finals
   date." and the picker starts on your saved day. Change it and tap
   **Cancel**: the old countdown comes back. Edit again, change it, **Save**:
   the new count shows.
3. **The three special days:** set tomorrow: "1 day" and "Finals are
   tomorrow, <weekday, Mon d>." Set today: "Today" with no unit, and "Finals
   are today. Good luck! 🍀". Set yesterday: "Done", and "Finals were
   <weekday, Mon d>. Set a new date for next term."
4. **Clear and relaunch:** Edit → **Clear**. The card asks for a date again,
   with no Clear or Cancel. Set your real date, close the app fully and
   reopen it: the countdown is still there.
5. **The report:** below your classes, **Term report → Share as a
   spreadsheet (CSV)**. The top of the sheet says "ClassPing grade report".
   Choose **Save to Files → On My iPhone → Save**. In Files, tap
   `classping-grades.csv` and Quick Look shows the table. Check: a Term line
   (if your term has a name), "Generated" with today's date, one row per
   grade with the oldest first, then "Class summary", then "Overall GPA"
   with the same number as the GPA card.
6. **Somewhere else:** share it again with Mail (to yourself) and open it on
   the laptop in Excel or Google Sheets. The columns match the web's CSV:
   Class, Credits, Item, Type, Date, Score, Out of, Percent, Weight %.
7. **Presentation:** dark mode and both accents: the big number, Edit and the
   share button stay easy to read. With VoiceOver the countdown is one stop.
   With larger text, the sentence under the number wraps instead of being cut
   off.

Nothing here can damage your planner: the report only reads it, and the
finals date is one profile field. Save failures are covered by the
disposable tests. Nothing was committed or installed by the agent.

## 6. Done when

- [ ] 9b is committed on its own.
- [ ] The tree builds without warnings; 371 logic and 79 store tests pass.
- [ ] The countdown counts whole days, shows Today and Done on the right
      days, and survives a relaunch.
- [ ] Edit, Cancel, Save and Clear behave as in steps 2 to 4.
- [ ] The CSV saves to Files, opens, and its rows and GPA match the screen.
- [ ] Light, dark, both accents and larger text are all readable.

Reference verification is not a phone pass. Tell me how steps 1 to 7 went.

## 7. If it breaks

- **Cannot infer contextual base in reference to member
  'commaSeparatedText':** `TermReportCard.swift` is missing
  `import UniformTypeIdentifiers`.
- **Type 'Grade' does not conform to protocol 'ReportGrade':** the
  `extension Grade: ReportGrade` in 4.3 needs its `kindName` property.
- **Cannot find type 'TermReport' in scope:** 4.3 isn't in yet, or
  `TermReport` ended up inside `extension Store { }`. It's a struct of its
  own, at the top level of the file.
- **The share sheet opens but has no Save to Files, or the file has an odd
  name:** check that the closure returns `SentTransferredFile(url)` and the
  path ends in `classping-grades.csv`.
- **The count is stuck after midnight:** the countdown isn't inside
  `TimelineView(.everyMinute)`.
- **Save does nothing and a red line appears:** the phone couldn't write
  planner.json (the screen's top banner says so too). Free some storage and
  tap Save again; your old date is still saved.

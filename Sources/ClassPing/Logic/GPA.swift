//
// File: ~/ClassPing/Sources/ClassPing/Logic/GPA.swift
// Phase: 9a (grades and GPA), extended in 9b (scales, goals and what-if)
// Ports: lib/gpa.ts: averages, bands, credits and weight budgets (9a);
//        the custom-scale limits and checks, projected GPA and
//        "what do I need?" (9b).
// Summary: Foundation-only maths. Protocols let both the real models and
// small Linux test values supply the same fields without importing SwiftUI.
//
import Foundation

/// Only the numbers and relationship the calculation needs.
protocol GradedResult {
    var courseID: UUID? { get }
    var score: Double { get }
    var max: Double { get }
    var weight: Double { get }
}

protocol GradedCourse {
    var id: UUID { get }
    var credits: Double? { get }
}

// NEW in Phase 9b
/// A course that may carry a target percentage. It builds on GradedCourse,
/// the way Completable builds on Dated (6b), so anything with a goal also has
/// the id and credits the GPA needs. 9a's tests keep using GradedCourse alone.
protocol GoalCourse: GradedCourse {
    var goal: Double? { get }
}

/// Moved unchanged from Profile.swift: its saved JSON keys stay identical.
struct ScaleBand: Codable, Hashable, Sendable {
    var min: Double
    var letter: String
    var points: Double
}

let DEFAULT_SCALE: [ScaleBand] = [
    .init(min: 93, letter: "A", points: 4),
    .init(min: 90, letter: "A-", points: 3.7),
    .init(min: 87, letter: "B+", points: 3.3),
    .init(min: 83, letter: "B", points: 3),
    .init(min: 80, letter: "B-", points: 2.7),
    .init(min: 77, letter: "C+", points: 2.3),
    .init(min: 73, letter: "C", points: 2),
    .init(min: 70, letter: "C-", points: 1.7),
    .init(min: 67, letter: "D+", points: 1.3),
    .init(min: 63, letter: "D", points: 1),
    .init(min: 60, letter: "D-", points: 0.7),
]

let SIMPLE_SCALE: [ScaleBand] = [
    .init(min: 90, letter: "A", points: 4),
    .init(min: 80, letter: "B", points: 3),
    .init(min: 70, letter: "C", points: 2),
    .init(min: 60, letter: "D", points: 1),
]

// NEW in Phase 9b
/// A custom scale's limits, named once instead of repeated as bare numbers.
/// `MAX_SCALE_BANDS`, `MAX_GRADE_POINTS` and `MAX_LETTER_LENGTH` in lib/gpa.ts.
/// 10 points fits weighted (5.0) and out-of-10 systems; it catches typos.
let MAX_SCALE_BANDS = 16
let MAX_GRADE_POINTS = 10.0
let MAX_LETTER_LENGTH = 6

/// Empty is unknown, not zero. Weights need not add up to 100.
func classAverage<G: GradedResult>(_ grades: [G]) -> Double? {
    let valid = grades.filter { $0.max > 0 && $0.weight > 0 }
    guard !valid.isEmpty else { return nil }
    let total = valid.reduce(0) { $0 + $1.weight }
    return valid.reduce(0) { $0 + ($1.score / $1.max) * $1.weight } / total * 100
}

/// Highest threshold wins; a supplied zero band can name the fallback.
func letterFor(_ pct: Double, _ scale: [ScaleBand] = DEFAULT_SCALE) -> String {
    scale.sorted { $0.min > $1.min }.first { pct >= $0.min }?.letter ?? "F"
}

func pointsFor(_ pct: Double, _ scale: [ScaleBand] = DEFAULT_SCALE) -> Double {
    scale.sorted { $0.min > $1.min }.first { pct >= $0.min }?.points ?? 0
}

func creditsFor<C: GradedCourse>(_ course: C) -> Double {
    guard let credits = course.credits, credits > 0 else { return 1 }
    return credits
}

/// The caller supplies this term's courses, or one past term's courses.
func overallGpa<C: GradedCourse, G: GradedResult>(
    _ courses: [C], _ grades: [G], _ scale: [ScaleBand] = DEFAULT_SCALE
) -> Double? {
    var totalCredits = 0.0
    var totalPoints = 0.0
    for course in courses {
        if let average = classAverage(grades.filter { $0.courseID == course.id }) {
            let credits = creditsFor(course)
            totalCredits += credits
            totalPoints += pointsFor(average, scale) * credits
        }
    }
    return totalCredits == 0 ? nil : totalPoints / totalCredits
}

// NEW in Phase 9b
/// A course's goal when it counts as one: a number above zero. Missing, zero
/// and negative all mean "no goal", as `typeof c.goal === "number" &&
/// c.goal > 0` does on the web. One helper, so the projection and the Grades
/// screen can't disagree about it.
func goalOf<C: GoalCourse>(_ course: C) -> Double? {
    guard let goal = course.goal, goal > 0 else { return nil }
    return goal
}

// NEW in Phase 9b
/// Where the term ends if every goal is met. `projectedGpa` on the web.
/// A class with a goal counts at that goal, one without at its average so
/// far, so the number answers "where do I land if the plan holds?". Nil until
/// some class has a goal: with none it would only repeat the GPA above it.
func projectedGpa<C: GoalCourse, G: GradedResult>(
    _ courses: [C], _ grades: [G], _ scale: [ScaleBand] = DEFAULT_SCALE
) -> Double? {
    // `contains(where:)` asks "is there any?" with no loop to break out of.
    guard courses.contains(where: { goalOf($0) != nil }) else { return nil }
    var totalCredits = 0.0
    var totalPoints = 0.0
    for course in courses {
        // `??` picks the goal when there is one, otherwise the class average.
        // A class with neither (no goal, nothing graded) is left out.
        if let pct = goalOf(course) ?? classAverage(grades.filter { $0.courseID == course.id }) {
            let credits = creditsFor(course)
            totalCredits += credits
            totalPoints += pointsFor(pct, scale) * credits
        }
    }
    return totalCredits == 0 ? nil : totalPoints / totalCredits
}

func usedWeight<G: GradedResult>(_ grades: [G]) -> Double {
    grades.filter { $0.max > 0 && $0.weight > 0 }.reduce(0) { $0 + $1.weight }
}

func remainingWeight<G: GradedResult>(_ grades: [G]) -> Double {
    Swift.max(100 - usedWeight(grades), 0)
}

/// Extra credit is allowed; the hint catches accidental extra zeroes.
func extraCreditHint(_ score: Double, _ max: Double) -> String? {
    guard score.isFinite, max.isFinite, max > 0, score > max else { return nil }
    return "That's above full marks, logged as extra credit (\(String(format: "%.0f", score / max * 100))%)."
}

// NEW in Phase 9b
/// The answer to "what do I need on the rest?". `WhatIfResult` in lib/gpa.ts.
/// One value with four fields, so the screen gets the number and the two
/// verdicts together and can't work them out differently.
struct WhatIfResult: Equatable {
    /// The average the ungraded work must reach, in percent. Above 100 needs
    /// extra credit; zero or below means the goal is already safe.
    var needed: Double
    /// How much of the class's 100% is still to be graded.
    var remainingWeight: Double
    /// True when even a zero on everything left still reaches the target.
    var alreadySecured: Bool
    /// True when full marks on everything left isn't enough.
    var outOfReach: Bool
}

// NEW in Phase 9b
/// What the remaining work must average for the class to finish at
/// `target` percent. `whatIfNeeded` on the web. Weights are shares of 100:
/// logged grades worth 70 leave 30. Nil when nothing is left (100 used),
/// and also when the weights add up to more than 100, which the Grades
/// screen tells apart with usedWeight.
func whatIfNeeded<G: GradedResult>(_ grades: [G], _ target: Double) -> WhatIfResult? {
    let valid = grades.filter { $0.max > 0 && $0.weight > 0 }
    let left = 100 - valid.reduce(0) { $0 + $1.weight }
    guard left > 0 else { return nil }
    // Points already banked, measured against a 100-weight total.
    let earned = valid.reduce(0) { $0 + ($1.score / $1.max) * $1.weight }
    // Same operation order as the web, so the same inputs give the same bits.
    let needed = (target - earned) / left * 100
    return WhatIfResult(needed: needed, remainingWeight: left,
                        alreadySecured: needed <= 0, outOfReach: needed > 100)
}

// NEW in Phase 9b
/// The first six UTF-16 units of a letter, as JavaScript's `slice(0, 6)`
/// counts them. Shared by normalizeScale and the editor's Grade field.
func letterPrefix(_ text: String) -> String {
    String(decoding: Array(text.utf16.prefix(MAX_LETTER_LENGTH)), as: UTF16.self)
}

/// This typed boundary consumes existing Codable bands. Decoding unknown
/// network data belongs to sync. Since 9b the editor's rows come through here
/// too, after Logic/ScaleDraft.swift turns their text into numbers.
func normalizeScale(_ raw: [ScaleBand]) -> [ScaleBand]? {
    var out: [ScaleBand] = []
    var seen: Set<String> = []
    // CHANGED in Phase 9b: the limits use the named constants.
    for band in raw where out.count < MAX_SCALE_BANDS {
        let trimmed = band.letter.trimmingCharacters(in: .whitespacesAndNewlines)
        let letter = letterPrefix(trimmed)
        let key = letter.lowercased()
        if !letter.isEmpty, !seen.contains(key),
           band.min.isFinite, (0...100).contains(band.min),
           band.points.isFinite, (0...MAX_GRADE_POINTS).contains(band.points) {
            seen.insert(key)
            out.append(ScaleBand(min: (band.min * 10).rounded() / 10,
                                 letter: letter, points: (band.points * 100).rounded() / 100))
        }
    }
    return out.isEmpty ? nil : out.sorted { $0.min > $1.min }
}

// NEW in Phase 9b
/// What's wrong with a scale being edited, in words you can act on, or an
/// empty list when nothing is. `scaleIssues` on the web. It reads the draft,
/// not the normalized result, because its job is to name the rows
/// normalizeScale would quietly drop.
func scaleIssues(_ draft: [ScaleBand]) -> [String] {
    var issues: [String] = []
    // Counts kept in first-seen order, so the messages come out in the web's
    // order. (A JavaScript Map remembers insertion order; a Dictionary doesn't.)
    var letters: [(key: String, count: Int)] = []
    var mins: [(value: Double, count: Int)] = []

    for (index, band) in draft.enumerated() {
        let row = index + 1
        let letter = band.letter.trimmingCharacters(in: .whitespacesAndNewlines)
        if letter.isEmpty { issues.append("Row \(row) has no letter.") }

        // A usable minimum is also counted, to spot two bands at one start.
        if !band.min.isFinite || band.min < 0 || band.min > 100 {
            issues.append("Row \(row): the minimum must be between 0 and 100.")
        } else if let i = mins.firstIndex(where: { $0.value == band.min }) {
            mins[i].count += 1
        } else {
            mins.append((value: band.min, count: 1))
        }

        if !band.points.isFinite || band.points < 0 || band.points > MAX_GRADE_POINTS {
            issues.append("Row \(row): points must be between 0 and \(Int(MAX_GRADE_POINTS)).")
        }

        // Letters compare without case: "A" and "a" are the same grade.
        if !letter.isEmpty {
            let key = letter.lowercased()
            if let i = letters.firstIndex(where: { $0.key == key }) {
                letters[i].count += 1
            } else {
                letters.append((key: key, count: 1))
            }
        }
    }

    // `for ... where` visits only the entries that pass the test.
    for entry in letters where entry.count > 1 {
        issues.append("\"\(entry.key.uppercased())\" appears more than once.")
    }
    for entry in mins where entry.count > 1 {
        issues.append("Two bands both start at \(entry.value.formatted())%, only the first will ever match.")
    }
    if draft.count > MAX_SCALE_BANDS {
        issues.append("A scale can hold at most \(MAX_SCALE_BANDS) bands.")
    }
    return issues
}

/// Read custom bands already saved in a profile without silently replacing them.
func resolveScale(_ name: String?, custom: [ScaleBand] = []) -> [ScaleBand] {
    if name == "custom" { return normalizeScale(custom) ?? DEFAULT_SCALE }
    return name == "simple" ? SIMPLE_SCALE : DEFAULT_SCALE
}

// NEW in Phase 9b
/// True when Custom is chosen but none of its bands are usable yet, so the
/// standard scale is standing in. `customScaleIsEmpty` on the web.
func customScaleIsEmpty(_ name: String?, custom: [ScaleBand]) -> Bool {
    name == "custom" && normalizeScale(custom) == nil
}

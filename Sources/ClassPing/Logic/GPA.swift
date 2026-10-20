//
// File: ~/ClassPing/Sources/ClassPing/Logic/GPA.swift
// Phase: 9a (grades and GPA)
// Ports: lib/gpa.ts (averages, bands, credits and weight budgets).
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

/// This typed boundary consumes existing Codable bands. Decoding unknown
/// network data belongs to sync; the custom editor arrives in 9b.
func normalizeScale(_ raw: [ScaleBand]) -> [ScaleBand]? {
    var out: [ScaleBand] = []
    var seen: Set<String> = []
    for band in raw where out.count < 16 {
        let trimmed = band.letter.trimmingCharacters(in: .whitespacesAndNewlines)
        // The web caps letters by UTF-16 units, as JavaScript slice does.
        let letter = String(decoding: Array(trimmed.utf16.prefix(6)), as: UTF16.self)
        let key = letter.lowercased()
        if !letter.isEmpty, !seen.contains(key),
           band.min.isFinite, (0...100).contains(band.min),
           band.points.isFinite, (0...10).contains(band.points) {
            seen.insert(key)
            out.append(ScaleBand(min: (band.min * 10).rounded() / 10,
                                 letter: letter, points: (band.points * 100).rounded() / 100))
        }
    }
    return out.isEmpty ? nil : out.sorted { $0.min > $1.min }
}

/// Read custom bands already saved in a profile without silently replacing them.
func resolveScale(_ name: String?, custom: [ScaleBand] = []) -> [ScaleBand] {
    if name == "custom" { return normalizeScale(custom) ?? DEFAULT_SCALE }
    return name == "simple" ? SIMPLE_SCALE : DEFAULT_SCALE
}

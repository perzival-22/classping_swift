// Phase 9a twins of lib/gpa.test.ts for the functions with a caller now.
// Projection, what-if and editor diagnostics arrive with 9b.
import Foundation
import Testing
@testable import CPLogic

private struct Result: GradedResult {
    var courseID: UUID? = nil
    var score = 90.0
    var max = 100.0
    var weight = 100.0
}

private struct Subject: GradedCourse {
    var id = UUID()
    var credits: Double? = nil
}

@Suite struct GPATests {
    @Test func noUsableGradesMeansUnknown() {
        #expect(classAverage([Result]()) == nil)
        #expect(classAverage([Result(max: 0)]) == nil)
        #expect(classAverage([Result(weight: 0)]) == nil)
    }

    @Test func declaredWeightsDriveTheAverage() {
        #expect(classAverage([Result(score: 10, max: 10, weight: 30),
                              Result(score: 5, max: 10, weight: 70)]) == 65)
    }

    @Test func weightsNeedNotTotalOneHundred() {
        #expect(classAverage([Result(score: 100, weight: 5),
                              Result(score: 80, weight: 5)]) == 90)
    }

    @Test func ignoresUnusableEntriesButKeepsTheRest() {
        #expect(classAverage([Result(score: 100, weight: 50),
                              Result(score: 1, max: 0, weight: 50)]) == 100)
    }

    @Test func extraCreditSurvivesTheAverage() {
        #expect(abs((classAverage([Result(score: 110)]) ?? 0) - 110) < 1e-10)
    }

    @Test(arguments: [
        (100.0, "A"), (93, "A"), (92.9, "A-"), (90, "A-"),
        (89.9, "B+"), (60, "D-"), (59.9, "F"), (0, "F"),
    ])
    func exactLetterBoundaries(pct: Double, letter: String) {
        #expect(letterFor(pct) == letter)
    }

    @Test func pointsMatchTheWeb() {
        #expect(pointsFor(95) == 4)
        #expect(pointsFor(90) == 3.7)
        #expect(pointsFor(59) == 0)
    }

    @Test func noGpaUntilAListedClassIsGraded() {
        #expect(overallGpa([Subject()], [Result]()) == nil)
        #expect(overallGpa([Subject](), [Result()]) == nil)
    }

    @Test func onlyGradedClassesContribute() {
        let a = Subject(), b = Subject(), c = Subject()
        #expect(overallGpa([a, b, c], [Result(courseID: a.id, score: 95),
                                     Result(courseID: b.id, score: 85)]) == 3.5)
    }

    @Test func unlistedAndUnassignedGradesDoNotCount() {
        let a = Subject()
        #expect(overallGpa([a], [Result(courseID: a.id, score: 95),
                                Result(courseID: UUID(), score: 10),
                                Result(courseID: nil, score: 0)]) == 4)
    }

    @Test func creditHoursWeightTheGpa() {
        let a = Subject(credits: 4), b = Subject(credits: 1)
        #expect(overallGpa([a, b], [Result(courseID: a.id, score: 95),
                                  Result(courseID: b.id, score: 85)]) == 3.8)
    }

    @Test func missingZeroAndNegativeCreditsCountOnce() {
        #expect(creditsFor(Subject()) == 1)
        #expect(creditsFor(Subject(credits: 0)) == 1)
        #expect(creditsFor(Subject(credits: -3)) == 1)
    }

    @Test func alternateScaleChangesTheResult() {
        let a = Subject()
        #expect(letterFor(90, SIMPLE_SCALE) == "A")
        #expect(pointsFor(90, SIMPLE_SCALE) == 4)
        #expect(overallGpa([a], [Result(courseID: a.id)], SIMPLE_SCALE) == 4)
    }

    @Test func emptyWeightBudgetStartsAtOneHundred() {
        #expect(usedWeight([Result]()) == 0)
        #expect(remainingWeight([Result]()) == 100)
    }

    @Test func weightBudgetIgnoresUnusableResults() {
        #expect(usedWeight([Result(weight: 20), Result(weight: 30)]) == 50)
        let values = [Result(weight: 40), Result(max: 0, weight: 30), Result(weight: 0)]
        #expect(usedWeight(values) == 40)
        #expect(remainingWeight(values) == 60)
    }

    @Test func overAllocationNeverHasNegativeRemainingWeight() {
        let values = Array(repeating: Result(weight: 20), count: 6)
        #expect(usedWeight(values) == 120)
        #expect(remainingWeight(values) == 0)
        #expect(remainingWeight(Array(values.prefix(5))) == 0)
        #expect(remainingWeight(Array(values.prefix(4))) == 20)
    }

    @Test func extraCreditHintMatchesTheWeb() {
        for score in [0.0, 90, 100] { #expect(extraCreditHint(score, 100) == nil) }
        #expect(extraCreditHint(110, 100)?.contains("extra credit (110%)") == true)
        #expect(extraCreditHint(.nan, 100) == nil)
        #expect(extraCreditHint(50, .nan) == nil)
        #expect(extraCreditHint(50, 0) == nil)
    }

    @Test func customBandsSortAndDropOnlyBadRows() {
        let raw = [ScaleBand(min: 50, letter: "C", points: 2),
                   ScaleBand(min: 70, letter: "A", points: 4),
                   ScaleBand(min: 60, letter: "", points: 3),
                   ScaleBand(min: 200, letter: "D", points: 2),
                   ScaleBand(min: 40, letter: "E", points: 99)]
        #expect(normalizeScale(raw)?.map(\.letter) == ["A", "C"])
        #expect(normalizeScale([]) == nil)
        #expect(normalizeScale([.init(min: 1, letter: "", points: 1)]) == nil)
    }

    @Test func customLettersAreTrimmedAndDeduplicated() {
        let raw = [ScaleBand(min: 70, letter: " A ", points: 4),
                   ScaleBand(min: 65, letter: "a", points: 3.7)]
        #expect(normalizeScale(raw) == [.init(min: 70, letter: "A", points: 4)])
    }

    @Test func customScaleCapsBandsAndAllowsTenPoints() {
        let many = (0..<21).map { ScaleBand(min: Double(100 - $0), letter: "L\($0)", points: 4) }
        #expect(normalizeScale(many)?.count == 16)
        #expect(normalizeScale([.init(min: 90, letter: "A*", points: 5)])?.first?.points == 5)
        #expect(normalizeScale([.init(min: 90, letter: "A", points: 10)]) != nil)
        #expect(normalizeScale([.init(min: 90, letter: "A", points: 10.5)]) == nil)
    }

    @Test func resolvingExistingProfilesPreservesCustomBands() {
        #expect(resolveScale(nil) == DEFAULT_SCALE)
        #expect(resolveScale("standard") == DEFAULT_SCALE)
        #expect(resolveScale("simple") == SIMPLE_SCALE)
        #expect(resolveScale("custom") == DEFAULT_SCALE)
        let bands = resolveScale("custom", custom: [.init(min: 70, letter: "First", points: 4),
                                                    .init(min: 60, letter: "2:1", points: 3)])
        #expect(letterFor(72, bands) == "First")
        #expect(letterFor(64, bands) == "2:1")
        #expect(pointsFor(64, bands) == 3)
    }

    @Test func unorderedScalesAndExplicitBottomBandWork() {
        let bands = [ScaleBand(min: 0, letter: "Fail", points: 0),
                     ScaleBand(min: 70, letter: "Pass", points: 4)]
        #expect(letterFor(80, bands) == "Pass")
        #expect(letterFor(20, bands) == "Fail")
        #expect(pointsFor(80, bands) == 4)
    }

    @Test func movedScaleBandStillDecodesExistingProfileShape() {
        let json = Data(#"{"min":93,"letter":"A","points":4}"#.utf8)
        #expect((try? JSONDecoder().decode(ScaleBand.self, from: json)) == DEFAULT_SCALE[0])
    }
}

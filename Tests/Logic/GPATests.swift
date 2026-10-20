// GPATests.swift: the Swift twins of lib/gpa.test.ts. Phase 9a ported the
// averages, bands, credits, budgets and reading saved scales; 9b adds the
// projection, what-if, scaleIssues, customScaleIsEmpty and the custom-scale
// GPA. Cases marked "web:" are lib/gpa.ts's own output (node 22, 2026-10-20).
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

/// A course with a goal, for the 9b projection tests.
private struct Aim: GoalCourse {
    var id = UUID()
    var credits: Double? = nil
    var goal: Double? = nil
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

    // MARK: - Phase 9b: projectedGpa

    @Test func noProjectionUntilAClassHasAGoal() {
        let a = Aim()
        #expect(projectedGpa([a], [Result(courseID: a.id)]) == nil)
        #expect(projectedGpa([Aim](), [Result]()) == nil)
    }

    @Test func aGoalOutranksTheCurrentAverage() {
        // A C (75%) now, aiming for an A: the projection believes the goal.
        let a = Aim(goal: 95)
        #expect(projectedGpa([a], [Result(courseID: a.id, score: 75)]) == 4)
    }

    @Test func classesWithoutAGoalCountAtTheirAverage() {
        let a = Aim(goal: 95), b = Aim()
        #expect(projectedGpa([a, b], [Result(courseID: a.id, score: 60),
                                    Result(courseID: b.id, score: 85)]) == 3.5)
    }

    @Test func aGoalCountsBeforeAnyGrades() {
        #expect(projectedGpa([Aim(goal: 85)], [Result]()) == 3)
    }

    @Test func projectionIsCreditWeighted() {
        // (4.0 x 4 + 3.0 x 1) / 5 = 3.8
        #expect(projectedGpa([Aim(credits: 4, goal: 95), Aim(credits: 1, goal: 85)],
                             [Result]()) == 3.8)
    }

    @Test func zeroNegativeAndMissingGoalsAreNoGoal() {
        let zero = Aim(goal: 0), negative = Aim(goal: -5)
        #expect(projectedGpa([zero], [Result(courseID: zero.id)]) == nil)
        #expect(projectedGpa([negative], [Result(courseID: negative.id)]) == nil)
        #expect(goalOf(Aim(goal: .nan)) == nil)
        #expect(goalOf(Aim(goal: 90)) == 90)
    }

    @Test func projectionHonoursTheScale() {
        // 90% is an A- (3.7) on the standard scale, a flat A (4.0) on simple.
        #expect(projectedGpa([Aim(goal: 90)], [Result](), SIMPLE_SCALE) == 4)
        #expect(projectedGpa([Aim(goal: 90)], [Result]()) == 3.7)
    }

    // MARK: - Phase 9b: whatIfNeeded

    @Test func nothingLeftToGradeHasNoAnswer() {
        #expect(whatIfNeeded([Result(weight: 100)], 90) == nil)
        // The usedWeight/remainingWeight boundary cases agree with it.
        let six = Array(repeating: Result(weight: 20), count: 6)
        #expect(whatIfNeeded(six, 90) == nil)
        #expect(whatIfNeeded(Array(six.prefix(5)), 90) == nil)
        #expect(whatIfNeeded(Array(six.prefix(4)), 90)?.remainingWeight == 20)
    }

    @Test func neededScoreOnTheRemainingWeight() {
        // 80% on 50 weight banks 40 points; finishing at 90 needs 100% on the rest.
        let result = whatIfNeeded([Result(score: 80, weight: 50)], 90)
        #expect(result == WhatIfResult(needed: 100, remainingWeight: 50,
                                       alreadySecured: false, outOfReach: false))
    }

    @Test func alreadySecuredAndOutOfReach() {
        let safe = whatIfNeeded([Result(score: 100, weight: 80)], 70)
        #expect(safe?.alreadySecured == true)
        #expect((safe?.needed ?? 1) <= 0)
        let far = whatIfNeeded([Result(score: 20, weight: 90)], 90)
        #expect(far?.outOfReach == true)
        #expect((far?.needed ?? 0) > 100)
    }

    @Test func whatIfIgnoresUnusableGrades() {
        let result = whatIfNeeded([Result(score: 90, weight: 40),
                                   Result(score: 1, max: 0, weight: 30)], 90)
        #expect(result?.remainingWeight == 60)
    }

    @Test func whatIfKeepsTheWebsOperationOrder() {
        // web: 2/3 at weight 30, target 90 -> needed exactly 100, not out of reach.
        let result = whatIfNeeded([Result(score: 2, max: 3, weight: 30)], 90)
        #expect(result == WhatIfResult(needed: 100, remainingWeight: 70,
                                       alreadySecured: false, outOfReach: false))
    }

    // MARK: - Phase 9b: scaleIssues and customScaleIsEmpty

    @Test func aSoundScaleHasNoIssues() {
        #expect(scaleIssues([.init(min: 70, letter: "A", points: 4),
                             .init(min: 60, letter: "B", points: 3)]).isEmpty)
    }

    @Test func issuesNameTheRow() {
        let issues = scaleIssues([.init(min: 70, letter: "A", points: 4),
                                  .init(min: 60, letter: "", points: 3)])
        #expect(issues.contains("Row 2 has no letter."))
    }

    @Test func duplicateLettersAndShadowedBands() {
        let twice = scaleIssues([.init(min: 70, letter: "A", points: 4),
                                 .init(min: 60, letter: "A", points: 3)])
        #expect(twice.contains { $0.contains("more than once") })
        let shadowed = scaleIssues([.init(min: 70, letter: "A", points: 4),
                                    .init(min: 70, letter: "B", points: 3)])
        #expect(shadowed.contains { $0.contains("only the first will ever match") })
    }

    @Test func outOfRangeMinimumAndPoints() {
        #expect(scaleIssues([.init(min: 120, letter: "A", points: 4)]).first?
            .contains("between 0 and 100") == true)
        #expect(scaleIssues([.init(min: 90, letter: "A", points: 40)]).first?
            .contains("points must be") == true)
    }

    @Test func issuesMatchTheWebWordForWordAndInOrder() {
        // web: fromDraft of A/70/4, blank, a/70.5/11, " B "/abc/3, b/70.5/2, C/70/-1.
        // Number("") is 0 there, so the blank row's minimum counts as 0.
        let draft = [ScaleBand(min: 70, letter: "A", points: 4),
                     ScaleBand(min: 0, letter: "", points: 0),
                     ScaleBand(min: 70.5, letter: "a", points: 11),
                     ScaleBand(min: .nan, letter: " B ", points: 3),
                     ScaleBand(min: 70.5, letter: "b", points: 2),
                     ScaleBand(min: 70, letter: "C", points: -1)]
        #expect(scaleIssues(draft) == [
            "Row 2 has no letter.",
            "Row 3: points must be between 0 and 10.",
            "Row 4: the minimum must be between 0 and 100.",
            "Row 6: points must be between 0 and 10.",
            "\"A\" appears more than once.",
            "\"B\" appears more than once.",
            "Two bands both start at 70%, only the first will ever match.",
            "Two bands both start at 70.5%, only the first will ever match.",
        ])
    }

    @Test func tooManyBandsIsAnIssue() {
        let many = (0..<17).map { ScaleBand(min: Double(100 - $0), letter: "L\($0)", points: 4) }
        #expect(scaleIssues(many).last == "A scale can hold at most 16 bands.")
        #expect(scaleIssues(Array(many.prefix(16))).isEmpty)
    }

    @Test func knowsWhenACustomScaleIsStillEmpty() {
        let bands = [ScaleBand(min: 70, letter: "First", points: 4)]
        #expect(customScaleIsEmpty("custom", custom: []))
        #expect(!customScaleIsEmpty("custom", custom: bands))
        #expect(!customScaleIsEmpty("standard", custom: []))
        #expect(customScaleIsEmpty("custom", custom: [.init(min: 70, letter: " ", points: 4)]))
    }

    @Test func gpaUsesTheStudentsOwnPoints() {
        let scale = resolveScale("custom", custom: [.init(min: 70, letter: "First", points: 4),
                                                    .init(min: 60, letter: "2:1", points: 3),
                                                    .init(min: 50, letter: "2:2", points: 2),
                                                    .init(min: 40, letter: "Third", points: 1)])
        let a = Subject(credits: 3), b = Subject(credits: 1)
        // (4 x 3 + 2 x 1) / 4 = 3.5
        #expect(overallGpa([a, b], [Result(courseID: a.id, score: 72),
                                  Result(courseID: b.id, score: 52)], scale) == 3.5)
        #expect(letterFor(12, scale) == "F")
    }

    @Test func letterPrefixCountsLikeJavaScript() {
        #expect(letterPrefix("Distinction") == "Distin")
        #expect(letterPrefix("A+") == "A+")
        // An emoji is two UTF-16 units, as in JavaScript.
        #expect(letterPrefix("😀😀😀😀").utf16.count <= 6)
    }
}

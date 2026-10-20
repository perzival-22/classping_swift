// Phase 9a, extended in 9b (scale choice, custom bands and goals): use an
// isolated Documents path, never the real planner file.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct GradeStoreTests {
    private func fresh() -> (Store, Course) {
        try? FileManager.default.removeItem(at: Store.fileURL)
        let store = Store()
        let course = Course(name: "Biology", short: "Bio", color: .teal,
                            days: [0], startMin: 600, endMin: 660)
        store.addCourse(course)
        return (store, course)
    }

    private func result(_ course: Course) -> Grade {
        Grade(courseID: course.id, title: "  Midterm  ", score: 105,
              max: 100, weight: 20, date: "2026-10-19", kind: .exam)
    }

    @Test func addEditAndReloadPreserveExtraCreditAndIdentity() {
        let (store, course) = fresh()
        var value = result(course)
        #expect(store.addGrade(value))
        #expect(Store.load().grade(value.id)?.title == "Midterm")
        #expect(Store.load().grade(value.id)?.score == 105)
        value.title = "Final"; value.score = 93; value.kind = nil
        #expect(store.updateGrade(value))
        let loaded = Store.load()
        #expect(loaded.liveGrades.count == 1)
        #expect(loaded.grade(value.id)?.title == "Final")
        #expect(loaded.grade(value.id)?.kind == nil)
        #expect(loaded.grade(value.id)?.date == "2026-10-19")
    }

    @Test func duplicateIdsAndDeletedTargetsAreRefused() {
        let (store, course) = fresh()
        let value = result(course)
        #expect(store.addGrade(value))
        #expect(!store.addGrade(value))
        #expect(store.deleteGrade(value.id))
        #expect(!store.updateGrade(value))
        #expect(!store.addGrade(value))
        #expect(store.grades.count == 1)
    }

    @Test func invalidFieldsCannotReachThePlanner() {
        let (store, course) = fresh()
        let good = result(course)
        var bad = good; bad.courseID = nil; #expect(!store.addGrade(bad))
        bad = good; bad.courseID = UUID(); #expect(!store.addGrade(bad))
        bad = good; bad.title = " "; #expect(!store.addGrade(bad))
        bad = good; bad.score = .nan; #expect(!store.addGrade(bad))
        bad = good; bad.score = -1; #expect(!store.addGrade(bad))
        bad = good; bad.max = 0; #expect(!store.addGrade(bad))
        bad = good; bad.max = .infinity; #expect(!store.addGrade(bad))
        bad = good; bad.weight = 0; #expect(!store.addGrade(bad))
        bad = good; bad.weight = 101; #expect(!store.addGrade(bad))
        bad = good; bad.date = "2026-02-31"; #expect(!store.addGrade(bad))
        #expect(Store.load().grades.isEmpty)
    }

    @Test func deletionAndUndoSurviveReloadWithoutChangingTheGrade() {
        let (store, course) = fresh()
        let value = result(course)
        store.addGrade(value)
        let saved = store.grade(value.id)
        #expect(store.deleteGrade(value.id))
        #expect(store.grade(value.id) == nil)
        #expect(Store.load().grades.first?.deletedAt != nil)
        #expect(store.pendingUndo?.item == .grade(value.id))
        store.undoDelete()
        #expect(Store.load().grade(value.id) == saved)
    }

    @Test func aDeletedClassCannotReceiveNewGradesAndItsUndoIsExact() {
        let (store, course) = fresh()
        let old = result(course)
        store.addGrade(old)
        store.deleteGrade(old.id)
        let live = result(course)
        store.addGrade(live)
        store.deleteCourse(course.id)
        #expect(!store.addGrade(result(course)))
        #expect(!store.updateGrade(live))
        store.undoDelete()
        #expect(store.grade(old.id) == nil)
        #expect(store.grade(live.id) != nil)
    }

    @Test func sameDayOrderingAndTermsRemainSeparate() {
        let (store, course) = fresh()
        var past = course; past.id = UUID(); past.archived = true; past.term = " Fall 2025 "
        store.addCourse(past)
        let first = result(course), second = result(course)
        var newer = result(course); newer.date = "2026-10-20"
        var pastGrade = result(past); pastGrade.score = 0
        for value in [first, second, newer, pastGrade] { store.addGrade(value) }
        #expect(store.grades(for: course.id).map(\.id) == [newer.id, first.id, second.id])
        #expect(overallGpa(store.activeCourses, store.liveGrades) == 4)
        #expect(store.gradedPastTerms == ["Fall 2025"])
        #expect(overallGpa(store.gradedCourses(in: "Fall 2025"), store.liveGrades) == 0)
    }

    @Test func editCanMoveAResultWithoutCountingItsWeightTwice() {
        let (store, course) = fresh()
        var next = course; next.id = UUID(); store.addCourse(next)
        var value = result(course)
        store.addGrade(value)
        value.courseID = next.id
        #expect(store.updateGrade(value))
        #expect(store.grades(for: course.id).isEmpty)
        #expect(usedWeight(store.grades(for: next.id)) == 20)
    }

    @Test func overAllocatedClassStillAcceptsValidIndividualWeights() {
        let (store, course) = fresh()
        for _ in 0..<6 { #expect(store.addGrade(result(course))) }
        #expect(usedWeight(store.liveGrades) == 120)
        #expect(remainingWeight(store.liveGrades) == 0)
    }

    /// Turn the file path into a directory so an atomic file write fails.
    private func blockWrites() -> Bool {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return (try? FileManager.default.createDirectory(at: Store.fileURL,
                                                         withIntermediateDirectories: false)) != nil
    }

    @Test func failedAddRetainsNoPhantomAndRetryWritesExactlyOnce() {
        let (store, course) = fresh()
        let value = result(course)
        let blocked = blockWrites(); #expect(blocked); guard blocked else { return }
        #expect(!store.addGrade(value))
        #expect(store.lastSaveFailed)
        #expect(store.grades.isEmpty)
        try? FileManager.default.removeItem(at: Store.fileURL)
        #expect(store.addGrade(value))
        #expect(Store.load().grades.count == 1)
    }

    @Test func failedEditAndDeleteKeepTheOriginalAndPreviousUndo() {
        let (store, course) = fresh()
        var value = result(course)
        store.addGrade(value)
        let before = store.grade(value.id)
        let previous = PendingUndo(item: .note(UUID()), label: "Previous", at: .now)
        store.pendingUndo = previous
        let blocked = blockWrites(); #expect(blocked); guard blocked else { return }
        value.score = 40
        #expect(!store.updateGrade(value))
        #expect(store.grade(value.id) == before)
        #expect(!store.deleteGrade(value.id))
        #expect(store.grade(value.id) == before)
        #expect(store.pendingUndo == previous)
        try? FileManager.default.removeItem(at: Store.fileURL)
        #expect(store.updateGrade(value))
        #expect(Store.load().grade(value.id)?.score == 40)
    }

    @Test func existingCustomScaleSurvivesAPlannerRoundTrip() {
        let (store, _) = fresh()
        store.profile.gradeScale = .custom
        store.profile.customScale = [.init(min: 70, letter: "First", points: 5)]
        store.save()
        #expect(Store.load().gradeScale == store.profile.customScale)
    }

    // MARK: - Phase 9b: scales and goals

    @Test func scaleChoiceAndCustomBandsSurviveAReload() {
        let (store, _) = fresh()
        #expect(store.setGradeScale(.custom))
        // Unsorted, with one row normalizeScale must drop (no letter).
        #expect(store.setCustomScale([.init(min: 60, letter: " 2:1 ", points: 3),
                                      .init(min: 50, letter: "", points: 2),
                                      .init(min: 70, letter: "First", points: 4)]))
        let loaded = Store.load()
        #expect(loaded.profile.gradeScale == .custom)
        #expect(loaded.profile.customScale == [.init(min: 70, letter: "First", points: 4),
                                               .init(min: 60, letter: "2:1", points: 3)])
        #expect(letterFor(64, loaded.gradeScale) == "2:1")
        #expect(!loaded.usesFallbackScale)
        #expect(store.setGradeScale(.simple))
        #expect(Store.load().gradeScale == SIMPLE_SCALE)
    }

    @Test func nothingUsableSavesAnEmptyScaleAndFallsBack() {
        let (store, _) = fresh()
        store.setGradeScale(.custom)
        #expect(store.setCustomScale([.init(min: 50, letter: "", points: 2),
                                      .init(min: 200, letter: "X", points: 2)]))
        let loaded = Store.load()
        #expect(loaded.profile.customScale.isEmpty)
        #expect(loaded.usesFallbackScale)
        #expect(loaded.gradeScale == DEFAULT_SCALE)
    }

    @Test func goalsSaveClearAndFeedTheProjection() {
        let (store, course) = fresh()
        var value = result(course); value.score = 60; value.weight = 50
        store.addGrade(value)
        #expect(projectedGpa(store.activeCourses, store.liveGrades) == nil)
        #expect(store.setGoal(95, for: course.id))
        #expect(Store.load().course(course.id)?.goal == 95)
        #expect(projectedGpa(store.activeCourses, store.liveGrades) == 4)
        // 60% on 50 banks 30 points; 95 needs 130% on the remaining 50.
        #expect(whatIfNeeded(store.grades(for: course.id), 95)?.outOfReach == true)
        #expect(store.setGoal(nil, for: course.id))
        #expect(Store.load().course(course.id)?.goal == nil)
        #expect(store.setGoal(0, for: course.id))
        #expect(store.course(course.id)?.goal == nil)
    }

    @Test func impossibleGoalsAndMissingClassesAreRefused() {
        let (store, course) = fresh()
        #expect(store.setGoal(90, for: course.id))
        #expect(!store.setGoal(150, for: course.id))
        #expect(!store.setGoal(.nan, for: course.id))
        #expect(!store.setGoal(.infinity, for: course.id))
        #expect(!store.setGoal(90, for: UUID()))
        #expect(store.course(course.id)?.goal == 90)
        store.deleteCourse(course.id)
        #expect(!store.setGoal(80, for: course.id))
    }

    @Test func failedScaleAndGoalWritesPutTheOldValuesBack() {
        let (store, course) = fresh()
        store.setGoal(90, for: course.id)
        let bands = [ScaleBand(min: 70, letter: "First", points: 4)]
        store.setCustomScale(bands)
        let blocked = blockWrites(); #expect(blocked); guard blocked else { return }
        #expect(!store.setGradeScale(.simple))
        #expect(store.profile.gradeScale == nil)
        #expect(!store.setCustomScale([.init(min: 50, letter: "Pass", points: 1)]))
        #expect(store.profile.customScale == bands)
        #expect(!store.setGoal(80, for: course.id))
        #expect(store.course(course.id)?.goal == 90)
        // The same bands again still retry while the last write had failed.
        #expect(!store.setCustomScale(bands))
        try? FileManager.default.removeItem(at: Store.fileURL)
        #expect(store.setGoal(80, for: course.id))
        #expect(Store.load().course(course.id)?.goal == 80)
        #expect(Store.load().profile.customScale == bands)
    }

    @Test func unchangedBandsSkipTheWrite() {
        let (store, _) = fresh()
        let bands = [ScaleBand(min: 70, letter: "First", points: 4)]
        #expect(store.setCustomScale(bands))
        // With writes blocked, only a call that skips the write can succeed.
        let blocked = blockWrites(); #expect(blocked); guard blocked else { return }
        #expect(store.setCustomScale([.init(min: 70, letter: " First", points: 4)]))
        #expect(!store.lastSaveFailed)
        try? FileManager.default.removeItem(at: Store.fileURL)
    }
}

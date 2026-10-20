//
// File: ~/ClassPing/Sources/ClassPing/Store+Grades.swift
// Phase: 9a, extended in 9b
// Ports: lib/store.tsx (grade actions, and the gradeScale, customScale and
//        goal writes) and app/grades' filtering.
// Summary: Grade CRUD, validation and the bridge to the pure GPA functions.
//          Since 9b also the scale choice, the custom bands and class goals,
//          each saved only once planner.json has it.
//
import Foundation

// These models already have every field the maths asks for.
extension Grade: GradedResult {}
extension Course: GradedCourse {}
// NEW in Phase 9b: Course already has `goal`, so signing up is one line.
extension Course: GoalCourse {}

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
}

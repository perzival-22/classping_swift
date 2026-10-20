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

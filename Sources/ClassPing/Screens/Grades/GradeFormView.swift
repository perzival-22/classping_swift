//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift
// Phase: 9a, changed in 9b (D-54) and 9b+ (the class sheet)
// Ports: app/grades/new, app/grades/[id]/edit and components/GradeFields.
// Summary: One sheet for adding and editing. A failed save keeps the draft.
// Since 9b the fields wear your accent, and the keyboard can be swiped away
// or put down with Done, so Save & add another is never stuck under it.
//
import SwiftUI

struct GradeFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let editing: Grade?
    @State private var draftID: UUID
    @State private var courseID: UUID?
    @State private var title: String
    @State private var kind: Grade.Kind?
    @State private var score: String
    @State private var maximum: String
    @State private var weight: String
    @State private var date: Date
    @State private var message: String? = nil
    @State private var addedCount = 0
    @State private var showCourseForm = false

    // NEW in Phase 9b: which field has the keyboard, so Done can put it away
    // and Return on the title can move on to the score. `@FocusState` (6a).
    private enum Field { case title, score, maximum, weight }
    @FocusState private var focus: Field?

    /// State is seeded once per sheet, never overwritten by a store redraw.
    init(editing: Grade? = nil, courseID: UUID? = nil) {
        self.editing = editing
        _draftID = State(initialValue: editing?.id ?? UUID())
        _courseID = State(initialValue: editing?.courseID ?? courseID)
        _title = State(initialValue: editing?.title ?? "")
        _kind = State(initialValue: editing == nil ? .assignment : editing?.kind)
        _score = State(initialValue: editing.map { String($0.score) } ?? "")
        _maximum = State(initialValue: editing.map { String($0.max) } ?? "100")
        _weight = State(initialValue: editing.map { String($0.weight) } ?? "20")
        _date = State(initialValue: editing.flatMap {
            deadlineDayStart(Deadline(date: $0.date, time: nil))
        } ?? .now)
    }

    /// Match Number("") == 0 on the web. Decimal commas follow the device locale.
    private func number(_ text: String) -> Double {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        return Double(value.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".",
                                                 with: ".")) ?? .nan
    }

    private var draft: Grade {
        Grade(id: draftID, courseID: courseID, title: title, score: number(score),
              max: number(maximum), weight: number(weight), date: dayOf(date), kind: kind)
    }

    /// Exclude the item being edited, so its weight is not counted twice.
    private var otherGrades: [Grade] {
        store.liveGrades.filter { $0.courseID == courseID && $0.id != editing?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section { Text(message).foregroundStyle(Theme.danger) }
                }
                if addedCount > 0 {
                    Section { Text("\(addedCount) saved on this device.") }
                }
                if store.liveCourses.isEmpty {
                    Section {
                        Text("You need a class before you can log a grade.")
                        Button("Add your first class") { showCourseForm = true }
                    }
                } else {
                    Section("Class") {
                        Picker("Class", selection: $courseID) {
                            Text("Choose a class").tag(nil as UUID?)
                            ForEach(store.liveCourses) { course in
                                Text(course.name).tag(Optional(course.id))
                            }
                        }
                    }
                    Section("What was graded?") {
                        Picker("Type", selection: $kind) {
                            Text("No type").tag(nil as Grade.Kind?)
                            ForEach([Grade.Kind.assignment, .quiz, .exam, .project], id: \.self) {
                                Text($0.rawValue.capitalized).tag(Optional($0))
                            }
                        }
                        // CHANGED in Phase 9b: the accent well, and Return goes to Score.
                        TextField("Title", text: $title)
                            .focused($focus, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focus = .score }
                            .inputField(store.profile.accent)
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                    Section("Result") {
                        numberField("Score", text: $score, field: .score)
                        numberField("Out of", text: $maximum, field: .maximum)
                        if let hint = extraCreditHint(number(score), number(maximum)) {
                            Text(hint).font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                    Section("Weight in this class") {
                        numberField("Weight (%)", text: $weight, field: .weight)
                        budget
                    }
                    if editing == nil {
                        Section {
                            Button("Save & add another") { commit(another: true) }
                                .disabled(!store.validGrade(draft))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .tint(Theme.brand(store.profile.accent))
            // NEW in Phase 9b: swipe down or tap Done to see the buttons again.
            .keyboardDismissable { focus = nil }
            .navigationTitle(editing == nil ? "New Grade" : "Edit Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit(another: false) }
                        .disabled(!store.validGrade(draft))
                }
            }
            .onChange(of: kind) { _, next in
                // The new form's type buttons fill an empty/default title.
                // Editing an existing result never renames it unexpectedly.
                let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasLabel = Grade.Kind.allCases.contains { $0.rawValue.capitalized == clean }
                if editing == nil, let next, clean.isEmpty || wasLabel {
                    title = next.rawValue.capitalized
                }
            }
            // CHANGED in Phase 9b+: in its own NavigationStack, like every
            // other place that opens the class form. Without one the sheet had
            // no bar, so no Save, no Cancel, and no Done over the keyboard.
            .sheet(isPresented: $showCourseForm) {
                NavigationStack {
                    CourseFormView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showCourseForm = false }
                            }
                        }
                }
            }
        }
    }

    /// Keep labels visible after typing, including for VoiceOver.
    // CHANGED in Phase 9b: the accent well, at most 120 points wide so it
    // reads as a box for a number, and a focus id for Done.
    private func numberField(_ label: String, text: Binding<String>,
                             field: Field) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focus, equals: field)
                .accessibilityLabel(label)
                .frame(maxWidth: 120)
                .inputField(store.profile.accent)
        }
    }

    /// Warn above 100%, but allow saving: weighted averages still make sense.
    private var budget: some View {
        let used = usedWeight(otherGrades)
        let entered = number(weight)
        let pending = entered.isFinite && entered > 0 ? entered : 0
        let total = used + pending
        let left = remainingWeight(otherGrades)
        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: min(total, 100), total: 100)
                .tint(total > 100 ? Theme.danger : Theme.brand(store.profile.accent))
                .accessibilityLabel("Allocated grade weight")
                .accessibilityValue("\(total.formatted()) percent")
            Text(total > 100
                 ? "This puts the class at \(total.formatted())% of its weight. The average still works, but what do I still need can't be answered past 100%."
                 : "\(used.formatted())% already logged. This takes \(pending.formatted())% more, leaving \((100 - total).formatted())%.")
                .font(.footnote)
                .foregroundStyle(total > 100 ? Theme.danger : Theme.muted)
            if left > 0 && pending != left {
                Button("Use remaining \(left.formatted())%") { weight = String(left) }
            }
        }
    }

    /// Advance only after durable success. A failed attempt keeps its UUID,
    /// values and sheet; a successful next entry gets a fresh UUID.
    private func commit(another: Bool) {
        let saved = editing == nil ? store.addGrade(draft) : store.updateGrade(draft)
        guard saved else {
            message = store.lastSaveFailed
                ? "Couldn't save on this device. Your draft is still here. Tap Save to retry."
                : "This grade or its class is no longer available, or a field is invalid."
            return
        }
        message = nil
        if another {
            addedCount += 1
            let left = remainingWeight(store.liveGrades.filter { $0.courseID == courseID })
            title = ""
            score = ""
            maximum = "100"
            weight = String(left > 0 ? min(20, left) : 20)
            draftID = UUID()
        } else {
            dismiss()
        }
    }
}

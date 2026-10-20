//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradeScaleEditor.swift
// Phase: 9b (scales, goals and what-if)
// Ports: components/GradeScaleEditor.tsx (shown under Custom in the web's
//        Settings grading card; here it opens from the Grades scale card).
// Summary: Build your school's grading scale as rows of grade, from % and
//          points. Every edit saves whatever is usable, the issues list names
//          what isn't, and "What this gives" checks five marks against it.
//
import SwiftUI

struct GradeScaleEditor: View {
    @Environment(Store.self) private var store

    /// The rows as typed. Seeded once from the saved bands (or the standard
    /// scale when there are none, as on the web), then only this screen
    /// changes them. Saving never rewrites them, so a half-typed row stays.
    @State private var rows: [ScaleDraftRow]
    /// Set when the last edit couldn't be written to planner.json.
    @State private var saveFailed = false
    /// The scale a "Start from" button is waiting to put in, once confirmed.
    @State private var replacing: [ScaleBand]? = nil
    /// One field in one row. Each field needs its own focus value: if two
    /// fields shared one, SwiftUI couldn't tell which of them you tapped.
    private struct BandField: Hashable {
        enum Column { case letter, min, points }
        let row: UUID
        let column: Column
    }
    /// Which field has the keyboard, or nil. Done sets it to nil.
    @FocusState private var focused: BandField?

    init(saved: [ScaleBand]) {
        _rows = State(initialValue: scaleDraftRows(from: saved.isEmpty ? DEFAULT_SCALE : saved))
    }

    var body: some View {
        // Worked out fresh on every redraw from the rows as they stand.
        let draft = scaleBands(from: rows)
        let issues = scaleIssues(draft)
        let resolved = normalizeScale(draft)

        Form {
            if saveFailed {
                Section {
                    Text("Couldn't save on this device. Your rows are still here.")
                        .foregroundStyle(Theme.danger)
                    Button("Retry save") { commit(rows) }
                }
            }

            Section {
                // `ForEach($rows)` hands each row over as a binding (`$row`),
                // so a field can write straight into its own row of the array.
                ForEach($rows) { $row in
                    bandRow($row)
                }
            } header: {
                HStack(spacing: 8) {
                    Text("Grade").frame(width: 62)
                    Text("From %").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Points").frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 44, height: 1)
                }
            } footer: {
                Text("A grade is earned at its minimum percentage or above. Anything below every band is an F unless you add one starting at 0.")
            }

            Section {
                Button("Add a grade") { rows.append(ScaleDraftRow()) }
                    .disabled(rows.count >= MAX_SCALE_BANDS)
                Button("Start from A / A\u{2212}") { startFrom(DEFAULT_SCALE) }
                Button("Start from A / B / C") { startFrom(SIMPLE_SCALE) }
            }

            if !issues.isEmpty {
                Section {
                    ForEach(issues, id: \.self) { issue in
                        Text(issue)
                            .font(.footnote)
                            .foregroundStyle(Theme.warnInk)
                    }
                }
            }

            Section {
                if let resolved {
                    preview(resolved)
                } else {
                    Text("No usable bands yet, so grades still use the standard scale. Add at least one row with a grade, a minimum and its points.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            } header: {
                Text("What this gives")
            } footer: {
                Text("Points are what your GPA is averaged from, \(Int(MAX_GRADE_POINTS)) is the highest allowed, so weighted and out-of-10 systems both fit.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .tint(Theme.brand(store.profile.accent))
        // Swipe down or tap Done to reach the buttons under the rows.
        .keyboardDismissable { focused = nil }
        .navigationTitle("Custom scale")
        .navigationBarTitleDisplayMode(.inline)
        // Every edit saves, as on the web: no Save button, because a scale
        // that only applies after you find a button is one you'd think was set.
        .onChange(of: rows) { _, next in commit(next) }
        .confirmationDialog("Replace your bands?", isPresented: Binding(
            get: { replacing != nil }, set: { if !$0 { replacing = nil } }
        ), titleVisibility: .visible) {
            Button("Replace", role: .destructive) {
                if let replacing { rows = scaleDraftRows(from: replacing) }
                replacing = nil
            }
            Button("Cancel", role: .cancel) { replacing = nil }
        } message: {
            Text("Every row you've typed is swapped for this scale. There's no undo.")
        }
    }

    /// One band: grade, from %, points and a bin. The bin is `.borderless`
    /// because in a Form a plain button takes over the whole row's taps,
    /// and tapping a field would delete the band.
    private func bandRow(_ row: Binding<ScaleDraftRow>) -> some View {
        let accent = store.profile.accent
        let id = row.wrappedValue.id
        return HStack(spacing: 8) {
            TextField("A", text: row.letter)
                .multilineTextAlignment(.center)
                .fontWeight(.semibold)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused, equals: BandField(row: id, column: .letter))
                .accessibilityLabel("Grade")
                .inputField(accent)
                .frame(width: 62)
            TextField("93", text: row.min)
                .keyboardType(.decimalPad)
                .focused($focused, equals: BandField(row: id, column: .min))
                .accessibilityLabel("Minimum percentage")
                .inputField(accent)
            TextField("4.0", text: row.points)
                .keyboardType(.decimalPad)
                .focused($focused, equals: BandField(row: id, column: .points))
                .accessibilityLabel("Grade points")
                .inputField(accent)
            Button(role: .destructive) {
                rows.removeAll { $0.id == id }
            } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(row.wrappedValue.letter.isEmpty ? "this band" : row.wrappedValue.letter)")
        }
    }

    /// "What this gives": five marks run through the scale as it stands, so
    /// you can check your work without leaving the screen.
    private func preview(_ scale: [ScaleBand]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)],
                  alignment: .leading, spacing: 6) {
            ForEach(SCALE_PREVIEW_MARKS, id: \.self) { mark in
                // The letter is its own Text, so it alone is bold.
                Text("\(mark.formatted())% = \(Text(letterFor(mark, scale)).bold())")
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// Typed rows go straight in. Rows you've changed get a check first,
    /// since the buttons replace every row and the web has no undo for that.
    private func startFrom(_ bands: [ScaleBand]) {
        if scaleBands(from: rows) == bands || rows.allSatisfy({ $0.letter.isEmpty }) {
            rows = scaleDraftRows(from: bands)
        } else {
            replacing = bands
        }
    }

    /// Save what's usable. Letters past six characters are trimmed first:
    /// changing `rows` runs `.onChange` again, and that pass saves.
    private func commit(_ next: [ScaleDraftRow]) {
        let clipped = next.map { row in
            var copy = row
            copy.letter = letterPrefix(row.letter)
            return copy
        }
        if clipped != next {
            rows = clipped
            return
        }
        saveFailed = !store.setCustomScale(scaleBands(from: next))
    }
}

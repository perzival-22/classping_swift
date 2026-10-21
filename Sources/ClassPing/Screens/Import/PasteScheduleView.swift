//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/PasteScheduleView.swift
//  Phase:   13b (paste a timetable, and imports from the class form)
//  Ports:   components/PasteSchedule.tsx, the paste half. Its review of a
//           screenshot or PDF read by the AI server (`initialRows`, with the
//           "I checked..." boxes) is Phase 15.
//
//  Summary: Paste your timetable, check it, add it. Cells copied from a school
//           portal or a spreadsheet (or typed as CSV) become one row per
//           meeting, every field still editable. Untick what you don't want,
//           group a course's rows into one class, then Add selected meetings.
//           Nothing is added before that, and the text never leaves the phone.
//           A sheet from the import panel (D-84).
//

import SwiftUI

/// The web's example table, word for word: two Biology meetings, so
/// grouping shows what it does.
private let EXAMPLE_TABLE = "Course\tDays\tStart\tEnd\tRoom\nBiology\tMon/Wed\t9:00 AM\t10:00 AM\tScience 204\nBiology\tThu\t2:00 PM\t4:00 PM\tLab 3"

/// What the empty box shows: the example's first two lines.
private let PASTE_PLACEHOLDER = "Course\tDays\tStart\tEnd\tRoom\nBiology\tMon/Wed\t9:00 AM\t10:00 AM\tScience 204"

/// Every field here that can hold the keyboard: the paste box, or one cell
/// of one row. A case can carry values, as `CourseField.room(id)` does (9b+).
private enum PasteField: Hashable {
    case text
    case cell(Int, PasteColumn)
}

struct PasteScheduleView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Runs once the classes are added, just before the sheet closes, with
    /// whether the term question should follow (read before adding).
    let onAdded: (_ askTerm: Bool) -> Void

    /// The pasted text.
    @State private var text = ""
    /// The rows being checked, empty while you're still pasting. A good
    /// read always has at least one row, so empty means "the paste step".
    @State private var rows: [PasteRow] = []
    /// Why the last Review or Add couldn't go ahead, or nil.
    @State private var error: String? = nil
    /// "Group rows with the same course name", on to start, as on the web.
    @State private var group = true
    /// Set by Add, so a second tap while the sheet closes can't add twice.
    /// The web's `committed` ref.
    @State private var committed = false
    /// Which field has the keyboard, so Done can put it away.
    @FocusState private var focus: PasteField?

    var body: some View {
        let accent = store.profile.accent
        // The meetings already on your planner, to spot repeats.
        let existing = existingSlotKeys(store.activeCourses) { $0.name }

        NavigationStack {
            ScrollView {
                // `LazyVStack` builds each piece only as it scrolls into view,
                // where a VStack builds all of them at once. A paste can be
                // 200 rows of seven fields, so only the few on screen are made.
                LazyVStack(alignment: .leading, spacing: 16) {
                    if rows.isEmpty {
                        pasteStep(accent)
                    } else {
                        reviewIntro(accent)
                        // By index: each row is a struct inside `rows`, so
                        // its fields are changed through `rows[i]` (below).
                        ForEach(rows.indices, id: \.self) { i in
                            rowCard(i, accent, existing)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .keyboardDismissable { focus = nil }
            // The buttons stay at the bottom, as the web's sticky bar does,
            // with any problem just above them where it can't scroll away.
            .safeAreaInset(edge: .bottom) { bar(accent) }
            .navigationTitle("Paste your timetable")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - The two steps

    /// Step one: the box, the example, and what the columns are.
    @ViewBuilder
    private func pasteStep(_ accent: Profile.Accent) -> some View {
        Text("Copy cells from your school portal or spreadsheet. Include Course, Days, Start and End; Room, Teacher and Credits are optional. Tab-separated tables and CSV work here.")
            .font(.system(size: 14))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 8) {
            Text("Timetable text")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
            // A cell copied from a spreadsheet arrives with tabs between the
            // cells. Autocorrect is off, so "MWF" stays "MWF".
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focus, equals: .text)
                .scrollContentBackground(.hidden)
                // A set height, like the web's seven rows: a long paste
                // scrolls inside the box instead of stretching the screen.
                .frame(height: 170)
                // A TextEditor has no placeholder, so one sits on top while
                // it's empty, letting taps through to the box.
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(PASTE_PLACEHOLDER)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.hint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .inputField(accent)
                .accessibilityLabel("Timetable text")
        }

        Button("Use example table") {
            text = EXAMPLE_TABLE
            error = nil
        }
        .font(.system(size: 14, weight: .semibold))
        .buttonStyle(.bordered)
        .tint(Theme.brand(accent))

        Text("Without headers, use this order: Course, Days, Start, End, Room, Teacher, Credits. Your pasted text is processed on this device.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Step two's top: how the review works, and the grouping switch.
    @ViewBuilder
    private func reviewIntro(_ accent: Profile.Accent) -> some View {
        Text("Edit any field before adding. Uncheck rows you do not want. Exact duplicates are initially unchecked; repeated selected rows are added once.")
            .font(.system(size: 14))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)

        Toggle(isOn: $group) {
            Text("Group rows with the same course name into one subject with multiple meetings.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(Theme.brand(accent))

        Text("Grouping applies to these rows. Keep course codes and sections distinct; edit names to combine a lecture and lab belonging to the same subject. To add a meeting to an existing subject, use Edit class.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One row's card: its tick, its seven fields, then what's wrong with it
    /// or that it's already on your planner.
    private func rowCard(_ i: Int, _ accent: Profile.Accent, _ existing: Set<SlotKey>) -> some View {
        let row = rows[i]
        let parsed = parsePasteRow(row)

        return VStack(alignment: .leading, spacing: 10) {
            // The tick. `rows[i].selected.toggle()` changes the row inside
            // the array. A struct is a value, so `var r = rows[i]` would be
            // a copy, and ticking `r` would leave `rows` as it was.
            Button {
                rows[i].selected.toggle()
            } label: {
                Label("Row \(i + 1)", systemImage: row.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(row.selected ? Theme.brand(accent) : Theme.muted)
            .accessibilityAddTraits(row.selected ? .isSelected : [])

            // The course across the card, then the other six two by two.
            cell(i, .name, accent)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                      alignment: .leading, spacing: 8) {
                ForEach(PasteColumn.allCases.filter { $0 != .name }, id: \.self) { column in
                    cell(i, column, accent)
                }
            }

            if case .failure(let problem) = parsed {
                Text(problem.message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .success(let value) = parsed, existing.contains(slotKey(value)) {
                Text("This meeting already exists. Keep it unchecked to avoid adding another copy.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// One field of one row: its name over an editable well.
    private func cell(_ i: Int, _ column: PasteColumn, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(column.label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            TextField(column.label, text: field(i, column))
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focus, equals: .cell(i, column))
                .inputField(accent)
                .accessibilityLabel("Row \(i + 1) \(column.label)")
        }
    }

    /// A binding to one cell of one row, for its text field: `Binding(get:set:)`
    /// (5b) through the index and the row's subscript, so typing changes the
    /// row in `rows` itself. Editing clears the last problem, as on the web.
    /// The index is checked, since Back empties `rows` under the fields.
    private func field(_ i: Int, _ column: PasteColumn) -> Binding<String> {
        Binding(
            get: { rows.indices.contains(i) ? rows[i][column] : "" },
            set: { newText in
                guard rows.indices.contains(i) else { return }
                rows[i][column] = newText
                error = nil
            }
        )
    }

    // MARK: - The buttons

    /// How many rows are ticked.
    private var selectedCount: Int {
        rows.filter(\.selected).count
    }

    /// True when a ticked row can't be read: Add waits until it's fixed or unticked.
    private var anyProblem: Bool {
        rows.contains { $0.selected && $0.problem != nil }
    }

    /// The bar along the bottom: Cancel and Review classes while pasting,
    /// Back and Add selected meetings while checking.
    private func bar(_ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if rows.isEmpty {
                    Button { dismiss() } label: { wide("Cancel") }
                        .buttonStyle(.bordered)
                        .tint(Theme.muted)
                    Button { review() } label: { wide("Review classes") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand(accent))
                } else {
                    // Back keeps the text, so a fix to the paste is one tap away.
                    Button {
                        rows = []
                        error = nil
                    } label: {
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(minWidth: 70, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.muted)
                    Button { add() } label: { wide("Add selected meetings (\(selectedCount))") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand(accent))
                        .disabled(anyProblem || selectedCount == 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    /// A button's text, full width, at least 48 points tall, shrinking a
    /// little rather than cutting off a long count.
    private func wide(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    // MARK: - Doing it

    /// Review classes: the text as rows, repeats unticked, or why it can't
    /// be read. The web's `preview`.
    private func review() {
        focus = nil
        switch readPastedSchedule(text) {
        case .success(let read):
            rows = reviewRows(read, existing: existingSlotKeys(store.activeCourses) { $0.name })
            error = nil
        case .failure(let problem):
            error = problem.message
        }
    }

    /// Add selected meetings: the ticked rows as classes, added in one save,
    /// then the sheet closes. The web's `confirm`, with 13a's message when the
    /// phone can't save (D-81).
    private func add() {
        guard !committed, selectedCount > 0, !anyProblem else { return }
        focus = nil
        switch buildPastedClasses(rows, group: group) {
        case .failure(let problem):
            error = problem.message
        case .success(let classes):
            guard !classes.isEmpty else { return }
            committed = true
            // Asked before adding: adding is what makes the planner non-empty.
            let ask = store.shouldOfferTermSetup
            guard store.importItems(classes, []) else {
                committed = false
                error = "Couldn't save on this device, so nothing was added. Try again."
                return
            }
            onAdded(ask)
            dismiss()
        }
    }
}

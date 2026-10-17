//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AddMenu.swift
//  Phase:   3 (app shell), changed in 4a (the first three rows open the
//           task form) and 5b (Class opens the class form)
//  Ports:   components/AddMenu.tsx (the five labelled choices)
//
//  Summary: The sheet the Add button opens: the five things you can add, named,
//           in the same order as the web app. Assignment, Exam and Reminder
//           slide in the task form, Class slides in the class form; Note still
//           just closes (Phase 8).
//

import SwiftUI

/// The value pushed when you pick Class. An empty marker type: it carries no
/// data, it just tells `.navigationDestination` below which form to show.
// NEW in Phase 5b
struct NewCourseLink: Hashable {}

struct AddMenu: View {
    /// `dismiss` closes the sheet, the way `onClose()` does in the web component.
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store

    /// How tall the sheet is. Starts at half height; jumps to full when a
    /// form slides in, because a form needs the room.
    @State private var detent: PresentationDetent = .medium   // NEW in Phase 4a

    /// One choice in the menu. `symbol` is an SF Symbol name (the native icon set
    /// that replaces components/icons.tsx). `kind` is set for the three rows
    /// that open the task form; `addsCourse` for the Class row.
    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let symbol: String
        var kind: Assignment.Kind? = nil       // NEW in Phase 4a
        var addsCourse = false                 // NEW in Phase 5b
    }

    /// The five choices, matching AddMenu.tsx's list and wording.
    private let options = [
        Option(label: "Assignment", detail: "Homework, essays, lab reports", symbol: "doc.text", kind: .assignment),
        Option(label: "Exam", detail: "A test or quiz to revise for", symbol: "graduationcap", kind: .exam),
        Option(label: "Reminder", detail: "Something to bring or do, not graded", symbol: "bell", kind: .reminder),
        Option(label: "Note", detail: "Write down a lecture or a thought", symbol: "pencil"),
        // CHANGED in Phase 5b: Class now opens the class form.
        Option(label: "Class", detail: "Add a subject to your timetable", symbol: "book", addsCourse: true),
    ]

    var body: some View {
        NavigationStack {
            List(options) { opt in
                // A row with a kind pushes that kind; the Class row pushes the
                // marker. Each value type has its own destination below.
                if let kind = opt.kind {
                    NavigationLink(value: kind) {
                        label(for: opt)
                    }
                } else if opt.addsCourse {
                    // NEW in Phase 5b
                    NavigationLink(value: NewCourseLink()) {
                        label(for: opt)
                    }
                } else {
                    // Note (Phase 8) still just closes the menu.
                    Button {
                        dismiss()
                    } label: {
                        label(for: opt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // What to show when a kind is pushed. Saving closes the whole Add
            // sheet (not just the form), so `onFinish` is our dismiss.
            .navigationDestination(for: Assignment.Kind.self) { kind in
                AssignmentFormView(kind: kind, onFinish: { dismiss() })
                    .onAppear { detent = .large }
            }
            // NEW in Phase 5b: and when Class is picked.
            .navigationDestination(for: NewCourseLink.self) { _ in
                CourseFormView(onFinish: { dismiss() })
                    .onAppear { detent = .large }
            }
        }
        // A sheet that opens to about half height, draggable to full. The
        // `selection:` lets the code above change the height too.
        .presentationDetents([.medium, .large], selection: $detent)   // CHANGED in Phase 4a
    }

    /// One row's look: a brand-soft rounded square holding the icon, then the
    /// name and a one-line description, like the web rows.
    // NEW in Phase 4a (moved out of `body`, so both row types can share it)
    private func label(for opt: Option) -> some View {
        let accent = store.profile.accent
        return HStack(spacing: 14) {
            Image(systemName: opt.symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 38, height: 38)
                .background(Theme.brand(accent).opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(opt.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(opt.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

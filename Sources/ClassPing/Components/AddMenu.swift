//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AddMenu.swift
//  Phase:   3 (app shell)
//  Ports:   components/AddMenu.tsx (the five labelled choices)
//
//  Summary: The sheet the Add button opens: the five things you can add, named,
//           in the same order as the web app. Phase 3 just shows and dismisses;
//           Phase 4 wires each row to the task and class forms.
//

import SwiftUI

struct AddMenu: View {
    /// `dismiss` closes the sheet, the way `onClose()` does in the web component.
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store

    /// One choice in the menu. `symbol` is an SF Symbol name (the native icon set
    /// that replaces components/icons.tsx).
    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let symbol: String
    }

    /// The five choices, matching AddMenu.tsx's list and wording.
    private let options = [
        Option(label: "Assignment", detail: "Homework, essays, lab reports", symbol: "doc.text"),
        Option(label: "Exam", detail: "A test or quiz to revise for", symbol: "graduationcap"),
        Option(label: "Reminder", detail: "Something to bring or do, not graded", symbol: "bell"),
        Option(label: "Note", detail: "Write down a lecture or a thought", symbol: "pencil"),
        Option(label: "Class", detail: "Add a subject to your timetable", symbol: "book"),
    ]

    var body: some View {
        let accent = store.profile.accent
        NavigationStack {
            List(options) { opt in
                Button {
                    // Phase 4 opens the matching form. For now the menu just closes.
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        // A brand-soft rounded square holds the icon, like the web rows.
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
                .buttonStyle(.plain)
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // A sheet that opens to about half height, draggable to full.
        .presentationDetents([.medium, .large])
    }
}
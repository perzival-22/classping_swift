//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/TaskFilterBar.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   components/TaskFilterBar.tsx (the chip and its panel; the saved
//           preferences part lives in AssignmentsView as @AppStorage)
//
//  Summary: One "Filters" chip that opens a panel for narrowing the list by
//           subject, by type, and whether archived classes' work is shown.
//           When filters are on, the chip shows how many and "3 of 12" explains
//           why the list looks short.
//

import SwiftUI

struct TaskFilterBar: View {
    /// The filters, owned by the Tasks screen. `@Binding` means this view can
    /// read AND change a value that lives somewhere else: setting `filters`
    /// here writes straight back into the screen's storage.
    @Binding var filters: TaskFilters
    /// Whether the panel is open, also owned by the screen.
    @Binding var open: Bool

    /// Classes that actually have work in the list (a filter for an empty class
    /// is a dead end), how many tasks are showing, and out of how many.
    let courses: [Course]
    let showing: Int
    let total: Int
    let accent: Profile.Accent

    var body: some View {
        let active = filters.activeCount

        VStack(alignment: .leading, spacing: 10) {
            // The chip row: Filters (· count), then "3 of 12" and Clear when filtering.
            HStack(spacing: 8) {
                Button {
                    open.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Text("Filters")
                        if active > 0 { Text("· \(active)").bold() }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(active > 0 ? Theme.brandDeep(accent) : Theme.muted)
                    .background(active > 0 ? Theme.brand(accent).opacity(0.16) : Theme.surface2,
                                in: Capsule())
                }
                .buttonStyle(.plain)

                if active > 0 {
                    Text("\(showing) of \(total)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Clear") { filters = TaskFilters.defaults }
                        .font(.system(size: 12.5, weight: .semibold))
                }
            }

            // The panel, only while open.
            if open {
                VStack(alignment: .leading, spacing: 12) {
                    // Subject: All, then one chip per class. Tapping the active
                    // chip again turns it off, as on the web.
                    group("Subject") {
                        chip("All", filters.subject == nil) { filters.subject = nil }
                        ForEach(courses) { course in
                            chip(course.short.isEmpty ? course.name : course.short,
                                 filters.subject == course.id) {
                                filters.subject = filters.subject == course.id ? nil : course.id
                            }
                        }
                    }

                    // Type: All, then the four kinds. `allCases` exists because
                    // Kind is CaseIterable (Step 0 of Phase 4a put that back).
                    group("Type") {
                        chip("All", filters.kind == nil) { filters.kind = nil }
                        ForEach(Assignment.Kind.allCases, id: \.self) { kind in
                            chip(kind.pluralLabel, filters.kind == kind.rawValue) {
                                filters.kind = filters.kind == kind.rawValue ? nil : kind.rawValue
                            }
                        }
                    }

                    // Only worth asking when some class is archived.
                    if courses.contains(where: { $0.archived }) {
                        group("Archived classes") {
                            chip("Show their work", filters.includeArchived) { filters.includeArchived = true }
                            chip("Hide", !filters.includeArchived) { filters.includeArchived = false }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    /// A labelled row of chips that scrolls sideways when it runs out of room.
    /// `@ViewBuilder` lets the caller pass several views (the chips) in braces,
    /// the same way `HStack { ... }` takes its children.
    private func group<Content: View>(_ label: String,
                                      @ViewBuilder _ chips: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { chips() }
            }
        }
    }

    /// One chip: brand-filled when active, the card color when not.
    private func chip(_ text: String, _ active: Bool,
                      _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12.5, weight: active ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .foregroundStyle(active ? Color.white : Theme.ink)
                .background(active ? Theme.brand(accent) : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

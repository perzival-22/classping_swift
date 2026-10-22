//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Import/FeedRefreshView.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   components/FeedRefresh.tsx (FeedRefreshPreview)
//
//  Summary: What a feed refresh would do, before it does any of it. Grouped
//           by what happened (new, changed at school, changed in both
//           places, cancelled, gone from the feed, matched), because those
//           need very different amounts of your attention. Every row has a
//           tick; the ones that could lose your work start unticked.
//

import SwiftUI

/// One group of the preview: the action it holds, its heading and why it
/// needs a look. `SECTIONS` in FeedRefresh.tsx, in the web's order and words.
private struct RefreshSection {
    let action: FeedAction
    let heading: String
    let note: String
    /// Warning groups say their note in the warning color.
    let warn: Bool
}

private let REFRESH_SECTIONS: [RefreshSection] = [
    RefreshSection(action: .add, heading: "New", note: "Not in your planner yet.", warn: false),
    RefreshSection(action: .update, heading: "Changed at school",
                   note: "You haven't edited these, so applying them is safe.", warn: false),
    RefreshSection(action: .conflict, heading: "Changed in both places",
                   note: "You edited these and the school changed them too. Left unticked, tick one only if you want the school's version instead of yours.",
                   warn: true),
    RefreshSection(action: .withdrawn, heading: "Cancelled by the school",
                   note: "The feed says these are off. Ticking one moves it to Recently Deleted, where you can still get it back.",
                   warn: true),
    RefreshSection(action: .missing, heading: "No longer in the feed",
                   note: "These may simply have scrolled out of the window your school publishes, so nothing is removed unless you say so.",
                   warn: true),
    RefreshSection(action: .adopt, heading: "Matched to what you already have",
                   note: "Imported before we recorded feed IDs. Linking them now is what stops a future refresh adding a second copy.",
                   warn: false),
]

/// One row of the preview with what it needs on screen, whichever kind of
/// item it is. The web's `FeedEntrySummary`.
private struct RefreshRow: Identifiable {
    let key: String
    let action: FeedAction
    let title: String
    let changes: [FieldChange]
    var id: String { key }
}

/// The preview itself: a summary, the groups with their ticks, then Cancel
/// and Apply. Shown inside the import panel in place of its buttons.
struct FeedRefreshPreview: View {
    @Environment(Store.self) private var store

    let plan: FeedPlan
    /// The ticked rows, by key. A `Binding` so the panel holds the ticks and
    /// this view only shows and flips them.
    @Binding var picked: Set<String>
    /// True while the refresh is being written.
    var busy = false
    let onApply: () -> Void
    let onCancel: () -> Void

    /// Classes then assignments, as one list, leaving out "unchanged".
    private var rows: [RefreshRow] {
        let classes = plan.classes.map { RefreshRow(key: $0.key, action: $0.action, title: $0.title, changes: $0.changes) }
        let tasks = plan.tasks.map { RefreshRow(key: $0.key, action: $0.action, title: $0.title, changes: $0.changes) }
        return (classes + tasks).filter { $0.action != .unchanged }
    }

    var body: some View {
        let accent = store.profile.accent
        let actionable = rows
        let chosen = actionable.filter { picked.contains($0.key) }.count
        let unchanged = plan.totals[.unchanged] ?? 0

        VStack(alignment: .leading, spacing: 14) {
            if actionable.isEmpty {
                // Nothing to review: say so, and one button to close.
                summary("Already up to date",
                        "Nothing in this feed has changed since your last refresh.", accent)
                Button { onCancel() } label: { wide("Done") }
                    .buttonStyle(.bordered)
                    .tint(Theme.muted)
            } else {
                summary("\(actionable.count) change\(actionable.count == 1 ? "" : "s") to review",
                        "\(unchanged) item\(unchanged == 1 ? "" : "s") already match. Nothing is written until you apply.",
                        accent)

                // Each group that has rows, in the web's order.
                ForEach(REFRESH_SECTIONS, id: \.action) { section in
                    let group = actionable.filter { $0.action == section.action }
                    if !group.isEmpty {
                        sectionView(section, group, accent)
                    }
                }

                HStack(spacing: 10) {
                    Button { onCancel() } label: { wide("Cancel") }
                        .buttonStyle(.bordered)
                        .tint(Theme.muted)
                    Button { onApply() } label: { wide(busy ? "Applying…" : "Apply \(chosen)") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand(accent))
                        .disabled(chosen == 0 || busy)
                }
            }
        }
    }

    // MARK: - Pieces

    /// The tinted box at the top: a bold line and a quiet one.
    private func summary(_ title: String, _ detail: String, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    /// One group: its heading and count, why it needs a look, then its rows.
    private func sectionView(_ section: RefreshSection, _ group: [RefreshRow],
                             _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.heading.uppercased())
                    .tracking(1.2)
                Text("\(group.count)")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.faint)
            .accessibilityAddTraits(.isHeader)

            Text(section.note)
                .font(.system(size: 12))
                .foregroundStyle(section.warn ? Theme.warnInk : Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(group) { row in
                rowView(row, accent)
            }
        }
    }

    /// One row: its tick, the item's name, and each change as "Days: Mon Wed → Tue Thu".
    private func rowView(_ row: RefreshRow, _ accent: Profile.Accent) -> some View {
        let on = picked.contains(row.key)
        return Button {
            // Flip this row's tick. `Set.remove` / `insert` change the
            // binding, which the panel holds.
            if on { picked.remove(row.key) } else { picked.insert(row.key) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17))
                    .foregroundStyle(on ? Theme.brand(accent) : Theme.hint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    ForEach(row.changes, id: \.field) { change in
                        Text("\(change.label): \(change.from) → \(change.to)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Theme.brandSoft(accent).opacity(0.6),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            // The whole row is the tap target, not only the text.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A button's text, full width, at least 48 points tall.
    private func wide(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
    }
}

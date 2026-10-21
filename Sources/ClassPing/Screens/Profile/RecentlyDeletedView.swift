//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/RecentlyDeletedView.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   app/settings/deleted/page.tsx (RecentlyDeletedScreen,
//           EmptyState, TrashRow)
//
//  Summary: Everything you've deleted in the last 30 days, newest first, with
//           the class it belonged to and how long it has left. Restore puts it
//           back; Delete now (tap twice) removes it for good. Work that went
//           with its class says so instead, because the class owns it.
//

import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(Store.self) private var store

    /// Empty was tapped once: it now says "Sure?".
    @State private var confirmEmpty = false
    /// The row whose Delete now was tapped once, by its id, or nil.
    @State private var confirmPurge: String? = nil
    /// A save that didn't reach planner.json, in words, or nil.
    @State private var problem: String? = nil
    /// The moment the countdowns are read against: when you opened the
    /// screen, as the web's `useMemo(() => new Date(), [])`.
    @State private var now = Date.now

    var body: some View {
        let accent = store.profile.accent
        let trash = store.trash

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                }
                if trash.isEmpty {
                    emptyState
                } else {
                    Text("Deleted items stay here for \(RECOVERY_RETENTION_DAYS) days, then they're gone for good. Restoring one brings back everything that went with it.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                    ForEach(trash) { entry in
                        row(entry, accent)
                    }
                }
            }
            .padding(18)
        }
        .background(Theme.canvas)
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The web's Empty button, top right, asking once more first.
            ToolbarItem(placement: .topBarTrailing) {
                Button(confirmEmpty ? "Sure?" : "Empty") {
                    if confirmEmpty {
                        report(store.emptyTrash())
                        confirmEmpty = false
                    } else {
                        confirmEmpty = true
                    }
                }
                .fontWeight(.semibold)
                .tint(Theme.dangerInk)
                .disabled(trash.isEmpty)
            }
        }
    }

    /// One deleted item: what it was, where it was, how long it has left,
    /// and what you can do about it.
    private func row(_ entry: TrashEntry, _ accent: Profile.Accent) -> some View {
        // "Assignment · Biology · 12 days left". An empty detail is left out.
        let line = [entry.kind.label, entry.detail, purgeLine(entry.deletedAt, now: now)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol(entry.kind))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted2)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface2, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(line)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            if entry.viaClass {
                // Restoring this alone would put it under a class that isn't
                // there, so the class owns the action and the row says so.
                Text("Went with its class. Restore the class to bring this back too.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.infoInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.infoSoft, in: RoundedRectangle(cornerRadius: 11))
            } else {
                HStack(spacing: 8) {
                    Button {
                        confirmPurge = nil
                        report(store.restoreFromTrash(entry))
                    } label: {
                        chip("Restore", fill: Theme.brandSoft(accent), ink: Theme.brand(accent), bold: true)
                    }
                    Button {
                        if confirmPurge == entry.id {
                            confirmPurge = nil
                            report(store.purgeFromTrash(entry))
                        } else {
                            confirmPurge = entry.id
                        }
                    } label: {
                        let asking = confirmPurge == entry.id
                        chip(asking ? "Delete for good?" : "Delete now",
                             fill: asking ? Theme.dangerSoft : .clear,
                             ink: asking ? Theme.dangerInk : Theme.muted2, bold: false)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// A small round-ended button label, like the web's pill buttons. At
    /// least 44 points tall, so it's easy to hit.
    private func chip(_ title: String, fill: Color, ink: Color, bold: Bool) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: bold ? .bold : .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(fill, in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    /// Nothing deleted: a calm card that says what this screen is for.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 22))
                .foregroundStyle(Theme.hint)
                .frame(width: 52, height: 52)
                .background(Theme.surface2, in: Circle())
                .accessibilityHidden(true)
            Text("Nothing deleted")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Anything you delete waits here for \(RECOVERY_RETENTION_DAYS) days, so an accidental tap is never the end of it.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.top, 24)
    }

    /// Each kind's little picture, close to the web's icons.
    private func symbol(_ kind: EntityKind) -> String {
        switch kind {
        case .course: "book.closed"
        case .assignment: "checklist"
        case .grade: "graduationcap"
        case .note: "pencil"
        }
    }

    /// Shows the save message when a write didn't reach planner.json.
    private func report(_ saved: Bool) {
        problem = saved ? nil : "Couldn't save on this device. Nothing changed."
    }
}

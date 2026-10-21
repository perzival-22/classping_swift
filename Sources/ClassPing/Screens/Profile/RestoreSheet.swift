//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/RestoreSheet.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   components/RestoreSheet.tsx
//
//  Summary: Restoring a backup as a decision, not a button. You pick a file,
//           and before anything moves you see what would happen: what's new,
//           what's already here, what would be updated and, only in Replace,
//           what would go. Merge is picked to start with. Nothing changes
//           until you tap the restore button, and the Undo bar can take it
//           back afterwards.
//

import SwiftUI
import UniformTypeIdentifiers

struct RestoreSheet: View {
    @Environment(Store.self) private var store
    /// Closes this sheet. SwiftUI hands every presented screen this action.
    @Environment(\.dismiss) private var dismiss

    /// The Files app's picker is open.
    @State private var picking = false
    /// The chosen file's name, shown under the button.
    @State private var fileName = ""
    /// The checked, read backup, or nil before a good file is picked.
    @State private var backup: BackupContents? = nil
    /// Why the picked file can't be restored, or nil.
    @State private var error: String? = nil
    @State private var mode = RestoreMode.merge

    var body: some View {
        let accent = store.profile.accent

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if backup == nil && error == nil {
                        Text("Choose a ClassPing backup file. You'll see exactly what changes before anything is restored.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: Choosing the file
                    Button { picking = true } label: {
                        Text(fileName.isEmpty ? "Choose a backup file" : "Choose a different file")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.ink)

                    if !fileName.isEmpty {
                        Text(fileName)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity)
                    }

                    if let error {
                        callout(error, Theme.dangerSoft, Theme.dangerInk)
                    }

                    // MARK: What would happen
                    if let backup {
                        plan(store.restorePlan(backup, mode: mode), backup, accent)
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Restore a backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        // MARK: The picker
        // The Files app's own picker, showing only JSON files. You get back
        // the address of the file you chose, or nothing if you cancel.
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { open(url) }
        }
    }

    /// The plan for the picked file, the two modes, and the restore button.
    @ViewBuilder
    private func plan(_ plan: RestorePlan, _ backup: BackupContents, _ accent: Profile.Accent) -> some View {
        // How to restore: Merge or Replace.
        sectionLabel("HOW TO RESTORE")
        HStack(spacing: 8) {
            modeButton(.merge, "Merge", "Adds what's missing. Keeps everything already here.", accent)
            modeButton(.replace, "Replace", "Makes this device match the file exactly.", accent)
        }

        // What changes, one line per kind, the web's words.
        sectionLabel("WHAT CHANGES")
        VStack(alignment: .leading, spacing: 6) {
            // `id: \.self` uses each line as its own id; no two lines match.
            ForEach(describePlan(plan), id: \.self) { line in
                Text(line.capitalized)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
            }
            if plan.restoresPreferences {
                Text("Your preferences and progress come back as they were saved.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
            }
        }

        if !plan.warnings.isEmpty {
            callout(plan.warnings.joined(separator: "\n"), Theme.warnSoft, Theme.warnInk)
        }

        if mode == .replace {
            callout("Replace removes anything on this device that isn't in the file. You can undo it straight afterwards.",
                    Theme.dangerSoft, Theme.dangerInk)
        }

        // The web's <details>: a tap opens it.
        DisclosureGroup("What a backup doesn't include") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(BACKUP_LEAVES_OUT, id: \.what) { item in
                    // A `Text` can sit inside another's text: the name bold, the reason plain.
                    Text("\(Text(item.what).bold().foregroundStyle(Theme.ink)), \(item.why)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 6)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .tint(Theme.muted2)

        // The button says what it will do, and can't be tapped for nothing.
        Button {
            if store.restoreBackup(backup, mode: mode) {
                dismiss()
            } else {
                error = "Couldn't save on this device. Nothing was restored."
            }
        } label: {
            Text(plan.totalChanges == 0 ? "Nothing to restore"
                 : mode == .merge ? "Restore and merge" : "Replace everything")
                .font(.system(size: 15.5, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brand(accent))
        .disabled(plan.totalChanges == 0)
    }

    /// One of the two choices, highlighted when it's the one picked.
    private func modeButton(_ which: RestoreMode, _ title: String, _ detail: String,
                            _ accent: Profile.Accent) -> some View {
        let active = mode == which
        return Button { mode = which } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? Theme.brandDeep(accent) : Theme.ink)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(active ? Theme.brandSoft(accent) : Theme.surface2,
                        in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(active ? Theme.brand(accent).opacity(0.35) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        // VoiceOver hears "selected" on the chosen one, like the web's aria-pressed.
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The small spaced-out caps over each part.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
            .padding(.top, 4)
    }

    /// A tinted box for an error, a warning or the Replace caution.
    private func callout(_ text: String, _ fill: Color, _ ink: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 13))
    }

    /// Reads the chosen file and checks it. A file from the picker lives
    /// outside the app, so iOS asks the app to say when it starts and stops
    /// reading it ("security-scoped"). `defer` runs its block when this
    /// function ends, however it ends, so the stop is never forgotten.
    private func open(_ url: URL) {
        let reading = url.startAccessingSecurityScopedResource()
        defer { if reading { url.stopAccessingSecurityScopedResource() } }

        fileName = url.lastPathComponent
        backup = nil
        mode = .merge
        guard let data = try? Data(contentsOf: url) else {
            error = "That file couldn't be read. Try choosing it again."
            return
        }
        // A bad file changes nothing but the message saying why.
        switch BackupContents.open(data) {
        case .success(let contents):
            backup = contents
            error = nil
        case .failure(let problem):
            error = problem.message
        }
    }
}

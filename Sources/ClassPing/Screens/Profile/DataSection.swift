//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/DataSection.swift
//  Phase:   11b+c (backups, Recently Deleted and the calendar)
//  Ports:   the backup rows of app/settings/page.tsx's Account card: where
//           your work is, "Back up my data", "Restore a backup", "Recently
//           Deleted" and "Clear all data"
//
//  Summary: The Profile tab's YOUR DATA card. Back up saves a file through
//           the Files app's save sheet, Restore opens the restore sheet,
//           Recently Deleted opens its screen, and Clear all data asks once,
//           naming exactly what would go, before it empties the planner.
//

import SwiftUI
import UniformTypeIdentifiers

/// The backup file, as the save sheet needs it. `FileDocument` is SwiftUI's
/// way to hand a file to the system: it says which kinds of file it is
/// (`readableContentTypes`) and gives its bytes in a `FileWrapper`. Like
/// JSONValue, both methods may throw by the protocol's rules and don't here.
struct BackupDocument: FileDocument {
    /// A backup is JSON. `UTType` names file kinds; `.json` is "public.json".
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    /// Reading a document back in. Only exporting uses this type, but the
    /// protocol asks for it.
    init(configuration: ReadConfiguration) {
        data = configuration.file.regularFileContents ?? Data()
    }

    /// The file's bytes, for the save sheet to write where you choose.
    func fileWrapper(configuration: WriteConfiguration) -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataSection: View {
    @Environment(Store.self) private var store

    /// The file being saved, made when you tap Back up.
    @State private var backup: BackupDocument? = nil
    /// The save sheet is open.
    @State private var exporting = false
    /// "Backup saved" shows for a few seconds after it worked.
    @State private var backedUp = false
    /// The restore sheet is open.
    @State private var restoring = false
    /// Clear all data was tapped once: the confirmation is showing.
    @State private var confirmClear = false
    /// "Cleared, your planner is empty." shows for a few seconds.
    @State private var cleared = false
    /// Something didn't work, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        let summary = store.clearSummary
        let deletedCount = store.trash.count

        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR DATA")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

            // MARK: Where your work is
            // The web's sync row, in its "saved" state: there's no cloud yet.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(store.lastSaveFailed ? Theme.danger : Theme.hint)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                    Text(store.lastSaveFailed ? "Couldn't save on this device" : "Saved on this device")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(store.lastSaveFailed ? Theme.danger : Theme.ink)
                }
                Text("Your work is saved on this device.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            Divider()

            // MARK: Back up
            Button(action: startBackup) {
                rowLabel("💾", backedUp ? "Backup saved" : "Back up my data", accent)
            }
            Divider()

            // MARK: Restore
            Button { restoring = true } label: {
                rowLabel("📥", "Restore a backup", accent)
            }
            Divider()

            // MARK: Recently Deleted
            NavigationLink {
                RecentlyDeletedView()
            } label: {
                rowLabel("🗂️", "Recently Deleted", accent,
                         count: deletedCount > 0 ? deletedCount : nil)
            }
            Divider()

            // MARK: Clear all data
            if confirmClear, let summary {
                clearConfirmation(summary, accent)
            } else {
                Button { confirmClear = true } label: {
                    HStack(spacing: 12) {
                        icon("🧹", Theme.warnSoft)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Clear all data")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text(cleared ? "Cleared, your planner is empty."
                                 : summary.map { "Erase \($0). Keeps your preferences." }
                                 ?? "Nothing to clear yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .disabled(summary == nil)
                .opacity(summary == nil ? 0.5 : 1)
            }

            if let problem {
                Text(problem)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
                    .padding([.horizontal, .bottom], 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // MARK: The save sheet
        // The Files app's "save to…" sheet: you pick the folder and can rename
        // the file. The name goes in without ".json"; the sheet adds it from
        // the content type. Cancelling just closes it.
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json,
                      defaultFilename: String(backupFilename(.now).dropLast(5)),
                      onCompletion: { result in
                          // `Result` (11a): it worked, or here's why not.
                          switch result {
                          case .success:
                              backedUp = true
                              problem = nil
                          case .failure:
                              problem = "Couldn't save the backup. Try again."
                          }
                          backup = nil
                      })
        .sheet(isPresented: $restoring) {
            RestoreSheet()
        }
        // "Backup saved" for 5 seconds, as the web's "Backup downloaded".
        .task(id: backedUp) {
            guard backedUp else { return }
            try? await Task.sleep(for: .seconds(5))
            backedUp = false
        }
        // "Cleared…" for 5 seconds too.
        .task(id: cleared) {
            guard cleared else { return }
            try? await Task.sleep(for: .seconds(5))
            cleared = false
        }
    }

    /// One row: an emoji in a soft square, its words, and a count or arrow.
    /// The web uses the same emoji, so the two apps look alike here.
    private func rowLabel(_ emoji: String, _ title: String, _ accent: Profile.Accent,
                          count: Int? = nil) -> some View {
        HStack(spacing: 12) {
            icon(emoji, Theme.brandSoft(accent))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            if let count {
                Text("\(count)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.muted2)
            }
        }
        .padding(16)
        .frame(minHeight: 44)
        // The whole row is the button, not just its words.
        .contentShape(Rectangle())
    }

    /// The emoji in its 36-point rounded square.
    private func icon(_ emoji: String, _ fill: Color) -> some View {
        Text(emoji)
            .font(.system(size: 17))
            .frame(width: 36, height: 36)
            .background(fill, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    /// The second step of Clear all data: what would go, a way to back up
    /// first, then Keep it or Clear everything. The web's wording, less the
    /// cloud and account parts this phone doesn't have yet (D-76).
    private func clearConfirmation(_ summary: String, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This permanently deletes \(summary) on this device. Your preferences stay. It can't be undone.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back up first", action: startBackup)
                .font(.system(size: 13, weight: .semibold))
                .tint(Theme.brand(accent))
            HStack(spacing: 10) {
                Button {
                    confirmClear = false
                } label: {
                    Text("Keep it")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.muted)

                Button {
                    if store.clearData() {
                        confirmClear = false
                        problem = nil
                        cleared = true
                    } else {
                        problem = "Couldn't save on this device. Nothing was cleared."
                    }
                } label: {
                    Text("Clear everything")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.danger)
            }
        }
        .padding(16)
    }

    /// Makes the file and opens the save sheet. `handleExportData`.
    private func startBackup() {
        guard let data = store.backupData() else {
            problem = "Couldn't make the backup. Try again."
            return
        }
        backup = BackupDocument(data: data)
        exporting = true
    }
}

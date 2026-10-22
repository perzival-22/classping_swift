//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/AccountCard.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   the Account card of app/settings/page.tsx (who you're signed in
//           as, the sync row, sign out) and the web's "Continue with Google"
//           sign-in; the first-sync review is the phone's own (D-90, D-97)
//
//  Summary: Signing in, the sync row, and the review a first sync shows
//           before anything is sent. Replaces the "Your account and sync"
//           placeholder on the Profile tab.
//

import SwiftUI

struct AccountCard: View {
    @Environment(Store.self) private var store
    @Environment(SyncEngine.self) private var sync

    /// The review sheet is open. It opens by itself when a first sync is
    /// ready to review, and from the card's button after "Later".
    @State private var reviewing = false

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)

            // `if let` on the account decides which half of the card shows.
            if let email = sync.account.email ?? sync.account.userID {
                signedIn(email, accent)
            } else {
                signedOut(accent)
            }

            if let problem = sync.account.problem {
                Text(problem)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // A first sync's review opens as soon as it's ready.
        .onChange(of: sync.phase) { _, phase in
            if case .review = phase { reviewing = true }
        }
        .sheet(isPresented: $reviewing) {
            FirstSyncReview()
        }
    }

    // MARK: Signed out

    /// The web's sign-in prompt: one button, Google, since that's how you sign in.
    private func signedOut(_ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign in to sync your planner with classping.space. Until then, everything stays on this phone.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task {
                    await sync.account.signInWithGoogle()
                    await sync.accountChanged()
                }
            } label: {
                Text(sync.account.working ? "Opening Google…" : "Continue with Google")
                    .font(.system(size: 15.5, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand(accent))
            .disabled(sync.account.working || !sync.account.isLoaded)
        }
    }

    // MARK: Signed in

    /// Who you are, the sync row, and the buttons that go with it.
    private func signedIn(_ email: String, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signed in as \(email)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)

            // The sync row: 14a's words for where your work is.
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rowTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(sync.status.state == .error ? Theme.danger : Theme.ink)
                    Text(rowDetail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                // After the first sync, a manual pull and push; before it,
                // the way back to the review.
                switch sync.phase {
                case .live:
                    Button("Sync now") { Task { await sync.pullAndPush() } }
                        .buttonStyle(.bordered)
                        .tint(Theme.brand(accent))
                case .review:
                    Button("Review first sync") { reviewing = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand(accent))
                default:
                    EmptyView()
                }
                Spacer(minLength: 0)
                Button("Sign out") {
                    Task {
                        await sync.account.signOut()
                        await sync.accountChanged()
                    }
                }
                .buttonStyle(.bordered)
                .tint(Theme.muted)
                .disabled(sync.account.working)
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(minHeight: 44)
        }
    }

    /// The sync row's title. Before the first sync it says so instead.
    private var rowTitle: String {
        switch sync.phase {
        case .preparing: return "Checking what's on the web…"
        case .review: return "Not synced yet"
        default: return syncLabel(sync.status)
        }
    }

    /// The line under it.
    private var rowDetail: String {
        switch sync.phase {
        case .preparing, .review:
            return "Nothing has been sent or changed. Review what a first sync would do, then decide."
        default:
            return syncDetail(sync.status)
        }
    }

    /// Green when synced, red on an error, grey otherwise.
    private var dotColor: Color {
        switch sync.status.state {
        case .synced: return Theme.good
        case .error: return Theme.danger
        default: return Theme.hint
        }
    }
}

/// What a first sync would do, and your go-ahead (D-90, D-97). Nothing
/// changes on the phone or the web until you tap "Sync now".
struct FirstSyncReview: View {
    @Environment(Store.self) private var store
    @Environment(SyncEngine.self) private var sync
    @Environment(\.dismiss) private var dismiss

    /// You've made both backups. The button stays off until this is on.
    @State private var backedUp = false
    /// True while the first sync runs.
    @State private var syncing = false

    var body: some View {
        let accent = store.profile.accent

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Nothing has been sent or changed yet. Here's what a first sync would do.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error = sync.status.error {
                        Text(error)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.danger)
                        Button("Try again") { Task { await sync.prepareReview() } }
                            .buttonStyle(.bordered)
                            .tint(Theme.brand(accent))
                    }

                    if case .review(let review) = sync.phase {
                        summary(review)
                    } else {
                        ProgressView("Checking what's on the web…")
                    }

                    // MARK: Back up first
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BACK UP FIRST")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.faint)
                        Text("Save a backup of this phone (Profile, Your data, Back up my data) and export one from Settings on classping.space. If anything looks wrong afterwards, either one puts it back.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Toggle("I've backed up both", isOn: $backedUp)
                            .font(.system(size: 15, weight: .medium))
                            .tint(Theme.brand(accent))
                    }
                    .padding(16)
                    .cardStyle()

                    Button {
                        syncing = true
                        Task {
                            await sync.confirmFirstSync()
                            syncing = false
                            if sync.phase == .live { dismiss() }
                        }
                    } label: {
                        Text(syncing ? "Syncing…" : "Sync now")
                            .font(.system(size: 15.5, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand(accent))
                    .disabled(!backedUp || syncing || !isReady)

                    Button("Not now (signs out, changes nothing)") {
                        Task {
                            await sync.declineFirstSync()
                            dismiss()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .tint(Theme.muted)
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .navigationTitle("Your first sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    /// True once the review is ready to act on.
    private var isReady: Bool {
        if case .review = sync.phase { return sync.status.error == nil }
        return false
    }

    /// The counts, table by table, then what happens to the profile and progress.
    private func summary(_ review: SyncReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(review.tables, id: \.table) { table in
                if !table.isQuiet {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reviewTableName(table.table))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(line(table))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if review.tables.allSatisfy(\.isQuiet) {
                Text("Your lists already match the web.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
            }
            if review.profileFromWeb {
                Text("Your profile and settings come from the web.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            if review.gameFromWeb {
                Text("Your progress comes from the web.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            if review.differ > 0 {
                Text("Where the phone and the web both have an item but it isn't the same, the web's version is kept. A note keeps this phone's version too, as a \"Conflicted copy\".")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "3 go to the web · 5 come from the web · 1 differs", leaving out zeros.
    private func line(_ table: TableReview) -> String {
        var parts: [String] = []
        let toWeb = table.toWeb + table.changedHere
        if toWeb > 0 { parts.append("\(toWeb) go to the web") }
        if table.fromWeb > 0 { parts.append("\(table.fromWeb) come from the web") }
        if table.differ > 0 { parts.append("\(table.differ) differ (the web's kept)") }
        if table.removedHere > 0 { parts.append("\(table.removedHere) removed here") }
        if table.same > 0 { parts.append("\(table.same) already match") }
        return parts.joined(separator: " · ")
    }
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/EmailPrefsCard.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   the Email switches of app/settings/page.tsx (`emailPrefs`,
//           `handleEmailPref`, `EmailPrefRow`) and their route,
//           app/api/email/prefs
//
//  Summary: Which ClassPing emails you get, one switch each. The settings
//           live on the server, not in the planner: the server sends the
//           email, and turning one off has to work even if this phone never
//           syncs again. A switch answers straight away and the change
//           follows; if the server doesn't take it, the switch goes back,
//           so it never shows something the server doesn't hold. Only shown
//           signed in.
//

import SwiftUI

struct EmailPrefsCard: View {
    @Environment(Store.self) private var store
    @Environment(SyncEngine.self) private var sync

    /// Your settings, or nil until they've loaded.
    @State private var prefs: EmailPrefs? = nil
    /// True when loading them failed.
    @State private var failed = false

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 12) {
            Text("EMAIL")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)

            if let prefs {
                ForEach(EmailStream.allCases, id: \.self) { stream in
                    // A `Binding` made on the spot: `get` reads the switch,
                    // `set` runs `flip` when you tap it.
                    Toggle(isOn: Binding(get: { prefs.isOn(stream) },
                                         set: { flip(stream, on: $0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stream.label)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text(stream.hint)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Theme.brand(accent))
                }
                if prefs.unsubscribedAll {
                    Text("You unsubscribed from all ClassPing email. Turn any switch back on to start receiving it again.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if failed {
                Text("Couldn't load your email settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                Button("Try again") { Task { await load() } }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(Theme.brand(accent))
            } else {
                Text("Loading your email settings…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        // Loads when the card appears, and again if you sign in as someone else.
        .task(id: sync.account.userID) { await load() }
    }

    /// Asks the server for your settings.
    private func load() async {
        failed = false
        let reply = await WebAPI.emailPrefs()
        if reply.ok, let loaded = EmailPrefs.fromServer(reply.body) {
            prefs = loaded
        } else {
            failed = prefs == nil
        }
    }

    /// One switch flipped: show it now, send it, and put it back if the
    /// server doesn't take it.
    private func flip(_ stream: EmailStream, on: Bool) {
        guard let current = prefs else { return }
        let change = current.setting(stream, on: on)
        prefs = change.shown
        Task {
            let reply = await WebAPI.setEmailPrefs(change.body)
            if !reply.ok { prefs = current }
        }
    }
}

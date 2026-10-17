//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card)
//  Ports:   the profile card and the Appearance / App color sections of
//           app/settings/page.tsx, moved into their own tab (D-19)
//
//  Summary: The Profile tab. For now: your avatar and name, the Appearance
//           card (moved here from Today), the Reminders card, and a list of
//           what arrives in this tab later. Phase 11 builds the full
//           settings, Phase 12 your level.
//

import SwiftUI

struct ProfileView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` lets the pickers write into the store (Phase 3).
        @Bindable var store = store
        let accent = store.profile.accent

        ScrollView {
            VStack(spacing: 16) {
                // Surface a failed local save beside the controls that caused it.
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                // MARK: You
                VStack(spacing: 10) {
                    AvatarBadge(name: store.profile.username, size: 84, accent: accent)
                    Text(store.profile.username.isEmpty ? "Your profile" : store.profile.username)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Your level, streak and trophies are coming soon.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .cardStyle()

                // MARK: Appearance
                // Moved from Today's temporary card (Phase 3). Phase 11 turns
                // this into the full Appearance section of the settings.
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("APPEARANCE")
                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)

                    Picker("App color", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // MARK: Reminders
                // NEW in Phase 7a: the after-class nudge and quiet hours.
                RemindersSection()

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    comingRow("graduationcap", "Grades & GPA")
                    // CHANGED in Phase 7a: the "Reminders and quiet hours" row
                    // is gone; it's the card above now.
                    comingRow("calendar", "Semester, backups, Recently Deleted")
                    comingRow("person.crop.circle", "Your name, photo and account")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Profile")
        // Save whenever a profile field changes, so the choice survives a
        // relaunch. CHANGED in Phase 5a: this moved here from TodayView.
        .onChange(of: store.profile) { store.save() }
    }

    /// The small spaced-out caps over each card, like the web's section labels.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// One upcoming feature, shown as a label until its screen is available.
    private func comingRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.faint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }
}

/// A round avatar: the first letter of your name on the brand gradient, or a
/// person symbol before you've set a name. The tab bar uses a small one, the
/// Profile tab a big one. Phase 11 adds your photo; Phase 12 the pet-tier ring.
struct AvatarBadge: View {
    let name: String
    let size: CGFloat
    let accent: Profile.Accent

    var body: some View {
        ZStack {
            Circle().fill(Theme.brandGradient(accent))
            // `.first` is the name's first character, or nil for an empty name.
            if let initial = name.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        // The tab's own label says "Profile", so VoiceOver skips the picture.
        .accessibilityHidden(true)
    }
}

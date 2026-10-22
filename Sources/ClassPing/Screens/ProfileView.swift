//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card),
//           11a (the settings: profile, grading scale, semester), 11b+c
//           (the calendar file, and your data: backups, Recently Deleted,
//           clearing), 13a (importing from your school) and 13b+ (the theme
//           and app-color pills, the rounded-square photo)
//  Ports:   app/settings/page.tsx, moved into its own tab (D-19): the
//           Profile, Appearance, Reminders (with its calendar export), Import
//           from your school, Grading scale and Semester cards, and the backup
//           rows of the Account card
//
//  Summary: The Profile tab is ClassPing's settings: you, the look, your
//           reminders and calendar, importing from your school, how letters
//           are worked out, the term, and your data. Your account arrives
//           with sync, your level in Phase 12.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` lets the pickers write into the store (Phase 3).
        @Bindable var store = store

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
                // CHANGED in Phase 11a: your photo and name, editable.
                ProfileCard()

                // Phase 9a: Grades now opens on Profile's navigation stack.
                NavigationLink {
                    GradesView()
                } label: {
                    HStack {
                        Label("Grades & GPA", systemImage: "graduationcap")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .frame(minHeight: 44)
                    .cardStyle()
                }

                // MARK: Appearance
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("APPEARANCE")
                    // CHANGED in Phase 13b+: round pills, each in its own color
                    // (D-88). Light is cream and Dark is charcoal whatever the
                    // phone is showing now; the chosen one has a ring and a check.
                    PillPicker(label: "Theme", selection: $store.profile.theme, options: [
                        .init(value: .light, title: "Light", colors: Theme.themePill(.light)),
                        .init(value: .dark, title: "Dark", colors: Theme.themePill(.dark))
                    ])
                    // NEW in Phase 11a: the web's line under each choice.
                    footnote(store.profile.theme == .dark
                             ? "Warm charcoal, with the same soft surfaces and your app color."
                             : "Switch to warm charcoal for late-night planning.")

                    sectionLabel("APP COLOR")
                        .padding(.top, 6)
                    // CHANGED in Phase 13b+: Baby Pink stays pink and Ocean stays
                    // blue, so you can see both while you're on either.
                    PillPicker(label: "App color", selection: $store.profile.accent, options: [
                        .init(value: .babypink, title: "Baby Pink", colors: Theme.accentPill(.babypink)),
                        .init(value: .ocean, title: "Ocean", colors: Theme.accentPill(.ocean))
                    ])
                    footnote("Baby Pink or Ocean, for your highlights and primary actions.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // MARK: Reminders
                RemindersSection()

                // MARK: Calendar
                // NEW in Phase 11b+c: the timetable as a .ics file. The web
                // puts this inside its Reminders card; here it's its own card.
                CalendarCard()

                // MARK: Import from your school
                // NEW in Phase 13a: a calendar or schedule file, as on the
                // web's Settings, between the calendar and the grading scale.
                ImportCard()

                // MARK: Grading scale
                // NEW in Phase 11a: moved here from the Grades screen (D-67).
                GradingSection()

                // MARK: Semester
                // NEW in Phase 11a.
                SemesterSection()

                // MARK: Your data
                // NEW in Phase 11b+c: back up, restore, Recently Deleted, clear.
                DataSection()

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    // CHANGED in Phase 11b+c: backups, Recently Deleted and
                    // the calendar are here now. Only your account is left.
                    comingRow("person.crop.circle", "Your account and sync")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        // NEW in Phase 11a: a swipe down the page puts the keyboard away.
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
        .navigationTitle("Profile")
        // Save whenever a profile field changes, so the choice survives a
        // relaunch. CHANGED in Phase 5a: this moved here from TodayView.
        .onChange(of: store.profile) { store.save() }
        // NEW in Phase 11b+c: "Backup restored" with its Undo shows here,
        // where the restore happened, as well as on the other tabs.
        .undoBar()
    }

    /// The small spaced-out caps over each card, like the web's section labels.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
    }

    /// The small grey line under a control. NEW in Phase 11a.
    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)
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

/// An avatar: your photo if you've chosen one, otherwise up to two initials
/// on the brand gradient, or a person symbol before you've set a name. It's
/// a circle by default (the tab bar's), or a rounded square when you give it a
/// `corner` (the Profile banner's). Phase 12 adds the pet-tier ring.
struct AvatarBadge: View {
    // NEW in Phase 11a: the photo comes from the store, so every badge
    // shows it without each caller passing it in.
    @Environment(Store.self) private var store

    let name: String
    let size: CGFloat
    let accent: Profile.Accent
    /// NEW in Phase 13b+: nil is a circle; a number is a rounded square with
    /// that corner radius. A default value means the older callers don't change.
    var corner: CGFloat? = nil

    /// The badge's outline. A rounded rectangle whose radius is half its side
    /// is a perfect circle, so one shape covers both looks.
    private var outline: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner ?? size / 2,
                         style: corner == nil ? .circular : .continuous)
    }

    var body: some View {
        ZStack {
            outline.fill(Theme.brandGradient(accent))
            // CHANGED in Phase 11a: two initials, as on the web ("KM").
            let letters = avatarInitials(name.trimmingCharacters(in: .whitespaces))
            if letters.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            } else {
                Text(letters)
                    .font(.system(size: size * (letters.count > 1 ? 0.36 : 0.42), weight: .bold))
                    .foregroundStyle(.white)
            }
            // NEW in Phase 11a: the photo, laid over the initials.
            if let uri = store.profile.avatarURL, uri.hasPrefix("data:image/") {
                AvatarPhoto(uri: uri)
            }
        }
        .frame(width: size, height: size)
        .clipShape(outline)
        // The tab's own label says "Profile", so VoiceOver skips the picture.
        .accessibilityHidden(true)
    }
}

/// A stored `data:` picture, turned back into an image once per picture
/// rather than on every redraw. NEW in Phase 11a.
private struct AvatarPhoto: View {
    let uri: String
    /// The decoded picture, or nil until it's ready (the initials show).
    @State private var image: UIImage? = nil

    var body: some View {
        // `Color.clear` takes the badge's size; the photo fills it, cropped.
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            // Runs when the badge appears and again when the picture changes.
            .task(id: uri) {
                image = avatarImageData(uri).flatMap { UIImage(data: $0) }
            }
    }
}

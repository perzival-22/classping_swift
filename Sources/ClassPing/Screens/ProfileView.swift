//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card),
//           11a (the settings: profile, grading scale, semester), 11b+c
//           (the calendar file, and your data: backups, Recently Deleted,
//           clearing), 13a (importing from your school), 13b+ (the theme
//           and app-color pills, the rounded-square photo), 14cd (your
//           account and sync) and 14e (email settings, rating the app)
//  Ports:   app/settings/page.tsx, moved into its own tab (D-19): the
//           Profile, Appearance, Reminders (with its calendar export), Import
//           from your school, Grading scale and Semester cards, and the backup
//           rows of the Account card
//
//  Summary: The Profile tab is ClassPing's settings: you, the look, your
//           reminders and calendar, importing from your school, how letters
//           are worked out, the term, your data and, since 14cd, your
//           account and sync. Signed in (14e), your email settings and a
//           card to rate the app join them. Your level arrives in Phase 12.
//

import SwiftUI
import UIKit

private enum ProfileCategory: String, Hashable, CaseIterable {
    case grades, profile, themes, reminders, imports, semester, data, rate

    var title: String {
        switch self {
        case .grades: "Grading scale & Grades"
        case .profile: "Profile"
        case .themes: "Themes"
        case .reminders: "Reminders"
        case .imports: "Imports"
        case .semester: "Semester"
        case .data: "Your data"
        case .rate: "Rate ClassPing"
        }
    }

    var detail: String {
        switch self {
        case .grades: "Choose your scale and view grades and GPA"
        case .profile: "Your profile, account, sync and account actions"
        case .themes: "Choose the appearance and app color"
        case .reminders: "Class alarms, quiet hours and email reminders"
        case .imports: "Import your school schedule"
        case .semester: "Dates, progress and start a new term"
        case .data: "Backups, deleted items and data controls"
        case .rate: "Share feedback about ClassPing"
        }
    }

    var symbol: String {
        switch self {
        case .grades: "graduationcap"
        case .profile: "person.crop.circle"
        case .themes: "paintpalette"
        case .reminders: "bell.badge"
        case .imports: "square.and.arrow.down"
        case .semester: "calendar"
        case .data: "externaldrive"
        case .rate: "star"
        }
    }
}

struct ProfileView: View {
    @Binding var tabBarCompact: Bool
    @Environment(Store.self) private var store
    // NEW in Phase 14e: the email and review cards need a sign-in.
    @Environment(SyncEngine.self) private var sync

    var body: some View {
        // `@Bindable` lets the pickers write into the store (Phase 3).
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 8) {
                // Surface a failed local save beside the controls that caused it.
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                NavigationLink(value: ProfileCategory.profile) {
                    profileBanner
                }
                .buttonStyle(.plain)
                // Grading and GPA lead the settings, followed by the other
                // compact category rows.
                ForEach(ProfileCategory.allCases, id: \.self) { category in
                    NavigationLink(value: category) {
                        categoryRow(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            // Leave a small clear runway after the last card so it can settle
            // above the tab bar and the optional undo strip.
            // Allow the final account controls to scroll clear of the floating
            // tab bar, including its raised center button.
            .padding(.bottom, 120)
        }
        .onScrollPhaseChange { _, phase in
            withAnimation(.easeInOut(duration: 1.0)) {
                tabBarCompact = phase.isScrolling
            }
        }
        // NEW in Phase 11a: a swipe down the page puts the keyboard away.
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
        .navigationTitle("Profile")
        .navigationDestination(for: ProfileCategory.self) { category in
            categoryPage(category)
        }
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

    private func categoryRow(_ category: ProfileCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.brand(store.profile.accent))
                .frame(width: 38, height: 38)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(category.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.hint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .cardStyle()
        .contentShape(Rectangle())
    }

    private var profileBanner: some View {
        HStack(spacing: 14) {
            AvatarBadge(name: store.profile.username, size: 58,
                        accent: store.profile.accent, corner: 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.85), lineWidth: 2)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.profile.username.isEmpty ? "Your profile" : store.profile.username)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Profile, account and sync")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Theme.brandGradient(store.profile.accent),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens profile and account settings")
    }

    @ViewBuilder
    private func categoryPage(_ category: ProfileCategory) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                switch category {
                case .grades:
                    NavigationLink {
                        GradesView()
                    } label: {
                        HStack {
                            Label("Grades & GPA", systemImage: "graduationcap")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(16)
                        .cardStyle()
                    }
                    GradingSection()
                case .profile:
                    ProfileCard()
                    AccountCard()
                case .themes:
                    themeSection
                case .reminders:
                    RemindersSection()
                    if sync.account.userID != nil { EmailPrefsCard() }
                    CalendarCard()
                case .imports:
                    ImportCard()
                case .semester:
                    SemesterSection()
                case .data:
                    DataSection()
                case .rate:
                    if sync.account.userID != nil {
                        ReviewCard()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sign in to share feedback about ClassPing.")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                            NavigationLink(value: ProfileCategory.profile) {
                                HStack {
                                    Text("Go to Profile and Account")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.brand(store.profile.accent))
                                .padding(16)
                                .cardStyle()
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 120)
        }
        .background(Theme.canvas)
        .navigationTitle(category.title)
        .scrollDismissesKeyboard(.interactively)
    }

    private var themeSection: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel("APPEARANCE")
            PillPicker(label: "Theme", selection: $store.profile.theme, options: [
                .init(value: .light, title: "Light", colors: Theme.themePill(.light)),
                .init(value: .dark, title: "Dark", colors: Theme.themePill(.dark))
            ])
            footnote(store.profile.theme == .dark
                     ? "Warm charcoal, with the same soft surfaces and your app color."
                     : "Switch to warm charcoal for late-night planning.")
            sectionLabel("APP COLOR").padding(.top, 6)
            PillPicker(label: "App color", selection: $store.profile.accent, options: [
                .init(value: .babypink, title: "Baby Pink", colors: Theme.accentPill(.babypink)),
                .init(value: .ocean, title: "Ocean", colors: Theme.accentPill(.ocean))
            ])
            footnote("Baby Pink or Ocean, for your highlights and primary actions.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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
            // CHANGED in Phase 14e: an uploaded (https) photo shows too.
            if let uri = store.profile.avatarURL, isPersistableAvatar(uri) {
                AvatarPhoto(uri: uri)
            }
        }
        .frame(width: size, height: size)
        .clipShape(outline)
        // The tab's own label says "Profile", so VoiceOver skips the picture.
        .accessibilityHidden(true)
    }
}

/// A stored picture, turned back into an image once per picture rather than
/// on every redraw. NEW in Phase 11a; CHANGED in Phase 14e: through
/// `AvatarLoader`, so an uploaded (https) photo is downloaded.
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
                image = await AvatarLoader.image(for: uri)
            }
    }
}

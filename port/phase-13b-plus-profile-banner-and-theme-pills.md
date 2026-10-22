---
title: "Phase 13b+: the profile banner and the theme pills"
date: 2026-10-21
---

# Phase 13b+: the profile banner and the theme pills

A look pass on the Profile tab, after your 13b (commit `ba8b0a9`, identical to
the 13b reference: all four files SAME, your tree built). It's two small stops
you can phone-check separately, both from your screenshot of the app (not the
web). Nothing new is stored, so there's no migration and no test change.

**Start here:** Stop 1 is the pills (three files). Stop 2 is the banner (two
files). Type Stop 1, build, look at it on your phone, then do Stop 2.

**What I changed from the plan you sent, and why (D-86 to D-88):**

- **"Dark text on Baby Pink" can't be our ink color.** I measured it.
  `Theme.ink` on `#E85D8A` is 3.7 : 1, which fails 4.5 : 1, and white is 3.3 : 1.
  Only the darker charcoal (`#26232A`) passes, at 4.7 : 1. So the pink pill
  uses charcoal text.
- **Ocean can't use the brand blue either.** `#3B82C4` gives white 4.1 : 1 and
  charcoal 3.0 : 1, both fail. The Ocean pill uses the deeper blue `#2A6BA8`
  (white on it: 5.6 : 1). It's a shade darker than the blue you see in the app
  once you pick Ocean, on purpose.
- **The fade has to be stronger than "a gradient on the bottom edge".** A fade
  that only darkens the last strip leaves white words at about 2.8 : 1 on a
  pure white photo. The fade here is 60% black from the middle of the banner
  down, which keeps white words at 5.7 : 1 or better.
- **Custom banner upload is not in this guide.** It needs a new profile field,
  an upload route on the server (a web change), a sweep that deletes the file
  when you delete your account, and a privacy line. That's server work, so it
  waits for sign-in in Phase 14 (D-87). The blurred photo is the default
  banner and needs none of that.

**Verification (2026-10-21):** the reference iOS build passed with no warnings.
No logic or store file changed, so the 568 logic and 132 store tests stand.
The guide's blocks laid over your `ba8b0a9` tree are identical to the
reference (see section 5). **Not checked on the phone, and I can't see the
screen from here**, so the layout and the keyboard hand-off (steps 7 and 8 in
section 5) are the parts most likely to need a tweak.

## 1. Goal

**On your phone, Profile tab:**

- The top card is now a banner: your photo blurred behind everything (or a
  gradient in your app color if you have no photo), a dark fade over the lower
  half, your photo as a rounded square on the left, your name as white text
  beside it, and a pencil on the right.
- The pencil opens a name field under the banner; the check mark that replaces
  it (or the keyboard's Done) saves the name and closes the field.
- Appearance now shows round pills. **Light** is cream, **Dark** is charcoal,
  **Baby Pink** is pink, **Ocean** is blue, always, whichever you're on. The
  chosen pill has a check mark and a ring around it.

## 2. New Swift concepts

### A blurred image that doesn't show a pale edge

`.blur(radius:)` smears a view. The smear fades out at the view's own edges, so
a blurred photo gets a pale rim. The fix is two lines: scale the photo up
first, then clip to the frame so the overflow is cut off.

```swift
Image(uiImage: photo)
    .resizable().scaledToFill()
    .blur(radius: 28)
    .scaleEffect(1.4)      // 40% bigger than its frame
// ...inside something with .clipped(), so the extra is cut off
```

The web does the same with CSS `filter: blur(28px)` plus `overflow: hidden`.

### A shape with a different radius on each corner

`RoundedRectangle` rounds all four corners the same. `UnevenRoundedRectangle`
takes one radius per corner, so the banner can round its top two and meet the
rest of the card flat at the bottom.

```swift
.clipShape(UnevenRoundedRectangle(
    topLeadingRadius: 15, bottomLeadingRadius: 0,
    bottomTrailingRadius: 0, topTrailingRadius: 15,
    style: .continuous))
```

### A generic view

`PillPicker<Value: Hashable>` is one view that edits "some value", the theme
enum in one place and the accent enum in another. `Value` is a stand-in; the
compiler fills it in from the `selection` you hand it. You met generic
functions in Phase 4a; this is the same idea on a `struct`.

```swift
struct Box<Thing: Hashable> { let thing: Thing }
let a = Box(thing: 3)       // Thing is Int
let b = Box(thing: "hi")    // Thing is String
```

## 3. What it maps from the web

Nothing, on purpose. `app/settings/page.tsx` has no banner and plain buttons
for Light/Dark and the two app colors. This is a phone-only look change and
stores nothing new, so the phone and the web stay compatible (D-86, D-88). If
you ever want the banner on the web, that's a new feature for both apps and
goes on the "after the app" list first.

Two small differences from the web's Profile card: the "PROFILE" label above
the card is gone (the screen's title already says Profile), and the username
field is hidden until you tap the pencil.

Colors, measured (text on its own pill):

| Pill | Fill | Text | Contrast |
|---|---|---|---|
| Baby Pink | `#E85D8A` | `#26232A` | 4.7 : 1 |
| Ocean | `#2A6BA8` | white | 5.6 : 1 |
| Light | `#F5F3EF` | `#3A3530` | 10.9 : 1 |
| Dark | `#26232A` | white | 15.5 : 1 |
| Name on the banner, worst case (white photo) | 60% black | white | 5.7 : 1 |

## 4. Files, in the order to type them

### Stop 1: the pills

### 4.1 `~/ClassPing/Sources/ClassPing/Design/Theme+Pills.swift` (new file)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Pills.swift
//  Phase:   13b+ (the profile banner and the theme pills)
//  Ports:   nothing. The web's Appearance card uses plain buttons
//           (app/settings/page.tsx); this is a look change on the phone
//           alone (D-88).
//
//  Summary: The four colors of the Appearance pills: Baby Pink, Ocean,
//           Light (cream) and Dark (charcoal). Each pill always wears its
//           own color, whichever one is chosen right now, so Ocean stays
//           blue while you're on Baby Pink. Each fill comes with the text
//           color that reads on it (4.5 : 1 or better, measured in D-88).
//

import SwiftUI

extension Theme {
    /// What one pill is made of: the color behind it and the color of the
    /// words (and the check mark) drawn on it.
    struct PillColors {
        /// The pill's own color.
        let fill: Color
        /// The text on it. Never `Theme.ink`: ink is a light-mode color, and
        /// on Baby Pink it only reaches 3.7 : 1.
        let text: Color
    }

    // MARK: App color pills

    /// Baby Pink: the brand pink with charcoal text. White on this pink is
    /// only 3.3 : 1 and `Theme.ink` 3.7 : 1; charcoal (#26232A) is 4.7 : 1.
    private static let pinkPill = PillColors(
        fill: Color(hex: "#E85D8A"), text: Color(hex: "#26232A"))

    /// Ocean: the deep end of the blue with white text (5.6 : 1). The brand
    /// blue (#3B82C4) fails both ways, 4.1 : 1 with white, 3.0 : 1 with
    /// charcoal, so the pill uses `brandDeep`'s shade.
    private static let oceanPill = PillColors(
        fill: Color(hex: "#2A6BA8"), text: .white)

    // MARK: Light and Dark pills

    /// Light: the web's cream surface with ink text (10.9 : 1).
    private static let creamPill = PillColors(
        fill: Color(hex: "#F5F3EF"), text: Color(hex: "#3A3530"))

    /// Dark: the warm charcoal with white text (15.5 : 1).
    private static let charcoalPill = PillColors(
        fill: Color(hex: "#26232A"), text: .white)

    /// The pill for one of the two app colors.
    static func accentPill(_ a: Profile.Accent) -> PillColors {
        switch a {
        case .babypink: pinkPill
        case .ocean:    oceanPill
        }
    }

    /// The pill for Light or Dark.
    static func themePill(_ t: Profile.Theme) -> PillColors {
        switch t {
        case .light: creamPill
        case .dark:  charcoalPill
        }
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Screens/Profile/PillPicker.swift` (new file)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/PillPicker.swift
//  Phase:   13b+ (the profile banner and the theme pills)
//  Ports:   nothing: the web's Appearance choices are plain buttons
//           (app/settings/page.tsx). A phone-only look change (D-88).
//
//  Summary: A row of round pills where you pick one. Every pill is filled
//           with the color it applies, so you see Baby Pink and Ocean (or
//           Light and Dark) side by side. The chosen pill gets a ring around
//           it and a check mark, so "selected" never depends on a color.
//

import SwiftUI

/// A row of pills that edits one value. `Value` is a stand-in for any type
/// that can be compared and hashed (the theme enum, the accent enum), so one
/// view serves both pickers. That is a generic type: the angle brackets name
/// the stand-in, and the compiler fills it in from the `selection` you pass.
struct PillPicker<Value: Hashable>: View {
    /// One pill: the value it sets, its words and its colors.
    struct Option: Identifiable {
        let value: Value
        let title: String
        let colors: Theme.PillColors
        /// `ForEach` needs a stable id; the value itself is one.
        var id: Value { value }
    }

    /// What VoiceOver calls the whole row ("Theme", "App color").
    let label: String
    /// Written to when a pill is tapped.
    @Binding var selection: Value
    let options: [Option]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { option in
                pill(option)
            }
        }
        // VoiceOver reads the label, then each pill inside it.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// One pill, drawn from the outside in: the words, the color behind them,
    /// a hairline edge, a gap, and (if chosen) the ring.
    private func pill(_ option: Option) -> some View {
        let chosen = option.value == selection
        return Button {
            selection = option.value
        } label: {
            HStack(spacing: 6) {
                // The check shows beside the words, so a chosen pill is
                // marked by a shape, not only by its ring.
                if chosen {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(option.colors.text)
            // 44 points tall at the least, the size of a comfortable tap.
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(option.colors.fill, in: Capsule())
            // `strokeBorder` draws inside the shape's edge (`stroke` would
            // straddle it). The hairline keeps the cream pill visible on the
            // cream card and the charcoal one on the dark card.
            .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
            // A 4-point gap of card color, then the ring around the gap.
            // Unchosen pills keep the same gap so nothing shifts on a tap.
            .padding(4)
            .overlay {
                if chosen {
                    Capsule().strokeBorder(Theme.ink, lineWidth: 2.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (replaces your 13a file: the two pickers become pills, and `AvatarBadge` can now be a rounded square)

```swift
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
```

### 4.4 Stop 1 check: build and look

```bash
cd ~/ClassPing
xtool dev build        # expect no errors and no warnings
```

Then run it on your phone (section 5, steps 1 to 4). The Profile card on top
will still look the old way until Stop 2.

### Stop 2: the banner

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileBanner.swift` (new file)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileBanner.swift
//  Phase:   13b+ (the profile banner and the theme pills)
//  Ports:   nothing: the web's Profile card has no banner. A phone-only look
//           change, pure styling with nothing new stored (D-86).
//
//  Summary: The strip across the top of the Profile card. Behind it, your
//           photo blurred (or a gradient in your app color if you have no
//           photo yet); over that, a dark fade at the bottom so the words
//           stay readable on a bright photo; on top, your photo as a rounded
//           square, your name as plain text, and a pencil to edit the name.
//

import SwiftUI
import PhotosUI
// The SwiftUI half of PhotosUI, named by hand for xtool (see ProfileCard).
import _PhotosUI_SwiftUI
import UIKit

struct ProfileBanner: View {
    @Environment(Store.self) private var store

    /// The name to show on the banner. While you're typing it, that's the
    /// draft, so the banner follows your keystrokes.
    let name: String
    let accent: Profile.Accent
    /// True while the name field below the banner is open.
    let editing: Bool
    /// The pencil was tapped (or the check mark that replaces it).
    let onEdit: () -> Void
    /// The photo chosen in the library; ProfileCard reads and saves it.
    @Binding var picked: PhotosPickerItem?

    /// The decoded photo, or nil until it's ready (or if there is none).
    @State private var image: UIImage? = nil

    /// The banner is 150 points tall on every phone; the width is the card's.
    private let height: CGFloat = 150

    var body: some View {
        // Plain copies, read here: the picker's label below isn't drawn on
        // the main actor, where the store lives (the same care as Phase 11a).
        let shown = name
        let color = accent

        ZStack(alignment: .bottomLeading) {
            backdrop(color)
            scrim
            HStack(alignment: .bottom, spacing: 14) {
                PhotosPicker(selection: $picked, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        // A rounded square, not a rectangle (photos are cropped
                        // square) and not a circle (that stays the tab bar's).
                        AvatarBadge(name: shown, size: 88, accent: color, corner: 22)
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                            }
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Theme.brand(color), in: Circle())
                            .offset(x: 6, y: 6)
                    }
                }
                .accessibilityLabel("Change profile picture")

                // The name is text on the banner, not a field on a photo.
                Text(shown.isEmpty ? "Add your name" : shown)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white.opacity(shown.isEmpty ? 0.8 : 1))
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onEdit) {
                    Image(systemName: editing ? "checkmark" : "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel(editing ? "Done editing name" : "Edit name")
            }
            .padding(16)
        }
        .frame(height: height)
        // Only the top corners are rounded: the bottom meets the rest of
        // the card. `UnevenRoundedRectangle` takes one radius per corner.
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: Theme.Radius.card,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Theme.Radius.card,
            style: .continuous))
        // Decoded once per picture, not on every redraw (as AvatarPhoto does).
        .task(id: store.profile.avatarURL) {
            guard let uri = store.profile.avatarURL, uri.hasPrefix("data:image/") else {
                image = nil
                return
            }
            image = avatarImageData(uri).flatMap { UIImage(data: $0) }
        }
    }

    /// Behind everything: your photo blurred, or the brand gradient.
    @ViewBuilder
    private func backdrop(_ color: Profile.Accent) -> some View {
        if let image {
            // `Color.clear` takes the banner's size; the photo fills it,
            // cropped, then `blur` smears it. A blur fades at its own edges,
            // so the photo is scaled up 40% first and `clipped` trims the
            // overflow: no pale rim round the banner.
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 28)
                        .scaleEffect(1.4)
                }
                .clipped()
        } else {
            Theme.brandGradient(color)
        }
    }

    /// A dark fade over the lower half of the banner. It's clear in the top
    /// fifth, 60% black by the middle and 70% at the bottom, so white words
    /// in the lower half stay at 5.7 : 1 or better even over a pure white
    /// photo (D-86). The top of the photo stays visible.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.2),
                .init(color: .black.opacity(0.6), location: 0.5),
                .init(color: .black.opacity(0.7), location: 1)
            ],
            startPoint: .top, endPoint: .bottom)
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileCard.swift` (replaces your 11a file: the banner on top, the name field behind the pencil)

```swift

//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileCard.swift
//  Phase:   11a (settings: you, the look, grading and the term), changed in
//           13b+ (the banner)
//  Ports:   the Profile card of app/settings/page.tsx and the picture
//           handling of lib/avatar.ts (`fileToAvatarDataUrl`)
//
//  Summary: Your picture and your name, under a banner. Tap the picture to
//           choose a photo: it's cropped to a square, shrunk to 256 pixels
//           and kept in your profile, on the phone, until sync can upload it
//           (D-65). The name shows as text on the banner; the pencil opens a
//           field below it to change it (D-86). The name saves when you leave
//           the field. Both save as you go (D-68).
//

import SwiftUI
import PhotosUI
// The SwiftUI half of PhotosUI (`PhotosPicker`). Xcode adds this one by
// itself when a file imports both SwiftUI and PhotosUI; xtool's build
// doesn't, so it's named here (D-65).
import _PhotosUI_SwiftUI
import UIKit

struct ProfileCard: View {
    @Environment(Store.self) private var store

    /// The photo chosen in the picker, until it's been read and saved.
    @State private var picked: PhotosPickerItem? = nil
    /// The name as typed; saved when the field loses focus.
    @State private var name = ""
    @FocusState private var typing: Bool
    /// NEW in Phase 13b+: true while the name field is open under the banner.
    @State private var editing = false
    /// What went wrong with the last photo or save, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        // CHANGED in Phase 13b+: while the field is open the banner shows what
        // you're typing; otherwise it shows the saved name.
        let shown = editing ? name.trimmingCharacters(in: .whitespaces)
                            : store.profile.username

        // Spacing 0: the banner runs edge to edge, so the card's padding
        // moves to the part under it.
        VStack(spacing: 0) {
            // NEW in Phase 13b+: the banner replaces the old "PROFILE" label
            // and the centered round picture.
            ProfileBanner(name: shown, accent: accent, editing: editing,
                          onEdit: toggleEditing, picked: $picked)

            VStack(spacing: 10) {
                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                } else {
                    Text("Tap your photo to change it")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                // Back to initials. The web has no way to do this; it's one button.
                if store.profile.avatarURL != nil {
                    Button("Remove photo") {
                        problem = store.setAvatar(nil) ? nil : "Couldn't save on this device. Try again."
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
                }

                // NEW in Phase 13b+: the field only exists while you're
                // editing, so the card is just the banner the rest of the time.
                if editing {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("USERNAME")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(Theme.faint)
                        TextField("Your name", text: $name)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($typing)
                            .submitLabel(.done)
                            .onSubmit { typing = false }
                            .inputField(accent)
                            // The field appears when you tap the pencil, so
                            // it takes the keyboard as it arrives.
                            .onAppear { typing = true }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .onAppear { name = store.profile.username }
        // Leaving the field saves it, as the web saves the term name on blur,
        // and closes the field. CHANGED in Phase 13b+: it also closes it.
        .onChange(of: typing) { _, isTyping in
            if !isTyping && editing {
                saveName()
                editing = false
            }
        }
        // A new pick: read it, shrink it, save it. `.task(id:)` cancels the
        // last one if you pick again before it finishes.
        .task(id: picked) {
            guard let item = picked else { return }
            await use(item)
            // Cleared, so choosing the same photo again still counts as new.
            picked = nil
        }
    }

    /// The banner's pencil (or its check mark). Open: show the field with the
    /// saved name in it. Closed: put the keyboard away, which saves the name
    /// through `onChange(of: typing)` above. NEW in Phase 13b+.
    private func toggleEditing() {
        if editing {
            typing = false
        } else {
            name = store.profile.username
            editing = true
        }
    }

    /// Saves the typed name. A blank one goes back to the saved name.
    private func saveName() {
        if store.setUsername(name) {
            name = store.profile.username
            problem = nil
        } else {
            problem = "Couldn't save on this device. Try again."
        }
    }

    /// Reads the chosen photo, turns it into the profile's `data:` address and
    /// saves it. `loadTransferable` asks the photo library for the bytes;
    /// `try?` turns a failure into nil.
    private func use(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            problem = AvatarProblem.decodeFailed.message
            return
        }
        switch avatarURI(from: data) {
        case .success(let uri):
            problem = store.setAvatar(uri) ? nil : "Couldn't save on this device. Try again."
        case .failure(let reason):
            problem = reason.message
        }
    }
}

/// A picked photo as the profile's picture: cropped to its middle square,
/// scaled to 256 pixels, laid on white (JPEG has no transparency), then
/// saved as JPEG at the best quality that fits the size limit. The web's
/// `fileToAvatarDataUrl`. `Result` carries either the address or the reason.
@MainActor
func avatarURI(from data: Data) -> Result<String, AvatarProblem> {
    guard data.count <= AVATAR_MAX_INPUT_BYTES else { return .failure(.tooLarge) }
    guard let image = UIImage(data: data) else { return .failure(.notAnImage) }
    let side = min(image.size.width, image.size.height)
    guard side > 0 else { return .failure(.decodeFailed) }

    // A renderer draws into a fresh picture of a fixed size. Scale 1 means
    // 256 real pixels, not 256 points times the screen's density.
    let size = CGFloat(AVATAR_SIZE)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
    // Scaled so the short side is 256, centered, so the overflow is cropped evenly.
    let scale = size / side
    let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let frame = CGRect(x: (size - drawn.width) / 2, y: (size - drawn.height) / 2,
                       width: drawn.width, height: drawn.height)

    for quality in AVATAR_QUALITY_STEPS {
        let jpeg = renderer.jpegData(withCompressionQuality: quality) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            image.draw(in: frame)
        }
        if let uri = avatarDataURI(jpeg: jpeg) { return .success(uri) }
    }
    // Even the lowest quality is too big: refuse rather than bloat the planner.
    return .failure(.tooLarge)
}
```

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 568 (unchanged)
scripts/test-store.sh     # expect 132 (unchanged)
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

**After Stop 1:**

1. **The pills:** Profile tab, APPEARANCE. Light is cream and Dark is
   charcoal, side by side; APP COLOR shows a pink Baby Pink and a blue Ocean.
   The chosen one has a check mark and a ring.
2. **Both colors show at once:** pick Ocean. Baby Pink is still pink. Pick
   Baby Pink again. Same for Light and Dark: switch to Dark and the Light pill
   is still cream.
3. **Readable:** the words on all four pills are easy to read. On Baby Pink
   they're dark, on Ocean they're white.
4. **Both themes:** with the phone in light mode and then dark mode, the cream
   pill and the charcoal pill both still have a visible edge, and the ring is
   easy to see on whichever is chosen.

**After Stop 2:**

5. **With a photo:** the top card shows your photo blurred as the background,
   a dark fade at the bottom, your photo as a rounded square (not a circle)
   on the left, your name in white. No pale rim round the edges.
6. **Without a photo:** tap **Remove photo**. The banner becomes a gradient in
   your app color, the square shows your initials, the name is still white and
   readable. Switch the app color and the gradient follows.
7. **Edit the name:** tap the pencil. A USERNAME field appears under the banner
   with the keyboard up and your name in it, and the banner follows what you
   type. Tap the check mark on the banner (or Done on the keyboard): the field
   closes and the name stays. Close the app fully and reopen: still saved.
   Clearing the field and tapping the check keeps your old name.
8. **Swipe to dismiss:** open the field again and swipe down on the page. The
   keyboard goes, the name saves, the field closes.
9. **A bright photo:** pick a very light photo (a white wall, a document).
   The name is still easy to read.
10. **Bigger text:** Settings, Display, Text Size, drag it up. The name wraps
    to two lines without leaving the banner. At the very biggest sizes it may
    grow past the fade; tell me if it does.
11. **The tab bar:** the little avatar in the tab bar is still a circle.

**Report back:** anything that looks off in steps 5 to 8 (those are the ones I
couldn't see), ideally with a screenshot.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] `xtool dev build` has no errors or warnings after each stop
- [ ] The four pills are cream, charcoal, pink and blue in both phone themes
- [ ] The chosen pill has a check mark and a ring
- [ ] The banner shows the blurred photo, or the gradient with no photo
- [ ] The name is readable on a bright photo
- [ ] The pencil opens the field, the check mark or a swipe saves it
- [ ] The tab bar avatar is still a circle

## 7. If it breaks

- **`Cannot infer contextual base type for '.init'` in ProfileView.** The
  `options:` list needs the `PillPicker`'s `selection` to be known first. Check
  the `selection:` argument is written before `options:`, as in 4.3, and that
  `Profile.Theme` and `Profile.Accent` are the enums' real names in
  `Profile.swift`.
- **`Value of type 'Theme' has no member 'themePill'`.** `Theme+Pills.swift`
  is missing, or the file isn't in `Sources/ClassPing/Design/`.
- **`Cannot find 'ProfileBanner' in scope`.** You typed 4.6 before 4.5. Add the
  banner file first.
- **`Extra argument 'corner' in call`.** `ProfileView.swift` (4.3) is still the
  old one; `AvatarBadge` gains `corner` there.
- **A pale rim round the blurred photo.** The `.scaleEffect(1.4)` or the
  `.clipped()` line is missing in `backdrop`.
- **The field appears but the keyboard doesn't.** Tell me which iOS version
  you're on. The `.onAppear { typing = true }` hand-off is the part I couldn't
  try on a device, and the fix would be one line.

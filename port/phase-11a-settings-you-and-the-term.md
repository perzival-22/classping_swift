---
title: "Phase 11a: Settings, you, the look, grading and the term"
date: 2026-10-20
---

# Phase 11a: Settings, you, the look, grading and the term

First of three parts of Phase 11 (D-70). It builds on your committed 10b
(`11e4586`): your tree is identical to the 10b reference, and on 2026-10-20
you confirmed the sound plays locked with working lock-screen buttons.

**Your three answers, built in:** the photo is picked from your library and
kept on the phone (D-65); backups will use the web's file format (D-66, that's
11b); the grading scale card moves from the Grades screen to the Profile tab,
where the web keeps it in Settings (D-67).

**One thing to know before you test:** "Start a new term" archives every class
on your timetable, and neither app has a way to un-archive one (the web has
the store function but no button). Section 5 step 9 tests it only as far as
Cancel unless you're ready to file your real classes away.

**Changed after typing (D-71):** 4.6 now shows your version of `range(for:)`,
which leaves both date pickers free. The first version kept the start
before the end, which made step 8 impossible whenever the start was today.

**Start here:** type six new Swift files (4.1 to 4.6), replace two (4.7
`ProfileView.swift`, 4.8 `GradesView.swift`, where three spots change), copy
three test files and add one word to `scripts/test-store.sh` (4.9).

**Verification (2026-10-20):** the reference iOS build passed with no
warnings. 420/420 logic tests passed in the default zone and in
America/New_York (+15: `AvatarTests` 7, `TermTests` 8, every web line printed
by the web's own code with node). 78/78 reference store tests (+8 in
`ProfileStoreTests`). The eight guide blocks laid over your tree are identical
to the reference, and that tree built with no warnings. Your own suites with
the new test files, against the new source: 420/420 and 90/90. No 11a phone check has
happened yet.

## 1. Goal

The Profile tab becomes ClassPing's settings: your photo and name, the look,
your reminders, the grading scale, and the semester.

**On your phone:** Profile tab → tap your picture → choose a photo. It shows
in the card and in the tab bar, and it's still there after you close the app.
Further down, name the term, set its first and last days, and read "Week 8 of
16 · 60 days to go."

This part includes:

- **Your photo,** cropped to a square, shrunk to 256 pixels and stored inside
  your profile the way the web stores one before it's uploaded. **Remove
  photo** goes back to your initials.
- **Your name,** saved when you leave the field. Initials now use two letters,
  as on the web: "kelvin.m" is **KM**.
- **Appearance,** with the web's line under each choice.
- **The grading scale card,** moved, not changed. The Grades screen keeps one
  line saying which scale the letters use.
- **The semester:** its name, its first and last days (these already limit
  Today and the week grid since 6a), a progress bar with "Week X of Y", and
  **Start a new term**, which archives this term's classes under its name.

## 2. New Swift concepts

### Picking a photo

`PhotosPicker` is a button that opens the system's photo picker. The picker
runs outside your app, so ClassPing never sees the rest of your library and
iOS asks no permission. What you choose arrives as a `PhotosPickerItem`, and
`loadTransferable(type:)` asks the library for its bytes:

```swift
@State private var picked: PhotosPickerItem? = nil

PhotosPicker(selection: $picked, matching: .images) {
    Text("Choose a photo")
}
.task(id: picked) {                 // runs again each time you pick
    guard let item = picked else { return }
    let data = try? await item.loadTransferable(type: Data.self)
}
```

`PhotosPicker` lives in a small module with an odd name, `_PhotosUI_SwiftUI`.
Xcode adds it by itself when a file imports both SwiftUI and PhotosUI; xtool's
build doesn't (the reference build failed with "cannot find type
'PhotosPickerItem'" until it was named), so `ProfileCard.swift` imports it
directly. The underscore is Apple's, not a hack of ours: it's a real
framework in the SDK and on the phone.

### Drawing a new picture

`UIGraphicsImageRenderer` draws into a fresh picture of a size you choose and
hands it back as JPEG bytes. `format.scale = 1` means 256 real pixels, not 256
points times the screen's density:

```swift
let format = UIGraphicsImageRendererFormat()
format.scale = 1
let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
let jpeg = renderer.jpegData(withCompressionQuality: 0.82) { context in
    image.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))
}
let uri = "data:image/jpeg;base64," + jpeg.base64EncodedString()
```

Base64 turns bytes into plain letters, so the picture can sit inside
planner.json as text. That's exactly what the web's `canvas.toDataURL` makes.

### Saving when you leave a field, and `Result`

You met `@FocusState` in 9b+. Here it decides when to save: watching it with
`onChange` catches the moment the field loses focus.

```swift
@FocusState private var typing: Bool

TextField("Your name", text: $name).focused($typing)
    .onChange(of: typing) { _, isTyping in
        if !isTyping { store.setUsername(name) }
    }
```

`avatarURI(from:)` hands back either the picture or the reason it failed.
`Result<String, AvatarProblem>` is a type made for that: `.success(value)` or
`.failure(reason)`, read with a `switch`:

```swift
switch avatarURI(from: data) {
case .success(let uri): store.setAvatar(uri)
case .failure(let reason): problem = reason.message
}
```

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| The limits, `isPersistableAvatar` and `avatarErrorMessage` in `lib/avatar.ts`; the `initials` line of `app/settings/page.tsx` | `Logic/Avatar.swift` |
| `fileToAvatarDataUrl` in `lib/avatar.ts` | `avatarURI(from:)` in `ProfileCard.swift` |
| The Profile card of `app/settings/page.tsx` (photo, username) | `Screens/Profile/ProfileCard.swift` |
| `setProfile` for username, avatar, term name and dates; `archiveTerm` in `lib/store.tsx` | `Store+Profile.swift` |
| The Appearance card | `ProfileView.swift` (the two lines added) |
| The grading card | `Screens/Profile/GradingSection.swift` (moved from `GradesView`) |
| The Semester card, `CurrentTerm`, `DateBox` | `Screens/Profile/SemesterSection.swift`, `Logic/Term.swift` |

Where the phone differs:

- **The photo stays on the phone (D-65).** The web keeps a picked photo as a
  `data:` address and uploads it when you press Save; there's no upload until
  sign-in and sync (Phase 14), so the phone keeps the same address in
  planner.json. Same size limit (240,000 characters, about 180 KB).
- **No Save button (D-68).** The photo saves when you pick it, the name when
  you leave the field, like the web's term name and dates already do.
- **Remove photo.** The web has no way back to initials; it's one button here.
- **No name shows a person symbol,** as since 5a. The web shows "?".
- **The grading scale lives in Profile (D-67),** with one line about it left
  on the Grades screen.
- **"Starts in N days" counts the real days (D-69).** The web's count is
  `totalDays - remainingDays + 1`, which is 1 whenever a term hasn't started:
  node printed "Starts in 1 day" for terms 1, 9 and 31 days away. The phone
  counts from today to the first day, and says "1 week long" for a one-week
  term. The web is unchanged; say if you want it fixed there too.
- **Dates are buttons until set.** An iOS date picker can't be empty, so an
  unset day shows **Add date**, and a set one has a clear button.

Web behavior kept on purpose: the wording on every card, the 64-character
term name, an end date before the start allowed (and called out), the
two-step archive (name it, then Archive) with no undo, archived classes
keeping their grades under the term name, and the term's name and dates
cleared after archiving so next semester doesn't inherit them.

## 4. Files, in the order to type them

Six new files, then two replaced. Build once all of them are in.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/Avatar.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Avatar.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   lib/avatar.ts (the limits, `isPersistableAvatar`, the error
//           messages) and the `initials` line of app/settings/page.tsx
//
//  Summary: The rules for your profile picture, Foundation only. A photo is
//           kept the way the web keeps one before it's uploaded: as a small
//           JPEG written into the profile itself as a `data:` address, so it
//           survives a relaunch, travels in a backup, and syncs later (D-65).
//

import Foundation

/// The stored picture is a square this many pixels on a side. `SIZE`.
let AVATAR_SIZE = 256
/// Pictures bigger than this aren't even opened. `MAX_INPUT_BYTES`.
let AVATAR_MAX_INPUT_BYTES = 12 * 1024 * 1024
/// The longest `data:` address allowed, about 180 KB of picture: it rides in
/// planner.json and, later, in every sync. `MAX_ENCODED_CHARS`.
let AVATAR_MAX_ENCODED_CHARS = 240_000
/// JPEG qualities to try, best first, until one fits. `QUALITY_STEPS`.
let AVATAR_QUALITY_STEPS: [Double] = [0.82, 0.7, 0.55, 0.4]

/// What can go wrong picking a picture. `AvatarError`.
enum AvatarProblem: Error, Equatable {
    case notAnImage, tooLarge, decodeFailed

    /// What the screen says. `avatarErrorMessage` on the web.
    var message: String {
        switch self {
        case .notAnImage: "That file isn't an image."
        case .tooLarge: "That image is too large, try a smaller one."
        case .decodeFailed: "Couldn't read that image. Try another."
        }
    }
}

/// Up to two letters for the round badge: the first letter of the first two
/// parts of your name, split at dots, spaces, underscores and dashes.
/// "kelvin.m" -> "KM", "Kelvin" -> "K". The web's `initials`; the web shows
/// "?" for no name, the phone keeps 5a's person symbol, so this gives "".
func avatarInitials(_ name: String) -> String {
    // Empty parts are kept, as JavaScript's `split` keeps them: "kelvin  m"
    // (two spaces) is ["kelvin", "", "m"], whose first two give just "K".
    let parts = name.split(omittingEmptySubsequences: false,
                           whereSeparator: { ".-_".contains($0) || $0.isWhitespace })
    return parts.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
}

/// True for a saved picture that can still be shown after a relaunch: a
/// `data:image/` address, or an https link (an upload, once sync exists).
/// The web's old `blob:` addresses are dead by then. `isPersistableAvatar`.
func isPersistableAvatar(_ url: String?) -> Bool {
    guard let url else { return false }
    return url.hasPrefix("data:image/") || url.hasPrefix("https://")
}

/// A JPEG as the `data:` address the profile stores, the web's
/// `canvas.toDataURL("image/jpeg")`. Nil when it's longer than the limit.
func avatarDataURI(jpeg: Data) -> String? {
    let uri = "data:image/jpeg;base64," + jpeg.base64EncodedString()
    return uri.count <= AVATAR_MAX_ENCODED_CHARS ? uri : nil
}

/// The picture's bytes back out of a stored `data:image/…;base64,` address,
/// or nil for anything else (an https link waits for sync).
func avatarImageData(_ url: String?) -> Data? {
    guard let url, url.hasPrefix("data:image/"),
          let comma = url.firstIndex(of: ",") else { return nil }
    return Data(base64Encoded: String(url[url.index(after: comma)...]))
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/Term.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Term.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the lines under the dates in `CurrentTerm` (app/settings/page.tsx)
//
//  Summary: What the Semester card says under the two dates: whether your
//           classes are limited to the window, how far through the term you
//           are, or what's missing. Foundation only, so it can be tested.
//           Fixes the web's "Starts in" count, which always said 1 day (D-69).
//

import Foundation

/// The words and the bar under the Semester card's dates.
struct TermNote: Equatable {
    /// Show "Your classes only appear inside this window…".
    var showsWindow: Bool
    /// The bar's fill, 0 to 1, or nil when there's no bar.
    var fraction: Double?
    /// The line under the bar, or under the dates when there's no bar.
    var line: String
}

/// The line the window note uses, word for word from the web.
let TERM_WINDOW_NOTE = "Your classes only appear inside this window, on Today, on the week grid, and in the calendar you export to your phone."

/// What to say for these dates ("yyyy-MM-dd" or nil) on the day `now` falls.
func termNote(start: String?, end: String?, now: Date) -> TermNote {
    let progress = termProgress(start, end, now)
    // Both dates there but no progress means the end is before the start.
    let inverted = start != nil && end != nil && progress == nil
    let showsWindow = (start != nil || end != nil) && !inverted

    guard let progress else {
        let line = inverted
            ? "The end date is before the start date, check the dates."
            : "Set both dates to see how far through the semester you are. They're printed on your grade report too."
        return TermNote(showsWindow: showsWindow, fraction: nil, line: line)
    }

    let line: String
    switch progress.phase {
    case .before:
        // Days from today to the first day. The web counts
        // `totalDays - remainingDays + 1`, which is 1 whenever the term
        // hasn't started, so it always said "Starts in 1 day" (D-69).
        let days = (start.flatMap(dayNumber) ?? 0) - todayNumber(now)
        line = "Starts in \(days) \(days == 1 ? "day" : "days"), \(progress.totalWeeks) \(progress.totalWeeks == 1 ? "week" : "weeks") long."
    case .after:
        line = "This term has ended. Archive it below to clear your timetable."
    case .during:
        let left = progress.remainingDays
        line = "Week \(progress.week) of \(progress.totalWeeks) \u{00B7} \(left) \(left == 1 ? "day" : "days") to go."
    }
    return TermNote(showsWindow: showsWindow, fraction: progress.fraction, line: line)
}

/// A "yyyy-MM-dd" day as the start of that day here, for a date picker, or
/// nil when it isn't a real day.
func dayStart(_ day: String?) -> Date? {
    deadlineDayStart(makeDeadline(day, nil))
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Store+Profile.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Profile.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the profile writes of app/settings/page.tsx (`handleSave`, the
//           Semester card's `setProfile` calls) and `archiveTerm` in
//           lib/store.tsx
//
//  Summary: Saving your name and picture, the term's name and dates, and
//           "Start a new term", which files this term's classes under its
//           name. Like the grade actions (D-49, D-53), each one only counts
//           once planner.json has it; a failed write puts things back.
//

import Foundation

extension Store {
    /// Your name, saved when you leave the field (the web saves it with the
    /// card's Save button, D-68). A blank name keeps the old one, as the
    /// web's `username.trim() || profile.username` does.
    @discardableResult
    func setUsername(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != profile.username else { return true }
        let before = profile.username
        profile.username = clean
        save()
        if lastSaveFailed { profile.username = before; return false }
        return true
    }

    /// Your picture as a `data:` address from Logic/Avatar.swift, or nil to
    /// go back to initials. Saved as soon as it's picked (D-68). Anything
    /// that couldn't be shown after a relaunch, or is over the size limit,
    /// is refused.
    @discardableResult
    func setAvatar(_ avatar: String?) -> Bool {
        if let avatar, !isPersistableAvatar(avatar) || avatar.count > AVATAR_MAX_ENCODED_CHARS {
            return false
        }
        let before = profile.avatarURL
        profile.avatarURL = avatar
        save()
        if lastSaveFailed { profile.avatarURL = before; return false }
        return true
    }

    /// The term's name, saved when the field loses focus, as the web saves on
    /// blur. Blank means none; the web's field stops at 64 characters.
    @discardableResult
    func setTermName(_ name: String) -> Bool {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        let next: String? = clean.isEmpty ? nil : clean
        if next == profile.termName { return true }
        let before = profile.termName
        profile.termName = next
        save()
        if lastSaveFailed { profile.termName = before; return false }
        return true
    }

    /// Sets or clears the semester's first and last days ("yyyy-MM-dd").
    /// A day that isn't real is refused. An end before the start is allowed,
    /// as on the web, and the card says so instead.
    @discardableResult
    func setTermDates(start: String?, end: String?) -> Bool {
        if let start, !isValidDate(start) { return false }
        if let end, !isValidDate(end) { return false }
        let before = (profile.termStart, profile.termEnd)
        profile.termStart = start
        profile.termEnd = end
        save()
        if lastSaveFailed {
            (profile.termStart, profile.termEnd) = before
            return false
        }
        return true
    }

    /// "Start a new term": every class still on the timetable is archived
    /// under `name` (`archiveTerm` in lib/store.tsx), then the term's name and
    /// dates are cleared so the next semester doesn't inherit them, as the
    /// web's Archive button does. Grades stay, now under that past term.
    @discardableResult
    func archiveTerm(_ name: String) -> Bool {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return false }
        let beforeCourses = courses
        let beforeProfile = profile
        // `indices` walks the positions, so each class can be changed in place.
        // Deleted classes too, as on the web: one restored from Recently
        // Deleted later belongs to the term it was part of.
        for i in courses.indices where !courses[i].archived {
            courses[i].archived = true
            courses[i].term = label
        }
        profile.termName = nil
        profile.termStart = nil
        profile.termEnd = nil
        save()
        if lastSaveFailed {
            courses = beforeCourses
            profile = beforeProfile
            return false
        }
        return true
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileCard.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileCard.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the Profile card of app/settings/page.tsx and the picture
//           handling of lib/avatar.ts (`fileToAvatarDataUrl`)
//
//  Summary: Your picture and your name. Tap the picture to choose a photo:
//           it's cropped to a square, shrunk to 256 pixels and kept in your
//           profile, on the phone, until sync can upload it (D-65). The name
//           saves when you leave the field. Both save as you go (D-68).
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
    /// What went wrong with the last photo or save, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        // Read here, not inside the picker's label: that label isn't drawn
        // on the main actor, where the store lives, so it gets a plain copy.
        let username = store.profile.username

        VStack(spacing: 14) {
            Text("PROFILE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            // The picture is the button. `PhotosPicker` opens your photo
            // library; what you choose arrives in `picked`.
            PhotosPicker(selection: $picked, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarBadge(name: username, size: 90, accent: accent)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.brand(accent), in: Circle())
                }
            }
            .accessibilityLabel("Change profile picture")

            if let problem {
                Text(problem)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
            } else {
                Text("Tap to change photo")
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
                    .onSubmit { saveName() }
                    .inputField(accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .onAppear { name = store.profile.username }
        // Leaving the field saves it, as the web saves the term name on blur.
        .onChange(of: typing) { _, isTyping in
            if !isTyping { saveName() }
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

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Profile/GradingSection.swift` (new file)

This is your Grades screen's `scalePicker`, moved into its own card with the
Profile tab's label style. Only the label and the card's frame changed.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/GradingSection.swift
//  Phase:   11a (settings), moved here from 9b's Grades screen (D-67)
//  Ports:   the grading card of app/settings/page.tsx
//
//  Summary: The Grading scale card in the Profile tab: A / A−, A / B / C or
//           Custom, a line about each, and for Custom the way into 9b's
//           scale editor. Moved, not changed: the same code that sat on the
//           Grades screen until there was a Settings to put it in (D-51).
//

import SwiftUI

struct GradingSection: View {
    @Environment(Store.self) private var store

    var body: some View {
        let selected = store.profile.gradeScale ?? .standard

        VStack(alignment: .leading, spacing: 10) {
            Text("GRADING SCALE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)
            // The choice goes through the store, which puts the old one back
            // if the write fails (D-53).
            Picker("Grade scale", selection: Binding(
                get: { store.profile.gradeScale ?? .standard },
                set: { store.setGradeScale($0) }
            )) {
                Text("A / A\u{2212}").tag(Profile.GradeScale.standard)
                Text("A / B / C").tag(Profile.GradeScale.simple)
                Text("Custom").tag(Profile.GradeScale.custom)
            }
            .pickerStyle(.segmented)

            // A line about the chosen scale; Custom adds the way into its editor.
            switch selected {
            case .standard:
                Text("93+ is an A, 90+ an A\u{2212}. The usual US scale.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            case .simple:
                Text("90+ is an A, 80+ a B. No plus or minus bands.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            case .custom:
                Text(store.usesFallbackScale
                     ? "Your custom scale is empty. Using US 4.0 for now."
                     : "Using your \(store.gradeScale.count) bands.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                NavigationLink {
                    GradeScaleEditor(saved: store.profile.customScale)
                } label: {
                    HStack {
                        Text(store.usesFallbackScale ? "Set up your scale" : "Edit your scale")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Profile/SemesterSection.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/SemesterSection.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the Semester card of app/settings/page.tsx, with `CurrentTerm`
//           and `DateBox`
//
//  Summary: The term's name and its first and last days, how far through it
//           you are, and "Start a new term", which files this term's classes
//           under its name so the timetable starts clean. The name saves when
//           you leave the field, a date as soon as you pick it, like the web.
//

import SwiftUI

struct SemesterSection: View {
    @Environment(Store.self) private var store

    /// The term name as typed; saved when the field loses focus.
    @State private var name = ""
    @FocusState private var typing: Bool

    /// "Start a new term" was tapped: the naming step is showing.
    @State private var archiving = false
    /// The name typed for the term being archived.
    @State private var archiveName = ""
    @FocusState private var namingArchive: Bool
    /// Shows "Term archived…" for a few seconds after it worked.
    @State private var archived = false
    /// A save that didn't reach planner.json, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        let start = store.profile.termStart
        let end = store.profile.termEnd
        // Live classes still on the timetable: what "Start a new term" files away.
        let classes = store.activeCourses.count

        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SEMESTER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.faint)
                    .accessibilityAddTraits(.isHeader)

                // MARK: Current term
                fieldLabel("CURRENT TERM")
                TextField("e.g. Fall 2025", text: $name)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                    // The web's field stops at 64 characters; so does this one.
                    .onChange(of: name) { _, typed in
                        if typed.count > 64 { name = String(typed.prefix(64)) }
                    }
                    .inputField(accent)

                // MARK: The two days
                dateRow("SEMESTER STARTS", day: start, accent: accent) { picked in
                    store.setTermDates(start: picked, end: store.profile.termEnd)
                }
                dateRow("SEMESTER ENDS", day: end, accent: accent) { picked in
                    store.setTermDates(start: store.profile.termStart, end: picked)
                }

                // MARK: How far through
                // `TimelineView` (5a) redraws this each minute, so the count
                // moves on at midnight without leaving the tab.
                TimelineView(.everyMinute) { context in
                    let note = termNote(start: start, end: end, now: context.date)
                    VStack(alignment: .leading, spacing: 8) {
                        if note.showsWindow {
                            Text(TERM_WINDOW_NOTE)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.faint)
                        }
                        if let fraction = note.fraction {
                            ProgressView(value: fraction)
                                .tint(Theme.brand(accent))
                            Text(note.line)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.muted)
                        } else {
                            Text(note.line)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                }

                // MARK: Start a new term
                if classes > 0 {
                    Divider().padding(.vertical, 4)
                    Text("Finished the semester? Archive these \(classes) \(classes == 1 ? "class" : "classes") to clear your timetable. Their grades stay on the Grades screen under the term name.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if archiving {
                        archiveStep(accent)
                    } else {
                        Button {
                            archiveName = store.profile.termName ?? ""
                            archiving = true
                        } label: {
                            Text("Start a new term")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.brand(accent))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            if archived {
                Text("Term archived, your timetable is clear. 🎉")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.brand(accent))
            }
        }
        .onAppear { name = store.profile.termName ?? "" }
        // Archiving (or anything else) changed the saved name: show it,
        // unless you're typing, so the field never writes a stale name back.
        .onChange(of: store.profile.termName) { _, saved in
            if !typing { name = saved ?? "" }
        }
        .onChange(of: typing) { _, isTyping in
            if !isTyping { saveName() }
        }
        // The "archived" line goes away after 4 seconds, as on the web.
        .task(id: archived) {
            guard archived else { return }
            try? await Task.sleep(for: .seconds(4))
            archived = false
        }
    }

    /// The small caps over a field, like the web's labels inside the box.
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.faint)
    }

    /// One of the semester's days. Unset: an "Add date" button. Set: a date
    /// picker, kept on its side of the other day, and a button to clear it.
    /// `save` gets the new day as "yyyy-MM-dd", or nil to clear it.
    private func dateRow(_ label: String, day: String?, accent: Profile.Accent,
                         save: @escaping (String?) -> Bool) -> some View {
        HStack {
            fieldLabel(label)
            Spacer()
            if let date = dayStart(day) {
                DatePicker(label, selection: Binding(
                    get: { date },
                    set: { report(save(dayOf($0))) }
                ), in: range(for: label), displayedComponents: .date)
                .labelsHidden()
                .tint(Theme.brand(accent))
                Button {
                    report(save(nil))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.faint)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear \(label.lowercased())")
            } else {
                Button("Add date") {
                    report(save(dayOf(firstGuess(for: label))))
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(minHeight: 44)
                .tint(Theme.brand(accent))
            }
        }
    }

    /// Either date can be moved independently. The web allows an end before
    /// the start and calls that out in the card, so don't clamp one to the
    /// other here.
    private func range(for _: String) -> ClosedRange<Date> {
        Date.distantPast...Date.distantFuture
    }

    /// Where "Add date" starts you: today, unless that would land on the
    /// wrong side of the other day; then the other day itself.
    private func firstGuess(for label: String) -> Date {
        let today = Calendar.current.startOfDay(for: .now)
        if label == "SEMESTER STARTS" {
            return min(today, dayStart(store.profile.termEnd) ?? today)
        }
        return max(today, dayStart(store.profile.termStart) ?? today)
    }

    /// Shows the save message when a write didn't reach planner.json.
    private func report(_ saved: Bool) {
        problem = saved ? nil : "Couldn't save on this device. Try again."
    }

    /// Saves the typed term name, then shows it as saved (trimmed).
    private func saveName() {
        report(store.setTermName(name))
        name = store.profile.termName ?? ""
    }

    /// Naming the term being archived, then Cancel or Archive.
    @ViewBuilder
    private func archiveStep(_ accent: Profile.Accent) -> some View {
        fieldLabel("NAME THIS TERM")
        TextField("e.g. Fall 2025", text: $archiveName)
            .focused($namingArchive)
            .submitLabel(.done)
            .inputField(accent)
        HStack(spacing: 10) {
            Button {
                archiving = false
                archiveName = ""
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.muted)

            Button {
                namingArchive = false
                if store.archiveTerm(archiveName) {
                    archiving = false
                    archiveName = ""
                    problem = nil
                    archived = true
                } else {
                    report(false)
                }
            } label: {
                Text("Archive")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand(accent))
            .disabled(archiveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (replaces your 7a file)

The "You" block is now `ProfileCard`, the Appearance card gains two lines and
its APP COLOR label, `GradingSection` and `SemesterSection` join the list,
the Coming card shrinks, and `AvatarBadge` shows your photo and two initials.
`RootView` calls `AvatarBadge` exactly as before, so it doesn't change.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week), changed in 7a (Reminders card)
//           and 11a (the settings: profile, grading scale, semester)
//  Ports:   app/settings/page.tsx, moved into its own tab (D-19): the
//           Profile, Appearance, Reminders, Grading scale and Semester cards
//
//  Summary: The Profile tab is ClassPing's settings: you, the look, your
//           reminders, how letters are worked out, and the term. Backups,
//           Recently Deleted and the calendar export arrive in 11b and 11c,
//           your account with sync, your level in Phase 12.
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
                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)
                    // NEW in Phase 11a: the web's line under each choice.
                    footnote(store.profile.theme == .dark
                             ? "Warm charcoal, with the same soft surfaces and your app color."
                             : "Switch to warm charcoal for late-night planning.")

                    sectionLabel("APP COLOR")
                        .padding(.top, 6)
                    Picker("App color", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                    footnote("Baby Pink or Ocean, for your highlights and primary actions.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // MARK: Reminders
                RemindersSection()

                // MARK: Grading scale
                // NEW in Phase 11a: moved here from the Grades screen (D-67).
                GradingSection()

                // MARK: Semester
                // NEW in Phase 11a.
                SemesterSection()

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    // CHANGED in Phase 11a: name, photo and semester are here now.
                    comingRow("externaldrive", "Backups, Recently Deleted, calendar export")
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

/// A round avatar: your photo if you've chosen one, otherwise up to two
/// initials on the brand gradient, or a person symbol before you've set a
/// name. The tab bar uses a small one, the Profile tab a big one. Phase 12
/// adds the pet-tier ring.
struct AvatarBadge: View {
    // NEW in Phase 11a: the photo comes from the store, so every badge
    // shows it without each caller passing it in.
    @Environment(Store.self) private var store

    let name: String
    let size: CGFloat
    let accent: Profile.Accent

    var body: some View {
        ZStack {
            Circle().fill(Theme.brandGradient(accent))
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
        .clipShape(Circle())
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

### 4.8 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift` (replaces your 9c file)

Three spots change, so editing beats retyping: the header comment (lines 3
to 8), `scalePicker` under `FinalsCountdown()` becomes the footnote `Text`,
and the whole `private var scalePicker` at the bottom becomes the short
`private var scaleName`. The full file, so you can check:

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift
// Phase: 9a, extended in 9b, 9c and 11a
// Ports: app/grades/page.tsx, reached from Profile (D-19).
// Summary: This term's credit-weighted GPA, results and separate past terms.
// 9b adds the projected GPA and a goal on each class, 9c the finals
// countdown and the term report. 11a moves the grading scale to the Profile
// tab, where the web keeps it in Settings (D-67); a line here names it.
//
import SwiftUI

struct GradesView: View {
    @Environment(Store.self) private var store
    @State private var sheet: GradeSheet? = nil
    @State private var deleting: Grade? = nil

    /// One item binding avoids competing add and edit sheets.
    private struct GradeSheet: Identifiable {
        let id = UUID()
        var editing: Grade? = nil
        var courseID: UUID? = nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.lastSaveFailed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .foregroundStyle(Theme.danger)
                        Button("Retry save") { store.save() }
                    }
                    .font(.footnote)
                }
                overview
                // NEW in Phase 9c: under the GPA, where the web's phone layout
                // puts it.
                FinalsCountdown()
                // CHANGED in Phase 11a: the scale card moved to the Profile tab
                // (D-67). One line still says which scale the letters use.
                Text("Letters use the \(scaleName) scale. Change it under Profile \u{2192} Grading scale.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                if store.activeCourses.isEmpty {
                    Text("No classes in this term yet. Add a class to start logging grades.")
                        .foregroundStyle(Theme.muted)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
                ForEach(store.activeCourses) { course in courseCard(course, canAdd: true) }
                // NEW in Phase 9c: the report, once there's a term to describe
                // (the web shows it as soon as a class exists, grades or not).
                if !store.activeCourses.isEmpty {
                    TermReportCard()
                }
                ForEach(store.gradedPastTerms, id: \.self) { term in
                    pastTerm(term)
                }
            }
            .padding(16)
            // Keep the wider device layout readable without hardcoding a phone width.
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .navigationTitle("Grades")
        .tint(Theme.brand(store.profile.accent))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = GradeSheet(courseID: store.liveGrades.last?.courseID)
                } label: { Label("Add grade", systemImage: "plus") }
            }
        }
        .sheet(item: $sheet) { value in
            GradeFormView(editing: value.editing, courseID: value.courseID)
        }
        .alert("Delete this grade?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleting { store.deleteGrade(deleting.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("You can undo this deletion.")
        }
        .undoBar()
    }

    private var overview: some View {
        let gpa = overallGpa(store.activeCourses, store.liveGrades, store.gradeScale)
        let count = store.activeCourses.filter { !store.grades(for: $0.id).isEmpty }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT TERM GPA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            // CHANGED in Phase 9c: rounded like the web's toFixed (D-57), so
            // the card and the CSV report always show the same GPA.
            Text(gpa.map { jsFixed($0, 2) } ?? "—")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand(store.profile.accent))
                .monospacedDigit()
                .accessibilityLabel(gpa.map { "GPA \($0.formatted())" } ?? "No GPA yet")
            Text(count == 0 ? "Log your first result to see your GPA."
                 : "Across \(count) graded \(count == 1 ? "class" : "classes"). Weighted by credits; an unset credit counts as one.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            // NEW in Phase 9b: where the term lands if every goal is met.
            // Nil until a class has a goal, so it never just repeats the GPA.
            if let projected = projectedGpa(store.activeCourses, store.liveGrades, store.gradeScale) {
                HStack(spacing: 10) {
                    Image(systemName: "target")
                        .foregroundStyle(Theme.brand(store.profile.accent))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROJECTED BY END OF TERM")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.brandDeep(store.profile.accent))
                        Text("If you hit every goal you've set.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Text(jsFixed(projected, 2))   // CHANGED in Phase 9c (D-57)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.brandDeep(store.profile.accent))
                }
                .padding(12)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                // One VoiceOver stop: "Projected by end of term, 3.50".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Projected by end of term if you hit every goal, \(jsFixed(projected, 2))")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // NEW in Phase 11a
    /// The chosen scale's short name, for the line under the countdown.
    private var scaleName: String {
        switch store.profile.gradeScale ?? .standard {
        case .standard: "A / A\u{2212}"
        case .simple: "A / B / C"
        case .custom: store.usesFallbackScale ? "A / A\u{2212} (your custom one is empty)" : "custom"
        }
    }

    private func courseCard(_ course: Course, canAdd: Bool) -> some View {
        let grades = store.grades(for: course.id)
        let average = classAverage(grades)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SubjectBook(color: course.color, short: course.short, compact: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name).font(.headline).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    // CHANGED in Phase 9c: toFixed(1) rounding (D-57).
                    Text(average.map { "\(jsFixed($0, 1))% average" }
                         ?? "No grades logged yet")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    if course.credits != nil {
                        Text("\(creditsFor(course).formatted()) cr").font(.caption)
                    }
                }
                Spacer(minLength: 0)
                if let average {
                    Text(letterFor(average, store.gradeScale))
                        .font(.title2.bold())
                        .foregroundStyle(Theme.subjectInk(course.color))
                }
            }
            // NEW in Phase 9b: this term's classes (the ones you can add to)
            // get a goal and the "what do I need?" answer. Past terms don't.
            if canAdd {
                GoalCard(course: course, grades: grades)
            }
            ForEach(grades) { grade in
                Divider()
                gradeRow(grade)
            }
            if canAdd {
                Button {
                    sheet = GradeSheet(courseID: course.id)
                } label: { Label("Add grade", systemImage: "plus") }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Add grade for \(course.name)")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func gradeRow(_ grade: Grade) -> some View {
        HStack(alignment: .top) {
            Button {
                sheet = GradeSheet(editing: grade)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(grade.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(grade.score.formatted()) / \(grade.max.formatted()) · \(grade.weight.formatted())% weight")
                    Text("\(grade.date)\(grade.kind.map { " · \($0.rawValue.capitalized)" } ?? "")")
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit grade")
            Button(role: .destructive) { deleting = grade } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Delete \(grade.title)")
        }
    }

    /// Archived courses never dilute today's headline. Their GPA is calculated
    /// with the same selected scale, matching the web's separate term sections.
    private func pastTerm(_ term: String) -> some View {
        let courses = store.gradedCourses(in: term)
        let gpa = overallGpa(courses, store.liveGrades, store.gradeScale)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Past term · \(term)")
                .font(.headline).foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            if let gpa {
                Text("\(jsFixed(gpa, 2)) GPA")   // CHANGED in Phase 9c (D-57)
                    .font(.subheadline)
            }
            ForEach(courses) { course in courseCard(course, canAdd: false) }
        }
    }
}
```

### 4.9 Tests and the store script (copy, don't type)

```bash
cd ~/ClassPing
R=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $R/Logic/AvatarTests.swift $R/Logic/TermTests.swift Tests/Logic/   # new: 7 + 8 tests
cp $R/Persistence/ProfileStoreTests.swift Tests/Store/                # new: 8 tests
```

Then add `Store+Profile` to the end of the `for source in …` list in
`scripts/test-store.sh`, so it reads `… Store+Notes Store+Grades
Store+Profile; do`. Without it the store tests can't find `setUsername`.

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 420 tests passing
scripts/test-store.sh     # expect 90
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

1. **The card:** Profile tab. At the top, PROFILE: your initials on the
   gradient with a camera badge, "Tap to change photo", and USERNAME. A name
   with a dot, space, dash or underscore shows two letters ("kelvin.m" is KM).
2. **A photo:** tap the picture. The photo picker opens with no permission
   question. Choose a photo: it fills the circle, centered, here and in the
   tab bar. Close the app fully and reopen: still there.
3. **Remove photo:** tap it. Back to initials, in both places.
4. **Your name:** change it, tap Done. Close fully, reopen: kept. Clear the
   field and tap Done: the old name comes back.
5. **Appearance:** Dark reads "Warm charcoal, with the same soft surfaces and
   your app color."; Light "Switch to warm charcoal for late-night planning."
6. **Grading scale:** the card is in Profile, below Reminders. Open Grades &
   GPA: no scale card, and under the countdown "Letters use the A / A− scale.
   Change it under Profile → Grading scale." Switch to A / B / C in Profile:
   the letters on Grades follow.
7. **The term:** type a name in CURRENT TERM, tap Done, close fully, reopen:
   kept. Tap **Add date** on both rows and set them around today: the window
   line, a bar, and "Week X of Y · N days to go." Move the start into the
   future: "Starts in N days, W weeks long." Tap a row's × : that day clears.
8. **The week follows the dates:** set the end date to yesterday. Today says
   the term is over and the week grid stops at the end. If the end is now
   before the start, the card says "The end date is before the start date,
   check the dates." Put it back.
9. **Start a new term (as far as Cancel):** below the dates, "Finished the
   semester? Archive these N classes…" Tap **Start a new term**: NAME THIS
   TERM appears, filled with the term name; Archive is greyed while it's
   empty. Tap **Cancel**. Only tap Archive if you're ready: your classes leave
   the timetable for good (grades stay, under the term name on Grades), and
   "Term archived, your timetable is clear. 🎉" shows for 4 seconds.

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] 420 logic and 90 store tests pass; the tree builds without warnings.
- [ ] A picked photo shows in the card and the tab bar and survives a full
      close; Remove photo brings the initials back.
- [ ] The name and the term name save when you leave the field.
- [ ] The grading scale card works from Profile, and Grades names the scale.
- [ ] Both dates set, the card shows the week and days left; Start a new term
      opens its naming step and Cancel closes it.

## 7. If it breaks

- **Cannot find type 'PhotosPickerItem' in scope:** the
  `import _PhotosUI_SwiftUI` line is missing from `ProfileCard.swift` (with
  its leading underscore).
- **Main actor-isolated property 'store' can not be referenced from a
  nonisolated context, in ProfileCard:** the badge inside `PhotosPicker` must
  get `username`, the copy made at the top of `body`, not
  `store.profile.username`.
- **Cannot find 'termNote' or 'TERM_WINDOW_NOTE':** 4.2 isn't in `Logic/`.
- **The store tests can't find 'setUsername' or 'archiveTerm':** the
  `Store+Profile` word is missing from `scripts/test-store.sh` (4.9).
- **The photo comes back as initials after a relaunch:** the save failed
  (the red line at the top of the Profile tab says so) or the picture was
  refused; a photo over 12 MB says "That image is too large, try a smaller
  one." instead.
- **"Starts in" disagrees with the web:** expected, the web's is wrong
  (D-69).

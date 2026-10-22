# Phase 3: The app shell, theme and dark mode

*Replaces old Milestone 1 (redone with four tabs). Checked on 2026-10-14: `build-check.sh` gave `BUILD_OK` with no warnings. The Phase 2 logic and Phase 1 persistence tests are untouched (this phase adds no `Logic/` or model code).*

**Before you start:** Phase 2 must be typed, building and committed.

**Note on the designs file:** the iOS designs (`ClassPing Screens.dc.html`) still aren't readable from here, so this shell is built from the web app's `components/TabBar.tsx`, `AddMenu.tsx`, `app/globals.css` and `lib/accents.ts`. If you drop that file into `docs/ios/` later, we can fine-tune spacing and the exact bar look; nothing below depends on it.

## 1. Goal

The two bare tabs become the real app frame: **Today · Notes · [+] · Planner · Tasks**, with the brand Add button raised in the middle, a themed warm background, and full dark mode. **On your phone:** four tabs switch screens, the center + opens a labelled Add menu (five choices, they just close for now), and a temporary "Appearance" card on Today flips between light/dark and Baby Pink/Ocean, with the whole app recoloring instantly and the choice surviving a relaunch.

## 2. New Swift concepts

**Color extensions, and colors that switch themselves.** You can add methods to types you don't own, even `Color`. `Color(hex: "#E85D8A")` builds a color from the same hex the web app stores. For light/dark, `UIColor(dynamicProvider:)` hands back a different shade per mode, and SwiftUI re-resolves it whenever the mode changes:

```swift
static func dyn(_ light: String, _ dark: String) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}
static let ink = dyn("#3A3530", "#FFFFFF")   // near-black by day, white by night
```

**View modifiers.** A modifier is a reusable style attached with a method, SwiftUI's version of a shared CSS class. One `extension View { func cardStyle() ... }` gives every card the same surface:

```swift
Text("hi").padding(16).cardStyle()   // card color + 15pt corners + a soft lift
```

**A selection-driven tab bar.** The bar is not Apple's `TabView`; it is a plain row whose look you control, driven by one piece of state. The selected tab is `@State`, the bar takes a `@Binding` to it, tapping a tab sets it, and the body shows the matching screen. `.safeAreaInset(edge: .bottom)` pins the bar and keeps lists from scrolling under it:

```swift
@State private var tab: MainTab = .today
// ...
Group { switch tab { case .today: TodayView(); /* ... */ } }
    .safeAreaInset(edge: .bottom) { MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent) }
```

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `app/globals.css` tokens | `Design/Theme.swift` | The hex values become `Theme.ink`, `Theme.card`, `Theme.brand(accent)` and `Theme.Radius.card`. The CSS switched on an `html.dark` class; Swift switches with `UIColor(dynamicProvider:)` |
| `lib/accents.ts` (two accents) | `Theme.brand/brandDeep/brandBright/brandGradient` | Baby Pink and Ocean, with Baby Pink the default, exactly as the registry |
| `components/TabBar.tsx` | `RootView.swift` (the `MainTabBar`) | Four destinations, two a side, the Add button centered and raised. The pet "aura" ring on the button is left for Phase 12 |
| `components/AddMenu.tsx` | `Components/AddMenu.swift` | The same five choices and wording in a sheet. Tapping one closes it for now; Phase 4 opens the forms |
| `app/home`, `app/classes` | `Screens/TodayView.swift`, `Screens/NotesView.swift` | Placeholders. Today also carries a temporary Appearance card so dark mode and the accent can be tried before Settings exists (Phase 11) |

The Planner and Tasks tabs still show your existing `WeekView` and `AssignmentsView`; they move into `Screens/` and get their real content in Phases 5 and 4.

## 4. Files, in the order to type them

**First make the three folders** (this is where the last phase tripped up). From inside `~/ClassPing/Sources/ClassPing`:

```bash
cd ~/ClassPing/Sources/ClassPing
mkdir -p Design Components Screens
```

Then create each file in its folder. Watch for stray leading spaces in file names. Type `Theme.swift` first, because every other file uses it.

### 4.1 `~/ClassPing/Sources/ClassPing/Design/Theme.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme.swift
//  Phase:   3 (app shell)
//  Ports:   app/globals.css (the design tokens), lib/accents.ts (the two accents)
//
//  Summary: The app's look in one place: the colors, the two accents, the corner
//           radii and a card-surface modifier. Colors switch themselves between
//           light and dark, so a screen asks for `Theme.ink` and gets the right
//           shade for whichever mode the phone is in.
//

import SwiftUI
import UIKit

/// Build a Color from a hex string like "#E85D8A". The web app stores colors as
/// hex in globals.css; this is how the same values reach SwiftUI.
extension Color {
    init(hex: String) { self = Color(uiColor: UIColor(hex: hex)) }
}

extension UIColor {
    /// A UIColor from "#RRGGBB" (the leading # is optional). A malformed string
    /// falls back to mid-grey, so a typo shows up on screen instead of crashing.
    /// `scanHexInt64` returns a Bool, so there is no throwing call to wrap.
    convenience init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        let ok = Scanner(string: s).scanHexInt64(&v) && s.count == 6
        let r = ok ? Double((v >> 16) & 0xFF) / 255 : 0.5
        let g = ok ? Double((v >> 8) & 0xFF) / 255 : 0.5
        let b = ok ? Double(v & 0xFF) / 255 : 0.5
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

/// Every design token, grouped under one name so screens read `Theme.ink`,
/// `Theme.card`, `Theme.Radius.card`, and so on.
enum Theme {
    /// A color that resolves itself per mode. `light` and `dark` are hex strings.
    /// `UIColor(dynamicProvider:)` hands back the right one for the current trait,
    /// which SwiftUI updates whenever the color scheme (or our forced one) changes.
    private static func dyn(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Surfaces. `--color-canvas`, `--bg-card`, `--bg-outer` in globals.css.
    static let canvas = dyn("#EDEAE4", "#26232A")
    static let card   = dyn("#EDEAE4", "#26232A")
    static let outer  = dyn("#F5F3EF", "#211F24")

    // Text, darkest to faintest. `--color-ink` / `-muted` / `-faint` / `-hint`.
    static let ink   = dyn("#3A3530", "#FFFFFF")
    static let muted = dyn("#6B6458", "#C9C1BC")
    static let faint = dyn("#847B6D", "#A59994")
    static let hint  = dyn("#948B7E", "#928780")

    /// The hairline between rows. Opaque warm grey in light, a faint wash in dark.
    static let line = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.89, alpha: 0.12)
            : UIColor(hex: "#DCD6CB")
    })

    // Status colors (used from Phase 4 on). `--good` / `--danger` in globals.css.
    static let good   = dyn("#6F9C65", "#9FBB8A")
    static let danger = dyn("#C9514D", "#E88076")

    /// Corner radii. 15 is the app's most-used card radius (61 uses on the web).
    enum Radius {
        static let small: CGFloat = 13
        static let card: CGFloat = 15
        static let large: CGFloat = 18
        static let sheet: CGFloat = 24
    }
}

/// The accent colors. lib/accents.ts has exactly two; Baby Pink is the default.
/// Each returns the hue for the accent the student picked in their profile.
extension Theme {
    /// The main brand hue. `--color-brand`.
    static func brand(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: Color(hex: "#E85D8A")
        case .ocean:    Color(hex: "#3B82C4")
        }
    }
    /// The deep end of the brand gradient. `--color-brand-deep`.
    static func brandDeep(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: Color(hex: "#C43D6E")
        case .ocean:    Color(hex: "#2A6BA8")
        }
    }
    /// The bright end of the brand gradient. `--color-brand-bright`.
    static func brandBright(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: Color(hex: "#FF8FB0")
        case .ocean:    Color(hex: "#6BA8E0")
        }
    }
    /// The 135° brand gradient, bright to deep. `--brand-grad` in globals.css.
    static func brandGradient(_ a: Profile.Accent) -> LinearGradient {
        LinearGradient(colors: [brandBright(a), brandDeep(a)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A view modifier is a reusable style you attach with a method, the SwiftUI
/// answer to a shared CSS class. `.cardStyle()` is the app's card surface:
/// the card color, a 15pt rounded corner and a soft lift off the canvas.
extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/RootView.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   3 (app shell)  [was Phase 0]
//  Ports:   components/TabBar.tsx (the four tabs with the Add button between them)
//
//  Summary: The screen under everything else. A custom bottom bar switches
//           between the four main screens, Today, Notes, Planner and Tasks, with
//           the brand Add button raised in the middle. The whole app is tinted
//           with the chosen accent and forced to the chosen light/dark mode here.
//

import SwiftUI

/// Which of the four main tabs is showing. In the web app this is the current
/// `pathname`; here it is one piece of state the bar reads and writes.
enum MainTab: Hashable { case today, notes, planner, tasks }

struct RootView: View {
    /// The shared store, for the accent and theme the whole app reads.
    @Environment(Store.self) private var store

    /// The selected tab, and whether the Add menu is open. `@State` means this
    /// view owns these values and redraws when they change.
    @State private var tab: MainTab = .today
    @State private var addOpen = false

    var body: some View {
        // Read the accent once; reading it here means the whole screen redraws
        // (new tint, new bar colors) the moment it changes in Settings.
        let accent = store.profile.accent

        // The selected screen. Each tab keeps its own NavigationStack, so it has
        // its own back history, the way each web route keeps its own URL.
        Group {
            switch tab {
            case .today:   NavigationStack { TodayView() }
            case .notes:   NavigationStack { NotesView() }
            case .planner: NavigationStack { WeekView().navigationTitle("Planner") }
            case .tasks:   NavigationStack { AssignmentsView().navigationTitle("Tasks") }
            }
        }
        // `safeAreaInset` pins the bar to the bottom and insets the screen above
        // it, so a list never scrolls underneath the bar.
        .safeAreaInset(edge: .bottom) {
            MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent)
        }
        // The warm ground behind everything, including under the bar.
        .background(Theme.canvas.ignoresSafeArea())
        // The accent tints buttons, pickers and links app-wide.
        .tint(Theme.brand(accent))
        // Force light or dark to match the profile, overriding the system setting.
        .preferredColorScheme(store.profile.theme == .dark ? .dark : .light)
        // The Add button opens this sheet.
        .sheet(isPresented: $addOpen) { AddMenu() }
    }
}

/// The bottom bar: two tabs, the Add button, two tabs. A rounded "glass" pill
/// floating above the canvas, matching components/TabBar.tsx.
private struct MainTabBar: View {
    @Binding var tab: MainTab
    @Binding var addOpen: Bool
    let accent: Profile.Accent

    var body: some View {
        HStack(spacing: 0) {
            item(.today, "Today", "house.fill")
            item(.notes, "Notes", "book.fill")
            addButton
            item(.planner, "Planner", "calendar")
            item(.tasks, "Tasks", "checklist")
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// One destination. Active gets the brand color, the rest stay faint, the
    /// same split the web bar makes with `--color-brand` vs `--color-faint`.
    private func item(_ which: MainTab, _ label: String, _ symbol: String) -> some View {
        let active = tab == which
        return Button {
            tab = which
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20))
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(active ? Theme.brand(accent) : Theme.faint)
        }
        .buttonStyle(.plain)
    }

    /// The raised brand circle in the middle. Opens the Add menu.
    private var addButton: some View {
        Button {
            addOpen = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.brandGradient(accent), in: Circle())
                .shadow(color: Theme.brand(accent).opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .frame(width: 62)       // a fixed middle slot, so the two halves balance
        .offset(y: -14)         // lifted above the bar, like the web's -mt-6
    }
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Components/AddMenu.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AddMenu.swift
//  Phase:   3 (app shell)
//  Ports:   components/AddMenu.tsx (the five labelled choices)
//
//  Summary: The sheet the Add button opens: the five things you can add, named,
//           in the same order as the web app. Phase 3 just shows and dismisses;
//           Phase 4 wires each row to the task and class forms.
//

import SwiftUI

struct AddMenu: View {
    /// `dismiss` closes the sheet, the way `onClose()` does in the web component.
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store

    /// One choice in the menu. `symbol` is an SF Symbol name (the native icon set
    /// that replaces components/icons.tsx).
    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let symbol: String
    }

    /// The five choices, matching AddMenu.tsx's list and wording.
    private let options = [
        Option(label: "Assignment", detail: "Homework, essays, lab reports", symbol: "doc.text"),
        Option(label: "Exam", detail: "A test or quiz to revise for", symbol: "graduationcap"),
        Option(label: "Reminder", detail: "Something to bring or do, not graded", symbol: "bell"),
        Option(label: "Note", detail: "Write down a lecture or a thought", symbol: "pencil"),
        Option(label: "Class", detail: "Add a subject to your timetable", symbol: "book"),
    ]

    var body: some View {
        let accent = store.profile.accent
        NavigationStack {
            List(options) { opt in
                Button {
                    // Phase 4 opens the matching form. For now the menu just closes.
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        // A brand-soft rounded square holds the icon, like the web rows.
                        Image(systemName: opt.symbol)
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.brand(accent))
                            .frame(width: 38, height: 38)
                            .background(Theme.brand(accent).opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(opt.label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(opt.detail)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // A sheet that opens to about half height, draggable to full.
        .presentationDetents([.medium, .large])
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/TodayView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/TodayView.swift
//  Phase:   3 (app shell)
//  Ports:   app/home/page.tsx (placeholder; Phase 6 builds the real Today)
//
//  Summary: The Today tab. For now a welcome card plus a temporary Appearance
//           card, so you can watch dark mode and the accent switch live. Phase 6
//           replaces this with the next class, priorities, planned work and the
//           quote banner.
//

import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` turns the observable store into something a Picker can bind
        // to, so `$store.profile.theme` is a two-way connection to that field.
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // A plain card, to show the surface and radius tokens on screen.
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Your day's classes, priorities and planned work will appear here in Phase 6.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // TEMPORARY. Phase 11 moves appearance into Settings; this card is
                // here only so dark mode and the accent can be exercised now.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance (temporary)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.faint)

                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)

                    Picker("Accent", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Today")
        // Save whenever any profile field changes, so the choice survives a relaunch.
        // Profile is Equatable, so onChange fires only on a real change.
        .onChange(of: store.profile) { store.save() }
    }

    /// "Welcome back" or "Welcome back, <name>" once a username exists.
    private var greeting: String {
        store.profile.username.isEmpty
            ? "Welcome back"
            : "Welcome back, \(store.profile.username)"
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/NotesView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/NotesView.swift
//  Phase:   3 (app shell)
//  Ports:   app/classes/page.tsx (placeholder; Phase 8 builds the real Notes)
//
//  Summary: The Notes tab. A themed placeholder until Phase 8 builds the subject
//           list, the reader and the markdown editor.
//

import SwiftUI

struct NotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your classes and their notes will live here.")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Phase 8 builds the notes reader and editor.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Notes")
    }
}
```

## 5. Run it

```bash
xtool dev build
xtool dev
git add . && git commit -m "Phase 3: app shell, theme, dark mode"
```

On the phone:
1. Four tabs along the bottom, the + raised in the middle. Tapping **Today / Notes / Planner / Tasks** switches screens; the active one turns the accent color.
2. Tap **+**: the Add menu slides up with Assignment, Exam, Reminder, Note, Class. Each one, and Cancel, closes it.
3. On **Today**, use the Appearance card: **Dark** recolors the whole app, **Ocean** turns the accent blue. Switch the app away and back; your choice held.
4. **Tasks** still lists your assignments with the Phase 2 deadline text, now inside the themed frame.

## 6. Done when

- [ ] `xtool dev build` finishes with no warnings.
- [ ] All four tabs switch, and the active tab shows the accent color.
- [ ] The + opens the five-choice Add menu; every row and Cancel dismiss it.
- [ ] Dark mode and the Ocean accent both change the whole app, and survive a relaunch.
- [ ] `Design/`, `Components/` and `Screens/` each hold their new file, with no stray leading spaces in the names.

## 7. If it breaks

- **Files in the wrong place again:** the three new files must sit under `Sources/ClassPing/Design/`, `.../Components/` and `.../Screens/`. If the build says `cannot find 'Theme' in scope` or `cannot find 'TodayView' in scope`, a file landed outside `Sources/ClassPing/`. Check with `find ~/ClassPing/Sources/ClassPing -name '*.swift'`.
- **`cannot find type 'Profile' in scope`** in `Theme.swift`: `Profile.Accent` comes from your Phase 1 `Profile.swift`; make sure that file still builds.
- **`cannot find 'UIColor' in scope`:** the `import UIKit` line at the top of `Theme.swift` is missing.
- **The Picker won't bind (`cannot find '$store'`)**: the `@Bindable var store = store` line at the top of `TodayView`'s `body` is missing or misspelled; that is what makes `$store.profile.theme` work.
- **Dark mode doesn't stick after relaunch:** the `.onChange(of: store.profile) { store.save() }` line on `TodayView` is missing, so the choice never reaches `planner.json`.

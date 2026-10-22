# Phase 0: Housekeeping

*Replaces the unfinished half of old Milestone 2. Built and checked with `build-check.sh` on 2026-10-13: `BUILD_OK`, no warnings.*

## 1. Goal

Put the project under git, give every file its header, and connect the store to the screens. **On your phone:** the Tasks tab lists the five sample assignments with their class and due date, instead of "Your tasks will show up here."

## 2. New Swift concepts

**`@State` on an object you own.** `@State private var store = Store.sample` tells SwiftUI "make this once and keep it". Without `@State`, a new Store would be built every time the view redraws and your data would reset.

**The environment.** `.environment(store)` drops the store into a shared space every screen below can read. A screen picks it up with one line:

```swift
@Environment(Store.self) private var store
```

It's React context without the provider boilerplate.

**`List` and `Identifiable`.** `List(items) { item in ... }` draws one row per item. It needs each item to have an `id`, which is why `Assignment` is `Identifiable`.

## 3. What it maps from the web app

| Web | Swift | Difference |
|---|---|---|
| `<StoreProvider>` in `lib/store.tsx`, wrapped in `app/layout.tsx` | `@State` + `.environment(store)` in `ClassPingApp.swift` | Same idea, one line |
| `app/tasks/page.tsx` | `AssignmentsView.swift` | Only the list for now. Filters, groups and actions are Phase 4 |

## 4. Files, in the order to type them

### 4.0 Commands first (VS Code terminal, inside `~/ClassPing`)

```bash
git init
git add .
git commit -m "Milestone 1 and 2 as typed"
```

Your `.gitignore` already skips `.build` and `/xtool`, so only your own files go in.

### 4.1 `~/ClassPing/Sources/ClassPing/Models.swift` (adds a header only)

Type these lines above `import Foundation`. Nothing else in the file changes.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Models.swift
//  Phase:   0 (housekeeping; you typed this in Milestone 2)
//  Ports:   docs/SCHEMA.md, lib/supabase/map.ts (classes and tasks rows)
//
//  Summary: The two core data types: a Course (one class you take) and an
//           Assignment (one piece of work). Phase 1 completes them.
//
```

### 4.2 `~/ClassPing/Sources/ClassPing/Store.swift` (adds a header only)

Same again, above `import Foundation`:

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store.swift
//  Phase:   0 (housekeeping; you typed this in Milestone 2)
//  Ports:   lib/store.tsx (the shared state) and the sample week from your designs
//
//  Summary: The one place the app's data lives while it runs, plus a sample
//           store to show until you add your own classes.
//
```

### 4.3 `~/ClassPing/Sources/ClassPing/ClassPingApp.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   0 (housekeeping)
//  Ports:   app/layout.tsx (the root that wraps every screen)
//
//  Summary: The app's entry point. It creates the one Store the whole app shares
//           and hands it to every screen through the SwiftUI environment.
//

import SwiftUI

/// `@main` marks where the app starts, like the root layout in the web app.
@main
struct ClassPingApp: App {
    /// The app's single store. `@State` keeps the same Store alive for as long as
    /// the app runs, instead of making a new one every time SwiftUI redraws.
    // CHANGED in Phase 0: the store is created here (it used to not exist at all).
    @State private var store = Store.sample

    var body: some Scene {
        WindowGroup {
            // `.environment(store)` puts the store where any screen below can ask for it
            // with `@Environment(Store.self)`. In the web app this is the
            // <StoreProvider> in lib/store.tsx.
            // CHANGED in Phase 0
            RootView()
                .environment(store)
        }
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/RootView.swift` (replaces the file: header and comments, same code)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   0 (housekeeping)
//  Ports:   components/TabBar.tsx (only two tabs for now; Phase 3 makes it four plus Add)
//
//  Summary: The screen under everything else: a tab bar that switches between
//           the Week and Tasks screens.
//

import SwiftUI

/// The app's main screen. Each tab gets its own NavigationStack so it keeps its
/// own back history, the way each web route keeps its own URL.
struct RootView: View {
    var body: some View {
        TabView {
            // Tab 1: the week. Phase 5 renames it Planner and fills it in.
            Tab("Week", systemImage: "calendar") {
                NavigationStack { WeekView().navigationTitle("This Week") }
            }
            // Tab 2: every assignment, quiz, exam and reminder.
            Tab("Tasks", systemImage: "checklist") {
                NavigationStack { AssignmentsView().navigationTitle("Tasks") }
            }
        }
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/WeekView.swift` (replaces the file: header only)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/WeekView.swift
//  Phase:   0 (housekeeping)
//  Ports:   app/week/page.tsx (placeholder until Phase 5)
//
//  Summary: Holds the Week tab's place until the real seven-day grid is built.
//

import SwiftUI

/// Placeholder for the Planner screen.
struct WeekView: View {
    var body: some View {
        Text("Your week will show up here.")
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/AssignmentsView.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/AssignmentsView.swift
//  Phase:   0 (housekeeping)
//  Ports:   app/tasks/page.tsx (a first, plain list; Phase 4 builds the real screen)
//
//  Summary: Lists every assignment in the store with its class and due date, so you
//           can see on the phone that the store reached the screen.
//

import SwiftUI

/// The Tasks tab, for now a simple list.
struct AssignmentsView: View {
    /// Reads the shared store that ClassPingApp put into the environment.
    /// NEW in Phase 0
    @Environment(Store.self) private var store

    var body: some View {
        // NEW in Phase 0: `List` draws one row per item. It can do that because
        // Assignment is Identifiable (it has an `id`), so SwiftUI can tell rows apart.
        List(store.assignments) { assignment in
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.headline)
                    // Completed work is struck through, like the web's done rows.
                    .strikethrough(assignment.done)
                // The second line: which class, and when it's due.
                Text("\(courseName(for: assignment)) · due \(assignment.due)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The short name of the class an assignment belongs to, or "Inbox" when it has none.
    /// NEW in Phase 0
    private func courseName(for assignment: Assignment) -> String {
        // `first(where:)` walks the courses and stops at the first match. It returns
        // an optional, because there might be no match.
        let course = store.courses.first(where: { $0.id == assignment.courseID })
        // `?.short ?? "Inbox"`: use the course's short name if there is a course,
        // otherwise the word the web app uses for unfiled work.
        return course?.short ?? "Inbox"
    }
}
```

## 5. Run it

```bash
xtool dev build    # compiles only
xtool dev          # installs and opens it on the phone
git add . && git commit -m "Phase 0: store wired to the Tasks tab"
```

On the phone, tap **Tasks**.

## 6. Done when

- [ ] `git log` shows two commits.
- [ ] Every file starts with the `File / Phase / Ports / Summary` header.
- [ ] The Tasks tab shows 5 rows: Lab report (OChem), Problem Set 4 (ML), Reading response (Poli), Midterm study guide (Calc, struck through), Reflection journal (Psych, struck through).
- [ ] The Week tab still says "Your week will show up here."

## 7. If it breaks

- **The app crashes on opening Tasks with "No Observable object of type Store found":** `.environment(store)` is missing or attached to the wrong view. It goes on `RootView()`, inside `WindowGroup`.
- **`cannot find 'store' in scope`** in `AssignmentsView`: the `@Environment(Store.self) private var store` line is missing, or it's inside `body` instead of above it.
- **Every class shows "Inbox"**: compare with `==` on `$0.id == assignment.courseID`. A single `=` won't compile; a typo in `courseID` would.

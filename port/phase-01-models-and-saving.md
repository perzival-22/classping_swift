# Phase 1: Complete data models, and saving to the phone

*Replaces old Milestone 2 (models) and Milestone 5 (save to your phone). Checked on 2026-10-13: `build-check.sh` gave `BUILD_OK` with no warnings, and `persistence-test.sh` passed 4 of 4 tests on Linux (first launch, save and load round trip, unreadable file set aside, all-day never stored as 23:59).*

**Before you start:** Phase 0 must be done and committed.

## 1. Goal

Every model mirrors its Supabase table, and the planner is saved on the phone after each change. **On your phone:** tap a task to complete it, swipe the app away, reopen it, and the task is still completed. Two new sample rows show up: "Midterm 2" (an exam at 10:00) and an undated Inbox item.

## 2. New Swift concepts

**Optionals.** `String?` means "a String, or nothing (`nil`)". It's how Swift says what TypeScript says with `string | null`. You can't use an optional as if it were there; you unwrap it first:

```swift
if let due = assignment.due { print("due \(due)") } else { print("no date") }
let name = course?.short ?? "Inbox"   // ?? means "or else"
```

`due` becomes `String?` in this phase because Inbox work has no date, and the product rules say undated work is never given a fake one.

**Enums with raw values.** `enum SubjectColor: String { case teal, ocean }` is a closed list of choices. The `String` raw value means `.teal` is saved as `"teal"`, the same text the web app stores. A typo like `.tael` won't compile, which a plain `String` could never catch.

**Codable + files, and `try?`.** `Codable` lets `JSONEncoder` turn a struct into JSON and `JSONDecoder` turn it back. Reading and writing files can fail, and Swift makes you say what happens then. Your rule is no `do`/`catch`, so every risky call uses `try?`, which turns a failure into `nil`:

```swift
guard let data = try? Data(contentsOf: url) else { return .sample }
```

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `ClassItem`, `TaskItem`, `GradeItem`, `NoteItem`, `TaskPlan`, `StudySession`, `Profile` | `Course`, `Assignment`, `Grade`, `Note`, `TaskPlan`, `StudySession`, `Profile` | Field names follow the Supabase columns (`start_min` becomes `startMin`), not the web's renames (`start`). Sync later becomes a mapping |
| `classId: ""` for Inbox | `courseID: UUID?` set to `nil` | Swift has a real "nothing"; the sync mapper turns it into SQL `null` |
| `deletedAt` in epoch milliseconds | `deletedAt: Date?` | `Date` is Swift's instant; the JSON stores it as ISO 8601 text |
| `color: "teal"` | `color: SubjectColor` | Your hex codes are gone: the web stores names, and the hex for each name lives in the theme (Phase 3), which also gives dark mode its own shades |
| localStorage `classping.v1:<user>` | `Documents/planner.json` | One file. iOS deletes it when the app is deleted |
| "never treat a parse failure as empty" (backup rules) | an unreadable file is renamed `planner.unreadable.json` | So a bug in a later phase can't silently replace your planner with the sample |

**One rule for every later phase:** a property added to a model after today must be optional (`var x: T? = nil`). The decoder treats a missing optional as `nil`, but a missing non-optional makes the whole file unreadable.

**Why `id` stays `UUID`:** you already typed it that way, and it's stricter than a `String`. Supabase's `uuid` columns accept it as-is.

**Why `Store.documentsFolder` uses `FileManager`:** the shorter `URL.documentsDirectory` exists on iOS but not in Linux Foundation, and the tests for this phase run on Linux.

## 4. Files, in the order to type them

Models first, because the store and the screens use them. Two files grow (Models, Store), three are new, and three get small changes.

### 4.1 `~/ClassPing/Sources/ClassPing/Models.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Models.swift
//  Phase:   1 (complete data models)
//  Ports:   lib/store.tsx (ClassItem, TaskItem), lib/class-meetings.ts (ClassMeeting),
//           lib/palette.ts (SubjectColor), lib/supabase/map.ts (column names)
//
//  Summary: The two core data types, now complete: a Course mirrors every
//           client-owned column of the `classes` table, an Assignment every
//           client-owned column of `tasks`.
//

import Foundation

/// The nine subject colors, by name. The web app stores the name ("teal"), not a
/// hex code, so the same name works in light and dark mode and syncs as-is.
/// `String` raw values mean each case is saved as its own name in the JSON.
// NEW in Phase 1 (replaces the hex strings)
enum SubjectColor: String, Codable, CaseIterable {
    case amber, indigo, coral, teal, pink, violet, mint, ocean, slate
}

/// One extra time slot for a class, like a Friday lab on top of the Mon/Wed lectures.
/// In lib/class-meetings.ts this is `ClassMeeting`, and it's saved inside the
/// class row (`additional_meetings`), so its field names stay `start` and `end`.
// NEW in Phase 1
struct ClassMeeting: Identifiable, Codable, Hashable {
    var id = UUID()
    var days: [Int]            // 0 = Monday ... 6 = Sunday
    var start: Int             // minutes from midnight
    var end: Int
    var room: String? = nil
    var label: String? = nil   // e.g. "Lab"
}

/// One class you take. Mirrors the `classes` table, one property per column.
/// Identifiable: lists can tell items apart. Codable: saved as JSON.
/// Hashable: can be compared and stored in sets.
struct Course: Identifiable, Codable, Hashable {
    // What the class is.
    var id = UUID()                    // a unique ID made automatically
    var name: String                   // "Foundations of Machine Learning"
    var short: String                  // "ML"
    var color: SubjectColor            // CHANGED in Phase 1: a named color, not hex

    // When it meets. Times are minutes from midnight: 600 = 10:00 AM.
    var days: [Int]                    // 0 = Monday ... 6 = Sunday
    var additionalMeetings: [ClassMeeting] = []   // NEW in Phase 1
    var startMin: Int
    var endMin: Int

    // Reminders before class.
    var remindBefore = 10              // minutes before class
    var alarm = true                   // the pre-class alarm, which rings even in quiet hours
    var extraReminders: [Int] = []     // NEW in Phase 1: more lead times, in minutes

    // Details. `String?` means "a String, or nothing": a class may have no room yet.
    var credits: Double? = nil         // NEW in Phase 1: nothing counts as 1 in the GPA
    var room: String? = nil
    var instructor: String? = nil      // NEW in Phase 1
    var notes: String? = nil           // NEW in Phase 1: free text about the class
    var term: String? = nil            // NEW in Phase 1: nothing means the current term
    var archived = false               // NEW in Phase 1
    var goal: Double? = nil            // NEW in Phase 1: target grade in percent

    // Where it came from, when a calendar feed made it (Phase 13).
    var sourceFeed: String? = nil      // NEW in Phase 1
    var sourceUID: String? = nil       // NEW in Phase 1
    var sourceHash: String? = nil      // NEW in Phase 1

    /// When it was moved to Recently Deleted. Nothing means it's live.
    /// Deleting only sets this, so it can be restored for 30 days.
    var deletedAt: Date? = nil         // NEW in Phase 1
}

/// One step in an assignment's checklist. `TaskSubtask` in lib/store.tsx.
// NEW in Phase 1
struct Subtask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var done = false
}

/// One assignment, quiz, exam or reminder. Mirrors the `tasks` table.
struct Assignment: Identifiable, Codable, Hashable {
    /// The kinds of work ClassPing tracks. String raw values save as plain text.
    enum Kind: String, Codable, CaseIterable { case assignment, quiz, exam, reminder }

    /// How a task repeats once it's completed. NEW in Phase 1
    enum RepeatRule: String, Codable { case weekly, monthly }

    // What it is.
    var id = UUID()
    var courseID: UUID?                // nothing = Inbox (not filed under a class)
    var title: String

    // The deadline: local wall-clock time, never an instant.
    //   due nil                -> undated (Inbox)
    //   due set, dueTime nil   -> all-day (never pretend it's 23:59)
    //   due set, dueTime set   -> exact time
    var due: String?                   // CHANGED in Phase 1: optional. "yyyy-MM-dd"
    var dueTime: String? = nil         // "HH:mm", 24-hour

    var kind = Kind.assignment         // a plain assignment unless you pick another kind
    var reminder = false               // "nudge me until it's done", daily from 24 h out
    var done = false                   // on screen this is "Complete" / "Completed"

    // More about it.
    var notes: String? = nil           // NEW in Phase 1: the brief, page range, what to bring
    var subtasks: [Subtask] = []       // NEW in Phase 1: the checklist

    // Extra reminder controls (Phase 7 uses these).
    var remindLeads: [Int] = []        // NEW in Phase 1: extra warnings, minutes before. Empty = not chosen
    var snoozedUntil: Date? = nil      // NEW in Phase 1: an instant, unlike `due`

    // Repeating work.
    var repeatRule: RepeatRule? = nil  // NEW in Phase 1
    var repeatUntil: String? = nil     // NEW in Phase 1: "yyyy-MM-dd"
    var recurrenceParentID: UUID? = nil // NEW in Phase 1: stops a double follow-up

    // Feed provenance (Phase 13).
    var sourceFeed: String? = nil      // NEW in Phase 1
    var sourceUID: String? = nil       // NEW in Phase 1
    var sourceHash: String? = nil      // NEW in Phase 1

    var deletedAt: Date? = nil         // NEW in Phase 1: soft delete, see Course
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Records.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Records.swift
//  Phase:   1 (complete data models)
//  Ports:   lib/store.tsx (GradeItem), lib/notes.ts (NoteItem),
//           lib/planning.ts (TaskPlan, StudySession), lib/supabase/map.ts
//
//  Summary: The four smaller record types: grades, notes, planned work days and
//           finished study blocks. Each mirrors its Supabase table.
//

import Foundation

/// One graded result. Mirrors the `grades` table.
struct Grade: Identifiable, Codable, Hashable {
    /// What was graded. Old grades on the web have no kind, so it's optional.
    enum Kind: String, Codable, CaseIterable { case exam, quiz, assignment, project }

    var id = UUID()
    var courseID: UUID?          // the class it counts toward
    var title: String
    var score: Double            // points earned
    var max: Double              // points possible
    var weight: Double           // share of the class grade, in percent
    var date: String             // "yyyy-MM-dd"
    var kind: Kind? = nil
    var deletedAt: Date? = nil   // soft delete
}

/// One lecture note or quick note. Mirrors the `notes` table.
struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var courseID: UUID?          // nothing = a quick note, not filed under a class
    var date: String             // the lecture day, "yyyy-MM-dd": a heading, not a clock
    var title = ""               // empty = the list shows the first line instead
    var body = ""                // markdown, in the dialect lib/notes.ts defines
    var assignmentID: UUID? = nil // the assignment this note supports, if linked
    /// When this device last edited it. The server keeps its own copy of this.
    var updatedAt = Date()
    var deletedAt: Date? = nil
}

/// An assignment placed on a work day. Mirrors `task_plans`.
/// Planning never touches the deadline: this date is when you'll work on it.
struct TaskPlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var assignmentID: UUID       // required: a plan is always for one assignment
    var date: String             // "yyyy-MM-dd"
    var priority: Int? = nil     // 1 to 3 when it's one of the day's top three
    var updatedAt = Date()
}

/// One finished focus block. Mirrors `study_sessions`. Breaks are never saved.
struct StudySession: Identifiable, Codable, Hashable {
    /// Which timer recorded it.
    enum Mode: String, Codable { case timer, pomodoro }

    var id = UUID()
    var assignmentID: UUID?
    var courseID: UUID?
    var minutes: Int             // 1 to 240
    var completedAt: Date        // an instant: when the block finished
    var mode = Mode.timer
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Profile.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Profile.swift
//  Phase:   1 (complete data models)
//  Ports:   lib/store.tsx (Profile), lib/accents.ts, lib/feeds.ts (SavedFeed),
//           lib/gpa.ts (ScaleBand), lib/supabase/map.ts (profiles row)
//
//  Summary: Your preferences: name, theme, accent, quiet hours, term dates,
//           grade scale, saved calendar feeds and your own quotes.
//

import Foundation

/// One saved calendar feed, refreshed in Phase 13. `SavedFeed` in lib/feeds.ts.
struct SavedFeed: Identifiable, Codable, Hashable {
    var id = UUID()
    var url: String
    var label: String
    var lastSyncedAt: Date? = nil   // nothing = never refreshed
}

/// One band of a custom grade scale: "93 and up is an A, worth 4.0".
struct ScaleBand: Codable, Hashable {
    var min: Double                 // lowest percent for this letter
    var letter: String
    var points: Double              // GPA points
}

/// Your preferences. Mirrors the `profiles` table (all but `tz`, which sync
/// writes on its own, and the legacy `style` column, which is always "soft").
struct Profile: Codable, Hashable {
    /// Light or dark. Phase 3 applies it to every screen.
    enum Theme: String, Codable { case light, dark }
    /// The app-wide accent. The web app has exactly these two.
    enum Accent: String, Codable, CaseIterable { case babypink, ocean }
    /// Which letter-grade scale the GPA uses. Nothing = the US standard scale.
    enum GradeScale: String, Codable { case standard, simple, custom }

    // Who you are.
    var username = ""
    var avatarURL: String? = nil

    // How the app looks.
    var theme = Theme.light
    var accent = Accent.babypink    // Baby Pink is the default

    // Reminders.
    var postClassNudge = true       // "Did that class come with homework?"
    var quietStart: Int? = nil      // minutes from midnight; both nil = never quiet
    var quietEnd: Int? = nil

    // The term.
    var finalsDate: String? = nil   // "yyyy-MM-dd"
    var gradeScale: GradeScale? = nil
    var termStart: String? = nil
    var termEnd: String? = nil
    var termName: String? = nil     // "Fall 2026"
    var termSetupPrompted = false

    // Lists you build up.
    var importFeeds: [SavedFeed] = []   // at most 5
    var customScale: [ScaleBand] = []   // at most 16, used when gradeScale is .custom
    var quotes: [String] = []           // empty = the built-in quotes
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Store.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store.swift
//  Phase:   1 (complete data models)
//  Ports:   lib/store.tsx (the shared state) and the sample week from your designs
//
//  Summary: The one place the app's data lives while it runs, plus a sample
//           store to show until you add your own classes.
//

import Foundation
import Observation

/// The single place your app's data lives while it runs.
/// @Observable: any screen showing this data redraws by itself when it changes.
/// @MainActor: only used from the main (UI) thread, which Swift 6 checks for you.
@MainActor @Observable
final class Store {
    /// Everything you've entered. Deleted items stay here with `deletedAt` set.
    var courses: [Course] = []           // every class you take
    var assignments: [Assignment] = []   // every assignment, open or done
    var grades: [Grade] = []             // NEW in Phase 1
    var notes: [Note] = []               // NEW in Phase 1
    var taskPlans: [TaskPlan] = []       // NEW in Phase 1
    var studySessions: [StudySession] = [] // NEW in Phase 1
    var profile = Profile()              // NEW in Phase 1

    /// True when the last save to the phone failed. The screens must say so,
    /// because "Saved on this device" has to be true when the app claims it.
    var lastSaveFailed = false           // NEW in Phase 1
}

extension Store {
    /// A store filled with the classes and assignments from your design screens 02 and 06.
    /// The app uses it until you add your own. End times are made up.
    static var sample: Store {
        // Times are minutes from midnight: 510 = 8:30 AM, 560 = 9:20 AM.
        // CHANGED in Phase 1: colors are names now, not hex codes.
        let calc = Course(name: "Calculus III", short: "Calc", color: .coral,
                          days: [0, 2, 4], startMin: 510, endMin: 560)
        let ml = Course(name: "Foundations of Machine Learning", short: "ML", color: .indigo,
                        days: [0, 2], startMin: 600, endMin: 680, remindBefore: 15, room: "Friend 101")
        let poli = Course(name: "Modern Political Theory", short: "Poli", color: .teal,
                          days: [0, 2], startMin: 810, endMin: 885)
        let ochem = Course(name: "Organic Chemistry II", short: "OChem", color: .ocean,
                           days: [1, 3], startMin: 540, endMin: 615)
        let psych = Course(name: "Introduction to Psychology", short: "Psych", color: .amber,
                           days: [1, 3], startMin: 900, endMin: 975)

        let store = Store()
        store.courses = [calc, ml, poli, ochem, psych]
        // Each assignment points at its class through that class's id.
        store.assignments = [
            Assignment(courseID: ochem.id, title: "Lab report: Aldol condensation", due: day(1)),
            Assignment(courseID: ml.id, title: "Problem Set 4", due: day(2)),
            Assignment(courseID: poli.id, title: "Reading response: Rawls, Ch. 3", due: day(3), reminder: true),
            Assignment(courseID: calc.id, title: "Midterm study guide", due: day(-2), done: true),
            Assignment(courseID: psych.id, title: "Reflection journal", due: day(-1), done: true),
            // NEW in Phase 1: an exam with an exact time, and an undated Inbox item.
            Assignment(courseID: calc.id, title: "Midterm 2", due: day(5), dueTime: "10:00", kind: .exam),
            Assignment(title: "Email advisor about spring classes"),
        ]
        return store
    }

    /// The date `offset` days from today, as "yyyy-MM-dd": day(1) is tomorrow, day(-1) yesterday.
    private static func day(_ offset: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   // same format whatever your phone's language
        f.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        return f.string(from: date)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Store+Persistence.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Persistence.swift
//  Phase:   1 (save and load)
//  Ports:   lib/store.tsx (the localStorage cache, key "classping.v1:<user>")
//
//  Summary: Saves everything to Documents/planner.json after each change and
//           reads it back when the app opens. A file that can't be read is set
//           aside, never overwritten, so a bug can't erase your planner.
//

import Foundation

/// Everything that gets saved, in one value. Codable turns it into JSON and back.
/// Rule for later phases: a property added here (or to any model) must be
/// Optional, or old files on the phone won't load. Optional properties that are
/// missing from the file simply come back as nil.
struct PlannerDocument: Codable {
    var courses: [Course]
    var assignments: [Assignment]
    var grades: [Grade]
    var notes: [Note]
    var taskPlans: [TaskPlan]
    var studySessions: [StudySession]
    var profile: Profile
}

extension Store {
    /// The app's private Documents folder on the phone. Deleting the app deletes
    /// this folder too, which is how you reset to the sample.
    /// `urls(for:in:)` gives back a list; `.first` takes its only entry, and
    /// `?? temporaryDirectory` is a fallback so this can never crash.
    static var documentsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Where the planner is saved.
    static var fileURL: URL {
        documentsFolder.appending(path: "planner.json")
    }

    /// Where an unreadable planner.json is moved, so nothing ever writes over it.
    static var unreadableURL: URL {
        documentsFolder.appending(path: "planner.unreadable.json")
    }

    /// The store's contents packed into one saveable value.
    var document: PlannerDocument {
        PlannerDocument(courses: courses, assignments: assignments, grades: grades,
                        notes: notes, taskPlans: taskPlans, studySessions: studySessions,
                        profile: profile)
    }

    /// Writes the planner to the phone. Call it after every change, before any
    /// network call: that's what makes "Saved on this device" honest.
    func save() {
        // Set up the encoder. Dates become text like "2026-10-13T20:00:00Z".
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // readable if you open the file

        // `try?` turns a failure into nil instead of crashing (no do/catch needed).
        // `guard let ... else` leaves the function early when encoding fails.
        guard let data = try? encoder.encode(document) else {
            lastSaveFailed = true
            return
        }

        // `.atomic` writes to a temporary file first and swaps it in, so a crash
        // mid-save can't leave half a file. The write gives back nil on failure.
        let written = (try? data.write(to: Store.fileURL, options: .atomic)) != nil
        lastSaveFailed = !written
    }

    /// Builds the store when the app opens: your saved planner if there is one,
    /// otherwise the sample.
    static func load() -> Store {
        // No file yet (first launch): start from the sample.
        guard let data = try? Data(contentsOf: fileURL) else {
            return .sample
        }

        // Read the JSON back into a PlannerDocument.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let saved = try? decoder.decode(PlannerDocument.self, from: data) else {
            // The file exists but can't be read. Treating that as "empty" is how
            // planners get wiped (the web app's backup rules say the same). Move it
            // aside first, replacing any older unreadable copy, then use the sample.
            try? FileManager.default.removeItem(at: unreadableURL)
            try? FileManager.default.moveItem(at: fileURL, to: unreadableURL)
            return .sample
        }

        // Copy each saved list into a fresh store.
        let store = Store()
        store.courses = saved.courses
        store.assignments = saved.assignments
        store.grades = saved.grades
        store.notes = saved.notes
        store.taskPlans = saved.taskPlans
        store.studySessions = saved.studySessions
        store.profile = saved.profile
        return store
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Store+Assignments.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store+Assignments.swift
//  Phase:   1 (save and load)
//  Ports:   lib/store.tsx (toggleTask, the simple part; Phase 4 adds the rest)
//
//  Summary: Actions that change assignments. Each one changes the store and
//           then saves straight away.
//

import Foundation

extension Store {
    /// Marks an assignment completed, or back to open. In lib/store.tsx this is
    /// `toggleTask`, which also spawns the next repeat and awards XP (later phases).
    func toggleAssignment(_ id: UUID) {
        // Find the assignment's position in the array. `firstIndex(where:)` gives
        // back nil when there's no match, and `guard` leaves early in that case.
        guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }

        // Change it in place, then save before anything else happens.
        assignments[index].done.toggle()
        save()
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/ClassPingApp.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   1 (save and load)
//  Ports:   app/layout.tsx (the root that wraps every screen)
//
//  Summary: The app's entry point. It loads the planner saved on the phone (or
//           the sample, the first time) and hands that one Store to every screen.
//

import SwiftUI

/// `@main` marks where the app starts, like the root layout in the web app.
@main
struct ClassPingApp: App {
    /// The app's single store. `@State` keeps the same Store alive for as long as
    /// the app runs, instead of making a new one every time SwiftUI redraws.
    // CHANGED in Phase 1: load what's saved on the phone instead of always the sample.
    @State private var store = Store.load()

    var body: some Scene {
        WindowGroup {
            // `.environment(store)` puts the store where any screen below can ask for it
            // with `@Environment(Store.self)`. In the web app this is the
            // <StoreProvider> in lib/store.tsx.
            RootView()
                .environment(store)
        }
    }
}
```

### 4.8 `~/ClassPing/Sources/ClassPing/AssignmentsView.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/AssignmentsView.swift
//  Phase:   1 (save and load)
//  Ports:   app/tasks/page.tsx (a first, plain list; Phase 4 builds the real screen)
//
//  Summary: Lists every assignment with its class and deadline. Tapping a row
//           completes it, and the change is saved on the phone.
//

import SwiftUI

/// The Tasks tab, for now a simple list.
struct AssignmentsView: View {
    /// Reads the shared store that ClassPingApp put into the environment.
    @Environment(Store.self) private var store

    var body: some View {
        // CHANGED in Phase 1: `List { ... }` with `ForEach` inside, so the list can
        // hold a warning row as well as the assignment rows.
        List {
            // Only shown when the last save failed. Never hide a failed save.
            if store.lastSaveFailed {
                Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                    .foregroundStyle(.red)
            }

            // One row per assignment. A Button makes the whole row tappable.
            ForEach(store.assignments) { assignment in
                Button {
                    store.toggleAssignment(assignment.id)
                } label: {
                    row(for: assignment)
                }
                .foregroundStyle(.primary)   // keep the text black/white, not button blue
            }
        }
    }

    /// What one row shows: the title, then the class and the deadline.
    /// NEW in Phase 1 (moved out of `body` to keep it readable)
    private func row(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assignment.title)
                .font(.headline)
                // Completed work is struck through, like the web's done rows.
                .strikethrough(assignment.done)
            Text("\(courseName(for: assignment)) · \(deadlineText(for: assignment))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// The short name of the class an assignment belongs to, or "Inbox" when it has none.
    private func courseName(for assignment: Assignment) -> String {
        // `first(where:)` walks the courses and stops at the first match. It returns
        // an optional, because there might be no match.
        let course = store.courses.first(where: { $0.id == assignment.courseID })
        // `?.short ?? "Inbox"`: use the course's short name if there is a course,
        // otherwise the word the web app uses for unfiled work.
        return course?.short ?? "Inbox"
    }

    /// The deadline in words, for now the raw stored text. Phase 2 makes it friendly
    /// ("Tomorrow, 10:00 AM") with the ported lib/deadline.ts helpers.
    /// NEW in Phase 1: `due` is optional now, so "no date" needs its own case.
    private func deadlineText(for assignment: Assignment) -> String {
        // `if let` unwraps the optional: inside the braces, `due` is a plain String.
        if let due = assignment.due {
            // A time is only meaningful when there's a date.
            if let time = assignment.dueTime {
                return "due \(due) at \(time)"
            }
            return "due \(due), all day"
        }
        return "no date"
    }
}
```

## 5. Run it

```bash
xtool dev build
xtool dev
git add . && git commit -m "Phase 1: complete models, save to phone"
```

On the phone:
1. Open **Tasks**. You should see 7 rows, including "Midterm 2" (`due ... at 10:00`) and "Email advisor about spring classes" (`Inbox · no date`).
2. Tap "Problem Set 4". It gets struck through.
3. Swipe up to the app switcher and swipe ClassPing away. Open it again.
4. "Problem Set 4" is still struck through. Tap it again to reopen it.

To start over from the sample at any point, delete the app from the home screen and run `xtool dev` again. That erases its Documents folder.

## 6. Done when

- [ ] `xtool dev build` finishes with no warnings.
- [ ] Tasks shows 7 rows, and the Inbox item says "no date".
- [ ] A completed task stays completed after the app is closed and reopened.
- [ ] No red "Couldn't save on this device" row appears.
- [ ] `Course` has 22 properties and `Assignment` has 19: every client-owned column except `user_id`, which sync adds.

## 7. If it breaks

- **`cannot convert value of type 'String' to expected argument type 'SubjectColor'`** in `Store.swift`: the sample still passes a hex string. Use `.coral`, `.indigo` and so on.
- **`argument 'room' must precede argument 'remindBefore'`** (or any "must precede"): a memberwise initializer takes its arguments in the order the properties are declared. Check your property order against the listing.
- **The completed task comes back open after reopening:** `save()` isn't being called. Check that `toggleAssignment` ends with `save()`, and that the row's Button calls `store.toggleAssignment(assignment.id)`.

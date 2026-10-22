---
title: "Phase 7c: Taps and the post-class prompt"
date: 2026-10-18
generated_by: skills-for-architects
---

# Phase 7c: Taps and the post-class prompt

*Last of three parts of Phase 7 (D-29). Checked on 2026-10-18 on top of your Phase 7b commit `e6ceefa`: `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 184/184 (10 new, in `PostClassTests`), and `persistence-test.sh` passed 19/19. Nothing here has been on a phone yet.*

**Before you start:** your class alarm and daily nudge ring (you checked on 2026-10-18). This phase opens screens from those notifications, and leans hardest on the third kind, the after-class "… just ended" (7a's step 3, second banner). If that one has never arrived, check Profile → Reminders → **After-class nudge** is on, and try it before typing anything here.

## 1. Goal

Tapping a ClassPing notification opens what it's about, and the minutes after a class turn into one question: did it come with homework?

**On your phone:**

- Tap "Ping 7c just ended": ClassPing opens with a card over the dimmed app: "PING 7C JUST ENDED", "Did this class come with an assignment?", **Yes, add it** and **No, I'm good**. Yes slides up the New Assignment form with Ping 7c already picked. No says "Nice, nothing to log", names your next class today, and offers **Back to Home**.
- For half an hour after a class ends, Today shows "Ping 7c just finished · Did it come with an assignment?" with **Log it** (the same card) and **×** (hides it).
- Tap a "Due in 24 hours" or "3 days until this is due": the Tasks tab opens on that task's detail. Tap a "… starts at …" class alarm: Today.

## 2. New Swift concepts

**Hearing about a tap, and handing it to the main actor.** 7a's delegate has one method, `willPresent`. A tap arrives through a second one, `didReceive`. iOS doesn't call it on the main actor, but the store lives there (Swift 6 checks), so the method works out where to go and then hops over with `MainActor.run`, which runs a closure on the main actor and waits for it:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse) async {
    let destination = notificationRoute(response.notification.request.content.userInfo)
    let store = self.store                      // a local the closure can take along
    await MainActor.run { store.route = destination }
}
```

The closure may only carry values that are safe to send between actors. The store is (a `@MainActor` class always is) and so is the route; `self`, a plain `NSObject`, isn't. That's why the store is copied into a local first. One trap: delegate methods are optional, so a typo in the signature is not an error. The method simply never runs. Type it exactly.

**Navigating from code.** Until now a screen changed because you tapped something on it. A notification tap starts outside every screen, so it leaves a request in the store, `store.route`, and RootView, which owns the tabs, carries it out. Two tools do that:

- `NavigationStack(path:)` makes a tab's stack a value you can set. A `NavigationPath` is the stack written as a list: empty is the tab's first screen; one `AssignmentLink` in it is that task's detail on top. `NavigationLink(value:)` rows keep adding to it by themselves, as before.
- `.onChange(of:initial:)` runs when a value changes and, with `initial: true`, once more when the screen first appears. That second run matters: a tap on a closed app reaches the store before RootView exists.

```swift
@State private var tasksPath = NavigationPath()

NavigationStack(path: $tasksPath) { AssignmentsView() }
    .onChange(of: store.route, initial: true) { _, route in
        guard let route else { return }
        go(route)            // switch tab, set the path, or open the prompt
        store.route = nil    // taken
    }
```

**A preset through a default parameter.** The task form sometimes has to start on a class, and none of its existing callers should change. A parameter with a default does both: a caller that leaves it out gets nil (Inbox), as before.

```swift
init(kind: Assignment.Kind = .assignment, courseID: UUID? = nil,
     editing: Assignment? = nil, onFinish: (() -> Void)? = nil)

AssignmentFormView(courseID: course.id, onFinish: { addingFor = nil })  // the prompt's Yes
AssignmentFormView(kind: kind, onFinish: { dismiss() })                 // the Add menu, untouched
```

You'll also meet: **`.overlay` instead of `.sheet`** for the prompt (iOS shows one sheet at a time, so a sheet asked for while another is up never appears, and the tap is lost; an overlay always appears, and at worst waits under a sheet you still have open); **`max(by:)` and `min(by:)`**, which pick the biggest or smallest by a rule you give, with no loop; **`[AnyHashable: Any]` with `as?`**, iOS's loosely typed dictionary and the safe way to take a `String` out of it; **`.accessibilityAddTraits(.isModal)`**, so VoiceOver reads the card and nothing behind it; and **`some View` as a parameter type**, so one helper can take an icon or an emoji.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `justEndedClass` in `lib/store.tsx` | `justEnded` in `Logic/PostClass.swift` | Same rule: met today, ended at most 30 minutes ago, the latest end wins. It hands back the meeting, so a Friday lab counts as itself. (The map first put it in Phase 2's `Time.swift`; it waited for its first caller, as D-31 does) |
| `nextClassToday` in `app/prompt/page.tsx` | `nextClassToday`, same file | Same. It reads your active classes; the web page also reads archived ones (D-35) |
| `notificationclick` and `openApp` in `public/sw.js` | `didReceive` in `ClassPingApp.swift`, `notificationRoute`, and `go` in `RootView.swift` | The web opens Home for every reminder it rings itself, and only the server's post-class push opens `/prompt`. The phone has no push, so 7a's own "just ended" opens the prompt, a task's reminders open that task, and class alarms open Today, as on the web. No Yes / No buttons on the notification (D-33) |
| `app/prompt/page.tsx` | `Screens/Prompt/PostClassPrompt.swift` | Same three answers, same words. One card over the dimmed app; the web draws its card over a pretend agenda and shows the other two answers as whole pages (D-34) |
| `/tasks/new?class=…` | `AssignmentFormView(courseID:)` | Same: that class picked, everything else as for any new task. Save closes the form, as the Add menu does; the web goes on to the task list |
| The just-ended banner in `app/home/page.tsx` | `justEndedBanner` in `TodayView.swift` | Same words and rules: today, inside the term, × hides it for that class. The web forgets the × when you leave Home; the phone keeps it while the app is open, because Today stays alive in its tab |
| `router.push(…)` | `store.route` and `go` in `RootView.swift` | A URL names a screen on the web; a route value does here, and RootView takes it |

## 4. Files, in the order to type them

4.1 builds on its own and 4.2 needs it. 4.3 and 4.4 are separate pieces that 4.5 puts together. 4.6 and 4.7 send routes. Build after each if you like; everything has to be in by 4.7. Two new files, five replaced.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/PostClass.swift` (new file)

Pure logic, like 7b's `ExamPrep.swift`: no SwiftUI, so the Linux tests can run it. It uses `ReminderKind` (7a) and the meeting helpers (5a), and builds on its own.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/PostClass.swift
//  Phase:   7c (taps and the post-class prompt)
//  Ports:   `justEndedClass` in lib/store.tsx, `nextClassToday` in
//           app/prompt/page.tsx, and the "where does this tap go?" part of
//           the notificationclick handler in public/sw.js
//
//  Summary: Three small answers the post-class prompt needs: which class just
//           ended, which class is next today, and where a tapped notification
//           should take you. Foundation only, so the Linux tests can run it.
//

import Foundation

// MARK: - Which class just ended, and what's next

/// How long after a class ends Today's banner and the prompt still count it
/// as "just ended", in minutes. The `windowMins = 30` default of
/// `justEndedClass`. (The notification itself only rings in the first 20,
/// `postClassWindow` in ReminderPlan.swift.)
let justEndedWindow = 30

/// The meeting that ended in the last half hour today, or nil when none did.
/// With back-to-back classes, the one that ended most recently wins.
/// `justEndedClass` in lib/store.tsx.
func justEnded<C: Schedulable>(_ courses: [C], now: Date,
                               window: Int = justEndedWindow) -> MeetingSlot<C>? {
    let today = dayIndex(of: now)
    let mins = minuteOfDay(now)
    // Today's meetings that have ended, but no more than `window` minutes ago.
    let ended = expandClassMeetings(courses).filter { slot in
        slot.meeting.days.contains(today)
            && slot.meeting.end <= mins
            && mins - slot.meeting.end <= window
    }
    // The latest end. `max(by:)` takes an "is this one smaller?" rule and
    // returns the biggest; on a tie it keeps the first, as the web's sort does.
    return ended.max { $0.meeting.end < $1.meeting.end }
}

/// The next meeting still to start today, or nil when the day's done. What
/// "No, I'm good" points you to. `nextClassToday` in app/prompt/page.tsx.
func nextClassToday<C: Schedulable>(_ courses: [C], now: Date) -> MeetingSlot<C>? {
    let today = dayIndex(of: now)
    let mins = minuteOfDay(now)
    // Today's meetings that haven't started yet; the earliest start wins.
    return expandClassMeetings(courses)
        .filter { $0.meeting.days.contains(today) && $0.meeting.start > mins }
        .min { $0.meeting.start < $1.meeting.start }
}

// MARK: - Where a tap goes

/// Where the app should take you, asked for by a tapped notification or by
/// Today's "Log it". The store holds one until RootView acts on it. The web
/// does the same job with URLs (`/home`, `/prompt?class=…`).
enum AppRoute: Equatable {
    /// The Today tab. Where a class alarm goes: the web opens Home for every
    /// reminder it rings itself.
    case today
    /// One task's detail, on the Tasks tab: a daily nudge or an early warning.
    case task(UUID)
    /// The post-class prompt about this class. Nil means "whichever class just
    /// ended", the web's `/prompt` with no `?class=`.
    case postClass(UUID?)
}

/// Reads what 7a attached to a notification (`userInfo`: its kind, class and
/// task) and says where a tap on it should go. Anything unreadable goes to
/// Today. `[AnyHashable: Any]` is iOS's "anything keyed by anything"
/// dictionary; `as? String` takes a value out only if it really is text.
func notificationRoute(_ info: [AnyHashable: Any]) -> AppRoute {
    // Each value arrives as text, or not at all. `flatMap` turns the text into
    // a kind or a UUID, and gives nil when it isn't one (7a stores "" for none).
    let kind = (info["kind"] as? String).flatMap { ReminderKind(rawValue: $0) }
    let course = (info["course"] as? String).flatMap { UUID(uuidString: $0) }
    let task = (info["assignment"] as? String).flatMap { UUID(uuidString: $0) }

    switch kind {
    case .postClass:
        return .postClass(course)
    case .taskNag, .taskLead:
        // `map` wraps a task id into a route; no id leaves nil, so `??` picks Today.
        return task.map { AppRoute.task($0) } ?? .today
    case .classAlarm, nil:
        return .today
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Store.swift` (replaces the file)

Two touched spots: the summary at the top, and `route` at the end of the class. One stored property, so it has to live in the class itself: an `extension` can add functions and computed properties, never stored ones.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Store.swift
//  Ports:   lib/store.tsx (the shared state) and the sample week from your designs
//
//  Summary: The one place the app's data lives while it runs, plus a sample
//           store to show until you add your own classes. Since 7c it also
//           holds where a tapped notification wants to take you.
//


import Foundation
import Observation

/// The single place your app's data lives while it runs.
/// @Observable: any screen showing this data redraws by itself when it changes.
/// @MainActor: only used from the main (UI) thread, which Swift 6 checks for you.
@MainActor @Observable
final class Store {
    var courses: [Course] = []           // every class you take
    var assignments: [Assignment] = []   // every assignment, open or done
    var grades: [Grade] = []             // NEW in Phase 1
    var notes: [Note] = []               // NEW in Phase 1
    var taskPlans: [TaskPlan] = []       // NEW in Phase 1
    var studySessions: [StudySession] = [] // NEW in Phase 1
    var profile = Profile()

    /// True when the last save to the phone failed. The screens must say so,
    /// because "Saved on this device" has to be true when the app claims it.
    var lastSaveFailed = false           // NEW in Phase 1

    /// The latest assignment or class deletion, available to undo this session.
    var pendingUndo: PendingUndo? = nil

    /// Where the app should go next: set by a tapped notification or by
    /// Today's "Log it", taken by RootView, which goes there and sets it back
    /// to nil. Never saved: a tap is about now, not the next launch.
    var route: AppRoute? = nil           // NEW in Phase 7c
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

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift` (replaces the file)

Three touched spots: the header, the `init` signature (one new parameter), and the line that sets `_courseID`. Everything else is as you typed it in 4a.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Tasks/AssignmentFormView.swift
//  Phase:   4a (task logic and the add form), changed in 7c (start on a class)
//  Ports:   app/tasks/new/page.tsx and app/tasks/[id]/edit/page.tsx (one form, two modes)
//
//  Summary: The form for a new assignment, exam or reminder, and for editing
//           one. Only a title is required: no class means Inbox, no date means
//           "No deadline", and no time means all-day. Since 7c a new one can
//           start with its class already picked, as the post-class prompt does.
//

import SwiftUI

struct AssignmentFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The assignment being edited, or nil for a new one.
    let editing: Assignment?

    /// What to do after Save. The Add menu passes "close the whole sheet";
    /// when nil, the form just closes itself with `dismiss()`.
    let onFinish: (() -> Void)?

    // MARK: Form state
    // `@State` is the form's own scratch copy of every field. Nothing reaches
    // the store until Save, so Cancel or Back throws the edits away.
    @State private var title: String
    @State private var courseID: UUID?
    @State private var kind: Assignment.Kind
    @State private var hasDate: Bool          // off = No deadline (Inbox)
    @State private var dueDay: Date           // only the day part is used
    @State private var hasTime: Bool          // off = all-day
    @State private var dueClock: Date         // only the hour and minute are used
    @State private var reminder: Bool
    @State private var notes: String
    @State private var repeatRule: Assignment.RepeatRule?
    @State private var hasRepeatEnd: Bool
    @State private var repeatEnd: Date

    /// Sets the starting value of every field. A view's `@State` normally starts
    /// from a fixed value; to start it from the assignment being edited, the
    /// init writes to the underscore version (`_title`), which is the State box
    /// itself, wrapping the value in `State(initialValue:)`.
    /// New work starts like the web form: due in 3 days, all-day, reminder on.
    /// CHANGED in Phase 7c: `courseID` is a preset, the class new work starts
    /// on (the web's `/tasks/new?class=…`). It has a default, nil (Inbox), so
    /// every existing call still compiles unchanged. An edit ignores it.
    init(kind: Assignment.Kind = .assignment, courseID: UUID? = nil,
         editing: Assignment? = nil, onFinish: (() -> Void)? = nil) {
        self.editing = editing
        self.onFinish = onFinish

        // Where the dates start: the stored day if there is one, else 3 days out.
        let inThreeDays = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let storedDay = editing.flatMap { parseDay($0.due) }
        let storedClock = editing.flatMap { parseClock($0.dueTime) }
        let storedEnd = editing.flatMap { parseDay($0.repeatUntil) }

        _title = State(initialValue: editing?.title ?? "")
        // CHANGED in Phase 7c: an edit keeps its own class; new work takes the preset.
        _courseID = State(initialValue: editing == nil ? courseID : editing?.courseID)
        _kind = State(initialValue: editing?.kind ?? kind)
        _hasDate = State(initialValue: editing == nil ? true : storedDay != nil)
        _dueDay = State(initialValue: storedDay ?? inThreeDays)
        _hasTime = State(initialValue: storedClock != nil)
        _dueClock = State(initialValue: storedClock ?? parseClock("17:00") ?? .now)
        _reminder = State(initialValue: editing?.reminder ?? true)
        _notes = State(initialValue: editing?.notes ?? "")
        _repeatRule = State(initialValue: editing?.repeatRule)
        _hasRepeatEnd = State(initialValue: storedEnd != nil)
        _repeatEnd = State(initialValue: storedEnd ?? storedDay ?? inThreeDays)
    }

    var body: some View {
        Form {
            // MARK: Class
            // `selection: $courseID` binds the picker to the form's state: the
            // `$` hands the picker a two-way connection, so picking a row
            // writes straight into `courseID`. Each row's `.tag` is the value
            // it stands for; nil is Inbox, a real choice, not "nothing chosen".
            Section("Class") {
                Picker("Class", selection: $courseID) {
                    Text("Inbox, no class").tag(UUID?.none)
                    ForEach(store.courses.filter { $0.deletedAt == nil }) { course in
                        Text(course.name).tag(UUID?.some(course.id))
                    }
                }
            }

            // MARK: Type
            Section("Type") {
                Picker("Type", selection: $kind) {
                    ForEach(kindChoices, id: \.self) { k in
                        Text(kindTitle(k)).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: Name
            Section(nameHeading) {
                TextField(namePlaceholder, text: $title)
                    .textInputAutocapitalization(.sentences)
            }

            // MARK: Due
            Section {
                // The web's shortcut chips. A horizontal scroller, because seven
                // chips don't fit across a phone.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.label) { preset in
                            presetChip(preset)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // A switch for "has a day at all"; off is the Inbox.
                Toggle("Has a due date", isOn: $hasDate)
                if hasDate {
                    // New work can't be due in the past (the web's `min` is today).
                    // An edit keeps any day, so an overdue task isn't moved by accident.
                    DatePicker("Date", selection: $dueDay, in: earliestDay...,
                               displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $dueClock, displayedComponents: .hourAndMinute)
                    }
                }
            } header: {
                Text("Due")
            } footer: {
                // The plain-words summary under the web form: "Due Monday, Sep 7".
                Text("Due \(longDeadline(draftDeadline))")
            }

            // MARK: Repeat
            // Only for dated graded work, like the web: a reminder doesn't repeat.
            if hasDate && kind != .reminder {
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatRule) {
                        Text("None").tag(Assignment.RepeatRule?.none)
                        Text("Weekly").tag(Assignment.RepeatRule?.some(.weekly))
                        Text("Monthly").tag(Assignment.RepeatRule?.some(.monthly))
                    }
                    .pickerStyle(.segmented)
                    if repeatRule != nil {
                        Toggle("Repeat until a date", isOn: $hasRepeatEnd)
                        if hasRepeatEnd {
                            DatePicker("Until", selection: $repeatEnd, in: dueDay...,
                                       displayedComponents: .date)
                        }
                    }
                }
            }

            // MARK: Reminder
            Section {
                Toggle(isOn: $reminder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder")
                        Text("Nudge me until it's done")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }

            // MARK: Notes
            Section("Notes (optional)") {
                // `axis: .vertical` lets the field grow onto new lines as you type.
                TextField("What the brief asks for, pages to read, what to bring…",
                          text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        // Let the warm canvas show through instead of the system grey.
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(editing == nil ? "New Assignment" : "Edit Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        // The web caps notes at 2000 characters; trim anything pasted past that.
        .onChange(of: notes) {
            if notes.count > 2000 { notes = String(notes.prefix(2000)) }
        }
    }

    // MARK: - Pieces

    /// A due-date shortcut: a label and how many days from today (nil = No deadline).
    private struct Preset {
        let label: String
        let days: Int?
    }

    /// The web form's `DUE_PRESETS`, in the same order.
    private var presets: [Preset] {
        [Preset(label: "No deadline", days: nil), Preset(label: "Today", days: 0),
         Preset(label: "Tomorrow", days: 1), Preset(label: "2 days", days: 2),
         Preset(label: "3 days", days: 3), Preset(label: "1 week", days: 7),
         Preset(label: "2 weeks", days: 14)]
    }

    /// One shortcut chip. Filled with the brand color when it matches the
    /// current choice, the way the web lights up the active preset.
    private func presetChip(_ preset: Preset) -> some View {
        // The day this chip stands for, or nil for "No deadline".
        let target = preset.days.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }
        let on = target.map { hasDate && dayOf($0) == dayOf(dueDay) } ?? !hasDate
        let accent = store.profile.accent

        return Button {
            // Tapping sets (or clears) the date in one go.
            if let target {
                hasDate = true
                dueDay = target
            } else {
                hasDate = false
            }
        } label: {
            Text(preset.label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(on ? Color.white : Theme.muted)
                .background(on ? Theme.brand(accent) : Theme.canvas,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)   // stops the Form row treating the whole row as one button
    }

    // MARK: - Derived values

    /// The kinds the Type picker offers. Quizzes are made from a class card on
    /// the web, so a new task offers three; editing a quiz keeps Quiz on offer
    /// so saving never quietly turns it into an assignment.
    private var kindChoices: [Assignment.Kind] {
        let base: [Assignment.Kind] = [.assignment, .exam, .reminder]
        return editing?.kind == .quiz ? base + [.quiz] : base
    }

    /// The name each kind shows in the picker.
    private func kindTitle(_ k: Assignment.Kind) -> String {
        switch k {
        case .assignment: "Assignment"
        case .quiz:       "Quiz"
        case .exam:       "Exam"
        case .reminder:   "Reminder"
        }
    }

    /// The heading over the title field changes with the kind, as on the web.
    private var nameHeading: String {
        switch kind {
        case .exam:     "Exam"
        case .reminder: "Reminder"
        default:        "Assignment"
        }
    }

    /// The example text in the empty title field.
    private var namePlaceholder: String {
        switch kind {
        case .exam:     "e.g. Midterm, Chapters 1–6"
        case .reminder: "e.g. Bring safety goggles"
        default:        "e.g. Reading response: Rawls, Ch. 3"
        }
    }

    /// The first day the date picker allows: today for new work, any day for an edit.
    private var earliestDay: Date {
        editing == nil ? Calendar.current.startOfDay(for: .now) : .distantPast
    }

    /// The deadline the form currently describes, in the stored shape.
    private var draftDeadline: Deadline {
        Deadline(date: hasDate ? dayOf(dueDay) : nil,
                 time: hasDate && hasTime ? timeOf(dueClock) : nil)
    }

    /// Only a title is required. `canSave` in the web form.
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Saving

    /// Builds the assignment from the fields and hands it to the store.
    /// `save` in app/tasks/new/page.tsx and the edit page.
    private func save() {
        guard canSave else { return }

        // Start from the edited assignment so fields this form doesn't show
        // (checklist, done, feed ids...) survive; a new one starts blank.
        var a = editing ?? Assignment(title: "")
        let deadline = draftDeadline
        a.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        a.courseID = courseID
        a.kind = kind
        a.due = deadline.date
        a.dueTime = deadline.time
        a.reminder = reminder

        // Empty notes are stored as nothing, not as "".
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        a.notes = cleanNotes.isEmpty ? nil : cleanNotes

        // A repeat needs a date and isn't for reminders. "Until" only counts
        // when it is on or after the due day (string order is date order here).
        let rule = (deadline.date != nil && kind != .reminder) ? repeatRule : nil
        a.repeatRule = rule
        let until = dayOf(repeatEnd)
        a.repeatUntil = (rule != nil && hasRepeatEnd && until >= (deadline.date ?? "")) ? until : nil

        // New or edited: the store saves to the phone either way.
        if editing == nil {
            store.addAssignment(a)
        } else {
            store.updateAssignment(a)
        }

        // Close: the caller's way if it gave one, otherwise just this screen.
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

// MARK: - Turning stored text into picker dates

/// "2026-09-07" -> local midnight that day, for a DatePicker. Nil when empty or broken.
/// Reuses Deadline.swift, which already knows how to read a stored day.
private func parseDay(_ day: String?) -> Date? {
    deadlineDayStart(Deadline(date: day, time: nil))
}

/// "14:30" -> today at 2:30 PM, for a time-only DatePicker. Only the hour and
/// minute are ever read back out (with `timeOf`), so the day doesn't matter.
private func parseClock(_ time: String?) -> Date? {
    guard isValidTime(time) else { return nil }
    return deadlineInstant(Deadline(date: dayOf(.now), time: time))
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Prompt/PostClassPrompt.swift` (new file, in a new `Prompt` folder)

The card and its three faces. It knows nothing about tabs or sheets: it calls `onAdd` or `onClose`, and RootView decides what happens, the same split as 6b's `MyClassesSection`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Prompt/PostClassPrompt.swift
//  Phase:   7c (taps and the post-class prompt)
//  Ports:   app/prompt/page.tsx (PostClassPrompt, SignedOff, NothingJustEnded)
//
//  Summary: The question asked right after a class: "Did this class come with
//           an assignment?". Yes opens the task form with that class picked;
//           No says what's next today. A card over a dimmed screen, like the
//           web's modal. RootView shows it for a tapped "just ended"
//           notification or for Today's Log it.
//

import SwiftUI
import UIKit

/// Two colors only this screen uses. `private` on an extension (7b's
/// file-level `private`) keeps them out of the rest of the app.
private extension Theme {
    /// The chat icon and the "… JUST ENDED" line. `--color-poli`, one shade
    /// in both modes.
    static let poli = Color(hex: "#C99C8D")
    /// The tile behind the 🎉. `--good-soft`: a solid light shade, and in dark
    /// mode a see-through green, which a hex string can't write.
    static let goodSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 159 / 255, green: 187 / 255, blue: 138 / 255, alpha: 0.16)
            : UIColor(hex: "#DFE7D8")
    })
}

struct PostClassPrompt: View {
    @Environment(Store.self) private var store

    /// The class being asked about, or nil when none just ended (say, a late
    /// tap on a class that has since been deleted).
    let course: Course?
    /// "Yes, add it". RootView closes the prompt and opens the form for the class.
    let onAdd: (Course) -> Void
    /// "Back to Home". RootView closes the prompt and shows Today.
    let onClose: () -> Void

    /// True after "No, I'm good": the card becomes the sign-off. The web's
    /// `dismissed`.
    @State private var answeredNo = false

    var body: some View {
        let accent = store.profile.accent

        ZStack {
            // The dim layer behind the card, the web's rgba(30,22,60,.42). A
            // colored view on top catches touches, so nothing behind it can
            // be pressed by accident while the question is open.
            Color(red: 30 / 255, green: 22 / 255, blue: 60 / 255)
                .opacity(0.42)
                .ignoresSafeArea()

            // One card, three possible contents, in the web's order of checks.
            VStack(spacing: 0) {
                if let course, !answeredNo {
                    question(course, accent)
                } else if course != nil {
                    signedOff(accent)
                } else {
                    nothingEnded(accent)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 24)
        }
        // To VoiceOver this is a dialog: it reads the card and nothing behind it.
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - The three cards

    /// The question itself. `PostClassPrompt` in app/prompt/page.tsx.
    private func question(_ course: Course, _ accent: Profile.Accent) -> some View {
        VStack(spacing: 0) {
            tile(Image(systemName: "bubble.left.fill").font(.system(size: 30)).foregroundStyle(Theme.poli),
                 size: 66, radius: 20, color: Theme.dangerSoft)
            Text("\(course.name.uppercased()) JUST ENDED")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.poli)
                .padding(.top, 16)
            Text("Did this class come with an assignment?")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text("Log it now while it's fresh, we'll keep you on track.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted2)
                .padding(.top, 8)

            VStack(spacing: 10) {
                // Straight into the task form, with this class picked.
                Button {
                    onAdd(course)
                } label: {
                    Text("Yes, add it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.brandGradient(accent),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                // No: the card says so and points at what's next.
                Button {
                    answeredNo = true
                } label: {
                    Text("No, I'm good")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.surface2,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
    }

    /// The "No" answer: say something, and point at the next class today so
    /// the card does a small job instead of just closing. `SignedOff`.
    private func signedOff(_ accent: Profile.Accent) -> some View {
        // Worked out when the card is drawn, from the classes on your timetable.
        let next = nextClassToday(store.activeCourses, now: .now)
        return VStack(spacing: 0) {
            tile(Text("🎉").font(.system(size: 34)), size: 72, radius: 24, color: Theme.goodSoft)
            Text("Nice, nothing to log")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 20)
            Text(next.map { "Enjoy \($0.course.name) at \(fmtTime($0.meeting.start)) 👋" }
                 ?? "That's you done. Have a great rest of your day 👋")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            homeButton(accent)
        }
    }

    /// Nothing to ask about: no class ended recently. `NothingJustEnded`.
    private func nothingEnded(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 0) {
            tile(Image(systemName: "bubble.left.fill").font(.system(size: 32)).foregroundStyle(Theme.poli),
                 size: 72, radius: 24, color: Theme.dangerSoft)
            Text("No class just ended")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 20)
            Text("This nudge shows up right after one of your classes finishes, so you can log an assignment while it's still fresh.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            homeButton(accent)
        }
    }

    // MARK: - Pieces

    /// The rounded square at the top of each card, holding an icon or an emoji.
    /// `some View` as a parameter type: the caller can hand in any view.
    private func tile(_ content: some View, size: CGFloat, radius: CGFloat, color: Color) -> some View {
        content
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// "Back to Home", under the sign-off and the "nothing" card.
    private func homeButton(_ accent: Profile.Accent) -> some View {
        Button {
            onClose()
        } label: {
            Text("Back to Home")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.brandGradient(accent),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/RootView.swift` (replaces the file)

Touched: the header; three new pieces of state under `addOpen`; the Tasks tab's `NavigationStack(path:)`; the `.overlay` just before the Add sheet; and, after the Add sheet, the form sheet, `.onChange` and the new `go` function. `MainTabBar` underneath is unchanged.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   3 (app shell), changed in 5a (Profile tab replaces Planner, D-19),
//           6b (Today can switch tabs) and 7c (going where a tap asks)
//  Ports:   components/TabBar.tsx (four tabs with the Add button between them),
//           and openApp() in public/sw.js (a tap opens the right screen)
//
//  Summary: The screen under everything else. A custom bottom bar switches
//           between the four main screens, Today, Notes, Tasks and Profile,
//           with the brand Add button raised in the middle. The week now lives
//           inside Today. The whole app is tinted with the chosen accent and
//           forced to the chosen light/dark mode here. Since 7c it also takes
//           the store's route: a task's detail, Today, or the post-class
//           prompt, which it shows over everything.
//

import SwiftUI

/// Which of the four main tabs is showing. In the web app this is the current
/// `pathname`; here it is one piece of state the bar reads and writes.
// CHANGED in Phase 5a: `planner` is gone (the week is inside Today), `profile` is new
enum MainTab: Hashable { case today, notes, tasks, profile }

struct RootView: View {
    /// The shared store, for the accent and theme the whole app reads.
    @Environment(Store.self) private var store

    /// The selected tab, and whether the Add menu is open. `@State` means this
    /// view owns these values and redraws when they change.
    @State private var tab: MainTab = .today
    @State private var addOpen = false

    /// NEW in Phase 7c: what's pushed on the Tasks tab, in code. A
    /// `NavigationPath` is a navigation stack written as a list: empty is the
    /// task list itself; one `AssignmentLink` in it is that task's detail on
    /// top. Tapping a row still adds to it by itself; a tap on a notification
    /// replaces it.
    @State private var tasksPath = NavigationPath()

    /// NEW in Phase 7c: whether the post-class prompt is showing, and which
    /// class it asks about (nil: none just ended, so it says so).
    @State private var promptOpen = false
    @State private var promptCourse: Course? = nil

    /// NEW in Phase 7c: the class a new task starts on after "Yes, add it".
    /// While it's set, the task form is open in a sheet.
    @State private var addingFor: Course? = nil

    var body: some View {
        // Read the accent once; reading it here means the whole screen redraws
        // (new tint, new bar colors) the moment it changes in Profile.
        let accent = store.profile.accent

        // TabView keeps each screen and its navigation history alive when
        // switching tabs, including the selected day and expanded week.
        TabView(selection: $tab) {
            // CHANGED in Phase 6b: Today gets the tab, for "View all".
            NavigationStack { TodayView(tab: $tab) }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.today)
            NavigationStack { NotesView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.notes)
            // CHANGED in Phase 7c: `path:` lets a tap open a task's detail.
            NavigationStack(path: $tasksPath) { AssignmentsView().navigationTitle("Tasks") }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.tasks)
            NavigationStack { ProfileView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.profile)
        }
        // `safeAreaInset` pins the bar to the bottom and insets the screen above
        // it, so a list never scrolls underneath the bar.
        .safeAreaInset(edge: .bottom) {
            // CHANGED in Phase 5a: the bar also needs your name for the avatar.
            MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent,
                       name: store.profile.username)
        }
        // The warm ground behind everything, including under the bar.
        .background(Theme.canvas.ignoresSafeArea())
        // The accent tints buttons, pickers and links app-wide.
        .tint(Theme.brand(accent))
        // Force light or dark to match the profile, overriding the system setting.
        .preferredColorScheme(store.profile.theme == .dark ? .dark : .light)
        // NEW in Phase 7c: the post-class prompt, over the whole screen, tab
        // bar included. An overlay, not a sheet: a sheet can't open while
        // another one is showing, so a tap would get lost; an overlay always
        // appears, and at worst waits under a sheet you still have open.
        .overlay {
            ZStack {
                if promptOpen {
                    PostClassPrompt(course: promptCourse,
                                    onAdd: { course in
                                        promptOpen = false
                                        addingFor = course
                                    },
                                    onClose: {
                                        promptOpen = false
                                        tab = .today
                                    })
                        .transition(.opacity)
                }
            }
            // Fade the prompt in and out instead of popping. On the ZStack,
            // so only the prompt animates, not the tab switch behind it.
            .animation(.easeOut(duration: 0.2), value: promptOpen)
        }
        // The Add button opens this sheet.
        .sheet(isPresented: $addOpen) { AddMenu() }
        // NEW in Phase 7c: "Yes, add it" opens the task form on that class.
        // `sheet(item:)` shows it while `addingFor` is set and clears it on close.
        .sheet(item: $addingFor) { course in
            NavigationStack {
                AssignmentFormView(courseID: course.id, onFinish: { addingFor = nil })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { addingFor = nil }
                        }
                    }
            }
        }
        // NEW in Phase 7c: go where a tapped notification or "Log it" asked.
        // `initial: true` also runs this when the screen first appears, for a
        // tap that launched the app before this screen existed.
        .onChange(of: store.route, initial: true) { _, route in
            guard let route else { return }
            go(route)
            // Taken. Back to nil, so the same request again still counts as a change.
            store.route = nil
        }
    }

    /// Opens the screen a route names. NEW in Phase 7c. Nothing you have open
    /// is closed: if a sheet is showing, the screen waits underneath it.
    private func go(_ route: AppRoute) {
        switch route {
        case .today:
            tab = .today
        case .task(let id):
            tab = .tasks
            // The list with that task's detail on top, or just the list if
            // the task was deleted since the notification was planned.
            tasksPath = store.assignment(id) == nil
                ? NavigationPath()
                : NavigationPath([AssignmentLink(id: id)])
        case .postClass(let id):
            // The class the notification names, which stays right even if
            // you tap it an hour later; else whichever class just ended.
            promptCourse = store.course(id) ?? justEnded(store.activeCourses, now: .now)?.course
            promptOpen = true
        }
    }
}

/// The bottom bar: two tabs, the Add button, two tabs. A rounded "glass" pill
/// floating above the canvas, matching components/TabBar.tsx.
private struct MainTabBar: View {
    @Binding var tab: MainTab
    @Binding var addOpen: Bool
    let accent: Profile.Accent
    /// Your username, for the letter on the Profile avatar. NEW in Phase 5a
    let name: String

    var body: some View {
        HStack(spacing: 0) {
            item(.today, "Today", "house.fill")
            item(.notes, "Notes", "book.fill")
            addButton
            item(.tasks, "Tasks", "checklist")      // CHANGED in Phase 5a: Planner removed
            profileItem                              // NEW in Phase 5a
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
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .frame(height: 26)      // CHANGED in Phase 5a: as tall as the avatar
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(active ? Theme.brand(accent) : Theme.faint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The Profile tab: your avatar instead of an icon, with a brand ring
    /// around it while the tab is open. (Phase 12 swaps that ring for your
    /// pet's tier ring, which used to sit on the + button on the web.)
    // NEW in Phase 5a
    private var profileItem: some View {
        let active = tab == .profile
        let brand = Theme.brand(accent)
        return Button {
            tab = .profile
        } label: {
            VStack(spacing: 4) {
                AvatarBadge(name: name, size: 22, accent: accent)
                    .padding(2)
                    .overlay(Circle().stroke(active ? brand : Color.clear, lineWidth: 1.5))
                Text("Profile").font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(active ? brand : Theme.faint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .accessibilityAddTraits(active ? .isSelected : [])
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
        .accessibilityLabel("Add")
        .frame(width: 62)       // a fixed middle slot, so the two halves balance
        .offset(y: -14)         // lifted above the bar, like the web's -mt-6
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/ClassPingApp.swift` (replaces the file)

Touched: the header; `store` and `notificationDelegate`, which are now set in `init`; `init` itself; and in `NotificationDelegate`, the new `store`, `init` and `didReceive`. `ReminderSync` is unchanged.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/ClassPingApp.swift
//  Phase:   0 (housekeeping), changed in 7a (reminders) and 7c (taps)
//  Ports:   app/layout.tsx (the root that wraps every screen), when the
//           reminder loop in lib/store.tsx runs, and the notificationclick
//           handler in public/sw.js
//
//  Summary: The app's entry point. It creates the one Store the whole app
//           shares and hands it to every screen through the SwiftUI
//           environment. Since 7a it also keeps iOS's reminders in step with
//           the store, and lets them show while the app is open. Since 7c a
//           tap on one tells the store where to go.
//
import SwiftUI
import UserNotifications   // NEW in Phase 7a

/// @main marks where the app starts, similar to the root layout in the web app
@main
struct ClassPingApp: App {
    /// The app's single store. `@State` keeps the same Store alive for as long as
    /// the app runs, instead of making a new one every time SwiftUI redraws.
    // CHANGED in Phase 1: load what's saved on the phone instead of always the sample.
    // CHANGED in Phase 7c: loaded in `init`, so the delegate can share it.
    @State private var store: Store

    /// NEW in Phase 7a: the object iOS calls about notifications: before
    /// showing one while the app is open, and (since 7c) when you tap one.
    /// iOS only holds on to it weakly (it won't keep it alive by itself), so
    /// the app keeps it here for as long as it runs.
    // CHANGED in Phase 7c: made in `init`, with the store.
    private let notificationDelegate: NotificationDelegate

    /// NEW in Phase 7a: runs once, as the app starts, so the delegate is in
    /// place before any notification can arrive. iOS needs it set before the
    /// app finishes launching, or a tap that launched the app would be lost.
    // CHANGED in Phase 7c: loads the store here and hands the delegate the
    // same one. `_store` is the State box itself (as in 4a's form init).
    init() {
        let loaded = Store.load()
        _store = State(initialValue: loaded)
        notificationDelegate = NotificationDelegate(store: loaded)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            // `.environment(store)` puts the store where any screen below can ask for it
            // with `@Environment(Store.self)`. In the web app this is the
            // <StoreProvider> in lib/store.tsx.
            // CHANGED in Phase 7a: `.modifier(ReminderSync())` keeps the
            // reminders up to date. It sits inside `.environment(store)`, so
            // it can read the store too.
            RootView()
                .modifier(ReminderSync())
                .environment(store)
        }
    }
}

/// Rebuilds the reminder plan when the app starts, whenever your classes,
/// work or reminder settings change, and whenever the app comes back to the
/// screen. The web runs its check every 30 seconds while a tab is open; the
/// phone only needs to when something changed. A `ViewModifier`, like 4b's
/// Undo bar, because it needs the environment and a piece of state.
// NEW in Phase 7a
private struct ReminderSync: ViewModifier {
    @Environment(Store.self) private var store

    /// Whether the app is on screen (`.active`), half-covered (`.inactive`,
    /// say while Notification Center is pulled down) or in the background.
    /// SwiftUI keeps it up to date.
    @Environment(\.scenePhase) private var scenePhase

    /// How many times the app has come back to the screen. Each return bumps
    /// it, which re-runs the sync: a new day's nudges get planned, and what
    /// rang in the meantime is crossed off.
    @State private var wakeUps = 0

    func body(content: Content) -> some View {
        content
            // `.task(id:)` (4b) runs this when the app starts, and again,
            // cancelling the old run first, every time the id changes.
            .task(id: Trigger(inputs: store.reminderInputs, wakeUps: wakeUps)) {
                // Wait a moment, so a burst of quick edits (ticking off three
                // tasks) makes one sync, not three. A newer edit cancels the
                // wait; `try?` ignores that cancellation, and the guard stops.
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await store.syncReminders()
            }
            // Count each return to the screen.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { wakeUps += 1 }
            }
    }

    /// What the sync watches: the store's reminder inputs plus the wake-up
    /// count. Equatable, so `.task(id:)` can tell when it changed.
    private struct Trigger: Equatable {
        let inputs: Store.ReminderInputs
        let wakeUps: Int
    }
}

/// Lets reminders show while ClassPing is open, and (since 7c) opens the
/// right screen when you tap one. Without it, iOS stays silent about a
/// notification that arrives while you're in the app (the web shows them
/// while it's open, the only time it can). A delegate is an object iOS calls
/// back with "this is happening, what should I do?". `NSObject` is the base
/// class Apple's older callback-based frameworks expect.
// NEW in Phase 7a
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// NEW in Phase 7c: the app's store, where a tap leaves its route. A `let`,
    /// set once. The store is `@MainActor`, so holding it from here is safe;
    /// changing it means going over to the main actor first (below).
    let store: Store

    /// NEW in Phase 7c
    init(store: Store) {
        self.store = store
    }

    /// A notification is arriving with the app on screen: show it anyway, as
    /// a banner with its sound, and keep it in Notification Center.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// NEW in Phase 7c: you tapped a notification, on the lock screen, in
    /// Notification Center or as a banner. If the app was closed, iOS opens
    /// it first, then calls this. The web's `notificationclick` in sw.js.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Only a plain tap opens a screen. (Other answers, like dismissing,
        // only arrive here if an app asks for them; ClassPing doesn't.)
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        // Where to go, read from what 7a attached (Logic/PostClass.swift).
        let destination = notificationRoute(response.notification.request.content.userInfo)

        // This method doesn't run on the main actor, and the store lives
        // there. `MainActor.run` hops over, runs the closure, and comes back
        // (`await` waits for it). The closure may only take along values that
        // are safe to send between actors: the store and the route are, `self`
        // (a plain NSObject) isn't, so the store is copied into a local first.
        let store = self.store
        await MainActor.run {
            store.route = destination
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift` (replaces the file)

Four touched spots: the header, `dismissedBanner` under `sheet`, the banner at the top of `daySection` (just before the class cards), and the new `justEndedBanner` function above `emptyState`.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift
//  Phase:   6b (your work and your classes), after 6a (the picked day),
//           5a (the week) and 5b (class details); changed in 7c (the
//           just-ended banner)
//  Ports:   app/home/page.tsx (the greeting, the quote, the just-ended
//           banner, the picked day's classes, every "nothing here" message,
//           the term glance, the assignments and My Classes) and
//           app/week/page.tsx (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Below it, the quote
//           banner, a "just finished" banner for half an hour after a class,
//           the picked day's classes, and then your term at a glance, your
//           next assignments and your classes, with Edit and Delete.
//

import SwiftUI

/// One presentation at a time: a tapped meeting's details, a class's editor,
/// or the form for a new class. Each case carries what its sheet needs.
enum TodaySheet: Identifiable {
    case meeting(OpenedMeeting)
    case editCourse(Course)
    case newCourse                    // NEW in Phase 6a: "Add a class manually"

    var id: String {
        switch self {
        case .meeting(let opened):
            "meeting-\(opened.courseID)-\(opened.meetingID)-\(dayOf(opened.date))"
        case .editCourse(let course):
            "course-\(course.id)"
        case .newCourse:              // NEW in Phase 6a
            "new-course"
        }
    }
}

/// The days' full English names, Monday first. `DAY_NAMES` in
/// app/home/page.tsx, for "View Thursday's schedule" and the title.
// NEW in Phase 6a
private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The selected tab, owned by RootView. A binding, so "View all" in the
    /// assignments can switch to the Tasks tab from in here.
    // NEW in Phase 6b
    @Binding var tab: MainTab

    // MARK: Screen state
    // None of this is saved: Today always opens on this week, folded,
    // with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    /// The sheet currently presented, or nil when none is open.
    @State private var sheet: TodaySheet?
    /// NEW in Phase 7c: the class whose just-ended banner you closed with ×.
    /// The web's `promptDismissed`. Only that class: a later one still shows.
    @State private var dismissedBanner: UUID?

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the Now tag moves on and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // `activeClasses` in lib/store.tsx.
            let courses = store.activeCourses

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Class deletion and Undo save here too. Report a failed
                    // write even if deleting the last class shows first run.
                    if store.lastSaveFailed {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                    }

                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)

                    // NEW in Phase 6a: the quote, then the picked day. Before
                    // the first class there is nothing to show for any day, so
                    // the setup steps take the day's place (the web's isFirstRun).
                    QuoteBanner(now: now)
                    if courses.isEmpty {
                        firstRun(accent)
                    } else {
                        daySection(courses, now, accent)

                        // NEW in Phase 6b: the lists under the day
                        // (TodaySections.swift). Like the web, they wait
                        // until there's a first class.
                        TermGlance(now: now)
                            .padding(.top, 8)
                        AssignmentsPreview(now: now, onViewAll: { tab = .tasks })
                            .padding(.top, 8)
                        MyClassesSection(onAdd: { sheet = .newCourse },
                                         onEdit: { course in sheet = .editCourse(course) })
                            .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            // Browsing weeks keeps the picked weekday inside the visible week.
            .onChange(of: weekOffset) { _, offset in
                selectedDay = weekDates(now, offset)[dayIndex(of: selectedDay)]
            }
            // Keep following today across midnight until another day is picked.
            .onChange(of: Calendar.current.startOfDay(for: now)) { previous, current in
                if weekOffset == 0 && selectedDay == previous {
                    selectedDay = current
                }
            }
        }
        .background(Theme.canvas)
        // NEW in Phase 6b: the Undo bar after deleting a class (or an
        // assignment from its detail screen), the same one Tasks uses.
        .undoBar()
        // Where a tapped assignment goes, as on the Tasks tab.
        .navigationDestination(for: AssignmentLink.self) { link in
            AssignmentDetailView(assignmentID: link.id)
        }
        // CHANGED in Phase 6a: "Today", or the picked day's name, like the
        // web's heading.
        .navigationTitle(Calendar.current.isDateInToday(selectedDay)
                         ? "Today" : dayNames[dayIndex(of: selectedDay)])
        // The calendar button where the web's gear used to be (the gear's
        // job moved to the Profile tab). It opens and folds the week.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWeek()
                } label: {
                    Image(systemName: weekOpen ? "calendar.circle.fill" : "calendar")
                }
                .accessibilityLabel(weekOpen ? "Fold the week away" : "Show the whole week")
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .meeting(let opened):
                CourseSheet(opened: opened)
            case .editCourse(let course):
                NavigationStack {
                    CourseFormView(editing: course)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            case .newCourse:          // NEW in Phase 6a
                NavigationStack {
                    CourseFormView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { sheet = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - The week

    /// The card holding the week: the grid when open, the strip when folded,
    /// and the handle underneath either way.
    private func weekCard(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let start = store.profile.termStart
        let end = store.profile.termEnd

        return VStack(spacing: 6) {
            // `$weekOffset` hands the child a binding: the strip and the grid
            // both read and change the same week.
            if weekOpen {
                WeekGrid(courses: courses, termStart: start, termEnd: end, now: now,
                         weekOffset: $weekOffset, accent: accent,
                         onOpen: { slot, day, date in
                             sheet = .meeting(OpenedMeeting(courseID: slot.course.id,
                                                            meetingID: slot.meeting.id,
                                                            day: day, date: date))
                         },
                         onSchedule: { course in
                             sheet = .editCourse(course)
                         })
                    .transition(.opacity)
            } else {
                WeekStrip(courses: courses, termStart: start, termEnd: end, now: now,
                          weekOffset: $weekOffset, selected: $selectedDay, accent: accent)
                    .transition(.opacity)
            }
            handle
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// The little bar under the week. Tap it, or drag it down to open and up
    /// to fold. `highPriorityGesture` means a drag that starts on the handle
    /// moves the week instead of scrolling the page.
    private var handle: some View {
        Capsule()
            .fill(Theme.lineStrong)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .onTapGesture { toggleWeek() }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10).onEnded { drag in
                    // Down by 24 points or more opens; up by 24 or more folds.
                    if drag.translation.height > 24 && !weekOpen { toggleWeek() }
                    if drag.translation.height < -24 && weekOpen { toggleWeek() }
                }
            )
            // To VoiceOver this is a button with a clear name.
            .accessibilityElement()
            .accessibilityLabel(weekOpen ? "Fold the week away" : "Open the whole week")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggleWeek() }
    }

    /// Opens or folds the week. `withAnimation` animates every change the
    /// toggle causes: the card grows or shrinks smoothly, and the strip and
    /// grid cross-fade because each has `.transition(.opacity)`.
    private func toggleWeek() {
        withAnimation(reduceMotion ? nil : .snappy) {
            weekOpen.toggle()
        }
    }

    // MARK: - The picked day
    // NEW in Phase 6a: replaces the one-line day card from Phase 5a.

    /// The picked day: its class cards, then whichever message explains an
    /// empty day, then the way on to the next day. The middle of the web's
    /// home page. `@ViewBuilder` lets one function return different views
    /// depending on the `if`s, and allows the `let`s at the top.
    @ViewBuilder
    private func daySection(_ courses: [Course], _ now: Date, _ accent: Profile.Accent) -> some View {
        let day = selectedDay
        let col = dayIndex(of: day)
        let start = store.profile.termStart
        let end = store.profile.termEnd
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let dayName = dayNames[col]

        // A timetable only exists inside its semester. Outside it, nothing is
        // listed and the screen says so instead of "you're free".
        let inTerm = isWithinTerm(start, end, day)
        let slots = expandClassMeetings(courses)
        // This day's meetings, earliest first.
        let dayClasses = inTerm
            ? slots.filter { $0.meeting.days.contains(col) }.sorted { $0.meeting.start < $1.meeting.start }
            : []

        // "You're all free this week!" only once you've looked six or more
        // days ahead and nothing in the picked day's week falls in the term.
        // (The web's `checkedAll`: an empty day alone doesn't mean a free week.)
        let dates = weekDates(day, 0)
        let weekHasClasses = slots.contains { slot in
            slot.meeting.days.contains { d in
                dates.indices.contains(d) && isWithinTerm(start, end, dates[d])
            }
        }
        let checkedAll = daysAhead(of: now) >= 6 && dayClasses.isEmpty && !weekHasClasses

        // Today gets Now / Done tags; any other day gets -1, which turns them off.
        let nowMin = isToday ? minuteOfDay(now) : -1
        let nextName = dayNames[(col + 1) % 7]

        // NEW in Phase 7c: a class that finished in the last half hour gets a
        // banner asking about homework, above the day's classes. Today only,
        // inside the term, and not once you've closed it for that class.
        if isToday && inTerm, let ended = justEnded(courses, now: now),
           dismissedBanner != ended.course.id {
            justEndedBanner(ended.course, accent)
        }

        // The classes, one card each. ForEach gives every card its slot's id,
        // which is how each ClassCard keeps its own open/folded state.
        if !dayClasses.isEmpty {
            VStack(spacing: 12) {
                ForEach(dayClasses) { slot in
                    ClassCard(slot: slot, nowMin: nowMin)
                }
            }
            // A recurring meeting keeps its slot id across dates. Reset the
            // cards for a newly picked day so they always start expanded.
            .id(dayOf(day))
        }

        // At most one message: outside the term, a free day, or a free week.
        if !inTerm {
            let label = termRangeLabel(start, end)
            emptyState(emoji: "📅", title: "Outside your semester",
                       message: label.map { "Your term runs \($0), so nothing is timetabled for \(isToday ? "today" : dayName)." }
                           ?? "Nothing is timetabled for this date.")
        } else if checkedAll {
            emptyState(emoji: "🎉", title: "You're all free this week!",
                       message: "No classes scheduled this week. Enjoy your time!")
            Button {
                showDay(Calendar.current.startOfDay(for: now), now)
            } label: {
                Text("Back to Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else if dayClasses.isEmpty {
            emptyState(emoji: "🌿", title: "Looks like you're free!",
                       message: isToday ? "Nothing scheduled for today." : "Nothing on \(dayName).")
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack(spacing: 8) {
                    Text("View \(nextName)'s schedule")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Theme.brand(accent).opacity(0.32), radius: 12, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }

        // On a day with classes, or outside the term, a quieter way on.
        if !dayClasses.isEmpty || !inTerm {
            Button {
                showDay(scheduleDate(day, 1), now)
            } label: {
                HStack {
                    Text("View \(nextName)'s schedule")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.brand(accent).opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.brand(accent).opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// "Calculus III just finished · Did it come with an assignment?", with
    /// Log it (opens the post-class prompt) and × (hides it for this class).
    /// The just-ended banner in app/home/page.tsx. NEW in Phase 7c
    private func justEndedBanner(_ course: Course, _ accent: Profile.Accent) -> some View {
        HStack(spacing: 12) {
            Text("✍️")
                .font(.system(size: 17))
                .frame(width: 38, height: 38)
                .background(Theme.brandSoft(accent), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(course.name) just finished")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("Did it come with an assignment?")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Opens the prompt the same way a tapped notification does: by
            // leaving a route in the store for RootView to take.
            Button {
                store.route = .postClass(course.id)
            } label: {
                Text("Log it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.brand(accent), in: Capsule())
                    // The pill stays small; the tap area is 44 points tall.
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                dismissedBanner = course.id
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.hint)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(Theme.brand(accent).opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Theme.brand(accent).opacity(0.14), lineWidth: 1))
    }

    /// The big emoji tile, a heading and a line of explanation, centred.
    /// The web repeats this block for each of its three messages.
    private func emptyState(emoji: String, title: String, message: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 38))
                .frame(width: 80, height: 80)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.bottom, 14)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    // MARK: - First run
    // NEW in Phase 6a

    /// Before the first class: one job, get a class in. The web's first-run
    /// card leads with "Import my schedule"; importing arrives in Phase 13,
    /// so for now the manual route is the button, above the three steps.
    private func firstRun(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 10) {
            Button {
                sheet = .newCourse
            } label: {
                Text("Add a class manually")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(color: Theme.brand(accent).opacity(0.3), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)

            onboardStep(1, "Import or add your classes",
                        "Drop in your school's calendar file, or type a class in, about 20 seconds each.", accent)
            // The web says "on the Week tab"; on the phone the week lives
            // behind Today's calendar button (D-19).
            onboardStep(2, "Your week fills in",
                        "See today at a glance, and the whole week from the calendar button.", accent)
            onboardStep(3, "Get reminded",
                        "A heads-up before class starts, and before work is due.", accent)
        }
    }

    /// One numbered step. `OnboardStep` in app/home/page.tsx.
    private func onboardStep(_ n: Int, _ title: String, _ body: String, _ accent: Profile.Accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
                .frame(width: 26, height: 26)
                .background(Theme.brandSoft(accent), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
    }

    // MARK: - Moving between days
    // NEW in Phase 6a

    /// Picks `day` and moves the strip to the week that holds it, so "View
    /// Monday's schedule" on a Sunday lands on next week's Monday.
    private func showDay(_ day: Date, _ now: Date) {
        // Whole weeks between this week's Monday and the day, rounded down,
        // so a day in last week is -1 and not 0.
        let monday = weekDates(now, 0)[0]
        let days = Calendar.current.dateComponents([.day], from: monday, to: day).day ?? 0
        selectedDay = day
        weekOffset = Int((Double(days) / 7).rounded(.down))
    }

    /// How many days after today the picked day is (0 = today, -1 = yesterday).
    /// The web's `offset`. Counted in calendar days, so a daylight-saving
    /// change can't make it off by one.
    private func daysAhead(of now: Date) -> Int {
        let today = Calendar.current.startOfDay(for: now)
        return Calendar.current.dateComponents([.day], from: today, to: selectedDay).day ?? 0
    }

    /// "Good morning, Kelvin 👋". The web's `greeting(hour)` plus the first
    /// part of your username; just the greeting until you've set a name.
    // CHANGED in Phase 6a: the wave, as on the web.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? "\(hello) 👋" : "\(hello), \(first) 👋"
    }
}
```

### Not typed: the tests

`PostClassTests.swift` is in `docs/ios/reference/Tests/Logic/` (10 tests: the half-hour window, back-to-back classes, an extra meeting, the next class, and every notification route). To run it with your own script:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/PostClassTests.swift Tests/Logic/
scripts/test-logic.sh
```

No script changes this time: both of your scripts already copy every file in `Logic/`, and that covers the one `Store.swift` now needs.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 7c: notification taps and the post-class prompt"
```

On the phone:

1. **The prompt from a notification.** **+ → Class**: "Ping 7c", today's weekday only, starting 2 minutes from now and ending 3 minutes after that. Save, go to the Home Screen and lock the phone. When "Ping 7c just ended" arrives, tap it. ClassPing opens on the card: "PING 7C JUST ENDED", "Did this class come with an assignment?".
2. **Yes.** Tap **Yes, add it**: New Assignment slides up with **Class: Ping 7c** already picked. Name it "Ping homework" and Save: the form closes. Tasks lists it under Ping 7c.
3. **The banner and No.** On Today, above the day's classes: "Ping 7c just finished · Did it come with an assignment?". Tap **Log it**: the same card. Tap **No, I'm good**: "Nice, nothing to log" and "That's you done. Have a great rest of your day 👋" (or "Enjoy … at …" if another class is still to come today). **Back to Home** closes it on Today. Now tap the banner's **×**: it goes.
4. **A task's notification.** **+ → Assignment**: "Ping task", due today with a time 2 hours from now, Daily reminder on, Save. "Due in 24 hours" arrives at once (7a's step 4); leave it. Go to the Profile tab, pull down Notification Center and tap it: the Tasks tab opens on Ping task's detail, and Back goes to the list.
5. **From a closed app.** Add "Ping cold" the same way and leave its banner alone. Swipe ClassPing away in the app switcher. Pull down Notification Center and tap "Due in 24 hours · Ping cold…": ClassPing starts and opens straight on Ping cold. (This is the `initial: true` run.)
6. **A class alarm** (optional, about 13 minutes): a class starting 13 minutes from now with a 10-minute reminder, as in 7a's step 3. Tap "… starts at …" from another tab: Today.
7. Delete Ping 7c (Today → My Classes → trash, which takes Ping homework with it) and the two Ping tasks.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] Tapping "… just ended" opens the card for that class, from the lock screen and from a banner inside the app.
- [ ] Yes opens the form with the class picked; Save adds the task and closes the form.
- [ ] No shows the sign-off with your next class today, or "That's you done"; Back to Home lands on Today.
- [ ] Today's banner shows for half an hour after a class; Log it opens the card; × hides it.
- [ ] A task's notification opens that task's detail, including when the app was closed.
- [ ] A class alarm opens Today.

## 7. If it breaks

- **`cannot find type 'AppRoute' in scope`** (in `Store.swift`) or **`cannot find 'notificationRoute' in scope`**: 4.1 is missing, or a name in it is spelled differently.
- **`extra argument 'courseID' in call`** in `RootView.swift`: 4.3's new `init` isn't typed yet.
- **`return from initializer without initializing all stored properties`** in `ClassPingApp.swift`: `init` has to set `_store` and `notificationDelegate` before the line that hands the delegate to iOS.
- **`capture of 'self' with non-sendable type 'NotificationDelegate' in a '@Sendable' closure`**: the closure in `didReceive` reaches the store through `self`. Keep the `let store = self.store` line above it and use that.
- **A tap just opens the app wherever it was.** In order: the `didReceive` signature isn't exactly as in 4.6 (it compiles and is never called); `.onChange` lacks `initial: true` (then only a closed app misses it); or a sheet was open, and the screen is waiting under it (close the sheet).
- **The card says "No class just ended" right after a "just ended" tap:** the class was deleted in the meantime. If not, check 7a's `notificationRequest(for:)` still puts `"course"` in `userInfo`.
- **Today's banner never shows:** the class has to meet today, inside your term dates if you've set some, and the banner lasts 30 minutes from the end.

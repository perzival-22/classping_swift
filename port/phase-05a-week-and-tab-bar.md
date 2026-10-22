---
title: "Phase 5a: The new tab bar and the week"
date: 2026-10-17
generated_by: skills-for-architects
---

# Phase 5a: The new tab bar and the week

*First half of Phase 5 (D-19, D-20). Typed and building in Kelvin's project (commit `3fd880f`, `BUILD_OK` with no warnings, checked 2026-10-17). His copy has a few extra changes beyond this doc, listed in PROGRESS.md and mirrored in `reference/`.*

**Before you start: type Phase 4b first.** Your commits `phase 4.2`, `phase4b` and `phase4c` are Phase **4a**'s sections 4.1 to 4.6 plus its two fixes. Phase **4b** ([phase-04b-tasks-screen.md](phase-04b-tasks-screen.md): `Theme+Tasks.swift`, `Assignment+TaskView.swift` and the three `Screens/Tasks/` views) isn't in your project yet, and this phase uses `Theme.subject` and `Theme.lineStrong` from 4b's `Theme+Tasks.swift`. Type 4b, build, commit, then start here.

## 1. Goal

The bar becomes **Today · Notes · + · Tasks · Profile**, and the week moves inside Today (the layout from the "ClassPing Nav Redesign" mockup).

**On your phone:** the last tab is your avatar (your initial, or a person icon until you set a name) labelled **Profile**. It holds the Appearance card that used to sit on Today, plus a list of what's coming to that tab. **Today** shows a greeting, then a card with this week as a strip: seven days, today in a filled circle, a colored dot per class. Tap another day and it gets a ring, and the card underneath says "Thursday · 2 classes". Tap the **calendar button** at the top right (or tap the little handle under the strip, or drag it down) and the card opens into the full timetable with the sample classes: arrows to browse weeks, a coral line at the current time, and "Not yet scheduled" chips for classes with no times. Tap the button again (or drag the handle up) to fold it.

Tapping a class block doesn't do anything yet: Phase 5b opens its details.

## 2. New Swift concepts

**Layout by numbers: `ZStack` + `.offset`.** Until now every screen was stacks that place things one after another. A timetable needs "this block starts 96 points down", like `position: absolute` in CSS. A `ZStack` piles its children on top of each other, all starting at the same corner, and `.offset(y:)` slides each one down. An offset moves what you see without moving anything else, so blocks can't push each other around.

```swift
ZStack(alignment: .top) {
    Rectangle().fill(.clear)                  // the column itself
    Text("Calc").offset(y: 96)                // 11 AM, if 8 AM is 0 and an hour is 32
}
.frame(height: 320)
```

**`withAnimation` and `.transition`.** Wrap a state change in `withAnimation` and SwiftUI animates everything that change causes: the card grows smoothly from strip to grid. `.transition(.opacity)` says how a view that appears or disappears should do it, here a cross-fade.

```swift
withAnimation(.snappy) { weekOpen.toggle() }
if weekOpen { WeekGrid(...).transition(.opacity) } else { WeekStrip(...).transition(.opacity) }
```

**`TimelineView`.** A view that redraws its content on a schedule and hands you the time. `.everyMinute` fires at the top of each minute, so the "now" line moves and "today" rolls over at midnight with no timer of your own. It's the SwiftUI answer to the web's `useNow()` hook.

```swift
TimelineView(.everyMinute) { context in
    Text(fmtTime(minuteOfDay(context.date)))    // always the current time
}
```

Smaller things you'll meet: a protocol with `{ get }` requirements (`Schedulable`, the same idea as Phase 2's `Dated`), a **generic struct** (`MeetingSlot<C>`, Phase 4a's generics applied to a type), `switch` on a pair of optionals in `termRangeLabel`, and a `DragGesture` on the handle.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/class-meetings.ts` | `Logic/ClassMeetings.swift` (+ `ClassMeetingsTests.swift`) | Same rules and messages. The web marks the main meeting with the id `"primary"`; Swift uses the all-zero UUID (`primaryMeetingID`, D-22). A slot is `MeetingSlot(course:meeting:)` instead of one merged object |
| `ClassMeeting` in `Models.swift` (Phase 1) | moved into `Logic/ClassMeetings.swift` | Logic files must compile on their own for the Linux tests (D-22) |
| `weekInfo`, `fmtMD` (`lib/store.tsx`); `isWithinTerm`, `termRangeLabel` (`lib/time.ts`); labels and grid bounds (`app/week/page.tsx`) | `Logic/Week.swift` (+ `WeekTests.swift`) | Plus `dayIndex(of:)`, the one place Apple's weekday numbers become ClassPing's (IOS_APP.md 3.4). The web has no tests for these, so the Swift tests are written from the code |
| `app/week/page.tsx` (the Planner tab) | `Screens/Week/WeekGrid.swift`, inside Today | Same week arrows, day header, hour scale that stretches to fit, blocks, now line, out-of-term note and "Not yet scheduled". An hour is 36 points instead of 62, so the week fits a phone card. The upcoming-class banner waits for Phase 7 (reminders) |
| the day pill on `app/home/page.tsx` | `Screens/Week/WeekStrip.swift` | Replaces the ‹ day › arrows and "View Monday's schedule": you pick any day of the week in one tap (D-19) |
| `components/TabBar.tsx` | `RootView.swift` | Planner tab gone, Profile tab added, still two tabs a side (D-19). The web bar is unchanged for now |
| the profile and Appearance sections of `app/settings/page.tsx` | `Screens/ProfileView.swift` | A starting point: Phase 11 fills in the settings, Phase 12 your level and pet |
| `--subj-*` colors in `app/globals.css` | `Design/Theme+Courses.swift` | An extension, so `Theme.swift` stays as you typed it |

## 4. Files, in the order to type them

**First delete the Phase 0 placeholder.** The week no longer has a tab, and `RootView` below stops mentioning it:

```bash
cd ~/ClassPing/Sources/ClassPing
git rm WeekView.swift
mkdir -p Screens/Week
```

**Type 4.1 and 4.2 together.** `ClassMeeting` moves from `Models.swift` into the new file, and the project won't build while both files declare it.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/ClassMeetings.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/ClassMeetings.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   lib/class-meetings.ts (ClassMeeting, validMeeting,
//           validAdditionalMeetings, classMeetings, expandClassMeetings,
//           isUnscheduled, meetingKey, meetingError, meetingSummary)
//
//  Summary: A class can meet more than once a week at different times, like
//           Mon/Wed lectures plus a Friday lab. This file turns a class into
//           its list of meetings, checks that meetings make sense, and flattens
//           many classes into the slots the week grid draws. Foundation only,
//           so the Linux test runner can compile it on its own.
//

import Foundation

/// One time a class meets: which days, from when to when, and optionally
/// where and under what name ("Lab"). `ClassMeeting` in lib/class-meetings.ts.
/// It's saved inside the class (`additional_meetings`), so its fields keep the
/// web's names, `start` and `end`, in minutes from midnight.
// CHANGED in Phase 5a: moved here from Models.swift, so the tests can see it
struct ClassMeeting: Identifiable, Codable, Hashable {
    var id = UUID()
    var days: [Int]            // 0 = Monday ... 6 = Sunday
    var start: Int             // minutes from midnight
    var end: Int
    var room: String? = nil
    var label: String? = nil   // e.g. "Lab"
}

/// The id of a class's main meeting. The web calls it `"primary"`; ids here
/// are UUIDs, so the main meeting gets the all-zero UUID instead. `UUID()`
/// never makes that value (a random UUID always has its version bits set),
/// so it can't clash with a real extra meeting.
let primaryMeetingID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

/// The most meeting times one class can have, main meeting included.
/// `MAX_MEETINGS` in lib/class-meetings.ts.
let maxMeetings = 20

/// Short day names, Monday first, so `dayLabels[0]` is "Mon".
/// `DAY_LABELS` in lib/class-meetings.ts.
let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

/// Anything with a timetable: a main meeting stored on the thing itself, plus
/// a list of extra meetings. `Course` signs up in Models.swift. A protocol
/// keeps this file free of the Course model, the same trick as `Dated` in
/// Phase 2, so the tests can use a tiny stand-in instead of a whole Course.
/// `{ get }` means "readable": the protocol only ever reads these.
protocol Schedulable {
    var id: UUID { get }
    var days: [Int] { get }
    var startMin: Int { get }
    var endMin: Int { get }
    var room: String? { get }
    var additionalMeetings: [ClassMeeting] { get }
}

// MARK: - Checking meetings

/// Is this meeting usable? `validMeeting` in lib/class-meetings.ts.
/// (The web also checks the id's characters; a UUID is always well-formed.)
func validMeeting(_ m: ClassMeeting) -> Bool {
    // Days: one to seven of them, no repeats, each one a real weekday.
    // `Set(...)` drops duplicates, so a shorter set means a repeat.
    let daysOK = !m.days.isEmpty && m.days.count <= 7
        && Set(m.days).count == m.days.count
        && m.days.allSatisfy { (0...6).contains($0) }
    // Times: inside one day, and ending after they start.
    let timesOK = m.start >= 0 && m.end < 1440 && m.end > m.start
    // Text: the same caps as the web's inputs. Nothing (nil) always passes.
    let textOK = (m.room?.count ?? 0) <= 200 && (m.label?.count ?? 0) <= 80
    return daysOK && timesOK && textOK
}

/// Are these extra meetings safe to keep? `validAdditionalMeetings`.
/// Fewer than 20 (the main meeting is the 20th), each valid, none pretending
/// to be the main meeting, and no id used twice.
func validAdditionalMeetings(_ meetings: [ClassMeeting]) -> Bool {
    meetings.count < maxMeetings
        && meetings.allSatisfy { validMeeting($0) }
        && !meetings.contains(where: { $0.id == primaryMeetingID })
        && Set(meetings.map(\.id)).count == meetings.count
}

/// What the class form shows under the meetings when Save can't go ahead,
/// or nil when all is well. `meetingError` in lib/class-meetings.ts.
func meetingError(_ meetings: [ClassMeeting]) -> String? {
    // A class needs at least one meeting, and at most 20.
    if meetings.isEmpty || meetings.count > maxMeetings {
        return "Add between 1 and \(maxMeetings) meeting times."
    }
    // The first broken meeting, by position. `firstIndex(where:)` stops at
    // the first match, which is how the web's loop returns early.
    if let bad = meetings.firstIndex(where: { !validMeeting($0) }) {
        return "Meeting \(bad + 1): choose at least one day and an end time after the start time."
    }
    // Two meetings with one id would confuse every screen that tells them apart.
    if Set(meetings.map(\.id)).count != meetings.count {
        return "Meeting identifiers must be unique."
    }
    return nil
}

// MARK: - From classes to meetings

/// Every time a class meets: the main meeting first, then the extra ones.
/// `classMeetings` in lib/class-meetings.ts. The main meeting is built from
/// the class's own days, times and room. Extra meetings that fail the checks
/// are left out entirely, the way the web treats a damaged list.
/// `<C: Schedulable>` makes this generic (Phase 4a): it works for a Course or
/// for anything else that has a timetable.
func classMeetings<C: Schedulable>(_ c: C) -> [ClassMeeting] {
    let main = ClassMeeting(id: primaryMeetingID, days: c.days,
                            start: c.startMin, end: c.endMin, room: c.room)
    let extra = validAdditionalMeetings(c.additionalMeetings) ? c.additionalMeetings : []
    return [main] + extra
}

/// One meeting of one class, ready to draw on the week: the class it belongs
/// to, side by side with when it meets. The web spreads both into one object
/// (`expandClassMeetings` keeps the class's fields and adds `meetingId`); Swift
/// keeps them as two named parts, so `slot.course.name` and
/// `slot.meeting.start` say exactly where each value comes from.
struct MeetingSlot<C: Schedulable>: Identifiable {
    let course: C
    let meeting: ClassMeeting

    /// Unique per slot, even when one class meets twice on the same day.
    var id: String { meetingKey(self) }
}

/// Every meeting of every class, flattened into one list of slots.
/// `expandClassMeetings` in lib/class-meetings.ts.
func expandClassMeetings<C: Schedulable>(_ classes: [C]) -> [MeetingSlot<C>] {
    // `flatMap` turns "a list of lists" (each class's slots) into one list.
    classes.flatMap { c in
        classMeetings(c).map { MeetingSlot(course: c, meeting: $0) }
    }
}

/// True for a class added before its timetable was known: none of its
/// meetings has a day, so it never lands on the week. `isUnscheduled`.
func isUnscheduled<C: Schedulable>(_ c: C) -> Bool {
    classMeetings(c).allSatisfy { $0.days.isEmpty }
}

/// A slot's unique key. The main meeting keeps the class's own id (old links
/// still work); an extra meeting adds its own id after a colon.
/// `meetingKey` in lib/class-meetings.ts.
func meetingKey<C: Schedulable>(_ slot: MeetingSlot<C>) -> String {
    let courseKey = slot.course.id.uuidString
    return slot.meeting.id == primaryMeetingID
        ? courseKey
        : "\(courseKey):\(slot.meeting.id.uuidString)"
}

/// One line describing when a class meets, for lists:
/// "Mon/Wed 09:00–10:15 · Room 4; Lab: Fri 14:00–16:00".
/// `meetingSummary` in lib/class-meetings.ts.
func meetingSummary<C: Schedulable>(_ c: C) -> String {
    if isUnscheduled(c) { return "No set schedule yet" }
    let parts = classMeetings(c).map { m in
        // Like the web, an empty label or room counts as none.
        let label = nonEmpty(m.label).map { "\($0): " } ?? ""
        let room = nonEmpty(m.room).map { " · \($0)" } ?? ""
        // A day outside 0...6 would crash `dayLabels[d]`, so it shows as "?".
        let days = m.days.map { dayLabels.indices.contains($0) ? dayLabels[$0] : "?" }
        return "\(label)\(days.joined(separator: "/")) \(clock24(m.start))–\(clock24(m.end))\(room)"
    }
    return parts.joined(separator: "; ")
}

/// 545 -> "09:05", the 24-hour form `meetingSummary` uses.
private func clock24(_ mins: Int) -> String {
    String(format: "%02d:%02d", mins / 60, mins % 60)
}

/// The text, or nil when it's missing or empty.
private func nonEmpty(_ s: String?) -> String? {
    guard let s, !s.isEmpty else { return nil }
    return s
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Models.swift` (replaces the file)

Three changes, all marked: the `ClassMeeting` struct is gone (it's in 4.1 now), `extension Course: Schedulable {}` is new at the end of the Course section, and the two leftover Phase 1 fields in your `Assignment` (`var subtask` and `var snoozeUntil`, the old names next to `subtasks` and `snoozedUntil`) are gone. Your own comments can stay; only the code has to match.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Models.swift
//  Phase:   1 (complete data models), changed in 5a (ClassMeeting moved out,
//           Course signs up for Schedulable)
//  Ports:   lib/store.tsx (ClassItem, TaskItem), lib/palette.ts (SubjectColor),
//           lib/supabase/map.ts (column names)
//
//  Summary: The two core data types: a Course mirrors every client-owned
//           column of the `classes` table, an Assignment every client-owned
//           column of `tasks`. ClassMeeting now lives in Logic/ClassMeetings.swift.
//

import Foundation

/// The nine subject colors, by name. The web app stores the name ("teal"), not a
/// hex code, so the same name works in light and dark mode and syncs as-is.
/// `String` raw values mean each case is saved as its own name in the JSON.
// NEW in Phase 1 (replaces the hex strings)
enum SubjectColor: String, Codable, CaseIterable {
    case amber, indigo, coral, teal, pink, violet, mint, ocean, slate
}

// CHANGED in Phase 5a: `ClassMeeting` moved to Logic/ClassMeetings.swift, next
// to the logic that checks and expands it, so the Linux tests can compile it.

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

/// Course already has everything `Schedulable` asks for (id, days, startMin,
/// endMin, room, additionalMeetings), so signing it up is one empty line.
/// With it, classMeetings, expandClassMeetings and isUnscheduled accept courses.
// NEW in Phase 5a
extension Course: Schedulable {}

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

### 4.3 `~/ClassPing/Sources/ClassPing/Logic/Week.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Week.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   weekInfo and fmtMD from lib/store.tsx; isWithinTerm and
//           termRangeLabel from lib/time.ts; the week labels, hour labels
//           and grid bounds from app/week/page.tsx
//
//  Summary: Monday-to-Sunday week maths for the strip and the grid on Today:
//           which seven days a week holds, whether a day is inside the
//           semester, and the labels the week shows. Also home to the one
//           helper that turns Apple's weekday numbers into ClassPing's.
//

import Foundation

// MARK: - Days of the week

/// A date's day of the week in ClassPing's numbering: 0 = Monday ... 6 = Sunday.
/// This is the ONE place Apple's numbering is converted (IOS_APP.md 3.4):
/// `Calendar` says 1 = Sunday, 2 = Monday ... 7 = Saturday. Adding 5 and
/// taking the remainder after 7 shifts that so Monday lands on 0:
/// Monday 2 -> 0, Saturday 7 -> 5, Sunday 1 -> 6. The web writes the same
/// shift as `(getDay() + 6) % 7`, because JavaScript counts Sunday as 0.
func dayIndex(of date: Date) -> Int {
    let apple = Calendar.current.component(.weekday, from: date)
    return (apple + 5) % 7
}

/// A time of day as minutes from midnight: 10:40 AM -> 640. The unit every
/// class time uses, so the grid can compare "now" with a class's start.
func minuteOfDay(_ date: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

// MARK: - Weeks

/// The week the planner shows: its seven days and which column is today.
/// `weekInfo` in lib/store.tsx.
struct WeekInfo: Equatable {
    var dates: [Date]     // seven local midnights, Monday first
    var todayCol: Int     // 0 = Monday ... 6 = Sunday
}

/// The Monday-to-Sunday week that contains `now`. `weekInfo` in lib/store.tsx.
func weekInfo(_ now: Date) -> WeekInfo {
    WeekInfo(dates: weekDates(now, 0), todayCol: dayIndex(of: now))
}

/// The seven days of the week `offset` weeks away from `now`'s week:
/// 0 = this week, 1 = next week, -1 = last week. Each is local midnight.
/// The week page builds this from weekInfo's Monday plus 7 × offset days.
/// `scheduleDate` (Phase 2) does the calendar-aware day steps, so a
/// daylight-saving change can't knock a day off.
func weekDates(_ now: Date, _ offset: Int) -> [Date] {
    // Step back to this week's Monday, then whole weeks forward or back.
    let monday = scheduleDate(now, offset * 7 - dayIndex(of: now))
    // `(0..<7).map` makes the seven days, Monday + 0 ... Monday + 6.
    return (0..<7).map { scheduleDate(monday, $0) }
}

/// The week's big heading. `weekLabel` in app/week/page.tsx.
func weekTitle(_ offset: Int) -> String {
    // A `switch` can hand back a value directly. `case let n where n > 0`
    // matches any remaining number above zero and names it `n`.
    switch offset {
    case 0: "This Week"
    case 1: "Next Week"
    case -1: "Last Week"
    case let n where n > 0: "In \(n) Weeks"
    default: "\(-offset) Weeks Ago"
    }
}

/// The small caps line above it: "OCT 19 – 25", or "OCT 26 – NOV 1" when the
/// week crosses into a new month. `rangeLabel` in app/week/page.tsx.
func weekRangeLabel(_ dates: [Date]) -> String {
    guard let first = dates.first, let last = dates.last else { return "" }
    let cal = Calendar.current
    // "Oct", in English whatever the phone's language, like the web's "en-US".
    let month = DateFormatter()
    month.locale = Locale(identifier: "en_US_POSIX")
    month.dateFormat = "MMM"
    let startMonth = month.string(from: first).uppercased()
    // The month only repeats after the dash when it changes.
    let sameMonth = cal.component(.month, from: first) == cal.component(.month, from: last)
    let endMonth = sameMonth ? "" : month.string(from: last).uppercased() + " "
    return "\(startMonth) \(cal.component(.day, from: first)) – \(endMonth)\(cal.component(.day, from: last))"
}

/// "Jul 6" for a date. `fmtMD` in lib/store.tsx.
func fmtMD(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d"
    return f.string(from: d)
}

// MARK: - The semester

/// Does `date` fall inside the semester? `isWithinTerm` in lib/time.ts.
/// True when no term is set, and true for whichever half is set: the dates
/// exist to *bound* a timetable, never to hide one by accident. An inverted
/// range (end before start) is a typo, so it's ignored too.
func isWithinTerm(_ start: String?, _ end: String?, _ date: Date) -> Bool {
    // `flatMap` runs dayNumber (Phase 2) only on a present string, and keeps
    // nil for a missing or broken date.
    let s = start.flatMap(dayNumber)
    let e = end.flatMap(dayNumber)
    if let s, let e, e < s { return true }
    let day = todayNumber(date)
    if let s, day < s { return false }
    if let e, day > e { return false }
    return true
}

/// "Sep 1 – Dec 15", for telling you which window you're outside of.
/// "from Sep 1" or "until Dec 15" when only one end is set, nil when neither.
/// `termRangeLabel` in lib/time.ts.
func termRangeLabel(_ start: String?, _ end: String?) -> String? {
    let s = start.flatMap(monthDay)
    let e = end.flatMap(monthDay)
    // Switching on a pair. `s?` matches "s has a value" and unwraps it.
    switch (s, e) {
    case let (s?, e?): return "\(s) – \(e)"
    case let (s?, nil): return "from \(s)"
    case let (nil, e?): return "until \(e)"
    default: return nil
    }
}

/// "2026-09-01" -> "Sep 1". Read as a calendar day in UTC (like the web's
/// `timeZone: "UTC"`), so no time zone can move it to the 31st. Nil when the
/// string isn't a real date.
private func monthDay(_ iso: String) -> String? {
    guard let n = dayNumber(iso) else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "MMM d"
    // dayNumber counts days since 1 Jan 1970, so this is that day's UTC midnight.
    return f.string(from: Date(timeIntervalSince1970: Double(n) * 86_400))
}

// MARK: - The grid

/// The grid's usual hours: 8 AM to 5 PM. `DEFAULT_START_HOUR` / `DEFAULT_END_HOUR`.
let defaultStartHour = 8
let defaultEndHour = 17

/// The first and last hour lines the grid draws. It hugs the timetable: a
/// 7:30 AM lecture or a 6 PM seminar stretches it, so nothing is drawn off
/// the grid. `startHour` / `endHour` in app/week/page.tsx.
func gridHours(_ meetings: [ClassMeeting]) -> ClosedRange<Int> {
    // The earliest start, rounded down to its hour; the latest end, rounded up.
    // `.min()` and `.max()` are nil for an empty list, hence the defaults.
    let earliest = meetings.map { $0.start / 60 }.min() ?? defaultStartHour
    let latest = meetings.map { ($0.end + 59) / 60 }.max() ?? defaultEndHour
    return min(defaultStartHour, earliest)...max(defaultEndHour, latest)
}

/// The number beside an hour line: 8, 9 ... 12, then 1, 2 for the afternoon.
func hourLabel(_ hour: Int) -> String {
    "\(hour > 12 ? hour - 12 : hour)"
}

/// A class block's start time without AM/PM, "9:00", the way the grid
/// prints it (the web cuts " AM" / " PM" off `fmtHM`).
func fmtClock(_ mins: Int) -> String {
    // fmtTime (Phase 2) always ends in " AM" or " PM": drop those 3 characters.
    String(fmtTime(mins).dropLast(3))
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Design/Theme+Courses.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Courses.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   app/globals.css (--subj-<color>-bg / -text / -sub in light and
//           dark, --color-muted-2, --color-coral)
//
//  Summary: The colors a class block needs on the week grid: a soft block for
//           each subject color, the ink that reads on it and a quieter second
//           ink. In light mode the block is a pastel; in dark it's a faint
//           wash of the class color, so it never looks like a hole in the page.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade, the same helper Theme+Tasks.swift
/// keeps. Each file needs its own copy because `fileprivate` hides it from
/// every other file.
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

/// The six hex values behind one subject color, straight from globals.css:
/// the dot (`bar`, which Theme.subject also returns), the light block and its
/// two inks, and the two dark inks. A tuple is a quick unnamed group of values;
/// naming each part (`bg:`, `text:`) lets callers read `t.bg` instead of `t.1`.
fileprivate func tones(_ c: SubjectColor)
    -> (bar: String, bg: String, text: String, sub: String, darkText: String, darkSub: String) {
    switch c {
    case .amber:  ("#D9B36C", "#EAE1CE", "#795B28", "#917441", "#E8D1A7", "#E1C289")
    case .indigo: ("#8EA9C9", "#DEE2E8", "#465C77", "#64778D", "#BBCBDF", "#A5BAD4")
    case .coral:  ("#C99C8D", "#EADFD8", "#805B4D", "#997869", "#DFC4BB", "#D4B0A4")
    case .teal:   ("#9FBB8A", "#E0E5D8", "#4C6540", "#6B805B", "#C5D6B9", "#B2C9A1")
    case .pink:   ("#C99BAE", "#EADDE2", "#81546A", "#996F83", "#DFC3CE", "#D4AFBE")
    case .violet: ("#A99BC7", "#E3DEEA", "#655581", "#827297", "#CBC3DD", "#BAAFD2")
    case .mint:   ("#A4C1A0", "#DFE6DC", "#4C6948", "#6B8565", "#C8DAC6", "#B6CDB3")
    case .ocean:  ("#8BB6C6", "#DCE5E7", "#426675", "#658591", "#B9D3DD", "#A2C5D1")
    case .slate:  ("#98A4B5", "#E0E2E5", "#505D70", "#707C8D", "#C1C8D3", "#ADB6C4")
    }
}

extension Theme {
    /// The block a class sits on. `--subj-<color>-bg`: a pastel in light mode,
    /// the class color at 18 % strength in dark.
    static func subjectSoft(_ c: SubjectColor) -> Color {
        let t = tones(c)
        return shade(UIColor(hex: t.bg), UIColor(hex: t.bar).withAlphaComponent(0.18))
    }

    /// The class name's ink on that block. `--subj-<color>-text`.
    static func subjectInk(_ c: SubjectColor) -> Color {
        let t = tones(c)
        return shade(UIColor(hex: t.text), UIColor(hex: t.darkText))
    }

    /// The quieter ink for the time under it. `--subj-<color>-sub`.
    static func subjectSub(_ c: SubjectColor) -> Color {
        let t = tones(c)
        return shade(UIColor(hex: t.sub), UIColor(hex: t.darkSub))
    }

    /// The small caps above the week title. `--color-muted-2`.
    static let muted2 = shade(UIColor(hex: "#797164"), UIColor(hex: "#B2A8A2"))

    /// The "now" line across today's column. `bg-coral`, one shade in both modes.
    static let nowLine = Color(hex: "#C99C8D")
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Week/WeekStrip.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Week/WeekStrip.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   the day header of app/week/page.tsx, folded into Today (D-19);
//           the "Today · Wed, Oct 21" day pill on app/home/page.tsx
//
//  Summary: The folded week on Today: seven days in a row, today in a filled
//           circle, up to three colored dots per day for the classes that day.
//           Tapping a day picks it. Phase 6 shows that day's classes below.
//

import SwiftUI

struct WeekStrip: View {
    /// The classes to dot onto the days, already filtered to the live,
    /// unarchived ones by whoever shows the strip.
    let courses: [Course]
    /// The semester's ends ("yyyy-MM-dd"), so days outside it get no dots.
    let termStart: String?
    let termEnd: String?
    /// The moment this redraw is for, from Today's ticking clock.
    let now: Date
    /// Which week is showing (0 = this week). A `@Binding` because Today owns
    /// it and the grid shares it: browse to next week in the grid, fold it,
    /// and the strip is on next week too.
    @Binding var weekOffset: Int
    /// The day you picked, as local midnight. Also owned by Today.
    @Binding var selected: Date
    let accent: Profile.Accent

    /// One letter per column, Monday first.
    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let dates = weekDates(now, weekOffset)
        let slots = expandClassMeetings(courses)
        let brand = Theme.brand(accent)

        VStack(spacing: 8) {
            // The range on the left; on the right "This Week", or a way back
            // to it when you've browsed away in the grid.
            HStack {
                Text(weekRangeLabel(dates))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted2)
                Spacer()
                if weekOffset == 0 {
                    Text("This Week")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(brand)
                } else {
                    Button("Back to this week") {
                        weekOffset = 0
                        selected = scheduleDate(now, 0)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(brand)
                }
            }
            .padding(.horizontal, 8)

            // The seven days. `0..<7` is Monday to Sunday; `id: \.self` tells
            // ForEach the numbers themselves tell the columns apart.
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { col in
                    dayButton(col, dates[col], dots(on: col, dates[col], slots), brand)
                }
            }
        }
    }

    /// The color of every class on one day, earliest first. Days outside the
    /// semester get none, the same rule the grid follows.
    private func dots(on col: Int, _ date: Date, _ slots: [MeetingSlot<Course>]) -> [SubjectColor] {
        guard isWithinTerm(termStart, termEnd, date) else { return [] }
        return slots.filter { $0.meeting.days.contains(col) }
            .sorted { $0.meeting.start < $1.meeting.start }
            .map { $0.course.color }        // swap each slot for its color
    }

    /// One day: its letter, its date in a circle, and the class dots.
    private func dayButton(_ col: Int, _ date: Date, _ dots: [SubjectColor], _ brand: Color) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDate(date, inSameDayAs: now)
        let isPicked = cal.isDate(date, inSameDayAs: selected)
        // At most three dots fit under a day. `prefix(3)` keeps the first three.
        let shown = Array(dots.prefix(3))

        return Button {
            selected = date
        } label: {
            VStack(spacing: 4) {
                Text(letters[col])
                    .font(.system(size: 11, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? brand : Theme.faint)

                // Today: a filled brand circle. A picked day that isn't today:
                // a brand ring. `.background` and `.overlay` take a view, and
                // an `if` inside them draws it only when the condition holds.
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? Color.white : Theme.muted)
                    .frame(width: 32, height: 32)
                    .background {
                        if isToday { Circle().fill(brand) }
                    }
                    .overlay {
                        if isPicked && !isToday { Circle().stroke(brand, lineWidth: 1.5) }
                    }

                // The dots, in a fixed-height row so days without classes
                // line up with the rest.
                HStack(spacing: 3) {
                    ForEach(shown.indices, id: \.self) { i in
                        Circle()
                            .fill(Theme.subject(shown[i]))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            // Makes the whole column tappable, not just the text and circles.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // VoiceOver hears "Wednesday, October 21, 3 classes" instead of "W 21".
        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(classCount(dots.count))")
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    /// "no classes", "1 class", "4 classes", for VoiceOver.
    private func classCount(_ n: Int) -> String {
        switch n {
        case 0: "no classes"
        case 1: "1 class"
        default: "\(n) classes"
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Week/WeekGrid.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Week/WeekGrid.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   app/week/page.tsx (WeekScreen and ClassBlock), opened inside
//           Today instead of on its own tab (D-19)
//
//  Summary: The whole week as a timetable: a heading with week arrows, the
//           seven days, an hour scale, every class as a colored block at its
//           time, a line for "now", and the classes that have no times yet.
//           Today shows it when you open the week; tapping a block calls back.
//

import SwiftUI

struct WeekGrid: View {
    /// The classes to draw (live and unarchived; Today filters them).
    let courses: [Course]
    /// The semester's ends, "yyyy-MM-dd", so days outside it stay empty.
    let termStart: String?
    let termEnd: String?
    /// The moment this redraw is for, from Today's ticking clock.
    let now: Date
    /// Which week is showing: 0 = this week. Shared with the strip.
    @Binding var weekOffset: Int
    let accent: Profile.Accent

    /// What to do when a class block is tapped: the slot, its column
    /// (0 = Monday) and that column's date. A closure, so the grid doesn't
    /// need to know what happens next: Phase 5b's Today opens the class
    /// details. Until then the default does nothing.
    var onOpen: (MeetingSlot<Course>, Int, Date) -> Void = { _, _, _ in }

    /// What to do when a "Not yet scheduled" chip is tapped. Phase 5b opens
    /// the class form so you can add its times.
    var onSchedule: (Course) -> Void = { _ in }

    /// How tall one hour is, in points. The web uses 62 on a page of its own;
    /// inside the Today card the grid has to fit a phone, so it's tighter.
    private let hourHeight: CGFloat = 36
    /// The width of the hour numbers' column on the left.
    private let gutter: CGFloat = 26

    var body: some View {
        // Work out everything the grid needs once per redraw.
        let dates = weekDates(now, weekOffset)
        // "Today" markers only belong on the current week.
        let todayCol: Int? = weekOffset == 0 ? dayIndex(of: now) : nil
        // Per day, because a term can start or end mid-week.
        let inTerm = dates.map { isWithinTerm(termStart, termEnd, $0) }
        let slots = expandClassMeetings(courses)
        let unscheduled = courses.filter { isUnscheduled($0) }
        let hours = gridHours(slots.map(\.meeting))
        let brand = Theme.brand(accent)

        VStack(alignment: .leading, spacing: 10) {
            header(dates, brand)

            // The whole week is outside the semester: say so once, rather
            // than leave an empty grid that looks broken.
            if !inTerm.contains(true) && !courses.isEmpty {
                outOfTermNote(brand)
            }

            dayHeader(dates, todayCol, brand)
            plot(hours, slots, dates, inTerm, todayCol, brand)

            if !unscheduled.isEmpty {
                notScheduled(unscheduled, brand)
            }
        }
    }

    // MARK: - Heading

    /// "OCT 19 – 25" over "This Week", with the previous/next arrows.
    private func header(_ dates: [Date], _ brand: Color) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text(weekRangeLabel(dates))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted2)
                Text(weekTitle(weekOffset))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            arrow("chevron.left", "Previous week", brand) { weekOffset -= 1 }
            arrow("chevron.right", "Next week", brand) { weekOffset += 1 }
        }
        .padding(.horizontal, 4)
    }

    /// One round arrow button. `@escaping` marks a closure that's kept and
    /// run later (when the button is tapped), not straight away.
    private func arrow(_ symbol: String, _ label: String, _ brand: Color,
                       _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(brand)
                .frame(width: 38, height: 38)
                .background(Theme.card, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// "This week is outside your semester (Sep 1 – Dec 15), nothing is timetabled."
    private func outOfTermNote(_ brand: Color) -> some View {
        let range = termRangeLabel(termStart, termEnd).map { " (\($0))" } ?? ""
        return Text("This week is outside your semester\(range), nothing is timetabled.")
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(brand.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// MON 19, TUE 20 ... with today's date in a brand circle.
    private func dayHeader(_ dates: [Date], _ todayCol: Int?, _ brand: Color) -> some View {
        let names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        return HStack(spacing: 0) {
            // An empty slot the width of the hour column, so the days line up.
            Color.clear.frame(width: gutter, height: 1)
            ForEach(0..<7, id: \.self) { col in
                // A `let` inside a ForEach's closure: worked out once per column.
                let isToday = col == todayCol
                VStack(spacing: 3) {
                    Text(names[col])
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isToday ? brand : Theme.faint)
                    Text("\(Calendar.current.component(.day, from: dates[col]))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isToday ? Color.white : Theme.muted)
                        .frame(width: 26, height: 26)
                        .background(isToday ? brand : Color.clear, in: Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - The plot

    /// Minutes from midnight -> points down from the top of the plot. `top` is
    /// the first hour line in minutes (480 for 8 AM). The web's `y(mins)`.
    private func y(_ mins: Int, _ top: Int) -> CGFloat {
        CGFloat(mins - top) / 60 * hourHeight
    }

    /// The timetable itself: hour numbers on the left, then seven columns.
    /// Everything inside is placed by numbers, like absolute positioning in
    /// CSS: a `ZStack` piles its children on top of each other, all starting
    /// at its top edge, and `.offset(y:)` slides each one down to its time.
    /// An offset moves what you see without moving anything else, so the
    /// blocks can't push each other around.
    private func plot(_ hours: ClosedRange<Int>, _ slots: [MeetingSlot<Course>],
                      _ dates: [Date], _ inTerm: [Bool], _ todayCol: Int?,
                      _ brand: Color) -> some View {
        let top = hours.lowerBound * 60
        let height = CGFloat(hours.count - 1) * hourHeight
        let nowMin = minuteOfDay(now)
        // The now line only shows on the current week, inside the drawn hours.
        let showNow = todayCol != nil && nowMin >= top && nowMin <= hours.upperBound * 60

        return HStack(alignment: .top, spacing: 0) {
            // The hour numbers. `Array(hours)` turns 8...17 into [8, 9, ... 17].
            // Each label is lifted half its height so it sits on its line.
            ZStack(alignment: .topTrailing) {
                ForEach(Array(hours), id: \.self) { h in
                    Text(hourLabel(h))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                        .offset(y: y(h * 60, top) - 6)
                }
            }
            .padding(.trailing, 6)
            .frame(width: gutter, height: height, alignment: .topTrailing)

            ZStack(alignment: .topLeading) {
                // A hairline at every hour, across all seven days.
                ForEach(Array(hours), id: \.self) { h in
                    Rectangle()
                        .fill(Theme.line)
                        .frame(height: 1)
                        .offset(y: y(h * 60, top))
                }

                // The seven day columns, side by side.
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        column(col, slots, dates[col], inTerm[col], col == todayCol, top, brand)
                    }
                }

                // Now: a coral line with a dot at its left end.
                if showNow {
                    Rectangle()
                        .fill(Theme.nowLine)
                        .frame(height: 2)
                        .offset(y: y(nowMin, top) - 1)
                    Circle()
                        .fill(Theme.nowLine)
                        .frame(width: 7, height: 7)
                        .offset(x: -3, y: y(nowMin, top) - 3.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .top)
        }
        // The labels and the dot poke a few points outside the plot; keep
        // them from being clipped and give the last label room.
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// One day's column: a faint wash if it's today, then its class blocks.
    private func column(_ col: Int, _ slots: [MeetingSlot<Course>], _ date: Date,
                        _ inTerm: Bool, _ isToday: Bool, _ top: Int,
                        _ brand: Color) -> some View {
        // A day outside the semester has nothing on it.
        let daySlots = inTerm ? slots.filter { $0.meeting.days.contains(col) } : []
        return ZStack(alignment: .top) {
            Rectangle().fill(isToday ? brand.opacity(0.06) : Color.clear)
            // MeetingSlot is Identifiable, so ForEach can use it directly.
            ForEach(daySlots) { slot in
                block(slot, col, date, top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A hairline between days (not before Monday).
        .overlay(alignment: .leading) {
            if col > 0 {
                Rectangle().fill(Theme.line).frame(width: 1)
            }
        }
    }

    /// One class block: short name and start time on the class's soft color,
    /// with a stripe of its dot color down the left. `ClassBlock` on the web.
    private func block(_ slot: MeetingSlot<Course>, _ col: Int, _ date: Date, _ top: Int) -> some View {
        let course = slot.course
        let meeting = slot.meeting
        // At least 30 points tall, so even a short class has room for its name.
        let height = max(y(meeting.end, top) - y(meeting.start, top), 30)

        return Button {
            onOpen(slot, col, date)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(course.short)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.subjectInk(course.color))
                    .lineLimit(2)
                Text(fmtClock(meeting.start))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.subjectSub(course.color))
            }
            .padding(.leading, 6)
            .padding(.trailing, 2)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: height, alignment: .topLeading)
            .background(Theme.subjectSoft(course.color))
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.subject(course.color)).frame(width: 3)
            }
            // Clipping last trims the stripe and any text that doesn't fit
            // to the block's rounded shape.
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .offset(y: y(meeting.start, top))
        .accessibilityLabel("\(course.name), \(fmtTime(meeting.start))")
    }

    // MARK: - Not yet scheduled

    /// Classes added before their times were known never land on the grid, so
    /// they're listed here instead. Tapping one opens it to add times (5b).
    private func notScheduled(_ list: [Course], _ brand: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOT YET SCHEDULED")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            // Sideways scrolling, because a row of names can be wider than a phone.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(list) { course in
                        Button(course.name) { onSchedule(course) }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(brand)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(brand.opacity(0.16), in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(brand.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/ProfileView.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   the profile card and the Appearance / App color sections of
//           app/settings/page.tsx, moved into their own tab (D-19)
//
//  Summary: The Profile tab. For now: your avatar and name, the Appearance
//           card (moved here from Today), and a list of what arrives in this
//           tab later. Phase 11 builds the full settings, Phase 12 your level.
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
                // MARK: You
                VStack(spacing: 10) {
                    AvatarBadge(name: store.profile.username, size: 84, accent: accent)
                    Text(store.profile.username.isEmpty ? "Your profile" : store.profile.username)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Your level, streak and trophies arrive here in Phase 12.")
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

                // MARK: Coming to this tab
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("COMING TO THIS TAB")
                    comingRow("graduationcap", "Grades & GPA", "Phase 9")
                    comingRow("bell", "Reminders and quiet hours", "Phase 7")
                    comingRow("calendar", "Semester, backups, Recently Deleted", "Phase 11")
                    comingRow("person.crop.circle", "Your name, photo and account", "Phases 11 and 14")
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

    /// One "coming later" line: an icon, what it is, and which phase builds it.
    private func comingRow(_ symbol: String, _ title: String, _ phase: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.faint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(phase)
                .font(.caption)
                .foregroundStyle(Theme.muted)
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
```

### 4.8 `~/ClassPing/Sources/ClassPing/Screens/TodayView.swift` (replaces the file)

Rewritten: the temporary Appearance card and its save-on-change moved to `ProfileView` (4.7), and the week card is new.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/TodayView.swift
//  Phase:   3 (app shell), rewritten in 5a (the week lives here now, D-19)
//  Ports:   app/home/page.tsx (the greeting and day picking) and
//           app/week/page.tsx (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Phase 6 adds the
//           picked day's classes, priorities and planned work below.
//

import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store

    // MARK: Screen state
    // NEW in Phase 5a. None of this is saved: Today always opens on this
    // week, folded, with today picked.

    /// True when the week is open as the full grid, false when it's the strip.
    @State private var weekOpen = false
    /// Which week the strip and grid show: 0 = this week, 1 = next, -1 = last.
    @State private var weekOffset = 0
    /// The day picked in the strip, as local midnight. Starts on today.
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    var body: some View {
        // `TimelineView` redraws what's inside it on a schedule. `.everyMinute`
        // fires at the start of each minute and hands over the time as
        // `context.date`, so the now line moves and "today" rolls over at
        // midnight without a timer of our own. (The web uses `useNow()`.)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let accent = store.profile.accent
            // The classes on this term's timetable: not deleted, not archived.
            // `activeClasses` in lib/store.tsx; Phase 5b moves it into the store.
            let courses = store.courses.filter { $0.deletedAt == nil && !$0.archived }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(greeting(now))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted2)

                    weekCard(courses, now, accent)
                    dayCard(courses)
                }
                .padding(16)
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Today")
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
                         weekOffset: $weekOffset, accent: accent)
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
        withAnimation(.snappy) {
            weekOpen.toggle()
        }
    }

    // MARK: - The picked day

    /// A one-line look at the day picked in the strip. Phase 6 replaces this
    /// card with that day's class cards, priorities and planned work.
    private func dayCard(_ courses: [Course]) -> some View {
        let col = dayIndex(of: selectedDay)
        let inTerm = isWithinTerm(store.profile.termStart, store.profile.termEnd, selectedDay)
        let count = inTerm
            ? expandClassMeetings(courses).filter { $0.meeting.days.contains(col) }.count
            : 0
        // "Wednesday", in the phone's language.
        let dayName = selectedDay.formatted(.dateTime.weekday(.wide))
        let headline = switch count {
        case 0: "No classes on \(dayName)"
        case 1: "\(dayName) · 1 class"
        default: "\(dayName) · \(count) classes"
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Phase 6 lists that day's classes here, with your priorities and planned work.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "Good morning, Kelvin". The web's `greeting(hour)` plus the first part
    /// of your username; just the greeting until you've set a name.
    private func greeting(_ now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let hello = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        // "kelvin.m" -> "kelvin": the web splits on dots, spaces, _ and -.
        let first = store.profile.username
            .split(whereSeparator: { $0.isWhitespace || "._-".contains($0) })
            .first.map(String.init) ?? ""
        return first.isEmpty ? hello : "\(hello), \(first)"
    }
}
```

### 4.9 `~/ClassPing/Sources/ClassPing/RootView.swift` (replaces the file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   3 (app shell), changed in 5a (Profile tab replaces Planner, D-19)
//  Ports:   components/TabBar.tsx (four tabs with the Add button between them)
//
//  Summary: The screen under everything else. A custom bottom bar switches
//           between the four main screens, Today, Notes, Tasks and Profile,
//           with the brand Add button raised in the middle. The week now lives
//           inside Today. The whole app is tinted with the chosen accent and
//           forced to the chosen light/dark mode here.
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

    var body: some View {
        // Read the accent once; reading it here means the whole screen redraws
        // (new tint, new bar colors) the moment it changes in Profile.
        let accent = store.profile.accent

        // The selected screen. Each tab keeps its own NavigationStack, so it has
        // its own back history, the way each web route keeps its own URL.
        Group {
            switch tab {
            case .today:   NavigationStack { TodayView() }
            case .notes:   NavigationStack { NotesView() }
            case .tasks:   NavigationStack { AssignmentsView().navigationTitle("Tasks") }
            case .profile: NavigationStack { ProfileView() }    // NEW in Phase 5a
            }
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
            .frame(maxWidth: .infinity)
            .foregroundStyle(active ? Theme.brand(accent) : Theme.faint)
        }
        .buttonStyle(.plain)
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
            .frame(maxWidth: .infinity)
            .foregroundStyle(active ? brand : Theme.faint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
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

**You don't type the tests.** `docs/ios/reference/Tests/Logic/ClassMeetingsTests.swift` and `WeekTests.swift` prove the two Logic files behave like the web code. They run on Linux with `logic-test.sh`.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev
```

Then on the phone:

1. Look at the bar: Today, Notes, +, Tasks and your avatar labelled Profile.
2. On **Today**, find the week strip. Today's date is in a filled circle and the days with sample classes have dots (the sample has classes Monday to Friday).
3. Tap Thursday. It gets a ring and the card below says "Thursday · 2 classes". Tap Saturday: "No classes on Saturday".
4. Tap the **calendar button** at the top right. The card opens into the timetable. If it's a weekday during the sample's class hours, a coral line crosses the grid at the current time.
5. Tap **›** twice ("In 2 Weeks"), then fold the week with the button. The strip is on that week too, with **Back to this week** at the top right.
6. Open **Profile**. Switch Dark and Ocean. Close the app completely, reopen it: both stuck.

When it works: `git add -A && git commit -m "phase 5a"`.

## 6. Done when

- [ ] The bar is Today · Notes · + · Tasks · Profile, and the + still opens the Add menu.
- [ ] The strip shows the right week, today circled, dots on the class days.
- [ ] Picking a day rings it and the card below names it with the right class count.
- [ ] The calendar button and the handle both open and fold the week, with a smooth animation.
- [ ] The grid shows the sample classes on the right days and times; the arrows browse weeks; the title says This Week / Next Week / In 2 Weeks.
- [ ] Theme and app color changes on Profile survive a relaunch.

## 7. If it breaks

- **`invalid redeclaration of 'ClassMeeting'`**: `Logic/ClassMeetings.swift` is in, but `Models.swift` still has the old struct. Finish 4.2.
- **`type 'Theme' has no member 'subject'`** (or `lineStrong`): Phase 4b's `Design/Theme+Tasks.swift` isn't in the project. Type Phase 4b first.
- **`cannot find 'WeekView' in scope`** or **`type 'MainTab' has no member 'planner'`**: one of 4.9 (`RootView`) or the `git rm` hasn't happened yet. Both go together.
- **Every block sits at the top of the grid**: a missing `.offset(y: y(meeting.start, top))` at the end of `block(...)` in 4.6.
- **Dragging the handle scrolls the page instead**: use the calendar button for now, and tell Claude; the drag is the one part that can only be tried on the phone.

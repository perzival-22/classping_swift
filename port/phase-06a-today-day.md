---
title: "Phase 6a: Today, the picked day"
date: 2026-10-17
generated_by: skills-for-architects
---

# Phase 6a: Today, the picked day

*First half of Phase 6 (D-24). Checked on 2026-10-17 on top of your Phase 5 project (commit `3fd880f`) plus Phase 4b: `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 96/96 (9 new: quotes), `persistence-test.sh` passed 4/4.*

**Before you start: type Phase 4b.** Your Phase 5 commit has only 4b's `Theme+Tasks.swift`; its other four files (`Assignment+TaskView.swift`, `TaskFilterBar.swift`, `AssignmentDetailView.swift`, and `AssignmentsView.swift` in `Screens/Tasks/`) and the new `Components/UndoBar.swift` aren't in your project, so your Tasks tab is still the Phase 2 list. 6a would build without them, but 6b opens 4b's detail screen and uses its Undo bar, so type [phase-04b-tasks-screen.md](phase-04b-tasks-screen.md) from section 4.2, build, commit, then start here.

## 1. Goal

Today shows the day you picked, the way the web's home page does.

**On your phone:** under the week, a quote banner ("A LITTLE PUSH") with a pencil. Tap the pencil, the keyboard comes up in an editor where you write your own quotes, one per line; **Save quotes** and the banner says "YOUR REMINDER" and shows one of yours (they change every two hours, in step with the web app). Below it, the picked day's classes as cards, each with its color bar, a little book with the short name, the time and room, and **open** by default: days, time, room, teacher and your class note. Tap a card to fold it. On today, a class that's on says **Now**, a finished one fades and says **Done**, and the rest show a bell and their start time. Pick Saturday in the strip and you get "Looks like you're free!" with **View Sunday's schedule**; keep going to Monday and the strip jumps to next week. On a day with classes, a quieter **View Tuesday's schedule** row sits underneath. The title says "Today", or the picked day's name.

**What Phase 6 doesn't build, and why (D-23).** The old plan for this phase said "next class, planned work, three priorities". The web app has moved on: `QuoteBanner.tsx` says it *replaces* the old "choose what matters most" priorities card, and the home page has no planned-work list. Planning a day for a task lives on the task's detail page ("Plan the work"), next to exam prep, so it moves to Phase 7 with the rest of `lib/planning.ts`. "Next class" is the Now tag and the bell time on the cards.

## 2. New Swift concepts

**A child view with its own `@State`.** Until now the screens kept all their state at the top and handed bindings down. `ClassCard` keeps its own: `@State private var open = true`. Every card in the list gets a separate `open`, so folding Biology leaves Chemistry alone. SwiftUI tells the cards apart by the `id` the `ForEach` gives them (each meeting's key), and keeps a card's state for as long as that card stays on screen. Pick another day and the new cards start open again.

```swift
struct ClassCard: View {
    let slot: MeetingSlot<Course>
    @State private var open = true          // this card's own memory
    var body: some View {
        Button { open.toggle() } label: { ... }
        if open { details }
    }
}
ForEach(dayClasses) { slot in ClassCard(slot: slot, nowMin: nowMin) }
```

**`@FocusState`.** A property SwiftUI keeps in step with the keyboard. Attach it to a field with `.focused($fieldFocused)`; set it to `true` and that field gets the cursor and the keyboard comes up. The web does this with `autoFocus`. The field only exists once the editor is showing, so the quote editor sets it in the field's `.onAppear`.

```swift
@FocusState private var fieldFocused: Bool
TextField("...", text: $draft, axis: .vertical)
    .focused($fieldFocused)
    .onAppear { fieldFocused = true }
```

**A `TextField` that grows.** `axis: .vertical` turns a one-line field into one that grows downwards as you type, and Return adds a new line instead of finishing. `.lineLimit(5...10)` reads "at least 5 lines tall, then scroll inside after 10". Phase 8's note editor uses the bigger `TextEditor`; for a short list of quotes this is enough.

You'll also meet `Group` (one set of modifiers for an `if`/`else` that returns two different views), `.rotationEffect` (the chevron swings when a card folds), and a `@ViewBuilder` function with `let`s at the top, which is how the day section works out its numbers before drawing.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `lib/quotes.ts` | `Logic/Quotes.swift` | Same ten quotes in the same order, the same caps (30 quotes, 200 characters) and the same two-hour slots counted from 1970, so the phone and the web show the same quote at the same moment. Takes `[String]`: the web's checks for numbers and `null` in the list can't happen in Swift |
| `components/QuoteBanner.tsx` | `Screens/Today/QuoteBanner.swift` | Same words, editor and buttons. Saves your list to `profile.quotes` straight away, which syncs once Phase 14 exists |
| `ClassCard`, `ClassDetail`, `fmtRange` in `app/home/page.tsx` | `Screens/Today/ClassCard.swift` | Same open-by-default card, tags, rows and times. The meeting's label ("Lab") isn't shown, as on the web |
| `components/SubjectBook.tsx` and `.subject-book` in `globals.css` | `Components/SubjectBook.swift` | Drawn with SwiftUI shapes: the board, the pages, the tinted cover and the spine. Close to the web, not pixel-perfect |
| the middle of `app/home/page.tsx` | `Screens/Today/TodayView.swift` | Same messages, buttons and rules (including when "You're all free this week!" may show). The day arrows and pill are the 5a strip. Not here yet: the pet card (Phase 12), the "just finished, log it" banner (Phase 7), the "Change semester dates" button (Phase 11) and "Import my schedule" (Phase 13) |
| first-run card and `OnboardStep` | `firstRun` in `TodayView` | The manual route is the button until import exists. Step 2 says "from the calendar button" instead of "on the Week tab" (D-19) |
| `--brand-soft`, `--good-ink` in `globals.css` | `Design/Theme+Today.swift` | An extension, like Theme+Tasks.swift |

**One fix first.** In `Records.swift`, the `Note` type has two misspelled fields: `assignemntID` and `updateAt`. Swift saves each field under its name, and `updateAt` isn't optional, so if notes were ever saved under the wrong names, renaming them later would make your whole `planner.json` unreadable. No notes exist yet (they arrive in Phase 8), so fixing the names now costs nothing. They become `assignmentID` and `updatedAt`, matching every other model and the `notes` table.

## 4. Files, in the order to type them

First make the Today folder and move the screen into it. `git mv` moves the file and tells git it's the same file, so its history comes along:

```bash
cd ~/ClassPing/Sources/ClassPing
mkdir -p Screens/Today
git mv Screens/TodayView.swift Screens/Today/TodayView.swift
```

### 4.1 `~/ClassPing/Sources/ClassPing/Records.swift` (replaces the file)

Only the two `Note` lines marked `CHANGED in Phase 6a` and the header's Phase line differ from what you typed.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Records.swift
//  Phase:   1 (complete data models), two field names fixed in 6a
//  Ports:   lib/store.tsx (GradeItem), lib/notes.ts (NoteItem),
//           lib/planning.ts (TaskPlan, StudySession), lib/supabase/map.ts
//
//  Summary: The four smaller record types: grades, notes, planned work days and
//           finished study blocks. Each mirrors its Supabase table.
//
import Foundation

/// One graded resuilt., mirrors the grades table

struct Grade: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {case exam, quiz, assignment, project}

    var id = UUID()
    var courseID: UUID?
    var title: String
    var score: Double
    var max: Double
    var weight: Double
    var date: String
    var kind: Kind? = nil
    var deletedAt: Date? = nil
}

///Once lecture not or quiz note, mirrors the 'notes' table
struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var courseID: UUID?
    var date: String
    var title = ""
    var body = ""
    var assignmentID: UUID? = nil   // CHANGED in Phase 6a: was `assignemntID`

    var updatedAt = Date()          // CHANGED in Phase 6a: was `updateAt`
    var deletedAt:  Date? = nil
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
///One finished focus black. 

struct StudySession: Identifiable, Codable, Hashable {
    //which timer recorded it

    enum Mode: String, Codable {case timer, pomodoro}

    var id = UUID()
    var assignmentID: UUID?
    var courseID: UUID?
    var minutes: Int             // 1 to 240
    var completedAt: Date        // an instant: when the block finished
    var mode = Mode.timer
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/Quotes.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Quotes.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   lib/quotes.ts (DEFAULT_QUOTES, MAX_QUOTES, MAX_QUOTE_CHARS,
//           normalizeQuotes, quoteFor)
//
//  Summary: The motivational line at the top of Today. It changes every two
//           hours, and which one shows is worked out from the clock alone, so
//           the phone and the web app show the same quote at the same moment
//           without syncing anything. Your own list wins over the built-in one.
//

import Foundation

/// The built-in rotation, used until you write your own. `DEFAULT_QUOTES`,
/// word for word, in the same order (the order decides which shows when).
let defaultQuotes = [
    "Small steps every day add up to big results.",
    "You don't have to be perfect, you just have to start.",
    "Focus on progress, not perfection.",
    "The work you do today is a gift to the you of next week.",
    "One page, one problem, one push at a time.",
    "Discipline is choosing what you want most over what you want now.",
    "Done is better than perfect.",
    "Your future self is watching you right now through memories.",
    "A little progress each day beats a burst once a week.",
    "Show up, even when it's just for ten minutes.",
]

/// Ceilings, so a pasted essay can't become the banner. `MAX_QUOTES` and
/// `MAX_QUOTE_CHARS` in lib/quotes.ts.
let maxQuotes = 30
let maxQuoteChars = 200

/// How long each quote stays up: two hours, in seconds. The web counts in
/// milliseconds (`ROTATE_MS`); a Swift `Date` counts in seconds.
private let rotateSeconds: Double = 2 * 60 * 60

/// Cleans up a list of quotes: each one trimmed and cut to 200 characters,
/// blanks dropped, and at most 30 kept. `normalizeQuotes` in lib/quotes.ts.
/// The web also has to throw out things that aren't text at all, because its
/// list can come from anywhere; a Swift `[String]` can only hold text.
func normalizeQuotes(_ raw: [String]) -> [String] {
    // Three steps, chained: tidy each one, drop the empty ones, keep 30.
    // `prefix(n)` takes the first n items (or characters) and never crashes
    // when there are fewer; `Array(...)` turns the result back into a list.
    let tidied = raw.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxQuoteChars)) }
    return Array(tidied.filter { !$0.isEmpty }.prefix(maxQuotes))
}

/// The quote to show at `now`: yours if you have any, else the built-in
/// ones. Empty only if both lists are, which the banner treats as "show
/// nothing". `quoteFor` in lib/quotes.ts.
func quoteFor(_ quotes: [String], _ now: Date) -> String {
    let list = quotes.isEmpty ? defaultQuotes : quotes
    guard !list.isEmpty else { return "" }

    // Which two-hour slot of time `now` is in, counted from 1 January 1970.
    // Every phone and browser agrees on that number, so they agree on the quote.
    let slot = Int((now.timeIntervalSince1970 / rotateSeconds).rounded(.down))

    // The slot picks a quote, wrapping round the list. `%` can come out
    // negative for a negative number, so add the count and take `%` again:
    // the same "positive modulo" the web uses.
    let count = list.count
    return list[((slot % count) + count) % count]
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Design/Theme+Today.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Today.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   app/globals.css (--brand-soft, --good-ink)
//
//  Summary: The two tokens Today adds: the soft brand wash behind its pills
//           and buttons, and the green ink for "days clear". An extension, like
//           Theme+Tasks.swift, so the earlier Theme files stay as typed.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade. Each Theme file keeps its own copy,
/// because `fileprivate` hides it from every other file.
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

extension Theme {
    /// The brand color, faint: the wash behind the "View all" and "Add" pills
    /// and the "Now" day pill. `--brand-soft` is the brand at 16 % strength in
    /// light mode and 22 % in dark, so it reads the same on both canvases.
    static func brandSoft(_ a: Profile.Accent) -> Color {
        // The brand's hex, the same two values `brand(_:)` in Theme.swift uses.
        let hex = a == .babypink ? "#E85D8A" : "#3B82C4"
        // `withAlphaComponent` makes a see-through copy of a UIColor.
        return shade(UIColor(hex: hex).withAlphaComponent(0.16),
                     UIColor(hex: hex).withAlphaComponent(0.22))
    }

    /// Green text for good news ("12 days clear"). `--good-ink`.
    static let goodInk = shade(UIColor(hex: "#456F3D"), UIColor(hex: "#B6CDA5"))
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Components/SubjectBook.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Components/SubjectBook.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   components/SubjectBook.tsx and its `.subject-book` styles in
//           app/globals.css
//
//  Summary: The little hardcover book in the class's color, with its short
//           name on the cover. Today's class cards use the full size; the
//           My Classes list (Phase 6b) uses the compact one.
//

import SwiftUI

struct SubjectBook: View {
    let color: SubjectColor
    /// The class's short name, "Bio", printed on the cover.
    let short: String
    /// The narrower book for lists. `compact` on the web.
    var compact = false

    var body: some View {
        // The web sizes the book by width with a 16:9 shape: 64 or 56 points
        // wide, so 36 or 31.5 tall.
        let width: CGFloat = compact ? 56 : 64
        let height = width * 9 / 16
        let bar = Theme.subject(color)

        // `ZStack` piles views on top of each other, first one at the back.
        // `alignment: .leading` lines them up on the left edge, where the
        // spine goes.
        ZStack(alignment: .leading) {
            // The back board, in the class color, with the shadow under it.
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(bar)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 1, y: 3)

            // The pages, a cream edge showing below the cover. `.padding`
            // insets it like the CSS `inset: 5px 2px 2px 6px`.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#F5F0E5"))
                .padding(EdgeInsets(top: 5, leading: 6, bottom: 2, trailing: 2))

            // The cover: the card color tinted 38 % with the class color, a
            // darker outline, and the short name. It stops 5 points above the
            // bottom so the pages show.
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.card)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(bar.opacity(0.38))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(bar, lineWidth: 1)
                Text(short)
                    .font(.system(size: compact ? 10 : 11, weight: .heavy))
                    .foregroundStyle(Theme.subjectInk(color))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 11)
                    .padding(.trailing, 4)
            }
            .padding(.bottom, 5)

            // The spine: a 7-point strip of the class color down the left,
            // shaded darker at both edges like the web's gradient.
            LinearGradient(colors: [.black.opacity(0.16), .clear, .black.opacity(0.15)],
                           startPoint: .leading, endPoint: .trailing)
                .background(bar)
                .frame(width: 7)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.bottom, 5)
        }
        .frame(width: width, height: height)
        // Decoration only: the class name is already read out beside it.
        .accessibilityHidden(true)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Today/ClassCard.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/ClassCard.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   ClassCard, ClassDetail and fmtRange in app/home/page.tsx
//
//  Summary: One class meeting on the picked day: the color bar, the book, the
//           name, the time and room, and a Now / Done / reminder-time tag. It
//           starts open, showing the days, time, room, teacher and your notes,
//           because between classes the room is what you need. Tap it to fold.
//

import SwiftUI

/// "9:00 – 10:15 AM", or "11:00 AM – 12:15 PM" when it crosses noon.
/// `fmtRange` in app/home/page.tsx. Built on `fmtTime` from Phase 2, which
/// always ends in " AM" or " PM".
func fmtRange(_ start: Int, _ end: Int) -> String {
    let from = fmtTime(start)
    let to = fmtTime(end)
    // Same half of the day: say AM or PM once, at the end, by cutting the
    // last three characters (" AM") off the start time.
    return from.suffix(2) == to.suffix(2) ? "\(from.dropLast(3)) – \(to)" : "\(from) – \(to)"
}

struct ClassCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The meeting to show and the class it belongs to (Phase 5a's slot).
    let slot: MeetingSlot<Course>
    /// Minutes since midnight right now, or -1 when the picked day isn't
    /// today, so nothing is marked Now or Done. The web's `nowMin`.
    let nowMin: Int

    /// Open or folded. This is the card's OWN state: every ClassCard in the
    /// list gets a separate `open`, kept for as long as that card stays on
    /// screen. SwiftUI tells the cards apart by the `id` the ForEach in
    /// TodayView gives them, so folding Biology never folds Chemistry.
    /// It starts open, like the web, which explains why: the room is the
    /// reason the app exists, so you shouldn't have to tap to see it.
    @State private var open = true

    var body: some View {
        let course = slot.course
        let meeting = slot.meeting
        // Where this class sits against the clock. `nowMin > 0` keeps both
        // false on any day that isn't today (the web does the same check).
        let isPast = nowMin > 0 && nowMin > meeting.end
        let isNow = nowMin > 0 && nowMin >= meeting.start && nowMin <= meeting.end
        let range = fmtRange(meeting.start, meeting.end)

        VStack(alignment: .leading, spacing: 0) {
            // The top row: color bar, then a button that folds and unfolds.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.subject(course.color))
                    .frame(width: 5)

                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { open.toggle() }
                } label: {
                    header(course, meeting, range, isNow: isNow, isPast: isPast)
                }
                .buttonStyle(.plain)
                .accessibilityValue(open ? "Expanded" : "Collapsed")
            }

            // The details drawer, only while open.
            if open {
                details(course, meeting, range)
            }
        }
        // The card surface. Clipped to the rounded shape so the color bar's
        // corners are rounded too, then the shadow goes on the clipped shape.
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        // A class that's over fades back, the web's opacity .55.
        .opacity(isPast ? 0.55 : 1)
    }

    // MARK: - Pieces

    /// Book, name, "9:00 – 10:15 AM · Room 4", the tag and the chevron.
    private func header(_ course: Course, _ meeting: ClassMeeting, _ range: String,
                        isNow: Bool, isPast: Bool) -> some View {
        // The room only when there is one; an empty room counts as none.
        let room = meeting.room.flatMap { $0.isEmpty ? nil : $0 }

        return HStack(spacing: 12) {
            SubjectBook(color: course.color, short: course.short)

            VStack(alignment: .leading, spacing: 3) {
                Text(course.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(room.map { "\(range) · \($0)" } ?? range)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // One of three tags: on now, over, or still to come (with the
            // time its reminder points at).
            if isNow {
                Text("Now")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.good, in: Capsule())
            } else if isPast {
                Text("Done")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.hint)
            } else if nowMin > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bell")
                        .font(.system(size: 12))
                    Text(fmtTime(meeting.start))
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            }

            // Points right when folded and down when open.
            // `.rotationEffect` turns a view; the animation in the button
            // above makes it swing instead of jump.
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.hint)
                .rotationEffect(.degrees(open ? 90 : 0))
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 16)
        // Makes the whole row tappable, gaps included.
        .contentShape(Rectangle())
    }

    /// Days, time, room, teacher and the class's private note.
    private func details(_ course: Course, _ meeting: ClassMeeting, _ range: String) -> some View {
        // "Mon · Wed · Fri". A day outside 0...6 shows as "?" instead of crashing.
        let days = meeting.days.sorted()
            .map { dayLabels.indices.contains($0) ? dayLabels[$0] : "?" }
            .joined(separator: " · ")
        let room = meeting.room ?? ""
        let teacher = course.instructor ?? ""
        let notes = course.notes ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            detailRow("Days", days)
            detailRow("Time", range)
            // The web skips empty values: `{c.room && ...}`.
            if !room.isEmpty { detailRow("Room", room) }
            if !teacher.isEmpty { detailRow("Teacher", teacher) }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted2)
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The faint line between the row and the drawer.
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    /// One "Label   value" line. `ClassDetail` in app/home/page.tsx.
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted2)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Today/QuoteBanner.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/QuoteBanner.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   components/QuoteBanner.tsx
//
//  Summary: The banner at the top of Today: one motivational line that
//           changes every two hours. The pencil opens an editor where you can
//           write your own list, one per line; an empty list goes back to the
//           built-in rotation. Your list is saved on your profile.
//

import SwiftUI

struct QuoteBanner: View {
    @Environment(Store.self) private var store

    /// The moment to pick a quote for, from Today's ticking clock.
    let now: Date

    /// Showing the editor instead of the quote, and the text being edited.
    @State private var editing = false
    @State private var draft = ""

    /// Whether the editor's text field has the keyboard. `@FocusState` is a
    /// property SwiftUI keeps in step with the keyboard: set it to true and
    /// the field it's attached to (with `.focused`) gets the cursor and the
    /// keyboard comes up; tap elsewhere and SwiftUI sets it back to false.
    /// The web does the same with `autoFocus` on the textarea.
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let quotes = store.profile.quotes
        let accent = store.profile.accent

        // `Group` lets an if/else return two different views under one set
        // of modifiers: the same padding and background for both.
        Group {
            if editing {
                editor(accent)
            } else {
                reader(quotes, accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    // MARK: - Reading

    /// The quote, its small heading and the pencil.
    private func reader(_ quotes: [String], _ accent: Profile.Accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // "Your reminder" once you've written your own.
                Text((quotes.isEmpty ? "A little push" : "Your reminder").uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.faint)
                Text(quoteFor(quotes, now))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    // Wrap onto as many lines as it needs instead of "...".
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openEditor(quotes)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .frame(width: 32, height: 32)
                    .background(Theme.brandSoft(accent), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit my quotes")
        }
    }

    // MARK: - Editing

    /// The list as text, one quote per line, with Cancel and Save.
    private func editor(_ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR QUOTES")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.faint)
                Spacer()
                Text("One per line")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.hint)
            }

            // `axis: .vertical` turns a one-line TextField into one that grows
            // downwards as you type, and Return adds a new line instead of
            // finishing. `lineLimit(5...10)` means: at least 5 lines tall, and
            // scroll inside once it reaches 10.
            TextField("Write a line that keeps you going.\nAdd as many as you like.",
                      text: $draft, axis: .vertical)
                .lineLimit(5...10)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .focused($fieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Your motivational quotes, one per line")
                // Put the cursor in the field as soon as it appears.
                .onAppear { fieldFocused = true }

            Text("Up to \(maxQuotes). Leave it empty to use our rotation. They change every two hours.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    editing = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                Button {
                    save()
                } label: {
                    Text("Save quotes")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    /// Fills the editor with your current list, one per line, and shows it.
    private func openEditor(_ quotes: [String]) {
        draft = quotes.joined(separator: "\n")
        editing = true
    }

    /// Splits the text into lines, cleans them with the ported
    /// `normalizeQuotes`, and saves them to your profile. `setProfile({ quotes })`
    /// on the web. Saving straight away keeps "Saved on this device" honest.
    private func save() {
        store.profile.quotes = normalizeQuotes(draft.components(separatedBy: "\n"))
        store.save()
        editing = false
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift` (replaces the file you just moved)

The week card, the handle and the two `onChange`s are as you typed them in Phase 5. New: the `.newCourse` sheet, the day names, the quote, the day section with its messages, the first-run steps, `showDay` and `daysAhead`, the dynamic title and the wave in the greeting. The old one-line `dayCard` is gone.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/TodayView.swift
//  Phase:   6a (Today: the picked day), after 5a (the week) and 5b (class details)
//           [moved here from Sources/ClassPing/Screens/TodayView.swift]
//  Ports:   app/home/page.tsx (the greeting, the quote, the picked day's
//           classes and every "nothing here" message) and app/week/page.tsx
//           (the week, folded into Today)
//
//  Summary: The Today tab. A greeting, then the week: folded, it's a strip of
//           seven days you can pick from; tap the calendar button (or pull the
//           handle) and it opens into the full timetable. Below it, the quote
//           banner and the picked day's classes, or a message saying why there
//           are none, and a button on to the next day.
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

        // The classes, one card each. ForEach gives every card its slot's id,
        // which is how each ClassCard keeps its own open/folded state.
        if !dayClasses.isEmpty {
            VStack(spacing: 12) {
                ForEach(dayClasses) { slot in
                    ClassCard(slot: slot, nowMin: nowMin)
                }
            }
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

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 6a: Today shows the picked day"
```

On the phone (the sample week: Calculus Mon/Wed/Fri 8:30, ML and Political Theory Mon/Wed, Organic Chemistry and Psychology Tue/Thu):

1. **Today**: "Good morning 👋" (with your name once Phase 11 lets you set one), the week strip, then the quote banner.
2. Tap the **pencil**: the editor opens with the keyboard up. Type two lines, tap **Save quotes**: the heading says "YOUR REMINDER" and one of your lines shows. Open it again, clear everything, save: back to "A LITTLE PUSH".
3. Under the banner, today's classes, open. Tap a card to fold it, tap again to open. If one is on right now it says **Now**; earlier ones fade and say **Done**; later ones show a bell and the start time.
4. Tap Thursday in the strip: the title becomes "Thursday" and its classes show without Now/Done tags. The **View Friday's schedule** row moves you on a day.
5. Tap Saturday: "Looks like you're free!" and a big **View Sunday's schedule**. Tap it, then **View Monday's schedule**: the strip jumps to next week with Monday picked.
6. Close and reopen the app: your quotes are still there.

Two states you can't reach yet: **"Outside your semester"** and **"You're all free this week!"** need term dates, which you can set from Phase 11; **the first-run steps** need zero classes, which you can try in 6b once classes can be deleted.

## 6. Done when

- [ ] `xtool dev build` has no warnings, and `Screens/TodayView.swift` is gone (now `Screens/Today/TodayView.swift`).
- [ ] The quote banner shows a built-in quote; your own list saves, shows "YOUR REMINDER", and survives a relaunch; an empty list goes back to the built-in one.
- [ ] The picked day's classes show as open cards, earliest first; each folds on its own.
- [ ] On today, Now / Done / bell-and-time match the clock.
- [ ] Saturday says "Looks like you're free!", and the buttons walk you into next week with the strip following.
- [ ] The title follows the picked day.

## 7. If it breaks

- **`invalid redeclaration of 'TodayView'`** (or `'TodaySheet'`): the old `Screens/TodayView.swift` is still there, usually because a new file was created instead of moving it. Delete the old one; only `Screens/Today/TodayView.swift` should exist.
- **`type 'Theme' has no member 'brandSoft'`**: `Design/Theme+Today.swift` is missing, or `brandSoft` is spelled differently there.
- **The keyboard doesn't come up in the quote editor:** the `.focused($fieldFocused)` or the `.onAppear { fieldFocused = true }` line is missing from the TextField.
- **Folding one card folds them all:** `open` ended up in TodayView instead of inside `ClassCard`. Each card must own its own `@State`.
- **"View Monday's schedule" picks Monday but the strip stays on this week:** the last line of `showDay` (`weekOffset = ...`) is missing.

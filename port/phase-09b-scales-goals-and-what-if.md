---
title: "Phase 9b: Custom scales, goals and what-if"
date: 2026-10-20
---

# Phase 9b: Custom scales, goals and what-if

Second of three parts of Phase 9 (D-48). This guide builds on your typed 9a,
commit `e79050e`. I diffed that commit against the 9a reference and all seven
source files are identical. In throwaway copies it passed 316/316 logic tests
and 69/69 store tests and built with no warnings, and on 2026-10-20 you
confirmed the 9a phone checks. It also adds the two fixes you asked for after
that check: fields that look like fields, and a keyboard you can put away
(D-54).

**Start here:** type the eight files in section 4, in order. Four are new and
four replace files you already have. Each replaced file is shown in full, and
the list before it tells you which spots changed (they're marked
`// NEW in Phase 9b` or `// CHANGED in Phase 9b` in the code). Then copy the
three test files from 4.9. No test script changes this time.

**Verification (2026-10-20):** the reference iOS build passed with no warnings;
342/342 logic tests and 63/63 reference store tests passed. Your own logic and
store suites plus the three new test files passed 342/342 and 75/75 against
the new source in disposable packages. The eight guide blocks laid over
`e79050e` are identical to the reference, and that tree built with no
warnings. No 9b phone check has happened yet.

## 1. Goal

Set a target grade for each class and see what you need on the work that's
left. Watch the projected GPA for the end of term, and grade with your
school's own scale if it isn't American.

**On your phone:** open **Profile → Grades & GPA**. The fields in **Add grade**
now have a soft Baby Pink (or Ocean) wash, and the keyboard goes away when you
swipe down or tap **Done**. Under each class, tap **A** next to "Aiming for":
"You need 90.0% on the remaining 70% of the grade." A **Projected by end of
term** line shows up in the GPA card. Under **Grading scale**, pick **Custom**,
tap **Set up your scale** and turn the rows into First / 2:1 / 2:2 / Third.
"What this gives" checks your work as you type. Go back, and every letter on
the screen now uses your scale.

This part includes:

- A goal on each current-term class, picked from the top five bands of your
  scale, with the web's "what do I need?" sentence in all six cases: needed,
  out of reach, already locked in, fully graded (goal met or short), over
  100% weight, and no goal yet.
- The projected GPA, credit-weighted, which only appears once a goal is set.
- All three scales (A / A−, A / B / C, Custom) and the custom-scale editor:
  up to 16 bands, saved as you type, with the web's issue messages and its
  five-mark preview.
- Accent-colored typing wells and keyboard dismissal on the grade sheet and
  the scale editor (D-54).

**9c** adds the finals countdown and the CSV report.

## 2. New Swift concepts

### A draft list with stable ids

The scale editor keeps its rows as text in an array of `ScaleDraftRow`
values, and every edit saves only the usable part of them. The draft and the
saved bands are two separate things: a half-typed row stays on screen even
though nothing about it has been saved yet.

```swift
struct ScaleDraftRow: Identifiable, Hashable {
    var id = UUID()          // never changes, so SwiftUI tracks the row itself
    var letter = "", min = "", points = ""
}

ForEach($rows) { $row in TextField("A", text: $row.letter) }   // edits the row in place
    .onChange(of: rows) { _, next in store.setCustomScale(scaleBands(from: next)) }
```

You met `ForEach($array)` in 5b. What's new is the shape: the view owns a
draft, `.onChange(of:)` saves on every edit, and the store keeps only what
`normalizeScale` accepts. The `id` matters when you delete. Remove row 2 and
SwiftUI removes that row's fields, instead of deciding that rows 2 to 16 all
changed and moving your cursor somewhere else.

### `ViewThatFits`

`ViewThatFits` tries its children in order and shows the first one that fits
the space it's given. The goal chips use it to stay on one row when the
letters are short and scroll sideways when a custom scale's long names don't
fit:

```swift
ViewThatFits(in: .horizontal) {
    chipRow                                                     // first choice
    ScrollView(.horizontal, showsIndicators: false) { chipRow }  // fallback
}
```

### A `Text` inside a `Text`

Drop a styled `Text` into another `Text`'s string and it keeps its own bold
and color. That's how one sentence can highlight one number:

```swift
let needed = Text("90.0%").bold().foregroundStyle(accent)
Text("You need \(needed) on the remaining 70% of the grade.")
```

It's the SwiftUI version of the web's `<span className="font-bold">` inside a
`<p>`. (`Text("a") + Text("b")` also works. Interpolation reads more like
the sentence you're building, so this guide uses that.)

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `projectedGpa`, `whatIfNeeded`, `scaleIssues`, `customScaleIsEmpty` and the scale limits in `lib/gpa.ts` | `Logic/GPA.swift`, next to the 9a maths |
| `lib/gpa.test.ts` (the rest of it) | `GPATests.swift`: the projection, what-if, scale-issue, empty-scale and custom-points cases |
| `DraftBand`, `toDraft`, `fromDraft`, `PREVIEW_MARKS` in `components/GradeScaleEditor.tsx` | `Logic/ScaleDraft.swift`, with `ScaleDraftTests.swift` |
| The rest of `components/GradeScaleEditor.tsx` | `Screens/Grades/GradeScaleEditor.swift`, pushed from the Grades scale card |
| The grading card in `app/settings/page.tsx` | The scale card on Grades: three segments, a line about each, Custom's editor link (D-51) |
| `GoalBlock` in `app/grades/page.tsx` | `Screens/Grades/GoalCard.swift` |
| The projected row in `app/grades/page.tsx` | The GPA card in `GradesView.swift` |
| `updateClass(id, { goal })`, `setProfile({ gradeScale })`, `setProfile({ customScale })` | `setGoal`, `setGradeScale` and `setCustomScale` in `Store+Grades.swift` |
| `--bg-input` wells in `app/globals.css` | `Design/Theme+Fields.swift`, in your accent (D-54) |

Where the phone deliberately differs:

- **The scale lives on Grades, not Settings (D-51).** Settings comes to the
  Profile tab in Phase 11. Until then the scale card stays where 9a put it,
  and Phase 11 decides whether it moves.
- **"Start from" asks before replacing rows you've typed (D-52).** On the web
  those buttons swap every row at once with no undo. That's fine for the
  starting rows, but it would wipe out a 13-band IB scale with one mistap. If
  your rows are still the starting ones, or blank, it just replaces them.
- **Scale and goal changes only count once they're on disk (D-53),** like
  9a's grade actions (D-49). If the write fails, the old value comes back and
  the screen says so. If an edit doesn't change the usable bands (say, typing
  into a half-finished row), nothing is written. A goal of 0 or less is
  stored as no goal, which is how the web's maths already reads it, and a
  goal over 100 or one that isn't a number is refused.
- **Goal chips use your accent, not the class color.** The web fills them
  with the class's bar color behind white text. [Likely] Several of those
  pastels miss 4.5 : 1 contrast with white, so the chips use the same brand
  fill as the Tasks filter chips.

Web quirks kept on purpose: a blank number reads as 0, like JavaScript's
`Number("")`. A brand-new empty row counts as starting at 0% until you type
in it, and if another band also starts at 0 the editor warns about two bands
at 0%, exactly as the web does. Letters are cut at six UTF-16 units, as
JavaScript's `slice(0, 6)` counts them.

## 4. Files, in the order to type them

Eight source files: four new (4.1, 4.3, 4.6, 4.7) and four replaced (4.2,
4.4, 4.5, 4.8). Build once all eight are in. `GradesView` uses
`GoalCard` and `GradeScaleEditor`, so it won't compile before them.

### 4.1 `~/ClassPing/Sources/ClassPing/Design/Theme+Fields.swift` (new file)

The style you asked for after 9a, built once so every form can reuse it.
`inputField(_:)` is a view modifier (Phase 3): accent text, an accent caret and
a soft accent wash behind the field. `keyboardDismissable(_:)` bundles two
small keyboard tools. `.scrollDismissesKeyboard(.interactively)` lets a swipe
down the form drag the keyboard away, and a `ToolbarItemGroup(placement:
.keyboard)` puts **Done** on top of the number pad, which has no return key.
Done runs whatever closure you hand it. Here that's always "clear the
`@FocusState`", which tells iOS no field has the keyboard any more.

The text colors aren't `brandDeep`. [Certain] Measured on the wash,
`brandDeep` pink comes out between 3.5 and 4.1 : 1 in light mode and `brand`
pink between 3.5 and 3.8 : 1 in dark, both under the 4.5 : 1 that body text
needs. The shades below reach at least 4.6 : 1 in both modes, for both
accents.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Fields.swift
//  Phase:   9b (asked for after the 9a phone check, D-54)
//  Ports:   the web's input wells (`--bg-input` in app/globals.css), here
//           washed in your accent, Baby Pink or Ocean.
//
//  Summary: One look for anything you type into: a soft accent well with
//           accent text and caret, so a filled-in value like 20% reads as
//           "change me" rather than a label. And a way to put the keyboard
//           away: swipe down the form, or tap Done above the keys.
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
    /// The text you type, in your accent. A shade darker than `brandDeep` in
    /// light mode and the bright end in dark, because those are the ones that
    /// stay readable (4.5 : 1 or better) on the accent well in both modes.
    static func fieldInk(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: shade(UIColor(hex: "#A8305C"), UIColor(hex: "#FF8FB0"))
        case .ocean:    shade(UIColor(hex: "#245E94"), UIColor(hex: "#6BA8E0"))
        }
    }
}

extension View {
    /// The typing well. Put it on a TextField: accent text, an accent caret
    /// (`.tint` colors the caret and the selection) and the soft accent wash
    /// behind it, so the field looks like a field before you touch it.
    func inputField(_ accent: Profile.Accent) -> some View {
        self
            .foregroundStyle(Theme.fieldInk(accent))
            .tint(Theme.brand(accent))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.brandSoft(accent),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Lets the keyboard go, for a form whose buttons sit under it.
    /// `.scrollDismissesKeyboard(.interactively)` lets a swipe down the form
    /// drag the keyboard away with your finger, as in Messages. The number pad
    /// has no return key, so a Done button also rides on top of the keyboard:
    /// a toolbar item placed `.keyboard` appears only while it's up.
    func keyboardDismissable(_ done: @escaping () -> Void) -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: done)
                        .fontWeight(.semibold)
                }
            }
    }
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/GPA.swift` (replaces your 9a file)

Everything you typed in 9a stays. What changes:

- **Header:** now names the 9b ports.
- **`GoalCourse`** (new, after `GradedCourse`): a protocol built on another,
  the way `Completable` builds on `Dated` in 6b.
- **The three limits** (new, after `SIMPLE_SCALE`): `MAX_SCALE_BANDS`,
  `MAX_GRADE_POINTS` and `MAX_LETTER_LENGTH`.
- **`goalOf` and `projectedGpa`** (new, after `overallGpa`).
- **`WhatIfResult` and `whatIfNeeded`** (new, after `extraCreditHint`).
- **`letterPrefix`** (new) and **`normalizeScale`** (changed): the 16, 10 and
  six-letter limits now use the named constants, the UTF-16 cut moved into
  `letterPrefix`, and the doc comment was updated. Same results as before.
- **`scaleIssues`** (new, after `normalizeScale`) and **`customScaleIsEmpty`**
  (new, at the end).

`scaleIssues` counts letters and minimums in arrays of labeled tuples instead
of a `Dictionary`. A dictionary has no order, and the web's messages come out
in the order the rows were typed. A tuple like `(key: String, count: Int)` is
a quick unnamed struct, and `mins[i].count += 1` changes one in place.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Logic/GPA.swift
// Phase: 9a (grades and GPA), extended in 9b (scales, goals and what-if)
// Ports: lib/gpa.ts: averages, bands, credits and weight budgets (9a);
//        the custom-scale limits and checks, projected GPA and
//        "what do I need?" (9b).
// Summary: Foundation-only maths. Protocols let both the real models and
// small Linux test values supply the same fields without importing SwiftUI.
//
import Foundation

/// Only the numbers and relationship the calculation needs.
protocol GradedResult {
    var courseID: UUID? { get }
    var score: Double { get }
    var max: Double { get }
    var weight: Double { get }
}

protocol GradedCourse {
    var id: UUID { get }
    var credits: Double? { get }
}

// NEW in Phase 9b
/// A course that may carry a target percentage. It builds on GradedCourse,
/// the way Completable builds on Dated (6b), so anything with a goal also has
/// the id and credits the GPA needs. 9a's tests keep using GradedCourse alone.
protocol GoalCourse: GradedCourse {
    var goal: Double? { get }
}

/// Moved unchanged from Profile.swift: its saved JSON keys stay identical.
struct ScaleBand: Codable, Hashable, Sendable {
    var min: Double
    var letter: String
    var points: Double
}

let DEFAULT_SCALE: [ScaleBand] = [
    .init(min: 93, letter: "A", points: 4),
    .init(min: 90, letter: "A-", points: 3.7),
    .init(min: 87, letter: "B+", points: 3.3),
    .init(min: 83, letter: "B", points: 3),
    .init(min: 80, letter: "B-", points: 2.7),
    .init(min: 77, letter: "C+", points: 2.3),
    .init(min: 73, letter: "C", points: 2),
    .init(min: 70, letter: "C-", points: 1.7),
    .init(min: 67, letter: "D+", points: 1.3),
    .init(min: 63, letter: "D", points: 1),
    .init(min: 60, letter: "D-", points: 0.7),
]

let SIMPLE_SCALE: [ScaleBand] = [
    .init(min: 90, letter: "A", points: 4),
    .init(min: 80, letter: "B", points: 3),
    .init(min: 70, letter: "C", points: 2),
    .init(min: 60, letter: "D", points: 1),
]

// NEW in Phase 9b
/// A custom scale's limits, named once instead of repeated as bare numbers.
/// `MAX_SCALE_BANDS`, `MAX_GRADE_POINTS` and `MAX_LETTER_LENGTH` in lib/gpa.ts.
/// 10 points fits weighted (5.0) and out-of-10 systems; it catches typos.
let MAX_SCALE_BANDS = 16
let MAX_GRADE_POINTS = 10.0
let MAX_LETTER_LENGTH = 6

/// Empty is unknown, not zero. Weights need not add up to 100.
func classAverage<G: GradedResult>(_ grades: [G]) -> Double? {
    let valid = grades.filter { $0.max > 0 && $0.weight > 0 }
    guard !valid.isEmpty else { return nil }
    let total = valid.reduce(0) { $0 + $1.weight }
    return valid.reduce(0) { $0 + ($1.score / $1.max) * $1.weight } / total * 100
}

/// Highest threshold wins; a supplied zero band can name the fallback.
func letterFor(_ pct: Double, _ scale: [ScaleBand] = DEFAULT_SCALE) -> String {
    scale.sorted { $0.min > $1.min }.first { pct >= $0.min }?.letter ?? "F"
}

func pointsFor(_ pct: Double, _ scale: [ScaleBand] = DEFAULT_SCALE) -> Double {
    scale.sorted { $0.min > $1.min }.first { pct >= $0.min }?.points ?? 0
}

func creditsFor<C: GradedCourse>(_ course: C) -> Double {
    guard let credits = course.credits, credits > 0 else { return 1 }
    return credits
}

/// The caller supplies this term's courses, or one past term's courses.
func overallGpa<C: GradedCourse, G: GradedResult>(
    _ courses: [C], _ grades: [G], _ scale: [ScaleBand] = DEFAULT_SCALE
) -> Double? {
    var totalCredits = 0.0
    var totalPoints = 0.0
    for course in courses {
        if let average = classAverage(grades.filter { $0.courseID == course.id }) {
            let credits = creditsFor(course)
            totalCredits += credits
            totalPoints += pointsFor(average, scale) * credits
        }
    }
    return totalCredits == 0 ? nil : totalPoints / totalCredits
}

// NEW in Phase 9b
/// A course's goal when it counts as one: a number above zero. Missing, zero
/// and negative all mean "no goal", as `typeof c.goal === "number" &&
/// c.goal > 0` does on the web. One helper, so the projection and the Grades
/// screen can't disagree about it.
func goalOf<C: GoalCourse>(_ course: C) -> Double? {
    guard let goal = course.goal, goal > 0 else { return nil }
    return goal
}

// NEW in Phase 9b
/// Where the term ends if every goal is met. `projectedGpa` on the web.
/// A class with a goal counts at that goal, one without at its average so
/// far, so the number answers "where do I land if the plan holds?". Nil until
/// some class has a goal: with none it would only repeat the GPA above it.
func projectedGpa<C: GoalCourse, G: GradedResult>(
    _ courses: [C], _ grades: [G], _ scale: [ScaleBand] = DEFAULT_SCALE
) -> Double? {
    // `contains(where:)` asks "is there any?" with no loop to break out of.
    guard courses.contains(where: { goalOf($0) != nil }) else { return nil }
    var totalCredits = 0.0
    var totalPoints = 0.0
    for course in courses {
        // `??` picks the goal when there is one, otherwise the class average.
        // A class with neither (no goal, nothing graded) is left out.
        if let pct = goalOf(course) ?? classAverage(grades.filter { $0.courseID == course.id }) {
            let credits = creditsFor(course)
            totalCredits += credits
            totalPoints += pointsFor(pct, scale) * credits
        }
    }
    return totalCredits == 0 ? nil : totalPoints / totalCredits
}

func usedWeight<G: GradedResult>(_ grades: [G]) -> Double {
    grades.filter { $0.max > 0 && $0.weight > 0 }.reduce(0) { $0 + $1.weight }
}

func remainingWeight<G: GradedResult>(_ grades: [G]) -> Double {
    Swift.max(100 - usedWeight(grades), 0)
}

/// Extra credit is allowed; the hint catches accidental extra zeroes.
func extraCreditHint(_ score: Double, _ max: Double) -> String? {
    guard score.isFinite, max.isFinite, max > 0, score > max else { return nil }
    return "That's above full marks, logged as extra credit (\(String(format: "%.0f", score / max * 100))%)."
}

// NEW in Phase 9b
/// The answer to "what do I need on the rest?". `WhatIfResult` in lib/gpa.ts.
/// One value with four fields, so the screen gets the number and the two
/// verdicts together and can't work them out differently.
struct WhatIfResult: Equatable {
    /// The average the ungraded work must reach, in percent. Above 100 needs
    /// extra credit; zero or below means the goal is already safe.
    var needed: Double
    /// How much of the class's 100% is still to be graded.
    var remainingWeight: Double
    /// True when even a zero on everything left still reaches the target.
    var alreadySecured: Bool
    /// True when full marks on everything left isn't enough.
    var outOfReach: Bool
}

// NEW in Phase 9b
/// What the remaining work must average for the class to finish at
/// `target` percent. `whatIfNeeded` on the web. Weights are shares of 100:
/// logged grades worth 70 leave 30. Nil when nothing is left (100 used),
/// and also when the weights add up to more than 100, which the Grades
/// screen tells apart with usedWeight.
func whatIfNeeded<G: GradedResult>(_ grades: [G], _ target: Double) -> WhatIfResult? {
    let valid = grades.filter { $0.max > 0 && $0.weight > 0 }
    let left = 100 - valid.reduce(0) { $0 + $1.weight }
    guard left > 0 else { return nil }
    // Points already banked, measured against a 100-weight total.
    let earned = valid.reduce(0) { $0 + ($1.score / $1.max) * $1.weight }
    // Same operation order as the web, so the same inputs give the same bits.
    let needed = (target - earned) / left * 100
    return WhatIfResult(needed: needed, remainingWeight: left,
                        alreadySecured: needed <= 0, outOfReach: needed > 100)
}

// NEW in Phase 9b
/// The first six UTF-16 units of a letter, as JavaScript's `slice(0, 6)`
/// counts them. Shared by normalizeScale and the editor's Grade field.
func letterPrefix(_ text: String) -> String {
    String(decoding: Array(text.utf16.prefix(MAX_LETTER_LENGTH)), as: UTF16.self)
}

/// This typed boundary consumes existing Codable bands. Decoding unknown
/// network data belongs to sync. Since 9b the editor's rows come through here
/// too, after Logic/ScaleDraft.swift turns their text into numbers.
func normalizeScale(_ raw: [ScaleBand]) -> [ScaleBand]? {
    var out: [ScaleBand] = []
    var seen: Set<String> = []
    // CHANGED in Phase 9b: the limits use the named constants.
    for band in raw where out.count < MAX_SCALE_BANDS {
        let trimmed = band.letter.trimmingCharacters(in: .whitespacesAndNewlines)
        let letter = letterPrefix(trimmed)
        let key = letter.lowercased()
        if !letter.isEmpty, !seen.contains(key),
           band.min.isFinite, (0...100).contains(band.min),
           band.points.isFinite, (0...MAX_GRADE_POINTS).contains(band.points) {
            seen.insert(key)
            out.append(ScaleBand(min: (band.min * 10).rounded() / 10,
                                 letter: letter, points: (band.points * 100).rounded() / 100))
        }
    }
    return out.isEmpty ? nil : out.sorted { $0.min > $1.min }
}

// NEW in Phase 9b
/// What's wrong with a scale being edited, in words you can act on, or an
/// empty list when nothing is. `scaleIssues` on the web. It reads the draft,
/// not the normalized result, because its job is to name the rows
/// normalizeScale would quietly drop.
func scaleIssues(_ draft: [ScaleBand]) -> [String] {
    var issues: [String] = []
    // Counts kept in first-seen order, so the messages come out in the web's
    // order. (A JavaScript Map remembers insertion order; a Dictionary doesn't.)
    var letters: [(key: String, count: Int)] = []
    var mins: [(value: Double, count: Int)] = []

    for (index, band) in draft.enumerated() {
        let row = index + 1
        let letter = band.letter.trimmingCharacters(in: .whitespacesAndNewlines)
        if letter.isEmpty { issues.append("Row \(row) has no letter.") }

        // A usable minimum is also counted, to spot two bands at one start.
        if !band.min.isFinite || band.min < 0 || band.min > 100 {
            issues.append("Row \(row): the minimum must be between 0 and 100.")
        } else if let i = mins.firstIndex(where: { $0.value == band.min }) {
            mins[i].count += 1
        } else {
            mins.append((value: band.min, count: 1))
        }

        if !band.points.isFinite || band.points < 0 || band.points > MAX_GRADE_POINTS {
            issues.append("Row \(row): points must be between 0 and \(Int(MAX_GRADE_POINTS)).")
        }

        // Letters compare without case: "A" and "a" are the same grade.
        if !letter.isEmpty {
            let key = letter.lowercased()
            if let i = letters.firstIndex(where: { $0.key == key }) {
                letters[i].count += 1
            } else {
                letters.append((key: key, count: 1))
            }
        }
    }

    // `for ... where` visits only the entries that pass the test.
    for entry in letters where entry.count > 1 {
        issues.append("\"\(entry.key.uppercased())\" appears more than once.")
    }
    for entry in mins where entry.count > 1 {
        issues.append("Two bands both start at \(entry.value.formatted())%, only the first will ever match.")
    }
    if draft.count > MAX_SCALE_BANDS {
        issues.append("A scale can hold at most \(MAX_SCALE_BANDS) bands.")
    }
    return issues
}

/// Read custom bands already saved in a profile without silently replacing them.
func resolveScale(_ name: String?, custom: [ScaleBand] = []) -> [ScaleBand] {
    if name == "custom" { return normalizeScale(custom) ?? DEFAULT_SCALE }
    return name == "simple" ? SIMPLE_SCALE : DEFAULT_SCALE
}

// NEW in Phase 9b
/// True when Custom is chosen but none of its bands are usable yet, so the
/// standard scale is standing in. `customScaleIsEmpty` on the web.
func customScaleIsEmpty(_ name: String?, custom: [ScaleBand]) -> Bool {
    name == "custom" && normalizeScale(custom) == nil
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Logic/ScaleDraft.swift` (new file)

The editor's rows while you type, kept in Logic so the Linux tests can check
the text-to-number rules. `scaleNumber` follows JavaScript's `Number()` for
these fields: blank is 0, and anything unreadable is NaN, so `scaleIssues` can
point at the row. The `locale:` parameters default to the phone's own, so
"3,7" works where a comma is the decimal mark. The tests pass a fixed
locale so they come out the same on every machine.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Logic/ScaleDraft.swift
// Phase: 9b (scales, goals and what-if)
// Ports: components/GradeScaleEditor.tsx (DraftBand, toDraft, fromDraft and
//        PREVIEW_MARKS).
// Summary: The custom-scale editor's rows while you type. Numbers stay text,
//          so a half-typed "8" isn't read as 8 too early, and turning rows
//          back into bands is pure Foundation, so Linux tests can check it.
//
import Foundation

/// One band mid-edit. `DraftBand` in GradeScaleEditor.tsx.
/// `Identifiable` gives each row an id that never changes, so when you
/// remove row 2 SwiftUI removes that row, instead of deciding rows 2 to 16
/// all changed. `Hashable` lets `.onChange(of:)` compare two drafts.
struct ScaleDraftRow: Identifiable, Hashable {
    var id = UUID()
    var letter = ""
    var min = ""
    var points = ""
}

/// The marks "What this gives" runs through the scale. `PREVIEW_MARKS`.
let SCALE_PREVIEW_MARKS: [Double] = [95, 85, 72, 64, 45]

/// Saved bands as editable rows: `toDraft`. The numbers are written the
/// phone's way ("3.7", or "3,7" where a comma is the decimal mark), so the
/// field shows what the decimal keyboard would type.
func scaleDraftRows(from bands: [ScaleBand], locale: Locale = .current) -> [ScaleDraftRow] {
    bands.map { band in
        ScaleDraftRow(letter: band.letter,
                      min: band.min.formatted(.number.locale(locale).grouping(.never)),
                      points: band.points.formatted(.number.locale(locale).grouping(.never)))
    }
}

/// A field's text as a number, the way JavaScript's `Number()` reads it on
/// the web: blank is 0 and unreadable is NaN, which scaleIssues then names.
/// The phone's own decimal mark is accepted as well as a point.
func scaleNumber(_ text: String, locale: Locale = .current) -> Double {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return 0 }
    let mark = locale.decimalSeparator ?? "."
    return Double(value.replacingOccurrences(of: mark, with: ".")) ?? .nan
}

/// Rows back to bands, unchecked: `fromDraft`. Hand the result to
/// scaleIssues to explain it and to normalizeScale to keep what's usable.
func scaleBands(from rows: [ScaleDraftRow], locale: Locale = .current) -> [ScaleBand] {
    rows.map { row in
        ScaleBand(min: scaleNumber(row.min, locale: locale), letter: row.letter,
                  points: scaleNumber(row.points, locale: locale))
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Store+Grades.swift` (replaces your 9a file)

Changed spots:

- **Header** (changed).
- **`extension Course: GoalCourse {}`** (new, one line under the two 9a
  sign-ups). `Course` already has `goal: Double?`.
- **`usesFallbackScale`** (new, under `gradeScale`).
- **Scales and goals** (new, at the end): `setGradeScale`, `setCustomScale`
  and `setGoal`. All three follow 9a's rule: change the value, `save()`, and
  if the write failed, put the old value back and return `false`.

`setCustomScale` skips the write when the usable bands haven't changed. That
happens on most keystrokes in a half-finished row. After a failed write it
always tries again.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Store+Grades.swift
// Phase: 9a, extended in 9b
// Ports: lib/store.tsx (grade actions, and the gradeScale, customScale and
//        goal writes) and app/grades' filtering.
// Summary: Grade CRUD, validation and the bridge to the pure GPA functions.
//          Since 9b also the scale choice, the custom bands and class goals,
//          each saved only once planner.json has it.
//
import Foundation

// These models already have every field the maths asks for.
extension Grade: GradedResult {}
extension Course: GradedCourse {}
// NEW in Phase 9b: Course already has `goal`, so signing up is one line.
extension Course: GoalCourse {}

extension Store {
    var liveGrades: [Grade] { grades.filter { $0.deletedAt == nil } }

    func grade(_ id: UUID) -> Grade? { liveGrades.first { $0.id == id } }

    /// Stable newest-day order: two grades entered on one date keep their order.
    func grades(for courseID: UUID) -> [Grade] {
        liveGrades.filter { $0.courseID == courseID }.sorted { $0.date > $1.date }
    }

    var gradeScale: [ScaleBand] {
        resolveScale(profile.gradeScale?.rawValue, custom: profile.customScale)
    }

    // NEW in Phase 9b
    /// True while Custom is chosen but none of its bands are usable, so the
    /// standard scale is standing in. The Grades screen says so.
    var usesFallbackScale: Bool {
        customScaleIsEmpty(profile.gradeScale?.rawValue, custom: profile.customScale)
    }

    /// Past terms keep their own totals, in order of the courses in the store.
    var gradedPastTerms: [String] {
        var terms: [String] = []
        for course in liveCourses where course.archived && !grades(for: course.id).isEmpty {
            let term = gradeTerm(for: course)
            if !terms.contains(term) { terms.append(term) }
        }
        return terms
    }

    func gradeTerm(for course: Course) -> String {
        let term = course.term?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return term.isEmpty ? "Earlier" : term
    }

    func gradedCourses(in term: String) -> [Course] {
        liveCourses.filter {
            $0.archived && gradeTerm(for: $0) == term && !grades(for: $0.id).isEmpty
        }
    }

    /// Same form bounds as the web. More than full marks is valid. A missing
    /// or deleted class cannot receive a grade, even if a sheet was open.
    func validGrade(_ value: Grade) -> Bool {
        course(value.courseID) != nil &&
        !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        value.score.isFinite && value.score >= 0 &&
        value.max.isFinite && value.max > 0 &&
        value.weight.isFinite && value.weight > 0 && value.weight <= 100 &&
        isValidDate(value.date) && value.deletedAt == nil
    }

    /// Return true only after the file is written. A failure leaves the draft
    /// in the form and rolls back this array, so retry cannot add a duplicate.
    @discardableResult
    func addGrade(_ value: Grade) -> Bool {
        guard validGrade(value), !grades.contains(where: { $0.id == value.id }) else { return false }
        var clean = value
        clean.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let before = grades
        grades.append(clean)
        save()
        if lastSaveFailed { grades = before; return false }
        return true
    }

    @discardableResult
    func updateGrade(_ value: Grade) -> Bool {
        guard validGrade(value),
              let index = grades.firstIndex(where: { $0.id == value.id && $0.deletedAt == nil })
        else { return false }
        let before = grades[index]
        var clean = value
        clean.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        grades[index] = clean
        save()
        if lastSaveFailed { grades[index] = before; return false }
        return true
    }

    /// Soft-delete only; the shared Undo action restores this exact record.
    @discardableResult
    func deleteGrade(_ id: UUID) -> Bool {
        guard let index = grades.firstIndex(where: { $0.id == id && $0.deletedAt == nil })
        else { return false }
        let now = Date.now
        grades[index].deletedAt = now
        save()
        if lastSaveFailed { grades[index].deletedAt = nil; return false }
        let title = grades[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUndo = PendingUndo(item: .grade(id),
                                  label: "\(title.isEmpty ? "Grade" : title) deleted", at: now)
        return true
    }

    // MARK: - Scales and goals (NEW in Phase 9b)

    /// Switch between the standard, simple and custom scales: the web's
    /// `setProfile({ gradeScale })`. Like the grade actions, true only once
    /// planner.json has it; a failed write puts the old choice back.
    @discardableResult
    func setGradeScale(_ next: Profile.GradeScale) -> Bool {
        let before = profile.gradeScale
        profile.gradeScale = next
        save()
        if lastSaveFailed { profile.gradeScale = before; return false }
        return true
    }

    /// Save the usable part of a custom scale, high to low: what the web's
    /// editor saves on every edit (`normalizeScale(...) ?? []`). Nothing
    /// usable saves an empty list, and grading falls back to the standard scale.
    @discardableResult
    func setCustomScale(_ draft: [ScaleBand]) -> Bool {
        let clean = normalizeScale(draft) ?? []
        // Typing into a half-finished row changes nothing usable: skip the
        // write. After a failed write, always try again.
        if clean == profile.customScale && !lastSaveFailed { return true }
        let before = profile.customScale
        profile.customScale = clean
        save()
        if lastSaveFailed { profile.customScale = before; return false }
        return true
    }

    /// Set or clear a class's target percentage: `updateClass(id, { goal })`.
    /// Nil, zero or less clears it, which is how the maths reads them anyway.
    /// A missing or deleted class, or a number that isn't a percentage, is
    /// refused. A failed write keeps the old goal.
    @discardableResult
    func setGoal(_ goal: Double?, for courseID: UUID) -> Bool {
        guard let index = courses.firstIndex(where: { $0.id == courseID && $0.deletedAt == nil })
        else { return false }
        if let goal, !goal.isFinite || goal > 100 { return false }
        let before = courses[index].goal
        // `flatMap` on an optional: keep a positive goal, turn the rest into nil.
        courses[index].goal = goal.flatMap { $0 > 0 ? $0 : nil }
        save()
        if lastSaveFailed { courses[index].goal = before; return false }
        return true
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift` (replaces your 9a file)

Your two requests, on the grade sheet (D-54). Changed spots:

- **Header** (changed).
- **`Field` and `focus`** (new, under `showCourseForm`): `@FocusState` from 6a,
  with a small enum so each field has its own focus value.
- **The Title field** (changed): the accent well, and `.submitLabel(.next)` with
  `.onSubmit` so Return jumps to Score.
- **The three `numberField` calls** (changed): each passes its `field:`.
- **`.keyboardDismissable { focus = nil }`** (new, after `.tint`).
- **`numberField`** (changed): a `Spacer` keeps the label left, and the field
  is at most 120 points wide, wears the well and gets its focus id.

Nothing about saving changes. The Class and Type pickers and the date already
show a chevron or a capsule, so they don't get a well.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradeFormView.swift
// Phase: 9a, changed in 9b (D-54)
// Ports: app/grades/new, app/grades/[id]/edit and components/GradeFields.
// Summary: One sheet for adding and editing. A failed save keeps the draft.
// Since 9b the fields wear your accent, and the keyboard can be swiped away
// or put down with Done, so Save & add another is never stuck under it.
//
import SwiftUI

struct GradeFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let editing: Grade?
    @State private var draftID: UUID
    @State private var courseID: UUID?
    @State private var title: String
    @State private var kind: Grade.Kind?
    @State private var score: String
    @State private var maximum: String
    @State private var weight: String
    @State private var date: Date
    @State private var message: String? = nil
    @State private var addedCount = 0
    @State private var showCourseForm = false

    // NEW in Phase 9b: which field has the keyboard, so Done can put it away
    // and Return on the title can move on to the score. `@FocusState` (6a).
    private enum Field { case title, score, maximum, weight }
    @FocusState private var focus: Field?

    /// State is seeded once per sheet, never overwritten by a store redraw.
    init(editing: Grade? = nil, courseID: UUID? = nil) {
        self.editing = editing
        _draftID = State(initialValue: editing?.id ?? UUID())
        _courseID = State(initialValue: editing?.courseID ?? courseID)
        _title = State(initialValue: editing?.title ?? "")
        _kind = State(initialValue: editing == nil ? .assignment : editing?.kind)
        _score = State(initialValue: editing.map { String($0.score) } ?? "")
        _maximum = State(initialValue: editing.map { String($0.max) } ?? "100")
        _weight = State(initialValue: editing.map { String($0.weight) } ?? "20")
        _date = State(initialValue: editing.flatMap {
            deadlineDayStart(Deadline(date: $0.date, time: nil))
        } ?? .now)
    }

    /// Match Number("") == 0 on the web. Decimal commas follow the device locale.
    private func number(_ text: String) -> Double {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }
        return Double(value.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".",
                                                 with: ".")) ?? .nan
    }

    private var draft: Grade {
        Grade(id: draftID, courseID: courseID, title: title, score: number(score),
              max: number(maximum), weight: number(weight), date: dayOf(date), kind: kind)
    }

    /// Exclude the item being edited, so its weight is not counted twice.
    private var otherGrades: [Grade] {
        store.liveGrades.filter { $0.courseID == courseID && $0.id != editing?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section { Text(message).foregroundStyle(Theme.danger) }
                }
                if addedCount > 0 {
                    Section { Text("\(addedCount) saved on this device.") }
                }
                if store.liveCourses.isEmpty {
                    Section {
                        Text("You need a class before you can log a grade.")
                        Button("Add your first class") { showCourseForm = true }
                    }
                } else {
                    Section("Class") {
                        Picker("Class", selection: $courseID) {
                            Text("Choose a class").tag(nil as UUID?)
                            ForEach(store.liveCourses) { course in
                                Text(course.name).tag(Optional(course.id))
                            }
                        }
                    }
                    Section("What was graded?") {
                        Picker("Type", selection: $kind) {
                            Text("No type").tag(nil as Grade.Kind?)
                            ForEach([Grade.Kind.assignment, .quiz, .exam, .project], id: \.self) {
                                Text($0.rawValue.capitalized).tag(Optional($0))
                            }
                        }
                        // CHANGED in Phase 9b: the accent well, and Return goes to Score.
                        TextField("Title", text: $title)
                            .focused($focus, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focus = .score }
                            .inputField(store.profile.accent)
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                    Section("Result") {
                        numberField("Score", text: $score, field: .score)
                        numberField("Out of", text: $maximum, field: .maximum)
                        if let hint = extraCreditHint(number(score), number(maximum)) {
                            Text(hint).font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                    Section("Weight in this class") {
                        numberField("Weight (%)", text: $weight, field: .weight)
                        budget
                    }
                    if editing == nil {
                        Section {
                            Button("Save & add another") { commit(another: true) }
                                .disabled(!store.validGrade(draft))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .tint(Theme.brand(store.profile.accent))
            // NEW in Phase 9b: swipe down or tap Done to see the buttons again.
            .keyboardDismissable { focus = nil }
            .navigationTitle(editing == nil ? "New Grade" : "Edit Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit(another: false) }
                        .disabled(!store.validGrade(draft))
                }
            }
            .onChange(of: kind) { _, next in
                // The new form's type buttons fill an empty/default title.
                // Editing an existing result never renames it unexpectedly.
                let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasLabel = Grade.Kind.allCases.contains { $0.rawValue.capitalized == clean }
                if editing == nil, let next, clean.isEmpty || wasLabel {
                    title = next.rawValue.capitalized
                }
            }
            .sheet(isPresented: $showCourseForm) { CourseFormView() }
        }
    }

    /// Keep labels visible after typing, including for VoiceOver.
    // CHANGED in Phase 9b: the accent well, at most 120 points wide so it
    // reads as a box for a number, and a focus id for Done.
    private func numberField(_ label: String, text: Binding<String>,
                             field: Field) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focus, equals: field)
                .accessibilityLabel(label)
                .frame(maxWidth: 120)
                .inputField(store.profile.accent)
        }
    }

    /// Warn above 100%, but allow saving: weighted averages still make sense.
    private var budget: some View {
        let used = usedWeight(otherGrades)
        let entered = number(weight)
        let pending = entered.isFinite && entered > 0 ? entered : 0
        let total = used + pending
        let left = remainingWeight(otherGrades)
        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: min(total, 100), total: 100)
                .tint(total > 100 ? Theme.danger : Theme.brand(store.profile.accent))
                .accessibilityLabel("Allocated grade weight")
                .accessibilityValue("\(total.formatted()) percent")
            Text(total > 100
                 ? "This puts the class at \(total.formatted())% of its weight. The average still works, but what do I still need can't be answered past 100%."
                 : "\(used.formatted())% already logged. This takes \(pending.formatted())% more, leaving \((100 - total).formatted())%.")
                .font(.footnote)
                .foregroundStyle(total > 100 ? Theme.danger : Theme.muted)
            if left > 0 && pending != left {
                Button("Use remaining \(left.formatted())%") { weight = String(left) }
            }
        }
    }

    /// Advance only after durable success. A failed attempt keeps its UUID,
    /// values and sheet; a successful next entry gets a fresh UUID.
    private func commit(another: Bool) {
        let saved = editing == nil ? store.addGrade(draft) : store.updateGrade(draft)
        guard saved else {
            message = store.lastSaveFailed
                ? "Couldn't save on this device. Your draft is still here. Tap Save to retry."
                : "This grade or its class is no longer available, or a field is invalid."
            return
        }
        message = nil
        if another {
            addedCount += 1
            let left = remainingWeight(store.liveGrades.filter { $0.courseID == courseID })
            title = ""
            score = ""
            maximum = "100"
            weight = String(left > 0 ? min(20, left) : 20)
            draftID = UUID()
        } else {
            dismiss()
        }
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Grades/GoalCard.swift` (new file)

The web's `GoalBlock`. It reads the goal with `goalOf`, the same helper the
projection uses, so the card and the GPA can't disagree about what counts as
a goal. `message` is a `@ViewBuilder` function, so each `if` branch can return
its own `Text`. It goes through the web's cases in the web's order and
words, including "Nothing graded yet.", which can't really happen once the
weights total exactly 100 but keeps the branches matching the web's.

The pill and the chips are 44 points tall for your finger, even though the
capsule you see is smaller. `.frame(minHeight: 44)` grows the tap area and
`.contentShape(Rectangle())` makes all of it tappable.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GoalCard.swift
// Phase: 9b (scales, goals and what-if)
// Ports: GoalBlock in app/grades/page.tsx.
// Summary: A class's target grade and what it will take to get there. Pick a
//          goal from the top bands of your scale, then read what you need on
//          the work that's left, or why there's nothing left to work out.
//
import SwiftUI

/// Sits in a current-term class's card on the Grades screen, under its
/// average. The goal is saved on the class, not held in this view, because
/// the projected GPA at the top of the screen reads it too.
struct GoalCard: View {
    @Environment(Store.self) private var store
    let course: Course
    /// This class's live grades (its card already has them).
    let grades: [Grade]

    /// True while choosing a new goal over an existing one.
    @State private var picking = false
    /// Set when the last goal couldn't be written to planner.json.
    @State private var failed = false

    var body: some View {
        let goal = goalOf(course)
        let accent = Theme.brand(store.profile.accent)
        VStack(alignment: .leading, spacing: 8) {
            // The label, and the goal as a pill that reopens the chips.
            HStack {
                Text(goal == nil ? "Aiming for" : "Goal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                if let goal, !picking {
                    Button { picking = true } label: {
                        HStack(spacing: 6) {
                            Text("\(letterFor(goal, store.gradeScale)) · \(goal.formatted())%")
                            Image(systemName: "pencil").imageScale(.small)
                        }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accent, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Goal \(letterFor(goal, store.gradeScale)), \(goal.formatted()) percent")
                    .accessibilityHint("Change the goal")
                }
            }

            // Chips stay open until a goal exists; after that, the pill opens them.
            if picking || goal == nil {
                chips(goal)
            }

            message(goal, accent: accent)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if failed {
                Text("Couldn't save the goal on this device. Tap it again to retry.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// The top five bands of your scale as chips, so a goal reads as a real
    /// grade ("A-") rather than a bare number. Tapping the active one clears it.
    private func chips(_ goal: Double?) -> some View {
        let bands = Array(store.gradeScale.sorted { $0.min > $1.min }.prefix(5))
        // `ViewThatFits` shows the first child that fits the width it's offered:
        // one plain row when the letters are short, a row that scrolls sideways
        // when a custom scale's longer names ("First", "Third") don't fit.
        return ViewThatFits(in: .horizontal) {
            chipRow(bands, goal)
            ScrollView(.horizontal, showsIndicators: false) { chipRow(bands, goal) }
        }
    }

    private func chipRow(_ bands: [ScaleBand], _ goal: Double?) -> some View {
        HStack(spacing: 6) {
            // Letters are unique in every scale (normalizeScale sees to it),
            // so the letter can be each chip's id.
            ForEach(bands, id: \.letter) { band in
                let on = goal == band.min
                chip(band.letter, on: on) { choose(on ? nil : band.min) }
                    .accessibilityLabel("\(band.letter), \(band.min.formatted()) percent")
            }
            if goal != nil {
                chip("Clear", on: false) { choose(nil) }
            }
        }
    }

    /// One chip: brand-filled when it's the goal, the card color when not,
    /// like the Tasks filter chips. 44 points tall for the finger.
    private func chip(_ text: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(on ? Color.white : Theme.ink)
                .background(on ? Theme.brand(store.profile.accent) : Theme.card, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Save the new goal (nil clears it), then close the chips. A failed
    /// write leaves them open and says so; the class keeps its old goal.
    private func choose(_ next: Double?) {
        if store.setGoal(next, for: course.id) {
            failed = false
            picking = false
        } else {
            failed = true
        }
    }

    /// The sentence under the goal, in the web's words. `@ViewBuilder` lets
    /// each branch return its own Text. A `Text` dropped into another Text's
    /// string keeps its own bold and color, so one sentence can stress a number.
    @ViewBuilder
    private func message(_ goal: Double?, accent: Color) -> some View {
        let used = usedWeight(grades)
        // Rounded to one place, as the web's Math.round(used * 10) / 10.
        let usedText = Text("\(((used * 10).rounded() / 10).formatted())%")
            .bold()
            .foregroundStyle(Theme.dangerInk)

        if let goal {
            if let result = whatIfNeeded(grades, goal) {
                let left = result.remainingWeight.formatted()
                if result.alreadySecured {
                    Text("Already locked in, even a zero on the remaining \(left)% keeps you there. 🎉")
                } else {
                    let needed = Text("\(result.needed.formatted(.number.precision(.fractionLength(1))))%")
                        .bold()
                        .foregroundStyle(accent)
                    let reach = result.outOfReach
                        ? " That's above full marks, only extra credit gets you there." : ""
                    Text("You need \(needed) on the remaining \(left)% of the grade.\(reach)")
                }
            } else if used > 100 {
                // Over 100: whatIfNeeded has nothing to answer, and saying why
                // beats letting the answer quietly disappear.
                Text("Your logged weights add up to \(usedText), more than the 100% a class has. The average still works, it's scaled to fit, but there's no \u{201C}remaining\u{201D} left to work out what you need. Tap a grade to fix its weight.")
            } else if let average = classAverage(grades) {
                // Exactly 100: fully graded, so report the result.
                let finished = average.formatted(.number.precision(.fractionLength(1)))
                if average >= goal {
                    Text("Everything's graded, you finished at \(finished)%. Goal met. 🎉")
                } else {
                    Text("Everything's graded, you finished at \(finished)%, \((goal - average).formatted(.number.precision(.fractionLength(1)))) points short.")
                }
            } else {
                Text("Nothing graded yet.")
            }
        } else if used > 100 {
            // A data problem, not a goal problem, so it shows without a goal too.
            Text("Heads up: your logged weights add up to \(usedText), more than the 100% a class has. Tap a grade to fix its weight.")
        } else {
            Text("Set a target and we'll work out what you still need, and fold it into your projected GPA.")
        }
    }
}
```

### 4.7 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradeScaleEditor.swift` (new file)

The custom-scale editor, as a `Form` pushed from the Grades scale card. The
rows are a draft (section 2). `commit` trims letters to six characters first.
Changing `rows` runs `.onChange` again, and that second pass is the one that
saves. Two Form gotchas are handled in here, and section 7 has both:

- The bin is `.buttonStyle(.borderless)`. Without it, a Form makes the whole
  row one button, and tapping a field deletes the band.
- Each field's focus value is a `BandField` (row id plus column). If the three
  fields in a row shared the row's id, SwiftUI couldn't tell which one you
  tapped.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradeScaleEditor.swift
// Phase: 9b (scales, goals and what-if)
// Ports: components/GradeScaleEditor.tsx (shown under Custom in the web's
//        Settings grading card; here it opens from the Grades scale card).
// Summary: Build your school's grading scale as rows of grade, from % and
//          points. Every edit saves whatever is usable, the issues list names
//          what isn't, and "What this gives" checks five marks against it.
//
import SwiftUI

struct GradeScaleEditor: View {
    @Environment(Store.self) private var store

    /// The rows as typed. Seeded once from the saved bands (or the standard
    /// scale when there are none, as on the web), then only this screen
    /// changes them. Saving never rewrites them, so a half-typed row stays.
    @State private var rows: [ScaleDraftRow]
    /// Set when the last edit couldn't be written to planner.json.
    @State private var saveFailed = false
    /// The scale a "Start from" button is waiting to put in, once confirmed.
    @State private var replacing: [ScaleBand]? = nil
    /// One field in one row. Each field needs its own focus value: if two
    /// fields shared one, SwiftUI couldn't tell which of them you tapped.
    private struct BandField: Hashable {
        enum Column { case letter, min, points }
        let row: UUID
        let column: Column
    }
    /// Which field has the keyboard, or nil. Done sets it to nil.
    @FocusState private var focused: BandField?

    init(saved: [ScaleBand]) {
        _rows = State(initialValue: scaleDraftRows(from: saved.isEmpty ? DEFAULT_SCALE : saved))
    }

    var body: some View {
        // Worked out fresh on every redraw from the rows as they stand.
        let draft = scaleBands(from: rows)
        let issues = scaleIssues(draft)
        let resolved = normalizeScale(draft)

        Form {
            if saveFailed {
                Section {
                    Text("Couldn't save on this device. Your rows are still here.")
                        .foregroundStyle(Theme.danger)
                    Button("Retry save") { commit(rows) }
                }
            }

            Section {
                // `ForEach($rows)` hands each row over as a binding (`$row`),
                // so a field can write straight into its own row of the array.
                ForEach($rows) { $row in
                    bandRow($row)
                }
            } header: {
                HStack(spacing: 8) {
                    Text("Grade").frame(width: 62)
                    Text("From %").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Points").frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 44, height: 1)
                }
            } footer: {
                Text("A grade is earned at its minimum percentage or above. Anything below every band is an F unless you add one starting at 0.")
            }

            Section {
                Button("Add a grade") { rows.append(ScaleDraftRow()) }
                    .disabled(rows.count >= MAX_SCALE_BANDS)
                Button("Start from A / A\u{2212}") { startFrom(DEFAULT_SCALE) }
                Button("Start from A / B / C") { startFrom(SIMPLE_SCALE) }
            }

            if !issues.isEmpty {
                Section {
                    ForEach(issues, id: \.self) { issue in
                        Text(issue)
                            .font(.footnote)
                            .foregroundStyle(Theme.warnInk)
                    }
                }
            }

            Section {
                if let resolved {
                    preview(resolved)
                } else {
                    Text("No usable bands yet, so grades still use the standard scale. Add at least one row with a grade, a minimum and its points.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            } header: {
                Text("What this gives")
            } footer: {
                Text("Points are what your GPA is averaged from, \(Int(MAX_GRADE_POINTS)) is the highest allowed, so weighted and out-of-10 systems both fit.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .tint(Theme.brand(store.profile.accent))
        // Swipe down or tap Done to reach the buttons under the rows.
        .keyboardDismissable { focused = nil }
        .navigationTitle("Custom scale")
        .navigationBarTitleDisplayMode(.inline)
        // Every edit saves, as on the web: no Save button, because a scale
        // that only applies after you find a button is one you'd think was set.
        .onChange(of: rows) { _, next in commit(next) }
        .confirmationDialog("Replace your bands?", isPresented: Binding(
            get: { replacing != nil }, set: { if !$0 { replacing = nil } }
        ), titleVisibility: .visible) {
            Button("Replace", role: .destructive) {
                if let replacing { rows = scaleDraftRows(from: replacing) }
                replacing = nil
            }
            Button("Cancel", role: .cancel) { replacing = nil }
        } message: {
            Text("Every row you've typed is swapped for this scale. There's no undo.")
        }
    }

    /// One band: grade, from %, points and a bin. The bin is `.borderless`
    /// because in a Form a plain button takes over the whole row's taps,
    /// and tapping a field would delete the band.
    private func bandRow(_ row: Binding<ScaleDraftRow>) -> some View {
        let accent = store.profile.accent
        let id = row.wrappedValue.id
        return HStack(spacing: 8) {
            TextField("A", text: row.letter)
                .multilineTextAlignment(.center)
                .fontWeight(.semibold)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused, equals: BandField(row: id, column: .letter))
                .accessibilityLabel("Grade")
                .inputField(accent)
                .frame(width: 62)
            TextField("93", text: row.min)
                .keyboardType(.decimalPad)
                .focused($focused, equals: BandField(row: id, column: .min))
                .accessibilityLabel("Minimum percentage")
                .inputField(accent)
            TextField("4.0", text: row.points)
                .keyboardType(.decimalPad)
                .focused($focused, equals: BandField(row: id, column: .points))
                .accessibilityLabel("Grade points")
                .inputField(accent)
            Button(role: .destructive) {
                rows.removeAll { $0.id == id }
            } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(row.wrappedValue.letter.isEmpty ? "this band" : row.wrappedValue.letter)")
        }
    }

    /// "What this gives": five marks run through the scale as it stands, so
    /// you can check your work without leaving the screen.
    private func preview(_ scale: [ScaleBand]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)],
                  alignment: .leading, spacing: 6) {
            ForEach(SCALE_PREVIEW_MARKS, id: \.self) { mark in
                // The letter is its own Text, so it alone is bold.
                Text("\(mark.formatted())% = \(Text(letterFor(mark, scale)).bold())")
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// Typed rows go straight in. Rows you've changed get a check first,
    /// since the buttons replace every row and the web has no undo for that.
    private func startFrom(_ bands: [ScaleBand]) {
        if scaleBands(from: rows) == bands || rows.allSatisfy({ $0.letter.isEmpty }) {
            rows = scaleDraftRows(from: bands)
        } else {
            replacing = bands
        }
    }

    /// Save what's usable. Letters past six characters are trimmed first:
    /// changing `rows` runs `.onChange` again, and that pass saves.
    private func commit(_ next: [ScaleDraftRow]) {
        let clipped = next.map { row in
            var copy = row
            copy.letter = letterPrefix(row.letter)
            return copy
        }
        if clipped != next {
            rows = clipped
            return
        }
        saveFailed = !store.setCustomScale(scaleBands(from: next))
    }
}
```

### 4.8 `~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift` (replaces your 9a file)

Changed spots:

- **Header** (changed).
- **The projected row** (new, at the bottom of `overview`): only there while
  `projectedGpa` isn't nil.
- **`scalePicker`** (replaced whole): a segmented `Picker` with the web's three
  labels, a line about each scale, and for Custom, a `NavigationLink` to the
  editor. The setter now calls `store.setGradeScale`, which does 9a's rollback
  for you.
- **`GoalCard`** (new, in `courseCard` under the header): only for this
  term's classes (`canAdd`). Past terms keep their read-only cards.

```swift
//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GradesView.swift
// Phase: 9a, extended in 9b
// Ports: app/grades/page.tsx, reached from Profile (D-19), and the grading
//        card of app/settings/page.tsx (D-51).
// Summary: This term's credit-weighted GPA, results and separate past terms.
// 9b adds the projected GPA, a goal on each class, and the three scales with
// the custom editor. Exports and the finals countdown come in 9c.
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
                scalePicker
                if store.activeCourses.isEmpty {
                    Text("No classes in this term yet. Add a class to start logging grades.")
                        .foregroundStyle(Theme.muted)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
                ForEach(store.activeCourses) { course in courseCard(course, canAdd: true) }
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
            Text(gpa.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—")
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
                    Text(projected.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.brandDeep(store.profile.accent))
                }
                .padding(12)
                .background(Theme.brandSoft(store.profile.accent),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                // One VoiceOver stop: "Projected by end of term, 3.50".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Projected by end of term if you hit every goal, \(projected.formatted(.number.precision(.fractionLength(2))))")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // CHANGED in Phase 9b: all three scales, as the web's grading card has
    // them, with Custom opening its editor (D-51). The choice goes through
    // the store, which puts the old one back if the write fails.
    private var scalePicker: some View {
        let selected = store.profile.gradeScale ?? .standard
        return VStack(alignment: .leading, spacing: 10) {
            Text("GRADING SCALE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
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
        .cardStyle()
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
                    Text(average.map { "\($0.formatted(.number.precision(.fractionLength(1))))% average" }
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
                Text("\(gpa.formatted(.number.precision(.fractionLength(2)))) GPA")
                    .font(.subheadline)
            }
            ForEach(courses) { course in courseCard(course, canAdd: false) }
        }
    }
}
```

### 4.9 Tests (copy these, don't type them)

```bash
cd ~/ClassPing
REF=/mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests
cp $REF/Logic/GPATests.swift Tests/Logic/           # replaces 9a's: +21 tests
cp $REF/Logic/ScaleDraftTests.swift Tests/Logic/    # new: 5 tests
cp $REF/Persistence/GradeStoreTests.swift Tests/Store/   # replaces 9a's: +6 tests
```

Your scripts don't need changes: `test-logic.sh` copies every `Logic/*.swift`
file (so `ScaleDraft.swift` comes along), and `test-store.sh` already lists
`Store+Grades`.

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 342 tests passing
scripts/test-store.sh     # expect 75 tests passing
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself. Use a
throwaway class for steps 2 to 4 so the numbers come out exactly as written.

1. **Fields and keyboard:** Profile → Grades & GPA → Add grade. Title, Score,
   Out of and Weight each sit in a soft accent well, and the 20 in Weight
   looks like something to change. Type a title and tap Return: the cursor
   moves to Score. With the number pad up, swipe down on the form and the
   keyboard follows your finger away. Tap a field again and then tap
   **Done**. **Save & add another** is reachable both ways.
2. **What do I need:** log 100/100 at weight 30. Under the class, "Aiming
   for" shows chips A, A-, B+, B, B-. Tap **A**: the pill reads "A · 93%"
   and the line says "You need 90.0% on the remaining 70% of the grade." A
   **Projected by end of term** row appears in the GPA card.
3. **The other answers**, editing that one result each time:
   - 20/100 at weight 90, goal A: "You need 750.0% … That's above full
     marks, only extra credit gets you there."
   - 100/100 at weight 80, goal B-: "Already locked in, even a zero on the
     remaining 20% keeps you there. 🎉"
   - then add 50/100 at weight 20: "Everything's graded, you finished at
     90.0%. Goal met. 🎉"
   - then add one more at weight 20: "Your logged weights add up to 120%,
     more than the 100% a class has. …"
4. **Clear and relaunch:** tap the pill, then the active chip (or Clear). The
   goal goes, and so does the projected row if no other class has one. Set a
   goal again, close the app fully and reopen: the goal is still there.
5. **Built-in scales:** under Grading scale tap **A / B / C**: a 90% result
   is now an A. Tap **A / A−** to go back.
6. **Your own scale:** tap **Custom**. The card says "Your custom scale is
   empty. Using US 4.0 for now." Tap **Set up your scale**. The rows start
   as the standard scale, and What this gives reads 95% = A, 85% = B,
   72% = C-, 64% = D, 45% = F.
7. **Build a UK scale:** tap **Start from A / B / C** (no question asked,
   because you haven't typed anything). Change the rows to First 70 4,
   2:1 60 3, 2:2 50 2, Third 40 1. While you type, warnings like "Two bands
   both start at 70%" can flash up and then go away. Done, the preview reads
   95% = First, 85% = First, 72% = First, 64% = 2:1, 45% = Third.
8. **Issues:** empty a letter ("Row 2 has no letter."), type 11 as points
   ("points must be between 0 and 10."), type `first` in another row
   ("FIRST" appears more than once). Undo each by typing it back.
9. **Start from asks now:** tap **Start from A / A−**. "Replace your bands?"
   appears. Tap Cancel and your rows stay.
10. **Back on Grades:** letters read First / 2:1 / …, and the GPA uses your
    points. Relaunch: still Custom, still your bands.
11. **Empty scale:** in the editor, remove every row with its bin. The preview
    says "No usable bands yet…", and back on Grades the card says it's
    using US 4.0. Rebuild your scale or switch back afterwards.
12. **Presentation:** check Baby Pink and Ocean, light and dark (the field
    text must stay easy to read). Try larger text, where the goal chips should
    scroll sideways rather than squash. With VoiceOver, a chip reads like "A,
    93 percent" and the goal chip is announced as selected. Tapping a field
    in the scale editor must never delete its row.

Save-failure injection is covered by the disposable tests, not by damaging
your real planner. After these checks, commit with your usual workflow.
Nothing was committed or installed by the agent.

## 6. Done when

- [ ] The tree builds without warnings; 342 logic and 75 store tests pass.
- [ ] Grade fields wear the accent; swipe-down and Done put the keyboard away.
- [ ] Goals give the right sentence in each case in step 3 and survive a relaunch.
- [ ] The projected GPA appears only with a goal and matches your goals.
- [ ] All three scales work, and a custom scale is saved as you type and
      survives a relaunch.
- [ ] The editor's issues and preview match steps 7 and 8; Start from asks
      before replacing typed rows.
- [ ] Light, dark, both accents and larger text are all readable.

Reference verification is not a phone pass. Confirm this checklist before 9c.

## 7. If it breaks

- **Cannot find type 'GoalCourse' / 'Course' does not conform to 'GoalCourse':**
  4.2 adds the protocol, and 4.4 needs its one-line
  `extension Course: GoalCourse {}`.
- **Cannot find 'inputField' or 'keyboardDismissable':** 4.1 goes in
  `Sources/ClassPing/Design/`, next to the other Theme files.
- **Tapping a field in the scale editor deletes the row:** the bin is missing
  `.buttonStyle(.borderless)`.
- **Tapping From % puts the cursor in Grade instead:** two fields share a focus
  value. Each one needs its own `BandField(row:column:)`.
- **No Done button over the number pad:** `.keyboardDismissable` has to sit on
  the `Form`, inside the `NavigationStack`. A keyboard toolbar outside it
  never shows.
- **Rows jump or your typing vanishes in the editor:** something writes the
  saved bands back into `rows`. Only `init` seeds the rows. After that, only
  `commit` and the buttons change them.
- **The goal chips never close:** the goal didn't save (the red line under the
  card says so). Free some storage and tap the chip again.

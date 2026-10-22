---
title: "Phase 8c: The formatting bar and tidy"
date: 2026-10-18
generated_by: skills-for-architects
---

# Phase 8c: The formatting bar and tidy

*Third of four parts of Phase 8 (D-36, split again by D-40). Checked on 2026-10-18 over your tree as it stood that evening (8a and 8b typed, with your own hardening, D-42): `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 283/283 (45 new, in `NoteFormatTests` and `NoteTidyTests`), and `persistence-test.sh` 32/32. Nothing here has been on a phone yet.*

*Since typed (D-44): your tree goes further than this doc in `Store+Notes.swift` (`saveNoteBody`), `NoteView.swift` (Apply and Undo tidy use it), `NoteTidy.swift` (a lighter `lineDiff`), `NoteTidySheet.swift` and `NoteFormatBar.swift` (the pens scroll). The reference holds your version, and 8d builds on it.*

**Before you start:** 8a and 8b built and committed, with one fix first: in your `Logic/NoteMarkdown.swift`, the link's `return` is still from before D-39: take `escapeHtml( )` off `href`, in both places it wraps it, as in 8b's doc, and copy `NoteMarkdownTests.swift` again for the test that checks it. This phase adds buttons to 8a's editor and a Tidy button to 8b's reader.

## 1. Goal

Formatting a note no longer means typing `**` and `- [ ] ` with your thumbs: a bar sits on top of the keyboard with a button for each. And **Tidy note** turns a messy lecture into headings and lists, after showing you exactly what it would change.

**On your phone:** open a note and tap **Edit**. Above the keyboard is a row of buttons that scrolls sideways: **Aa** (Heading 1, 2, 3, Body text), **B**, *I*, U, the highlighter and an eraser (Highlight and Clear, D-38), a palette (the five pens), bullets, numbers, a checklist, a quote, `</>` for inline code and `{ }` for a code block. Select some words (double-tap one, or drag the handles), tap **B**: the words get `**` around them, still selected; tap **B** again and they're gone. Tap **Done**: the note drawn, with your formatting. Above a note you're reading, **Tidy note** opens a preview: what it did, the original and the suggestion, and every changed line; **Apply** writes it, **Undo tidy** puts it back.

## 2. New Swift concepts

**`TextEditor(text:selection:)` and `TextSelection`.** Since 8a the editor has handed you its text through `$text`. Given a `selection` binding too, it also tells you what's selected (or where the caret is) as you move it, and moves it when you set the binding. A `TextSelection` holds positions in the string (`String.Index`, as in Phase 2); the formatting code counts UTF-16 units from the start instead, so `utf16Offset(in:)` turns a position into a number and `String.Index(utf16Offset:in:)` turns it back:

```swift
@State private var text = "a cell wall"
@State private var selection: TextSelection? = nil

TextEditor(text: $text, selection: $selection)

// What's selected, as counts from the start. `indices` is an enum, and
// `if case` both checks which case it is and pulls out what it carries.
if let selection, case .selection(let range) = selection.indices {
    let from = range.lowerBound.utf16Offset(in: text)   // 2
    let to = range.upperBound.utf16Offset(in: text)     // 6, so "cell"
}

// And back: select "cell" from code.
let lo = String.Index(utf16Offset: 2, in: text)
let hi = String.Index(utf16Offset: 6, in: text)
selection = TextSelection(range: lo..<hi)
```

Why UTF-16: it's what the web's `selectionStart` counts and what `noteLength` counts (8a), and `NSString`, which NoteFormat works on, counts the same way. An emoji is one `Character` but two units, and counting the same way everywhere is what keeps the selection on the right letters.

**`Menu`.** A button that opens a short list of buttons. The **Aa** button is one:

```swift
Menu {
    Button("Heading 1") { apply { setLineStyle(.heading1, in: $0) } }
    Button("Body text") { apply { setLineStyle(.body, in: $0) } }
} label: {
    Image(systemName: "textformat.size")
}
```

**`DisclosureGroup`.** A heading you tap to show or hide what's under it, with the arrow drawn for you: the web's `<details>`. The tidy preview's "See exactly what changed" is one:

```swift
DisclosureGroup("See exactly what changed") {
    Text("− Cells")
    Text("+ # Cells")
}
```

You'll also meet: **`mutating`**, which a struct's function needs before it may change the struct's own `var`s (`Rewrite.copy` in 4.1). **`inout` and `&`**: `tidyPlain(plain, &flags)` hands the function the caller's `flags` itself rather than a copy, so the counts it adds survive the call; the web passes an object, which JavaScript shares rather than copies. **`@escaping`** on a closure parameter that's kept for later (each bar button keeps its change until it's tapped). **`switch` as a value**, `let sign = switch line.kind { … }`, the same switch handing back one value per case. **`Label`**, an icon and words together ("✨ Tidy note"). And an optional tuple as `@State`, `(original: String, applied: String)?`: two values that come and go together, without a struct for them.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `Toolbar` in `components/NoteEditor.tsx` | `Screens/Notes/NoteFormatBar.swift` | The web's buttons change rich text (`execCommand`); the phone types markdown, so its buttons change the text, writing the markers the web's editor saves. Not on the phone's bar: tables, columns, links and emoji (D-41). Tables, columns and links are typed and the reader draws them; the keyboard has emoji |
| Heading 1 to 3, Body text, the lists, Quote | `setLineStyle` in `Logic/NoteFormat.swift` | Each line the selection touches gets the new start in place of its old one; on lines that are all that style already, the same button ends it. Numbers count from 1 and start again after a blank line, which is how the web saves a list and how the reader numbers it |
| Bold, Italic, Underline, Inline code | `toggleMark` | Each end of the selected words flips on its own, a marker there comes out and one goes in where there's none (D-41), and each line is done separately, since the reader reads markers one line at a time. Nothing selected types an empty pair to type into |
| The highlight menu (four swatches and ×) | `highlight`, `clearHighlight` | One yellow and a Clear (D-38). Highlight only adds; Clear takes off every highlight the selection touches, a caret inside one being enough |
| Text colour (five pens and No colour) | `paint`, and the pens' row on the bar | The same five pens. Words in a pen change colour; a caret inside a pen is enough |
| Code block | `insertCodeBlock` | Fences the lines you're on, or puts in an empty block |
| `components/NoteTidyButton.tsx` | `tidyRow` in `NoteView.swift`, `Screens/Notes/NoteTidySheet.swift` | The same preview, Apply and Undo tidy, with the two panels one above the other. On the reader only (D-41). No "this note changed" check: nothing can change the note while the sheet is up until sync (Phase 14). No "too long to tidy": a phone note never goes past the limit |
| `lib/tidy-note.ts` | `tidyNote` in `Logic/NoteTidy.swift` | Same rules and same answers, checked against the web for thirteen notes |
| `lib/line-diff.ts` | `lineDiff` | Same, down to which side wins a tie |

## 4. Files, in the order to type them

4.1 and 4.2 build on their own; 4.3 needs 4.1; 4.4 needs 4.2; 4.5 needs 4.3 and 4.4. Four new files, one replaced.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/NoteFormat.swift` (new file)

Pure logic: what every button on the bar does to the text. Three kinds of change, words (`toggleMark`, `highlight`, `clearHighlight`, `paint`), lines (`setLineStyle`, `insertCodeBlock`), and the helpers they share at the bottom. Type the helpers too; nothing above them builds without them. The tests run every button against the reader (`parseBlocks`, `noteRuns`), so what the bar writes is what gets drawn.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/NoteFormat.swift
//  Phase:   8c (the formatting bar and tidy)
//  Ports:   what the toolbar in components/NoteEditor.tsx does, for a phone
//           that types markdown. The web's buttons change a page of rich
//           text (`execCommand`); these change the note's own text, writing
//           the markers the web's editor saves (`htmlToMd` in lib/notes.ts),
//           so a note reads the same whichever app formatted it
//
//  Summary: What each button on the formatting bar does to the text. Words
//           get wrapped in `**` or `==` or a pen, lines get started with
//           `## ` or `- [ ] `. Each change takes the text and what's
//           selected, and gives back the new text and what to select, so a
//           second tap undoes the first and the tests can check every one
//           without a phone.
//

import Foundation

/// The note being typed: its text, and what's selected in it.
///
/// The selection counts UTF-16 units from the start, the way `noteLength`
/// counts and the web's `selectionStart` does. An empty range is just the
/// caret. `NSString` counts the same way, which is why this file works on
/// `text as NSString` instead of on `String` (where an emoji is one
/// `Character` but two units).
struct NoteEdit: Equatable {
    var text: String
    var selection: Range<Int>
}

// MARK: - Bold, italic, underline, highlight, code

/// The markers that wrap words, each the one the reader looks for
/// (`inlineToHtml`).
enum NoteMark: String {
    case bold = "**"
    case italic = "*"
    case underline = "__"
    case highlight = "=="
    case code = "`"

    /// The marker's character as one UTF-16 unit, for counting a run of them.
    var unit: UInt16 { rawValue.utf16.first ?? 0 }

    /// Whether a run of this many marker characters in a row has this mark
    /// in it. Bold and italic share the star: `**` is bold, `*` italic and
    /// `***` both. So italic is in an odd run, bold in a run of two or more.
    /// The others just need their whole marker.
    func isIn(_ run: Int) -> Bool {
        self == .italic ? run % 2 == 1 : run >= rawValue.utf16.count
    }
}

/// Bold (or italic, or …) flipped on the selected words. Each end of the
/// words flips on its own: a marker there comes out, and where there's
/// none, one goes in. So plain words get wrapped, `**words**` lose their
/// stars, and the end word of a bold stretch comes out of it. Each line's
/// words are done separately, because the reader looks for markers one line
/// at a time. With only a caret, an empty pair goes in with the caret
/// between, ready to type into; tapped again there, the pair goes.
func toggleMark(_ mark: NoteMark, in edit: NoteEdit) -> NoteEdit {
    let ns = edit.text as NSString
    let sel = clamp(edit.selection, ns.length)
    let m = mark.rawValue
    let k = m.utf16.count
    let u = mark.unit

    let parts = sel.isEmpty ? [sel] : stretches(ns, sel)
    guard !parts.isEmpty else { return edit }
    var out = Rewrite(ns)
    for part in parts {
        // The words: the stretch without any marker characters at its ends.
        let lo = part.lowerBound + run(ns, u, from: part.lowerBound, to: part.upperBound)
        let hi = part.upperBound - runBack(ns, u, from: part.upperBound, to: lo)
        guard lo < hi || part.isEmpty else { continue }
        // Whether each end has the mark already: the run of marker
        // characters there, inside the stretch and out, has it in it.
        let left = mark.isIn(runBack(ns, u, from: lo))
        let right = mark.isIn(run(ns, u, from: hi, to: ns.length))

        out.copy(to: left ? lo - k : lo)
        if left { out.skip(to: lo) } else { out.add(m) }
        out.selectFromHere()
        out.copy(to: hi)
        out.selectToHere()
        if right { out.skip(to: hi + k) } else { out.add(m) }
    }
    return out.finish()
}

/// D-38's Highlight: the selected words wrapped in `==`. It only ever adds:
/// words already in a highlight are left alone (wrapping inside one would
/// split it in two), and Clear is what takes a highlight off.
func highlight(in edit: NoteEdit) -> NoteEdit {
    guard touchedSpans(highlightSpan, in: edit).isEmpty else { return edit }
    return toggleMark(.highlight, in: edit)
}

/// D-38's Clear: every highlight the selection touches loses its `==`, the
/// whole of each one, so a caret anywhere in a highlight is enough. The
/// words it cleared end up selected.
func clearHighlight(in edit: NoteEdit) -> NoteEdit {
    rewriteSpans(highlightSpan, in: edit) { g in g[1] } ?? edit
}

/// `==words==`, the way the reader finds a highlight, one line at a time.
private let highlightSpan = #"==([^=\n]+)=="#

// MARK: - The pens

/// `[[red|words]]`, the way the reader finds a pen, one line at a time.
private let penSpan = #"\[\[("# + notePens.joined(separator: "|") + #")\|([^\n]*?)\]\]"#

/// The selected words in a pen, or out of every pen when `pen` is nil.
/// Words in a pen already change to the new one (a caret in them is
/// enough); anything else gets wrapped, each line's words separately.
func paint(_ pen: String?, in edit: NoteEdit) -> NoteEdit {
    // Pens the selection touches: change them, or take them off.
    let changed = rewriteSpans(penSpan, in: edit) { g in
        if let pen { return "[[\(pen)|\(g[2])]]" }
        return g[2]
    }
    if let changed { return changed }
    guard let pen else { return edit }

    let ns = edit.text as NSString
    let sel = clamp(edit.selection, ns.length)
    let parts = sel.isEmpty ? [sel] : stretches(ns, sel)
    guard !parts.isEmpty else { return edit }
    var out = Rewrite(ns)
    for part in parts {
        out.copy(to: part.lowerBound)
        out.add("[[\(pen)|")
        out.selectFromHere()
        out.copy(to: part.upperBound)
        out.selectToHere()
        out.add("]]")
    }
    return out.finish()
}

// MARK: - Headings, lists and quotes

/// What a line is, by how it starts. Body text is a line with no start.
enum NoteLineStyle {
    case body, heading1, heading2, heading3, bullet, numbered, checkbox, quote
}

/// How a line starts, and how long that start is in UTF-16 units: `## ` is a
/// heading 2, three long. The same patterns `parseBlocks` reads, the
/// checkbox before the bullet because `- [ ] ` starts like a bullet too.
func linePrefix(_ line: String) -> (style: NoteLineStyle, length: Int) {
    let starts: [(String, NoteLineStyle)] = [
        (#"^#\s+"#, .heading1),
        (#"^##\s+"#, .heading2),
        (#"^###\s+"#, .heading3),
        (#"^[-*]\s+\[[ xX]\]\s*"#, .checkbox),
        (#"^[-*]\s+"#, .bullet),
        (#"^\d+\.\s+"#, .numbered),
        (#"^>\s?"#, .quote),
    ]
    for (pattern, style) in starts {
        if let found = line.range(of: pattern, options: .regularExpression) {
            return (style, line[found].utf16.count)
        }
    }
    return (.body, 0)
}

/// The start each style writes. Numbered lines count up from 1, the way the
/// web's editor saves a list.
private func prefix(_ style: NoteLineStyle, number: Int) -> String {
    switch style {
    case .body: ""
    case .heading1: "# "
    case .heading2: "## "
    case .heading3: "### "
    case .bullet: "- "
    case .numbered: "\(number). "
    case .checkbox: "- [ ] "
    case .quote: "> "
    }
}

/// Every line the selection touches made a heading, a list item, a quote or
/// body text: its old start swapped for the new one. On lines that all have
/// that style already it takes them back to body text, so a second tap on
/// Bullet ends the list. A line that's the style already keeps its own
/// start, so a ticked box stays ticked.
func setLineStyle(_ style: NoteLineStyle, in edit: NoteEdit) -> NoteEdit {
    let ns = edit.text as NSString
    let sel = clamp(edit.selection, ns.length)
    let block = wholeLines(ns, sel)
    let lines = ns.substring(with: NSRange(block)).components(separatedBy: "\n")
    let starts = lines.map(linePrefix)

    // Blank lines stay blank, unless that's all there is (a caret on an
    // empty line, about to start a list).
    let filled = lines.indices.filter { !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty }
    let chosen = filled.isEmpty ? Array(lines.indices) : filled
    let wanted: NoteLineStyle = chosen.allSatisfy { starts[$0].style == style } ? .body : style

    var out: [String] = []
    var cut: [Int] = []   // per line: how long the start that came off was
    var put: [Int] = []   // and how long the start that went on is
    var number = 0
    for (i, line) in lines.enumerated() {
        let old = chosen.contains(i) ? starts[i].length : 0
        var new = (line as NSString).substring(to: old)
        if chosen.contains(i) {
            number += 1
            if starts[i].style != wanted { new = prefix(wanted, number: number) }
        } else {
            // A blank line ends a numbered list in the reader, so the
            // count starts again after one.
            number = 0
        }
        out.append(new + (line as NSString).substring(from: old))
        cut.append(old)
        put.append(new.utf16.count)
    }

    // Where a place in the old lines lands: inside a line's old start, just
    // after its new one; after it, moved by the difference.
    func moved(_ place: Int) -> Int {
        var start = block.lowerBound
        var shift = 0
        for (i, line) in lines.enumerated() {
            let length = line.utf16.count
            if place <= start + length {
                let into = place - start
                return start + shift + (into < cut[i] ? put[i] : into - cut[i] + put[i])
            }
            start += length + 1
            shift += put[i] - cut[i]
        }
        return place + shift
    }

    let text = ns.replacingCharacters(in: NSRange(block), with: out.joined(separator: "\n"))
    return NoteEdit(text: text, selection: moved(sel.lowerBound)..<moved(sel.upperBound))
}

// MARK: - Code blocks

/// The lines the selection touches fenced as a code block, and selected. On
/// an empty line it puts in an empty block with the caret inside.
func insertCodeBlock(in edit: NoteEdit) -> NoteEdit {
    let ns = edit.text as NSString
    let sel = clamp(edit.selection, ns.length)
    let block = wholeLines(ns, sel)
    let lines = ns.substring(with: NSRange(block))
    let fence = "```"
    if lines.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let text = ns.replacingCharacters(in: NSRange(block), with: fence + "\n\n" + fence)
        let caret = block.lowerBound + 4
        return NoteEdit(text: text, selection: caret..<caret)
    }
    let text = ns.replacingCharacters(in: NSRange(block), with: fence + "\n" + lines + "\n" + fence)
    let start = block.lowerBound + 4
    return NoteEdit(text: text, selection: start..<(start + block.count))
}

// MARK: - Helpers

/// A new text built from an old one, a piece at a time, keeping track of
/// what to select in it. `copy` brings the old text across up to a place,
/// `skip` jumps over some of it (so it's left out), `add` puts new text in.
/// `mutating` marks the functions that change the struct's own variables.
private struct Rewrite {
    let old: NSString
    private var text = ""
    private var at = 0             // how far through `old` it has got
    private var start: Int? = nil  // the new selection's start, once known
    private var end = 0

    init(_ old: NSString) {
        self.old = old
    }

    mutating func copy(to place: Int) {
        text += old.substring(with: NSRange(location: at, length: place - at))
        at = place
    }

    mutating func skip(to place: Int) {
        at = place
    }

    mutating func add(_ piece: String) {
        text += piece
    }

    /// The new selection starts here (only the first time it's called)…
    mutating func selectFromHere() {
        if start == nil { start = text.utf16.count }
    }

    /// …and ends here (the last time wins).
    mutating func selectToHere() {
        end = text.utf16.count
    }

    /// The rest of the old text, and the finished edit.
    mutating func finish() -> NoteEdit {
        copy(to: old.length)
        let lo = start ?? end
        return NoteEdit(text: text, selection: lo..<max(lo, end))
    }
}

/// The selection kept inside the text, in case the two have drifted apart.
private func clamp(_ range: Range<Int>, _ length: Int) -> Range<Int> {
    let lo = min(max(range.lowerBound, 0), length)
    return lo..<min(max(range.upperBound, lo), length)
}

/// How many `unit`s there are in a row starting at `from`, going on (no
/// further than `to`).
private func run(_ ns: NSString, _ unit: UInt16, from: Int, to limit: Int) -> Int {
    var n = 0
    while from + n < limit && ns.character(at: from + n) == unit {
        n += 1
    }
    return n
}

/// The same going back: how many sit in a row just before `from` (no
/// further back than `to`).
private func runBack(_ ns: NSString, _ unit: UInt16, from: Int, to limit: Int = 0) -> Int {
    var n = 0
    while from - n > limit && ns.character(at: from - n - 1) == unit {
        n += 1
    }
    return n
}

/// Where a line's words end: before its return, if it has one (10 is the
/// return's UTF-16 code).
private func lineEnd(_ ns: NSString, _ line: NSRange) -> Int {
    let end = line.location + line.length
    return end > line.location && ns.character(at: end - 1) == 10 ? end - 1 : end
}

/// The whole lines a selection touches, without the last one's return. A
/// selection that ends at the very start of a line (a whole line picked,
/// its return and all) doesn't take in the line after.
private func wholeLines(_ ns: NSString, _ sel: Range<Int>) -> Range<Int> {
    var end = sel.upperBound
    if end > sel.lowerBound && ns.character(at: end - 1) == 10 { end -= 1 }
    let lines = ns.lineRange(for: NSRange(location: sel.lowerBound, length: end - sel.lowerBound))
    return lines.location..<lineEnd(ns, lines)
}

/// The selected words, one stretch per line, each without the spaces at its
/// ends or its line's start (`## `, `- [ ] `), so a marker never lands
/// between a bullet's dash and its words. Lines with only spaces selected
/// are left out.
private func stretches(_ ns: NSString, _ sel: Range<Int>) -> [Range<Int>] {
    var parts: [Range<Int>] = []
    var place = sel.lowerBound
    while place < sel.upperBound {
        let line = ns.lineRange(for: NSRange(location: place, length: 0))
        let end = lineEnd(ns, line)
        let words = ns.substring(with: NSRange(location: line.location, length: end - line.location))
        var lo = max(sel.lowerBound, line.location + linePrefix(words).length)
        var hi = min(sel.upperBound, end)
        // 32 is a space, 9 a tab.
        while lo < hi && [32, 9].contains(ns.character(at: lo)) { lo += 1 }
        while hi > lo && [32, 9].contains(ns.character(at: hi - 1)) { hi -= 1 }
        if lo < hi { parts.append(lo..<hi) }
        place = max(line.location + line.length, place + 1)
    }
    return parts
}

/// The matches of `pattern` the selection touches: a caret has to be inside
/// one, a selection only has to overlap it.
private func touchedSpans(_ pattern: String, in edit: NoteEdit) -> [NSTextCheckingResult] {
    let ns = edit.text as NSString
    let sel = clamp(edit.selection, ns.length)
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex.matches(in: edit.text, range: NSRange(location: 0, length: ns.length)).filter { m in
        let lo = m.range.location
        let hi = lo + m.range.length
        return sel.isEmpty ? (lo < sel.lowerBound && sel.lowerBound < hi)
                           : (lo < sel.upperBound && sel.lowerBound < hi)
    }
}

/// Every match of `pattern` the selection touches, swapped for what
/// `rewrite` makes of its groups (`g[0]` the whole match, `g[1]` the first
/// bracket, and so on), with what changed selected. Nil when it touches none.
private func rewriteSpans(_ pattern: String, in edit: NoteEdit,
                          _ rewrite: ([String]) -> String) -> NoteEdit? {
    let ns = edit.text as NSString
    let touched = touchedSpans(pattern, in: edit)
    guard !touched.isEmpty else { return nil }
    var out = Rewrite(ns)
    for m in touched {
        let groups = (0..<m.numberOfRanges).map { n in
            m.range(at: n).location == NSNotFound ? "" : ns.substring(with: m.range(at: n))
        }
        out.copy(to: m.range.location)
        out.selectFromHere()
        out.add(rewrite(groups))
        out.selectToHere()
        out.skip(to: m.range.location + m.range.length)
    }
    return out.finish()
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Logic/NoteTidy.swift` (new file)

Pure logic, the web's `lib/tidy-note.ts` and `lib/line-diff.ts`, rule for rule. The tests include the web's own answers for thirteen notes, so a tidy on the phone and on the laptop come out the same.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/NoteTidy.swift
//  Phase:   8c (the formatting bar and tidy)
//  Ports:   lib/tidy-note.ts (`tidyNote`) and lib/line-diff.ts (`lineDiff`)
//
//  Summary: "Tidy this note", worked out on the phone, the way the web now
//           does it too: no AI, nothing sent anywhere. It only ever adds
//           structure (`## ` before a line that reads like a heading, `- `
//           before a run of short loose lines) and tidies the spacing; it
//           never changes, moves or drops a word, and it leaves code, columns
//           and tables exactly as written. Being a pure function of the note,
//           the same note tidies the same on the phone and on the laptop.
//           `lineDiff` shows what it would change before anything is applied.
//

import Foundation

/// What a tidy came back with. `NoteTidy` in lib/note-tidy.ts.
struct NoteTidy: Equatable {
    /// The rearranged note. The note as it was when nothing changed.
    let body: String
    /// False when the note was tidy already.
    let changed: Bool
    /// One short line on what was done, shown above the preview.
    let summary: String
}

// MARK: - Reading a line

/// Does `pattern` match somewhere in `text`? The web's `/…/.test(text)`.
private func test(_ pattern: String, _ text: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
}

/// `.trim()`: the spaces and returns off both ends.
private func trim(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func isFence(_ t: String) -> Bool { test("^```", t) }
private func isHeading(_ t: String) -> Bool { test(#"^#{1,3}\s+"#, t) }
/// Includes `- [ ]` checkboxes.
private func isBullet(_ t: String) -> Bool { test(#"^[-*]\s+"#, t) }
private func isNumbered(_ t: String) -> Bool { test(#"^\d+\.\s+"#, t) }
private func isQuote(_ t: String) -> Bool { test(#"^>\s?"#, t) }
private func isTableLine(_ line: String) -> Bool { test(#"^\s*\|"#, line) }
private func isStructured(_ t: String) -> Bool {
    isHeading(t) || isBullet(t) || isNumbered(t) || isQuote(t)
}

/// The longest line folded into a heading or a bullet. A wrapped sentence
/// is longer than this, so leaving long lines alone avoids bulleting prose.
private let shortLine = 90

/// What a tidy did, for the summary line.
private struct Flags {
    var headings = 0
    var bullets = 0
    var spacing = false
}

/// The spaces off a line's end, and any bullet glyph (`*`, `•` and friends)
/// made a `- `.
private func normalizeLine(_ line: String) -> String {
    line.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"^(\s*)[*•·‣▪◦]\s+"#, with: "$1- ", options: .regularExpression)
}

/// An ALL-CAPS label with no sentence punctuation reads as a heading.
private func looksLikeCapsHeading(_ t: String) -> Bool {
    if t.utf16.count > 60 { return false }
    if test(#"[.?!]$"#, t) { return false }
    let letters = t.replacingOccurrences(of: "[^A-Za-z]", with: "", options: .regularExpression)
    return letters.utf16.count >= 3 && letters == letters.uppercased()
}

/// A short label ending in a colon, with words under it, reads as one too.
private func looksLikeColonHeading(_ t: String) -> Bool {
    if !test(":$", t) { return false }
    let label = t.replacingOccurrences(of: #"\s*:$"#, with: "", options: .regularExpression)
    if label.isEmpty || label.utf16.count > 60 { return false }
    if test(#"[.?!]"#, label) { return false }   // a sentence, not a label
    return label.split(whereSeparator: \.isWhitespace).count <= 8
}

/// A promoted heading doesn't need its colon any more.
private func headingText(_ t: String) -> String {
    t.replacingOccurrences(of: #"\s*:\s*$"#, with: "", options: .regularExpression)
}

// MARK: - Tidying

/// One run of ordinary lines (no code, columns or table) reformatted:
/// headings promoted first, then each run of two or more loose lines made a
/// list. Blank lines pass through and break runs, which is what keeps
/// real paragraphs from turning into lists.
private func tidyPlain(_ input: [String], _ flags: inout Flags) -> [String] {
    let lines = input.map(normalizeLine)

    // Headings first, so a promoted heading breaks the list below it.
    var headed: [String] = []
    for (idx, line) in lines.enumerated() {
        let t = trim(line)
        if t.isEmpty || isStructured(t) {
            headed.append(line)
        } else if looksLikeCapsHeading(t) {
            flags.headings += 1
            headed.append("## \(headingText(t))")
        } else if lines[(idx + 1)...].contains(where: { !trim($0).isEmpty }) && looksLikeColonHeading(t) {
            flags.headings += 1
            headed.append("## \(headingText(t))")
        } else {
            headed.append(line)
        }
    }

    func bulletable(_ line: String) -> Bool {
        let t = trim(line)
        return !t.isEmpty && !isStructured(t) && t.utf16.count <= shortLine && !t.hasSuffix(",")
    }

    var out: [String] = []
    var i = 0
    while i < headed.count {
        if !bulletable(headed[i]) {
            out.append(headed[i])
            i += 1
            continue
        }
        var group: [String] = []
        while i < headed.count && bulletable(headed[i]) {
            group.append(headed[i])
            i += 1
        }
        // Two or more loose lines in a row are a list; one stays a line.
        if group.count >= 2 {
            out += group.map { "- \(trim($0))" }
            flags.bullets += 1
        } else {
            out += group
        }
    }
    return out
}

/// A blank line before every heading, blank runs squeezed to one, and the
/// ends trimmed.
private func finalize(_ lines: [String], _ flags: inout Flags) -> String {
    var spaced: [String] = []
    for line in lines {
        if isHeading(trim(line)), let last = spaced.last, !trim(last).isEmpty {
            spaced.append("")
            flags.spacing = true
        }
        spaced.append(line)
    }
    let joined = spaced.joined(separator: "\n")
    // `(?m)` makes `$` match at every line's end, the web's `/gm`.
    let cleaned = trim(joined
        .replacingOccurrences(of: #"(?m)[ \t]+$"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression))
    if cleaned != joined { flags.spacing = true }
    return cleaned
}

/// The one line saying what changed: "Added a heading and grouped loose
/// lines into lists."
private func summarize(_ flags: Flags) -> String {
    var parts: [String] = []
    if flags.headings > 0 {
        parts.append(flags.headings == 1 ? "added a heading" : "added \(flags.headings) headings")
    }
    if flags.bullets > 0 { parts.append("grouped loose lines into lists") }
    if parts.isEmpty && flags.spacing { parts.append("tidied the spacing") }
    guard let last = parts.last else { return "Tidied the layout." }
    let phrase = parts.count == 1 ? last : parts.dropLast().joined(separator: ", ") + " and " + last
    return phrase.prefix(1).uppercased() + phrase.dropFirst() + "."
}

/// A note reformatted. The note comes back untouched (`changed` false) when
/// it's tidy already, when the result would go past the note limit, or
/// when it would somehow come back empty, so Apply can never make a note
/// worse.
func tidyNote(_ input: String) -> NoteTidy {
    let src = input.replacingOccurrences(of: "\r\n?", with: "\n", options: .regularExpression)
        .components(separatedBy: "\n")
    var flags = Flags()
    var out: [String] = []
    var plain: [String] = []
    func flush() {
        if !plain.isEmpty {
            out += tidyPlain(plain, &flags)
            plain = []
        }
    }

    var i = 0
    while i < src.count {
        let line = src[i]
        let t = trim(line)

        // A code block, kept exactly: up to and including its closing fence.
        if isFence(t) {
            flush()
            out.append(line)
            i += 1
            var done = false
            while i < src.count && !done {
                out.append(src[i])
                done = isFence(trim(src[i]))
                i += 1
            }
            continue
        }

        // A column block, kept exactly: up to its closing `:::`.
        if t == ":::columns" {
            flush()
            out.append(line)
            i += 1
            var done = false
            while i < src.count && !done {
                out.append(src[i])
                done = trim(src[i]) == ":::"
                i += 1
            }
            continue
        }

        // A table: only the spaces off each row's end.
        if isTableLine(line) {
            flush()
            while i < src.count && isTableLine(src[i]) {
                out.append(src[i].replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression))
                i += 1
            }
            continue
        }

        plain.append(line)
        i += 1
    }
    flush()

    let body = finalize(out, &flags)
    let changed = body != input && !trim(body).isEmpty && fitsBudget(noteLength(body))
    if !changed {
        return NoteTidy(body: input, changed: false, summary: "This note already looks tidy.")
    }
    return NoteTidy(body: body, changed: true, summary: summarize(flags))
}

// MARK: - What changed

/// One line of a before-and-after comparison: in both, only in the tidy
/// (added), or only in the original (gone).
struct DiffLine: Equatable {
    enum Kind { case same, add, del }
    let kind: Kind
    let text: String
}

/// The two texts compared line by line, the standard longest-common-
/// subsequence way: lines in both stay as context, so a well-behaved tidy
/// shows only the headings it put in and the lines it reshaped. Line for
/// line the web's `lineDiff`, including which side wins a tie.
func lineDiff(_ before: String, _ after: String) -> [DiffLine] {
    let a = before.components(separatedBy: "\n")
    let b = after.components(separatedBy: "\n")
    let n = a.count
    let m = b.count

    // lcs[i][j]: how many lines a[i...] and b[j...] have in common, in order.
    var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    for i in stride(from: n - 1, through: 0, by: -1) {
        for j in stride(from: m - 1, through: 0, by: -1) {
            lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
        }
    }

    var out: [DiffLine] = []
    var i = 0
    var j = 0
    while i < n && j < m {
        if a[i] == b[j] {
            out.append(DiffLine(kind: .same, text: a[i]))
            i += 1
            j += 1
        } else if lcs[i + 1][j] >= lcs[i][j + 1] {
            out.append(DiffLine(kind: .del, text: a[i]))
            i += 1
        } else {
            out.append(DiffLine(kind: .add, text: b[j]))
            j += 1
        }
    }
    out += a[i...].map { DiffLine(kind: .del, text: $0) }
    out += b[j...].map { DiffLine(kind: .add, text: $0) }
    return out
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteFormatBar.swift` (new file)

The bar. It needs 4.1. The `extension NoteEdit` at the bottom is where `TextSelection` (section 2) turns into the offsets NoteFormat counts in, and back.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteFormatBar.swift
//  Phase:   8c (the formatting bar and tidy)
//  Ports:   `Toolbar` in components/NoteEditor.tsx: Heading 1 to 3 and Body
//           text, Bold, Italic, Underline, the highlighter (one Highlight
//           and a Clear, D-38), Text colour, the three lists, Quote, Inline
//           code and Code block. Tables, columns and links aren't on the
//           phone's bar; they're typed (D-40)
//
//  Summary: The row of buttons that sits on top of the keyboard while you
//           type a note. Each button hands one of NoteFormat's changes to
//           the editor, which runs it on the text and what's selected.
//           Text colour swaps the row for the five pens.
//

import SwiftUI

struct NoteFormatBar: View {
    /// Runs a change on the editor's text and selection. The bar doesn't
    /// hold the text itself; the editor does (NoteView.swift).
    let apply: ((NoteEdit) -> NoteEdit) -> Void

    /// True while the row shows the pens instead of the buttons.
    @State private var choosingPen = false

    var body: some View {
        Group {
            if choosingPen {
                pens
            } else {
                buttons
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Theme.outer)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: The buttons

    private var buttons: some View {
        // Wider than the phone, so it scrolls sideways.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // A `Menu` is a button that opens a short list of buttons.
                Menu {
                    Button("Heading 1") { apply { setLineStyle(.heading1, in: $0) } }
                    Button("Heading 2") { apply { setLineStyle(.heading2, in: $0) } }
                    Button("Heading 3") { apply { setLineStyle(.heading3, in: $0) } }
                    Button("Body text") { apply { setLineStyle(.body, in: $0) } }
                } label: {
                    glyph("textformat.size")
                }
                .accessibilityLabel("Text style")
                gap

                key("bold", "Bold") { toggleMark(.bold, in: $0) }
                key("italic", "Italic") { toggleMark(.italic, in: $0) }
                key("underline", "Underline") { toggleMark(.underline, in: $0) }
                gap

                key("highlighter", "Highlight") { highlight(in: $0) }
                key("eraser", "Clear highlight") { clearHighlight(in: $0) }
                Button {
                    choosingPen = true
                } label: {
                    glyph("paintpalette")
                }
                .accessibilityLabel("Text colour")
                gap

                key("list.bullet", "Bulleted list") { setLineStyle(.bullet, in: $0) }
                key("list.number", "Numbered list") { setLineStyle(.numbered, in: $0) }
                key("checklist", "Checklist") { setLineStyle(.checkbox, in: $0) }
                key("text.quote", "Quote") { setLineStyle(.quote, in: $0) }
                gap

                key("chevron.left.forwardslash.chevron.right", "Inline code") { toggleMark(.code, in: $0) }
                key("curlybraces", "Code block") { insertCodeBlock(in: $0) }
            }
            .padding(.horizontal, 8)
        }
    }

    /// One button: its symbol, what VoiceOver calls it, and the change it
    /// makes. `@escaping` because the change is kept in the button's action
    /// until the tap.
    private func key(_ symbol: String, _ name: String,
                     _ change: @escaping (NoteEdit) -> NoteEdit) -> some View {
        Button {
            apply(change)
        } label: {
            glyph(symbol)
        }
        .accessibilityLabel(name)
    }

    /// A button's face: an SF Symbol in a 40-point square, all of it tappable.
    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }

    /// The thin upright line between groups of buttons (the web's Divider).
    private var gap: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: 1, height: 22)
            .padding(.horizontal, 5)
    }

    // MARK: The pens

    /// Text colour's row: back, the five pens, and No colour. Picking one
    /// paints the selection and puts the buttons back.
    private var pens: some View {
        HStack(spacing: 12) {
            Button {
                choosingPen = false
            } label: {
                glyph("chevron.left")
            }
            .accessibilityLabel("Back to formatting")

            ForEach(notePens, id: \.self) { pen in
                Button {
                    apply { paint(pen, in: $0) }
                    choosingPen = false
                } label: {
                    Circle()
                        .fill(Theme.pen(pen) ?? Theme.ink)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                // "Red", the web's label for the pen.
                .accessibilityLabel(pen.capitalized)
            }

            Button {
                apply { paint(nil, in: $0) }
                choosingPen = false
            } label: {
                Text("No colour")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 6)
                    .frame(height: 40)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - The editor's selection, as offsets

extension NoteEdit {
    /// The editor's text and selection as a NoteEdit. `TextSelection` holds
    /// positions in the string (`String.Index`); NoteFormat counts UTF-16
    /// units from the start, and `utf16Offset(in:)` turns one into the
    /// other. No selection yet, or one the text has outrun, is a caret at
    /// the end.
    init(text: String, selection: TextSelection?) {
        let end = text.utf16.count
        var range = end..<end
        if let selection, case .selection(let picked) = selection.indices,
           picked.upperBound <= text.endIndex {
            let lo = picked.lowerBound.utf16Offset(in: text)
            let hi = picked.upperBound.utf16Offset(in: text)
            range = lo..<max(lo, hi)
        }
        self.init(text: text, selection: range)
    }

    /// The selection back as the editor's own kind, its positions found in
    /// the new text. An empty one is a caret (an "insertion point").
    var textSelection: TextSelection {
        let lo = String.Index(utf16Offset: selection.lowerBound, in: text)
        let hi = String.Index(utf16Offset: selection.upperBound, in: text)
        return selection.isEmpty ? TextSelection(insertionPoint: lo) : TextSelection(range: lo..<hi)
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteTidySheet.swift` (new file)

The tidy preview. It needs 4.2, and 8b's `NoteReaderView` for the two panels.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteTidySheet.swift
//  Phase:   8c (the formatting bar and tidy)
//  Ports:   the dialog in components/NoteTidyButton.tsx: what the tidy did,
//           the original and the suggestion side by side (one above the
//           other on a phone), "See exactly what changed", Discard and Apply
//
//  Summary: The preview of a tidy. Nothing changes until Apply, and the
//           line-by-line comparison is there to check that no word went
//           missing. The tidy itself (`tidyNote`) is worked out once, when
//           the preview is made.
//

import SwiftUI

/// One tidy waiting for Apply or Discard: the note it was worked out from,
/// what came back, and the comparison. `Identifiable` so `.sheet(item:)`
/// can show it, and a fresh `id` each time, so tapping Tidy again opens a
/// fresh sheet.
struct TidyPreview: Identifiable {
    let id = UUID()
    let source: String
    let tidy: NoteTidy
    let diff: [DiffLine]

    init(source: String) {
        self.source = source
        tidy = tidyNote(source)
        diff = lineDiff(source, tidy.body)
    }
}

private extension Theme {
    /// A line the tidy added: `--good-soft` behind `--good-ink`. In dark
    /// mode the soft green is see-through, which a hex string can't write.
    static let addedBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 159 / 255, green: 187 / 255, blue: 138 / 255, alpha: 0.16)
            : UIColor(hex: "#DFE7D8")
    })
    static let addedInk = Color(uiColor: UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? "#B6CDA5" : "#456F3D")
    })
}

struct NoteTidySheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: TidyPreview
    /// Saves the tidied text. False when the store refused it.
    let onApply: (String) -> Bool

    /// Set when Apply couldn't save.
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if preview.tidy.changed {
                        Text("\(preview.tidy.summary) Your original stays until you apply; check that nothing you wrote is missing.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        side("Original", preview.source)
                        side("Suggested", preview.tidy.body)
                        // A `DisclosureGroup` is a heading you tap to show
                        // or hide what's under it (the web's <details>).
                        DisclosureGroup("See exactly what changed") {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(preview.diff.indices, id: \.self) { i in
                                    diffRow(preview.diff[i])
                                }
                            }
                            .padding(10)
                            .background(Theme.surface2,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.top, 6)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .tint(Theme.ink)
                        if failed {
                            Text("Couldn't save the tidied note. Your original is unchanged.")
                                .font(.system(size: 13.5))
                                .foregroundStyle(Theme.dangerInk)
                        }
                    } else {
                        Text("This note already looks tidy. Nothing to change.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Tidy this note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preview.tidy.changed ? "Discard" : "Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if onApply(preview.tidy.body) {
                            dismiss()
                        } else {
                            failed = true
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!preview.tidy.changed)
                }
            }
        }
    }

    /// The original or the suggestion, drawn as the reader draws it, in a
    /// panel of its own that scrolls when the note is long.
    private func side(_ label: String, _ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            ScrollView {
                NoteReaderView(markdown: markdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 260)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// One line of the comparison: − on red for a line that goes, + on green
    /// for one the tidy adds, and quiet for one that stays.
    private func diffRow(_ line: DiffLine) -> some View {
        let sign = switch line.kind {
        case .del: "−"
        case .add: "+"
        case .same: " "
        }
        let ink = switch line.kind {
        case .del: Theme.dangerInk
        case .add: Theme.addedInk
        case .same: Theme.muted
        }
        let fill = switch line.kind {
        case .del: Theme.dangerSoft
        case .add: Theme.addedBackground
        case .same: Color.clear
        }
        return HStack(alignment: .top, spacing: 8) {
            Text(sign)
                .opacity(0.7)
            // An empty line still takes a line's height.
            Text(line.text.isEmpty ? " " : line.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(ink)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(fill)
    }
}
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift` (replaces the file)

Built on your own 8b version of this file, so your editor-owned Done, Retry and save-before-delete all stay (D-42). Six touched spots, each marked `NEW` or `CHANGED in Phase 8c`: the header; in `NoteView`, two new `@State`s (`tidyPreview`, `undoTidy`), the `tidyRow` line in `reader`, the `.sheet(item:)` and the new `tidyRow` function; in `NoteEditorView`, the `selection` state, `selection:` on the `TextEditor`, the bar at the end of the column, and the new `apply` function.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift
//  Phase:   8a (notes you can write and find), changed in 8b (read first)
//           and 8c (the formatting bar and tidy)
//  Ports:   NotePane in app/classes/page.tsx (the title, "class · day", the
//           bin), the saving half of components/NoteEditor.tsx (save half
//           a second after you stop typing, "Saving…" / "Saved", the 20,000
//           character limit and New page), since 8b the phone's view of a
//           note, components/NoteReader.tsx, and since 8c the Tidy note
//           button and its Undo (components/NoteTidyButton.tsx)
//
//  Summary: One note. A note with words in it opens to read, drawn by
//           NoteReaderView, with Tidy note above it; Edit switches to typing
//           it as plain markdown, with the formatting bar over the keyboard,
//           and Done goes back to reading (D-37). An empty note opens
//           straight for typing. Typing saves by itself a moment after you
//           stop, when you leave, and when the app goes to the background.
//

import SwiftUI

struct NoteView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss   // NEW in Phase 8b

    /// Which note to show. The note itself is looked up in the store.
    let noteID: UUID

    /// NEW in Phase 8b: true while typing, false while reading. Nil until the
    /// screen first appears, then settled once: an empty note opens for
    /// typing, one with words opens to read. Settled once, so typing a note's
    /// first words doesn't flip the screen over to reading.
    @State private var editing: Bool? = nil

    /// NEW in Phase 8c: a tidy waiting in its sheet for Apply or Discard.
    @State private var tidyPreview: TidyPreview? = nil

    /// NEW in Phase 8c: what Undo tidy puts back, and what Apply wrote. Undo
    /// shows while the note still holds exactly what Apply wrote; any edit
    /// after that and it's gone, as on the web.
    @State private var undoTidy: (original: String, applied: String)? = nil

    var body: some View {
        if let note = store.note(noteID) {
            // CHANGED in Phase 8b: reading or typing.
            let typing = editing ?? (note.title.isEmpty && note.body.isEmpty)
            Group {
                if typing {
                    NoteEditorView(note: note, onDone: { editing = false })
                } else {
                    reader(note)
                }
            }
            .toolbar {
                // The editor owns Done so it can flush its draft before the
                // reader appears, and retain the draft if saving fails.
                if !typing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { editing = true }
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear {
                if editing == nil { editing = typing }
            }
        } else {
            // Just deleted (the screen is on its way back), or never existed.
            ContentUnavailableView("Note not found.", systemImage: "note.text")
        }
    }

    /// NEW in Phase 8b: the note to read. Its title and where it lives, then
    /// the note drawn. Nothing here takes the keyboard, the web phone's point:
    /// a thumb brushing the page can't change a word.
    private func reader(_ note: Note) -> some View {
        let course = store.course(note.courseID)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.lastSaveFailed {
                    Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dangerInk)
                        .padding(.bottom, 12)
                }
                Text(noteTitle(title: note.title, body: note.body))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
                tidyRow(note)   // NEW in Phase 8c
                    .padding(.top, 12)
                Divider()
                    .padding(.vertical, 14)
                if note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // The web's empty-note line, as in the editor.
                    Text("Start typing: # for a heading, - for a bullet, - [ ] for a checkbox")
                        .font(.system(size: 15.5))
                        .foregroundStyle(Theme.hint)
                } else {
                    NoteReaderView(markdown: note.body)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        // NEW in Phase 8c: the preview, until Apply or Discard. The note can't
        // change under it while it's up (nothing syncs yet, Phase 14), so
        // the web's "this note changed" check isn't needed.
        .sheet(item: $tidyPreview) { preview in
            NoteTidySheet(preview: preview) { tidied in
                guard store.updateNote(note.id, body: tidied) else { return false }
                undoTidy = (original: preview.source, applied: tidied)
                return true
            }
        }
        .toolbar {
            // The bin, as in the editor: delete, and back to the list's Undo.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
        }
    }

    /// NEW in Phase 8c: Tidy note, and Undo tidy while it lasts. Tidy is off
    /// for a note with nothing in it.
    private func tidyRow(_ note: Note) -> some View {
        let accent = store.profile.accent
        let empty = note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 6) {
            Button {
                tidyPreview = TidyPreview(source: note.body)
            } label: {
                Label("Tidy note", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Theme.brandSoft(accent), in: Capsule())
            }
            .disabled(empty)
            .opacity(empty ? 0.5 : 1)

            if let undo = undoTidy, note.body == undo.applied {
                Button("Undo tidy") {
                    if store.updateNote(note.id, body: undo.original) { undoTidy = nil }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.brand(accent))
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
            }
        }
    }
}

/// The writing surface. A separate view so its scratch copy of the text can
/// start from the note once, in `init` (4a's `_title = State(...)`), and then
/// belong to the typing rather than to the store.
private struct NoteEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// The note as it was when the screen opened: its id, class and day.
    let note: Note

    /// Return to the reader after the whole draft has been saved.
    let onDone: () -> Void

    /// What's typed, which can run ahead of what's saved by half a second.
    @State private var title: String
    @State private var text: String

    /// NEW in Phase 8c: what's selected in the note, or where the caret is.
    /// Nil until the editor first reports one. The formatting bar reads it
    /// to know which words to change, and sets it to select what changed.
    @State private var selection: TextSelection? = nil

    /// The note started by New page, while it's open.
    @State private var nextPage: UUID?

    /// Which field has the keyboard, or nil for none. `@FocusState` is
    /// `@State` for the keyboard: set it to move the caret, set it to nil to
    /// put the keyboard away.
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    init(note: Note, onDone: @escaping () -> Void) {
        self.note = note
        self.onDone = onDone
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.body)
    }

    var body: some View {
        let course = store.course(note.courseID)
        let length = noteLength(text)
        let full = !fitsBudget(length)
        // Saved only when the draft matches and the file write succeeded.
        let saved = !store.lastSaveFailed
            && (store.note(note.id).map { $0.title == title && $0.body == text } ?? false)

        VStack(spacing: 0) {
            // MARK: Title, and where the note lives
            VStack(alignment: .leading, spacing: 2) {
                // The grey text is what the list would call it untitled.
                TextField(noteTitle(title: "", body: text), text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .title)
                    .accessibilityLabel("Note title")
                    // Return in the title moves down into the note.
                    .submitLabel(.next)
                    .onSubmit { focus = .body }
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // MARK: The note
            // `TextEditor` is a multi-line text field that scrolls by itself.
            // It has no placeholder, so one sits behind it while it's empty.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Start typing: # for a heading, - for a bullet, - [ ] for a checkbox")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.hint)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                // CHANGED in Phase 8c: `selection:` keeps `selection` up to date
                // as you move the caret, and moves it when `selection` is set.
                TextEditor(text: $text, selection: $selection)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .body)
                    .accessibilityLabel("Note body")
                    // Let the canvas show through instead of a white box.
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
            }

            // MARK: Saving
            // "Saving…" until the store has it, then "Saved". Near the limit,
            // the count and New page, so a long lecture goes on in a new note
            // instead of stopping at the ceiling.
            VStack(alignment: .leading, spacing: 6) {
                if store.lastSaveFailed {
                    HStack(spacing: 10) {
                        Text("Couldn't save on this device. Your last change may be lost if the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.dangerInk)
                        Button("Retry") { save() }
                            .font(.footnote.weight(.semibold))
                    }
                }
                Text(full ? "This note is full, start a new page to keep writing"
                          : (saved ? "Saved" : "Saving…"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
                if length > maxNoteChars * 9 / 10 {
                    HStack(spacing: 10) {
                        Text("\(length.formatted()) / \(maxNoteChars.formatted())")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(full ? Theme.dangerInk : Theme.warnInk)
                        Spacer(minLength: 0)
                        Button("New page") {
                            save()
                            nextPage = store.addNote(courseID: note.courseID, date: note.date,
                                                     assignmentID: note.assignmentID)
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }

            // MARK: The formatting bar
            // NEW in Phase 8c: last in the column, so with the keyboard up it
            // sits right on top of it. Hidden while you type the title,
            // since every button changes the note's words.
            if focus != .title {
                NoteFormatBar(apply: apply)
            }
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete goes straight back, where the Undo bar is waiting.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Flush the debounce first, so Undo restores the latest typing.
                    save()
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
            // Flush before replacing the editor. A refused body or failed
            // file write must leave the draft available to fix or retry.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    save()
                    guard fitsBudget(noteLength(text)), !store.lastSaveFailed else { return }
                    focus = nil
                    onDone()
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
        // Save half a second after the typing stops (the web's 500 ms).
        // Every keystroke changes the id, which cancels the waiting save and
        // starts a new wait: only the last one survives its sleep (4b, 7a).
        .task(id: Draft(title: title, body: text)) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
        // And straight away when you leave, or the app goes to the background.
        .onDisappear { save() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { save() }
        }
        // A new note and Edit both open intentionally for typing.
        .onAppear {
            focus = .body
        }
        .navigationDestination(item: $nextPage) { id in
            NoteView(noteID: id)
        }
    }

    /// What `.task(id:)` watches: the title and the body together.
    private struct Draft: Equatable {
        let title: String
        let body: String
    }

    /// NEW in Phase 8c: one of the bar's changes, run on what's typed and
    /// what's selected. The new text goes into `text`, so it saves the way
    /// typing does, and the new selection into the editor. The keyboard
    /// comes back too, for a tap made while it was away.
    private func apply(_ change: (NoteEdit) -> NoteEdit) {
        let before = NoteEdit(text: text, selection: selection)
        let after = change(before)
        if after != before {
            text = after.text
            selection = after.textSelection
        }
        focus = .body
    }

    /// Hands the store what's on screen. Past the limit, the title still
    /// saves and the body waits until it fits again, so nothing is cut off.
    private func save() {
        let fits = fitsBudget(noteLength(text))
        store.updateNote(note.id, title: title, body: fits ? text : nil)
    }
}
```

### Not typed: the tests

`NoteFormatTests.swift` (27 tests) and `NoteTidyTests.swift` (18 tests) are in `docs/ios/reference/Tests/Logic/`. To run them with your own script:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/NoteFormatTests.swift Tests/Logic/
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/NoteTidyTests.swift Tests/Logic/
scripts/test-logic.sh
```

No script changes: both new code files are in `Logic/`, which both scripts copy whole.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 8c: the formatting bar and tidy"
```

On the phone:

1. **Bold on and off.** Make a note, tap **Edit**, type `a cell wall`. Double-tap "cell" and tap **B**: `a **cell** wall`, with "cell" still selected. Tap **B** again: the stars go. Tap **B** a third time and **Done**: "cell" in bold.
2. **Bold from nothing.** **Edit**, put the caret at the end of a line, tap **B** with nothing selected: `****`, with the caret in the middle. Type `ATP`, then **Done**: bold.
3. **Out of the middle.** **Edit**, select all of a line, tap **B**, then double-tap one word in the middle and tap **B**: that word gets its own stars and, after **Done**, is the only plain word in a bold line.
4. **Lines.** Put the caret in a line and tap the bullet button: `- ` in front. Tap it again: gone. Select three lines and tap the numbers: `1.`, `2.`, `3.`. **Aa → Heading 2** on one: `## `. Try the checklist and the quote.
5. **Highlight and Clear.** Select two words, tap the highlighter: `==` around them. Tap it again: nothing changes, on purpose. Put the caret anywhere inside them and tap the eraser: the whole highlight goes.
6. **Pens.** Select a word, tap the palette: the row turns into five dots. Tap red: `[[red|word]]`. Put the caret in it, palette, blue: `[[blue|word]]`. Palette, **No colour**: plain again.
7. **Code.** Select a word, tap `</>`: backticks. On an empty line tap `{ }`: two fences with the caret between them. **Done**: the grey panel.
8. **Tidy.** Make a note with these lines and tap **Done**: `BIOLOGY 101`, `Cell parts:`, `nucleus`, `mitochondria`, `ribosome`. Tap **Tidy note**: "Added 2 headings and grouped loose lines into lists.", the original above the suggestion. Open **See exactly what changed**: red lines going, green ones coming. **Apply**: two headings and a list. **Undo tidy**: back as you wrote it. Tidy and Apply again, then **Edit** and change a word: **Undo tidy** is gone.
9. **Already tidy.** Tap **Tidy note** on the tidied note: "This note already looks tidy. Nothing to change.", with Apply greyed out.
10. **Dark mode.** Profile → Appearance → Dark: the bar, the dots and the red and green lines all still read.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] The bar sits on the keyboard while you type a note, and goes while you type the title.
- [ ] Bold, italic, underline and inline code go on and come off with a second tap, and stay selected in between.
- [ ] Headings, the three lists and quotes start and end lines, and numbers count from 1.
- [ ] Highlight only adds; Clear takes a whole highlight off; the pens wrap, recolour and come off.
- [ ] Tidy previews, Apply writes, Undo tidy puts it back, and nothing changes on Discard.

## 7. If it breaks

- **`extra argument 'selection' in call`** or **`cannot find type 'TextSelection' in scope`**: both are iOS 18. Check `Package.swift` says `.iOS(.v18)`, as it has since Phase 0.
- **After a button, the caret jumps to the end of the note** (the text changed but the selection didn't stick): set the selection a moment later, after the editor has taken the new text. In `apply`, swap `selection = after.textSelection` for `Task { selection = after.textSelection }`, and tell me, since it'd mean iOS behaves differently from what the docs promise.
- **A button does nothing:** Highlight on words already highlighted does nothing on purpose (Clear first). Anything else: check the button's change returns the new edit, and that `NoteFormatBar(apply: apply)` passes the editor's function, not a new one.
- **The bar shows empty squares instead of icons:** an SF Symbol name is misspelled. They're strings, so the build can't catch it; compare with 4.3 letter by letter.
- **`cannot pass immutable value as inout argument`**: the `&flags` passed to `tidyPlain` and `finalize` has to be a `var`, as in 4.2.
- **Tidy takes a moment on a very long note:** it's worked out when you tap. A note at the 20,000-character limit made of short lines takes about a second on a laptop's debug build; a real lecture is a fraction of that.

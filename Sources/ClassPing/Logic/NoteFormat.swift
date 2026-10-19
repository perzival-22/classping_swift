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

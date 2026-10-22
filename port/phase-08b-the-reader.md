---
title: "Phase 8b: The reader"
date: 2026-10-18
generated_by: skills-for-architects
---

# Phase 8b: The reader

*Second of three parts of Phase 8 (D-36). Checked on 2026-10-18 on top of Phase 8a's doc laid over your tree: `build-check.sh` gave `BUILD_OK` with no warnings, `logic-test.sh` passed 236/236 (31 new, in `NoteMarkdownTests`), and `persistence-test.sh` 28/28. Nothing here has been on a phone yet.*

*Since typed (D-42): your tree goes further than this doc in `NoteView.swift` (Done in the editor), `NoteReaderView.swift` (VoiceOver headings and checkbox states, selectable table cells) and `NoteMarkdown.swift` (a safe restore of set-aside pieces). The reference holds your version, plus D-39's link fix, which yours still needs.*

**Before you start:** 8a typed, built and committed. This phase draws the notes 8a lets you write, and it reuses two of 8a's helpers (`tableCells`, `isTableRuler`).

## 1. Goal

A note opens the way it's meant to be read: `# Cells` is a heading, `- [x] lecture` a ticked box, `==powerhouse==` highlighted, `[[red|late]]` in red. **Edit** switches to the markdown to type it, **Done** back to reading.

**On your phone:** open a note with words in it. Its title, "Biology · Today", a line, then the note drawn: headings in three sizes, bullets, numbered lists counted 1, 2, 3, checkboxes (filled with your accent when ticked), quotes with a rule down the left, code on a grey panel, tables in a grid, columns one under the other, and inside the lines **bold**, *italic*, underline, highlight, the five pens, `code` and links that open in Safari. Long-press to select and copy. **Edit** at the top right brings up the keyboard with the markdown; **Done** puts it away and draws the note again. A new, empty note still opens straight for typing.

## 2. New Swift concepts

**`AttributedString`: one piece of text, many styles.** A `Text` normally has one font and one color. An `AttributedString` carries attributes per stretch of characters, and one `Text` shows them all, wrapping as a single paragraph. You build it by adding styled pieces together:

```swift
var line = AttributedString("Cells are ")
var small = AttributedString("smallest")
small.font = .system(size: 15.5, weight: .bold)
small.backgroundColor = Theme.markBackground      // a highlighter behind it
line += small
var link = AttributedString("the book")
link.link = URL(string: "https://openstax.org")   // tappable: opens Safari
line += link
Text(line)
```

`styledLine` does exactly this for each run `inlineRuns` gives it.

**A view that contains itself.** A column block holds blocks of its own, so `NoteBlocksView` draws a column by putting another `NoteBlocksView` inside itself, the way `parseBlocks` calls itself for each column. That's fine for a view as long as each level is given less to draw, so it ends (a column can't contain the block it's in).

```swift
ForEach(cols.indices, id: \.self) { i in
    NoteBlocksView(blocks: cols[i])      // the same view, one level down
}
```

**`Grid` and `GridRow`.** A table needs cells lined up in both directions: every cell in a column as wide as the widest, every cell in a row as tall as the tallest. `Grid` does that, where nested `HStack`s inside a `VStack` can't (each `HStack` sizes itself alone):

```swift
Grid(horizontalSpacing: 0, verticalSpacing: 0) {
    GridRow { Text("Part"); Text("Job") }
    GridRow { Text("Nucleus"); Text("DNA") }
}
```

You'll also meet: **`NSRegularExpression`**, used for the two things `replacingOccurrences(…, options: .regularExpression)` can't do (reading a match's groups, and deciding per match what to put back); its ranges count in UTF-16 units, so the text is read as an `NSString`. **Functions inside a function** that change the outer function's variables (`flushTable`, `keep`), the web's arrow functions. **`.textSelection(.enabled)`**, which lets a long-press select and copy. **`alignmentGuide`**, which tells the checkbox where its baseline is so it lines up with the words. And `Text.LineStyle`, SwiftUI's name for an underline, written out because UIKit has one with the same short name.

## 3. What it maps from the web app

| Web | Swift | Difference, and why |
|---|---|---|
| `parseBlocks` in `lib/notes.ts` | `parseBlocks` in `Logic/NoteMarkdown.swift` | Same blocks from the same rules; the tests include the web's own output for a mixed note |
| `renderBlocks`'s lists and tables | `listNumbers`, `tableGrid` | The web's `<ol>` numbers each run of `1.` lines from 1 (typed digits don't count), and short table rows get empty cells: the same here, worked out ahead of drawing |
| `escapeHtml`, `safeHref`, `inlineToHtml` | same names, same file | Same HTML, checked line for line against the web, including the link fix both apps got on 2026-10-18 (D-39: an address with `&` was escaped twice). One phone-only fix: an escaped character inside `code` comes back as itself, where the web shows a stray "0" |
| The browser reading that HTML | `inlineRuns` | Phone-only: the HTML read back as styled runs. Crossed tags (`**a __b** c__`) come out as the browser shows them |
| `components/NoteReader.tsx` | `Screens/Notes/NoteReaderView.swift` | Drawn with SwiftUI instead of HTML and CSS, at the same sizes, colors and spacing. No highlighting by selecting text: SwiftUI's `Text` can be selected and copied, but iOS 18 doesn't tell the app what was selected. Highlighting moves to 8c's formatting bar, one Highlight and a Clear (D-38) |
| `.note-body` in `app/globals.css` | `Design/Theme+Notes.swift`, and the sizes in the reader | Same pens (deep on light, lifted on dark, deep under a highlight), highlighter, code colors. Two small differences: `[[red|==hi==]]` stays red (the web's highlighter ink wins there), and a table wider than the phone scrolls sideways |
| The phone's note view (`NotePane` with `desktop` false) | `NoteView`'s reader, with Edit (D-37) | The web's phone only reads; here Edit switches to 8a's typing. A note with nothing in it opens for typing, so Quick note and New note still land on the keyboard |

## 4. Files, in the order to type them

4.1 and 4.2 build on their own; 4.3 needs both; 4.4 needs 4.3. Three new files, one replaced.

### 4.1 `~/ClassPing/Sources/ClassPing/Logic/NoteMarkdown.swift` (new file)

Pure logic, the biggest file of the phase. Three parts: two regular-expression helpers, `parseBlocks` and its two small friends, then the inline dialect. Every pattern is the web's, character for character; the tests compare the output with `lib/notes.ts` itself.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/NoteMarkdown.swift
//  Phase:   8b (the reader)
//  Ports:   lib/notes.ts (parseBlocks, escapeHtml, safeHref, inlineToHtml,
//           and from renderBlocks the list numbering and the table padding)
//
//  Summary: Reads a note's markdown the way the web does. `parseBlocks` cuts
//           it into blocks: headings, paragraphs, list items, checkboxes,
//           quotes, code, tables and columns. `inlineToHtml` turns one line's
//           markers into the same small HTML the web makes, and `inlineRuns`
//           reads that HTML back as runs of styled text for the reader to
//           draw. Foundation only, for the tests.
//

import Foundation

// MARK: - Regular expressions, with groups and callbacks

/// The bracketed groups of the first match of `pattern` in `text` (index 0
/// is the whole match), or nil when there's no match. The web's
/// `/…/.exec(text)`. Apple's regular expressions still count in UTF-16 units,
/// like JavaScript, so the text is handled as an `NSString` for the ranges.
private func regexGroups(_ pattern: String, _ text: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = text as NSString
    guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
        return nil
    }
    // A group that took no part in the match comes back as "".
    return (0..<m.numberOfRanges).map { i in
        m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i))
    }
}

/// Every match of `pattern` replaced by what `transform` makes of its groups.
/// The web's `.replace(/…/g, (whole, a, b) => …)`, a replace that decides
/// per match: keep a link only if its address is safe, say.
private func replacingMatches(of pattern: String, in text: String,
                              with transform: ([String]) -> String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
    let ns = text as NSString
    var out = ""
    var copied = 0   // how much of `text` is already in `out`
    for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
        // The plain text between the last match and this one.
        out += ns.substring(with: NSRange(location: copied, length: m.range.location - copied))
        let groups = (0..<m.numberOfRanges).map { i in
            m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i))
        }
        out += transform(groups)
        copied = m.range.location + m.range.length
    }
    return out + ns.substring(from: copied)
}

// MARK: - Blocks

/// One block of a note: a heading, a paragraph, one list item, a quote line,
/// a code block, a table or a set of columns. `Block` in lib/notes.ts.
/// A block can hold blocks (a column's), which is fine for a struct as long
/// as they sit in an array.
struct NoteBlock: Equatable {
    enum Kind: Equatable {
        case h1, h2, h3, p, quote, code, ul, ol, check, cols, table
    }
    var kind: Kind
    /// The line's text, inline markers still in (the reader styles them).
    /// For code, the whole block's text.
    var text = ""
    /// Whether a checkbox is ticked.
    var checked = false
    /// A column block's columns, each a run of blocks of its own.
    var columns: [[NoteBlock]] = []
    /// A table's rows, header first, as each cell's text.
    var rows: [[String]] = []
}

/// A note's markdown, cut into blocks. `parseBlocks` in lib/notes.ts, the
/// same rules in the same order: code fences keep everything literal (and
/// an unclosed one runs to the end), `:::columns` gathers lines until `:::`
/// and parses each column again, a run of `|` lines is a table only if its
/// second line is the ruler, and every other line is read by its first
/// characters.
func parseBlocks(_ md: String) -> [NoteBlock] {
    var out: [NoteBlock] = []
    var inFence = false
    var fence: [String] = []
    var inCols = false
    var colGroups: [[String]] = []
    var colFence = false   // a code fence inside a column, where `:::` is just text
    var tableBuf: [String] = []

    // Functions inside a function can change the variables above them.
    // These are the web's `flushCols` and `flushTable`.
    func flushCols() {
        out.append(NoteBlock(kind: .cols,
                             columns: colGroups.map { parseBlocks($0.joined(separator: "\n")) }))
        inCols = false
        colGroups = []
        colFence = false
    }
    func flushTable() {
        guard !tableBuf.isEmpty else { return }
        let buf = tableBuf
        tableBuf = []
        if buf.count >= 2 && isTableRuler(buf[1]) {
            // The header, then the body rows; the ruler itself is dropped.
            let rows = ([buf[0]] + buf.dropFirst(2)).map(tableCells)
            out.append(NoteBlock(kind: .table, rows: rows))
        } else {
            // A half-typed table reads as plain lines rather than vanishing.
            out += buf.map { NoteBlock(kind: .p, text: $0) }
        }
    }
    // Inside a column block: a column's lines are collected for later.
    func addToColumn(_ line: String) {
        if colGroups.isEmpty { colGroups.append([]) }
        colGroups[colGroups.count - 1].append(line)
    }

    for line in md.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if inCols {
            if trimmed.hasPrefix("```") {
                colFence.toggle()
                addToColumn(line)
                continue
            }
            if !colFence && trimmed == ":::col" {
                colGroups.append([])
                continue
            }
            if !colFence && trimmed == ":::" {
                flushCols()
                continue
            }
            addToColumn(line)
            continue
        }

        // A fence opens or closes a code block.
        if trimmed.hasPrefix("```") {
            flushTable()
            if inFence {
                out.append(NoteBlock(kind: .code, text: fence.joined(separator: "\n")))
                fence = []
                inFence = false
            } else {
                inFence = true
            }
            continue
        }
        if inFence {
            fence.append(line)
            continue
        }

        if trimmed == ":::columns" {
            flushTable()
            inCols = true
            colGroups = []
            colFence = false
            continue
        }

        // A `|` line joins the table being collected; anything else ends it.
        if regexGroups(#"^\s*\|"#, line) != nil {
            tableBuf.append(line)
            continue
        }
        flushTable()

        // The one-line blocks, by their first characters.
        if let g = regexGroups(#"^(#{1,3})\s+(.*)$"#, line) {
            let kind: NoteBlock.Kind = g[1].count == 1 ? .h1 : (g[1].count == 2 ? .h2 : .h3)
            out.append(NoteBlock(kind: kind, text: g[2]))
            continue
        }
        if let g = regexGroups(#"^[-*]\s+\[([ xX])\]\s*(.*)$"#, line) {
            out.append(NoteBlock(kind: .check, text: g[2], checked: g[1].lowercased() == "x"))
            continue
        }
        if let g = regexGroups(#"^[-*]\s+(.*)$"#, line) {
            out.append(NoteBlock(kind: .ul, text: g[1]))
            continue
        }
        if let g = regexGroups(#"^\d+\.\s+(.*)$"#, line) {
            out.append(NoteBlock(kind: .ol, text: g[1]))
            continue
        }
        if let g = regexGroups(#"^>\s?(.*)$"#, line) {
            out.append(NoteBlock(kind: .quote, text: g[1]))
            continue
        }
        out.append(NoteBlock(kind: .p, text: line))
    }

    // Whatever was still open at the end of the note renders as it stands.
    flushTable()
    if inFence { out.append(NoteBlock(kind: .code, text: fence.joined(separator: "\n"))) }
    if inCols { flushCols() }
    return out
}

/// Each block's number in its numbered list, from 1, or 0 for a block that
/// isn't a numbered item. The web's `<ol>` numbers a run of `1.` lines by
/// itself, whatever digits were typed, and any other kind of block ends it.
func listNumbers(_ blocks: [NoteBlock]) -> [Int] {
    var numbers: [Int] = []
    var count = 0
    for b in blocks {
        count = b.kind == .ol ? count + 1 : 0
        numbers.append(count)
    }
    return numbers
}

/// A table's rows with empty cells added, so every row is as wide as the
/// widest. renderBlocks does the same, so a short row still has its cells.
func tableGrid(_ rows: [[String]]) -> [[String]] {
    let width = max(rows.map(\.count).max() ?? 1, 1)
    return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
}

// MARK: - The inline dialect

/// `&`, `<`, `>` and `"` written as HTML entities, `&` first so the others'
/// own `&` isn't escaped twice. `escapeHtml` in lib/notes.ts.
func escapeHtml(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

/// The entities back as characters, `&amp;` last. The reverse of escapeHtml.
func unescapeHtml(_ s: String) -> String {
    s.replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&amp;", with: "&")
}

/// The address, trimmed, if it's `http(s)://` or `mailto:`; nil for anything
/// else (`javascript:` above all), which stays plain text. `safeHref`.
func safeHref(_ url: String) -> String? {
    let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.range(of: #"^(https?://|mailto:)"#, options: [.regularExpression, .caseInsensitive]) != nil
        ? t : nil
}

/// `[[red|text]]`, as in Notes.swift. (`private` there, so it's repeated.)
private let penMarker = #"\[\[("# + notePens.joined(separator: "|") + #")\|([\s\S]*?)\]\]"#

/// One line's inline markers as HTML, from text already put through
/// escapeHtml. `inlineToHtml` in lib/notes.ts, pass for pass:
/// backslash escapes and code spans are set aside first (their contents are
/// literal), then pens, links, bold, underline, highlight, italic, and the
/// set-aside pieces go back in. The tests compare its output with the web's.
func inlineToHtml(_ escaped: String) -> String {
    // Pieces set aside, each replaced by a marker no note can contain: the
    // characters U+0000 and U+0001 around its number.
    var stash: [String] = []
    func keep(_ html: String) -> String {
        stash.append(html)
        return "\u{0}\(stash.count - 1)\u{1}"
    }

    var s = replacingMatches(of: #"\\([\\*_=`\[\]])"#, in: escaped) { g in keep(g[1]) }
    s = replacingMatches(of: "`([^`]+)`", in: s) { g in keep("<code>\(g[1])</code>") }

    // A pen first: its words stay text, so a link or bold inside it still reads.
    s = replacingMatches(of: penMarker, in: s) { g in
        "<span data-note-color=\"\(g[1])\">\(g[2])</span>"
    }
    // A link only to a safe address; anything else stays exactly as typed.
    // The address is already escaped (the whole line was), so it goes in as
    // it stands: escaping it again turned `&` into `&amp;amp;` (D-39).
    s = replacingMatches(of: #"\[([^\]]*)\]\(([^)\s]*)\)"#, in: s) { g in
        guard let href = safeHref(g[2]) else { return g[0] }
        return "<a href=\"\(href)\" target=\"_blank\" rel=\"noreferrer noopener\">"
            + (g[1].isEmpty ? href : g[1]) + "</a>"
    }
    // Longest markers first: ** before *, so bold isn't read as two italics.
    s = s.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<b>$1</b>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"__([^_]+)__"#, with: "<u>$1</u>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"==([^=]+)=="#, with: "<mark>$1</mark>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(^|[^*])\*([^*]+)\*"#, with: "$1<i>$2</i>", options: .regularExpression)

    // The set-aside pieces back in. Twice, because a code span can hold an
    // escaped character's marker (the web, putting them back once, shows a
    // stray "0" there).
    let slot = #"\x{0}(\d+)\x{1}"#
    let restore: ([String]) -> String = { g in stash[Int(g[1]) ?? 0] }
    return replacingMatches(of: slot, in: replacingMatches(of: slot, in: s, with: restore), with: restore)
}

/// A stretch of a line in one style. The reader turns each into styled text.
struct InlineRun: Equatable {
    var text: String
    var bold = false
    var italic = false
    var underline = false
    var highlight = false
    var code = false
    /// A pen's name, "red" to "purple", or nil for the usual ink.
    var pen: String? = nil
    /// A safe address (safeHref), or nil when it isn't a link.
    var link: String? = nil
}

/// Reads inlineToHtml's HTML back as runs. Only its own tags can appear
/// (every other `<` was escaped), so a scan is enough: text collects until a
/// `<`, the tag collects until a `>`, and each tag turns a style on or off.
/// Counters rather than true/false, so `**a __b** c__` (whose tags cross)
/// still reads as the browser shows it.
func inlineRuns(_ html: String) -> [InlineRun] {
    var runs: [InlineRun] = []
    var bold = 0, italic = 0, underline = 0, highlight = 0, code = 0
    var pens: [String] = []
    var links: [String] = []
    var text = ""
    var tag = ""
    var inTag = false

    // The text so far becomes one run in the current style.
    func flush() {
        guard !text.isEmpty else { return }
        runs.append(InlineRun(text: unescapeHtml(text), bold: bold > 0, italic: italic > 0,
                              underline: underline > 0, highlight: highlight > 0, code: code > 0,
                              pen: pens.last, link: links.last))
        text = ""
    }
    // One tag, without its < and >: "b", "/b", "a href=\"…\" …".
    func apply(_ tag: String) {
        let closing = tag.hasPrefix("/")
        let body = closing ? String(tag.dropFirst()) : tag
        let name = String(body.prefix { $0 != " " })
        let step = closing ? -1 : 1
        switch name {
        case "b": bold += step
        case "i": italic += step
        case "u": underline += step
        case "mark": highlight += step
        case "code": code += step
        case "span":
            if closing {
                _ = pens.popLast()
            } else {
                pens.append(regexGroups(#"data-note-color="([a-z]+)""#, tag)?[1] ?? "")
            }
        case "a":
            if closing {
                _ = links.popLast()
            } else {
                links.append(unescapeHtml(regexGroups(#"href="([^"]*)""#, tag)?[1] ?? ""))
            }
        default:
            return
        }
    }

    for ch in html {
        if inTag {
            if ch == ">" {
                apply(tag)
                tag = ""
                inTag = false
            } else {
                tag.append(ch)
            }
        } else if ch == "<" {
            flush()
            inTag = true
        } else {
            text.append(ch)
        }
    }
    flush()
    return runs
}

/// One line of a note as styled runs: the three steps above in a row.
func noteRuns(_ line: String) -> [InlineRun] {
    inlineRuns(inlineToHtml(escapeHtml(line)))
}
```

### 4.2 `~/ClassPing/Sources/ClassPing/Design/Theme+Notes.swift` (new file)

The note's colors, beside the other theme files. Nothing here needs anything new.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Notes.swift
//  Phase:   8b (the reader)
//  Ports:   app/globals.css (the note pens --note-pen-*, the highlighter,
//           inline code --code-*, code blocks --code-block-*)
//
//  Summary: The colors a drawn note uses: the five pens, the highlighter,
//           and the two kinds of code. Each has a light and a dark shade,
//           like the rest of the theme.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade (Theme+Tasks.swift has the same
/// helper; `fileprivate` keeps each file's copy to itself).
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

/// A see-through color from 0 to 255 values, for the CSS `rgba(...)` tokens.
fileprivate func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> UIColor {
    UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

extension Theme {
    // MARK: The pens

    /// A pen's ink, by the name the note stores: deep on the light theme,
    /// lifted on the dark one, so it reads on either paper. Under a
    /// highlighter it's the deep shade in both themes, because the
    /// highlighter is pale in both. Nil for a name that isn't a pen.
    static func pen(_ name: String?, onHighlight: Bool = false) -> Color? {
        // (deep, lifted) for each pen, from --note-pen-*-deep and html.dark.
        let shades: (String, String)
        switch name {
        case "red":    shades = ("#B5382F", "#F0A79C")
        case "orange": shades = ("#A2621F", "#E2C28C")
        case "green":  shades = ("#456F3D", "#B6CDA5")
        case "blue":   shades = ("#365D7D", "#ADC3DB")
        case "purple": shades = ("#6D4E8C", "#C7B4DE")
        default:       return nil
        }
        return onHighlight
            ? Color(hex: shades.0)
            : shade(UIColor(hex: shades.0), UIColor(hex: shades.1))
    }

    // MARK: The highlighter

    /// The highlighter's yellow, the same in both themes, with its ink pinned
    /// dark: white text on yellow is not a highlight. `.note-body mark`.
    static let markBackground = Color(hex: "#FFF3A3")
    static let markInk = Color(hex: "#241D00")

    // MARK: Code

    /// `inline code`: a rose ink on a tinted chip. `--code-ink`, `--code-bg`.
    static let codeInk = shade(UIColor(hex: "#983C65"), UIColor(hex: "#E3A6BE"))
    static let codeBackground = shade(UIColor(hex: "#EADFE1"), rgba(201, 155, 174, 0.12))

    /// A fenced code block: an inset panel. `--code-block-*`.
    static let codeBlockInk = shade(UIColor(hex: "#4E4942"), UIColor(hex: "#DDD3CD"))
    static let codeBlockBackground = shade(UIColor(hex: "#E5E1D9"), UIColor(hex: "#211E24"))
    static let codeBlockBorder = shade(UIColor(hex: "#D4CDC1"), UIColor(hex: "#403840"))
}
```

### 4.3 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteReaderView.swift` (new file)

The drawing. It needs 4.1 and 4.2.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteReaderView.swift
//  Phase:   8b (the reader)
//  Ports:   components/NoteReader.tsx (a note drawn to read, not to type in)
//           and the .note-body styles in app/globals.css
//
//  Summary: A note drawn the way it's meant to be read: headings, paragraphs,
//           bullets, numbered lists, checkboxes, quotes, code, tables and
//           columns, with bold, italic, underline, highlight, the pens, code
//           and links inside the lines. Columns stack one under another, as
//           the web does on a phone. Text can be selected and copied, and a
//           link opens in Safari.
//

import SwiftUI

/// A note's markdown, drawn. Cut into blocks by NoteMarkdown.swift.
struct NoteReaderView: View {
    /// The note's text as stored. (Not `body`: that name is the view's own.)
    let markdown: String

    var body: some View {
        NoteBlocksView(blocks: parseBlocks(markdown))
    }
}

/// A run of blocks, top to bottom. A column holds a run of blocks too, so
/// this view draws a column block by putting more NoteBlocksViews inside
/// itself. A view may contain its own type like that, as long as each level
/// has fewer blocks to draw, so the nesting ends.
struct NoteBlocksView: View {
    @Environment(Store.self) private var store

    let blocks: [NoteBlock]

    var body: some View {
        // Each numbered item's number, worked out once for the whole run.
        let numbers = listNumbers(blocks)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks.indices, id: \.self) { i in
                block(blocks[i], number: numbers[i])
                    .padding(.top, i == 0 ? 0 : gap(blocks[i - 1].kind, blocks[i].kind))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - One block

    /// One block, drawn by its kind. The sizes are the web's: body 15.5,
    /// headings 26, 21 and 17.5, tables 14, code 13.
    @ViewBuilder
    private func block(_ b: NoteBlock, number: Int) -> some View {
        let accent = store.profile.accent
        switch b.kind {
        case .h1:
            line(b.text, size: 26, weight: .semibold, spacing: 2)
        case .h2:
            line(b.text, size: 21, weight: .semibold, spacing: 2)
        case .h3:
            line(b.text, size: 17.5, weight: .semibold, spacing: 2)
        case .p:
            line(b.text)
        case .ul:
            listItem(Text("•"), b.text)
        case .ol:
            listItem(Text("\(number).").monospacedDigit(), b.text)
        case .check:
            checkItem(b, accent)
        case .quote:
            // A brand rule down the left, in quieter ink.
            line(b.text, ink: Theme.muted)
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Theme.brand(accent)).frame(width: 3)
                }
        case .code:
            codeBlock(b.text, accent)
        case .table:
            table(b.rows)
        case .cols:
            columns(b.columns)
        }
    }

    /// One line of text with its inline styles, selectable. The extra line
    /// spacing is the web's `line-height: 1.65` for body text.
    private func line(_ text: String, size: CGFloat = 15.5, weight: Font.Weight = .regular,
                      ink: Color = Theme.ink, spacing: CGFloat = 6) -> some View {
        Text(styledLine(text, size: size, weight: weight, ink: ink,
                        link: Theme.brand(store.profile.accent)))
            .lineSpacing(spacing)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    /// A bullet or a number, then the item's line, lined up on the text.
    private func listItem(_ marker: Text, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            marker
                .font(.system(size: 15.5))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 16, alignment: .trailing)
            line(text)
        }
        .padding(.leading, 6)
    }

    /// A checkbox: the box is drawn, filled with the accent and a tick when
    /// done, and a done item's words go quieter. It can't be ticked here: the
    /// reader only reads, like the web's.
    private func checkItem(_ b: NoteBlock, _ accent: Profile.Accent) -> some View {
        let brand = Theme.brand(accent)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(b.checked ? brand : Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(b.checked ? brand : Theme.lineStrong, lineWidth: 1.8))
                .overlay {
                    if b.checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 16, height: 16)
                // A box has no text baseline; this says where its baseline
                // sits, so it lines up with the first line of the words.
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 3 }
            line(b.text, ink: b.checked ? Theme.muted2 : Theme.ink)
        }
        .padding(.leading, 2)
    }

    /// A fenced code block: monospaced and literal, on an inset panel with
    /// the accent down its left edge.
    private func codeBlock(_ text: String, _ accent: Profile.Accent) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Theme.codeBlockInk)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(.vertical, 10)
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.codeBlockBackground)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.brand(accent)).frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.codeBlockBorder, lineWidth: 1))
    }

    /// A table: the header row on a tinted strip, every cell boxed. `Grid`
    /// lines its cells up in rows and columns, sizing each column to its
    /// widest cell. A wide table scrolls sideways instead of squashing.
    private func table(_ rows: [[String]]) -> some View {
        let grid = tableGrid(rows)
        return ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(grid.indices, id: \.self) { r in
                    GridRow {
                        ForEach(grid[r].indices, id: \.self) { c in
                            tableCell(grid[r][c], header: r == 0)
                        }
                    }
                }
            }
            .overlay(Rectangle().strokeBorder(Theme.lineStrong, lineWidth: 0.5))
        }
    }

    /// One cell. Its text wraps past 220 points, and its box fills the row,
    /// so the lines between cells run the full height of the tallest one.
    private func tableCell(_ text: String, header: Bool) -> some View {
        Text(styledLine(text, size: 14, weight: header ? .semibold : .regular, ink: Theme.ink,
                        link: Theme.brand(store.profile.accent)))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 42, maxWidth: 220, alignment: .topLeading)
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(header ? Theme.surface2 : Color.clear)
            .overlay(Rectangle().strokeBorder(Theme.lineStrong, lineWidth: 0.5))
    }

    /// Columns, one under another as on the web's phone, a line between.
    /// Each column is its own run of blocks: a NoteBlocksView inside this one.
    private func columns(_ cols: [[NoteBlock]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(cols.indices, id: \.self) { i in
                if i > 0 {
                    Rectangle()
                        .fill(Theme.lineStrong)
                        .frame(height: 1)
                        .padding(.vertical, 9)
                }
                NoteBlocksView(blocks: cols[i])
            }
        }
    }
}

// MARK: - Inline styles

/// One line's runs as one `AttributedString`: text where each stretch keeps
/// its own font, color, underline, highlight and link, all shown by a single
/// `Text`. The web's `<b>`, `<mark>`, `<a>` and so on, as attributes.
func styledLine(_ line: String, size: CGFloat, weight: Font.Weight,
                ink: Color, link: Color) -> AttributedString {
    let runs = noteRuns(line)
    // A blank line still takes a line's height.
    guard !runs.isEmpty else { return AttributedString(" ") }

    var out = AttributedString()
    for run in runs {
        var piece = AttributedString(run.text)

        // The font: bold, or the line's own weight; code monospaced and a
        // little smaller (the web's 0.86em); italic on top of either.
        var font = Font.system(size: run.code ? size * 0.86 : size,
                               weight: run.bold ? .bold : weight,
                               design: run.code ? .monospaced : .default)
        if run.italic { font = font.italic() }
        piece.font = font

        // The ink: code's, a link's, a pen's (deep under a highlight), the
        // highlighter's own, or the line's.
        piece.foregroundColor = run.code ? Theme.codeInk
            : run.link != nil ? link
            : Theme.pen(run.pen, onHighlight: run.highlight) ?? (run.highlight ? Theme.markInk : ink)

        // What sits behind the words: the highlighter, or code's chip.
        if run.highlight {
            piece.backgroundColor = Theme.markBackground
        } else if run.code {
            piece.backgroundColor = Theme.codeBackground
        }

        // Underlined, and links too. `Text.LineStyle` names SwiftUI's kind of
        // underline (UIKit has one of its own with the same name).
        if run.underline || run.link != nil {
            piece.underlineStyle = Text.LineStyle(pattern: .solid)
        }
        // A link Text can open: tapping it hands the address to Safari or Mail.
        if let address = run.link, let url = URL(string: address) {
            piece.link = url
        }
        out += piece
    }
    return out
}

// MARK: - Spacing

/// The space between two blocks, from the web's CSS margins. Where two
/// margins meet, the larger wins, as in CSS; items of the same list sit close.
private func gap(_ above: NoteBlock.Kind, _ below: NoteBlock.Kind) -> CGFloat {
    let listKinds: [NoteBlock.Kind] = [.ul, .ol, .check]
    if above == below && listKinds.contains(above) { return 4 }
    return max(spaceBelow(above), spaceAbove(below))
}

/// The margin above a block, in points (the em sizes times the font size).
private func spaceAbove(_ kind: NoteBlock.Kind) -> CGFloat {
    switch kind {
    case .h1: 28
    case .h2: 21
    case .h3: 16
    case .quote: 8
    case .code, .table: 9
    case .cols: 11
    case .p, .ul, .ol, .check: 0
    }
}

/// The margin below a block.
private func spaceBelow(_ kind: NoteBlock.Kind) -> CGFloat {
    switch kind {
    case .h1: 10
    case .h2: 7
    case .h3: 5
    case .p: 8
    case .ul, .ol, .check, .quote, .code, .table: 9
    case .cols: 11
    }
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift` (replaces the file)

Four touched spots: the header; `NoteView` itself (the `dismiss` line, `editing`, the reading-or-typing switch with its Edit / Done button, and the new `reader` function); the keyboard bar's Done, gone; and `.onAppear` in the editor, which now always brings the keyboard up. `NoteEditorView`'s typing and saving are as you typed them in 8a.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Notes/NoteView.swift
//  Phase:   8a (notes you can write and find), changed in 8b (read first)
//  Ports:   NotePane in app/classes/page.tsx (the title, "class · day", the
//           bin), the saving half of components/NoteEditor.tsx (save half
//           a second after you stop typing, "Saving…" / "Saved", the 20,000
//           character limit and New page), and since 8b the phone's view
//           of a note, components/NoteReader.tsx
//
//  Summary: One note. A note with words in it opens to read, drawn by
//           NoteReaderView; Edit switches to typing it as plain markdown, and
//           Done goes back to reading (D-37). An empty note opens straight
//           for typing. Typing saves by itself a moment after you stop, when
//           you leave, and when the app goes to the background.
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

    var body: some View {
        if let note = store.note(noteID) {
            // CHANGED in Phase 8b: reading or typing.
            let typing = editing ?? (note.title.isEmpty && note.body.isEmpty)
            Group {
                if typing {
                    NoteEditorView(note: note)
                } else {
                    reader(note)
                }
            }
            .toolbar {
                // Edit to type, Done to read again. Leaving the editor saves
                // it on the way out (its `.onDisappear`).
                ToolbarItem(placement: .topBarTrailing) {
                    Button(typing ? "Done" : "Edit") { editing = !typing }
                        .font(.system(size: 16, weight: .semibold))
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
                Text(noteTitle(title: note.title, body: note.body))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(course?.name ?? "Quick note") · \(dayLabel(note.date))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
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

    /// What's typed, which can run ahead of what's saved by half a second.
    @State private var title: String
    @State private var text: String

    /// The note started by New page, while it's open.
    @State private var nextPage: UUID?

    /// Which field has the keyboard, or nil for none. `@FocusState` is
    /// `@State` for the keyboard: set it to move the caret, set it to nil to
    /// put the keyboard away.
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    init(note: Note) {
        self.note = note
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.body)
    }

    var body: some View {
        let course = store.course(note.courseID)
        let length = noteLength(text)
        let full = !fitsBudget(length)
        // Saved when the store holds exactly what's on screen.
        let saved = store.note(note.id).map { $0.title == title && $0.body == text } ?? false

        VStack(spacing: 0) {
            // MARK: Title, and where the note lives
            VStack(alignment: .leading, spacing: 2) {
                // The grey text is what the list would call it untitled.
                TextField(noteTitle(title: "", body: text), text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .title)
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
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .body)
                    // Let the canvas show through instead of a white box.
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
            }

            // MARK: Saving
            // "Saving…" until the store has it, then "Saved". Near the limit,
            // the count and New page, so a long lecture goes on in a new note
            // instead of stopping at the ceiling.
            HStack(spacing: 10) {
                Text(full ? "This note is full, start a new page to keep writing"
                          : (saved ? "Saved" : "Saving…"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if length > maxNoteChars * 9 / 10 {
                    Text("\(length.formatted()) / \(maxNoteChars.formatted())")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(full ? Theme.dangerInk : Theme.warnInk)
                    Button("New page") {
                        save()
                        nextPage = store.addNote(courseID: note.courseID, date: note.date,
                                                 assignmentID: note.assignmentID)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }
        }
        .background(Theme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete goes straight back, where the Undo bar is waiting.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.deleteNote(note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
            // CHANGED in Phase 8b: the keyboard bar's Done is gone. Done at
            // the top (NoteView) now puts the keyboard away and shows the
            // note drawn. Phase 8c puts the formatting buttons on that bar.
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
        // CHANGED in Phase 8b: the editor only opens when you mean to type
        // (a new note, or Edit), so the keyboard always comes up.
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

    /// Hands the store what's on screen. Past the limit, the title still
    /// saves and the body waits until it fits again, so nothing is cut off.
    private func save() {
        let fits = fitsBudget(noteLength(text))
        store.updateNote(note.id, title: title, body: fits ? text : nil)
    }
}
```

### Not typed: the tests

`NoteMarkdownTests.swift` is in `docs/ios/reference/Tests/Logic/` (31 tests). To run it with your own script:

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/NoteMarkdownTests.swift Tests/Logic/
scripts/test-logic.sh
```

No script changes: the new file is in `Logic/`, which both scripts copy whole.

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
git add -A && git commit -m "Phase 8b: the reader"
```

On the phone:

1. **Read.** Open 8a's "Ping note" (`# Cells`, `- mitochondria`). It opens drawn: "Cells" as a big heading, a bullet under it, and no keyboard.
2. **Edit.** Tap **Edit**: the keyboard comes up on the markdown. Add these lines at the end, one per line:
   - `**bold**, *italic*, __underlined__ and ==marked==`
   - `[[red|in red]] and [[blue|in blue]]`
   - `1. first` and `1. second` (two lines)
   - `- [ ] flashcards` and `- [x] lecture` (two lines)
   - `> a quote`
   - `` `ATP` `` and `[the book](https://openstax.org)`
3. **Done.** Tap **Done**: each line drawn. The numbers read 1 and 2 (you typed 1 twice), the ticked box is filled with your accent and its words are quieter, the quote has a rule down its left.
4. **A link.** Tap "the book": Safari opens openstax.org. Come back to ClassPing.
5. **A table and code.** Edit again and add `| Part | Job |`, `| --- | --- |`, `| Nucleus | DNA |`, then three lines: ` ``` `, `print("hi")`, ` ``` `. Done: a two-column grid with a tinted header, and a grey code panel. Take the `| --- | --- |` line out and the three table lines show as plain text: no ruler, no table, as on the web.
6. **Copy.** Long-press a word in the drawn note: it selects, and Copy works.
7. **Dark mode.** Profile → Appearance → Dark, open the note: the pens lighten so they read on charcoal, the highlight stays yellow with dark ink.
8. **A new note still types.** Quick note: it opens with the keyboard, not the reader. Type a line, tap **Done**: drawn. Delete it.

## 6. Done when

- [ ] `xtool dev build` has no warnings.
- [ ] A note with words opens drawn, with no keyboard; an empty one opens for typing.
- [ ] Edit and Done switch between the two, and nothing typed is lost on the way.
- [ ] Headings, bullets, numbers (counted from 1), checkboxes, quotes, code, tables and columns all draw.
- [ ] Bold, italic, underline, highlight, the pens, `code` and links show inside lines, and links open.
- [ ] Dark mode keeps every color readable.

## 7. If it breaks

- **`cannot find 'tableCells' in scope`** (or `isTableRuler`, `notePens`): 8a's `Logic/Notes.swift` isn't in your tree; the reader builds on it.
- **`invalid redeclaration of 'body'`** in `NoteReaderView`: the note's text is `markdown`. `body` is the name SwiftUI gives the view's own content.
- **`ambiguous use of 'single'`** (or of `underlineStyle`): write `Text.LineStyle(pattern: .solid)`, as in 4.3, not `.single`. Both SwiftUI and UIKit have an underline type with that short name.
- **The note shows `**` and `==` instead of styles:** a line went to `Text` as a plain string. Each one must go through `styledLine` (which calls `noteRuns`).
- **Everything after a ` ``` ` line is grey code:** that's right while the fence is open, as on the web. Close it with a second ` ``` ` line.
- **A tapped link does nothing:** the address must start with `https://`, `http://` or `mailto:`; anything else stays plain text on purpose (`safeHref`).

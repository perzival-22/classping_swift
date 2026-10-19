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
    // Pieces set aside, each replaced by U+0000 and U+0001 around its
    // number. The restore step also tolerates pasted control characters.
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
    let restore: ([String]) -> String = { g in
        guard let index = Int(g[1]), stash.indices.contains(index) else { return g[0] }
        return stash[index]
    }
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

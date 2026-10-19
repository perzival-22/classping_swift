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
    // Already tidy or refused at the limit: no quadratic work for a long
    // note that comes back unchanged. No shared lines means all deletions
    // precede all additions, which is also the web's tie-breaking rule.
    if before == after { return a.map { DiffLine(kind: .same, text: $0) } }
    if Set(a).isDisjoint(with: Set(b)) {
        return a.map { DiffLine(kind: .del, text: $0) }
            + b.map { DiffLine(kind: .add, text: $0) }
    }
    let n = a.count
    let m = b.count

    // Only two rows of LCS lengths are needed at once. Keep each cell's
    // delete/add choice as a Bool for the walk below, instead of retaining
    // a whole matrix of Ints on the phone. Ties still prefer deletion.
    var deletes = Array(repeating: Array(repeating: false, count: m), count: n)
    var next = Array(repeating: 0, count: m + 1)
    for i in stride(from: n - 1, through: 0, by: -1) {
        var current = Array(repeating: 0, count: m + 1)
        for j in stride(from: m - 1, through: 0, by: -1) {
            if a[i] == b[j] {
                current[j] = next[j + 1] + 1
            } else {
                deletes[i][j] = next[j] >= current[j + 1]
                current[j] = deletes[i][j] ? next[j] : current[j + 1]
            }
        }
        next = current
    }

    var out: [DiffLine] = []
    var i = 0
    var j = 0
    while i < n && j < m {
        if a[i] == b[j] {
            out.append(DiffLine(kind: .same, text: a[i]))
            i += 1
            j += 1
        } else if deletes[i][j] {
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

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
                .accessibilityAddTraits(.isHeader)
        case .h2:
            line(b.text, size: 21, weight: .semibold, spacing: 2)
                .accessibilityAddTraits(.isHeader)
        case .h3:
            line(b.text, size: 17.5, weight: .semibold, spacing: 2)
                .accessibilityAddTraits(.isHeader)
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
                .accessibilityLabel(b.checked ? "Checked" : "Unchecked")
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
            .textSelection(.enabled)
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

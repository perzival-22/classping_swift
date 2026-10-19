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
        ScrollView(.horizontal, showsIndicators: false) {
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

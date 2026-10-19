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
        // An unchanged or over-budget tidy has no comparison to display.
        diff = tidy.changed ? lineDiff(source, tidy.body) : []
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

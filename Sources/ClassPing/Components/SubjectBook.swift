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

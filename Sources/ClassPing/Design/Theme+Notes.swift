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

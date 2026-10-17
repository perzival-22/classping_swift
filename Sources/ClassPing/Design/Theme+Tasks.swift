//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Tasks.swift
//  Phase:   4b (the Tasks screen)
//  Ports:   app/globals.css (--surface-2, --line-strong, the soft/ink status
//           pairs), lib/palette.ts (each subject color's dot, `bar`)
//
//  Summary: The extra tokens the Tasks screen needs: the class color dots,
//           the soft backgrounds and inks for Overdue / Exam / Quiz pills, and
//           two quieter surfaces. Added as an extension so Theme.swift stays as typed.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade. Theme.swift's own `dyn` is private to
/// that file, so this file has its own copy. `fileprivate` = only this file.
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

/// A see-through color from 0 to 255 values, for the dark-mode tokens that the
/// CSS writes as `rgba(...)` and a hex string can't express.
fileprivate func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> UIColor {
    UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

extension Theme {
    // Quieter surfaces. `--surface-2` (pill backgrounds) and `--line-strong`
    // (the empty completion circle).
    static let surface2 = shade(UIColor(hex: "#E5E1D9"), UIColor(hex: "#2D2930"))
    static let lineStrong = shade(UIColor(hex: "#C6BEAF"), rgba(228, 214, 204, 0.28))

    // Status pairs: a soft background and the ink that reads on it.
    // Overdue / due soon. `--danger-soft` and `--danger-ink`.
    static let dangerSoft = shade(UIColor(hex: "#F1DEDA"), rgba(211, 113, 98, 0.18))
    static let dangerInk  = shade(UIColor(hex: "#A83632"), UIColor(hex: "#F0A79C"))
    // The Exam badge. `--warn-soft` and `--warn-ink`.
    static let warnSoft = shade(UIColor(hex: "#EEE2C8"), rgba(217, 179, 108, 0.18))
    static let warnInk  = shade(UIColor(hex: "#886221"), UIColor(hex: "#E2C28C"))
    // The Quiz badge. `--info-soft` and `--info-ink`.
    static let infoSoft = shade(UIColor(hex: "#DCE5EB"), rgba(142, 169, 201, 0.18))
    static let infoInk  = shade(UIColor(hex: "#365D7D"), UIColor(hex: "#ADC3DB"))

    /// A class's dot color, from its stored name. `PALETTE[color].bar` in
    /// lib/palette.ts: one hex per color, readable on both light and dark.
    static func subject(_ color: SubjectColor) -> Color {
        switch color {
        case .amber:  Color(hex: "#D9B36C")
        case .indigo: Color(hex: "#8EA9C9")
        case .coral:  Color(hex: "#C99C8D")
        case .teal:   Color(hex: "#9FBB8A")
        case .pink:   Color(hex: "#C99BAE")
        case .violet: Color(hex: "#A99BC7")
        case .mint:   Color(hex: "#A4C1A0")
        case .ocean:  Color(hex: "#8BB6C6")
        case .slate:  Color(hex: "#98A4B5")
        }
    }
}

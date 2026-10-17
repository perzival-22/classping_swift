//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Courses.swift
//  Phase:   5a (the new tab bar and the week)
//  Ports:   app/globals.css (--subj-<color>-bg / -text / -sub in light and
//           dark, --color-muted-2, --color-coral)
//
//  Summary: The colors a class block needs on the week grid: a soft block for
//           each subject color, the ink that reads on it and a quieter second
//           ink. In light mode the block is a pastel; in dark it's a faint
//           wash of the class color, so it never looks like a hole in the page.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade, the same helper Theme+Tasks.swift
/// keeps. Each file needs its own copy because `fileprivate` hides it from
/// every other file.
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

/// The six hex values behind one subject color, straight from globals.css:
/// the dot (`bar`, which Theme.subject also returns), the light block and its
/// two inks, and the two dark inks. A tuple is a quick unnamed group of values;
/// naming each part (`bg:`, `text:`) lets callers read `t.bg` instead of `t.1`.
fileprivate func tones(_ c: SubjectColor)
    -> (bar: String, bg: String, text: String, sub: String, darkText: String, darkSub: String) {
    switch c {
    case .amber:  ("#D9B36C", "#EAE1CE", "#795B28", "#917441", "#E8D1A7", "#E1C289")
    case .indigo: ("#8EA9C9", "#DEE2E8", "#465C77", "#64778D", "#BBCBDF", "#A5BAD4")
    case .coral:  ("#C99C8D", "#EADFD8", "#805B4D", "#997869", "#DFC4BB", "#D4B0A4")
    case .teal:   ("#9FBB8A", "#E0E5D8", "#4C6540", "#6B805B", "#C5D6B9", "#B2C9A1")
    case .pink:   ("#C99BAE", "#EADDE2", "#81546A", "#996F83", "#DFC3CE", "#D4AFBE")
    case .violet: ("#A99BC7", "#E3DEEA", "#655581", "#827297", "#CBC3DD", "#BAAFD2")
    case .mint:   ("#A4C1A0", "#DFE6DC", "#4C6948", "#6B8565", "#C8DAC6", "#B6CDB3")
    case .ocean:  ("#8BB6C6", "#DCE5E7", "#426675", "#658591", "#B9D3DD", "#A2C5D1")
    case .slate:  ("#98A4B5", "#E0E2E5", "#505D70", "#707C8D", "#C1C8D3", "#ADB6C4")
    }
}

extension Theme {
    /// The block a class sits on. `--subj-<color>-bg`: a pastel in light mode,
    /// the class color at 18 % strength in dark.
    static func subjectSoft(_ c: SubjectColor) -> Color {
        let t = tones(c)
        return shade(UIColor(hex: t.bg), UIColor(hex: t.bar).withAlphaComponent(0.18))
    }

    /// The class name's ink on that block. `--subj-<color>-text`.
    static func subjectInk(_ c: SubjectColor) -> Color {
        let t = tones(c)
        return shade(UIColor(hex: t.text), UIColor(hex: t.darkText))
    }

    /// The quieter ink for the time under it. `--subj-<color>-sub`.
    static func subjectSub(_ c: SubjectColor) -> Color {
        let t = tones(c)
        return shade(UIColor(hex: t.sub), UIColor(hex: t.darkSub))
    }

    /// The small caps above the week title. `--color-muted-2`.
    static let muted2 = shade(UIColor(hex: "#797164"), UIColor(hex: "#B2A8A2"))

    /// The "now" line across today's column. `bg-coral`, one shade in both modes.
    static let nowLine = Color(hex: "#C99C8D")
}

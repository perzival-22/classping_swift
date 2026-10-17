//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Today.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   app/globals.css (--brand-soft, --good-ink)
//
//  Summary: The two tokens Today adds: the soft brand wash behind its pills
//           and buttons, and the green ink for "days clear". An extension, like
//           Theme+Tasks.swift, so the earlier Theme files stay as typed.
//

import SwiftUI
import UIKit

/// A color with a light and a dark shade. Each Theme file keeps its own copy,
/// because `fileprivate` hides it from every other file.
fileprivate func shade(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

extension Theme {
    /// The brand color, faint: the wash behind the "View all" and "Add" pills
    /// and the "Now" day pill. `--brand-soft` is the brand at 16 % strength in
    /// light mode and 22 % in dark, so it reads the same on both canvases.
    static func brandSoft(_ a: Profile.Accent) -> Color {
        // The brand's hex, the same two values `brand(_:)` in Theme.swift uses.
        let hex = a == .babypink ? "#E85D8A" : "#3B82C4"
        // `withAlphaComponent` makes a see-through copy of a UIColor.
        return shade(UIColor(hex: hex).withAlphaComponent(0.16),
                     UIColor(hex: hex).withAlphaComponent(0.22))
    }

    /// Green text for good news ("12 days clear"). `--good-ink`.
    static let goodInk = shade(UIColor(hex: "#456F3D"), UIColor(hex: "#B6CDA5"))
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Pills.swift
//  Phase:   13b+ (the profile banner and the theme pills)
//  Ports:   nothing. The web's Appearance card uses plain buttons
//           (app/settings/page.tsx); this is a look change on the phone
//           alone (D-88).
//
//  Summary: The four colors of the Appearance pills: Baby Pink, Ocean,
//           Light (cream) and Dark (charcoal). Each pill always wears its
//           own color, whichever one is chosen right now, so Ocean stays
//           blue while you're on Baby Pink. Each fill comes with the text
//           color that reads on it (4.5 : 1 or better, measured in D-88).
//

import SwiftUI

extension Theme {
    /// What one pill is made of: the color behind it and the color of the
    /// words (and the check mark) drawn on it.
    struct PillColors {
        /// The pill's own color.
        let fill: Color
        /// The text on it. Never `Theme.ink`: ink is a light-mode color, and
        /// on Baby Pink it only reaches 3.7 : 1.
        let text: Color
    }

    // MARK: App color pills

    /// Baby Pink: the brand pink with charcoal text. White on this pink is
    /// only 3.3 : 1 and `Theme.ink` 3.7 : 1; charcoal (#26232A) is 4.7 : 1.
    private static let pinkPill = PillColors(
        fill: Color(hex: "#E85D8A"), text: Color(hex: "#26232A"))

    /// Ocean: the deep end of the blue with white text (5.6 : 1). The brand
    /// blue (#3B82C4) fails both ways, 4.1 : 1 with white, 3.0 : 1 with
    /// charcoal, so the pill uses `brandDeep`'s shade.
    private static let oceanPill = PillColors(
        fill: Color(hex: "#2A6BA8"), text: .white)

    // MARK: Light and Dark pills

    /// Light: the web's cream surface with ink text (10.9 : 1).
    private static let creamPill = PillColors(
        fill: Color(hex: "#F5F3EF"), text: Color(hex: "#3A3530"))

    /// Dark: the warm charcoal with white text (15.5 : 1).
    private static let charcoalPill = PillColors(
        fill: Color(hex: "#26232A"), text: .white)

    /// The pill for one of the two app colors.
    static func accentPill(_ a: Profile.Accent) -> PillColors {
        switch a {
        case .babypink: pinkPill
        case .ocean:    oceanPill
        }
    }

    /// The pill for Light or Dark.
    static func themePill(_ t: Profile.Theme) -> PillColors {
        switch t {
        case .light: creamPill
        case .dark:  charcoalPill
        }
    }
}

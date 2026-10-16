//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme.swift
//  Phase:   3 (app shell)
//  Ports:   app/globals.css (the design tokens), lib/accents.ts (the two accents)
//
//  Summary: The app's look in one place: the colors, the two accents, the corner
//           radii and a card-surface modifier. Colors switch themselves between
//           light and dark, so a screen asks for `Theme.ink` and gets the right
//           shade for whichever mode the phone is in.
//
import SwiftUI
import UIKit

/// Build a Color from a hex string like "#E85D8A". The web app stores colors as
/// hex in globals.css; this is how the same values reach SwiftUI.
extension Color {
    init(hex: String) { self = Color(uiColor: UIColor(hex: hex)) }
}

extension UIColor {
    /// A UIColor from "#RRGGBB" (the leading # is optional). A malformed string
    /// falls back to mid-grey, so a typo shows up on screen instead of crashing.
    /// `scanHexInt64` returns a Bool, so there is no throwing call to wrap.
    convenience init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        let ok = Scanner(string: s).scanHexInt64(&v) && s.count == 6
        let r = ok ? Double((v >> 16) & 0xFF) / 255 : 0.5
        let g = ok ? Double((v >> 8) & 0xFF) / 255 : 0.5
        let b = ok ? Double(v & 0xFF) / 255 : 0.5
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

/// Every design token, grouped under one name so screens read `Theme.ink`,
/// `Theme.card`, `Theme.Radius.card`, and so on.
enum Theme {
    /// A color that resolves itself per mode. `light` and `dark` are hex strings.
    /// `UIColor(dynamicProvider:)` hands back the right one for the current trait,
    /// which SwiftUI updates whenever the color scheme (or our forced one) changes.
    private static func dyn(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Surfaces. `--color-canvas`, `--bg-card`, `--bg-outer` in globals.css.
    static let canvas = dyn("#EDEAE4", "#26232A")
    static let card   = dyn("#EDEAE4", "#26232A")
    static let outer  = dyn("#F5F3EF", "#211F24")

    // Text, darkest to faintest. `--color-ink` / `-muted` / `-faint` / `-hint`.
    static let ink   = dyn("#3A3530", "#FFFFFF")
    static let muted = dyn("#6B6458", "#C9C1BC")
    static let faint = dyn("#847B6D", "#A59994")
    static let hint  = dyn("#948B7E", "#928780")

    /// The hairline between rows. Opaque warm grey in light, a faint wash in dark.
    static let line = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.89, alpha: 0.12)
            : UIColor(hex: "#DCD6CB")
    })

    // Status colors (used from Phase 4 on). `--good` / `--danger` in globals.css.
    static let good   = dyn("#6F9C65", "#9FBB8A")
    static let danger = dyn("#C9514D", "#E88076")

    /// Corner radii. 15 is the app's most-used card radius (61 uses on the web).
    enum Radius {
        static let small: CGFloat = 13
        static let card: CGFloat = 15
        static let large: CGFloat = 18
        static let sheet: CGFloat = 24
    }
}

/// The accent colors. lib/accents.ts has exactly two; Baby Pink is the default.
/// Each returns the hue for the accent the student picked in their profile.
extension Theme {
    /// The main brand hue. `--color-brand`.
    static func brand(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: Color(hex: "#E85D8A")
        case .ocean:    Color(hex: "#3B82C4")
        }
    }
    /// The deep end of the brand gradient. `--color-brand-deep`.
    static func brandDeep(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: Color(hex: "#C43D6E")
        case .ocean:    Color(hex: "#2A6BA8")
        }
    }
    /// The bright end of the brand gradient. `--color-brand-bright`.
    static func brandBright(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: Color(hex: "#FF8FB0")
        case .ocean:    Color(hex: "#6BA8E0")
        }
    }
    /// The 135° brand gradient, bright to deep. `--brand-grad` in globals.css.
    static func brandGradient(_ a: Profile.Accent) -> LinearGradient {
        LinearGradient(colors: [brandBright(a), brandDeep(a)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A view modifier is a reusable style you attach with a method, the SwiftUI
/// answer to a shared CSS class. `.cardStyle()` is the app's card surface:
/// the card color, a 15pt rounded corner and a soft lift off the canvas.
extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}
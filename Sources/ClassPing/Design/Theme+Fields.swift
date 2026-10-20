//
//  File:    ~/ClassPing/Sources/ClassPing/Design/Theme+Fields.swift
//  Phase:   9b (asked for after the 9a phone check, D-54)
//  Ports:   the web's input wells (`--bg-input` in app/globals.css), here
//           washed in your accent, Baby Pink or Ocean.
//
//  Summary: One look for anything you type into: a soft accent well with
//           accent text and caret, so a filled-in value like 20% reads as
//           "change me" rather than a label. And a way to put the keyboard
//           away: swipe down the form, or tap Done above the keys.
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
    /// The text you type, in your accent. A shade darker than `brandDeep` in
    /// light mode and the bright end in dark, because those are the ones that
    /// stay readable (4.5 : 1 or better) on the accent well in both modes.
    static func fieldInk(_ a: Profile.Accent) -> Color {
        switch a {
        case .babypink: shade(UIColor(hex: "#A8305C"), UIColor(hex: "#FF8FB0"))
        case .ocean:    shade(UIColor(hex: "#245E94"), UIColor(hex: "#6BA8E0"))
        }
    }
}

extension View {
    /// The typing well. Put it on a TextField: accent text, an accent caret
    /// (`.tint` colors the caret and the selection) and the soft accent wash
    /// behind it, so the field looks like a field before you touch it.
    func inputField(_ accent: Profile.Accent) -> some View {
        self
            .foregroundStyle(Theme.fieldInk(accent))
            .tint(Theme.brand(accent))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.brandSoft(accent),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Lets the keyboard go, for a form whose buttons sit under it.
    /// `.scrollDismissesKeyboard(.interactively)` lets a swipe down the form
    /// drag the keyboard away with your finger, as in Messages. The number pad
    /// has no return key, so a Done button also rides on top of the keyboard:
    /// a toolbar item placed `.keyboard` appears only while it's up.
    func keyboardDismissable(_ done: @escaping () -> Void) -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: done)
                        .fontWeight(.semibold)
                }
            }
    }
}

//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/PillPicker.swift
//  Phase:   13b+ (the profile banner and the theme pills)
//  Ports:   nothing: the web's Appearance choices are plain buttons
//           (app/settings/page.tsx). A phone-only look change (D-88).
//
//  Summary: A row of round pills where you pick one. Every pill is filled
//           with the color it applies, so you see Baby Pink and Ocean (or
//           Light and Dark) side by side. The chosen pill gets a ring around
//           it and a check mark, so "selected" never depends on a color.
//

import SwiftUI

/// A row of pills that edits one value. `Value` is a stand-in for any type
/// that can be compared and hashed (the theme enum, the accent enum), so one
/// view serves both pickers. That is a generic type: the angle brackets name
/// the stand-in, and the compiler fills it in from the `selection` you pass.
struct PillPicker<Value: Hashable>: View {
    /// One pill: the value it sets, its words and its colors.
    struct Option: Identifiable {
        let value: Value
        let title: String
        let colors: Theme.PillColors
        /// `ForEach` needs a stable id; the value itself is one.
        var id: Value { value }
    }

    /// What VoiceOver calls the whole row ("Theme", "App color").
    let label: String
    /// Written to when a pill is tapped.
    @Binding var selection: Value
    let options: [Option]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { option in
                pill(option)
            }
        }
        // VoiceOver reads the label, then each pill inside it.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// One pill, drawn from the outside in: the words, the color behind them,
    /// a hairline edge, a gap, and (if chosen) the ring.
    private func pill(_ option: Option) -> some View {
        let chosen = option.value == selection
        return Button {
            selection = option.value
        } label: {
            HStack(spacing: 6) {
                // The check shows beside the words, so a chosen pill is
                // marked by a shape, not only by its ring.
                if chosen {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(option.colors.text)
            // 44 points tall at the least, the size of a comfortable tap.
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(option.colors.fill, in: Capsule())
            // `strokeBorder` draws inside the shape's edge (`stroke` would
            // straddle it). The hairline keeps the cream pill visible on the
            // cream card and the charcoal one on the dark card.
            .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
            // A 4-point gap of card color, then the ring around the gap.
            // Unchosen pills keep the same gap so nothing shifts on a tap.
            .padding(4)
            .overlay {
                if chosen {
                    Capsule().strokeBorder(Theme.ink, lineWidth: 2.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

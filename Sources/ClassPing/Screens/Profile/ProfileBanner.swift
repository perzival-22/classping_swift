//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileBanner.swift
//  Phase:   13b+ (the profile banner and the theme pills)
//  Ports:   nothing: the web's Profile card has no banner. A phone-only look
//           change, pure styling with nothing new stored (D-86).
//
//  Summary: The strip across the top of the Profile card. Behind it, your
//           photo blurred (or a gradient in your app color if you have no
//           photo yet); over that, a dark fade at the bottom so the words
//           stay readable on a bright photo; on top, your photo as a rounded
//           square, your name as plain text, and a pencil to edit the name.
//

import SwiftUI
import PhotosUI
// The SwiftUI half of PhotosUI, named by hand for xtool (see ProfileCard).
import _PhotosUI_SwiftUI
import UIKit

struct ProfileBanner: View {
    @Environment(Store.self) private var store

    /// The name to show on the banner. While you're typing it, that's the
    /// draft, so the banner follows your keystrokes.
    let name: String
    let accent: Profile.Accent
    /// True while the name field below the banner is open.
    let editing: Bool
    /// The pencil was tapped (or the check mark that replaces it).
    let onEdit: () -> Void
    /// The photo chosen in the library; ProfileCard reads and saves it.
    @Binding var picked: PhotosPickerItem?

    /// The decoded photo, or nil until it's ready (or if there is none).
    @State private var image: UIImage? = nil

    /// The banner is 150 points tall on every phone; the width is the card's.
    private let height: CGFloat = 150

    var body: some View {
        // Plain copies, read here: the picker's label below isn't drawn on
        // the main actor, where the store lives (the same care as Phase 11a).
        let shown = name
        let color = accent

        ZStack(alignment: .bottomLeading) {
            backdrop(color)
            scrim
            HStack(alignment: .bottom, spacing: 14) {
                PhotosPicker(selection: $picked, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        // A rounded square, not a rectangle (photos are cropped
                        // square) and not a circle (that stays the tab bar's).
                        AvatarBadge(name: shown, size: 88, accent: color, corner: 22)
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                            }
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Theme.brand(color), in: Circle())
                            .offset(x: 6, y: 6)
                    }
                }
                .accessibilityLabel("Change profile picture")

                // The name is text on the banner, not a field on a photo.
                Text(shown.isEmpty ? "Add your name" : shown)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white.opacity(shown.isEmpty ? 0.8 : 1))
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onEdit) {
                    Image(systemName: editing ? "checkmark" : "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel(editing ? "Done editing name" : "Edit name")
            }
            .padding(16)
        }
        .frame(height: height)
        // Only the top corners are rounded: the bottom meets the rest of
        // the card. `UnevenRoundedRectangle` takes one radius per corner.
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: Theme.Radius.card,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Theme.Radius.card,
            style: .continuous))
        // Decoded once per picture, not on every redraw (as AvatarPhoto does).
        .task(id: store.profile.avatarURL) {
            guard let uri = store.profile.avatarURL, uri.hasPrefix("data:image/") else {
                image = nil
                return
            }
            image = avatarImageData(uri).flatMap { UIImage(data: $0) }
        }
    }

    /// Behind everything: your photo blurred, or the brand gradient.
    @ViewBuilder
    private func backdrop(_ color: Profile.Accent) -> some View {
        if let image {
            // `Color.clear` takes the banner's size; the photo fills it,
            // cropped, then `blur` smears it. A blur fades at its own edges,
            // so the photo is scaled up 40% first and `clipped` trims the
            // overflow: no pale rim round the banner.
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 28)
                        .scaleEffect(1.4)
                }
                .clipped()
        } else {
            Theme.brandGradient(color)
        }
    }

    /// A dark fade over the lower half of the banner. It's clear in the top
    /// fifth, 60% black by the middle and 70% at the bottom, so white words
    /// in the lower half stay at 5.7 : 1 or better even over a pure white
    /// photo (D-86). The top of the photo stays visible.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.2),
                .init(color: .black.opacity(0.6), location: 0.5),
                .init(color: .black.opacity(0.7), location: 1)
            ],
            startPoint: .top, endPoint: .bottom)
    }
}

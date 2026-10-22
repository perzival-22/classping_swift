//
//  File:    ~/ClassPing/Sources/ClassPing/Components/AvatarLoader.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   the browser's `<img src={avatarUrl}>` in the web's avatar views,
//           which draws either kind of stored picture
//
//  Summary: Turns the profile's picture into an image, whichever way it's
//           stored: a `data:` address (a photo kept inside the profile) is
//           decoded on the phone, and an https address (one uploaded to the
//           web's storage) is downloaded once and remembered while the app
//           runs. Before 14e only the first kind showed; a photo set on the
//           web showed as initials.
//

import UIKit

/// The pictures, by address. `@MainActor` because the views ask from the
/// main thread and the downloaded pictures live in one dictionary.
@MainActor
enum AvatarLoader {
    /// Pictures already downloaded, by address, so a redraw or a second
    /// badge doesn't fetch again.
    private static var remembered: [String: UIImage] = [:]

    /// The picture for a stored address, or nil (no picture, an address the
    /// app doesn't draw, or no signal), in which case the initials stay.
    static func image(for address: String?) async -> UIImage? {
        guard let address else { return nil }
        // A picture inside the profile is decoded each time it changes; it's
        // already on the phone, so there's nothing to save by remembering it.
        if address.hasPrefix("data:image/") {
            return avatarImageData(address).flatMap { UIImage(data: $0) }
        }
        guard address.hasPrefix("https://"), let url = URL(string: address) else { return nil }
        if let known = remembered[address] { return known }
        // `try?` makes a failed download nil. `.0` is the bytes.
        let found = (try? await URLSession.shared.data(from: url)).flatMap { UIImage(data: $0.0) }
        if let found { remembered[address] = found }
        return found
    }

    /// Keeps a picture under an address without downloading it: after an
    /// upload the phone already has the photo it sent.
    static func remember(_ image: UIImage, for address: String) {
        remembered[address] = image
    }
}

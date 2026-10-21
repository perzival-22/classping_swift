//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Avatar.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   lib/avatar.ts (the limits, `isPersistableAvatar`, the error
//           messages) and the `initials` line of app/settings/page.tsx
//
//  Summary: The rules for your profile picture, Foundation only. A photo is
//           kept the way the web keeps one before it's uploaded: as a small
//           JPEG written into the profile itself as a `data:` address, so it
//           survives a relaunch, travels in a backup, and syncs later (D-65).
//

import Foundation

/// The stored picture is a square this many pixels on a side. `SIZE`.
let AVATAR_SIZE = 256
/// Pictures bigger than this aren't even opened. `MAX_INPUT_BYTES`.
let AVATAR_MAX_INPUT_BYTES = 12 * 1024 * 1024
/// The longest `data:` address allowed, about 180 KB of picture: it rides in
/// planner.json and, later, in every sync. `MAX_ENCODED_CHARS`.
let AVATAR_MAX_ENCODED_CHARS = 240_000
/// JPEG qualities to try, best first, until one fits. `QUALITY_STEPS`.
let AVATAR_QUALITY_STEPS: [Double] = [0.82, 0.7, 0.55, 0.4]

/// What can go wrong picking a picture. `AvatarError`.
enum AvatarProblem: Error, Equatable {
    case notAnImage, tooLarge, decodeFailed

    /// What the screen says. `avatarErrorMessage` on the web.
    var message: String {
        switch self {
        case .notAnImage: "That file isn't an image."
        case .tooLarge: "That image is too large, try a smaller one."
        case .decodeFailed: "Couldn't read that image. Try another."
        }
    }
}

/// Up to two letters for the round badge: the first letter of the first two
/// parts of your name, split at dots, spaces, underscores and dashes.
/// "kelvin.m" -> "KM", "Kelvin" -> "K". The web's `initials`; the web shows
/// "?" for no name, the phone keeps 5a's person symbol, so this gives "".
func avatarInitials(_ name: String) -> String {
    // Empty parts are kept, as JavaScript's `split` keeps them: "kelvin  m"
    // (two spaces) is ["kelvin", "", "m"], whose first two give just "K".
    let parts = name.split(omittingEmptySubsequences: false,
                           whereSeparator: { ".-_".contains($0) || $0.isWhitespace })
    return parts.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
}

/// True for a saved picture that can still be shown after a relaunch: a
/// `data:image/` address, or an https link (an upload, once sync exists).
/// The web's old `blob:` addresses are dead by then. `isPersistableAvatar`.
func isPersistableAvatar(_ url: String?) -> Bool {
    guard let url else { return false }
    return url.hasPrefix("data:image/") || url.hasPrefix("https://")
}

/// A JPEG as the `data:` address the profile stores, the web's
/// `canvas.toDataURL("image/jpeg")`. Nil when it's longer than the limit.
func avatarDataURI(jpeg: Data) -> String? {
    let uri = "data:image/jpeg;base64," + jpeg.base64EncodedString()
    return uri.count <= AVATAR_MAX_ENCODED_CHARS ? uri : nil
}

/// The picture's bytes back out of a stored `data:image/…;base64,` address,
/// or nil for anything else (an https link waits for sync).
func avatarImageData(_ url: String?) -> Data? {
    guard let url, url.hasPrefix("data:image/"),
          let comma = url.firstIndex(of: ",") else { return nil }
    return Data(base64Encoded: String(url[url.index(after: comma)...]))
}

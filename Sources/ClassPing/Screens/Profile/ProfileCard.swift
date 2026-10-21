//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileCard.swift
//  Phase:   11a (settings: you, the look, grading and the term)
//  Ports:   the Profile card of app/settings/page.tsx and the picture
//           handling of lib/avatar.ts (`fileToAvatarDataUrl`)
//
//  Summary: Your picture and your name. Tap the picture to choose a photo:
//           it's cropped to a square, shrunk to 256 pixels and kept in your
//           profile, on the phone, until sync can upload it (D-65). The name
//           saves when you leave the field. Both save as you go (D-68).
//

import SwiftUI
import PhotosUI
// The SwiftUI half of PhotosUI (`PhotosPicker`). Xcode adds this one by
// itself when a file imports both SwiftUI and PhotosUI; xtool's build
// doesn't, so it's named here (D-65).
import _PhotosUI_SwiftUI
import UIKit

struct ProfileCard: View {
    @Environment(Store.self) private var store

    /// The photo chosen in the picker, until it's been read and saved.
    @State private var picked: PhotosPickerItem? = nil
    /// The name as typed; saved when the field loses focus.
    @State private var name = ""
    @FocusState private var typing: Bool
    /// What went wrong with the last photo or save, in words, or nil.
    @State private var problem: String? = nil

    var body: some View {
        let accent = store.profile.accent
        // Read here, not inside the picker's label: that label isn't drawn
        // on the main actor, where the store lives, so it gets a plain copy.
        let username = store.profile.username

        VStack(spacing: 14) {
            Text("PROFILE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            // The picture is the button. `PhotosPicker` opens your photo
            // library; what you choose arrives in `picked`.
            PhotosPicker(selection: $picked, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarBadge(name: username, size: 90, accent: accent)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.brand(accent), in: Circle())
                }
            }
            .accessibilityLabel("Change profile picture")

            if let problem {
                Text(problem)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
            } else {
                Text("Tap to change photo")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            // Back to initials. The web has no way to do this; it's one button.
            if store.profile.avatarURL != nil {
                Button("Remove photo") {
                    problem = store.setAvatar(nil) ? nil : "Couldn't save on this device. Try again."
                }
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("USERNAME")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.faint)
                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                    .inputField(accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .onAppear { name = store.profile.username }
        // Leaving the field saves it, as the web saves the term name on blur.
        .onChange(of: typing) { _, isTyping in
            if !isTyping { saveName() }
        }
        // A new pick: read it, shrink it, save it. `.task(id:)` cancels the
        // last one if you pick again before it finishes.
        .task(id: picked) {
            guard let item = picked else { return }
            await use(item)
            // Cleared, so choosing the same photo again still counts as new.
            picked = nil
        }
    }

    /// Saves the typed name. A blank one goes back to the saved name.
    private func saveName() {
        if store.setUsername(name) {
            name = store.profile.username
            problem = nil
        } else {
            problem = "Couldn't save on this device. Try again."
        }
    }

    /// Reads the chosen photo, turns it into the profile's `data:` address and
    /// saves it. `loadTransferable` asks the photo library for the bytes;
    /// `try?` turns a failure into nil.
    private func use(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            problem = AvatarProblem.decodeFailed.message
            return
        }
        switch avatarURI(from: data) {
        case .success(let uri):
            problem = store.setAvatar(uri) ? nil : "Couldn't save on this device. Try again."
        case .failure(let reason):
            problem = reason.message
        }
    }
}

/// A picked photo as the profile's picture: cropped to its middle square,
/// scaled to 256 pixels, laid on white (JPEG has no transparency), then
/// saved as JPEG at the best quality that fits the size limit. The web's
/// `fileToAvatarDataUrl`. `Result` carries either the address or the reason.
@MainActor
func avatarURI(from data: Data) -> Result<String, AvatarProblem> {
    guard data.count <= AVATAR_MAX_INPUT_BYTES else { return .failure(.tooLarge) }
    guard let image = UIImage(data: data) else { return .failure(.notAnImage) }
    let side = min(image.size.width, image.size.height)
    guard side > 0 else { return .failure(.decodeFailed) }

    // A renderer draws into a fresh picture of a fixed size. Scale 1 means
    // 256 real pixels, not 256 points times the screen's density.
    let size = CGFloat(AVATAR_SIZE)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
    // Scaled so the short side is 256, centered, so the overflow is cropped evenly.
    let scale = size / side
    let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let frame = CGRect(x: (size - drawn.width) / 2, y: (size - drawn.height) / 2,
                       width: drawn.width, height: drawn.height)

    for quality in AVATAR_QUALITY_STEPS {
        let jpeg = renderer.jpegData(withCompressionQuality: quality) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            image.draw(in: frame)
        }
        if let uri = avatarDataURI(jpeg: jpeg) { return .success(uri) }
    }
    // Even the lowest quality is too big: refuse rather than bloat the planner.
    return .failure(.tooLarge)
}

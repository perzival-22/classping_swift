//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ProfileCard.swift
//  Phase:   11a (settings: you, the look, grading and the term), changed in
//           13b+ (the banner) and 14e (the upload)
//  Ports:   the Profile card of app/settings/page.tsx and the picture
//           handling of lib/avatar.ts (`fileToAvatarDataUrl`, and from 14e
//           `uploadAvatar`)
//
//  Summary: Your picture and your name, under a banner. Tap the picture to
//           choose a photo: it's cropped to a square and shrunk to 256
//           pixels. Signed in (14e), it's uploaded to the web's storage and
//           the profile keeps its short address; signed out, or if the
//           upload doesn't work, it's kept inside your profile (D-65,
//           D-105). The name shows as text on the banner; the pencil opens a
//           field below it to change it (D-86). The name saves when you leave
//           the field. Both save as you go (D-68).
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
    // NEW in Phase 14e: signed in, a new photo is uploaded.
    @Environment(SyncEngine.self) private var sync

    /// The photo chosen in the picker, until it's been read and saved.
    @State private var picked: PhotosPickerItem? = nil
    /// The name as typed; saved when the field loses focus.
    @State private var name = ""
    @FocusState private var typing: Bool
    /// NEW in Phase 13b+: true while the name field is open under the banner.
    @State private var editing = false
    /// What went wrong with the last photo or save, in words, or nil.
    @State private var problem: String? = nil
    /// NEW in Phase 14e: true while a new photo is uploading.
    @State private var uploading = false

    var body: some View {
        let accent = store.profile.accent
        // CHANGED in Phase 13b+: while the field is open the banner shows what
        // you're typing; otherwise it shows the saved name.
        let shown = editing ? name.trimmingCharacters(in: .whitespaces)
                            : store.profile.username

        // Spacing 0: the banner runs edge to edge, so the card's padding
        // moves to the part under it.
        VStack(spacing: 0) {
            // NEW in Phase 13b+: the banner replaces the old "PROFILE" label
            // and the centered round picture.
            ProfileBanner(name: shown, accent: accent, editing: editing,
                          onEdit: toggleEditing, picked: $picked)

            VStack(spacing: 10) {
                if let problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.danger)
                } else {
                    // CHANGED in Phase 14e: says so while a photo uploads.
                    Text(uploading ? "Saving your photo…" : "Tap your photo to change it")
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

                // NEW in Phase 13b+: the field only exists while you're
                // editing, so the card is just the banner the rest of the time.
                if editing {
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
                            .onSubmit { typing = false }
                            .inputField(accent)
                            // The field appears when you tap the pencil, so
                            // it takes the keyboard as it arrives.
                            .onAppear { typing = true }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .onAppear { name = store.profile.username }
        // Leaving the field saves it, as the web saves the term name on blur,
        // and closes the field. CHANGED in Phase 13b+: it also closes it.
        .onChange(of: typing) { _, isTyping in
            if !isTyping && editing {
                saveName()
                editing = false
            }
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

    /// The banner's pencil (or its check mark). Open: show the field with the
    /// saved name in it. Closed: put the keyboard away, which saves the name
    /// through `onChange(of: typing)` above. NEW in Phase 13b+.
    private func toggleEditing() {
        if editing {
            typing = false
        } else {
            name = store.profile.username
            editing = true
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
            // NEW in Phase 14e: signed in, upload first and keep the short
            // address, as the web's `uploadAvatar` does before it saves; on
            // any failure the photo stays inside the profile as before.
            var toSave = uri
            if sync.account.userID != nil {
                uploading = true
                if let url = await WebAPI.uploadAvatar(uri) {
                    toSave = versionedAvatarURL(url, at: .now)
                    // The phone already has this photo; no need to download it back.
                    if let image = avatarImageData(uri).flatMap({ UIImage(data: $0) }) {
                        AvatarLoader.remember(image, for: toSave)
                    }
                }
                uploading = false
            }
            problem = store.setAvatar(toSave) ? nil : "Couldn't save on this device. Try again."
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

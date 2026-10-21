// AvatarTests.swift: the profile picture rules (lib/avatar.ts) and the
// badge's initials (the `initials` line of app/settings/page.tsx).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@Suite struct AvatarTests {
    @Test func initialsTakeTheFirstLetterOfTheFirstTwoParts() {
        #expect(avatarInitials("kelvin.m") == "KM")
        #expect(avatarInitials("Kelvin") == "K")
        #expect(avatarInitials("ada_lovelace-byron") == "AL")
        #expect(avatarInitials("grace hopper") == "GH")
        #expect(avatarInitials("ünal") == "Ü")
    }

    /// JavaScript's split keeps empty parts, and so does this.
    @Test func emptyPartsCountAsParts() {
        #expect(avatarInitials("kelvin  m") == "K")
        #expect(avatarInitials(".kelvin") == "K")
        #expect(avatarInitials("") == "")
    }

    @Test func onlyAddressesThatSurviveARelaunchArePersistable() {
        #expect(isPersistableAvatar("data:image/jpeg;base64,AAAA"))
        #expect(isPersistableAvatar("https://blob.vercel-storage.com/a.jpg"))
        #expect(!isPersistableAvatar("blob:https://classping.app/1234"))
        #expect(!isPersistableAvatar("http://example.com/a.jpg"))
        #expect(!isPersistableAvatar(nil))
    }

    @Test func aJpegBecomesADataAddressUpToTheLimit() {
        #expect(avatarDataURI(jpeg: Data([1, 2, 3])) == "data:image/jpeg;base64,AQID")
        // 179,982 bytes are 239,976 base64 characters: 239,999 with the prefix.
        #expect(avatarDataURI(jpeg: Data(count: 179_982))?.count == 239_999)
        // Three more bytes are four more characters, over 240,000.
        #expect(avatarDataURI(jpeg: Data(count: 179_985)) == nil)
    }

    @Test func storedPicturesDecodeBackToTheirBytes() {
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let uri = avatarDataURI(jpeg: bytes)
        #expect(avatarImageData(uri) == bytes)
        #expect(avatarImageData("https://blob.vercel-storage.com/a.jpg") == nil)
        #expect(avatarImageData("data:image/jpeg;base64,not base64!") == nil)
        #expect(avatarImageData(nil) == nil)
    }

    @Test func theMessagesAreTheWebsOwn() {
        #expect(AvatarProblem.notAnImage.message == "That file isn't an image.")
        #expect(AvatarProblem.tooLarge.message == "That image is too large, try a smaller one.")
        #expect(AvatarProblem.decodeFailed.message == "Couldn't read that image. Try another.")
    }

    @Test func theLimitsMatchLibAvatar() {
        #expect(AVATAR_SIZE == 256)
        #expect(AVATAR_MAX_INPUT_BYTES == 12 * 1024 * 1024)
        #expect(AVATAR_MAX_ENCODED_CHARS == 240_000)
        #expect(AVATAR_QUALITY_STEPS == [0.82, 0.7, 0.55, 0.4])
    }
}

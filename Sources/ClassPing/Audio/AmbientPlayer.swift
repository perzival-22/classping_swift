//
//  File:    ~/ClassPing/Sources/ClassPing/Audio/AmbientPlayer.swift
//  Phase:   10b (ambient sound)
//  Ports:   the playback half of lib/ambient.ts (`ambienceUrl` and its cache)
//           and the <audio> element and Media Session code in
//           components/StudyTimer.tsx
//
//  Summary: Plays a study session's sound on a loop, carries on with the
//           screen locked (the app declares background audio in Info.plist),
//           and puts the session on the lock screen with play and pause
//           buttons that pause and resume the timer itself.
//

import AVFoundation
import MediaPlayer

/// One player for the timer screen. A plain class kept in the screen's
/// `@State`, so it lives as long as the sheet and never redraws anything.
@MainActor
final class AmbientPlayer {
    /// Each sound's WAV file, made the first time it's asked for and kept,
    /// like the web's `cache`. About 960 KB each.
    private var loops: [AmbienceID: Data] = [:]
    /// What's playing now, if anything, and which sound it is.
    private var player: AVAudioPlayer?
    private var playing: AmbienceID?

    /// The loop for `id`, built now if it hasn't been. The timer calls this
    /// when you pick a sound, so Start doesn't wait for it.
    @discardableResult
    func prepare(_ id: AmbienceID) -> Data {
        if let loop = loops[id] { return loop }
        let loop = encodeWav(synthesize(id))
        loops[id] = loop
        return loop
    }

    /// Plays `id` on repeat, starting it if it isn't the sound already loaded.
    func play(_ id: AmbienceID) {
        if player == nil || playing != id {
            player?.stop()
            // The audio session tells iOS what kind of sound this is.
            // `.playback` means "keep playing with the screen locked or the
            // ringer switch on silent", which needs UIBackgroundModes: audio
            // in Info.plist. `try?`: if iOS refuses, the timer runs silently.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
            player = try? AVAudioPlayer(data: prepare(id))
            player?.numberOfLoops = -1     // forever
            player?.volume = 0.55          // the web's level
            playing = id
        }
        player?.play()
    }

    /// Holds the sound where it is, for Pause.
    func pause() {
        player?.pause()
    }

    /// Ends playback and takes the session off the lock screen.
    func stop() {
        player?.stop()
        player = nil
        playing = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        // Lets music you were playing before carry on.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// What the lock screen shows: the block, the round, and whether it's
    /// running. The web's `navigator.mediaSession.metadata`. A rate of 1 means
    /// playing, 0 paused, which is how the lock screen picks its button.
    func showNowPlaying(title: String, detail: String, running: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: detail,
            MPMediaItemPropertyAlbumTitle: "ClassPing",
            MPNowPlayingInfoPropertyPlaybackRate: running ? 1.0 : 0.0,
        ]
    }

    /// Wires the lock screen's (and headphones') play and pause buttons to
    /// the timer. The web's `setActionHandler("play" / "pause")`. iOS calls
    /// these handlers on its own terms, so each one hops to the main actor
    /// with `Task { @MainActor in }` (7c) before touching the timer.
    func listen(play: @escaping @MainActor () -> Void, pause: @escaping @MainActor () -> Void) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        _ = center.playCommand.addTarget { _ in
            Task { @MainActor in play() }
            return .success
        }
        _ = center.pauseCommand.addTarget { _ in
            Task { @MainActor in pause() }
            return .success
        }
    }

    /// Unhooks the buttons again when the timer closes.
    func stopListening() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
    }
}

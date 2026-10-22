---
title: "Phase 10b: Ambient sound"
date: 2026-10-20
---

# Phase 10b: Ambient sound

Second and last part of Phase 10. It builds on your typed 10a: your staged
files are identical to the 10a reference, your suites passed 392/392 and
82/82, and on 2026-10-20 you confirmed every 10a check on the phone,
including the alert with the phone locked.

**Before you type anything: commit 10a** (`git commit -m "phase 10a"`; it's
staged already).

**The background-audio test (D-63).** In a throwaway project, xtool took a
custom `Info.plist` through an `infoPath:` line in `xtool.yml` and put
`UIBackgroundModes: audio` into the built app, and the audio code built with
no warnings. Then the same in a throwaway copy of your project, with this
guide's files: the build passed with no warnings, and the built app's Info.plist has UIBackgroundModes [audio] next to xtool's own keys (bundle id, launch screen, orientations) unchanged. [Likely] that's all iOS needs to keep the sound
playing with the screen locked (a background mode is an `Info.plist` key, not
something a paid account unlocks), but only your phone can prove it: step 3
in section 5.

**Start here:** add two project files (4.1 and 4.2: `Info.plist` is new,
`xtool.yml` gets one line), then type the four Swift files (4.3 to 4.6; two
new, two replaced), then copy one test file (4.7). No script changes.

**Verification (2026-10-20):** the reference iOS build passed with no
warnings. 405/405 logic tests passed (default zone and America/New_York; +13
in the new AmbientTests, including the web's own samples for a seed) and 70/70
reference store tests. The four guide blocks laid over your tree are identical
to the reference, and that tree built with no warnings. A throwaway copy of
your project with Info.plist and the xtool.yml line built too, with the
background mode in the app. Your own suites plus AmbientTests passed
405/405 and 82/82 against the new source. No 10b phone check has happened
yet.

## 1. Goal

Study to rain, deep noise or waves, made on the phone, which keeps playing
with the screen locked and puts the session on the lock screen.

**On your phone:** Start studying → **SOUND: Rain** → Start. Rain plays.
Lock the phone: it keeps raining, and the lock screen shows your task with a
pause button that pauses the timer itself.

This part includes:

- **Three sounds,** synthesised from arithmetic exactly as the web does: the
  same voices, the same 20-second loop with its end crossfaded into its start
  (so it never clicks), the same 16-bit WAV. A test feeds both apps the same
  random numbers and gets the same samples.
- **A sound row** in setup: Silent, Rain, Deep noise, Waves. Tapping the
  chosen one again is Silent, as on the web.
- **Playback that follows the session:** playing while it runs (breaks too),
  held while paused, gone at the end or when the sheet closes.
- **The lock screen:** "Break" or your task, "Round 2 of 4" or "Study block",
  and play and pause buttons that pause and resume the timer, as the web's
  Media Session does.

## 2. New Swift concepts

### Playing sound, and keeping it going in the background

`AVAudioPlayer` plays audio from a file or, here, from bytes in memory. The
**audio session** tells iOS what kind of sound it is: `.playback` means "this
is the point of the app right now", so it keeps playing with the ringer
switch on silent and, if the app declares the `audio` background mode, with
the screen locked.

```swift
let session = AVAudioSession.sharedInstance()
try? session.setCategory(.playback, mode: .default)
try? session.setActive(true)
player = try? AVAudioPlayer(data: wav)
player?.numberOfLoops = -1      // repeat forever
player?.play()
```

The background mode isn't Swift: it's an `Info.plist` key. xtool builds the
app's `Info.plist` itself and merges in yours when `xtool.yml` names it
(`infoPath: Info.plist`).

### The lock screen

Two shared objects from `MediaPlayer`. `MPNowPlayingInfoCenter` holds what
the lock screen shows; `MPRemoteCommandCenter` delivers its button presses
(and your headphones'):

```swift
MPNowPlayingInfoCenter.default().nowPlayingInfo = [
    MPMediaItemPropertyTitle: "Essay",
    MPMediaItemPropertyArtist: "Round 2 of 4",
]
_ = MPRemoteCommandCenter.shared().pauseCommand.addTarget { _ in
    Task { @MainActor in pause() }   // 7c's hop to the main actor
    return .success
}
```

### Writing bytes

A WAV file is a 44-byte header of small numbers, then one 16-bit number per
sample, every number lowest byte first ("little-endian").
`withUnsafeBytes(of:)` hands you a number's bytes; `.littleEndian` puts them
in that order on any device:

```swift
var bytes: [UInt8] = []
func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { bytes.append(contentsOf: $0) } }
u16(1)            // appends 0x01, 0x00
let file = Data(bytes)
```

It's the web's `DataView.setUint16(offset, value, true)`.

## 3. What it maps from the web

| Web source | Native file / behavior |
|---|---|
| `AMBIENCES`, the voices, `synthesize` and `encodeWav` in `lib/ambient.ts` | `Logic/Ambient.swift` |
| `lib/ambient.test.ts` | `AmbientTests.swift`, plus the web's own samples for a seed |
| `ambienceUrl` and its cache; the `<audio>` element in `StudyTimer.tsx` | `Audio/AmbientPlayer.swift` (`prepare`, `play`, `pause`, `stop`) |
| The Media Session effect in `StudyTimer.tsx` | `showNowPlaying` and `listen` in `AmbientPlayer`, wired in `StudyTimerView` |
| The Sound row and `pickAmbience` in `StudyTimer.tsx` | `StudySetupView` (the row), `StudyTimerView` (`prepare` on pick) |
| The ambient playback effect in `StudyTimer.tsx` | `syncSound` in `StudyTimerView` |

Where the phone differs:

- **A player instead of an `<audio>` element.** The web turns the loop into a
  `blob:` URL for an `<audio>` element because iOS suspends a web page's
  audio graph in the pocket, and a media element is what survives. The phone
  plays the same WAV bytes with `AVAudioPlayer`; surviving the pocket is the
  `.playback` session plus the background mode.
- **The ringer switch doesn't silence it,** because that's what `.playback`
  means. The volume buttons do.
- **A phone call or an alarm stops the sound, and it stays stopped** until you
  tap Pause and Resume. The timer keeps going either way.
- **Picking a sound builds its loop right then,** as the web does, on the main
  thread. [Likely] a short pause on the tap in a debug build; it's built once
  per sound per session.

Web behavior kept on purpose: the three sounds and their labels, the 0.55
volume, playing through breaks ("silence arriving on the dot is a jolt"),
Silent as the default, and the lock-screen lines.

## 4. Files, in the order to type them

Two project files, then four Swift files: two new (4.3, 4.4) and two replaced
(4.5, 4.6). Build once all of them are in.

### 4.1 `~/ClassPing/Info.plist` (new file, next to `xtool.yml`)

Not Swift, and not in `Sources`: it sits in the project folder, beside
`Package.swift` and `xtool.yml`. xtool merges it into the app's own.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- Phase 10b: keep the study timer's sound playing with the screen locked. -->
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
	</array>
</dict>
</plist>
```

### 4.2 `~/ClassPing/xtool.yml` (one line added)

```yaml
version: 1
bundleID: space.classping.ios
infoPath: Info.plist
```

### 4.3 `~/ClassPing/Sources/ClassPing/Logic/Ambient.swift` (new file)

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Ambient.swift
//  Phase:   10b (ambient sound)
//  Ports:   lib/ambient.ts (the three voices, the seamless loop, the WAV file)
//
//  Summary: Rain, deep noise and waves, made on the phone from arithmetic:
//           nothing ships as an audio file. One 20-second loop per sound,
//           whose end is crossfaded into its start so it never clicks when
//           it repeats, then written out as a WAV file the audio player can
//           read. Foundation only, so the tests run on Linux.
//

import Foundation

/// The three sounds. `AmbienceId` on the web.
enum AmbienceID: String, CaseIterable, Sendable {
    case rain, brown, waves
}

/// One sound as the picker shows it. `Ambience` on the web.
struct Ambience: Equatable, Sendable {
    let id: AmbienceID
    let label: String
    /// One line saying what it sounds like.
    let hint: String
}

/// The web's `AMBIENCES`, in its order.
let AMBIENCES: [Ambience] = [
    Ambience(id: .rain, label: "Rain", hint: "Steady rainfall"),
    Ambience(id: .brown, label: "Deep noise", hint: "Low, even hum"),
    Ambience(id: .waves, label: "Waves", hint: "Slow surf"),
]

/// 24 kHz mono: noise has no fine detail to keep, so 44.1 kHz would only
/// cost memory. The web's `SAMPLE_RATE`.
let AMBIENT_SAMPLE_RATE = 24_000
/// Long enough that the ear stops hearing the repeat.
let AMBIENT_LOOP_SECONDS = 20.0
/// The crossfade over the seam: hides it without smearing.
let AMBIENT_FADE_SECONDS = 0.75

/// A source of random numbers from 0 up to (not including) 1. The tests
/// hand in a seeded one so a run can be repeated; the app uses the system's.
typealias Rng = () -> Double

/// White noise from -1 up to 1.
private func white(_ rng: Rng) -> Double { rng() * 2 - 1 }

/// A one-pole lowpass filter: each call moves its output a share `a` of the
/// way toward the input, so smaller `a` is darker. It returns a closure that
/// keeps its own `y` between calls, as the web's does.
private func lowpass(_ a: Double) -> (Double) -> Double {
    var y = 0.0
    return { x in
        y += a * (x - y)
        return y
    }
}

/// The sample maker for one sound: each call gives the next sample, at
/// roughly full volume (the loop is levelled once at the end). The web's
/// `VOICES`, with the same numbers and the random numbers drawn in the same
/// order, so a seed gives the same sound on both.
private func voice(_ id: AmbienceID, _ rng: @escaping Rng) -> () -> Double {
    switch id {
    case .brown:
        // White noise added up, with a leak so it can't drift off to one side.
        var last = 0.0
        return {
            last = (last + 0.02 * white(rng)) / 1.02
            return last * 3.5
        }
    case .rain:
        // A soft hiss, plus droplets: short clicks fired at random, about
        // 2,600 a second, which the ear hears as rain.
        let bed = lowpass(0.18)
        let grain = lowpass(0.45)
        let density = 0.11
        var drop = 0.0
        return {
            if rng() < density { drop = white(rng) }
            drop *= 0.86
            return bed(white(rng)) * 1.6 + grain(drop) * 0.9
        }
    case .waves:
        // Deep noise under a slow swell, about 9.3 seconds long, so the swell
        // and the 20-second loop never line up and give away the repeat.
        var last = 0.0
        var phase = 0.0
        let step = 2 * Double.pi / (9.3 * Double(AMBIENT_SAMPLE_RATE))
        let surf = lowpass(0.3)
        return {
            last = (last + 0.02 * white(rng)) / 1.02
            phase += step
            // A floor of 0.18: the tide going out isn't silence.
            let swell = 0.18 + 0.82 * pow((1 - cos(phase)) / 2, 1.6)
            return (last * 3.2 + surf(white(rng)) * 0.35) * swell
        }
    }
}

/// One loop of `id`, `seconds` long, that joins up with itself. `synthesize`.
///
/// It makes `length + fade` samples and crossfades the extra tail over the
/// start, so the sample after the last one, on the repeat, is sound that
/// really came before it. Equal-power weights (sin and cos) keep the volume
/// steady through the fade. Then the whole loop is scaled so its loudest
/// sample is 0.85, which can't clip.
/// Samples are stored as `Float`, like the web's `Float32Array`, and worked
/// out in `Double`, like JavaScript's numbers.
func synthesize(_ id: AmbienceID, rng: @escaping Rng = { Double.random(in: 0..<1) },
                sampleRate: Int = AMBIENT_SAMPLE_RATE, seconds: Double = AMBIENT_LOOP_SECONDS,
                fadeSeconds: Double = AMBIENT_FADE_SECONDS) -> [Float] {
    let length = Int((Double(sampleRate) * seconds).rounded(.down))
    let fade = min(Int((Double(sampleRate) * fadeSeconds).rounded(.down)), length >> 1)
    let next = voice(id, rng)

    // Every sample, in order: `map` calls the voice once per slot.
    let raw = (0..<(length + fade)).map { _ in Float(next()) }

    // The loop is the first `length` samples, with the tail faded over its start.
    var out = Array(raw.prefix(length))
    for i in 0..<fade {
        let t = Double(i + 1) / Double(fade + 1) * (Double.pi / 2)
        out[i] = Float(Double(raw[i]) * sin(t) + Double(raw[length + i]) * cos(t))
    }

    // Level it last, by the loudest sample, so nothing can clip.
    let peak = out.reduce(Float(0)) { max($0, abs($1)) }
    if peak > 0 {
        let gain = 0.85 / Double(peak)
        out = out.map { Float(Double($0) * gain) }
    }
    return out
}

/// The samples as a WAV file: 16-bit mono PCM behind a 44-byte header, the
/// plainest audio file there is. `encodeWav` on the web.
func encodeWav(_ samples: [Float], sampleRate: Int = AMBIENT_SAMPLE_RATE) -> Data {
    let dataBytes = samples.count * 2
    var bytes: [UInt8] = []
    bytes.reserveCapacity(44 + dataBytes)

    // Little-endian numbers: lowest byte first, as WAV wants. `withUnsafeBytes`
    // shows a number's bytes in memory; `.littleEndian` puts them in that order.
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { bytes.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { bytes.append(contentsOf: $0) } }
    func tag(_ s: String) { bytes.append(contentsOf: Array(s.utf8)) }

    tag("RIFF"); u32(UInt32(36 + dataBytes))       // file size minus these 8 bytes
    tag("WAVE")
    tag("fmt "); u32(16)                           // the format chunk's length
    u16(1)                                         // 1 = uncompressed PCM
    u16(1)                                         // mono
    u32(UInt32(sampleRate))
    u32(UInt32(sampleRate * 2))                    // bytes per second
    u16(2)                                         // bytes per sample
    u16(16)                                        // bits per sample
    tag("data"); u32(UInt32(dataBytes))

    for sample in samples {
        // Clamp first: a value past 1 would wrap to the other side as a crack.
        let s = Swift.max(-1, Swift.min(1, Double(sample)))
        // JavaScript's Math.round (a half rounds up) is floor(x + 0.5).
        let v = Int16((s * 32767 + 0.5).rounded(.down))
        u16(UInt16(bitPattern: v))
    }
    return Data(bytes)
}
```

### 4.4 `~/ClassPing/Sources/ClassPing/Audio/AmbientPlayer.swift` (new file)

A new folder, `Sources/ClassPing/Audio/`.

```swift
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
```

### 4.5 `~/ClassPing/Sources/ClassPing/Screens/Study/StudySetupView.swift` (replaces your 10a file)

Changed spots:

- **Header** (changed).
- **`@Binding var ambience`** (new, after `config`).
- **The SOUND row** (new, before the Start button).
- **`soundChip`** (new, at the end).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Study/StudySetupView.swift
//  Phase:   10a (the study timer), changed in 10b (the sound picker)
//  Ports:   the setup half of components/StudyTimer.tsx
//
//  Summary: The one decision before a study session: how long. One block
//           (15, 25, 45 or 60 minutes, or any number up to 240), or Pomodoro
//           (a focus length and 2, 3, 4 or 6 rounds, with breaks between).
//           Presets first, because "25 minutes" is a choice a stuck student
//           can make. Since 10b, a sound to study to: Silent, Rain, Deep
//           noise or Waves.
//

import SwiftUI

struct StudySetupView: View {
    @Environment(Store.self) private var store

    /// One block (`.timer`) or Pomodoro, owned by the timer screen.
    /// StudySession.Mode already names the two, so no new enum is needed.
    @Binding var mode: StudySession.Mode
    /// One block's length, in minutes.
    @Binding var minutes: Int
    /// Pomodoro's focus length and rounds.
    @Binding var config: PomodoroConfig
    /// NEW in Phase 10b: the sound for the session, or nil for silence.
    @Binding var ambience: AmbienceID?
    /// Starts the session the setup describes.
    let onStart: () -> Void

    /// The "Or set" field's text, kept as typed so a half-typed number isn't
    /// overwritten. A preset tap writes its number in here too.
    @State private var typed = ""
    @FocusState private var typing: Bool

    /// The web's `PRESETS` and `ROUND_CHOICES`.
    private let presets = [15, 25, 45, 60]
    private let roundChoices = [2, 3, 4, 6]

    var body: some View {
        let accent = store.profile.accent
        // What Start would run: the web's `previewPlan`.
        let preview = mode == .timer ? singlePlan(minutes) : buildPlan(config)

        VStack(alignment: .leading, spacing: 14) {
            // One block is the default; Pomodoro is a method you opt into.
            Picker("Mode", selection: $mode) {
                Text("One block").tag(StudySession.Mode.timer)
                Text("Pomodoro").tag(StudySession.Mode.pomodoro)
            }
            .pickerStyle(.segmented)

            if mode == .timer {
                chipRow(presets, selected: minutes, unit: "min") { p in
                    minutes = p
                    typed = "\(p)"
                }
                // Any length from 1 to 240. `clampMinutes` rounds the way
                // the web's input does, and keeps it in range.
                HStack(spacing: 10) {
                    Text("OR SET")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Theme.faint)
                    TextField("Minutes", text: $typed)
                        .keyboardType(.numberPad)
                        .focused($typing)
                        .inputField(accent)
                        .accessibilityLabel("Minutes")
                    Text("min").foregroundStyle(Theme.muted)
                }
                .onChange(of: typed) { _, text in
                    if let value = Double(text) {
                        minutes = clampMinutes(value, 1, MAX_BLOCK_MINUTES)
                    }
                }
            } else {
                label("FOCUS BLOCK")
                chipRow(presets, selected: config.focus, unit: "min") { config.focus = $0 }
                label("ROUNDS")
                chipRow(roundChoices, selected: config.rounds, unit: nil) { config.rounds = $0 }
                // "4 × 25 min, 5 min breaks, 1h 55m in all"
                Text("\(config.rounds) \u{00D7} \(config.focus) min, \(config.shortBreak) min breaks, \(studySpan(planMinutes(preview))) in all")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }

            // NEW in Phase 10b: the sound, made on the phone, so the list
            // costs nothing to ship. Tapping the chosen one again is Silent.
            label("SOUND")
            HStack(spacing: 10) {
                soundChip("Silent", on: ambience == nil, quiet: true) { ambience = nil }
                ForEach(AMBIENCES, id: \.id) { sound in
                    soundChip(sound.label, on: ambience == sound.id, quiet: false) {
                        ambience = ambience == sound.id ? nil : sound.id
                    }
                    .accessibilityHint(sound.hint)
                }
            }

            Button(action: onStart) {
                Text(mode == .timer ? "Start \(minutes) minutes" : "Start \(config.rounds) rounds")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        // Start from whatever length the screen holds.
        .onAppear { typed = "\(minutes)" }
        // Swipe down or tap Done to put the number pad away (D-54).
        .keyboardDismissable { typing = false }
    }

    /// A small caps label over a row of chips.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundStyle(Theme.faint)
    }

    /// Four chips in a row, the chosen one filled with your accent. `unit`
    /// is the small word under each number ("min"), or nil for none.
    private func chipRow(_ values: [Int], selected: Int, unit: String?,
                         pick: @escaping (Int) -> Void) -> some View {
        let accent = store.profile.accent
        return HStack(spacing: 10) {
            ForEach(values, id: \.self) { value in
                let on = value == selected
                Button { pick(value) } label: {
                    VStack(spacing: 2) {
                        Text("\(value)").font(.system(size: 18, weight: .bold))
                        if let unit {
                            Text(unit).font(.system(size: 10.5, weight: .medium)).opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(on ? Color.white : Theme.muted)
                    .background(on ? Theme.brand(accent) : Theme.surface2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unit.map { "\(value) \($0 == "min" ? "minutes" : $0)" } ?? "\(value) rounds")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // NEW in Phase 10b
    /// One sound chip. A chosen sound is filled with your accent; Silent,
    /// when chosen, just darkens, as on the web.
    private func soundChip(_ title: String, on: Bool, quiet: Bool,
                           pick: @escaping () -> Void) -> some View {
        let accent = store.profile.accent
        let fill = on ? (quiet ? Theme.lineStrong : Theme.brand(accent)) : Theme.surface2
        let ink = on ? (quiet ? Theme.ink : Color.white) : Theme.muted
        return Button(action: pick) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(ink)
                .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
```

### 4.6 `~/ClassPing/Sources/ClassPing/Screens/Study/StudyTimerView.swift` (replaces your 10a file)

Changed spots:

- **Header** (changed).
- **`ambience` and `sound`** (new `@State`, after `zen`).
- **`StudySetupView(...)`** (changed): passes `ambience: $ambience`.
- **Four modifiers** after `.task(id: phase)`: `onChange(of: ambience)`,
  `onChange(of: phase)` and `onAppear` (new); `onDisappear` (changed: also
  stops the sound and the lock-screen buttons).
- **`advance`** (changed): calls `syncSound()` at the end.
- **`syncSound` and `showNowPlaying`** (new, after `advance`).

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Study/StudyTimerView.swift
//  Phase:   10a (the study timer), changed in 10b (sound and the lock screen)
//  Ports:   components/StudyTimer.tsx (the running, paused and finished
//           states, focus mode, and its `onFocusComplete` and
//           `onFinishTask` callbacks in app/tasks/[id]/page.tsx)
//
//  Summary: A study session for one assignment, in a sheet. Setup, then a
//           ring counting down each block, Pause and Stop, and a focus mode
//           that hides everything but the clock. Every block's end is worked out when you start, so
//           the session keeps time with the phone in your pocket: an alert
//           rings at each block's end, and each finished focus block is
//           recorded at the moment it ended. Since 10b the session can play
//           a sound, which carries on with the screen locked, and shows on
//           the lock screen with play and pause buttons.
//

import SwiftUI

struct StudyTimerView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The work being studied. A copy taken when the sheet opened; whether
    /// it's done is read live from the store.
    let assignment: Assignment

    /// Where the session is. An enum with a value in three of its cases: the
    /// run travels with the state it belongs to, so a paused session can't be
    /// missing its run, and setup can't have one.
    private enum Phase: Equatable {
        case setup
        case running(StudyRun)
        case paused(StudyRun)
        case done(StudyRun)
    }

    @State private var phase = Phase.setup
    // The setup choices, kept here so "Another session" starts from them.
    @State private var mode = StudySession.Mode.timer
    @State private var minutes = 25
    @State private var config = DEFAULT_POMODORO
    /// How many of the plan's blocks are behind you and dealt with.
    @State private var credited = 0
    /// Focus mode, the web's "zen": everything but the clock hidden.
    @State private var zen = false
    /// NEW in Phase 10b: the sound picked in setup, or nil for silence.
    @State private var ambience: AmbienceID? = nil
    /// NEW in Phase 10b: plays it. `@State` keeps this one object for as
    /// long as the sheet is open, however often the screen redraws.
    @State private var sound = AmbientPlayer()

    var body: some View {
        let accent = store.profile.accent

        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // `switch` on the phase: each case gets its own screen.
                    // `let run` takes the value out of the case to use it.
                    switch phase {
                    case .setup:
                        header("WORKING ON", assignment.title)
                        // CHANGED in Phase 10b: the sound picker too.
                        StudySetupView(mode: $mode, minutes: $minutes, config: $config,
                                       ambience: $ambience, onStart: start)
                    case .running(let run):
                        // A clock redrawn twice a second; every number on it
                        // comes from the time, never from counting ticks.
                        TimelineView(.periodic(from: .now, by: 0.5)) { context in
                            live(run, at: context.date)
                        }
                    case .paused(let run):
                        face(run, RunPosition(index: run.index, remaining: run.left,
                                              finished: false), paused: true)
                    case .done(let run):
                        finished(run)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.canvas)
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // While a session runs, Stop ends it; Close is for before and after.
                if !isActive {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .tint(Theme.brand(accent))
            // Focus mode hides the bar along with everything else.
            .toolbar(zen ? .hidden : .visible, for: .navigationBar)
        }
        // Focus mode, laid over the whole sheet. An overlay rather than a
        // full-screen cover: a cover would make this screen "disappear",
        // and its `onDisappear` would cancel the alerts you need most then.
        .overlay {
            if zen { zenView }
        }
        // A swipe down can't throw away a running session by accident.
        .interactiveDismissDisabled(isActive)
        // Hand iOS this session's block-end alerts whenever it starts, pauses,
        // resumes, stops or ends. `.task(id:)` cancels the last call first.
        .task(id: phase) {
            await store.scheduleStudyAlerts(currentAlerts)
        }
        // NEW in Phase 10b: build the loop as soon as a sound is picked, so
        // Start doesn't wait for it (the web's `pickAmbience`), and let the
        // sound follow the session: playing while it runs, held while paused.
        .onChange(of: ambience) { _, picked in
            if let picked { sound.prepare(picked) }
        }
        .onChange(of: phase) {
            syncSound()
        }
        // NEW in Phase 10b: the lock screen's play and pause buttons pause and
        // resume the timer itself, as the web's Media Session handlers do.
        .onAppear {
            sound.listen(play: {
                if case .paused(let run) = phase { resume(run) }
            }, pause: {
                if case .running(let run) = phase { pause(run) }
            })
        }
        // Closing the sheet ends the session, so its alerts go too.
        // CHANGED in Phase 10b: and its sound and lock-screen buttons.
        .onDisappear {
            Task { await store.scheduleStudyAlerts([]) }
            sound.stop()
            sound.stopListening()
        }
    }

    // MARK: - State

    /// True while a session is running or paused.
    private var isActive: Bool {
        switch phase {
        case .running, .paused: true
        case .setup, .done: false
        }
    }

    /// The alerts for what's still ahead, while running; none otherwise.
    /// `if case` checks one case of an enum and takes its value out.
    private var currentAlerts: [StudyAlert] {
        if case .running(let run) = phase {
            return studyAlerts(run, title: assignment.title, after: .now)
        }
        return []
    }

    // MARK: - Actions

    /// Starts the plan the setup describes: the web's `startPlan`.
    private func start() {
        let plan = mode == .timer ? singlePlan(minutes) : buildPlan(config)
        credited = 0
        phase = .running(StudyRun(plan: plan, now: .now))
    }

    /// Records the focus blocks that ended since last time, each at its real
    /// end, and finishes the session after its last block. The web's
    /// `advance`, which runs once per block; this catches up on several at
    /// once after the phone slept.
    private func advance(_ run: StudyRun, at now: Date) {
        let result = newlyFinished(run, from: credited, at: now)
        for block in result.blocks {
            store.addStudySession(minutes: block.minutes, assignmentID: assignment.id,
                                  courseID: assignment.courseID, mode: mode,
                                  completedAt: block.endedAt)
        }
        credited = result.through
        if runPosition(run, at: now).finished {
            phase = .done(run)
            zen = false
        }
        // NEW in Phase 10b: a new block means a new lock-screen line.
        syncSound()
    }

    // NEW in Phase 10b
    /// Makes the sound match the session: playing while it runs (breaks
    /// included, as on the web: silence on the dot is a jolt), held while
    /// paused, gone before Start and after the end.
    private func syncSound() {
        switch phase {
        case .running(let run):
            guard let ambience else {
                sound.stop()
                return
            }
            sound.play(ambience)
            let now = min(runPosition(run, at: .now).index, run.plan.count - 1)
            showNowPlaying(run, index: now, running: true)
        case .paused(let run):
            sound.pause()
            if ambience != nil { showNowPlaying(run, index: run.index, running: false) }
        case .setup, .done:
            sound.stop()
        }
    }

    // NEW in Phase 10b
    /// The lock screen's two lines: "Break" or the task, and the round.
    /// The web's `MediaMetadata`.
    private func showNowPlaying(_ run: StudyRun, index: Int, running: Bool) {
        let rounds = focusCount(run.plan)
        sound.showNowPlaying(title: run.plan[index].kind == .rest ? "Break" : assignment.title,
                             detail: rounds > 1 ? "Round \(roundAt(run.plan, index)) of \(rounds)" : "Study block",
                             running: running)
    }

    /// Stops the clock where it is. Whatever already finished is recorded first.
    private func pause(_ run: StudyRun) {
        let now = Date.now
        advance(run, at: now)
        if case .running = phase {
            phase = .paused(pausedRun(run, at: now))
        }
    }

    /// Starts the clock again from now: every later block moves along with it.
    private func resume(_ run: StudyRun) {
        var next = run
        next.anchor = .now
        phase = .running(next)
    }

    /// Back to setup. The web's `reset`; blocks already recorded stay recorded.
    private func stop() {
        phase = .setup
        zen = false
    }

    // MARK: - Pieces

    /// The small caps line and the title over the clock.
    private func header(_ label: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// A running session at one moment. `onChange(of:initial:)` (7c) notices
    /// each new block, including several at once after the phone slept, and
    /// records what finished.
    private func live(_ run: StudyRun, at now: Date) -> some View {
        let position = runPosition(run, at: now)
        return face(run, position, paused: false)
            .onChange(of: position.index, initial: true) {
                advance(run, at: now)
            }
    }

    /// The round dots, the ring with the time left, and the controls.
    private func face(_ run: StudyRun, _ position: RunPosition, paused: Bool) -> some View {
        let accent = store.profile.accent
        let index = min(position.index, run.plan.count - 1)
        let block = run.plan[index]
        let isBreak = block.kind == .rest
        let total = Double(block.minutes * 60)
        // How much of this block has gone, from 0 to 1.
        let gone = total > 0 ? 1 - min(1, position.remaining / total) : 0
        // Green for a break, your accent for work, as on the web.
        let color = isBreak ? Theme.good : Theme.brand(accent)
        let rounds = focusCount(run.plan)

        return VStack(spacing: 18) {
            header(isBreak ? "BREAK" : "WORKING ON", isBreak ? "Rest" : assignment.title)

            // One dot per round: done, now (wider), or still to come.
            if rounds > 1 {
                HStack(spacing: 6) {
                    ForEach(run.plan.indices.filter { run.plan[$0].kind == .focus }, id: \.self) { i in
                        Capsule()
                            .fill(i < index ? Theme.brand(accent) : i == index ? color : Theme.lineStrong)
                            .frame(width: i == index ? 20 : 8, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Round \(roundAt(run.plan, index)) of \(rounds)")
            }

            // The ring: a full grey circle, and on top of it the same circle
            // trimmed to the share that's gone. `trim` draws only part of a
            // shape's outline; turning it -90° starts it at twelve o'clock.
            ZStack {
                Circle()
                    .stroke(Theme.surface2, lineWidth: 11)
                Circle()
                    .trim(from: 0, to: gone)
                    .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(studyClock(position.remaining))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(paused ? "Paused" : isBreak ? "break" : "left")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 180, height: 180)
            .accessibilityElement(children: .combine)

            // Stop and Pause / Resume, then the way into focus mode.
            HStack(spacing: 10) {
                Button(action: stop) {
                    Text("Stop").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                Button {
                    if paused { resume(run) } else { pause(run) }
                } label: {
                    Text(paused ? "Resume" : "Pause").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Focus mode") { zen = true }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
        }
    }

    /// The end: what you did, then Mark it done, Another session or Close.
    private func finished(_ run: StudyRun) -> some View {
        let open = store.assignment(assignment.id)?.done == false
        return VStack(spacing: 14) {
            header("SESSION COMPLETE", assignment.title)
            Text("🎉").font(.system(size: 44))
            Text("\(studySpan(planMinutes(run.plan))) done")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
            // Only while the work is still open: the finished screen shouldn't
            // hand you a button that un-ticks it. (The web's XP line waits
            // for Phase 12.)
            if open {
                Button {
                    store.toggleAssignment(assignment.id)
                    dismiss()
                } label: {
                    Label("Mark it done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            Button { phase = .setup } label: {
                Text("Another session").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            Button("Close") { dismiss() }
                .frame(minHeight: 44)
        }
    }

    /// Focus mode: the round, what you're on, the time, a thin bar, and
    /// Pause / Resume and Exit. Nothing else. It only draws: the clock under
    /// it keeps running and recording, so finished blocks are counted once.
    @ViewBuilder
    private var zenView: some View {
        let accent = store.profile.accent
        ZStack {
            Theme.canvas.ignoresSafeArea()
            switch phase {
            case .running(let run):
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    zenFace(run, runPosition(run, at: context.date), paused: false, accent: accent)
                }
            case .paused(let run):
                zenFace(run, RunPosition(index: run.index, remaining: run.left, finished: false),
                        paused: true, accent: accent)
            case .setup, .done:
                // The session ended underneath: nothing to show, so leave.
                Color.clear.onAppear { zen = false }
            }
        }
        .tint(Theme.brand(accent))
    }

    private func zenFace(_ run: StudyRun, _ position: RunPosition, paused: Bool,
                         accent: Profile.Accent) -> some View {
        let index = min(position.index, run.plan.count - 1)
        let block = run.plan[index]
        let isBreak = block.kind == .rest
        let total = Double(block.minutes * 60)
        let gone = total > 0 ? 1 - min(1, position.remaining / total) : 0
        let color = isBreak ? Theme.good : Theme.brand(accent)
        let rounds = focusCount(run.plan)

        return VStack(spacing: 0) {
            Text(isBreak ? "BREAK" : rounds > 1 ? "ROUND \(roundAt(run.plan, index)) OF \(rounds)" : "FOCUS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
            Text(isBreak ? "Rest" : assignment.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.top, 10)
            Text(studyClock(position.remaining))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .padding(.top, 24)
            // The thin bar: a track, and the share that's gone laid over it.
            Capsule()
                .fill(Theme.surface2)
                .frame(width: 220, height: 3)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: 220 * gone, height: 3)
                }
                .padding(.top, 32)
            HStack(spacing: 10) {
                Button(paused ? "Resume" : "Pause") {
                    if paused { resume(run) } else { pause(run) }
                }
                .buttonStyle(.bordered)
                Button("Exit") { zen = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 40)
        }
        .padding(.horizontal, 32)
    }
}
```

### 4.7 Tests (copy this, don't type it)

```bash
cd ~/ClassPing
cp /mnt/c/Users/kelvi/Desktop/classping/docs/ios/reference/Tests/Logic/AmbientTests.swift Tests/Logic/   # new: 13 tests
```

## 5. Run it

```bash
cd ~/ClassPing
scripts/test-logic.sh     # expect 405 tests passing
scripts/test-store.sh     # still 82
xtool dev build
xtool dev
```

The last command installs on your phone, so run that one yourself.

1. **The row:** Start studying. Under the time choices, SOUND: Silent
   (chosen), Rain, Deep noise, Waves. Tap Rain: it fills. Tap it again:
   back to Silent. Note whether the first tap on a sound pauses for a moment.
2. **Play and pause:** pick Rain, set 2 minutes, Start. Rain plays. Pause:
   it holds. Resume: it carries on. Listen past the 20-second mark: no click
   where it loops.
3. **Locked (the one that proves background audio):** lock the phone. It
   keeps raining. The lock screen shows your task, "Study block" and
   "ClassPing", with a pause button. Tap it: the rain stops, and in the app
   the timer says Paused. Tap play on the lock screen: both carry on.
4. **The end:** let it finish locked. The sound stops and "Session complete"
   rings.
5. **Closing:** start with Waves, then Stop and Close: the sound stops. If you
   had music playing before, it can pick up again.
6. **The others:** Deep noise and Waves each play; Waves swells slowly.
7. **Pomodoro, when you have time:** 2 rounds of 15 with Rain, locked. The
   rain carries on through the break, and the lock screen reads "Break" and
   "Round 1 of 2".

Nothing was committed or installed by the agent.

## 6. Done when

- [ ] 405 logic and 82 store tests pass; the tree builds without warnings.
- [ ] Each sound plays, loops without a click, and follows Pause and Resume.
- [ ] The sound keeps playing with the phone locked, and the lock screen's
      buttons pause and resume the timer.
- [ ] Stop, Close and the end of a session all stop the sound.

## 7. If it breaks

- **The sound stops when you lock the phone:** the background mode didn't
  reach the app. `Info.plist` belongs in `~/ClassPing/`, beside `xtool.yml`
  (not in `Sources`), and `xtool.yml` needs `infoPath: Info.plist`. Run
  `xtool dev` again after fixing either.
- **No lock-screen controls:** they only appear while a sound plays. With
  Silent there's nothing to show, as on the web.
- **Cannot find 'AMBIENCES' or 'AmbienceID':** 4.3 isn't in `Logic/` yet.
- **An error about sending a closure, or 'Sendable', at `addTarget`:** the
  handler has to hop with `Task { @MainActor in … }` rather than call
  `play()` or `pause()` directly.
- **A click every 20 seconds:** compare the crossfade loop in `synthesize`
  line by line; `AmbientTests`' seam tests catch most slips.

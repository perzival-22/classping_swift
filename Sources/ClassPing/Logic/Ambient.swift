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

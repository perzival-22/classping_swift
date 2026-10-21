// AmbientTests.swift: the Swift twin of lib/ambient.test.ts, plus a check
// that a seed gives the web's own samples. Cases marked "web:" are
// lib/ambient.ts's output (node 24, 2026-10-20).
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// Mulberry32, the web test's `seeded`: a repeatable stand-in for random.
/// UInt32 with wrapping `&+` and `&*` does what JavaScript's `>>> 0` and
/// `Math.imul` do.
private func seeded(_ seed: UInt32) -> Rng {
    var a = seed
    return {
        a = a &+ 0x6D2B_79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

/// Short and low-rate: what's tested doesn't depend on the rate. The web's `opts`.
private func loop(_ id: AmbienceID, seed: UInt32 = 1, fade: Double = 0.25) -> [Float] {
    synthesize(id, rng: seeded(seed), sampleRate: 800, seconds: 1, fadeSeconds: fade)
}

/// Reads a little-endian number out of the WAV bytes.
private func int16(_ d: Data, _ at: Int) -> Int16 {
    Int16(bitPattern: UInt16(d[at]) | UInt16(d[at + 1]) << 8)
}
private func uint32(_ d: Data, _ at: Int) -> UInt32 {
    (0..<4).reduce(UInt32(0)) { $0 | UInt32(d[at + $1]) << (8 * UInt32($1)) }
}
private func tag(_ d: Data, _ at: Int) -> String {
    String(decoding: d[at..<(at + 4)], as: UTF8.self)
}

@Suite struct AmbientTests {

    // MARK: synthesize

    @Test(arguments: AmbienceID.allCases)
    func returnsExactlyTheRequestedLength(_ id: AmbienceID) {
        #expect(loop(id).count == 800)
    }

    @Test(arguments: AmbienceID.allCases)
    func neverExceedsTheNormalisedPeak(_ id: AmbienceID) {
        #expect(loop(id).allSatisfy { abs($0) <= 0.85 + 1e-6 })
    }

    /// Guards the leveller: a silent loop would pass every other check.
    @Test(arguments: AmbienceID.allCases)
    func actuallyReachesThatPeak(_ id: AmbienceID) {
        let peak = loop(id).reduce(Float(0)) { max($0, abs($1)) }
        #expect(abs(peak - 0.85) < 1e-5)
    }

    @Test(arguments: AmbienceID.allCases)
    func isDeterministicForAGivenSeed(_ id: AmbienceID) {
        #expect(loop(id, seed: 7) == loop(id, seed: 7))
    }

    /// The seam is no worse a jump than the 99th-percentile step inside it.
    @Test(arguments: AmbienceID.allCases)
    func joinsSeamlesslyWhenItWraps(_ id: AmbienceID) {
        let out = loop(id)
        let steps = (1..<out.count).map { abs(out[$0] - out[$0 - 1]) }.sorted()
        let p99 = steps[Int(Double(steps.count) * 0.99)]
        let seam = abs(out[0] - out[out.count - 1])
        #expect(seam <= p99)
    }

    /// Averaged over 24 seeds: the crossfade closes the seam, not luck.
    @Test(arguments: AmbienceID.allCases)
    func owesItsSeamToTheCrossfadeNotToChance(_ id: AmbienceID) {
        func meanSeam(_ fade: Double) -> Float {
            let seams = (1...24).map { seed -> Float in
                let a = loop(id, seed: UInt32(seed), fade: fade)
                return abs(a[0] - a[a.count - 1])
            }
            return seams.reduce(0, +) / 24
        }
        #expect(meanSeam(0.25) < meanSeam(0) / 2)
    }

    /// The same seed gives the web's own samples.
    @Test func aSeedGivesTheWebsSamples() {
        // web: seeded(1)'s first three numbers
        let r = seeded(1)
        #expect([r(), r(), r()] == [0.6270739405881613, 0.002735721180215478, 0.5274470399599522])
        // web: samples 0, 1, 2, 399 and 799 of each loop
        let expected: [AmbienceID: [Float]] = [
            .rain: [-0.2817111015319824, -0.3909749984741211, -0.2738807499408722,
                    0.2184121161699295, -0.22982659935951233],
            .brown: [0.1815878003835678, 0.2213265597820282, 0.09618190675973892,
                     -0.6294655203819275, 0.26628485321998596],
            .waves: [-0.24268263578414917, -0.24193722009658813, -0.4255656599998474,
                     -0.20690803229808807, -0.3045623302459717],
        ]
        for id in AmbienceID.allCases {
            let out = loop(id)
            let got = [out[0], out[1], out[2], out[399], out[799]]
            // Waves uses cos and pow, whose last bit can differ between
            // maths libraries, so allow a hair.
            let close = zip(got, expected[id] ?? []).allSatisfy { abs($0 - $1) <= 1e-6 }
            #expect(close, "\(id.rawValue): \(got)")
        }
    }

    // MARK: encodeWav

    @Test func writesARiffWaveHeaderOfTheRightSize() {
        let d = encodeWav([Float](repeating: 0, count: 10), sampleRate: 24000)
        #expect(d.count == 44 + 20)
        #expect(tag(d, 0) == "RIFF")
        #expect(tag(d, 8) == "WAVE")
        #expect(tag(d, 12) == "fmt ")
        #expect(tag(d, 36) == "data")
        #expect(uint32(d, 4) == 36 + 20)
        #expect(uint32(d, 40) == 20)
    }

    @Test func declaresMono16BitPcmAtTheGivenRate() {
        let d = encodeWav([Float](repeating: 0, count: 4), sampleRate: 22050)
        #expect(int16(d, 20) == 1)            // PCM
        #expect(int16(d, 22) == 1)            // channels
        #expect(uint32(d, 24) == 22050)
        #expect(uint32(d, 28) == 22050 * 2)   // byte rate
        #expect(int16(d, 32) == 2)            // block align
        #expect(int16(d, 34) == 16)           // bit depth
    }

    @Test func scalesFullScaleSamplesToTheRails() {
        let d = encodeWav([0, 1, -1], sampleRate: 24000)
        #expect(int16(d, 44) == 0)
        #expect(int16(d, 46) == 32767)
        #expect(int16(d, 48) == -32767)
    }

    @Test func clampsOutOfRangeInputInsteadOfWrappingIt() {
        let d = encodeWav([2, -2], sampleRate: 24000)
        #expect(int16(d, 44) == 32767)
        #expect(int16(d, 46) == -32767)
    }

    /// JavaScript's Math.round: a half rounds up, so -0.5 goes to the higher number.
    @Test func roundsLikeMathRound() {
        // web: [16384, -16383, 8192, 0, -1]
        let d = encodeWav([0.5, -0.5, 0.25, 0.00001, -0.00002], sampleRate: 24000)
        #expect((0..<5).map { int16(d, 44 + $0 * 2) } == [16384, -16383, 8192, 0, -1])
    }

    // MARK: AMBIENCES

    @Test func hasAVoiceForEveryListedIdAndNoDuplicates() {
        let ids = AMBIENCES.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(ids) == Set(AmbienceID.allCases))
    }
}

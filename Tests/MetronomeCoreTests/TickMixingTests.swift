import Foundation
import Testing
@testable import MetronomeCore

@Suite("Overlapping tick voices")
struct TickMixingTests {
    @Test
    func fastestSwungOnsetRetainsPreviousTailContinuously() {
        let settings = MetronomeSettings(bpm: 240, subdivision: 4, pitch: 880, volume: 1, swing: 0.45)
        let previousIndex = 1
        let currentIndex = 2
        let previousStart = MetronomeTiming.pulseTime(index: previousIndex, settings: settings)
        let currentStart = MetronomeTiming.pulseTime(index: currentIndex, settings: settings)
        let spacing = currentStart - previousStart
        #expect(abs(spacing - 0.034375) < 1e-12)
        #expect(spacing < TickSynthesis.duration)
        let previousGain = MetronomeTiming.pulseStrength(index: previousIndex, settings: settings)
        let currentGain = MetronomeTiming.pulseStrength(index: currentIndex, settings: settings)

        func mix(offset: Double) -> Double {
            TickSynthesis.mixedSample(at: offset, accent: false, strength: currentGain,
                                      previousTime: spacing + offset, previousAccent: false,
                                      previousStrength: previousGain, frequency: settings.pitch,
                                      volume: settings.volume)
        }
        let expectedTailAtOnset = TickSynthesis.sample(at: spacing, frequency: settings.pitch,
                                                        accent: false) * previousGain
        #expect(abs(expectedTailAtOnset) > 0.005)
        #expect(abs(mix(offset: 0) - expectedTailAtOnset) < 1e-12)
        // The old single-voice renderer discarded this nonzero tail at every short swung onset.
        let truncatedAtOnset = TickSynthesis.sample(at: 0, frequency: settings.pitch,
                                                     accent: false) * currentGain
        #expect(truncatedAtOnset == 0)
        #expect(abs(mix(offset: -1e-9) - mix(offset: 1e-9)) < 1e-7)

        for sampleIndex in 0...1200 {
            let offset = Double(sampleIndex) / 48_000
            let independentlySummed = (
                TickSynthesis.sample(at: offset, frequency: settings.pitch, accent: false) * currentGain
                + TickSynthesis.sample(at: spacing + offset, frequency: settings.pitch, accent: false) * previousGain
            ) * settings.volume
            #expect(abs(mix(offset: offset) - independentlySummed) < 1e-12)
        }
    }

    @Test(arguments: [220.0, 880.0, 1760.0])
    func allFastestDensityVoicesRemainBelowClipping(frequency: Double) {
        let settings = MetronomeSettings(bpm: 240, beatsPerBar: 1, subdivision: 4,
                                          pitch: frequency, volume: 1, swing: 0.45)
        let rate = 48_000.0
        for sampleIndex in 0..<24_000 {
            let elapsed = Double(sampleIndex) / rate
            let currentIndex = MetronomeTiming.pulseIndex(elapsed: elapsed, settings: settings)
            let currentStart = MetronomeTiming.pulseTime(index: currentIndex, settings: settings)
            let previousIndex = max(0, currentIndex - 1)
            let previousTime = currentIndex > 0
                ? elapsed - MetronomeTiming.pulseTime(index: previousIndex, settings: settings)
                : TickSynthesis.duration
            let mixed = TickSynthesis.mixedSample(
                at: elapsed - currentStart,
                accent: MetronomeTiming.pulseIsAccent(index: currentIndex, settings: settings),
                strength: MetronomeTiming.pulseStrength(index: currentIndex, settings: settings),
                previousTime: previousTime,
                previousAccent: MetronomeTiming.pulseIsAccent(index: previousIndex, settings: settings),
                previousStrength: MetronomeTiming.pulseStrength(index: previousIndex, settings: settings),
                frequency: frequency, volume: 1, sampleRate: rate
            )
            #expect(mixed.isFinite && abs(mixed) < 1)
            // A third simultaneous voice is impossible anywhere in the supported rhythm range.
            if currentIndex >= 2 {
                let olderAge = elapsed - MetronomeTiming.pulseTime(index: currentIndex - 2, settings: settings)
                #expect(olderAge >= TickSynthesis.duration)
            }
        }
    }

    @Test
    func expiredPreviousVoiceEqualsSingleVoiceAndGainsAreSafe() {
        let time = 0.004
        let expected = TickSynthesis.sample(at: time, frequency: 880, accent: true) * 0.72 * 0.65
        let actual = TickSynthesis.mixedSample(at: time, accent: true, strength: 0.72,
                                               previousTime: 0.08, previousAccent: false,
                                               previousStrength: 0.36, frequency: 880, volume: 0.65)
        #expect(abs(actual - expected) < 1e-12)
        #expect(TickSynthesis.mixedSample(at: time, accent: true, strength: .nan,
                                          previousTime: time, previousAccent: false,
                                          previousStrength: .infinity, frequency: 880, volume: 1) == 0)
        #expect(TickSynthesis.mixedSample(at: time, accent: true, strength: 1,
                                          previousTime: time, previousAccent: false,
                                          previousStrength: 1, frequency: 880, volume: .nan) == 0)
        let clamped = TickSynthesis.mixedSample(at: time, accent: true, strength: 4,
                                                previousTime: time, previousAccent: false,
                                                previousStrength: -1, frequency: 880, volume: 5)
        #expect(clamped == TickSynthesis.sample(at: time, frequency: 880, accent: true))
    }
}

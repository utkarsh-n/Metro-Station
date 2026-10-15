import Foundation
import Testing
@testable import MetronomeCore

@Suite("Rhythm math")
struct MetronomeTimingTests {
    @Test(arguments: [30.0, 120.0, 240.0])
    func tempoUnitsAndLongTermSchedule(bpm: Double) {
        let settings = MetronomeSettings(bpm: bpm)
        #expect(abs(settings.beatFrequency - bpm / 60) < 1e-12)
        #expect(abs(settings.beatDuration * settings.beatFrequency - 1) < 1e-12)
        #expect(settings.barDuration == settings.beatDuration * 4)
        // No iterative addition: a millionth beat remains on its mathematical timestamp.
        #expect(MetronomeTiming.pulseTime(index: 1_000_000, settings: settings) == 60_000_000 / bpm)
        for index in 0..<64 {
            let timestamp = MetronomeTiming.pulseTime(index: index, settings: settings)
            #expect(MetronomeTiming.pulseIndex(elapsed: timestamp, settings: settings) == index)
            let snapshot = BeatSnapshot.snapshot(elapsed: timestamp + settings.beatDuration / 4, settings: settings)
            #expect(abs(snapshot.beatPhase - 0.25) < 1e-10)
            #expect(snapshot.beatInBar == index % 4)
            #expect(snapshot.barIndex == index / 4)
        }
    }

    @Test(arguments: [1, 2, 3, 4])
    func subdivisionsAndSwing(subdivision: Int) {
        let straight = MetronomeSettings(bpm: 120, subdivision: subdivision)
        let swing = MetronomeSettings(bpm: 120, subdivision: subdivision, swing: 0.4)
        let step = 0.5 / Double(subdivision)
        #expect(straight.pulseFrequency == 2 * Double(subdivision))
        for index in 0..<32 {
            let expectedDelay = subdivision.isMultiple(of: 2) && !index.isMultiple(of: 2) ? 0.4 * step : 0
            let timestamp = MetronomeTiming.pulseTime(index: index, settings: swing)
            #expect(abs(timestamp - (Double(index) * step + expectedDelay)) < 1e-10)
            #expect(MetronomeTiming.pulseIndex(elapsed: timestamp, settings: swing) == index)
            if index > 0 {
                #expect(MetronomeTiming.pulseIndex(elapsed: timestamp - 0.00001, settings: swing) == index - 1)
            }
            #expect(MetronomeTiming.pulseDuration(index: index, settings: swing) > 0)
        }
        #expect(MetronomeTiming.pulseTime(index: subdivision, settings: swing) == 0.5)
        #expect(MetronomeTiming.pulseTime(index: subdivision * 8, settings: swing) == 4)
    }

    @Test
    func pulseRemainsPreviousUntilSwingDelayPasses() {
        let settings = MetronomeSettings(subdivision: 2, swing: 0.4)
        #expect(BeatSnapshot.snapshot(elapsed: 0.30, settings: settings).pulseInBeat == 0)
        #expect(BeatSnapshot.snapshot(elapsed: 0.35, settings: settings).pulseInBeat == 1)
        #expect(BeatSnapshot.snapshot(elapsed: 0.50, settings: settings).pulseInBeat == 0)
        #expect(BeatSnapshot.snapshot(elapsed: 2.75, settings: settings).beatInBar == 1)
        #expect(BeatSnapshot.snapshot(elapsed: 2.75, settings: settings).barIndex == 1)
    }

    @Test
    func sharedPulseAccentsAndStrengthsMatchMeter() {
        let settings = MetronomeSettings(beatsPerBar: 3, subdivision: 4)
        for index in 0..<36 {
            let downbeat = index.isMultiple(of: 12)
            #expect(MetronomeTiming.pulseIsAccent(index: index, settings: settings) == downbeat)
            let expected = downbeat ? 1.0 : index.isMultiple(of: 4) ? 0.72 : 0.36
            #expect(MetronomeTiming.pulseStrength(index: index, settings: settings) == expected)
        }
    }

    @Test(arguments: [73.0, 137.0, 191.5])
    func nonIntegerBeatDurationBoundaries(bpm: Double) {
        let settings = MetronomeSettings(bpm: bpm, beatsPerBar: 7, subdivision: 4, swing: 0.31)
        for index in 0..<200 {
            let time = MetronomeTiming.pulseTime(index: index, settings: settings)
            #expect(MetronomeTiming.pulseIndex(elapsed: time, settings: settings) == index)
            if index.isMultiple(of: 4) {
                let exact = BeatSnapshot.snapshot(elapsed: time, settings: settings)
                #expect(exact.beatPhase == 0)
                #expect(exact.beatInBar == (index / 4) % 7)
            }
            let snapshot = BeatSnapshot.snapshot(elapsed: time + 0.000001, settings: settings)
            #expect(snapshot.beatInBar == (index / 4) % 7)
            #expect(snapshot.barIndex == index / 28)
            #expect(snapshot.pulseInBeat == index % 4)
        }
    }

    @Test
    func hostileSettingsAndTimeAreSafe() {
        let bad = MetronomeSettings(bpm: .nan, beatsPerBar: .max, subdivision: -3,
                                    pitch: .infinity, volume: -.infinity, swing: .nan).sanitized
        #expect(bad.bpm == 120)
        #expect(bad.beatsPerBar == 12)
        #expect(bad.subdivision == 1)
        #expect(bad.pitch == 880)
        #expect(bad.volume == 0.65)
        #expect(bad.swing == 0)
        let clamped = MetronomeSettings(bpm: 5, beatsPerBar: 0, subdivision: 4,
                                        pitch: 6000, volume: 2, swing: 1).sanitized
        #expect(clamped.bpm == 30)
        #expect(clamped.beatsPerBar == 1)
        #expect(clamped.pitch == 1760)
        #expect(clamped.volume == 1)
        #expect(clamped.swing == 0.45)
        for time in [-1, .nan, .infinity, Double.greatestFiniteMagnitude] {
            let snapshot = BeatSnapshot.snapshot(elapsed: time, settings: bad)
            #expect(snapshot.beatPhase.isFinite)
            #expect(snapshot.beatPhase >= 0 && snapshot.beatPhase < 1)
            #expect(snapshot.beatInBar >= 0 && snapshot.beatInBar < 12)
            #expect(snapshot.pulseInBeat == 0)
        }
    }

    @Test
    func oscillatorShowsDerivativeRelationships() {
        let start = PhaseOscillatorState.at(beatPhase: 0, frequency: 2)
        #expect(start.displacement == 1)
        #expect(start.velocity == 0)
        #expect(start.acceleration == -1)
        let quarter = PhaseOscillatorState.at(beatPhase: 0.25, frequency: 2)
        #expect(abs(quarter.displacement) < 1e-12)
        #expect(abs(quarter.velocity + 1) < 1e-12)
        #expect(abs(quarter.velocityPerSecond + 4 * .pi) < 1e-12)
        let half = PhaseOscillatorState.at(beatPhase: 0.5, frequency: 2)
        #expect(half.displacement == -1)
        #expect(half.acceleration == 1)
        #expect(abs(half.accelerationPerSecondSquared - 16 * .pi * .pi) < 1e-12)
        #expect(PhaseOscillatorState.at(beatPhase: .nan).displacement == 1)
    }

    @Test
    func settingsCanRoundTripPersistence() throws {
        let source = MetronomeSettings(bpm: 137, beatsPerBar: 7, subdivision: 3,
                                      pitch: 660, volume: 0.4, soundEnabled: false,
                                      hapticsEnabled: true, swing: 0.2)
        let data = try JSONEncoder().encode(source)
        #expect(try JSONDecoder().decode(MetronomeSettings.self, from: data) == source)
    }
}

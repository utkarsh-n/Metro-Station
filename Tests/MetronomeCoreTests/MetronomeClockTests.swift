import Foundation
import Testing
@testable import MetronomeCore

@Suite("Continuous live transport clock")
struct MetronomeClockTests {
    @Test
    func denseTempoSweepPreservesBeatAndBarPhase() {
        var settings = MetronomeSettings(bpm: 30, beatsPerBar: 4, subdivision: 4, swing: 0.45)
        var clock = MetronomeClockSegment(hostAnchor: 10_000, beatPositionAnchor: 13.375, settings: settings)
        var host = clock.hostAnchor
        for change in 0...140 {
            host += 0.019 + Double(change % 7) * 0.003
            let previousPosition = clock.beatPosition(at: host)
            let previousSnapshot = clock.snapshot(at: host)
            // 30 → 240 → 30, including dozens of scrubbing updates in each direction.
            settings.bpm = 30 + Double(change <= 70 ? change : 140 - change) * 3
            clock = clock.rebased(settings: settings, at: host)
            let updatedSnapshot = clock.snapshot(at: host)
            #expect(clock.beatPosition(at: host) == previousPosition)
            #expect(updatedSnapshot.absoluteBeatPosition == previousSnapshot.absoluteBeatPosition)
            #expect(updatedSnapshot.beatPhase == previousSnapshot.beatPhase)
            #expect(updatedSnapshot.beatInBar == previousSnapshot.beatInBar)
            #expect(updatedSnapshot.barIndex == previousSnapshot.barIndex)
            #expect(updatedSnapshot.pulseInBeat == previousSnapshot.pulseInBeat)
            let futurePosition = clock.beatPosition(at: host + 0.01)
            #expect(abs(futurePosition - previousPosition - settings.bpm / 60 * 0.01) < 1e-10)
            #expect(futurePosition >= previousPosition)
        }
    }

    @Test
    func liveTempoUpdatesKeepOneMonotonicPulseCursor() {
        var settings = MetronomeSettings(bpm: 30, beatsPerBar: 4, subdivision: 4, swing: 0.45)
        let origin = 700_000.0
        var clock = MetronomeClockSegment(hostAnchor: origin, settings: settings)
        var nextIndex = 1 // Beat-zero pulse has already sounded.
        var lastPulseHost = origin
        var firedIndices = [0]
        var downbeats = [0]

        // Exercise the exact segment + integer pulse cursor used by the live audio scheduler.
        for change in 1...180 {
            let updateHost = origin + Double(change) * 0.075
            while clock.pulseHostTime(index: nextIndex) <= updateHost {
                let pulseHost = clock.pulseHostTime(index: nextIndex)
                #expect(pulseHost > lastPulseHost)
                #expect(nextIndex == firedIndices.count)
                #expect(clock.pulseIndex(at: pulseHost) == nextIndex)
                if MetronomeTiming.pulseIsAccent(index: nextIndex, settings: settings) {
                    downbeats.append(nextIndex / (settings.beatsPerBar * settings.subdivision))
                }
                firedIndices.append(nextIndex)
                lastPulseHost = pulseHost
                nextIndex += 1
            }
            let positionBeforeUpdate = clock.beatPosition(at: updateHost)
            let step = change % 140
            settings.bpm = 30 + Double(step <= 70 ? step : 140 - step) * 3
            clock = clock.rebased(settings: settings, at: updateHost)
            #expect(clock.beatPosition(at: updateHost) == positionBeforeUpdate)
            #expect(clock.pulseHostTime(index: nextIndex) > updateHost)
            #expect(clock.nextPulseIndex(after: updateHost) == nextIndex)
        }
        let finish = origin + 18
        while clock.pulseHostTime(index: nextIndex) <= finish {
            let pulseHost = clock.pulseHostTime(index: nextIndex)
            #expect(pulseHost > lastPulseHost)
            #expect(nextIndex == firedIndices.count)
            if MetronomeTiming.pulseIsAccent(index: nextIndex, settings: settings) {
                downbeats.append(nextIndex / (settings.beatsPerBar * settings.subdivision))
            }
            firedIndices.append(nextIndex)
            lastPulseHost = pulseHost
            nextIndex += 1
        }
        #expect(firedIndices.count > 100)
        #expect(firedIndices == Array(0..<firedIndices.count))
        #expect(downbeats == Array(0..<downbeats.count))
        #expect(downbeats.count >= 7)
    }

    @Test
    func alternatingTenthBPMEditsAtEveryAudioBufferNeverReplayPulse() {
        let sampleRate = 48_000.0
        let frameCount = 128
        let origin = 70_000.0
        var settings = MetronomeSettings(bpm: 120, subdivision: 4, swing: 0.45)
        var clock = MetronomeClockSegment(hostAnchor: origin, settings: settings)
        var nextPulse = 0
        var firedIndices: [Int] = []
        var lastOnset = -Double.infinity
        for buffer in 0..<6000 {
            let boundary = origin + Double(buffer * frameCount) / sampleRate
            let position = clock.beatPosition(at: boundary)
            settings.bpm = buffer.isMultiple(of: 2) ? 120 : 120.1
            clock = clock.rebased(settings: settings, at: boundary)
            #expect(clock.beatPosition(at: boundary) == position)
            let lastSampleHost = boundary + Double(frameCount - 1) / sampleRate
            while clock.pulseHostTime(index: nextPulse) <= lastSampleHost {
                let onset = clock.pulseHostTime(index: nextPulse)
                #expect(nextPulse == firedIndices.count)
                #expect(onset > lastOnset)
                #expect(clock.pulseIndex(at: onset) == nextPulse)
                // A pulse between buffers can be at most one sample old, never a replayed beat.
                #expect(onset >= boundary - 1 / sampleRate - 1e-10)
                firedIndices.append(nextPulse)
                lastOnset = onset
                nextPulse += 1
            }
        }
        #expect(firedIndices.count >= 128)
        #expect(firedIndices == Array(0..<firedIndices.count))
        let downbeats = firedIndices.filter { $0.isMultiple(of: 16) }.map { $0 / 16 }
        #expect(downbeats == Array(0..<downbeats.count))
    }

    @Test(arguments: [1, 2, 3, 4])
    func swingLivesInBeatSpaceAndMapsToHostTime(subdivision: Int) {
        let settings = MetronomeSettings(bpm: 73, subdivision: subdivision, swing: 0.4)
        let clock = MetronomeClockSegment(hostAnchor: 864_000, beatPositionAnchor: 3.125, settings: settings)
        for index in (4 * subdivision)..<(20 * subdivision) {
            let position = MetronomeTiming.pulseBeatPosition(index: index, settings: settings)
            let delay = subdivision.isMultiple(of: 2) && !index.isMultiple(of: 2) ? 0.4 : 0
            #expect(abs(position - (Double(index) + delay) / Double(subdivision)) < 1e-12)
            #expect(MetronomeTiming.pulseIndex(beatPosition: position, settings: settings) == index)
            let host = clock.pulseHostTime(index: index)
            #expect(clock.pulseIndex(at: host) == index)
            #expect(clock.nextPulseIndex(after: host) == index + 1)
            #expect(abs(clock.beatPosition(at: host) - position) < 1e-9)
            let beatDuration = MetronomeTiming.pulseBeatDuration(index: index, settings: settings)
            #expect(beatDuration > 0)
            #expect(abs(clock.pulseHostTime(index: index + 1) - host - beatDuration * 60 / 73) < 1e-9)
        }
    }

    @Test
    func meterChangePreservesAbsolutePositionAndElapsedIsIndependent() {
        var settings = MetronomeSettings(beatsPerBar: 4)
        let clock = MetronomeClockSegment(hostAnchor: 100, beatPositionAnchor: 13.375, settings: settings)
        let old = clock.snapshot(at: 100, elapsed: 17.25)
        #expect(old.barIndex == 3 && old.beatInBar == 1)
        settings.beatsPerBar = 7
        let rebased = clock.rebased(settings: settings, at: 100)
        let new = rebased.snapshot(at: 100, elapsed: 17.25)
        #expect(new.barIndex == 1 && new.beatInBar == 6)
        #expect(new.absoluteBeatPosition == old.absoluteBeatPosition)
        #expect(new.beatPhase == 0.375)
        #expect(new.elapsed == 17.25)
    }

    @Test
    func soundedTickMetadataKeepsRealAgeAndPitchAcrossTempoAndPitchChanges() {
        let start = 100.0
        let oldSettings = MetronomeSettings(bpm: 120, pitch: 440)
        let initial = MetronomeClockSegment(hostAnchor: start, settings: oldSettings)
        let updated = initial.rebased(settings: MetronomeSettings(bpm: 240, pitch: 1760), at: start + 0.02)
        let now = start + 0.04
        let snapshot = updated.snapshot(at: now, elapsed: 0.04, absolutePulseIndex: 0,
                                        tickElapsed: now - start, tickFrequency: 440,
                                        tickAccent: true, tickStrength: 1)
        #expect(abs(snapshot.absoluteBeatPosition - 0.12) < 1e-12)
        #expect(abs(snapshot.tickElapsed! - 0.04) < 1e-12)
        #expect(snapshot.tickFrequency == 440)
        #expect(snapshot.tickAccent == true && snapshot.tickStrength == 1)
        #expect(snapshot.absolutePulseIndex == 0)
        // Beat distance / current tempo would invent 30 ms and prematurely move the scope cursor.
        #expect(abs(snapshot.absoluteBeatPosition * updated.settings.beatDuration - snapshot.tickElapsed!) > 0.009)
        let unknown = updated.snapshot(at: now)
        #expect(unknown.tickElapsed == nil && unknown.tickFrequency == nil)
        let badMetadata = updated.snapshot(at: now, absolutePulseIndex: -1,
                                           tickElapsed: .nan, tickFrequency: .infinity,
                                           tickStrength: -3)
        #expect(badMetadata.absolutePulseIndex == 0)
        #expect(badMetadata.tickElapsed == nil && badMetadata.tickFrequency == nil)
        #expect(badMetadata.tickStrength == 0)
        let fixedTempo = BeatSnapshot.snapshot(elapsed: 0.01, settings: oldSettings)
        #expect(fixedTempo.tickStrength == oldSettings.volume)
        let silent = BeatSnapshot.snapshot(elapsed: 0.01, settings: MetronomeSettings(soundEnabled: false))
        #expect(silent.tickStrength == 0)
    }

    @Test
    func invalidClockInputIsFiniteAndSanitized() {
        let clock = MetronomeClockSegment(hostAnchor: .nan, beatPositionAnchor: .infinity,
                                          settings: MetronomeSettings(bpm: .nan))
        #expect(clock.hostAnchor == 0)
        #expect(clock.beatPositionAnchor == 0)
        #expect(clock.settings.bpm == 120)
        #expect(clock.beatPosition(at: .nan) == 0)
        #expect(clock.beatPosition(at: -10) == 0)
        #expect(clock.hostTime(forBeatPosition: .nan) == 0)
        #expect(clock.beatPosition(at: .greatestFiniteMagnitude).isFinite)
        let rebased = clock.rebased(settings: MetronomeSettings(bpm: 999), at: .infinity)
        #expect(rebased.hostAnchor == 0 && rebased.beatPositionAnchor == 0)
        #expect(rebased.settings.bpm == 240)
    }
}

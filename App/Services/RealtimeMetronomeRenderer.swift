import AVFoundation
import Foundation
import MetronomeCore
import Synchronization

/// Atomic scalar fields plus an even/odd sequence form a coherent mailbox.
/// A read takes at most two attempts and never waits for the writer.
nonisolated final class RealtimeMetronomeMailbox: Sendable {
    private let sequence = Atomic<UInt64>(0)
    private let host = Atomic<UInt64>(0)
    private let position = Atomic<UInt64>(0)
    private let applied = Atomic<UInt64>(0)
    private let bpm = Atomic<UInt64>(120.0.bitPattern)
    private let meter = Atomic<UInt64>(4)
    private let subdivision = Atomic<UInt64>(1)
    private let pitch = Atomic<UInt64>(880.0.bitPattern)
    private let volume = Atomic<UInt64>(0.65.bitPattern)
    private let flags = Atomic<UInt64>(3)
    private let swing = Atomic<UInt64>(0)
    private let tickOnset = Atomic<UInt64>((-Double.infinity).bitPattern)
    private let tickIndex = Atomic<UInt64>(0)
    private let tickFrequency = Atomic<UInt64>(880.0.bitPattern)
    private let tickFlags = Atomic<UInt64>(0)
    private let tickStrength = Atomic<UInt64>(0)
    private let previousOnset = Atomic<UInt64>((-Double.infinity).bitPattern)
    private let previousIndex = Atomic<UInt64>(0)
    private let previousFrequency = Atomic<UInt64>(880.0.bitPattern)
    private let previousFlags = Atomic<UInt64>(0)
    private let previousStrength = Atomic<UInt64>(0)
    private let gainHost = Atomic<UInt64>(0)
    private let gainStart = Atomic<UInt64>(0)
    private let gainTarget = Atomic<UInt64>(0)

    @discardableResult
    func publish(settings: MetronomeSettings, hostAnchor: Double = 0,
                 beatPosition: Double = 0, appliedRevision: UInt64 = 0,
                 tick: RealtimePresentedTick = .init(), previousTick: RealtimePresentedTick = .init(),
                 gain: RealtimeGainEnvelope = .init()) -> UInt64 {
        let previous = sequence.load(ordering: .sequentiallyConsistent)
        sequence.store(previous &+ 1, ordering: .sequentiallyConsistent)
        host.store(hostAnchor.bitPattern, ordering: .sequentiallyConsistent)
        position.store(beatPosition.bitPattern, ordering: .sequentiallyConsistent)
        applied.store(appliedRevision, ordering: .sequentiallyConsistent)
        bpm.store(settings.bpm.bitPattern, ordering: .sequentiallyConsistent)
        meter.store(UInt64(settings.beatsPerBar), ordering: .sequentiallyConsistent)
        subdivision.store(UInt64(settings.subdivision), ordering: .sequentiallyConsistent)
        pitch.store(settings.pitch.bitPattern, ordering: .sequentiallyConsistent)
        volume.store(settings.volume.bitPattern, ordering: .sequentiallyConsistent)
        flags.store((settings.soundEnabled ? 1 : 0) | (settings.hapticsEnabled ? 2 : 0), ordering: .sequentiallyConsistent)
        swing.store(settings.swing.bitPattern, ordering: .sequentiallyConsistent)
        tickOnset.store(tick.onset.bitPattern, ordering: .sequentiallyConsistent)
        tickIndex.store(UInt64(tick.index), ordering: .sequentiallyConsistent)
        tickFrequency.store(tick.frequency.bitPattern, ordering: .sequentiallyConsistent)
        tickFlags.store(tick.accent ? 1 : 0, ordering: .sequentiallyConsistent)
        tickStrength.store(tick.strength.bitPattern, ordering: .sequentiallyConsistent)
        previousOnset.store(previousTick.onset.bitPattern, ordering: .sequentiallyConsistent)
        previousIndex.store(UInt64(previousTick.index), ordering: .sequentiallyConsistent)
        previousFrequency.store(previousTick.frequency.bitPattern, ordering: .sequentiallyConsistent)
        previousFlags.store(previousTick.accent ? 1 : 0, ordering: .sequentiallyConsistent)
        previousStrength.store(previousTick.strength.bitPattern, ordering: .sequentiallyConsistent)
        gainHost.store(gain.startHost.bitPattern, ordering: .sequentiallyConsistent)
        gainStart.store(gain.startGain.bitPattern, ordering: .sequentiallyConsistent)
        gainTarget.store(gain.targetGain.bitPattern, ordering: .sequentiallyConsistent)
        sequence.store(previous &+ 2, ordering: .sequentiallyConsistent)
        return previous &+ 2
    }

    func read() -> RealtimeMetronomeState? {
        for _ in 0..<2 {
            let before = sequence.load(ordering: .sequentiallyConsistent)
            guard before != 0, before.isMultiple(of: 2) else { continue }
            let hostValue = host.load(ordering: .sequentiallyConsistent)
            let positionValue = position.load(ordering: .sequentiallyConsistent)
            let appliedValue = applied.load(ordering: .sequentiallyConsistent)
            let bpmValue = bpm.load(ordering: .sequentiallyConsistent)
            let meterValue = meter.load(ordering: .sequentiallyConsistent)
            let subdivisionValue = subdivision.load(ordering: .sequentiallyConsistent)
            let pitchValue = pitch.load(ordering: .sequentiallyConsistent)
            let volumeValue = volume.load(ordering: .sequentiallyConsistent)
            let flagsValue = flags.load(ordering: .sequentiallyConsistent)
            let swingValue = swing.load(ordering: .sequentiallyConsistent)
            let onsetValue = tickOnset.load(ordering: .sequentiallyConsistent)
            let tickIndexValue = tickIndex.load(ordering: .sequentiallyConsistent)
            let tickFrequencyValue = tickFrequency.load(ordering: .sequentiallyConsistent)
            let tickFlagsValue = tickFlags.load(ordering: .sequentiallyConsistent)
            let tickStrengthValue = tickStrength.load(ordering: .sequentiallyConsistent)
            let previousOnsetValue = previousOnset.load(ordering: .sequentiallyConsistent)
            let previousIndexValue = previousIndex.load(ordering: .sequentiallyConsistent)
            let previousFrequencyValue = previousFrequency.load(ordering: .sequentiallyConsistent)
            let previousFlagsValue = previousFlags.load(ordering: .sequentiallyConsistent)
            let previousStrengthValue = previousStrength.load(ordering: .sequentiallyConsistent)
            let gainHostValue = gainHost.load(ordering: .sequentiallyConsistent)
            let gainStartValue = gainStart.load(ordering: .sequentiallyConsistent)
            let gainTargetValue = gainTarget.load(ordering: .sequentiallyConsistent)
            let after = sequence.load(ordering: .sequentiallyConsistent)
            guard before == after else { continue }
            let settings = MetronomeSettings(
                bpm: Double(bitPattern: bpmValue), beatsPerBar: Int(meterValue),
                subdivision: Int(subdivisionValue), pitch: Double(bitPattern: pitchValue),
                volume: Double(bitPattern: volumeValue), soundEnabled: flagsValue & 1 != 0,
                hapticsEnabled: flagsValue & 2 != 0, swing: Double(bitPattern: swingValue)
            )
            return RealtimeMetronomeState(
                revision: after, appliedRevision: appliedValue,
                segment: MetronomeClockSegment(hostAnchor: Double(bitPattern: hostValue),
                                               beatPositionAnchor: Double(bitPattern: positionValue),
                                               settings: settings),
                tick: RealtimePresentedTick(onset: Double(bitPattern: onsetValue), index: Int(tickIndexValue),
                    frequency: Double(bitPattern: tickFrequencyValue), accent: tickFlagsValue != 0,
                    strength: Double(bitPattern: tickStrengthValue)),
                previousTick: RealtimePresentedTick(onset: Double(bitPattern: previousOnsetValue), index: Int(previousIndexValue),
                    frequency: Double(bitPattern: previousFrequencyValue), accent: previousFlagsValue != 0,
                    strength: Double(bitPattern: previousStrengthValue)),
                gain: RealtimeGainEnvelope(startHost: Double(bitPattern: gainHostValue),
                    startGain: Double(bitPattern: gainStartValue), targetGain: Double(bitPattern: gainTargetValue))
            )
        }
        return nil
    }
}

nonisolated struct RealtimeMetronomeState: Sendable {
    let revision: UInt64
    let appliedRevision: UInt64
    let segment: MetronomeClockSegment
    let tick: RealtimePresentedTick
    let previousTick: RealtimePresentedTick
    let gain: RealtimeGainEnvelope

    func presentedTick(at host: Double) -> RealtimePresentedTick? {
        if tick.onset.isFinite, tick.onset <= host { return tick }
        if previousTick.onset.isFinite, previousTick.onset <= host { return previousTick }
        return nil
    }
}

nonisolated struct RealtimePresentedTick: Sendable {
    var onset: Double = -.infinity
    var index: Int = 0
    var frequency: Double = 880
    var accent: Bool = false
    var strength: Double = 0
}

nonisolated struct RealtimeGainEnvelope: Sendable {
    var startHost: Double = 0
    var startGain: Double = 0
    var targetGain: Double = 0

    func value(at host: Double) -> Double {
        let progress = min(1, max(0, (host - startHost) / 0.008))
        return startGain + (targetGain - startGain) * progress
    }
}

/// Mutable transport and voices belong exclusively to the serial audio render thread.
/// Other threads communicate through the two atomic mailboxes and the atomic initial arm.
nonisolated final class RealtimeMetronomeRenderer: @unchecked Sendable {
    let commands = RealtimeMetronomeMailbox()
    let telemetry = RealtimeMetronomeMailbox()
    let previousTelemetry = RealtimeMetronomeMailbox()
    private let history: [RealtimeMetronomeMailbox] = (0..<64).map { _ in RealtimeMetronomeMailbox() }
    private let historyCount = Atomic<UInt64>(0)
    let sampleRate: Double
    private let initialHostTime = Atomic<UInt64>(0)
    private var clock: MetronomeClockSegment?
    private var appliedRevision: UInt64 = 0
    private var nextPulse = 0
    private var hasEmittedInitialPulse = false
    private var gainEnvelope = RealtimeGainEnvelope()
    private var latestTick = RealtimePresentedTick()
    private var precedingTick = RealtimePresentedTick()
    private var voiceA = RenderTickVoice()
    private var voiceB = RenderTickVoice()
    private var voiceC = RenderTickVoice()
    private var voiceD = RenderTickVoice()
    private var nextVoice = 0
    #if DEBUG
    // Assigned only before the source is attached/started, then immutable during a run.
    private var physicalAudioAudit: PhysicalAudioAudit?
    func attachPhysicalAudioAudit(_ audit: PhysicalAudioAudit) {
        physicalAudioAudit = audit
    }
    #endif

    init(settings: MetronomeSettings, sampleRate: Double) {
        self.sampleRate = sampleRate
        commands.publish(settings: settings)
    }

    func arm(startHostSeconds: Double) {
        initialHostTime.store(AVAudioTime.hostTime(forSeconds: startHostSeconds), ordering: .releasing)
    }

    func publish(settings: MetronomeSettings) {
        commands.publish(settings: settings)
    }

    /// HAL timestamps can be ahead of the UI clock. A preallocated history lets
    /// presentation follow the segment actually in force now, even across several
    /// rapid edits, without projecting a future BPM backwards.
    func presentationState(at host: Double) -> RealtimeMetronomeState? {
        if let latest = telemetry.read(), latest.segment.hostAnchor <= host,
           latest.presentedTick(at: host) != nil || !latest.tick.onset.isFinite {
            return latest
        }
        let count = historyCount.load(ordering: .acquiring)
        guard count > 0 else { return nil }
        for offset in 0..<min(64, Int(count)) {
            let index = Int((count - 1 - UInt64(offset)) % 64)
            guard let candidate = history[index].read(), candidate.segment.hostAnchor <= host else { continue }
            if candidate.presentedTick(at: host) != nil || !candidate.tick.onset.isFinite { return candidate }
        }
        return nil
    }

    /// A future render segment must not retime pulses that precede its anchor.
    /// Resolve their timestamp from the piece of clock owning that beat position.
    func clock(forBeatPosition position: Double) -> MetronomeClockSegment? {
        let count = historyCount.load(ordering: .acquiring)
        guard count > 0 else { return nil }
        for offset in 0..<min(64, Int(count)) {
            let index = Int((count - 1 - UInt64(offset)) % 64)
            guard let candidate = history[index].read(),
                  candidate.segment.beatPositionAnchor <= position else { continue }
            return candidate.segment
        }
        return nil
    }

    // The legacy SourceNode block is NS_SWIFT_NONSENDABLE. Construct it here,
    // outside MainActor, and keep the callback explicitly Sendable.
    func makeSource(format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { @Sendable [self] silence, timestamp, frameCount, output in
            render(silence: silence, timestamp: timestamp, frameCount: frameCount, output: output)
        }
    }

    private func render(silence: UnsafeMutablePointer<ObjCBool>,
                        timestamp: UnsafePointer<AudioTimeStamp>,
                        frameCount: AVAudioFrameCount,
                        output: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        #if DEBUG
        let audit = physicalAudioAudit
        let auditStart = audit?.beginRender(timestamp: timestamp.pointee,
                                           frames: Int(frameCount), sampleRate: sampleRate)
        defer {
            if let auditStart {
                audit?.endRender(began: auditStart, frames: Int(frameCount), sampleRate: sampleRate)
            }
        }
        #endif
        let buffers = UnsafeMutableAudioBufferListPointer(output)
        let initialHost = initialHostTime.load(ordering: .acquiring)
        guard initialHost != 0, timestamp.pointee.mFlags.contains(.hostTimeValid) else {
            clear(buffers)
            silence.pointee = true
            return noErr
        }
        let runAnchor = AVAudioTime.seconds(forHostTime: initialHost)
        let bufferHost = AVAudioTime.seconds(forHostTime: timestamp.pointee.mHostTime)

        if let command = commands.read(), command.revision != appliedRevision {
            let previous = clock
            let boundary = max(runAnchor, bufferHost)
            let replacement = previous?.rebased(settings: command.segment.settings, at: boundary)
                ?? MetronomeClockSegment(hostAnchor: runAnchor, settings: command.segment.settings)
            if let previous {
                publishTelemetry(to: previousTelemetry, clock: previous)
            }
            if let previous, hasEmittedInitialPulse,
               previous.settings.subdivision != replacement.settings.subdivision ||
               previous.settings.swing != replacement.settings.swing {
                // Topology edits affect future pulses; they never replay an onset.
                nextPulse = replacement.nextPulseIndex(after: boundary)
            }
            clock = replacement
            appliedRevision = command.revision
            #if DEBUG
            if auditStart != nil { audit?.recordCommand(clock: replacement, revision: appliedRevision) }
            #endif
            let newGain = replacement.settings.soundEnabled ? replacement.settings.volume : 0
            if previous == nil {
                // There are no sounding voices at startup, so preserve the tick's
                // own attack rather than fading the initial downbeat twice.
                gainEnvelope = RealtimeGainEnvelope(startHost: runAnchor, startGain: newGain, targetGain: newGain)
            } else if newGain != gainEnvelope.targetGain {
                gainEnvelope = RealtimeGainEnvelope(startHost: boundary,
                    startGain: gainEnvelope.value(at: boundary), targetGain: newGain)
            }
            publishTelemetry(to: telemetry, clock: replacement)
        }

        guard let clock else {
            clear(buffers)
            silence.pointee = true
            return noErr
        }
        // Recover from dropped render time without replaying an old beat burst.
        if clock.pulseHostTime(index: nextPulse) < bufferHost - TickSynthesis.duration {
            let recoveredPulse = clock.nextPulseIndex(after: bufferHost - TickSynthesis.duration)
            #if DEBUG
            if auditStart != nil { audit?.recordRecovery(skippedPulses: recoveredPulse - nextPulse) }
            #endif
            nextPulse = recoveredPulse
        }
        var nextOnset = clock.pulseHostTime(index: nextPulse)
        let sampleDuration = 1 / sampleRate
        var containsSignal = false

        for frame in 0..<Int(frameCount) {
            let hostTime = bufferHost + Double(frame) * sampleDuration
            if hostTime >= runAnchor {
                while hostTime >= nextOnset {
                    let voice = RenderTickVoice(
                        onset: nextOnset, frequency: clock.settings.pitch,
                        accent: MetronomeTiming.pulseIsAccent(index: nextPulse, settings: clock.settings),
                        strength: MetronomeTiming.pulseStrength(index: nextPulse, settings: clock.settings)
                    )
                    switch nextVoice {
                    case 0: voiceA = voice
                    case 1: voiceB = voice
                    case 2: voiceC = voice
                    default: voiceD = voice
                    }
                    nextVoice = (nextVoice + 1) % 4
                    hasEmittedInitialPulse = true
                    precedingTick = latestTick
                    latestTick = RealtimePresentedTick(onset: nextOnset, index: nextPulse,
                        frequency: clock.settings.pitch, accent: voice.accent, strength: voice.strength)
                    #if DEBUG
                    if auditStart != nil {
                        audit?.recordPulse(index: nextPulse, onset: nextOnset, renderedAt: hostTime,
                            frequency: voice.frequency, accent: voice.accent, strength: voice.strength,
                            gain: gainEnvelope.value(at: hostTime), sampleRate: sampleRate)
                    }
                    #endif
                    publishTelemetry(to: telemetry, clock: clock)
                    nextPulse += 1
                    nextOnset = clock.pulseHostTime(index: nextPulse)
                }
            }
            // Each voice retains the pitch and complete envelope of its own onset.
            let mix = voiceA.sample(at: hostTime, sampleRate: sampleRate)
                + voiceB.sample(at: hostTime, sampleRate: sampleRate)
                + voiceC.sample(at: hostTime, sampleRate: sampleRate)
                + voiceD.sample(at: hostTime, sampleRate: sampleRate)
            let rawValue = mix * gainEnvelope.value(at: hostTime)
            #if DEBUG
            if auditStart != nil { audit?.recordRawSample(rawValue) }
            #endif
            let value = Float(min(1, max(-1, rawValue)))
            containsSignal = containsSignal || value != 0
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = value
            }
        }
        silence.pointee = ObjCBool(!containsSignal)
        return noErr
    }

    private func clear(_ buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }
    }

    private func publishTelemetry(to mailbox: RealtimeMetronomeMailbox, clock: MetronomeClockSegment) {
        mailbox.publish(settings: clock.settings, hostAnchor: clock.hostAnchor,
            beatPosition: clock.beatPositionAnchor, appliedRevision: appliedRevision,
            tick: latestTick, previousTick: precedingTick, gain: gainEnvelope)
        if mailbox === telemetry {
            let count = historyCount.load(ordering: .relaxed)
            history[Int(count % 64)].publish(settings: clock.settings, hostAnchor: clock.hostAnchor,
                beatPosition: clock.beatPositionAnchor, appliedRevision: appliedRevision,
                tick: latestTick, previousTick: precedingTick, gain: gainEnvelope)
            historyCount.store(count &+ 1, ordering: .releasing)
        }
    }
}

nonisolated private struct RenderTickVoice {
    var onset: Double = -.infinity
    var frequency = 880.0
    var accent = false
    var strength = 0.0

    func sample(at hostTime: Double, sampleRate: Double) -> Double {
        let time = hostTime - onset
        guard strength > 0, time >= 0, time < TickSynthesis.duration else { return 0 }
        return TickSynthesis.sample(at: time, frequency: frequency,
                                    accent: accent, sampleRate: sampleRate) * strength
    }
}


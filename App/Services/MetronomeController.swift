import AVFoundation
import CoreHaptics
import Foundation
import Observation
import MetronomeCore
import UIKit

/// The audio thread owns the transport. UI edits travel through a bounded atomic
/// mailbox, preserving phase and sounding tick envelopes without rebuilding engines.
@MainActor
@Observable
final class MetronomeController {
    private var selectedSettings = MetronomeSettings()
    var settings: MetronomeSettings {
        get { selectedSettings }
        set {
            let normalized = Self.normalizedSettings(newValue)
            guard normalized != selectedSettings else { return }
            selectedSettings = normalized
            schedulePersistence()
            if isRunning {
                renderer?.publish(settings: normalized)
            } else {
                runningSettings = normalized
            }
            updateStatuses()
        }
    }

    private(set) var isRunning = false
    var errorMessage: String?
    private(set) var hapticStatus = "Checking device"
    private(set) var soundStatus = "Ready"
    var effectiveSettings: MetronomeSettings { isRunning ? runningSettings : settings }
    var isApplyingSettings: Bool { isRunning && settings != effectiveSettings }

    private var runningSettings = MetronomeSettings()
    @ObservationIgnored private var renderer: RealtimeMetronomeRenderer?
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    #if DEBUG
    @ObservationIgnored private var physicalAudioAudit: PhysicalAudioAudit?
    @ObservationIgnored private var physicalAudioRun = 0
    private(set) var physicalAudioExportStatus = "idle"
    #endif
    @ObservationIgnored private var hapticEngine: CHHapticEngine?
    @ObservationIgnored private var transportTimer: Timer?
    @ObservationIgnored private var beatPlayers: [ScheduledHaptic] = []
    @ObservationIgnored private var detentPlayers: [TempoDetent: any CHHapticPatternPlayer] = [:]
    @ObservationIgnored private var beatPatternCache: [BeatHapticPatternKey: CHHapticPattern] = [:]
    @ObservationIgnored private var nextHapticPulse = 0
    @ObservationIgnored private var lastAcknowledgedRevision: UInt64 = 0
    @ObservationIgnored private var hapticClockOffset = 0.0
    @ObservationIgnored private var runAnchor = 0.0
    @ObservationIgnored private var runningClock: MetronomeClockSegment?
    @ObservationIgnored private var acknowledgedSettings = MetronomeSettings()
    @ObservationIgnored private var pausedBeatPosition = 0.0
    @ObservationIgnored private var pausedElapsed = 0.0
    @ObservationIgnored private var tapTracker = TapTempoTracker()
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var audioConfigurationToken: NSObjectProtocol?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var persistenceTask: Task<Void, Never>?
    @ObservationIgnored private var isScrubbing = false
    @ObservationIgnored private var lastDetentTime = -Double.infinity
    @ObservationIgnored private let upwardDetent = UIImpactFeedbackGenerator(style: .rigid)
    @ObservationIgnored private let downwardDetent = UIImpactFeedbackGenerator(style: .heavy)
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persistenceEnabled: Bool

    private static let settingsKey = "spectral.metronome.settings.v1"
    private static let launchLeadTime = 0.12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        persistenceEnabled = !ProcessInfo.processInfo.arguments.contains("--uitesting")
        if persistenceEnabled, let data = defaults.data(forKey: Self.settingsKey),
           let restored = try? JSONDecoder().decode(MetronomeSettings.self, from: data) {
            selectedSettings = Self.normalizedSettings(restored)
        } else {
            selectedSettings = Self.normalizedSettings(MetronomeSettings())
        }
        runningSettings = settings
        acknowledgedSettings = settings
        updateStatuses()
        observeAudioSession()
    }

    isolated deinit {
        stop()
        persistenceTask?.cancel()
        for token in notificationTokens { NotificationCenter.default.removeObserver(token) }
    }

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        settings = Self.normalizedSettings(settings)
        errorMessage = nil
        pausedElapsed = 0
        pausedBeatPosition = 0
        nextHapticPulse = 0
        lastAcknowledgedRevision = 0
        runningSettings = settings
        acknowledgedSettings = settings
        generation = UUID()
        let currentGeneration = generation

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setPreferredSampleRate(48_000)
            try? session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)

            // Keep both transports available for the entire run. Output switches
            // become gain/scheduling changes, never audio-session reconfiguration.
            prepareHaptics(session: session, generation: currentGeneration)
            let engine = AVAudioEngine()
            let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            guard sampleRate > 0,
                  let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                throw PlaybackError.noAudioOutput
            }
            let newRenderer = RealtimeMetronomeRenderer(settings: settings, sampleRate: sampleRate)
            let source = newRenderer.makeSource(format: format)
            engine.attach(source)
            try engine.connectNode(source, to: engine.mainMixerNode, format: format)
            engine.prepare()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--physical-qa") {
                physicalAudioRun += 1
                let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
                let audit = PhysicalAudioAudit(sampleRate: mixerFormat.sampleRate,
                    channels: Int(mixerFormat.channelCount), run: physicalAudioRun,
                    metadata: PhysicalAudioAudit.metadata(settings: settings))
                physicalAudioAudit = audit
                physicalAudioExportStatus = "capturing"
                newRenderer.attachPhysicalAudioAudit(audit)
                audit.installTap(on: engine.mainMixerNode)
            }
            #endif
            renderer = newRenderer
            audioEngine = engine
            try engine.start()
            observeConfiguration(of: engine, generation: currentGeneration)

            runAnchor = Self.hostSeconds() + Self.launchLeadTime
            runningClock = MetronomeClockSegment(hostAnchor: runAnchor, settings: settings)
            newRenderer.arm(startHostSeconds: runAnchor)
            calibrateHapticClock()
            isRunning = true
            UIApplication.shared.isIdleTimerDisabled = true
            updateStatuses()
            refreshTransport()
            let timer = Timer(timeInterval: 0.02, repeats: true) { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshTransport() }
            }
            timer.tolerance = 0.002
            RunLoop.main.add(timer, forMode: .common)
            transportTimer = timer
        } catch {
            stop()
            errorMessage = "Unable to start audio: \(error.localizedDescription)"
            soundStatus = "Audio unavailable"
        }
    }

    func stop() {
        #if DEBUG
        physicalAudioAudit?.closeCapture(metadata: PhysicalAudioAudit.metadata(settings: settings))
        #endif
        if isRunning {
            let host = Self.hostSeconds()
            let clock = renderer?.presentationState(at: host)?.segment ?? runningClock
            pausedBeatPosition = clock?.beatPosition(at: host) ?? 0
            pausedElapsed = max(0, host - runAnchor)
        }
        isRunning = false
        generation = UUID()
        transportTimer?.invalidate()
        transportTimer = nil
        cancelBeatPatterns()
        discardDetentPlayers()
        beatPatternCache.removeAll()
        hapticEngine?.stoppedHandler = { @Sendable _ in }
        hapticEngine?.resetHandler = { @Sendable in }
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        if let audioConfigurationToken {
            NotificationCenter.default.removeObserver(audioConfigurationToken)
            self.audioConfigurationToken = nil
        }
        audioEngine?.stop()
        #if DEBUG
        if let physicalAudioAudit {
            if let mixer = audioEngine?.mainMixerNode { physicalAudioAudit.removeTap(from: mixer) }
            physicalAudioExportStatus = "exporting"
            physicalAudioAudit.exportAfterStop { @Sendable [weak self] result in
                Task { @MainActor [weak self] in
                    self?.physicalAudioExportStatus = result.error == nil ? "complete" : "failed"
                }
            }
        }
        physicalAudioAudit = nil
        #endif
        audioEngine?.reset()
        audioEngine = nil
        renderer = nil
        runningClock = nil
        runningSettings = settings
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        persistenceTask?.cancel()
        persistenceTask = nil
        persistSettings()
        updateStatuses()
    }

    func changeTempo(by amount: Double) {
        guard amount.isFinite else { return }
        settings.bpm = TempoAdjustment.wholeBPM(settings.bpm + amount)
    }

    func stepTempo(direction: Int) {
        guard direction != 0 else { return }
        applyTempo(TempoAdjustment.wholeBPM(settings.bpm + (direction > 0 ? 1 : -1)),
                   marking: false)
    }

    func stepTempoMarking(direction: Int) {
        guard direction != 0 else { return }
        applyTempo(TempoAdjustment.nextMarkingBPM(from: settings.bpm, direction: direction),
                   marking: true)
    }

    func beginScrub() {
        isScrubbing = true
        persistenceTask?.cancel()
        persistenceTask = nil
        upwardDetent.prepare()
        downwardDetent.prepare()
    }

    func endScrub() {
        isScrubbing = false
        persistenceTask?.cancel()
        persistenceTask = nil
        persistSettings()
    }

    func scrubTempo(to value: Double) {
        guard value.isFinite else { return }
        applyTempo(TempoAdjustment.wholeBPM(value), marking: false)
    }

    func tapTempo() {
        if let bpm = tapTracker.tap(at: Self.hostSeconds()) { settings.bpm = TempoAdjustment.wholeBPM(bpm) }
    }

    private func applyTempo(_ value: Double, marking: Bool) {
        let previous = settings.bpm
        let next = TempoAdjustment.wholeBPM(value)
        guard next != previous else { return }
        settings.bpm = next
        playTempoDetent(increasing: next > previous, marking: marking)
    }

    func snapshot(at _: Date) -> BeatSnapshot {
        let host = Self.hostSeconds()
        if isRunning, let state = renderer?.presentationState(at: host) {
            let elapsed = max(0, host - runAnchor)
            let tick = state.presentedTick(at: host)
            return state.segment.snapshot(
                at: host, elapsed: elapsed,
                absolutePulseIndex: tick?.index,
                tickElapsed: tick.map { host - $0.onset },
                tickFrequency: tick?.frequency,
                tickAccent: tick?.accent,
                tickStrength: tick.map { $0.strength * state.gain.value(at: host) }
            )
        }
        if isRunning, let runningClock {
            return runningClock.snapshot(at: host, elapsed: max(0, host - runAnchor))
        }
        return BeatSnapshot.snapshot(beatPosition: pausedBeatPosition,
                                     elapsed: pausedElapsed, settings: settings)
    }

    private func refreshTransport() {
        guard isRunning else { return }
        let host = Self.hostSeconds()
        if let state = renderer?.telemetry.read() {
            runningClock = state.segment
            if state.appliedRevision != lastAcknowledgedRevision {
                let previous = acknowledgedSettings
                acknowledgedSettings = state.segment.settings
                if previous.bpm != acknowledgedSettings.bpm ||
                    previous.beatsPerBar != acknowledgedSettings.beatsPerBar ||
                    previous.subdivision != acknowledgedSettings.subdivision ||
                    previous.swing != acknowledgedSettings.swing ||
                    previous.pitch != acknowledgedSettings.pitch ||
                    previous.hapticsEnabled != acknowledgedSettings.hapticsEnabled {
                    replanBeatPatterns(clock: state.segment, hostNow: host)
                }
                lastAcknowledgedRevision = state.appliedRevision
            }
        }
        if let presented = renderer?.presentationState(at: host), runningSettings != presented.segment.settings {
            runningSettings = presented.segment.settings
            updateStatuses()
        }
        beatPlayers.removeAll { $0.finishHostSeconds < host - 0.02 }
        scheduleBeatHaptics(hostNow: host)
    }

    private func scheduleBeatHaptics(hostNow: Double) {
        guard acknowledgedSettings.hapticsEnabled, let engine = hapticEngine,
              let clock = runningClock else { return }
        let settings = clock.settings
        let presentedClock = renderer?.presentationState(at: hostNow)?.segment
        let cursorClock = presentedClock?.settings.subdivision == clock.settings.subdivision ? (presentedClock ?? clock) : clock
        let latestDue = cursorClock.pulseIndex(at: hostNow)
        nextHapticPulse = max(nextHapticPulse, latestDue)
        let horizon = hostNow + 0.14
        while true {
            let beatPosition = MetronomeTiming.pulseBeatPosition(index: nextHapticPulse, settings: settings)
            let eventClock = renderer?.clock(forBeatPosition: beatPosition) ?? clock
            let eventHost = eventClock.hostTime(forBeatPosition: beatPosition)
            guard eventHost < horizon else { break }
            let pulse = nextHapticPulse
            nextHapticPulse += 1
            guard eventHost > hostNow - 0.003 else { continue }
            let pulseSettings = eventClock.settings
            let key = BeatHapticPatternKey(pulse: pulse, settings: pulseSettings)
            do {
                let player = try engine.makePlayer(with: beatPattern(for: key))
                let start = eventHost > Self.hostSeconds() + 0.003
                    ? eventHost + hapticClockOffset : CHHapticTimeImmediate
                try player.start(atTime: start)
                beatPlayers.append(ScheduledHaptic(player: player, finishHostSeconds: eventHost + 0.08,
                    onsetHostSeconds: eventHost, pulseIndex: pulse, subdivision: settings.subdivision,
                    patternKey: key))
            } catch {
                // A haptic failure never tears down a working audio transport.
                hapticStatus = "Haptics temporarily unavailable"
            }
        }
    }

    private func replanBeatPatterns(clock: MetronomeClockSegment, hostNow: Double) {
        var retained: [ScheduledHaptic] = []
        var replacedFuturePattern = false
        let presentedClock = renderer?.presentationState(at: hostNow)?.segment
        let cursorClock = presentedClock?.settings.subdivision == clock.settings.subdivision ? (presentedClock ?? clock) : clock
        var cursor = hostNow < runAnchor ? 0 : cursorClock.nextPulseIndex(after: hostNow - 0.002)
        if let presented = renderer?.presentationState(at: hostNow),
           presented.segment.settings.subdivision == clock.settings.subdivision,
           let sounded = presented.presentedTick(at: hostNow) {
            cursor = max(cursor, sounded.index + 1)
        }
        for scheduled in beatPlayers {
            let sameGrid = scheduled.subdivision == clock.settings.subdivision
            let correctedClock = scheduled.pulseIndex.map {
                let position = MetronomeTiming.pulseBeatPosition(index: $0, settings: clock.settings)
                return renderer?.clock(forBeatPosition: position) ?? clock
            }
            let correction = scheduled.pulseIndex.flatMap { pulse in
                let position = MetronomeTiming.pulseBeatPosition(index: pulse, settings: clock.settings)
                return correctedClock.map {
                    abs($0.hostTime(forBeatPosition: position) - scheduled.onsetHostSeconds)
                }
            } ?? .infinity
            // Preserve a pulse already sounding or too close to replace reliably.
            // Fine BPM edits alter an imminent timestamp only by microseconds.
            let imminent = sameGrid && scheduled.onsetHostSeconds <= hostNow + 0.012 && correction < 0.004
            let sameTimbre = scheduled.pulseIndex.flatMap { pulse in
                correctedClock.map { BeatHapticPatternKey(pulse: pulse, settings: $0.settings) }
            } == scheduled.patternKey
            // Avoid replacing a scheduled hardware transient for submillisecond
            // drift with the same timbre. Larger timing edits still rebase it.
            let effectivelyUnchanged = !replacedFuturePattern && sameGrid && sameTimbre && correction < 0.001
            if scheduled.onsetHostSeconds <= hostNow || imminent || effectivelyUnchanged {
                retained.append(scheduled)
                if sameGrid, let pulse = scheduled.pulseIndex { cursor = max(cursor, pulse + 1) }
            } else {
                replacedFuturePattern = true
                try? scheduled.player.stop(atTime: CHHapticTimeImmediate)
            }
        }
        beatPlayers = retained
        nextHapticPulse = cursor
        if !clock.settings.hapticsEnabled { cancelBeatPatterns() }
    }

    private func cancelBeatPatterns() {
        for scheduled in beatPlayers { try? scheduled.player.stop(atTime: CHHapticTimeImmediate) }
        beatPlayers.removeAll()
    }

    private func beatPattern(for key: BeatHapticPatternKey) throws -> CHHapticPattern {
        if let pattern = beatPatternCache[key] { return pattern }
        // A pitch sweep may visit many sharpnesses; retain a small bounded cache.
        if beatPatternCache.count >= 12 { beatPatternCache.removeAll(keepingCapacity: true) }
        let pattern = try CHHapticPattern(events: [CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: key.intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: key.sharpness)
        ], relativeTime: 0)], parameters: [])
        beatPatternCache[key] = pattern
        return pattern
    }

    private func playTempoDetent(increasing: Bool, marking: Bool) {
        guard settings.hapticsEnabled else { return }
        let host = Self.hostSeconds()
        // One physical notch per accepted update; fast adjustments never queue
        // catch-up haptics. Repeated gesture beginnings cannot bypass this limit.
        guard host - lastDetentTime >= 0.050 else { return }
        lastDetentTime = host
        let detent: TempoDetent = marking
            ? (increasing ? .markingUpward : .markingDownward)
            : (increasing ? .upward : .downward)
        if isRunning, let player = detentPlayers[detent] {
            do {
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Keep the audio transport running. A reset recreates the cache;
                // until then use the existing native impact feedback generators.
                detentPlayers.removeValue(forKey: detent)
            }
        }
        if increasing {
            upwardDetent.impactOccurred(intensity: marking ? 1 : 0.78)
            upwardDetent.prepare()
        } else {
            downwardDetent.impactOccurred(intensity: marking ? 1 : 0.82)
            downwardDetent.prepare()
        }
    }

    private func cacheDetentPlayers(engine: CHHapticEngine) {
        // Core Haptics permits starting a player repeatedly. These four single
        // transients are independent of the metronome's scheduled beat players.
        for detent in TempoDetent.allCases {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: detent.intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: detent.sharpness)
            ], relativeTime: 0)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []),
               let player = try? engine.makePlayer(with: pattern) {
                detentPlayers[detent] = player
            }
        }
    }

    private func discardDetentPlayers() {
        for player in detentPlayers.values { try? player.stop(atTime: CHHapticTimeImmediate) }
        detentPlayers.removeAll()
    }

    private func prepareHaptics(session: AVAudioSession, generation: UUID) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine(audioSession: session)
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = false
            engine.stoppedHandler = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == generation, self.isRunning else { return }
                    self.cancelBeatPatterns()
                    self.discardDetentPlayers()
                    self.hapticStatus = "Haptics temporarily unavailable"
                }
            }
            engine.resetHandler = { @Sendable [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == generation, self.isRunning else { return }
                    self.cancelBeatPatterns()
                    self.discardDetentPlayers()
                    do {
                        try self.hapticEngine?.start()
                        if let engine = self.hapticEngine { self.cacheDetentPlayers(engine: engine) }
                        self.calibrateHapticClock()
                        let host = Self.hostSeconds()
                        let presented = self.renderer?.presentationState(at: host)
                        let clock = self.runningClock
                        let cursorClock = presented?.segment.settings.subdivision == clock?.settings.subdivision
                            ? (presented?.segment ?? clock) : clock
                        self.nextHapticPulse = host < self.runAnchor
                            ? 0 : (cursorClock?.nextPulseIndex(after: host - 0.002) ?? 0)
                        if presented?.segment.settings.subdivision == cursorClock?.settings.subdivision,
                           let sounded = presented?.presentedTick(at: host) {
                            self.nextHapticPulse = max(self.nextHapticPulse, sounded.index + 1)
                        }
                    } catch {
                        self.hapticStatus = "Haptics temporarily unavailable"
                    }
                }
            }
            try engine.start()
            hapticEngine = engine
            cacheDetentPlayers(engine: engine)
        } catch {
            hapticStatus = "Haptics unavailable on this device"
        }
    }

    private func calibrateHapticClock() {
        guard let engine = hapticEngine else { return }
        let before = Self.hostSeconds()
        let hapticNow = engine.currentTime
        let after = Self.hostSeconds()
        hapticClockOffset = hapticNow - (before + after) / 2
    }

    private func updateStatuses() {
        let active = effectiveSettings
        soundStatus = active.soundEnabled ? (isRunning ? "Sample-clock audio" : "Audio ready") : "Sound off"
        if !active.hapticsEnabled {
            hapticStatus = "Haptics off"
        } else if !CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            hapticStatus = "Haptics unavailable on this device"
        } else if isRunning, hapticEngine != nil {
            hapticStatus = "Pitch → sharpness · beat → intensity"
        } else if !isRunning {
            hapticStatus = "Pitch → sharpness · device limits"
        }
    }

    private func schedulePersistence() {
        persistenceTask?.cancel()
        guard !isScrubbing else { return }
        persistenceTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            self?.persistSettings()
        }
    }

    private func persistSettings() {
        guard persistenceEnabled else { return }
        if let data = try? JSONEncoder().encode(Self.normalizedSettings(settings)) {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }

    private static func normalizedSettings(_ value: MetronomeSettings) -> MetronomeSettings {
        var normalized = value.sanitized
        normalized.bpm = TempoAdjustment.wholeBPM(normalized.bpm)
        return normalized
    }

    private func observeAudioSession() {
        notificationTokens.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
            guard context?.source == .system else { return }
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                self.stop()
                self.errorMessage = "Playback paused by an audio interruption. Tap Start to resume."
            }
        })
        notificationTokens.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                self.stop()
                self.errorMessage = "Playback paused because the audio output disconnected."
            }
        })
        notificationTokens.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stop()
                self.errorMessage = "Audio services reset. Tap Start to reconnect."
            }
        })
    }

    private func observeConfiguration(of engine: AVAudioEngine, generation: UUID) {
        let engineID = ObjectIdentifier(engine)
        audioConfigurationToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] notification in
            guard let changedEngine = notification.object as? AVAudioEngine,
                  ObjectIdentifier(changedEngine) == engineID else { return }
            MainActor.assumeIsolated {
                guard let self, self.isRunning, self.generation == generation,
                      let currentEngine = self.audioEngine,
                      ObjectIdentifier(currentEngine) == engineID else { return }
                self.stop()
                self.errorMessage = "Audio format changed. Tap Start to reconnect."
            }
        }
    }

    nonisolated private static func hostSeconds() -> Double {
        AVAudioTime.seconds(forHostTime: mach_absolute_time())
    }
}

private struct ScheduledHaptic {
    let player: any CHHapticPatternPlayer
    let finishHostSeconds: Double
    var onsetHostSeconds: Double = 0
    var pulseIndex: Int? = nil
    var subdivision: Int? = nil
    var patternKey: BeatHapticPatternKey? = nil
}

private struct BeatHapticPatternKey: Hashable {
    let intensity: Float
    let sharpness: Float

    init(pulse: Int, settings: MetronomeSettings) {
        intensity = Float(MetronomeTiming.pulseStrength(index: pulse, settings: settings))
        let base = min(1, max(0, log2(settings.pitch / 220) / 3))
        let accent = MetronomeTiming.pulseIsAccent(index: pulse, settings: settings)
        sharpness = Float(min(1, base + (accent ? 0.12 : 0)))
    }
}

private enum TempoDetent: CaseIterable {
    case upward, downward, markingUpward, markingDownward

    var intensity: Float {
        switch self {
        case .upward: 0.78
        case .downward: 0.82
        case .markingUpward, .markingDownward: 1
        }
    }

    var sharpness: Float {
        switch self {
        case .upward: 0.95
        case .downward: 0.20
        case .markingUpward: 0.60
        case .markingDownward: 0.05
        }
    }
}

private enum PlaybackError: LocalizedError {
    case noAudioOutput
    var errorDescription: String? { "No audio output format is available." }
}


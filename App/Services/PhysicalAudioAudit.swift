#if DEBUG
import AVFoundation
import Foundation
import MetronomeCore
import Synchronization
#if canImport(UIKit)
import UIKit
#endif

/// Opt-in evidence from the running SourceNode and mixer, before HAL/speaker output.
/// Render and tap writers have separate storage. Export reads only after both gates close.
nonisolated final class PhysicalAudioAudit: @unchecked Sendable {
    private let accepting = Atomic<Bool>(true)
    private let renderWriters = Atomic<Int>(0)
    private let tapWriters = Atomic<Int>(0)
    private let exportScheduled = Atomic<Bool>(false)
    private let pcm: UnsafeMutablePointer<Float>
    private let previousSamples: UnsafeMutablePointer<Float>
    private let packets: UnsafeMutablePointer<PhysicalAudioPacket>
    private let pulses: UnsafeMutablePointer<PhysicalAudioPulse>
    private let commands: UnsafeMutablePointer<PhysicalAudioCommand>
    private let frameCapacity: Int
    private let packetCapacity = 50_000
    private let eventCapacity = 8_192
    private let captureSampleRate: Double
    private let channelCount: Int
    private let run: Int
    private let initialMetadata: PhysicalAudioMetadata
    private var finalMetadata: PhysicalAudioMetadata?
    // Each of these groups has exactly one writer, until capture closes.
    private var renderStats = PhysicalRenderStatistics()
    private var captureStats = PhysicalCaptureStatistics()
    private var previousRenderSampleTime: Double?
    private var previousRenderHost: Double?
    private var previousRenderFrames = 0
    private var previousTapSampleTime: Double?
    private var previousTapHost: Double?
    private var previousTapFrames = 0
    private var capturedFrames = 0
    private var packetCount = 0
    private var pulseCount = 0
    private var commandCount = 0
    private var hasPreviousPCM = false
    private var lastAppliedBPM: Double?
    private var tapInstalled = false

    init(sampleRate: Double, channels: Int, run: Int, metadata: PhysicalAudioMetadata) {
        captureSampleRate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        channelCount = max(1, min(8, channels))
        frameCapacity = Int((captureSampleRate * 120).rounded(.up))
        self.run = run
        initialMetadata = metadata
        pcm = .allocate(capacity: frameCapacity * channelCount)
        pcm.initialize(repeating: 0, count: frameCapacity * channelCount)
        previousSamples = .allocate(capacity: channelCount)
        previousSamples.initialize(repeating: 0, count: channelCount)
        packets = .allocate(capacity: packetCapacity)
        packets.initialize(repeating: .init(), count: packetCapacity)
        pulses = .allocate(capacity: eventCapacity)
        pulses.initialize(repeating: .init(), count: eventCapacity)
        commands = .allocate(capacity: eventCapacity)
        commands.initialize(repeating: .init(), count: eventCapacity)
    }

    deinit {
        pcm.deinitialize(count: frameCapacity * channelCount)
        pcm.deallocate()
        previousSamples.deinitialize(count: channelCount)
        previousSamples.deallocate()
        packets.deinitialize(count: packetCapacity)
        packets.deallocate()
        pulses.deinitialize(count: eventCapacity)
        pulses.deallocate()
        commands.deinitialize(count: eventCapacity)
        commands.deallocate()
    }

    #if canImport(UIKit)
    @MainActor static func metadata(settings: MetronomeSettings) -> PhysicalAudioMetadata {
        let session = AVAudioSession.sharedInstance()
        return PhysicalAudioMetadata(
            unixTime: Date().timeIntervalSince1970,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            deviceModel: UIDevice.current.model, systemVersion: UIDevice.current.systemVersion,
            isPhysicalDevice: {
                #if targetEnvironment(simulator)
                false
                #else
                true
                #endif
            }(),
            sessionCategory: session.category.rawValue,
            sessionMode: session.mode.rawValue, sessionSampleRate: session.sampleRate,
            ioBufferDuration: session.ioBufferDuration, outputLatency: session.outputLatency,
            inputLatency: session.inputLatency,
            outputPorts: session.currentRoute.outputs.map {
                PhysicalAudioPort(type: $0.portType.rawValue, name: $0.portName, uid: $0.uid)
            }, settings: settings
        )
    }
    #endif

    /// Construct the legacy tap outside MainActor; the callback never inherits actor isolation.
    func installTap(on mixer: AVAudioMixerNode) {
        mixer.installTap(onBus: 0, bufferSize: 4_096, format: nil) { @Sendable [self] buffer, when in
            appendPCM(buffer, when: when)
        }
        tapInstalled = true
    }

    func removeTap(from mixer: AVAudioMixerNode) {
        if tapInstalled {
            mixer.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    // Increment before checking the gate. Sequential consistency makes a closed gate
    // plus zero writers a safe quiescent point even when a late callback enters.
    func beginRender(timestamp: AudioTimeStamp, frames: Int, sampleRate: Double) -> UInt64? {
        renderWriters.wrappingAdd(1, ordering: .sequentiallyConsistent)
        guard accepting.load(ordering: .sequentiallyConsistent) else {
            renderWriters.wrappingSubtract(1, ordering: .sequentiallyConsistent)
            return nil
        }
        let began = mach_absolute_time()
        renderStats.callbackCount &+= 1
        renderStats.renderedFrameCount &+= UInt64(frames)
        renderStats.sourceSampleRate = sampleRate
        renderStats.maximumBufferFrames = max(renderStats.maximumBufferFrames, frames)
        let validSample = timestamp.mFlags.contains(.sampleTimeValid) && timestamp.mSampleTime.isFinite
        let validHost = timestamp.mFlags.contains(.hostTimeValid)
        let host = validHost ? AVAudioTime.seconds(forHostTime: timestamp.mHostTime) : nil
        if validSample {
            if let previousRenderSampleTime {
                recordRenderGap(timestamp.mSampleTime - previousRenderSampleTime - Double(previousRenderFrames),
                                tolerance: 0.5)
            }
            previousRenderSampleTime = timestamp.mSampleTime
            renderStats.sampleTimeBufferCount &+= 1
        } else {
            previousRenderSampleTime = nil
            if let host, let previousRenderHost {
                recordRenderGap((host - previousRenderHost) * sampleRate - Double(previousRenderFrames),
                                tolerance: 2)
                renderStats.hostFallbackBufferCount &+= 1
            }
        }
        if !validHost { renderStats.invalidHostTimeBufferCount &+= 1 }
        previousRenderHost = host
        previousRenderFrames = frames
        return began
    }

    private func recordRenderGap(_ error: Double, tolerance: Double) {
        guard error.isFinite else { return }
        renderStats.maximumTimestampErrorFrames = max(renderStats.maximumTimestampErrorFrames, abs(error))
        if abs(error) > tolerance {
            renderStats.timestampDiscontinuityCount &+= 1
            if error > 0 { renderStats.positiveGapFrames += error }
        }
    }

    func endRender(began: UInt64, frames: Int, sampleRate: Double) {
        let duration = AVAudioTime.seconds(forHostTime: mach_absolute_time() - began)
        renderStats.maximumCallbackWallSeconds = max(renderStats.maximumCallbackWallSeconds, duration)
        if frames > 0 {
            renderStats.maximumWallToBufferRatio = max(renderStats.maximumWallToBufferRatio,
                                                      duration / (Double(frames) / sampleRate))
        }
        renderWriters.wrappingSubtract(1, ordering: .sequentiallyConsistent)
    }

    func recordRecovery(skippedPulses: Int) {
        if skippedPulses > 0 {
            renderStats.recoveryCount &+= 1
            renderStats.skippedPulseCount &+= UInt64(skippedPulses)
        }
    }

    func recordRawSample(_ value: Double) {
        guard value.isFinite else {
            renderStats.nonfiniteSampleCount &+= 1
            return
        }
        renderStats.maximumPreClampMagnitude = max(renderStats.maximumPreClampMagnitude, abs(value))
        if abs(value) > 1 { renderStats.preClampClipSampleCount &+= 1 }
    }

    func recordCommand(clock: MetronomeClockSegment, revision: UInt64) {
        renderStats.appliedCommandCount &+= 1
        if let lastAppliedBPM, lastAppliedBPM != clock.settings.bpm { renderStats.tempoChangeCount &+= 1 }
        lastAppliedBPM = clock.settings.bpm
        renderStats.minimumAppliedBPM = min(renderStats.minimumAppliedBPM ?? clock.settings.bpm, clock.settings.bpm)
        renderStats.maximumAppliedBPM = max(renderStats.maximumAppliedBPM ?? clock.settings.bpm, clock.settings.bpm)
        guard commandCount < eventCapacity else {
            renderStats.commandRecordOverflowCount &+= 1
            return
        }
        commands[commandCount] = PhysicalAudioCommand(host: clock.hostAnchor,
            beatPosition: clock.beatPositionAnchor, revision: revision, settings: clock.settings)
        commandCount += 1
    }

    func recordPulse(index: Int, onset: Double, renderedAt: Double, frequency: Double,
                     accent: Bool, strength: Double, gain: Double, sampleRate: Double) {
        renderStats.pulseCount &+= 1
        let lateness = max(0, (renderedAt - onset) * sampleRate)
        renderStats.maximumPulseLatenessFrames = max(renderStats.maximumPulseLatenessFrames, lateness)
        if lateness > 1.5 { renderStats.latePulseCount &+= 1 }
        guard pulseCount < eventCapacity else {
            renderStats.pulseRecordOverflowCount &+= 1
            return
        }
        pulses[pulseCount] = PhysicalAudioPulse(index: index, onsetHost: onset,
            renderedAtHost: renderedAt, frequency: frequency, accent: accent,
            strength: strength, gainAtFirstRenderedSample: gain)
        pulseCount += 1
    }

    private func appendPCM(_ buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        tapWriters.wrappingAdd(1, ordering: .sequentiallyConsistent)
        defer { tapWriters.wrappingSubtract(1, ordering: .sequentiallyConsistent) }
        guard accepting.load(ordering: .sequentiallyConsistent) else { return }
        captureStats.bufferCount &+= 1
        let frames = Int(buffer.frameLength)
        captureStats.receivedFrameCount &+= UInt64(frames)
        guard buffer.format.commonFormat == .pcmFormatFloat32,
              Int(buffer.format.channelCount) == channelCount,
              abs(buffer.format.sampleRate - captureSampleRate) < 0.01,
              let channelData = buffer.floatChannelData else {
            captureStats.unsupportedFormatBufferCount &+= 1
            captureStats.droppedFrameCount &+= UInt64(frames)
            return
        }
        let host = when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : nil
        let sampleTime = when.isSampleTimeValid ? Double(when.sampleTime) : nil
        var error: Double?
        if let sampleTime, let previousTapSampleTime {
            error = sampleTime - previousTapSampleTime - Double(previousTapFrames)
        } else if let host, let previousTapHost {
            error = (host - previousTapHost) * captureSampleRate - Double(previousTapFrames)
        }
        if let error, error.isFinite {
            captureStats.maximumTimestampErrorFrames = max(captureStats.maximumTimestampErrorFrames, abs(error))
            let tolerance = sampleTime != nil && previousTapSampleTime != nil ? 0.5 : 2.0
            if abs(error) > tolerance { captureStats.timestampDiscontinuityCount &+= 1 }
        }
        previousTapSampleTime = sampleTime
        previousTapHost = host
        previousTapFrames = frames
        let writable = min(frames, frameCapacity - capturedFrames)
        if writable < frames { captureStats.capacityOverflowFrameCount &+= UInt64(frames - writable) }
        if packetCount < packetCapacity, writable > 0 {
            packets[packetCount] = PhysicalAudioPacket(firstFrame: capturedFrames, frameCount: writable,
                                                       host: host, sampleTime: sampleTime)
            packetCount += 1
        } else if writable > 0 {
            captureStats.packetRecordOverflowCount &+= 1
        }
        for frame in 0..<writable {
            for channel in 0..<channelCount {
                let value = buffer.format.isInterleaved
                    ? channelData[0][frame * channelCount + channel] : channelData[channel][frame]
                pcm[(capturedFrames + frame) * channelCount + channel] = value
                if value.isFinite {
                    let magnitude = abs(Double(value))
                    captureStats.maximumMagnitude = max(captureStats.maximumMagnitude, magnitude)
                    captureStats.sumSquares += Double(value) * Double(value)
                    if magnitude >= 1 { captureStats.fullScaleSampleCount &+= 1 }
                    if magnitude > 1 { captureStats.overFullScaleSampleCount &+= 1 }
                    if hasPreviousPCM {
                        let difference = abs(Double(value) - Double(previousSamples[channel]))
                        captureStats.maximumAdjacentSampleDifference = max(
                            captureStats.maximumAdjacentSampleDifference, difference)
                        if frame == 0 {
                            captureStats.maximumBufferBoundaryDifference = max(
                                captureStats.maximumBufferBoundaryDifference, difference)
                        }
                    }
                    previousSamples[channel] = value
                } else {
                    captureStats.nonfiniteSampleCount &+= 1
                    previousSamples[channel] = 0
                }
            }
            hasPreviousPCM = true
        }
        capturedFrames += writable
    }

    func closeCapture(metadata: PhysicalAudioMetadata) {
        accepting.store(false, ordering: .sequentiallyConsistent)
        finalMetadata = metadata
    }

    /// Called after stop/removal; no file work, waiting, logging, or tasks occur in either callback.
    func exportAfterStop(completion: @escaping @Sendable (PhysicalAudioExportResult) -> Void) {
        guard !exportScheduled.exchange(true, ordering: .sequentiallyConsistent) else { return }
        Task.detached(priority: .utility) { [self] in
            while renderWriters.load(ordering: .sequentiallyConsistent) != 0 ||
                    tapWriters.load(ordering: .sequentiallyConsistent) != 0 {
                try? await Task.sleep(for: .milliseconds(1))
            }
            completion(exportFiles())
        }
    }

    private func exportFiles() -> PhysicalAudioExportResult {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhysicalQA", isDirectory: true)
        let name = "audio-\(initialMetadata.processIdentifier)-\(run)"
        let wav = directory.appendingPathComponent(name + ".wav")
        let json = directory.appendingPathComponent(name + ".json")
        var wavError: String?
        var jsonError: String?
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try writeWAV(to: wav)
        } catch { wavError = String(describing: error) }
        let samples = capturedFrames * channelCount
        captureStats.capturedFrameCount = capturedFrames
        captureStats.rms = samples > 0 ? sqrt(captureStats.sumSquares / Double(samples)) : 0
        let document = PhysicalAudioDocument(
            initialMetadata: initialMetadata, finalMetadata: finalMetadata,
            run: run, captureSampleRate: captureSampleRate, channelCount: channelCount,
            captureCapacitySeconds: 120, capturedDurationSeconds: Double(capturedFrames) / captureSampleRate,
            wavPath: wav.path, wavWriteError: wavError, render: renderStats, mixer: captureStats,
            packets: Array(UnsafeBufferPointer(start: packets, count: packetCount)),
            pulses: Array(UnsafeBufferPointer(start: pulses, count: pulseCount)),
            commands: Array(UnsafeBufferPointer(start: commands, count: commandCount))
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(document).write(to: json, options: .atomic)
        } catch {
            jsonError = String(describing: error)
            NSLog("Physical audio audit export failed: %@", String(describing: error))
        }
        return PhysicalAudioExportResult(wavPath: wav.path, jsonPath: json.path,
                                         error: jsonError ?? wavError)
    }

    private func writeWAV(to url: URL) throws {
        let byteCount = capturedFrames * channelCount * MemoryLayout<Float>.size
        var header = Data()
        func text(_ value: String) { header.append(contentsOf: value.utf8) }
        func integer<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { header.append(contentsOf: $0) }
        }
        text("RIFF"); integer(UInt32(48 + byteCount)); text("WAVE")
        text("fmt "); integer(UInt32(16)); integer(UInt16(3)) // IEEE Float32, no quantization.
        integer(UInt16(channelCount)); integer(UInt32(captureSampleRate.rounded()))
        integer(UInt32(captureSampleRate.rounded()) * UInt32(channelCount * 4))
        integer(UInt16(channelCount * 4)); integer(UInt16(32))
        text("fact"); integer(UInt32(4)); integer(UInt32(capturedFrames))
        text("data"); integer(UInt32(byteCount))
        let temporary = url.appendingPathExtension("partial")
        _ = FileManager.default.createFile(atPath: temporary.path, contents: nil)
        let file = try FileHandle(forWritingTo: temporary)
        do {
            try file.write(contentsOf: header)
            let data = Data(bytesNoCopy: pcm, count: byteCount, deallocator: .none)
            try file.write(contentsOf: data)
            try file.synchronize()
            try file.close()
        } catch {
            try? file.close()
            throw error
        }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.moveItem(at: temporary, to: url)
    }
}

nonisolated struct PhysicalAudioMetadata: Codable, Sendable {
    let unixTime: Double
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let appVersion: String?
    let appBuild: String?
    let deviceModel: String
    let systemVersion: String
    let isPhysicalDevice: Bool
    let sessionCategory: String
    let sessionMode: String
    let sessionSampleRate: Double
    let ioBufferDuration: Double
    let outputLatency: Double
    let inputLatency: Double
    let outputPorts: [PhysicalAudioPort]
    let settings: MetronomeSettings
}

nonisolated struct PhysicalAudioExportResult: Sendable {
    let wavPath: String
    let jsonPath: String
    let error: String?
}

nonisolated struct PhysicalAudioPort: Codable, Sendable {
    let type: String
    let name: String
    let uid: String
}

nonisolated private struct PhysicalRenderStatistics: Codable, Sendable {
    var callbackCount: UInt64 = 0
    var renderedFrameCount: UInt64 = 0
    var sourceSampleRate = 0.0
    var maximumBufferFrames = 0
    var sampleTimeBufferCount: UInt64 = 0
    var hostFallbackBufferCount: UInt64 = 0
    var invalidHostTimeBufferCount: UInt64 = 0
    var timestampDiscontinuityCount: UInt64 = 0
    var maximumTimestampErrorFrames = 0.0
    var positiveGapFrames = 0.0
    var maximumCallbackWallSeconds = 0.0
    var maximumWallToBufferRatio = 0.0
    var recoveryCount: UInt64 = 0
    var skippedPulseCount: UInt64 = 0
    var preClampClipSampleCount: UInt64 = 0
    var nonfiniteSampleCount: UInt64 = 0
    var maximumPreClampMagnitude = 0.0
    var appliedCommandCount: UInt64 = 0
    var tempoChangeCount: UInt64 = 0
    var minimumAppliedBPM: Double?
    var maximumAppliedBPM: Double?
    var commandRecordOverflowCount: UInt64 = 0
    var pulseCount: UInt64 = 0
    var latePulseCount: UInt64 = 0
    var maximumPulseLatenessFrames = 0.0
    var pulseRecordOverflowCount: UInt64 = 0
}

nonisolated private struct PhysicalCaptureStatistics: Codable, Sendable {
    var bufferCount: UInt64 = 0
    var receivedFrameCount: UInt64 = 0
    var capturedFrameCount = 0
    var unsupportedFormatBufferCount: UInt64 = 0
    var droppedFrameCount: UInt64 = 0
    var capacityOverflowFrameCount: UInt64 = 0
    var packetRecordOverflowCount: UInt64 = 0
    var timestampDiscontinuityCount: UInt64 = 0
    var maximumTimestampErrorFrames = 0.0
    var maximumMagnitude = 0.0
    var fullScaleSampleCount: UInt64 = 0
    var overFullScaleSampleCount: UInt64 = 0
    var nonfiniteSampleCount: UInt64 = 0
    var maximumAdjacentSampleDifference = 0.0
    var maximumBufferBoundaryDifference = 0.0
    var sumSquares = 0.0
    var rms = 0.0
}

nonisolated private struct PhysicalAudioPacket: Codable, Sendable {
    var firstFrame = 0
    var frameCount = 0
    var host: Double?
    var sampleTime: Double?
}

nonisolated private struct PhysicalAudioPulse: Codable, Sendable {
    var index = 0
    var onsetHost = 0.0
    var renderedAtHost = 0.0
    var frequency = 0.0
    var accent = false
    var strength = 0.0
    var gainAtFirstRenderedSample = 0.0
}

nonisolated private struct PhysicalAudioCommand: Codable, Sendable {
    var host = 0.0
    var beatPosition = 0.0
    var revision: UInt64 = 0
    var settings = MetronomeSettings()
}

nonisolated private struct PhysicalAudioDocument: Encodable {
    let formatVersion = 1
    let launchFlag = "--physical-qa"
    let scope = "Actual SourceNode callbacks and mainMixer PCM before HAL, speaker, volume hardware, or haptic acoustics."
    let timingInterpretation = "Timestamp discontinuities indicate missing or repeated graph sample time; callback wall-duration ratio includes descheduling and is a deadline risk indicator, not a CPU-time or hardware underrun count."
    let differenceInterpretation = "Adjacent/buffer-boundary sample differences are measurements only. High-frequency carriers naturally have large differences; they are not standalone glitch failures."
    let writerSafety = "Gate closed and both in-flight writers quiescent before PCM/records were read or exported."
    let initialMetadata: PhysicalAudioMetadata
    let finalMetadata: PhysicalAudioMetadata?
    let run: Int
    let captureSampleRate: Double
    let channelCount: Int
    let captureCapacitySeconds: Int
    let capturedDurationSeconds: Double
    let wavPath: String
    let wavWriteError: String?
    let render: PhysicalRenderStatistics
    let mixer: PhysicalCaptureStatistics
    let packets: [PhysicalAudioPacket]
    let pulses: [PhysicalAudioPulse]
    let commands: [PhysicalAudioCommand]
}
#endif

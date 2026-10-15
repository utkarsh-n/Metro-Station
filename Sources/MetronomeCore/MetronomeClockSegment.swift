import Foundation

/// An immutable piece of the transport clock. Rebase at a parameter update to preserve phase.
/// Host time uses the caller's monotonic clock in seconds, never wall-clock dates.
public struct MetronomeClockSegment: Sendable, Equatable {
    public let hostAnchor: Double
    public let beatPositionAnchor: Double
    public let settings: MetronomeSettings

    public init(hostAnchor: Double = 0, beatPositionAnchor: Double = 0,
                settings: MetronomeSettings = .init()) {
        self.hostAnchor = hostAnchor.isFinite ? hostAnchor : 0
        self.beatPositionAnchor = MetronomeTiming.safeBeatPosition(beatPositionAnchor)
        self.settings = settings.sanitized
    }

    public func beatPosition(at hostTime: Double) -> Double {
        guard hostTime.isFinite else { return beatPositionAnchor }
        let position = beatPositionAnchor + (hostTime - hostAnchor) * settings.bpm / 60
        if position == .infinity { return Double(Int.max / 16) }
        return MetronomeTiming.safeBeatPosition(position)
    }

    public func rebased(settings newSettings: MetronomeSettings, at hostTime: Double) -> Self {
        let anchor = hostTime.isFinite ? hostTime : hostAnchor
        return Self(hostAnchor: anchor, beatPositionAnchor: beatPosition(at: anchor),
                    settings: newSettings)
    }

    public func hostTime(forBeatPosition beatPosition: Double) -> Double {
        let position = beatPosition.isFinite
            ? MetronomeTiming.safeBeatPosition(beatPosition) : beatPositionAnchor
        return hostAnchor + (position - beatPositionAnchor) * 60 / settings.bpm
    }

    public func pulseHostTime(index: Int) -> Double {
        hostTime(forBeatPosition: MetronomeTiming.pulseBeatPosition(index: index, settings: settings))
    }

    public func pulseIndex(at hostTime: Double) -> Int {
        let host = hostTime.isFinite ? hostTime : hostAnchor
        var index = MetronomeTiming.pulseIndex(beatPosition: beatPosition(at: host), settings: settings)
        // At a precise scheduled host timestamp, cancel the inverse conversion's rounding error.
        if index > 0 && pulseHostTime(index: index) > host { index -= 1 }
        if index < Int.max - 1 && pulseHostTime(index: index + 1) <= host { index += 1 }
        return index
    }

    /// Exclusively after the supplied host timestamp. The initial pulse at beat zero is separate.
    public func nextPulseIndex(after hostTime: Double) -> Int {
        min(Int.max - 1, pulseIndex(at: hostTime)) + 1
    }

    public func snapshot(at hostTime: Double, elapsed: Double = 0,
                          absolutePulseIndex: Int? = nil, tickElapsed: Double? = nil,
                          tickFrequency: Double? = nil, tickAccent: Bool? = nil,
                          tickStrength: Double? = nil) -> BeatSnapshot {
        BeatSnapshot.snapshot(beatPosition: beatPosition(at: hostTime), elapsed: elapsed,
                              settings: settings, absolutePulseIndex: absolutePulseIndex,
                              tickElapsed: tickElapsed, tickFrequency: tickFrequency,
                              tickAccent: tickAccent, tickStrength: tickStrength)
    }
}

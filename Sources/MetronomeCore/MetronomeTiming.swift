import Foundation

public struct BeatSnapshot: Sendable, Equatable {
    public let beatPhase: Double
    public let beatInBar: Int
    public let barIndex: Int
    public let pulseInBeat: Int
    public let elapsed: Double
    /// Unwrapped transport position. Independent of the current bar / subdivision settings.
    public let absoluteBeatPosition: Double
    public let absolutePulseIndex: Int
    /// Actual sounded voice age, measured in host seconds; tempo changes never stretch a tick.
    public let tickElapsed: Double?
    public let tickFrequency: Double?
    public let tickAccent: Bool?
    /// Current voice gain including the renderer's master gain; no second volume multiplier.
    public let tickStrength: Double?

    public init(beatPhase: Double, beatInBar: Int, barIndex: Int, pulseInBeat: Int,
                elapsed: Double, absoluteBeatPosition: Double, absolutePulseIndex: Int,
                tickElapsed: Double? = nil, tickFrequency: Double? = nil,
                tickAccent: Bool? = nil, tickStrength: Double? = nil) {
        self.beatPhase = beatPhase
        self.beatInBar = beatInBar
        self.barIndex = barIndex
        self.pulseInBeat = pulseInBeat
        self.elapsed = elapsed
        self.absoluteBeatPosition = absoluteBeatPosition
        self.absolutePulseIndex = max(0, absolutePulseIndex)
        self.tickElapsed = tickElapsed.flatMap { $0.isFinite ? max(0, $0) : nil }
        self.tickFrequency = tickFrequency.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.tickAccent = tickAccent
        self.tickStrength = tickStrength.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
    }

    public static func snapshot(elapsed: Double, settings: MetronomeSettings) -> Self {
        let s = settings.sanitized
        let time = MetronomeTiming.safeElapsed(elapsed)
        let pulse = MetronomeTiming.pulseIndex(elapsed: time, settings: s)
        let beatNumber = pulse / s.subdivision
        let beatStart = Double(beatNumber) * 60 / s.bpm
        // Subtract the timestamp used by the scheduler so exact scheduled boundaries stay zero.
        let phase = max(0, min(1.0.nextDown, (time - beatStart) * s.bpm / 60))
        return Self(
            beatPhase: phase,
            beatInBar: beatNumber % s.beatsPerBar,
            barIndex: beatNumber / s.beatsPerBar,
            pulseInBeat: pulse % s.subdivision,
            elapsed: time,
            absoluteBeatPosition: Double(beatNumber) + phase,
            absolutePulseIndex: pulse,
            tickElapsed: time - MetronomeTiming.pulseTime(index: pulse, settings: s),
            tickFrequency: s.pitch,
            tickAccent: MetronomeTiming.pulseIsAccent(index: pulse, settings: s),
            tickStrength: MetronomeTiming.pulseStrength(index: pulse, settings: s)
                * (s.soundEnabled ? s.volume : 0)
        )
    }

    /// A snapshot of a live transport that can change tempo without resetting beat or bar phase.
    public static func snapshot(beatPosition: Double, elapsed: Double = 0,
                                settings: MetronomeSettings, absolutePulseIndex: Int? = nil,
                                tickElapsed: Double? = nil, tickFrequency: Double? = nil,
                                tickAccent: Bool? = nil, tickStrength: Double? = nil) -> Self {
        let s = settings.sanitized
        let position = MetronomeTiming.safeBeatPosition(beatPosition)
        let beatNumber = Int(floor(position))
        let pulse = MetronomeTiming.pulseIndex(beatPosition: position, settings: s)
        return Self(beatPhase: position - floor(position),
                    beatInBar: beatNumber % s.beatsPerBar,
                    barIndex: beatNumber / s.beatsPerBar,
                    pulseInBeat: pulse % s.subdivision,
                    elapsed: MetronomeTiming.safeElapsed(elapsed),
                    absoluteBeatPosition: position,
                    absolutePulseIndex: absolutePulseIndex ?? pulse,
                    tickElapsed: tickElapsed, tickFrequency: tickFrequency,
                    tickAccent: tickAccent, tickStrength: tickStrength)
    }
}

/// Every timestamp is derived from its integer pulse index; no accumulated timer intervals.
public enum MetronomeTiming {
    /// A pulse's location in musical beats. Tempo changes only the conversion to wall-clock time.
    public static func pulseBeatPosition(index: Int, settings: MetronomeSettings) -> Double {
        let s = settings.sanitized
        let i = max(0, index)
        let beat = i / s.subdivision
        let pulse = i % s.subdivision
        let delay = s.subdivision.isMultiple(of: 2) && !pulse.isMultiple(of: 2) ? s.swing : 0
        return Double(beat) + (Double(pulse) + delay) / Double(s.subdivision)
    }

    /// Most recent pulse in musical beat space, including swing-delayed subdivisions.
    public static func pulseIndex(beatPosition: Double, settings: MetronomeSettings) -> Int {
        let s = settings.sanitized
        let position = safeBeatPosition(beatPosition)
        var index = Int(floor(position * Double(s.subdivision)))
        if index > 0 && pulseBeatPosition(index: index, settings: s) > position { index -= 1 }
        if index < Int.max - 1 && pulseBeatPosition(index: index + 1, settings: s) <= position { index += 1 }
        return index
    }

    public static func pulseBeatDuration(index: Int, settings: MetronomeSettings) -> Double {
        let i = max(0, min(Int.max - 1, index))
        return pulseBeatPosition(index: i + 1, settings: settings)
            - pulseBeatPosition(index: i, settings: settings)
    }

    public static func pulseTime(index: Int, settings: MetronomeSettings) -> Double {
        let s = settings.sanitized
        let i = max(0, index)
        let beat = i / s.subdivision
        let pulse = i % s.subdivision
        let interval = 60 / s.bpm / Double(s.subdivision)
        let delay = s.subdivision.isMultiple(of: 2) && !pulse.isMultiple(of: 2) ? s.swing * interval : 0
        return Double(beat) * 60 / s.bpm + Double(pulse) * interval + delay
    }

    /// Most recent pulse at or before `elapsed`, including swing-delayed pulses.
    public static func pulseIndex(elapsed: Double, settings: MetronomeSettings) -> Int {
        let s = settings.sanitized
        let time = safeElapsed(elapsed)
        let position = time * s.bpm / 60 * Double(s.subdivision)
        var index = Int(floor(position))
        if index > 0 && pulseTime(index: index, settings: s) > time {
            index -= 1
        }
        // A rounding difference at an exact boundary must not omit a due pulse.
        if index < Int.max - 1 && pulseTime(index: index + 1, settings: s) <= time {
            index += 1
        }
        return index
    }

    /// Length of the interval beginning at this pulse. Swing alternates longer / shorter gaps.
    public static func pulseDuration(index: Int, settings: MetronomeSettings) -> Double {
        let i = max(0, min(Int.max - 1, index))
        return pulseTime(index: i + 1, settings: settings) - pulseTime(index: i, settings: settings)
    }

    /// Shared audio / waveform gain before the user's master volume.
    public static func pulseStrength(index: Int, settings: MetronomeSettings) -> Double {
        let s = settings.sanitized
        let i = max(0, index)
        if i.isMultiple(of: s.subdivision * s.beatsPerBar) { return 1 }
        return i.isMultiple(of: s.subdivision) ? 0.72 : 0.36
    }

    public static func pulseIsAccent(index: Int, settings: MetronomeSettings) -> Bool {
        let s = settings.sanitized
        return max(0, index).isMultiple(of: s.subdivision * s.beatsPerBar)
    }

    static func safeElapsed(_ elapsed: Double) -> Double {
        guard elapsed.isFinite else { return 0 }
        // Leave room for the fastest possible rhythm and all supported subdivisions.
        return min(Double(Int.max / 32), max(0, elapsed))
    }

    static func safeBeatPosition(_ position: Double) -> Double {
        guard position.isFinite else { return 0 }
        return min(Double(Int.max / 16), max(0, position))
    }
}

/// An analytic phase guide, not a simulation of a mechanical pendulum or sound pressure.
public struct PhaseOscillatorState: Sendable, Equatable {
    public let phaseRadians: Double
    public let displacement: Double
    /// Velocity normalized by angular frequency, in [-1, 1].
    public let velocity: Double
    /// Acceleration normalized by angular frequency squared, in [-1, 1].
    public let acceleration: Double
    public let velocityPerSecond: Double
    public let accelerationPerSecondSquared: Double

    public static func at(beatPhase: Double, frequency: Double = 1) -> Self {
        let phase = beatPhase.isFinite ? beatPhase - floor(beatPhase) : 0
        let f = frequency.isFinite ? max(0, min(1000, frequency)) : 1
        let angle = 2 * Double.pi * phase
        let omega = 2 * Double.pi * f
        let x = cos(angle)
        let v = -sin(angle)
        return Self(
            phaseRadians: angle,
            displacement: x,
            velocity: v,
            acceleration: -x,
            velocityPerSecond: omega * v,
            accelerationPerSecondSquared: -omega * omega * x
        )
    }
}

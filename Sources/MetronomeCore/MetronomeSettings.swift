import Foundation

/// Rhythm rate and audible carrier pitch are deliberately separate quantities.
public struct MetronomeSettings: Codable, Equatable, Sendable {
    public var bpm: Double
    public var beatsPerBar: Int
    public var subdivision: Int
    public var pitch: Double
    public var volume: Double
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool
    /// For even subdivisions, delays each odd pulse by this fraction of one subdivision.
    public var swing: Double

    public init(
        bpm: Double = 120,
        beatsPerBar: Int = 4,
        subdivision: Int = 1,
        pitch: Double = 880,
        volume: Double = 0.65,
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        swing: Double = 0
    ) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.subdivision = subdivision
        self.pitch = pitch
        self.volume = volume
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.swing = swing
    }

    public var sanitized: Self {
        var value = self
        value.bpm = Self.clamp(bpm, to: 30...240, fallback: 120)
        value.beatsPerBar = min(12, max(1, beatsPerBar))
        value.subdivision = (1...4).contains(subdivision) ? subdivision : 1
        value.pitch = Self.clamp(pitch, to: 220...1760, fallback: 880)
        value.volume = Self.clamp(volume, to: 0...1, fallback: 0.65)
        value.swing = Self.clamp(swing, to: 0...0.45, fallback: 0)
        return value
    }

    /// Beats per second, not the acoustic pitch or haptic actuator frequency.
    public var beatFrequency: Double { sanitized.bpm / 60 }
    public var beatDuration: Double { 60 / sanitized.bpm }
    /// Average pulses per second; swing changes alternating intervals, not this average.
    public var pulseFrequency: Double { beatFrequency * Double(sanitized.subdivision) }
    public var barDuration: Double { beatDuration * Double(sanitized.beatsPerBar) }
    public var effectiveSwing: Double { sanitized.subdivision.isMultiple(of: 2) ? sanitized.swing : 0 }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

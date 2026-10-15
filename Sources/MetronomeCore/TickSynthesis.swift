import Foundation

public struct SpectrumBin: Sendable, Equatable {
    public let frequency: Double
    /// Linear amplitude, normalized to the strongest bin in the requested frequency range.
    public let magnitude: Double

    public init(frequency: Double, magnitude: Double) {
        self.frequency = frequency
        self.magnitude = magnitude
    }
}

/// A finite, enveloped oscillator tick. Its spectrum is computed from the same signal heard.
public enum TickSynthesis {
    public static let duration: Double = 0.055
    public static let attackDuration: Double = 0.0015
    public static let tailDuration: Double = 0.007

    /// Allocation-free mix of the current pulse and the still-live previous pulse.
    /// The fastest supported swung subdivision can start before the previous 55 ms tick ends.
    public static func mixedSample(
        at currentTime: Double,
        accent: Bool,
        strength: Double,
        previousTime: Double,
        previousAccent: Bool,
        previousStrength: Double,
        frequency: Double,
        volume: Double,
        sampleRate: Double = 48_000
    ) -> Double {
        let outputGain = safeUnitGain(volume)
        guard outputGain > 0 else { return 0 }
        let currentGain = safeUnitGain(strength)
        let previousGain = safeUnitGain(previousStrength)
        let current = currentGain > 0
            ? sample(at: currentTime, frequency: frequency, accent: accent, sampleRate: sampleRate) * currentGain
            : 0
        let previous = previousGain > 0
            ? sample(at: previousTime, frequency: frequency, accent: previousAccent, sampleRate: sampleRate) * previousGain
            : 0
        // Keep the waveform faithful to the independent voices. Supported timing/gains leave headroom.
        return (current + previous) * outputGain
    }

    public static func sample(
        at time: Double,
        frequency: Double,
        accent: Bool,
        sampleRate: Double = 48_000
    ) -> Double {
        guard time.isFinite, frequency.isFinite, sampleRate.isFinite,
              time >= 0, time < duration, frequency > 0, sampleRate > 0,
              frequency < sampleRate / 2 else { return 0 }
        let attack = smoothstep(time / attackDuration)
        let tail = 1 - smoothstep((time - duration + tailDuration) / tailDuration)
        let decay = exp(-time / (accent ? 0.010 : 0.0125))
        let amplitude = (accent ? 0.92 : 0.72) * attack * decay * tail
        let harmonicTwo = accent ? 0.30 : 0.16
        let harmonicThree = accent ? 0.10 : 0.04
        let angle = 2 * Double.pi * frequency * time
        var signal = sin(angle)
        var weight = 1.0
        if frequency * 2 < sampleRate / 2 {
            signal += harmonicTwo * sin(angle * 2)
            weight += harmonicTwo
        }
        if frequency * 3 < sampleRate / 2 {
            signal += harmonicThree * sin(angle * 3)
            weight += harmonicThree
        }
        return amplitude * signal / weight
    }

    /// Uniformly covers 0...55 ms, independent of audio device rate. Last sample is zero.
    public static func waveform(
        frequency: Double,
        accent: Bool,
        count: Int = 768,
        sampleRate: Double = 48_000
    ) -> [Double] {
        let size = min(8192, max(2, count))
        return (0..<size).map {
            sample(at: Double($0) / Double(size - 1) * duration,
                   frequency: frequency, accent: accent, sampleRate: sampleRate)
        }
    }

    /// Direct Fourier transform of the finite tick, including its envelope and harmonics.
    /// Zero padding improves displayed bin spacing, not the signal's true resolving power.
    public static func spectrum(
        frequency: Double,
        accent: Bool,
        binCount: Int = 512,
        sampleCount: Int = 4096,
        sampleRate: Double = 48_000
    ) -> [SpectrumBin] {
        guard sampleRate.isFinite, sampleRate > 0 else { return [] }
        let count = min(16_384, max(64, sampleCount))
        let bins = min(count / 2 + 1, max(1, binCount))
        let signalCount = min(count, Int(min(Double(count), ceil(duration * sampleRate))))
        let signal = (0..<signalCount).map {
            sample(at: Double($0) / sampleRate, frequency: frequency,
                   accent: accent, sampleRate: sampleRate)
        }
        var amplitudes = [Double](repeating: 0, count: bins)
        // Recurrence avoids two trigonometric calls per sample per bin.
        for bin in 0..<bins {
            let angle = -2 * Double.pi * Double(bin) / Double(count)
            let stepReal = cos(angle)
            let stepImaginary = sin(angle)
            var rotationReal = 1.0
            var rotationImaginary = 0.0
            var real = 0.0
            var imaginary = 0.0
            for sample in signal {
                real += sample * rotationReal
                imaginary += sample * rotationImaginary
                let nextReal = rotationReal * stepReal - rotationImaginary * stepImaginary
                rotationImaginary = rotationReal * stepImaginary + rotationImaginary * stepReal
                rotationReal = nextReal
            }
            amplitudes[bin] = hypot(real, imaginary)
        }
        let maximum = amplitudes.max() ?? 0
        return amplitudes.enumerated().map { index, amplitude in
            SpectrumBin(frequency: Double(index) * sampleRate / Double(count),
                        magnitude: maximum > 0 ? amplitude / maximum : 0)
        }
    }

    private static func smoothstep(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }

    private static func safeUnitGain(_ gain: Double) -> Double {
        gain.isFinite ? min(1, max(0, gain)) : 0
    }
}

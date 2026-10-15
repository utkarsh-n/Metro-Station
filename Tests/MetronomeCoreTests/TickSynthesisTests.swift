import Foundation
import Testing
@testable import MetronomeCore

@Suite("Audible tick DSP")
struct TickSynthesisTests {
    @Test(arguments: [220.0, 880.0, 1760.0])
    func boundedFiniteEnvelope(frequency: Double) {
        for accent in [true, false] {
            let waveform = TickSynthesis.waveform(frequency: frequency, accent: accent, count: 2048)
            #expect(waveform.count == 2048)
            #expect(waveform.allSatisfy { $0.isFinite && abs($0) <= 1 })
            #expect(waveform.first == 0)
            #expect(waveform.last == 0)
            #expect(waveform.map(abs).max()! > 0.2)
            let earlyEnergy = waveform[100..<500].reduce(0) { $0 + $1 * $1 }
            let lateEnergy = waveform[1600..<2000].reduce(0) { $0 + $1 * $1 }
            #expect(lateEnergy < earlyEnergy / 20)
        }
        #expect(TickSynthesis.sample(at: -0.1, frequency: frequency, accent: false) == 0)
        #expect(TickSynthesis.sample(at: TickSynthesis.duration, frequency: frequency, accent: false) == 0)
    }

    @Test
    func rejectsNonfiniteAndAboveNyquist() {
        #expect(TickSynthesis.sample(at: .nan, frequency: 880, accent: true) == 0)
        #expect(TickSynthesis.sample(at: 0.004, frequency: .infinity, accent: true) == 0)
        #expect(TickSynthesis.sample(at: 0.004, frequency: 880, accent: true, sampleRate: .nan) == 0)
        #expect(TickSynthesis.sample(at: 0.004, frequency: 24_000, accent: true) == 0)
        #expect(TickSynthesis.sample(at: 0.004, frequency: 25_000, accent: true) == 0)
        // If both harmonics are above Nyquist, the surviving fundamental has no folded tones.
        let time = 0.004
        let expected = 0.72 * exp(-time / 0.0125) * sin(2 * .pi * 9000 * time)
        #expect(abs(TickSynthesis.sample(at: time, frequency: 9000, accent: false, sampleRate: 30_000) - expected) < 1e-12)
    }

    @Test(arguments: [220.0, 880.0, 1760.0])
    func spectrumPeakTracksCarrierAndHarmonics(frequency: Double) {
        let spectrum = TickSynthesis.spectrum(frequency: frequency, accent: true)
        let peak = spectrum.max { $0.magnitude < $1.magnitude }!
        #expect(abs(peak.frequency - frequency) <= 48_000 / 4096)
        #expect(abs(peak.magnitude - 1) < 1e-12)
        #expect(spectrum.allSatisfy { $0.magnitude.isFinite && $0.magnitude >= 0 && $0.magnitude <= 1 })
        let secondHarmonic = spectrum.min { abs($0.frequency - 2 * frequency) < abs($1.frequency - 2 * frequency) }!
        #expect(secondHarmonic.magnitude > 0.15)
        #expect(secondHarmonic.magnitude < 0.5)
    }

    @Test
    func spectrumMatchesIndependentDFTOfAudioSamples() {
        let sampleRate = 8000.0
        let count = 1024
        let bin = 113
        let spectrum = TickSynthesis.spectrum(frequency: 880, accent: false,
                                              binCount: 256, sampleCount: count, sampleRate: sampleRate)
        func amplitude(_ binIndex: Int) -> Double {
            var real = 0.0
            var imaginary = 0.0
            for index in 0..<count {
                let sample = TickSynthesis.sample(at: Double(index) / sampleRate,
                                                   frequency: 880, accent: false, sampleRate: sampleRate)
                let angle = -2 * .pi * Double(binIndex * index) / Double(count)
                real += sample * cos(angle)
                imaginary += sample * sin(angle)
            }
            return hypot(real, imaginary)
        }
        let referenceMaximum = (0..<256).map(amplitude).max()!
        #expect(abs(spectrum[bin].magnitude - amplitude(bin) / referenceMaximum) < 1e-10)
        #expect(spectrum[bin].frequency == Double(bin) * sampleRate / Double(count))
    }

    @Test
    func badAnalysisInputsStayBounded() {
        #expect(TickSynthesis.waveform(frequency: 880, accent: false, count: .min).count == 2)
        #expect(TickSynthesis.spectrum(frequency: 880, accent: false, sampleRate: -1).isEmpty)
        let silence = TickSynthesis.spectrum(frequency: .nan, accent: false, binCount: 8, sampleCount: 64)
        #expect(silence.count == 8)
        #expect(silence.allSatisfy { $0.magnitude == 0 })
    }
}

import SwiftUI
import MetronomeCore

/// A compact isolated-tick instrument. It depicts the synth kernel, rather than
/// a microphone input or a live FFT of the complete overlapping voice mix.
struct MetroStationPillView: View {
    let settings: MetronomeSettings
    let snapshot: BeatSnapshot
    let isRunning: Bool
    let mode: ScopeMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .caption2) private var titleSize = 10.0
    @ScaledMetric(relativeTo: .caption2) private var axisSize = 9.0
    @ScaledMetric(relativeTo: .caption2) private var titleHeight = 14.0
    @ScaledMetric(relativeTo: .caption2) private var axisHeight = 11.0
    @State private var traces: PillTraceData?

    private let amber = Color(red: 1.0, green: 0.73, blue: 0.34)
    private var primary: Color {
        mode == .waveform
            ? Color(red: 0.31, green: 0.86, blue: 1.0)
            : Color(red: 0.76, green: 0.57, blue: 1.0)
    }
    private var secondary: Color {
        mode == .waveform
            ? Color(red: 0.21, green: 0.40, blue: 1.0)
            : Color(red: 0.96, green: 0.36, blue: 0.84)
    }
    private var carrier: Double {
        isRunning ? snapshot.tickFrequency ?? settings.pitch : settings.pitch
    }
    private var accented: Bool {
        isRunning && (snapshot.tickAccent
            ?? MetronomeTiming.pulseIsAccent(index: snapshot.absolutePulseIndex, settings: settings))
    }
    private var tickGain: Double {
        guard isRunning else { return settings.volume }
        if let strength = snapshot.tickStrength { return strength }
        return settings.soundEnabled
            ? MetronomeTiming.pulseStrength(index: snapshot.absolutePulseIndex, settings: settings) * settings.volume
            : 0
    }
    private var soundedTickTime: Double? { isRunning ? snapshot.tickElapsed : nil }
    private var pulseInterval: Double {
        MetronomeTiming.pulseDuration(index: snapshot.absolutePulseIndex, settings: settings)
    }
    private var perceptualResponse: Double {
        guard isRunning, !reduceMotion else { return 0 }
        let hapticClockStrength = settings.hapticsEnabled
            ? MetronomeTiming.pulseStrength(index: snapshot.absolutePulseIndex, settings: settings) : 0
        let strength = min(1, max(0, max(tickGain, hapticClockStrength)))
        return PillTickResponse.value(tickElapsed: soundedTickTime, pulseInterval: pulseInterval)
            * sqrt(strength)
    }
    private var stage: String {
        guard isRunning else { return "idle tick model" }
        guard let time = soundedTickTime else { return "armed" }
        if time < TickSynthesis.attackDuration { return "attack" }
        if time < TickSynthesis.duration - TickSynthesis.tailDuration { return "decay" }
        if time < TickSynthesis.duration { return "taper" }
        return "quiet"
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(mode == .waveform ? "WAVE" : "FREQ")
                .font(.system(size: titleSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: titleHeight)
            axisText(mode == .waveform ? "0 ms" : "6 kHz")
            Canvas { context, size in
                let plot = CGRect(x: 2, y: 2, width: max(1, size.width - 4), height: max(1, size.height - 4))
                drawCalibration(context: &context, plot: plot)
                guard let traces, traces.frequency == carrier else { return }
                if mode == .waveform {
                    drawWave(context: &context, plot: plot,
                             samples: accented ? traces.accentWave : traces.wave,
                             responseSamples: accented ? traces.accentPulseWave : traces.pulseWave)
                } else {
                    drawSpectrum(context: &context, plot: plot,
                                 bins: accented ? traces.accentSpectrum : traces.spectrum)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            axisText(mode == .waveform ? "55 ms" : "0 Hz")
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(minWidth: 28, idealWidth: 40, maxWidth: 42,
               minHeight: 140, idealHeight: 190, maxHeight: 218)
        .background {
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 0.055, green: 0.069, blue: 0.095),
                                              Color(red: 0.014, green: 0.022, blue: 0.037)],
                                     startPoint: .leading, endPoint: .trailing))
        }
        .overlay {
            Capsule().strokeBorder(
                LinearGradient(colors: [primary.opacity(contrast == .increased ? 0.7 : 0.36),
                                        .white.opacity(0.10), secondary.opacity(0.38)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
        }
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(mode == .waveform ? "metroStationWavePill" : "metroStationSpectrumPill")
        .accessibilityLabel(mode == .waveform ? "Vertical tick waveform" : "Vertical tick spectrum")
        .accessibilityValue(accessibilityDescription)
        .task(id: carrier) {
            let frequency = carrier
            if traces != nil && !isRunning {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
            }
            let result = await PillTraceCache.shared.trace(for: frequency)
            guard !Task.isCancelled, let result else { return }
            traces = result
        }
    }

    private var accessibilityDescription: String {
        let frequency = carrier.formatted(.number.precision(.fractionLength(0)))
        let responseDescription = reduceMotion
            ? "Reduce Motion keeps the reference static."
            : "The interior swell is a clock-synced perceptual cue with up to a 20 millisecond visual attack and 180 millisecond visual decay, shortened for fast pulses. It does not extend the audio tick or measure actuator intensity."
        if mode == .waveform {
            return "Unit-gain reference of an isolated \(frequency) hertz tick. Time runs from zero at the top to 55 milliseconds at the bottom; amplitude runs horizontally. The signal has a 1.5 millisecond attack, decay, and final 7 millisecond taper. Stage: \(stage). \(responseDescription)"
        }
        return "Discrete Fourier transform of the isolated \(frequency) hertz tick, with second and third harmonics. Frequency runs from zero at the bottom to 6000 hertz at the top. Reference magnitudes are normalized to the strongest peak. Amber marks the carrier. Stage: \(stage). \(responseDescription)"
    }

    private func axisText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: axisSize, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.74))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: axisHeight)
    }

    private func drawCalibration(context: inout GraphicsContext, plot: CGRect) {
        for index in 0...4 {
            let y = plot.minY + plot.height * Double(index) / 4
            var tick = Path()
            tick.move(to: CGPoint(x: plot.minX, y: y))
            tick.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(tick, with: .color(.white.opacity(index == 0 || index == 4 ? 0.17 : 0.07)), lineWidth: 0.5)
        }
        var spine = Path()
        let x = mode == .waveform ? plot.midX : plot.minX
        spine.move(to: CGPoint(x: x, y: plot.minY))
        spine.addLine(to: CGPoint(x: x, y: plot.maxY))
        context.stroke(spine, with: .color(primary.opacity(0.22)), lineWidth: 0.6)
    }

    private func drawWave(context: inout GraphicsContext, plot: CGRect, samples: [Double],
                          responseSamples: [Double]) {
        guard samples.count > 1 else { return }
        let attackY = plot.minY + plot.height * TickSynthesis.attackDuration / TickSynthesis.duration
        let taperY = plot.minY + plot.height * (TickSynthesis.duration - TickSynthesis.tailDuration) / TickSynthesis.duration
        context.fill(Path(CGRect(x: plot.minX, y: plot.minY, width: plot.width,
                                 height: attackY - plot.minY)), with: .color(amber.opacity(0.10)))
        context.fill(Path(CGRect(x: plot.minX, y: taperY, width: plot.width,
                                 height: plot.maxY - taperY)), with: .color(.white.opacity(0.035)))
        for edge in [attackY, taperY] {
            var boundary = Path()
            boundary.move(to: CGPoint(x: plot.minX, y: edge))
            boundary.addLine(to: CGPoint(x: plot.maxX, y: edge))
            context.stroke(boundary, with: .color(.white.opacity(0.24)),
                           style: StrokeStyle(lineWidth: 0.6, dash: [1, 2]))
        }
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: plot.midX + sample * plot.width / 2,
                                y: plot.minY + plot.height * Double(index) / Double(samples.count - 1))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .linearGradient(
            Gradient(colors: [primary.opacity(0.42), secondary.opacity(0.36)]),
            startPoint: CGPoint(x: plot.midX, y: plot.minY), endPoint: CGPoint(x: plot.midX, y: plot.maxY)),
                       style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        drawWaveResponse(context: &context, plot: plot, samples: responseSamples)
    }

    private func drawWaveResponse(context: inout GraphicsContext, plot: CGRect, samples: [Double]) {
        let response = perceptualResponse
        guard response > 0, samples.count > 1 else { return }
        let halfWidth = max(0, plot.width / 2 - 1) * response
        var ribbon = Path()
        var pulse = Path()
        for (index, sample) in samples.enumerated() {
            let y = plot.minY + plot.height * Double(index) / Double(samples.count - 1)
            let upper = CGPoint(x: plot.midX + abs(sample) * halfWidth, y: y)
            let point = CGPoint(x: plot.midX + sample * halfWidth, y: y)
            if index == 0 {
                ribbon.move(to: upper)
                pulse.move(to: point)
            } else {
                ribbon.addLine(to: upper)
                pulse.addLine(to: point)
            }
        }
        for index in samples.indices.reversed() {
            ribbon.addLine(to: CGPoint(x: plot.midX - abs(samples[index]) * halfWidth,
                                      y: plot.minY + plot.height * Double(index) / Double(samples.count - 1)))
        }
        ribbon.closeSubpath()
        context.fill(ribbon, with: .linearGradient(
            Gradient(colors: [primary.opacity(0.36), secondary.opacity(0.22)]),
            startPoint: CGPoint(x: plot.midX, y: plot.minY), endPoint: CGPoint(x: plot.midX, y: plot.maxY)))
        context.stroke(pulse, with: .color(primary.opacity(0.92)),
                       style: StrokeStyle(lineWidth: 1.8 * response, lineJoin: .round))
    }

    private func drawSpectrum(context: inout GraphicsContext, plot: CGRect, bins: [SpectrumBin]) {
        guard bins.count > 1 else { return }
        let maximumFrequency = 6_000.0
        var path = Path()
        path.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        for bin in bins where bin.frequency <= maximumFrequency {
            path.addLine(to: CGPoint(x: plot.minX + plot.width * bin.magnitude,
                                    y: plot.maxY - plot.height * bin.frequency / maximumFrequency))
        }
        var fill = path
        fill.addLine(to: CGPoint(x: plot.minX, y: plot.minY))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
            Gradient(colors: [secondary.opacity(0.07), primary.opacity(0.025)]),
            startPoint: CGPoint(x: plot.maxX, y: plot.maxY), endPoint: CGPoint(x: plot.minX, y: plot.minY)))
        context.stroke(path, with: .linearGradient(
            Gradient(colors: [secondary.opacity(0.38), primary.opacity(0.42)]), startPoint: CGPoint(x: plot.maxX, y: plot.maxY),
            endPoint: CGPoint(x: plot.minX, y: plot.minY)),
                       style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))

        drawSpectrumResponse(context: &context, plot: plot, bins: bins)

        let carrierY = plot.maxY - plot.height * carrier / maximumFrequency
        var marker = Path()
        marker.move(to: CGPoint(x: plot.minX, y: carrierY))
        marker.addLine(to: CGPoint(x: plot.maxX, y: carrierY))
        context.stroke(marker, with: .color(amber),
                       style: StrokeStyle(lineWidth: 0.75, dash: [2, 2]))
        context.fill(Path(ellipseIn: CGRect(x: plot.maxX - 2, y: carrierY - 1.8, width: 3.6, height: 3.6)),
                     with: .color(amber))
    }

    private func drawSpectrumResponse(context: inout GraphicsContext, plot: CGRect, bins: [SpectrumBin]) {
        let response = perceptualResponse
        guard response > 0 else { return }
        var pulse = Path()
        pulse.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        for bin in bins where bin.frequency <= 6_000 {
            pulse.addLine(to: CGPoint(x: plot.minX + (plot.width - 1) * bin.magnitude * response,
                                     y: plot.maxY - plot.height * bin.frequency / 6_000))
        }
        var energy = pulse
        energy.addLine(to: CGPoint(x: plot.minX, y: plot.minY))
        energy.closeSubpath()
        context.fill(energy, with: .linearGradient(
            Gradient(colors: [secondary.opacity(0.42), primary.opacity(0.22)]),
            startPoint: CGPoint(x: plot.maxX, y: plot.maxY), endPoint: CGPoint(x: plot.minX, y: plot.minY)))
        context.stroke(pulse, with: .color(secondary.opacity(0.94)),
                       style: StrokeStyle(lineWidth: 1.8 * response, lineJoin: .round))
    }
}

/// A shared actor keeps the Fourier work off the main actor and prevents the two
/// flanking instruments from calculating the same carrier independently.
private actor PillTraceCache {
    static let shared = PillTraceCache()
    private var entries: [Double: PillTraceData] = [:]
    private var order: [Double] = []

    func trace(for frequency: Double) -> PillTraceData? {
        guard !Task.isCancelled else { return nil }
        if let existing = entries[frequency] { return existing }
        let result = PillTraceData(frequency: frequency)
        entries[frequency] = result
        order.append(frequency)
        if order.count > 8 { entries[order.removeFirst()] = nil }
        return result
    }
}

/// Both accent variants are cached, so bar accents select existing arrays.
nonisolated private struct PillTraceData: Sendable {
    let frequency: Double
    let wave: [Double]
    let accentWave: [Double]
    let pulseWave: [Double]
    let accentPulseWave: [Double]
    let spectrum: [SpectrumBin]
    let accentSpectrum: [SpectrumBin]

    init(frequency: Double) {
        self.frequency = frequency
        let regular = TickSynthesis.waveform(frequency: frequency, accent: false, count: 768)
        let accented = TickSynthesis.waveform(frequency: frequency, accent: true, count: 768)
        wave = regular
        accentWave = accented
        let regularPeak = regular.lazy.map { abs($0) }.max() ?? 0
        let accentPeak = accented.lazy.map { abs($0) }.max() ?? 0
        pulseWave = regularPeak > 0 ? regular.map { $0 / regularPeak } : regular
        accentPulseWave = accentPeak > 0 ? accented.map { $0 / accentPeak } : accented
        spectrum = TickSynthesis.spectrum(frequency: frequency, accent: false, binCount: 512, sampleCount: 4096)
        accentSpectrum = TickSynthesis.spectrum(frequency: frequency, accent: true, binCount: 512, sampleCount: 4096)
    }
}

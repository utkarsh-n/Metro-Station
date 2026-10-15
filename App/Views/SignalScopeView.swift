import SwiftUI
import MetronomeCore

enum ScopeMode: String, CaseIterable, Identifiable {
    case waveform
    case spectrum

    var id: Self { self }
    var label: String { self == .waveform ? "Waveform" : "Spectrum" }
    var symbol: String { self == .waveform ? "waveform.path" : "chart.bar.xaxis" }
}

struct SignalScopeView: View {
    let settings: MetronomeSettings
    let snapshot: BeatSnapshot
    let isRunning: Bool
    let mode: ScopeMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var metadataSize = 11.0
    @ScaledMetric(relativeTo: .caption2) private var axisSize = 10.0
    @ScaledMetric(relativeTo: .caption2) private var chartHeight = 98.0
    @State private var traces: ScopeTraces?
    private let cyan = Color(red: 0.32, green: 0.91, blue: 0.96)
    private let amber = Color(red: 1, green: 0.72, blue: 0.31)

    private var currentPulse: Int { snapshot.absolutePulseIndex }
    private var isAccent: Bool { snapshot.tickAccent ?? MetronomeTiming.pulseIsAccent(index: currentPulse, settings: settings) }
    private var tickFrequency: Double { isRunning ? snapshot.tickFrequency ?? settings.pitch : settings.pitch }
    private var tickGain: Double {
        if isRunning, let strength = snapshot.tickStrength { return strength }
        return MetronomeTiming.pulseStrength(index: currentPulse, settings: settings) * settings.volume
    }
    private var carrierLabel: String { tickFrequency.formatted(.number.precision(.fractionLength(0))) + " Hz" }
    private var tickTime: Double? { snapshot.tickElapsed }
    private var tickStage: String {
        guard isRunning else { return "TICK MODEL" }
        guard let tickTime else { return "ARMED" }
        if tickTime < TickSynthesis.attackDuration { return "ATTACK" }
        if tickTime < TickSynthesis.duration - TickSynthesis.tailDuration { return "DECAY" }
        if tickTime < TickSynthesis.duration { return "TAPER" }
        return "QUIET"
    }

    var body: some View {
        VStack(spacing: 7) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        carrierReadout
                        traceReadout
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        carrierReadout
                        Spacer()
                        traceReadout
                    }
                }
            }
            .font(.system(size: metadataSize, weight: .medium, design: .monospaced))
            .tracking(0.3)
            .padding(.horizontal, 3)

            Canvas { context, size in
                let left = max(27, axisSize * 2.2 + 5)
                let bottom = max(28, axisSize * 1.65 + 11)
                let top = max(6, axisSize * 0.6)
                let plot = CGRect(x: left, y: top, width: max(1, size.width - left - 8), height: max(1, size.height - top - bottom))
                drawGrid(context: &context, plot: plot)
                if let traces, traces.frequency == tickFrequency {
                    if mode == .waveform {
                        drawWaveform(context: &context, plot: plot, samples: isAccent ? traces.accentWaveform : traces.waveform,
                                     gain: tickGain)
                    } else {
                        drawSpectrum(context: &context, plot: plot, bins: isAccent ? traces.accentSpectrum : traces.spectrum)
                    }
                }
            }
            .frame(height: chartHeight)
            .background(Color(red: 0.022, green: 0.036, blue: 0.047), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(mode == .waveform ? "Tick waveform" : "Tick frequency spectrum")
            .accessibilityValue(mode == .waveform ? "An isolated 55 millisecond tick at \(carrierLabel), with a 1.5 millisecond attack, decaying envelope, and final 7 millisecond taper. Current envelope stage: \(tickStage)." : "Spectrum of the isolated synthesized tick. Carrier at \(carrierLabel), with second and third harmonics. Magnitudes normalized to the largest peak. Current envelope stage: \(tickStage).")

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        accentReadout
                        traceExplanation
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        accentReadout
                        Spacer(minLength: 0)
                        traceExplanation
                    }
                }
            }
            .font(.system(size: metadataSize, weight: .regular, design: .monospaced))
            .padding(.horizontal, 3)
            .accessibilityElement(children: .combine)
        }
        .task(id: tickFrequency) {
            let frequency = tickFrequency
            // Idle preview sliders are debounced. A sounded voice already changes
            // only at pulse onsets, so its trace is refreshed immediately.
            if traces != nil && !isRunning {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
            }
            let result = await Task.detached(priority: .userInitiated) {
                ScopeTraces(frequency: frequency)
            }.value
            guard !Task.isCancelled else { return }
            traces = result
        }
    }

    private var carrierReadout: some View {
        HStack(spacing: 5) {
            Circle().fill(amber).frame(width: 3, height: 3)
            Text(carrierLabel).foregroundStyle(amber)
            Text("CARRIER").foregroundStyle(.white.opacity(0.68))
        }
    }

    private var traceReadout: some View {
        Text(mode == .waveform ? "ISOLATED TICK" : "NORMALIZED DFT")
            .foregroundStyle(.white.opacity(0.68))
    }

    private var accentReadout: some View {
        HStack(spacing: 5) {
            Text(tickStage)
                .foregroundStyle(tickStage == "ATTACK" ? amber : tickStage == "DECAY" ? cyan : .white.opacity(0.75))
            if isRunning && isAccent {
                Circle().fill(amber).frame(width: 3, height: 3)
                    .accessibilityLabel("Accented tick")
            }
        }
    }

    private var traceExplanation: some View {
        Text(mode == .waveform ? "55 ms ENVELOPE" : "FINITE TICK → PEAKS")
            .foregroundStyle(.white.opacity(0.68))
    }

    private func drawGrid(context: inout GraphicsContext, plot: CGRect) {
        for index in 0...4 {
            let x = plot.minX + plot.width * Double(index) / 4
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(line, with: .color(.white.opacity(index == 0 ? 0.15 : 0.065)), lineWidth: 0.6)
            let label: String
            if mode == .waveform {
                label = index == 4 ? "55 ms" : String(Int((Double(index) * 55 / 4).rounded()))
            } else {
                label = index == 4 ? "6 kHz" : index == 0 ? "0" : String(format: "%.1fk", Double(index) * 1.5)
            }
            let anchor: UnitPoint = index == 0 ? .leading : index == 4 ? .trailing : .center
            context.draw(axisLabel(label), at: CGPoint(x: x, y: plot.maxY + axisSize * 0.65 + 6.5), anchor: anchor)
        }
        for index in 0...4 {
            let y = plot.minY + plot.height * Double(index) / 4
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(.white.opacity(index == 2 && mode == .waveform ? 0.20 : 0.065)), lineWidth: 0.6)
        }
        if mode == .waveform {
            context.draw(axisLabel("+1"), at: CGPoint(x: plot.minX - 6, y: plot.minY + 3), anchor: .trailing)
            context.draw(axisLabel("0"), at: CGPoint(x: plot.minX - 6, y: plot.midY), anchor: .trailing)
            context.draw(axisLabel("−1"), at: CGPoint(x: plot.minX - 6, y: plot.maxY - 3), anchor: .trailing)
        } else {
            context.draw(axisLabel("1"), at: CGPoint(x: plot.minX - 6, y: plot.minY + 3), anchor: .trailing)
            context.draw(axisLabel("0"), at: CGPoint(x: plot.minX - 6, y: plot.maxY - 3), anchor: .trailing)
        }
    }

    private func drawWaveform(context: inout GraphicsContext, plot: CGRect, samples: [Double], gain: Double) {
        guard samples.count > 1 else { return }
        let attackEdge = plot.minX + plot.width * TickSynthesis.attackDuration / TickSynthesis.duration
        let taperEdge = plot.minX + plot.width * (TickSynthesis.duration - TickSynthesis.tailDuration) / TickSynthesis.duration
        context.fill(Path(CGRect(x: plot.minX, y: plot.minY, width: attackEdge - plot.minX, height: plot.height)), with: .color(amber.opacity(0.085)))
        context.fill(Path(CGRect(x: taperEdge, y: plot.minY, width: plot.maxX - taperEdge, height: plot.height)), with: .color(.white.opacity(0.035)))
        for edge in [attackEdge, taperEdge] {
            var boundary = Path()
            boundary.move(to: CGPoint(x: edge, y: plot.minY))
            boundary.addLine(to: CGPoint(x: edge, y: plot.maxY))
            context.stroke(boundary, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 0.6, dash: [1, 3]))
        }
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: plot.minX + plot.width * Double(index) / Double(samples.count - 1), y: plot.midY - sample * gain * plot.height / 2)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(cyan.opacity(0.16)), style: StrokeStyle(lineWidth: 3.3, lineJoin: .round))
        context.stroke(path, with: .color(cyan.opacity(0.94)), style: StrokeStyle(lineWidth: 1.0, lineJoin: .round))

        // The cursor only moves while the real finite tick is sounding, then
        // rests. Its sweep is in milliseconds, independent of the beat rate.
        if isRunning && !reduceMotion, let tickTime, tickTime < TickSynthesis.duration {
            let x = plot.minX + plot.width * tickTime / TickSynthesis.duration
            var cursor = Path()
            cursor.move(to: CGPoint(x: x, y: plot.minY))
            cursor.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(cursor, with: .color(amber.opacity(0.5)), lineWidth: 0.75)
        }
    }

    private func drawSpectrum(context: inout GraphicsContext, plot: CGRect, bins: [SpectrumBin]) {
        guard bins.count > 1 else { return }
        let maximumFrequency = 6_000.0
        var path = Path()
        path.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        for bin in bins where bin.frequency <= maximumFrequency {
            let point = CGPoint(x: plot.minX + plot.width * bin.frequency / maximumFrequency, y: plot.maxY - bin.magnitude * plot.height)
            path.addLine(to: point)
        }
        var fill = path
        fill.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(Gradient(colors: [cyan.opacity(0.28), cyan.opacity(0.018)]), startPoint: CGPoint(x: plot.midX, y: plot.minY), endPoint: CGPoint(x: plot.midX, y: plot.maxY)))
        context.stroke(path, with: .color(cyan), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))

        let carrierX = plot.minX + plot.width * tickFrequency / maximumFrequency
        var carrier = Path()
        carrier.move(to: CGPoint(x: carrierX, y: plot.minY))
        carrier.addLine(to: CGPoint(x: carrierX, y: plot.maxY))
        context.stroke(carrier, with: .color(amber.opacity(0.55)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
        var marker = Path()
        marker.move(to: CGPoint(x: carrierX - 3, y: plot.minY))
        marker.addLine(to: CGPoint(x: carrierX + 3, y: plot.minY))
        marker.addLine(to: CGPoint(x: carrierX, y: plot.minY + 5))
        marker.closeSubpath()
        context.fill(marker, with: .color(amber))
    }

    private func axisLabel(_ label: String) -> Text {
        Text(label)
            .font(.system(size: axisSize, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.68))
    }
}

/// Both accent variants are computed only when the tick's carrier changes.
private struct ScopeTraces: Sendable {
    let frequency: Double
    let waveform: [Double]
    let accentWaveform: [Double]
    let spectrum: [SpectrumBin]
    let accentSpectrum: [SpectrumBin]

    init(frequency: Double) {
        self.frequency = frequency
        waveform = TickSynthesis.waveform(frequency: frequency, accent: false, count: 768)
        accentWaveform = TickSynthesis.waveform(frequency: frequency, accent: true, count: 768)
        spectrum = TickSynthesis.spectrum(frequency: frequency, accent: false, binCount: 512, sampleCount: 4096)
        accentSpectrum = TickSynthesis.spectrum(frequency: frequency, accent: true, binCount: 512, sampleCount: 4096)
    }
}

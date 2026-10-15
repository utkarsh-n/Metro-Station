import SwiftUI
import MetronomeCore

struct PhysicsView: View {
    let controller: MetronomeController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Time you can see.\nFrequency you can feel.")
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        Text("The dial tracks the beat clock. The scope reveals the synthesized waveform inside each tick.")
                            .foregroundStyle(MetroStationTheme.secondary)
                    }
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        let snapshot = controller.snapshot(at: context.date)
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Beat phase", systemImage: "circle.dotted.circle")
                                .font(.headline).foregroundStyle(MetroStationTheme.cyan)
                            Text("φ = 2π · fractional(beats)").font(.system(.title3, design: .monospaced))
                            HStack {
                                value("PHASE", "\(Int(snapshot.beatPhase * 360))°")
                                value("PERIOD T", "\(Int(controller.effectiveSettings.beatDuration * 1000)) ms")
                                value("RATE f", String(format: "%.2f Hz", controller.effectiveSettings.beatFrequency))
                            }
                            Text("One revolution is one quarter note beat. At a steady tempo, beats = t / T. Tempo edits preserve accumulated beats and change only how quickly phase advances. Phase 0° is the tick; 90°, 180° and 270° mark equal fractions of the interval. A subdivision adds scheduled pulses inside that interval.")
                                .font(.subheadline).foregroundStyle(MetroStationTheme.secondary)
                        }.instrumentPanel()
                    }
                    explanation("Two different frequencies", symbol: "waveform.path", color: MetroStationTheme.amber,
                                formula: "fbeat = BPM / 60\nT = 1 / fbeat\nfpulse = subdivision × fbeat",
                                text: "At 120 BPM, the beat repeats at 2 Hz: once every 500 ms. An 880 Hz tick vibrates 880 times per second during its short envelope. Raising the tick pitch changes its brightness without changing tempo. With swing, pulse spacing alternates; the displayed pulse rate is its average.")
                    explanation("The anatomy of a tick", symbol: "waveform", color: MetroStationTheme.cyan,
                                formula: "signal(t) = envelope(t) × tone(t)",
                                text: "A smooth 1.5 ms attack excites an exponentially decaying 55 ms tone. A 7 ms taper ends the tail cleanly. Its carrier and small harmonics form the sound; beat one changes their weights, not the fundamental pitch. The short envelope spreads energy around each frequency peak. Wave shows a single tick's synthesized samples; Spectrum is their magnitude DFT, normalized to the largest peak. Fast swung pulses can overlap. This is a signal model, not a microphone measurement.")
                    explanation("Touch follows the clock", symbol: "hand.point.up.braille", color: MetroStationTheme.amber,
                                formula: "beat one → stronger pulse\nhigher pitch → sharper pulse",
                                text: "Core Haptics schedules pulses ahead of time. The first beat gets a strong, distinct accent; the remaining beats and subdivisions get softer pulses. Haptic sharpness represents pitch perceptually. iPhone hardware has its own resonances and cannot vibrate at every selected audio frequency.")
                    explanation("The familiar ticker", symbol: "metronome", color: MetroStationTheme.cyan,
                                formula: "θ = 26° · cos(π · beats)\nfull swing = two beats",
                                text: "The metal arm rests straight up at 0°. While playing, it swings left and right and reaches alternating endpoints on the quarter note ticks. It follows the same accumulated beat position as the audio, including gradual tempo adjustments. This is an ideal phase display, not a simulation of a mechanical escapement. Reduce Motion keeps the arm upright.")
                    explanation("Feel the tempo wheel", symbol: "arrow.trianglehead.2.clockwise.rotate.90", color: MetroStationTheme.amber,
                                formula: "clockwise → faster\ncounterclockwise → slower",
                                text: "Every tempo is a whole BPM. The left watch crown moves one BPM per notch, and its minus/plus buttons give exact single steps. The right crown jumps to the next or previous musical tempo marking. Clockwise notches feel crisp; counterclockwise notches feel deeper. Marking jumps use a heavier notch. Notch density is limited during fast tuning. Tempo edits preserve accumulated beats; Largo through Prestissimo labels describe approximate practice ranges.")
                    explanation("A moving light field", symbol: "move.3d", color: MetroStationTheme.cyan,
                                formula: "phone gravity → highlight position",
                                text: "Filtered Core Motion gravity shifts the rim highlights, chromatic reflection and depth of the dial. The glass controls use the native Liquid Glass material. The dial lighting is an artistic optical model; it does not alter the metronome clock or simulate a mechanical escapement.")
                    Text("Built for listening and practice in the foreground. Speaker, Bluetooth and haptic hardware add latency; digital timing does not guarantee zero physical output delay.")
                        .font(.caption).foregroundStyle(MetroStationTheme.secondary)
                }
                .padding(24)
            }
            .background(MetroStationTheme.background)
            .navigationTitle("Inside the tick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("physicsDone")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func value(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 8, design: .monospaced)).foregroundStyle(MetroStationTheme.secondary)
            Text(text).font(.system(.callout, design: .monospaced)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func explanation(_ title: String, symbol: String, color: Color, formula: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(color)
            Text(formula).font(.system(.callout, design: .monospaced)).lineSpacing(5)
            Text(text).font(.subheadline).foregroundStyle(MetroStationTheme.secondary).lineSpacing(3)
        }.instrumentPanel()
    }
}

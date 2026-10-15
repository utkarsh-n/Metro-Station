import SwiftUI
import MetronomeCore

struct ControlsView: View {
    @Bindable var controller: MetronomeController
    @Binding var motionEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Tempo")
                        Spacer()
                        Text("\(Int(controller.settings.bpm.rounded())) BPM")
                            .monospacedDigit().foregroundStyle(MetroStationTheme.cyan)
                            .lineLimit(1)
                            .accessibilityIdentifier("tempoValue")
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(TempoMarking.forBPM(controller.settings.bpm).name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(TempoMarking.forBPM(controller.settings.bpm).character)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Slider(value: $controller.settings.bpm, in: 30...240, step: 1)
                        .accessibilityLabel("Tempo")
                        .scrollGestureBoundary(identifier: "tempoSlider")
                    Stepper("1 BPM adjustment", value: $controller.settings.bpm, in: 30...240, step: 1)
                        .accessibilityIdentifier("tempoStepper")
                        // Native button bounds extend beyond the text's height.
                        // Protect their full touch target, including both edges.
                        .frame(minHeight: 44)
                        .scrollGestureBoundary(identifier: "tempoStepper")
                    HStack {
                        ForEach([60, 90, 120, 180], id: \.self) { bpm in
                            Button("\(bpm)") { controller.settings.bpm = Double(bpm) }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .buttonStyle(.glass)
                                .accessibilityLabel("\(bpm) BPM preset")
                                .accessibilityIdentifier("preset\(bpm)")
                        }
                    }
                } header: {
                    Text("Beat clock")
                } footer: {
                    Text("All tempos use whole BPM. The left crown steps by one; the right crown jumps between tempo markings. Clockwise is faster, counterclockwise is slower. Tempo edits preserve the current beat and bar. Tempo names use approximate practice ranges.")
                }

                Section("Rhythm") {
                    Picker("Beats per bar", selection: $controller.settings.beatsPerBar) {
                        ForEach(1...12, id: \.self) { Text("\($0) / 4").tag($0) }
                    }
                    Picker("Subdivision", selection: $controller.settings.subdivision) {
                        Text("Quarter · 1 pulse").tag(1)
                        Text("Eighth · 2 pulses").tag(2)
                        Text("Triplet · 3 pulses").tag(3)
                        Text("Sixteenth · 4 pulses").tag(4)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Swing")
                            Spacer()
                            Text(String(format: "%.1f : %.1f", 50 + controller.settings.swing * 50, 50 - controller.settings.swing * 50))
                                .monospacedDigit().foregroundStyle(MetroStationTheme.amber)
                        }
                        Slider(value: $controller.settings.swing, in: 0...0.45, step: 0.01)
                            .accessibilityLabel("Swing delay")
                            .disabled(controller.settings.subdivision % 2 != 0)
                            .scrollGestureBoundary(identifier: "swingSlider")
                        Text("Swing delays the second pulse of each pair. Available for eighths and sixteenths; the quarter note beat stays steady.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Audible ticks", isOn: $controller.settings.soundEnabled)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tick pitch")
                            Spacer()
                            Text("\(Int(controller.settings.pitch)) Hz").monospacedDigit()
                                .foregroundStyle(MetroStationTheme.amber)
                        }
                        Slider(value: $controller.settings.pitch, in: 220...1760, step: 10)
                            .accessibilityLabel("Tick pitch")
                            .scrollGestureBoundary(identifier: "pitchSlider")
                        HStack {
                            Text("Warm · 220 Hz")
                            Spacer()
                            Text("Bright · 1,760 Hz")
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                    Slider(value: $controller.settings.volume, in: 0...1) {
                        Text("Tick volume")
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .accessibilityLabel("Tick volume")
                    .scrollGestureBoundary(identifier: "volumeSlider")
                    Toggle("Haptic pulses", isOn: $controller.settings.hapticsEnabled)
                } header: { Text("Sound + touch") } footer: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(controller.soundStatus)
                        Text(controller.hapticStatus)
                        Text("Beat one is stronger. Subdivisions are softer. Pitch maps to haptic sharpness, while the audible tick retains the selected pitch.")
                    }
                }

                Section {
                    Toggle("Motion lighting", isOn: $motionEnabled)
                    Label("Tilt the phone to move the dial highlights.", systemImage: "move.3d")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Instrument surface") } footer: {
                    Text("Reduce Motion turns off tilt effects and the sweeping hand. Reduce Transparency gives the dial an opaque face.")
                }
            }
            .navigationTitle("Instrument controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("controlsDone")
                }
            }
        }
        .preferredColorScheme(.dark)
        // Direct manipulation must not be handed to the sheet's dismissal pan.
        .interactiveDismissDisabled()
    }
}

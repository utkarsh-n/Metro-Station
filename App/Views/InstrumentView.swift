import SwiftUI
import MetronomeCore

private enum InstrumentSheet: String, Identifiable {
    case physics
    var id: String { rawValue }
}

struct InstrumentView: View {
    @State private var controller = MetronomeController()
    @State private var motion = MotionLighting()
    @State private var scopeMode: ScopeMode = .waveform
    @State private var sheet: InstrumentSheet?
    @State private var showsControls = false
    #if DEBUG
    @State private var pillVisualSample: BeatSnapshot?
    @State private var pillVisualSampleStage = "awaitingPeak"
    @State private var glassVisualSample: BeatSnapshot?
    @State private var glassVisualSampleStage = "awaitingExpanded"
    @State private var tiltVisualSnapshot: BeatSnapshot?
    @State private var tiltVisualVector = SIMD2<Double>.zero
    @State private var tiltVisualEvidence = ""
    @State private var tiltVisualStage = "awaitingPositive"
    @Environment(\.accessibilityReduceTransparency) private var glassReduceTransparency
    private static let glassCaptureTolerance = 0.01
    #endif
    @AppStorage("spectral.motionLighting") private var motionEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                InstrumentBackground()
                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 12)
                    ScrollView {
                        Group {
                        if landscape {
                            HStack(alignment: .center, spacing: 24) {
                                VStack(spacing: 12) {
                                    clockDisplay(minimumInterval: 1.0 / 60.0) { snapshot in
                                        gaugeCluster(snapshot: snapshot, availableWidth: geometry.size.width * 0.47)
                                    }
                                    mainTempoStepper
                                    crowns
                                }
                                .frame(maxWidth: geometry.size.width * 0.47)
                                VStack(spacing: 18) {
                                    clockDisplay { snapshot in
                                        VStack(spacing: 18) {
                                            telemetry(snapshot: snapshot)
                                            beatStrip(snapshot: snapshot)
                                            scope(snapshot: snapshot)
                                        }
                                    }
                                    rhythmControls
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            VStack(spacing: 12) {
                                clockDisplay(minimumInterval: 1.0 / 60.0) { snapshot in
                                    gaugeCluster(snapshot: snapshot, availableWidth: geometry.size.width - 24)
                                }
                                mainTempoStepper.padding(.horizontal, 10)
                                crowns
                                    .padding(.horizontal, 10)
                                clockDisplay { snapshot in
                                    VStack(spacing: 14) {
                                        telemetry(snapshot: snapshot)
                                        beatStrip(snapshot: snapshot)
                                        scope(snapshot: snapshot)
                                    }
                                    .padding(.horizontal, 10)
                                }
                                rhythmControls.padding(.horizontal, 10)
                            }
                            .frame(maxWidth: 540)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                        }
                        }
                        // Leave the final controls reachable above the floating
                        // transport, while content continues behind its glass.
                        .padding(.bottom, 98)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("instrumentScroll")
                    .overlay(alignment: .bottom) {
                        transport.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 12)
                    }
                }
            }
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("--physical-qa") {
                VStack(spacing: 0) {
                    Text(controller.physicalAudioExportStatus)
                        .accessibilityIdentifier(controller.physicalAudioExportStatus == "complete"
                            ? "physicalAudioExportComplete" : "physicalAudioExportStatus")
                    if controller.physicalAudioExportStatus == "complete" {
                        let stable = PhysicalScrollAudit.shared.controlTouchesStayedStationary
                        Text(stable ? "Scroll audit stable" : "Scroll audit failure")
                            .accessibilityIdentifier(stable
                                ? "physicalScrollAuditStable" : "physicalScrollAuditFailure")
                    }
                }
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if ProcessInfo.processInfo.arguments.contains("--pill-visual-qa") {
                VStack(spacing: 0) {
                    Text(pillVisualSampleStage)
                        .font(.system(size: 1))
                        .accessibilityIdentifier(pillVisualSampleStage == "peakReady"
                            ? "pillVisualPeakReady" : pillVisualSampleStage == "quietReady"
                            ? "pillVisualQuietReady" : "pillVisualSampleStatus")
                    Button("Quiet sample") { pillVisualSampleStage = "awaitingQuiet" }
                        .font(.system(size: 10))
                        .frame(width: 72, height: 44)
                        .background(MetroStationTheme.panel)
                        .accessibilityIdentifier("pillVisualShowQuiet")
                }
            }
        }
        .task(id: pillVisualSampleStage) {
            guard ProcessInfo.processInfo.arguments.contains("--pill-visual-qa"),
                  pillVisualSampleStage == "awaitingPeak" || pillVisualSampleStage == "awaitingQuiet" else { return }
            let waitingForPeak = pillVisualSampleStage == "awaitingPeak"
            while !Task.isCancelled {
                if controller.isRunning {
                    let sample = controller.snapshot(at: Date())
                    let interval = MetronomeTiming.pulseDuration(index: sample.absolutePulseIndex,
                                                               settings: controller.effectiveSettings)
                    let level = PillTickResponse.value(tickElapsed: sample.tickElapsed,
                                                       pulseInterval: interval)
                    let quiet = sample.tickElapsed.map { $0 >= PillTickResponse.duration(pulseInterval: interval) } ?? false
                    if waitingForPeak ? level >= 0.95 : quiet {
                        // Hold an actual rendered sample for native pixel comparison;
                        // the gauge, audio engine, and haptic clock keep advancing.
                        pillVisualSample = sample
                        pillVisualSampleStage = waitingForPeak ? "peakReady" : "quietReady"
                        break
                    }
                }
                do { try await Task.sleep(for: .milliseconds(8)) }
                catch { break }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if ProcessInfo.processInfo.arguments.contains("--glass-dial-qa") {
                VStack(spacing: 0) {
                    Text(glassVisualSampleDescription)
                        .font(.system(size: 1))
                        .accessibilityIdentifier(glassVisualSampleStage == "expandedReady"
                            ? "glassDialExpandedReady" : glassVisualSampleStage == "compressedReady"
                            ? "glassDialCompressedReady" : "glassDialSampleStatus")
                    Button { glassVisualSampleStage = "awaitingExpanded" } label: {
                        Text("Expand sample").frame(width: 72, height: 44)
                    }
                        .accessibilityIdentifier("glassDialShowExpanded")
                    Button { glassVisualSampleStage = "awaitingCompressed" } label: {
                        Text("Compress sample").frame(width: 72, height: 44)
                    }
                        .accessibilityIdentifier("glassDialShowCompressed")
                }
                .font(.system(size: 9))
                .buttonStyle(.bordered)
                .frame(width: 84)
                .background(MetroStationTheme.panel)
            }
        }
        .task(id: glassVisualSampleStage) {
            guard ProcessInfo.processInfo.arguments.contains("--glass-dial-qa"),
                  glassVisualSampleStage == "awaitingExpanded" || glassVisualSampleStage == "awaitingCompressed" else { return }
            let expanded = glassVisualSampleStage == "awaitingExpanded"
            let phase = expanded ? GlassDialMotion.peakPhase : GlassDialMotion.compressionPhase
            while !Task.isCancelled {
                if controller.isRunning {
                    let sample = controller.snapshot(at: Date())
                    if abs(sample.beatPhase - phase) <= Self.glassCaptureTolerance {
                        // Hold only the lens at a real rendered beat phase;
                        // transport, pills and metal ticker continue normally.
                        glassVisualSample = sample
                        glassVisualSampleStage = expanded ? "expandedReady" : "compressedReady"
                        break
                    }
                }
                do { try await Task.sleep(for: .milliseconds(8)) }
                catch { break }
            }
        }
        .overlay(alignment: .bottomLeading) { tiltRefractionDiagnostics }
        .task(id: tiltVisualStage) { await captureTiltRefractionSample() }
        #endif
        .sheet(item: $sheet) { destination in
            switch destination {
            case .physics:
                PhysicsView(controller: controller)
            }
        }
        .fullScreenCover(isPresented: $showsControls) {
            ControlsView(controller: controller, motionEnabled: $motionEnabled)
        }
        .task {
            updateMotion()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--scrub-smoke-test") {
                await ScrubPlaybackCheck.run(controller: controller)
            }
            #endif
        }
        .onChange(of: motionEnabled) { updateMotion() }
        .onChange(of: reduceMotion) { updateMotion() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                controller.stop()
                motion.stop()
            } else {
                updateMotion()
            }
        }
    }

    private func clockDisplay<Content: View>(minimumInterval: Double = 1.0 / 30.0,
                                             @ViewBuilder content: @escaping (BeatSnapshot) -> Content) -> some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : minimumInterval,
                                paused: !controller.isRunning || scenePhase != .active)) { timeline in
            content(controller.snapshot(at: timeline.date))
        }
    }

    private var crowns: some View {
        TempoCrownsView(settings: controller.settings, motion: motion,
                        onFineStep: { controller.stepTempo(direction: $0) },
                        onMarkingStep: { controller.stepTempoMarking(direction: $0) },
                        onInteractionBegan: { controller.beginScrub() },
                        onInteractionEnded: { controller.endScrub() })
            .frame(maxWidth: 380)
    }

    /// Native repeat lives outside the animation timeline, preserving the touch
    /// while the rendered clock and visualizers advance independently.
    private var mainTempoStepper: some View {
        Stepper {
            HStack(spacing: 10) {
                Text("TEMPO")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(MetroStationTheme.secondary)
                Text("\(Int(controller.settings.bpm)) BPM")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MetroStationTheme.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("mainTempoValue")
            }
        } onIncrement: {
            controller.stepTempo(direction: 1)
        } onDecrement: {
            controller.stepTempo(direction: -1)
        } onEditingChanged: { editing in
            if editing { controller.beginScrub() }
            else { controller.endScrub() }
        }
        .accessibilityIdentifier("mainTempoStepper")
        .accessibilityHint("Hold plus or minus to repeat one BPM steps while watching the gauge.")
        // Protect the entire native button, including top and bottom edges.
        .frame(minHeight: 48)
        .padding(.horizontal, 14)
        .background(MetroStationTheme.panel.opacity(0.85), in: .capsule)
        .overlay(Capsule().strokeBorder(MetroStationTheme.cyan.opacity(0.14), lineWidth: 1))
        .scrollGestureBoundary(identifier: "mainTempoStepper")
        .frame(maxWidth: 380)
    }

    private func gaugeCluster(snapshot: BeatSnapshot, availableWidth: CGFloat) -> some View {
        #if DEBUG
        let pillSnapshot = pillVisualSample ?? snapshot
        #else
        let pillSnapshot = snapshot
        #endif
        let clusterWidth = min(availableWidth, 490)
        let pillWidth: CGFloat = clusterWidth < 350 ? 30 : 36
        let diameter = min(360, clusterWidth - pillWidth * 2 - 12)
        let pillHeight = min(218, diameter * 0.66)
        return HStack(alignment: .center, spacing: 6) {
            MetroStationPillView(settings: controller.effectiveSettings, snapshot: pillSnapshot,
                             isRunning: controller.isRunning, mode: .waveform)
                .frame(width: pillWidth, height: pillHeight)
            dial(snapshot: snapshot, width: diameter)
            MetroStationPillView(settings: controller.effectiveSettings, snapshot: pillSnapshot,
                             isRunning: controller.isRunning, mode: .spectrum)
                .frame(width: pillWidth, height: pillHeight)
        }
        .frame(width: diameter + pillWidth * 2 + 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(MetroStationTheme.cyan)
                    Text("Metro Station")
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text("WAVEFORM METRONOME")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(2.6).foregroundStyle(MetroStationTheme.secondary)
            }
            Spacer()
            Button { sheet = .physics } label: {
                Image(systemName: "atom")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Tick physics")
            .accessibilityIdentifier("physicsButton")
        }
    }

    private func dial(snapshot: BeatSnapshot, width: CGFloat) -> some View {
        #if DEBUG
        let heldSnapshot = tiltRefractionQAEnabled ? (tiltVisualSnapshot ?? snapshot) : snapshot
        let glassPhase = tiltRefractionQAEnabled ? tiltVisualSnapshot?.beatPhase : glassVisualSample?.beatPhase
        let glassTilt = tiltRefractionQAEnabled ? tiltVisualVector : nil
        let metalLighting: SIMD2<Double>? = tiltRefractionQAEnabled ? .zero : nil
        #else
        let heldSnapshot = snapshot
        let glassPhase: Double? = nil
        let glassTilt: SIMD2<Double>? = nil
        let metalLighting: SIMD2<Double>? = nil
        #endif
        return VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(controller.isRunning ? MetroStationTheme.cyan : MetroStationTheme.secondary)
                    .frame(width: 5, height: 5)
                Text(controller.isApplyingSettings ? "APPLYING SETTINGS" : (controller.isRunning ? "CLOCK RUNNING" : "READY TO PLAY"))
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer()
                Image(systemName: "move.3d")
                Text(motionEnabled && !reduceMotion && motion.isAvailable ? "TILT TO REFLECT" : "STILL LIGHT")
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .foregroundStyle(MetroStationTheme.secondary)
            // A render acknowledgement must never change the dial's height.
            .frame(height: 12)
            .padding(.horizontal, 8)
            GaugeView(settings: controller.settings, snapshot: heldSnapshot,
                      isRunning: controller.isRunning, motion: motion,
                      glassBeatPhase: glassPhase,
                      glassTiltOverride: glassTilt, metalLightingOverride: metalLighting,
                      onScrubBegan: { controller.beginScrub() },
                      onScrubEnded: { controller.endScrub() }) { bpm in
                controller.scrubTempo(to: bpm)
            }
            .frame(width: width, height: width)
        }
        .frame(width: width)
    }

    #if DEBUG
    private var tiltRefractionQAEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--tilt-refraction-qa")
            || ProcessInfo.processInfo.arguments.contains("--tilt-refraction-live-qa")
    }

    @ViewBuilder private var tiltRefractionDiagnostics: some View {
        if tiltRefractionQAEnabled {
            VStack(spacing: 2) {
                Text(tiltVisualDescription)
                    .font(.system(size: 1))
                    .accessibilityIdentifier(tiltVisualStage == "positiveReady"
                        ? "tiltRefractionPositiveReady" : tiltVisualStage == "negativeReady"
                        ? "tiltRefractionNegativeReady" : "tiltRefractionSampleStatus")
                Text(tiltVisualStage == "awaitingPositive" ? "Tilt right" : tiltVisualStage == "awaitingNegative" ? "Tilt left" : "Pose captured")
                    .font(.system(size: 11)).foregroundStyle(MetroStationTheme.cyan)
                    .frame(width: 84, height: 24)
                Button { tiltVisualStage = "awaitingNegative" } label: {
                    Text("Other tilt").frame(width: 72, height: 44)
                }
                .font(.system(size: 9)).buttonStyle(.bordered)
                .accessibilityIdentifier("tiltRefractionShowNegative")
            }
            .frame(width: 84).background(MetroStationTheme.panel)
        }
    }

    private var tiltVisualDescription: String {
        guard let sample = tiltVisualSnapshot else { return tiltVisualStage }
        let source = ProcessInfo.processInfo.arguments.contains("--tilt-refraction-live-qa") ? "actualGravity" : "synthetic"
        let scale = GlassDialMotion.radiusScale(beatPhase: sample.beatPhase, bpm: controller.settings.bpm)
        return "\(tiltVisualStage); source=\(source); x=\(tiltVisualVector.x); y=\(tiltVisualVector.y); phase=\(sample.beatPhase); radiusScale=\(scale); bpm=\(controller.settings.bpm); heldSnapshot=\(sample.absoluteBeatPosition); referenceDiameter=322; referenceMaxShift=\(LensRefraction.maximumShift(diameter: 322)); \(tiltVisualEvidence)"
    }

    private func captureTiltRefractionSample() async {
        guard tiltRefractionQAEnabled,
              tiltVisualStage == "awaitingPositive" || tiltVisualStage == "awaitingNegative" else { return }
        let positive = tiltVisualStage == "awaitingPositive"
        let live = ProcessInfo.processInfo.arguments.contains("--tilt-refraction-live-qa")
        while !Task.isCancelled {
            if controller.isRunning {
                let vector = live ? SIMD2(motion.x, motion.y) : SIMD2(positive ? 0.70 : -0.70, positive ? 0.35 : -0.35)
                let ready = !live || (motion.isActive && motion.sampleCount > 5
                    && (positive ? vector.x >= 0.35 : vector.x <= -0.35))
                let candidate = tiltVisualSnapshot ?? controller.snapshot(at: Date())
                if ready && (tiltVisualSnapshot != nil || abs(candidate.beatPhase - GlassDialMotion.peakPhase) <= Self.glassCaptureTolerance) {
                    // One actual running snapshot holds ticker/phase constant.
                    // Only the sampled refraction vector changes between poses.
                    tiltVisualSnapshot = candidate
                    tiltVisualVector = vector
                    tiltVisualEvidence = live
                        ? "sampleCount=\(motion.sampleCount); sensorTimestamp=\(motion.lastSampleTimestamp); gravityX=\(motion.lastGravity.x); gravityY=\(motion.lastGravity.y); gravityZ=\(motion.lastGravity.z)"
                        : "sampleCount=0; sensorTimestamp=0"
                    tiltVisualStage = positive ? "positiveReady" : "negativeReady"
                    break
                }
            }
            do { try await Task.sleep(for: .milliseconds(8)) } catch { break }
        }
    }

    private var glassVisualSampleDescription: String {
        guard let sample = glassVisualSample else { return glassVisualSampleStage }
        let scale = GlassDialMotion.radiusScale(beatPhase: sample.beatPhase, bpm: controller.settings.bpm)
        let target = glassVisualSampleStage == "expandedReady"
            ? GlassDialMotion.peakPhase : GlassDialMotion.compressionPhase
        let opacity = glassReduceTransparency ? 1 : GaugeView.glassOpacity
        return "\(glassVisualSampleStage); phase=\(sample.beatPhase); bpm=\(controller.settings.bpm); radiusScale=\(scale); baseDiameterRatio=0.76; targetPhase=\(target); captureTolerance=\(Self.glassCaptureTolerance); glassOpacity=\(opacity); reduceTransparency=\(glassReduceTransparency); tickerPivotFraction=\(GaugeView.tickerPivotFraction); tickerLengthFraction=\(GaugeView.tickerLengthFraction)"
    }
    #endif

    private func telemetry(snapshot: BeatSnapshot) -> some View {
        HStack(spacing: 0) {
            metric(label: "BEAT RATE", value: controller.effectiveSettings.beatFrequency.formatted(.number.precision(.fractionLength(2))), unit: "Hz", color: MetroStationTheme.cyan)
            divider
            metric(label: "INTERVAL", value: (controller.effectiveSettings.beatDuration * 1000).formatted(.number.precision(.fractionLength(0))), unit: "ms", color: .white)
            divider
            metric(label: "TICK PITCH", value: controller.effectiveSettings.pitch.formatted(.number.precision(.fractionLength(0))), unit: "Hz", color: MetroStationTheme.amber)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("instrumentTelemetry")
    }

    private func metric(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(label).font(.system(.caption2, design: .monospaced))
                .tracking(1.2).foregroundStyle(MetroStationTheme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(.title3, design: .monospaced)).minimumScaleFactor(0.6)
                Text(unit).font(.system(.caption2, design: .monospaced))
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.10)).frame(width: 1, height: 30)
    }

    private func beatStrip(snapshot: BeatSnapshot) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("BEAT GRID").tracking(1.7)
                Spacer()
                Text(controller.isRunning ? "\(snapshot.beatInBar + 1) / \(controller.effectiveSettings.beatsPerBar)" : "\(controller.effectiveSettings.beatsPerBar) BEATS / BAR")
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .foregroundStyle(MetroStationTheme.secondary)
            HStack(spacing: 7) {
                ForEach(0..<controller.effectiveSettings.beatsPerBar, id: \.self) { beat in
                    let active = controller.isRunning && snapshot.beatInBar == beat
                    VStack(spacing: 3) {
                        Text("\(beat + 1)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        HStack(spacing: 3) {
                            ForEach(0..<controller.effectiveSettings.subdivision, id: \.self) { pulse in
                                Capsule().fill(active && snapshot.pulseInBeat == pulse ? (beat == 0 ? MetroStationTheme.amber : MetroStationTheme.cyan) : .white.opacity(0.16))
                                    .frame(height: 2)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .foregroundStyle(active ? (beat == 0 ? MetroStationTheme.amber : MetroStationTheme.cyan) : MetroStationTheme.secondary)
                    .frame(maxWidth: .infinity).frame(height: 37)
                    .background(active ? MetroStationTheme.cyan.opacity(0.08) : .white.opacity(0.025), in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? MetroStationTheme.cyan.opacity(0.35) : .white.opacity(0.06)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Beat grid")
            .accessibilityValue(controller.isRunning ? "Beat \(snapshot.beatInBar + 1) of \(controller.effectiveSettings.beatsPerBar), subdivision \(snapshot.pulseInBeat + 1)" : "Stopped. \(controller.effectiveSettings.beatsPerBar) beats per bar")
        }
    }

    private func scope(snapshot: BeatSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("SIGNAL LAB").font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.8).foregroundStyle(MetroStationTheme.secondary)
                Spacer(minLength: 16)
                Picker("Signal display", selection: $scopeMode) {
                    Text("Wave").tag(ScopeMode.waveform)
                    Text("Spectrum").tag(ScopeMode.spectrum)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
                .accessibilityIdentifier("scopePicker")
            }
            SignalScopeView(settings: controller.effectiveSettings, snapshot: snapshot,
                            isRunning: controller.isRunning, mode: scopeMode)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 140)
        }
        .instrumentPanel()
    }

    private var rhythmControls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    Picker("Beats per bar", selection: setting(\.beatsPerBar)) {
                        ForEach(1...12, id: \.self) { Text("\($0) beats per bar").tag($0) }
                    }
                } label: {
                    Label("\(controller.settings.beatsPerBar)/4", systemImage: "square.grid.2x2")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass).accessibilityLabel("Meter, \(controller.settings.beatsPerBar) quarter note beats per bar")
                Menu {
                    Picker("Subdivision", selection: setting(\.subdivision)) {
                        Text("Quarter notes · 1").tag(1)
                        Text("Eighth notes · 2").tag(2)
                        Text("Triplets · 3").tag(3)
                        Text("Sixteenth notes · 4").tag(4)
                    }
                } label: {
                    Label("1:\(controller.settings.subdivision)", systemImage: "waveform.path")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass).accessibilityLabel("Subdivision, \(controller.settings.subdivision) pulses per beat")
                channelButton("speaker.wave.2", label: "Sound", enabled: controller.settings.soundEnabled) {
                    controller.settings.soundEnabled.toggle()
                }
                channelButton("waveform", label: "Haptics", enabled: controller.settings.hapticsEnabled) {
                    controller.settings.hapticsEnabled.toggle()
                }
            }
        }
    }

    private func channelButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: enabled ? symbol : (label == "Sound" ? "speaker.slash" : "waveform.slash"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(enabled ? MetroStationTheme.cyan : MetroStationTheme.secondary)
                .frame(width: 46, height: 44)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(label)
        .accessibilityValue(enabled ? "On" : "Off")
        .accessibilityIdentifier(label == "Sound" ? "soundButton" : "hapticsButton")
    }

    private var transport: some View {
        VStack(spacing: 8) {
            if let message = controller.errorMessage {
                Text(message).font(.caption).foregroundStyle(MetroStationTheme.amber)
                    .accessibilityIdentifier("engineError")
            }
            GlassEffectContainer(spacing: 14) {
                HStack(spacing: 12) {
                    Button { controller.tapTempo() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "hand.tap").font(.system(size: 18))
                            Text("TAP").font(.system(.caption2, design: .monospaced)).tracking(1)
                        }
                        .frame(width: 62, height: 58)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Tap tempo")
                    .accessibilityHint("Tap repeatedly to set the beat rate")
                    .accessibilityIdentifier("tapTempoButton")
                    Button { controller.toggle() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                            Text(controller.isRunning ? "Stop clock" : "Start clock")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(controller.isRunning ? MetroStationTheme.amber : MetroStationTheme.cyan)
                    .accessibilityIdentifier("transportButton")
                    Button { showsControls = true } label: {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 20))
                            .frame(width: 54, height: 58)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Instrument controls")
                    .accessibilityIdentifier("controlsButton")
                }
            }
        }
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<MetronomeSettings, Value>) -> Binding<Value> {
        Binding(get: { controller.settings[keyPath: keyPath] },
                set: { controller.settings[keyPath: keyPath] = $0 })
    }

    private func updateMotion() {
        #if DEBUG
        let enabled = motionEnabled || tiltRefractionQAEnabled
        #else
        let enabled = motionEnabled
        #endif
        if enabled && !reduceMotion && scenePhase == .active { motion.start() }
        else { motion.stop() }
    }
}

#Preview { InstrumentView().preferredColorScheme(.dark) }

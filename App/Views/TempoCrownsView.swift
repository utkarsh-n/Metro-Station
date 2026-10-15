import SwiftUI
import MetronomeCore

/// Fine and musical-band controls are kept outside the beat animation timeline.
struct TempoCrownsView: View {
    let settings: MetronomeSettings
    let motion: MotionLighting
    let onFineStep: (Int) -> Void
    let onMarkingStep: (Int) -> Void
    let onInteractionBegan: () -> Void
    let onInteractionEnded: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeInteractions = 0

    init(settings: MetronomeSettings, motion: MotionLighting,
         onFineStep: @escaping (Int) -> Void, onMarkingStep: @escaping (Int) -> Void,
         onInteractionBegan: @escaping () -> Void, onInteractionEnded: @escaping () -> Void) {
        self.settings = settings
        self.motion = motion
        self.onFineStep = onFineStep
        self.onMarkingStep = onMarkingStep
        self.onInteractionBegan = onInteractionBegan
        self.onInteractionEnded = onInteractionEnded
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 18) { fineCrown; markingCrown }
            } else {
                HStack(alignment: .top, spacing: 12) { fineCrown; markingCrown }
            }
        }
        .scrollGestureBoundary(identifier: "tempoCrowns")
    }

    private var fineCrown: some View {
        TempoCrownControl(kind: .fine, settings: settings, motion: motion,
                          onStep: onFineStep, onBegan: beginInteraction, onEnded: endInteraction)
    }

    private var markingCrown: some View {
        TempoCrownControl(kind: .marking, settings: settings, motion: motion,
                          onStep: onMarkingStep, onBegan: beginInteraction, onEnded: endInteraction)
    }

    private func beginInteraction() {
        if activeInteractions == 0 { onInteractionBegan() }
        activeInteractions += 1
    }

    private func endInteraction() {
        guard activeInteractions > 0 else { return }
        activeInteractions -= 1
        if activeInteractions == 0 { onInteractionEnded() }
    }
}

private enum TempoCrownKind {
    case fine, marking

    var accent: Color {
        self == .fine ? Color(red: 0.32, green: 0.91, blue: 0.96) : Color(red: 1, green: 0.72, blue: 0.31)
    }
    var detentDegrees: Double { self == .fine ? 8 : 20 }
    var accessibilityName: String { self == .fine ? "Fine tempo crown" : "Italian tempo crown" }
}

private struct TempoCrownControl: View {
    let kind: TempoCrownKind
    let settings: MetronomeSettings
    let motion: MotionLighting
    let onStep: (Int) -> Void
    let onBegan: () -> Void
    let onEnded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption2) private var captionRowHeight = 14.0
    @State private var tracker = CrownDetentTracker(detentDegrees: 8)
    @State private var isDragging = false
    @State private var previousVisualAngle: Double?
    @State private var rotation = 0.0
    @State private var lastEmissionTime = -Double.infinity
    @State private var pendingStep = 0

    private var bpm: Double { TempoAdjustment.wholeBPM(settings.bpm) }
    private var marking: TempoMarking { TempoMarking.forBPM(bpm) }

    var body: some View {
        VStack(spacing: 5) {
            Text(kind == .fine ? "FINE" : "TEMPO · \(marking.name)")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(kind.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(height: captionRowHeight)

            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 0) {
                    stepButton(-1)
                    crown
                    stepButton(1)
                }
                .frame(maxWidth: .infinity)
            }

            Group { if kind == .fine {
                Text("±1 BPM")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 3) {
                        Text(neighborName(-1)).lineLimit(1)
                        Image(systemName: "arrow.left.arrow.right")
                        Text(neighborName(1)).lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    Text("NEXT MARKING").lineLimit(1)
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .accessibilityHidden(true)
            } }
            .frame(height: captionRowHeight)
        }
        .frame(maxWidth: .infinity)
        .onDisappear { finishGesture() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishGesture() }
        }
    }

    private var crown: some View {
        CrownMetalFace(accent: kind.accent, rotation: reduceMotion ? 0 : rotation,
                       lightX: reduceMotion ? 0 : motion.x, lightY: reduceMotion ? 0 : motion.y,
                       isPressed: isDragging, isFine: kind == .fine)
            .frame(width: 62, height: 62)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - 31
                        let dy = value.location.y - 31
                        guard hypot(dx, dy) >= 7 else {
                            // Crossing the bearing discards only angular history;
                            // emerging on the other side cannot create a large step.
                            tracker.reset()
                            previousVisualAngle = nil
                            pendingStep = 0
                            return
                        }
                        let angle = atan2(dy, dx) * 180 / .pi
                        if !isDragging {
                            isDragging = true
                            tracker = CrownDetentTracker(detentDegrees: kind.detentDegrees)
                            tracker.begin(angleDegrees: angle)
                            previousVisualAngle = angle
                            lastEmissionTime = -Double.infinity
                            pendingStep = 0
                            onBegan()
                            return
                        }
                        if let previousVisualAngle {
                            var delta = angle - previousVisualAngle
                            if delta > 180 { delta -= 360 }
                            if delta < -180 { delta += 360 }
                            // A queued notch cannot fire against a new direction.
                            // Sub-half-degree tremor leaves the pending detent calm.
                            if pendingStep != 0, delta * Double(pendingStep) < -0.5 {
                                pendingStep = 0
                            }
                            rotation += delta
                        }
                        previousVisualAngle = angle
                        let detent = tracker.update(angleDegrees: angle)
                        if detent != 0 { pendingStep = detent }
                        let now = ProcessInfo.processInfo.systemUptime
                        guard pendingStep != 0, now - lastEmissionTime >= 0.05 else { return }
                        let direction = pendingStep
                        pendingStep = 0
                        guard canStep(direction) else { return }
                        lastEmissionTime = now
                        onStep(direction)
                    }
                    .onEnded { _ in finishGesture() }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(kind.accessibilityName)
            .accessibilityValue(kind == .fine ? "\(Int(bpm)) beats per minute" : "\(marking.name), \(Int(bpm)) beats per minute")
            .accessibilityHint(kind == .fine ? "Clockwise adds one BPM per notch; counterclockwise subtracts one." : "Clockwise advances to the next Italian tempo marking; counterclockwise selects the previous one.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: tapStep(1)
                case .decrement: tapStep(-1)
                @unknown default: break
                }
            }
            .accessibilityIdentifier(kind == .fine ? "fineTempoCrown" : "markingTempoCrown")
    }

    private func stepButton(_ direction: Int) -> some View {
        Button { tapStep(direction) } label: {
            Image(systemName: direction > 0 ? "plus" : "minus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(kind.accent)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(kind.accent.opacity(0.08)).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!canStep(direction))
        .accessibilityLabel(kind == .fine ? (direction > 0 ? "Increase tempo by one BPM" : "Decrease tempo by one BPM") : "Select \(neighborName(direction)) tempo")
        .accessibilityIdentifier(kind == .fine ? (direction > 0 ? "fineTempoPlus" : "fineTempoMinus") : (direction > 0 ? "markingTempoPlus" : "markingTempoMinus"))
    }

    private func tapStep(_ direction: Int) {
        guard canStep(direction) else { return }
        onBegan()
        onStep(direction)
        onEnded()
    }

    private func canStep(_ direction: Int) -> Bool {
        if kind == .fine { return direction > 0 ? bpm < 240 : bpm > 30 }
        return TempoAdjustment.nextMarkingBPM(from: bpm, direction: direction) != bpm
    }

    private func neighborName(_ direction: Int) -> String {
        let neighbor = TempoAdjustment.nextMarkingBPM(from: bpm, direction: direction)
        return neighbor == bpm ? "—" : TempoMarking.forBPM(neighbor).name
    }

    private func finishGesture() {
        guard isDragging else { return }
        isDragging = false
        tracker.reset()
        previousVisualAngle = nil
        pendingStep = 0
        onEnded()
    }
}

private struct CrownMetalFace: View {
    let accent: Color
    let rotation: Double
    let lightX: Double
    let lightY: Double
    let isPressed: Bool
    let isFine: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.12, green: 0.15, blue: 0.17))
                .shadow(color: .black.opacity(0.75), radius: isPressed ? 3 : 6, y: isPressed ? 2 : 5)
            Canvas { context, size in
                let diameter = min(size.width, size.height)
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let rim = CGRect(x: 1.5, y: 1.5, width: diameter - 3, height: diameter - 3)
                context.fill(Path(ellipseIn: rim), with: .linearGradient(Gradient(colors: [Color(red: 0.49, green: 0.57, blue: 0.61), Color(red: 0.10, green: 0.13, blue: 0.15), Color(red: 0.32, green: 0.39, blue: 0.43)]),
                                                                        startPoint: CGPoint(x: 9 + lightX * 8, y: lightY * 6), endPoint: CGPoint(x: diameter - 8, y: diameter)))
                for index in 0..<40 {
                    let radians = (Double(index) * 9 + rotation) * .pi / 180
                    var groove = Path()
                    groove.move(to: CGPoint(x: center.x + cos(radians) * (diameter * 0.40), y: center.y + sin(radians) * (diameter * 0.40)))
                    groove.addLine(to: CGPoint(x: center.x + cos(radians) * (diameter * 0.475), y: center.y + sin(radians) * (diameter * 0.475)))
                    context.stroke(groove, with: .color(.black.opacity(0.65)), lineWidth: 1.5)
                    context.stroke(groove, with: .color(.white.opacity(0.20)), lineWidth: 0.45)
                }
                let face = CGRect(x: 8, y: 8, width: diameter - 16, height: diameter - 16)
                context.fill(Path(ellipseIn: face), with: .linearGradient(Gradient(colors: [Color(red: 0.27, green: 0.33, blue: 0.37), Color(red: 0.08, green: 0.11, blue: 0.13)]),
                                                                         startPoint: CGPoint(x: center.x - 12 + lightX * 9, y: 3 + lightY * 8), endPoint: CGPoint(x: diameter - 7, y: diameter)))
                context.stroke(Path(ellipseIn: face), with: .color(.white.opacity(0.31)), lineWidth: 0.7)
                for inset in stride(from: 11.0, through: 16.0, by: 1.5) {
                    context.stroke(Path(ellipseIn: CGRect(x: inset, y: inset, width: diameter - inset * 2, height: diameter - inset * 2)), with: .color(.white.opacity(0.045)), lineWidth: 0.4)
                }
                let pointerAngle = (-90 + rotation) * .pi / 180
                var pointer = Path()
                pointer.move(to: CGPoint(x: center.x + cos(pointerAngle) * 16, y: center.y + sin(pointerAngle) * 16))
                pointer.addLine(to: CGPoint(x: center.x + cos(pointerAngle) * 21, y: center.y + sin(pointerAngle) * 21))
                context.stroke(pointer, with: .color(accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                var datum = Path()
                datum.move(to: CGPoint(x: center.x - 2.5, y: 0.5))
                datum.addLine(to: CGPoint(x: center.x + 2.5, y: 0.5))
                datum.addLine(to: CGPoint(x: center.x, y: 4))
                datum.closeSubpath()
                context.fill(datum, with: .color(accent))
            }
            if isFine {
                Text("1").font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Image(systemName: "metronome").font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

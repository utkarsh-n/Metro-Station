import SwiftUI
import MetronomeCore

/// A metal instrument face with a passive, clock-driven Liquid Glass lens.
struct GaugeView: View {
    static let glassOpacity = 0.48
    static let tickerPivotFraction = 0.38
    static let tickerLengthFraction = 0.235

    let settings: MetronomeSettings
    let snapshot: BeatSnapshot
    let isRunning: Bool
    let motion: MotionLighting
    let glassBeatPhase: Double?
    let glassTiltOverride: SIMD2<Double>?
    let metalLightingOverride: SIMD2<Double>?
    let onScrubBegan: () -> Void
    let onScrubEnded: () -> Void
    let onTempoChange: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption2) private var metadataSize = 11.0
    @State private var isDragging = false
    @State private var previousTouchAngle: Double?
    @State private var scrubTempo: Double?
    @State private var lastEmittedBPM = 120
    @State private var scrubDirection = 0

    private let cyan = Color(red: 0.32, green: 0.91, blue: 0.96)
    private let amber = Color(red: 1, green: 0.72, blue: 0.31)
    private var lightX: Double { reduceMotion ? 0 : (metalLightingOverride?.x ?? motion.x) }
    private var lightY: Double { reduceMotion ? 0 : (metalLightingOverride?.y ?? motion.y) }
    private var glassScale: Double {
        GlassDialMotion.radiusScale(beatPhase: glassBeatPhase ?? snapshot.beatPhase,
                                   bpm: settings.bpm, isRunning: isRunning,
                                   reduceMotion: reduceMotion || scenePhase != .active)
    }
    private var refractionEnabled: Bool {
        !reduceMotion && !reduceTransparency && scenePhase == .active
            && (glassTiltOverride != nil || motion.isActive)
    }
    private var tempoLabel: String {
        TempoAdjustment.wholeBPM(settings.bpm).formatted(.number.precision(.fractionLength(0)))
    }

    init(settings: MetronomeSettings, snapshot: BeatSnapshot, isRunning: Bool,
         motion: MotionLighting, glassBeatPhase: Double? = nil,
         glassTiltOverride: SIMD2<Double>? = nil, metalLightingOverride: SIMD2<Double>? = nil,
         onScrubBegan: @escaping () -> Void = {},
         onScrubEnded: @escaping () -> Void = {}, onTempoChange: @escaping (Double) -> Void) {
        self.settings = settings
        self.snapshot = snapshot
        self.isRunning = isRunning
        self.motion = motion
        self.glassBeatPhase = glassBeatPhase
        self.glassTiltOverride = glassTiltOverride
        self.metalLightingOverride = metalLightingOverride
        self.onScrubBegan = onScrubBegan
        self.onScrubEnded = onScrubEnded
        self.onTempoChange = onTempoChange
    }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            ZStack {
                Circle()
                    .fill(Color(red: 0.027, green: 0.041, blue: 0.055))
                    .shadow(color: .black.opacity(0.8), radius: 22, y: 16)
                    .overlay {
                        Circle().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.36), .white.opacity(0.025), .black, .white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.4
                        )
                    }

                Circle()
                    .inset(by: diameter * 0.038)
                    .fill(LinearGradient(colors: [Color(red: 0.055, green: 0.073, blue: 0.090), Color(red: 0.021, green: 0.032, blue: 0.042)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Circle().inset(by: diameter * 0.038)
                            .strokeBorder(.white.opacity(0.07), lineWidth: 0.6)
                    }

                if !reduceTransparency {
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.085), .cyan.opacity(0.018), .clear], center: UnitPoint(x: 0.28 + lightX * 0.25, y: 0.10 + lightY * 0.25), startRadius: 0, endRadius: diameter * 0.85))
                    Circle()
                        .inset(by: diameter * 0.05)
                        .stroke(LinearGradient(colors: [.clear, cyan.opacity(0.13), .clear], startPoint: UnitPoint(x: 0.1 + lightX * 0.12, y: 0.25 + lightY * 0.14), endPoint: .bottomTrailing), lineWidth: 5)
                        .blur(radius: 6)
                }

                Canvas { context, size in
                    drawDial(context: &context, diameter: min(size.width, size.height))
                }
                // Warp and separate color channels only in the underlying ink.
                // Native glass, text and controls never enter this filter.
                .layerEffect(refractionShader(diameter: diameter),
                             maxSampleOffset: CGSize(width: maximumSampleOffset(diameter: diameter),
                                                     height: maximumSampleOffset(diameter: diameter)),
                             isEnabled: refractionEnabled)
                .allowsHitTesting(false)

                // Native clear glass refracts the metal face and ticker beneath
                // it. Its constant composite opacity leaves the metal visible;
                // only the radius moves, with the readout and touch surface fixed.
                glassDial(diameter: diameter)

                if refractionEnabled {
                    glassHighlight(diameter: diameter)
                }

                Group {
                    Text(tempoLabel)
                        .font(.system(size: diameter * 0.23, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.91, green: 0.95, blue: 0.97))
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: diameter * 0.64)
                        .position(x: center.x, y: diameter * 0.52)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("BEATS / MIN")
                            .font(.system(size: metadataSize, weight: .medium, design: .monospaced))
                            .tracking(2.2)
                            .foregroundStyle(.white.opacity(0.68))
                            .position(x: center.x, y: diameter * 0.665)
                    }
                    Text(TempoMarking.forBPM(settings.bpm).name)
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .italic()
                        .foregroundStyle(cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(width: diameter * 0.64)
                        .position(x: center.x, y: diameter * (dynamicTypeSize.isAccessibilitySize ? 0.79 : 0.745))
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: 5) {
                            Circle().fill(isRunning ? amber : .white.opacity(0.28)).frame(width: 3, height: 3)
                            Text("φ  \(Int(snapshot.beatPhase * 360))°")
                                .font(.system(size: metadataSize, weight: .regular, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        .position(x: center.x, y: diameter * 0.835)
                    }
                }
                .allowsHitTesting(false)

                if !dynamicTypeSize.isAccessibilitySize && isDragging { VStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: scrubDirection >= 0 ? "arrow.clockwise" : "arrow.counterclockwise")
                            .font(.system(size: metadataSize - 1, weight: .medium))
                        Text(scrubDirection == 0 ? "SCRUB TEMPO" : scrubDirection > 0 ? "FASTER" : "SLOWER")
                            .font(.system(size: metadataSize, weight: .medium, design: .monospaced))
                            .tracking(1.15)
                    }
                    .foregroundStyle(.white.opacity(isDragging ? 0.95 : 0.68))
                    .padding(.bottom, diameter * 0.054)
                } }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // The large central readout stays calm; the complete rim
                        // is a direct manipulation target wider than 44 points.
                        let dx = value.startLocation.x - center.x
                        let dy = value.startLocation.y - center.y
                        guard hypot(dx, dy) >= diameter * 0.30 else { return }
                        if !isDragging {
                            isDragging = true
                            scrubTempo = TempoAdjustment.wholeBPM(settings.bpm)
                            lastEmittedBPM = Int(TempoAdjustment.wholeBPM(settings.bpm))
                            previousTouchAngle = atan2(dy, dx)
                            scrubDirection = 0
                            onScrubBegan()
                        }
                        let currentDX = value.location.x - center.x
                        let currentDY = value.location.y - center.y
                        guard hypot(currentDX, currentDY) >= diameter * 0.20 else {
                            previousTouchAngle = nil
                            return
                        }
                        let angle = atan2(currentDY, currentDX)
                        defer { previousTouchAngle = angle }
                        guard let previousTouchAngle, let scrubTempo else { return }
                        var delta = angle - previousTouchAngle
                        // Crossing the angle's ±π seam continues the same notch
                        // direction instead of jumping to an absolute tempo.
                        if delta > .pi { delta -= 2 * .pi }
                        if delta < -.pi { delta += 2 * .pi }
                        guard abs(delta) > 0.00001 else { return }
                        let next = min(240, max(30, scrubTempo + delta * 180 / .pi * 210 / 300))
                        self.scrubTempo = next
                        // Schmitt-style quantization: a notch changes after 0.65
                        // BPM of travel; reversing requires a real 0.30 BPM band.
                        // Finger tremor around a half step cannot flip the output.
                        let target: Int
                        if next >= Double(lastEmittedBPM) + 0.65 {
                            target = Int(floor(next + 0.35))
                        } else if next <= Double(lastEmittedBPM) - 0.65 {
                            target = Int(ceil(next - 0.35))
                        } else {
                            return
                        }
                        let bounded = min(240, max(30, target))
                        guard bounded != lastEmittedBPM else { return }
                        scrubDirection = bounded > lastEmittedBPM ? 1 : -1
                        lastEmittedBPM = bounded
                        onTempoChange(Double(bounded))
                    }
                    .onEnded { _ in endScrub() }
            )
            .onDisappear { endScrub() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { endScrub() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("mainTempoGauge")
            .accessibilityLabel("Tempo dial")
            .accessibilityValue("\(tempoLabel) beats per minute, \(TempoMarking.forBPM(settings.bpm).name)")
            .accessibilityHint("Adjust to change the tempo. Clockwise is faster; counterclockwise is slower. The dial ranges from 30 to 240 beats per minute.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onTempoChange(min(240, TempoAdjustment.wholeBPM(settings.bpm) + 1))
                case .decrement: onTempoChange(max(30, TempoAdjustment.wholeBPM(settings.bpm) - 1))
                @unknown default: break
                }
            }
            .accessibilityAction(named: "Increase tempo by ten") { onTempoChange(min(240, TempoAdjustment.wholeBPM(settings.bpm) + 10)) }
            .accessibilityAction(named: "Decrease tempo by ten") { onTempoChange(max(30, TempoAdjustment.wholeBPM(settings.bpm) - 10)) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .scrollGestureBoundary(identifier: "tempoDial")
    }

    private func glassDial(diameter: CGFloat) -> some View {
        return Color.clear
            .frame(width: diameter * 0.76, height: diameter * 0.76)
            .glassEffect(.clear, in: .circle)
            .scaleEffect(glassScale, anchor: .center)
            .opacity(reduceTransparency ? 1 : Self.glassOpacity)
            .transaction { $0.animation = nil }
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func refractionShader(diameter: CGFloat) -> Shader {
        let input = glassTiltOverride ?? SIMD2(motion.x, motion.y)
        let tilt = LensRefraction.enhancedTilt(x: input.x, y: input.y, enabled: refractionEnabled)
        return ShaderLibrary.metroStationLensOptics(
            .float2(Float(diameter / 2), Float(diameter / 2)),
            .float(Float(diameter * 0.38 * glassScale)),
            .float2(Float(tilt.x), Float(tilt.y)),
            .float(Float(LensRefraction.maximumShift(diameter: diameter))),
            .float(Float(LensRefraction.rimStart)),
            .float(Float(LensRefraction.curvature)),
            .float(Float(LensRefraction.maximumChannelSplit(diameter: diameter))),
            .float(Float(LensRefraction.chromaticInnerStart)),
            .float(Float(LensRefraction.chromaticPeakRadius))
        )
    }

    private func maximumSampleOffset(diameter: CGFloat) -> CGFloat {
        LensRefraction.maximumShift(diameter: diameter)
            + LensRefraction.maximumChannelSplit(diameter: diameter) * 0.5
    }

    private func glassHighlight(diameter: CGFloat) -> some View {
        let input = glassTiltOverride ?? SIMD2(motion.x, motion.y)
        let tilt = LensRefraction.enhancedTilt(x: input.x, y: input.y, enabled: refractionEnabled)
        let radius = diameter * 0.38 * glassScale
        return Canvas { context, _ in
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let rim = radius * 0.985
            let angle = -90 + tilt.x * 70 + tilt.y * 20
            let start = angle - 38
            let end = angle + 38
            let arc = Path { path in
                path.addArc(center: center, radius: rim, startAngle: .degrees(start),
                            endAngle: .degrees(end), clockwise: false)
            }
            let startPoint = CGPoint(x: center.x + rim * cos(start * .pi / 180),
                                     y: center.y + rim * sin(start * .pi / 180))
            let endPoint = CGPoint(x: center.x + rim * cos(end * .pi / 180),
                                   y: center.y + rim * sin(end * .pi / 180))
            // A faint reflection follows only the perimeter. No face fill,
            // bloom, moving patch or beat-driven brightness enters the glass.
            context.stroke(arc, with: .linearGradient(Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.085), location: 0.5),
                .init(color: .clear, location: 1)
            ]), startPoint: startPoint, endPoint: endPoint),
            style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        .frame(width: diameter, height: diameter)
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawDial(context: inout GraphicsContext, diameter: CGFloat) {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let radius = diameter * 0.445
        let tempoAngle = 120 + min(1, max(0, (settings.bpm - 30) / 210)) * 300
        let sweep = Path { path in
            path.addArc(center: center, radius: radius, startAngle: .degrees(120), endAngle: .degrees(420), clockwise: false)
        }
        context.stroke(sweep, with: .color(.white.opacity(0.075)), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        // A thin rainbow scale is separate from the bright amber tempo index.
        for index in 0..<120 {
            let angle = 120 + Double(index) * 2.5
            let segment = Path { path in
                path.addArc(center: center, radius: radius, startAngle: .degrees(angle), endAngle: .degrees(angle + 2.1), clockwise: false)
            }
            let hue = 0.49 + Double(index) / 120 * 0.37
            let lit = angle <= tempoAngle
            context.stroke(segment, with: .color(Color(hue: hue, saturation: 0.70, brightness: lit ? 0.92 : 0.33).opacity(lit ? 0.85 : 0.40)), style: StrokeStyle(lineWidth: lit ? 2.5 : 1.2, lineCap: .butt))
        }

        for tick in 0...70 {
            let angle = 120 + Double(tick) / 70 * 300
            let major = tick.isMultiple(of: 10)
            let middle = tick.isMultiple(of: 5)
            let outer = radius - 10
            let inner = outer - (major ? 12 : middle ? 8 : 4)
            var path = Path()
            path.move(to: point(angle: angle, radius: inner, center: center))
            path.addLine(to: point(angle: angle, radius: outer, center: center))
            context.stroke(path, with: .color(.white.opacity(major ? 0.64 : middle ? 0.38 : 0.19)), lineWidth: major ? 1.3 : 0.8)
            if major && !dynamicTypeSize.isAccessibilitySize {
                let label = Text("\(30 + tick * 3)")
                    .font(.system(size: diameter * 0.027, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                context.draw(label, at: point(angle: angle, radius: inner - 9, center: center))
            }
        }

        drawTicker(context: &context, diameter: diameter)

        let tip = point(angle: tempoAngle, radius: radius + 6, center: center)
        let left = point(angle: tempoAngle - 1.8, radius: radius + 12, center: center)
        let right = point(angle: tempoAngle + 1.8, radius: radius + 12, center: center)
        var triangle = Path()
        triangle.move(to: tip)
        triangle.addLine(to: left)
        triangle.addLine(to: right)
        triangle.closeSubpath()
        context.fill(triangle, with: .color(amber))
        var index = Path()
        index.move(to: point(angle: tempoAngle, radius: radius - 2, center: center))
        index.addLine(to: point(angle: tempoAngle, radius: radius - 20, center: center))
        context.stroke(index, with: .color(amber), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))

        // Different depths and slightly split chromatic highlights respond to
        // gravity independently, so tilt changes the apparent refraction.
        let reflectionAngle = -120 + lightX * 32 + lightY * 20
        for layer in 0..<3 {
            let layerRadius = diameter * (0.485 - Double(layer) * 0.008)
            let caustic = Path { path in
                path.addArc(center: CGPoint(x: center.x + lightX * Double(layer) * 1.1, y: center.y + lightY * Double(layer) * 1.1), radius: layerRadius, startAngle: .degrees(reflectionAngle - 27), endAngle: .degrees(reflectionAngle + 22), clockwise: false)
            }
            let color = layer == 0 ? Color.white : layer == 1 ? cyan : Color(red: 0.61, green: 0.54, blue: 0.97)
            context.stroke(caustic, with: .color(color.opacity(layer == 0 ? 0.30 : 0.12)), style: StrokeStyle(lineWidth: layer == 0 ? 1 : 0.6, lineCap: .round))
        }
    }

    private func endScrub() {
        guard isDragging else { return }
        isDragging = false
        previousTouchAngle = nil
        scrubTempo = nil
        scrubDirection = 0
        onScrubEnded()
    }

    private func drawTicker(context: inout GraphicsContext, diameter: CGFloat) {
        let pivot = CGPoint(x: diameter / 2, y: diameter * Self.tickerPivotFraction)
        let armLength = diameter * Self.tickerLengthFraction
        // The upright bearing is zero. Successive quarter-note ticks occur at
        // alternating endpoints; the complete arm cycle therefore takes two beats.
        let deflection = isRunning && !reduceMotion ? 26 * cos(.pi * snapshot.absoluteBeatPosition) : 0
        let angle = -90 + deflection
        let scaleRadius = armLength + diameter * 0.018
        let scale = Path { path in
            path.addArc(center: pivot, radius: scaleRadius, startAngle: .degrees(-116), endAngle: .degrees(-64), clockwise: false)
        }
        context.stroke(scale, with: .color(.white.opacity(0.22)), lineWidth: 0.8)
        for degrees in [-26.0, -13, 0, 13, 26] {
            let tickAngle = -90 + degrees
            var tick = Path()
            tick.move(to: point(angle: tickAngle, radius: scaleRadius - (degrees == 0 ? 4 : 2), center: pivot))
            tick.addLine(to: point(angle: tickAngle, radius: scaleRadius + 2, center: pivot))
            context.stroke(tick, with: .color(.white.opacity(degrees == 0 ? 0.75 : 0.38)), lineWidth: 0.8)
        }
        context.draw(Text("0°").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.72)),
                     at: point(angle: -90, radius: scaleRadius + 10, center: pivot))

        var neutralAxis = Path()
        neutralAxis.move(to: point(angle: -90, radius: armLength - 4, center: pivot))
        neutralAxis.addLine(to: CGPoint(x: pivot.x, y: pivot.y - 8))
        context.stroke(neutralAxis, with: .color(.white.opacity(0.13)), style: StrokeStyle(lineWidth: 0.6, dash: [1, 3]))

        let tip = point(angle: angle, radius: armLength, center: pivot)
        let perpendicular = angle + 90
        let baseLeft = point(angle: perpendicular, radius: 2, center: pivot)
        let baseRight = point(angle: perpendicular + 180, radius: 2, center: pivot)
        let tipLeft = point(angle: perpendicular, radius: 0.8, center: tip)
        let tipRight = point(angle: perpendicular + 180, radius: 0.8, center: tip)
        var stem = Path()
        stem.move(to: baseLeft)
        stem.addLine(to: tipLeft)
        stem.addLine(to: tipRight)
        stem.addLine(to: baseRight)
        stem.closeSubpath()
        context.fill(stem, with: .linearGradient(Gradient(colors: [.white.opacity(0.95), Color(red: 0.48, green: 0.58, blue: 0.63), .white.opacity(0.70)]),
                                                startPoint: CGPoint(x: pivot.x - 4, y: pivot.y), endPoint: CGPoint(x: pivot.x + 4, y: pivot.y)))
        var highlight = Path()
        highlight.move(to: baseLeft)
        highlight.addLine(to: tipLeft)
        context.stroke(highlight, with: .color(.white.opacity(0.85)), lineWidth: 0.65)

        let weightCenter = point(angle: angle, radius: armLength * 0.58, center: pivot)
        let weightTop = point(angle: angle, radius: 4.5, center: weightCenter)
        let weightBottom = point(angle: angle + 180, radius: 4.5, center: weightCenter)
        var weight = Path()
        weight.move(to: point(angle: perpendicular, radius: 3.4, center: weightTop))
        weight.addLine(to: point(angle: perpendicular + 180, radius: 3.4, center: weightTop))
        weight.addLine(to: point(angle: perpendicular + 180, radius: 3.4, center: weightBottom))
        weight.addLine(to: point(angle: perpendicular, radius: 3.4, center: weightBottom))
        weight.closeSubpath()
        context.fill(weight, with: .linearGradient(Gradient(colors: [.white.opacity(0.92), Color(red: 0.37, green: 0.46, blue: 0.51), .white.opacity(0.72)]),
                                                  startPoint: point(angle: perpendicular, radius: 3.4, center: weightCenter),
                                                  endPoint: point(angle: perpendicular + 180, radius: 3.4, center: weightCenter)))
        context.stroke(weight, with: .color(.white.opacity(0.55)), lineWidth: 0.55)
        var weightNotch = Path()
        weightNotch.move(to: point(angle: perpendicular, radius: 2.4, center: weightCenter))
        weightNotch.addLine(to: point(angle: perpendicular + 180, radius: 2.4, center: weightCenter))
        context.stroke(weightNotch, with: .color(.black.opacity(0.65)), lineWidth: 0.6)
        context.fill(Path(ellipseIn: CGRect(x: tip.x - 2.3, y: tip.y - 2.3, width: 4.6, height: 4.6)), with: .color(amber))

        let hub = CGRect(x: pivot.x - 4.5, y: pivot.y - 4.5, width: 9, height: 9)
        context.fill(Path(ellipseIn: hub), with: .linearGradient(Gradient(colors: [Color(red: 0.30, green: 0.36, blue: 0.39), .black]),
                                                              startPoint: CGPoint(x: hub.minX, y: hub.minY), endPoint: CGPoint(x: hub.maxX, y: hub.maxY)))
        context.stroke(Path(ellipseIn: hub), with: .color(.white.opacity(0.48)), lineWidth: 0.7)
        context.fill(Path(ellipseIn: CGRect(x: pivot.x - 1.5, y: pivot.y - 1.5, width: 3, height: 3)), with: .color(cyan.opacity(0.75)))
    }

    private func point(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }
}

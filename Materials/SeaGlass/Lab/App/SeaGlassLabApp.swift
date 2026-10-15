import SwiftUI
import MetroSeaGlass

@main
struct SeaGlassLabApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("--qa-large-type") {
                MaterialLabView().dynamicTypeSize(.accessibility3)
            } else {
                MaterialLabView()
            }
        }
    }
}

private struct MaterialLabView: View {
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var style = SeaGlassStyle.standard
    @State private var library = SeaGlassStyleLibrary()
    @State private var showSignal = true
    @State private var sampleActivations = 0
    @State private var backdrop: LabBackdrop = .signal
    @State private var referenceStyle = SeaGlassStyle.standard
    @State private var lightDragEnabled = false
    @State private var showingStyles = false

    private var tint: SeaGlassTint { SeaGlassTint(rawValue: style.tint.rawValue) ?? .tide }
    private var frost: Double { style.frost }
    private var depth: Double { style.depth }
    private var light: Double { style.lightAngleDegrees }
    private var opaque: Bool { style.forceOpaque }
    private var staticLight: Bool { style.staticLight }
    private var isMineral: Bool { style.appearance == .mineral }
    private var effectiveOpaque: Bool { opaque || systemReduceTransparency }
    private var effectiveStaticLight: Bool { staticLight || systemReduceMotion || effectiveOpaque }
    private var ink: Color { isMineral ? Color(red: 0.07, green: 0.17, blue: 0.18) : Color(red: 0.91, green: 0.95, blue: 0.97) }
    private var secondaryInk: Color { isMineral ? Color(red: 0.28, green: 0.39, blue: 0.40) : Color(red: 0.61, green: 0.73, blue: 0.76) }
    private var config: SeaGlassConfiguration {
        let angle = light * .pi / 180
        return SeaGlassConfiguration(frost: frost, depth: depth,
            lightDirection: SeaGlassLightDirection(x: cos(angle), y: sin(angle)), grain: style.grain,
            forceOpaque: opaque, staticLight: staticLight)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                Picker("Environment", selection: $style.appearance) {
                    ForEach(SeaGlassStyleAppearance.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("environment")

                Picker("Test background", selection: $backdrop) {
                    ForEach(LabBackdrop.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("test-background")

                specimen
                tintPicker
                controls
                MaterialComparisonView(style: style, referenceStyle: $referenceStyle, backdrop: backdrop)
                componentSamples
                accessibilityControls
                Text("Experimental surface • iOS 26+\nFrost and depth are artistic parameters. This study approximates scattered light; it does not trace rays or measure physical glass.")
                    .font(.footnote)
                    .foregroundStyle(secondaryInk)
                    .lineSpacing(4)
            }
            .padding(24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack {
                (isMineral ? Color(red: 0.89, green: 0.93, blue: 0.91) : Color(red: 0.025, green: 0.042, blue: 0.058))
                RadialGradient(colors: [.cyan.opacity(isMineral ? 0.06 : 0.09), .clear],
                               center: .topTrailing, startRadius: 8, endRadius: 600)
            }.ignoresSafeArea()
        }
        .foregroundStyle(ink)
        .tint(isMineral ? Color(red: 0.06, green: 0.42, blue: 0.43) : Color(red: 0.34, green: 0.93, blue: 0.96))
        .preferredColorScheme(isMineral ? .light : .dark)
        .task { library.load() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { showingStyles = true } label: {
                HStack {
                    Label("Styles", systemImage: "swatchpalette")
                    Spacer()
                    Text("\(library.styles.count) saved").font(.caption.monospaced())
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(SeaGlassButtonStyle(tint: tint, configuration: config))
            .accessibilityIdentifier("open-styles")
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showingStyles) {
            NavigationStack {
                ScrollView {
                    StyleWorkbenchView(style: $style, library: library)
                        .padding(24)
                }
                .navigationTitle("Styles")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingStyles = false }
                    }
                }
            }
            .preferredColorScheme(isMineral ? .light : .dark)
            .presentationDetents([.large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "water.waves")
                Text("METRO / MATERIAL 01")
                    .tracking(2)
            }
            .font(.caption.monospaced())
            .foregroundStyle(secondaryInk)
            Text("Sea glass")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text("A softer light. A worn edge.")
                .font(.subheadline)
                .foregroundStyle(secondaryInk)
        }
        .padding(.top, 10)
    }

    private var specimen: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                materialStage
                    .contentShape(RoundedRectangle(cornerRadius: 30))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let dx = value.location.x - geometry.size.width * 0.5
                                let dy = value.location.y - geometry.size.height * 0.5
                                guard hypot(dx, dy) > 24 else { return }
                                let angle = atan2(dy, dx) * 180 / .pi
                                style.lightAngleDegrees = (angle + 360).truncatingRemainder(dividingBy: 360).rounded()
                            },
                        including: lightDragEnabled && !effectiveStaticLight ? .all : .subviews
                    )
            }
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 400 : 280)
            .overlay {
                RoundedRectangle(cornerRadius: 30).strokeBorder(ink.opacity(0.08))
                    .allowsHitTesting(false)
            }
            HStack {
                Text(effectiveOpaque ? "SATIN / OPAQUE" : "SATIN / TRANSLUCENT")
                Spacer()
                Text(effectiveOpaque ? "OPAQUE SURFACE" : effectiveStaticLight ? "FIXED LIGHT" : "\(Int(light))° LIGHT")
            }
            .font(.caption2.monospaced())
            .foregroundStyle(secondaryInk)
            Toggle(isOn: $lightDragEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drag the light").font(.subheadline.weight(.medium))
                    Text("Touch the specimen to move its rim light.")
                        .font(.caption).foregroundStyle(secondaryInk)
                }
            }
            .disabled(effectiveStaticLight)
            .accessibilityIdentifier("drag-light")
        }
    }

    private var materialStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(isMineral ? Color.white.opacity(0.36) : Color.black.opacity(0.24))
            LabBackdropView(backdrop: backdrop, isMineral: isMineral, visible: showSignal)
                .clipShape(RoundedRectangle(cornerRadius: 30))
            SeaGlassSurface(tint: tint, configuration: config, cornerRadius: CGFloat(style.cornerRadius)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SG / 01").tracking(2)
                        Spacer()
                        Image(systemName: "circle.lefthalf.filled")
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(secondaryInk)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int((frost * 100).rounded()))")
                            .font(.system(size: 64, weight: .light, design: .rounded))
                            .monospacedDigit()
                        Text("%").font(.title3.monospaced())
                        Spacer()
                    }
                    Text("SURFACE FROST · \(tintName.uppercased())")
                        .font(.caption.monospaced()).tracking(1)
                }
                .padding(26)
                .foregroundStyle(ink)
            }
            .padding(26)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(tintName) sea glass specimen")
            .accessibilityValue("Surface frost \(Int((frost * 100).rounded())) percent")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tintName: String {
        switch tint {
        case .tide: "Tide"
        case .kelp: "Kelp"
        case .amber: "Amber"
        case .violet: "Violet"
        case .frost: "Frost"
        }
    }

    private var tintPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("01 / BODY COLOR")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    tintButton(.tide, "Tide")
                    tintButton(.kelp, "Kelp")
                    tintButton(.amber, "Amber")
                    tintButton(.violet, "Violet")
                    tintButton(.frost, "Frost")
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    tintRow
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { tintButton(.tide, "Tide"); tintButton(.kelp, "Kelp"); tintButton(.amber, "Amber") }
                        HStack { tintButton(.violet, "Violet"); tintButton(.frost, "Frost") }
                    }
                }
            }
        }
    }

    private var tintRow: some View {
        HStack(spacing: 7) {
            tintButton(.tide, "Tide")
            tintButton(.kelp, "Kelp")
            tintButton(.amber, "Amber")
            tintButton(.violet, "Violet")
            tintButton(.frost, "Frost")
        }
    }

    private func tintButton(_ value: SeaGlassTint, _ label: String) -> some View {
        Button { style.tint = SeaGlassStyleTint(rawValue: value.rawValue) ?? .tide } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .frame(minHeight: 44)
                .background(tint == value ? ink.opacity(0.12) : .clear, in: Capsule())
                .overlay { Capsule().strokeBorder(ink.opacity(tint == value ? 0.35 : 0.09)) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tint == value ? [.isSelected] : [])
        .accessibilityIdentifier("tint.\(label.lowercased())")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionLabel("02 / SURFACE RECIPE")
            parameter("Frost", description: "Increase the milky surface veil", value: $style.frost, range: 0...1, text: "\(Int((frost * 100).rounded()))%")
                .disabled(effectiveOpaque)
            parameter("Depth", description: "Strengthen the tinted edge", value: $style.depth, range: 0...1, text: "\(Int((depth * 100).rounded()))%")
            parameter("Grain", description: "Fine texture attached to the surface", value: $style.grain, range: 0...1, text: "\(Int((style.grain * 100).rounded()))%")
                .disabled(effectiveOpaque)
            parameter("Roundness", description: "Shape the worn shoulder", value: $style.cornerRadius, range: 12...64, text: "\(Int(style.cornerRadius)) pt")
            parameter("Light angle", description: effectiveStaticLight ? "Rim light is fixed by the comparison or system setting" : "Move the rim; keep the face still", value: $style.lightAngleDegrees, range: 0...360, text: effectiveStaticLight ? "Fixed" : "\(Int(light))°")
                .disabled(effectiveStaticLight)
        }
        .padding(20)
        .background(ink.opacity(isMineral ? 0.025 : 0.025), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(ink.opacity(0.08)) }
    }

    private func parameter(_ title: String, description: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(text).font(.subheadline.monospaced()).monospacedDigit()
            }
            Text(description).font(.caption).foregroundStyle(secondaryInk)
            Slider(value: value, in: range) { Text(title) }
                .accessibilityValue(text)
                .accessibilityIdentifier("parameter.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    private var componentSamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("04 / TOUCH SAMPLES")
            Button {
                sampleActivations += 1
            } label: {
                Label("Test press", systemImage: "hand.tap")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeaGlassButtonStyle(tint: tint, configuration: config))
            .accessibilityIdentifier("test-press")
            HStack(spacing: 12) {
                Button("Reset") {
                    style = .standard
                    showSignal = true
                    sampleActivations = 0
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(SeaGlassButtonStyle(tint: .frost, configuration: config))
                Button("Unavailable") {}
                    .frame(maxWidth: .infinity)
                    .buttonStyle(SeaGlassButtonStyle(tint: .frost, configuration: config))
                    .disabled(true)
            }
            Text(sampleActivations == 0 ? "Press a sample to inspect the visual contact response." : "Accepted presses: \(sampleActivations)")
                .font(.caption)
                .foregroundStyle(secondaryInk)
        }
    }

    private var accessibilityControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("05 / COMPARISON")
            Toggle("Show specimen background", isOn: $showSignal)
            Toggle("Opaque surface", isOn: $style.forceOpaque)
            Toggle("Static light", isOn: $style.staticLight)
            Text("System Reduce Transparency and Reduce Motion always take precedence.")
                .font(.caption)
                .foregroundStyle(secondaryInk)
        }
        .font(.subheadline)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.monospaced())
            .tracking(1.7)
            .foregroundStyle(secondaryInk)
    }
}

#Preview { MaterialLabView() }

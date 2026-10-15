import SwiftUI

/// Experimental satin glass built from native backdrop material and decorative SwiftUI drawing.
/// This is a custom material recipe, not Apple's Liquid Glass or a physical optics simulation.
public struct SeaGlassSurface<Content: View>: View {
    private let tint: SeaGlassTint
    private let configuration: SeaGlassConfiguration
    private let cornerRadius: CGFloat
    private let content: Content

    public init(
        tint: SeaGlassTint = .tide,
        configuration: SeaGlassConfiguration = .standard,
        cornerRadius: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.configuration = configuration
        self.cornerRadius = max(0, cornerRadius.isFinite ? cornerRadius : 28)
        self.content = content()
    }

    public var body: some View {
        content
            .background {
                SeaGlassBackdrop(
                    tint: tint,
                    configuration: configuration,
                    cornerRadius: cornerRadius
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

private struct SeaGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    let tint: SeaGlassTint
    let configuration: SeaGlassConfiguration
    let cornerRadius: CGFloat

    private var reduceTransparency: Bool {
        systemReduceTransparency || configuration.forceOpaque
    }

    private var reduceMotion: Bool {
        systemReduceMotion || configuration.staticLight
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var direction: SeaGlassLightDirection {
        reduceMotion ? .upperLeading : configuration.lightDirection
    }

    private var rimAngle: Double {
        atan2(direction.y, direction.x) * 180 / .pi
    }

    public var body: some View {
        ZStack {
            if reduceTransparency {
                shape.fill(tint.opaqueColor(for: colorScheme))
            } else {
                shape.fill(.ultraThinMaterial)
                // Pigment and scattering are constant across light-direction updates.
                shape.fill(tint.color.opacity(colorScheme == .dark ? 0.20 : 0.25))
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity((colorScheme == .dark ? 0.10 : 0.37) * configuration.frost),
                            Color.white.opacity((colorScheme == .dark ? 0.025 : 0.16) * configuration.frost)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // Stable ink bed guards the center from a bright or busy backdrop.
                shape.fill(
                    (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.06 + 0.12 * configuration.frost)
                )
                SeaGlassGrain(intensity: configuration.grain)
                    .clipShape(shape)
            }

            // A soft interior edge suggests a worn bevel. No rainbow or refractive sampling.
            shape.strokeBorder(
                tint.color.opacity(reduceTransparency ? 0.10 : 0.16),
                lineWidth: 2 + 4 * configuration.depth
            )
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(contrast == .increased ? 0.62 : 0.36),
                        Color.white.opacity(0.08),
                        Color.black.opacity(colorScheme == .dark ? 0.28 : 0.13),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: contrast == .increased ? 1.6 : 0.8
            )

            if !reduceTransparency {
                // Only this restrained perimeter arc follows the supplied light vector.
                shape.inset(by: 0.9).strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.40), location: 0.10),
                            .init(color: .clear, location: 0.22),
                            .init(color: .clear, location: 1)
                        ]),
                        center: .center,
                        startAngle: .degrees(rimAngle - 38),
                        endAngle: .degrees(rimAngle + 322)
                    ),
                    lineWidth: 0.85 + 0.55 * configuration.depth
                )
            }
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10),
            radius: 1 + 2 * configuration.depth,
            x: 0,
            y: 1 + 2 * configuration.depth
        )
        .shadow(
            color: tint.color.opacity(colorScheme == .dark ? 0.06 : 0.08),
            radius: 5 + 8 * configuration.depth,
            x: 0,
            y: 4 + 5 * configuration.depth
        )
    }
}

/// Deterministic grain: bounded draw count, no image asset, animation clock, or random-state owner.
private struct SeaGlassGrain: View {
    let intensity: Double

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            guard intensity > 0, size.width > 0, size.height > 0 else { return }
            let count = min(2_400, Int(size.width * size.height / 12))
            var seed: UInt64 = 0xC0A57A1
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 32) / Double(UInt32.max)
            }
            for index in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let diameter = 0.35 + 0.65 * next()
                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color((index.isMultiple(of: 3) ? Color.black : Color.white)
                        .opacity((0.025 + 0.065 * next()) * intensity))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

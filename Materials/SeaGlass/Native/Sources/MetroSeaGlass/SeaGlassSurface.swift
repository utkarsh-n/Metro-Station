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
        GeometryReader { geometry in
            let shortestSide = min(geometry.size.width, geometry.size.height)
            let shoulderWidth = min(12 + 20 * configuration.depth, max(2, shortestSide * 0.18))
            ZStack {
                contactShadow
                if reduceTransparency {
                    shape.fill(tint.opaqueColor(for: colorScheme))
                } else {
                    // Native backdrop stays outside decorative compositing and filtering.
                    shape.fill(.ultraThinMaterial)
                }
                layers(shoulderWidth: shoulderWidth)
            }
        }
    }

    private func layers(shoulderWidth: CGFloat) -> some View {
        ZStack {
            if !reduceTransparency {
                // Pigment and scattering are constant across light-direction updates.
                shape.fill(tint.color.opacity(colorScheme == .dark ? 0.27 : 0.22))
                shape.fill(
                    (colorScheme == .dark ? tint.color : .white)
                        .opacity((colorScheme == .dark ? 0.04 : 0.09)
                                 + (colorScheme == .dark ? 0.10 : 0.18) * configuration.frost)
                )
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity((colorScheme == .dark ? 0.09 : 0.24) * configuration.frost),
                            Color.white.opacity((colorScheme == .dark ? 0.025 : 0.10) * configuration.frost)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // Stable ink bed guards the center from a bright or busy backdrop.
                shape.fill(
                    (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.025 + 0.065 * configuration.frost)
                )
                matteShoulder(width: shoulderWidth)
                SeaGlassGrain(intensity: configuration.grain)
                    .clipShape(shape)
            }

            // A narrow boundary sits outside the soft inward shoulder; it is not a colored ring.
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(contrast == .increased ? 0.62 : (colorScheme == .dark ? 0.23 : 0.42)),
                        Color.white.opacity(0.04),
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        Color.white.opacity(0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: contrast == .increased ? 1.6 : 0.65
            )

            if !reduceTransparency {
                // Only this restrained perimeter arc follows the supplied light vector.
                ZStack {
                    shape.inset(by: 0.8).strokeBorder(rimGradient, lineWidth: 2 + configuration.depth)
                        .blur(radius: 0.8 + 0.4 * configuration.depth)
                        .opacity(0.55)
                    shape.inset(by: 0.8).strokeBorder(
                        rimGradient,
                        lineWidth: 0.7 + 0.4 * configuration.depth
                    )
                }
                .clipShape(shape)
                .transaction { $0.animation = nil }
            }
        }
    }

    /// Draw only outside the silhouette: no opaque source fill is placed behind native material.
    private var contactShadow: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let margin: CGFloat = 48
            let bounds = CGRect(x: margin, y: margin,
                                width: max(0, size.width - 2 * margin),
                                height: max(0, size.height - 2 * margin))
            let silhouette = shape.path(in: bounds)
            context.drawLayer { layer in
                layer.addFilter(.shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.26 : 0.11),
                    radius: 1.5 + 2 * configuration.depth,
                    x: 0, y: 1.5 + 2 * configuration.depth, options: .shadowOnly
                ))
                layer.fill(silhouette, with: .color(.black))
            }
            context.drawLayer { layer in
                layer.addFilter(.shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.14 : 0.055),
                    radius: 7 + 7 * configuration.depth,
                    x: 0, y: 4 + 5 * configuration.depth, options: .shadowOnly
                ))
                layer.fill(silhouette, with: .color(.black))
            }
            context.blendMode = .destinationOut
            context.fill(silhouette, with: .color(.black))
        }
        .padding(-48)
    }

    /// Two blurred bands and a soft static bevel merge into an inward roll, rather than a stroke.
    /// All blur is applied to decorative shapes and clipped to the surface; content is a sibling.
    private func matteShoulder(width: CGFloat) -> some View {
        ZStack {
            shape.strokeBorder(
                tint.color.opacity((colorScheme == .dark ? 0.15 : 0.11) + 0.10 * configuration.depth),
                lineWidth: width
            )
            .blur(radius: max(1, width * 0.28))

            shape.strokeBorder(
                tint.color.opacity((colorScheme == .dark ? 0.20 : 0.16) + 0.08 * configuration.depth),
                lineWidth: width * 0.40
            )
            .blur(radius: max(0.7, width * 0.16))

            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(colorScheme == .dark ? 0.13 : 0.27), location: 0),
                        .init(color: .white.opacity(0.02), location: 0.43),
                        .init(color: .clear, location: 0.58),
                        .init(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.09), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: width * 0.64
            )
            .blur(radius: max(1, width * 0.22))
        }
        .clipShape(shape)
    }

    private var rimGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.32), location: 0.10),
                .init(color: .clear, location: 0.22),
                .init(color: .clear, location: 1)
            ]),
            center: .center,
            startAngle: .degrees(rimAngle - 38),
            endAngle: .degrees(rimAngle + 322)
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

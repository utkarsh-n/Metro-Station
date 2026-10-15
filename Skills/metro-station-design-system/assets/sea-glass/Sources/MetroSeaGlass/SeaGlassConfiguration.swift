import SwiftUI

/// A bounded light vector in screen coordinates: positive x is right; positive y is down.
/// Only the decorative perimeter follows this vector. The face and content remain fixed.
public struct SeaGlassLightDirection: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        let safeX = x.isFinite ? x : 0
        let safeY = y.isFinite ? y : 0
        let scale = max(abs(safeX), abs(safeY))
        if scale > 1 {
            // Normalize before hypot so even the largest finite input cannot overflow.
            let scaledX = safeX / scale
            let scaledY = safeY / scale
            let length = hypot(scaledX, scaledY)
            self.x = scaledX / length
            self.y = scaledY / length
        } else {
            let divisor = max(1, hypot(safeX, safeY))
            self.x = safeX / divisor
            self.y = safeY / divisor
        }
    }

    public static let upperLeading = Self(x: -0.65, y: -0.76)
    public static let upperTrailing = Self(x: 0.65, y: -0.76)
}

/// Dimensionless, bounded art-direction controls. These values are not optical measurements.
public struct SeaGlassConfiguration: Equatable, Sendable {
    /// Milky scattering overlay. Native backdrop blur remains controlled by the system.
    public var frost: Double {
        didSet { frost = Self.clamp(frost) }
    }
    /// Illustrated perimeter thickness and contact shadow, not physical thickness.
    public var depth: Double {
        didSet { depth = Self.clamp(depth) }
    }
    public var lightDirection: SeaGlassLightDirection
    /// Fine, static decorative micrograin intensity.
    public var grain: Double {
        didSet { grain = Self.clamp(grain) }
    }
    /// Additive preview override. Never disables the system's Reduce Transparency preference.
    public var forceOpaque: Bool
    /// Additive preview override. Never disables the system's Reduce Motion preference.
    public var staticLight: Bool

    public init(
        frost: Double = 0.64,
        depth: Double = 0.55,
        lightDirection: SeaGlassLightDirection = .upperLeading,
        grain: Double = 0.45,
        forceOpaque: Bool = false,
        staticLight: Bool = false
    ) {
        self.frost = Self.clamp(frost)
        self.depth = Self.clamp(depth)
        self.lightDirection = lightDirection
        self.grain = Self.clamp(grain)
        self.forceOpaque = forceOpaque
        self.staticLight = staticLight
    }

    public static let standard = Self()

    private static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }
}

import Foundation

/// Relative angular detents for a touch crown. Clockwise screen angles are positive.
/// Each update returns at most one step; large pointer jumps never leave queued whole detents.
public struct CrownDetentTracker: Sendable {
    public let detentDegrees: Double
    public let hysteresisDegrees: Double
    public private(set) var residualDegrees: Double = 0
    public private(set) var lastDirection: Int = 0
    private var previousAngle: Double?

    public init(detentDegrees: Double, hysteresisDegrees: Double? = nil) {
        let spacing = detentDegrees.isFinite ? min(90, max(0.1, detentDegrees)) : 8
        self.detentDegrees = spacing
        let requested = hysteresisDegrees ?? spacing * 0.18
        self.hysteresisDegrees = requested.isFinite
            ? min(spacing * 0.45, max(0, requested)) : spacing * 0.18
    }

    public mutating func begin(angleDegrees: Double) {
        reset()
        if angleDegrees.isFinite { previousAngle = Self.wrap(angleDegrees) }
    }

    public mutating func reset() {
        previousAngle = nil
        residualDegrees = 0
        lastDirection = 0
    }

    /// Accumulates relative motion, preserves fractional travel, and damps direction reversals.
    public mutating func update(angleDegrees: Double) -> Int {
        guard angleDegrees.isFinite else { return 0 }
        let angle = Self.wrap(angleDegrees)
        guard let previousAngle else {
            self.previousAngle = angle
            return 0
        }
        self.previousAngle = angle
        residualDegrees += Self.wrap(angle - previousAngle)
        let direction = residualDegrees > 0 ? 1 : -1
        let reversing = lastDirection != 0 && direction != lastDirection
        let threshold = detentDegrees + (reversing ? hysteresisDegrees : 0)
        // Ignore only floating-point noise at an exact angular threshold.
        guard abs(residualDegrees) + 1e-9 >= threshold else { return 0 }
        residualDegrees -= Double(direction) * threshold
        // Keep fractional travel while discarding further whole steps from a large jump.
        residualDegrees = residualDegrees.truncatingRemainder(dividingBy: detentDegrees)
        if abs(residualDegrees) < 1e-9 { residualDegrees = 0 }
        lastDirection = direction
        return direction
    }

    private static func wrap(_ angle: Double) -> Double {
        var result = angle.truncatingRemainder(dividingBy: 360)
        if result > 180 { result -= 360 }
        if result < -180 { result += 360 }
        return result
    }
}

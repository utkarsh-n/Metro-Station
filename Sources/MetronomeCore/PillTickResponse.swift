/// A clock-synced perceptual envelope for the interior of a visual instrument.
/// This is not audio amplitude or a model of the haptic actuator. The synthesized
/// audio tick remains 55 ms; a slow pulse can have a longer visual response.
public enum PillTickResponse {
    public static let maximumDuration: Double = 0.200
    public static let preferredAttackDuration: Double = 0.020

    /// Settle before the following pulse, including the short side of swing.
    /// Pass the interval beginning at the actual rendered pulse, not its average.
    public static func duration(pulseInterval: Double) -> Double {
        guard pulseInterval.isFinite, pulseInterval > 0 else { return 0 }
        return min(maximumDuration, pulseInterval * 0.8)
    }

    /// The peak stays at 20 ms for slower rhythms and scales down for fast ones.
    public static func attackDuration(pulseInterval: Double) -> Double {
        min(preferredAttackDuration, duration(pulseInterval: pulseInterval) * 0.25)
    }

    /// Evaluate the current voice's actual host-clock age without a UI timer or
    /// accumulated animation state. Strength, accent and pitch are separate visual
    /// choices; multiplying this result by a bounded strength preserves its range.
    /// The rise and fall have zero slope at onset, peak and release (C1 continuity).
    public static func value(tickElapsed: Double?, pulseInterval: Double) -> Double {
        guard let elapsed = tickElapsed, elapsed.isFinite, elapsed > 0 else { return 0 }
        let support = duration(pulseInterval: pulseInterval)
        guard support > 0, elapsed < support else { return 0 }
        let attack = attackDuration(pulseInterval: pulseInterval)
        // Extremely small positive intervals may underflow the attack to zero.
        guard attack > 0 else { return 0 }
        if elapsed <= attack {
            return smoothstep(elapsed / attack)
        }
        return 1 - smoothstep((elapsed - attack) / (support - attack))
    }

    private static func smoothstep(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        return t * t * (3 - 2 * t)
    }
}

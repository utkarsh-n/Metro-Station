import Foundation

/// An analytically damped visual rhythm for a stationary circular glass surface.
/// Only the radius changes. This is a designed motion curve, not a simulation
/// of a mechanical spring, escapement or haptic actuator.
public enum GlassDialMotion {
    public static let restScale: Double = 1
    public static let minimumScale: Double = 0.92
    public static let maximumScale: Double = 1.09
    /// Dominant compressive overshoot after the initial outward swell.
    public static let compressionPhase: Double = 0.4549894277271932
    /// Dominant outward swell. Useful for a deterministic expanded-state capture.
    public static let peakPhase: Double = 0.18039238161291354

    // Maximum of the analytic displacement over 0...1, at peakPhase.
    private static let displacementPeak = 0.5982974279225974

    /// One outward swell, compressive overshoot and smaller settling rebound per
    /// quarter-note beat. A damped sinusoid provides the motion; smooth attack and
    /// release windows make radius, velocity and acceleration continuous at wrap.
    /// Use the transport's preserved beat phase, rather than elapsed time
    /// recomputed from the newly selected tempo. There are no staged easing joins.
    ///
    /// BPM gently scales excursion, from 70% at 30 BPM to 100% at 240 BPM.
    /// A one-BPM edit changes scale by at most 0.000129 without restarting phase.
    /// Finite phase is clamped to 0...1; malformed values and static modes rest.
    public static func radiusScale(
        beatPhase: Double,
        bpm: Double,
        isRunning: Bool = true,
        reduceMotion: Bool = false
    ) -> Double {
        guard isRunning, !reduceMotion, beatPhase.isFinite, bpm.isFinite else {
            return restScale
        }
        let phase = min(1, max(0, beatPhase))
        guard phase > 0, phase < 1 else { return restScale }
        let tempo = TempoAdjustment.wholeBPM(bpm)
        let amount = 0.70 + 0.30 * (tempo - 30) / 210
        let offset = 0.09 * displacement(at: phase) / displacementPeak
        return min(maximumScale, max(minimumScale, restScale + amount * offset))
    }

    private static func displacement(at phase: Double) -> Double {
        // expm1 preserves the smooth small-phase attack without cancellation.
        let attack = -expm1(-12 * phase)
        let remaining = 1 - phase
        // 1 - quintic smootherstep, factored to remain stable near release.
        let release = remaining * remaining * remaining * (1 + 3 * phase + 6 * phase * phase)
        return exp(-1.2 * phase) * attack * attack * release * sin(3 * .pi * phase)
    }
}

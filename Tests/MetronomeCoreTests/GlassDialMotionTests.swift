import Testing
@testable import MetronomeCore

@Suite("Glass dial radius motion")
struct GlassDialMotionTests {
    @Test
    func dampedOscillationStaysBoundedAndEachOvershootSettles() {
        for bpm in [30.0, 60, 120, 168, 240] {
            let compression = GlassDialMotion.radiusScale(beatPhase: GlassDialMotion.compressionPhase, bpm: bpm)
            let rebound = GlassDialMotion.radiusScale(beatPhase: GlassDialMotion.peakPhase, bpm: bpm)
            let settling = GlassDialMotion.radiusScale(beatPhase: 0.7418575990345566, bpm: bpm)
            #expect(compression < 1 && rebound > 1)
            #expect(settling > 1)
            #expect(abs(compression - 1) < abs(rebound - 1))
            #expect(abs(settling - 1) < abs(compression - 1))
            #expect(GlassDialMotion.radiusScale(beatPhase: 0, bpm: bpm) == 1)
            #expect(GlassDialMotion.radiusScale(beatPhase: 1, bpm: bpm) == 1)
            for index in 0...1000 {
                let radius = GlassDialMotion.radiusScale(beatPhase: Double(index) / 1000, bpm: bpm)
                #expect(radius.isFinite && radius >= 0.92 && radius <= 1.09)
            }
        }
        #expect(abs(GlassDialMotion.radiusScale(beatPhase: GlassDialMotion.compressionPhase, bpm: 240)
                    - 0.9540206939011883) < 1e-12)
        #expect(abs(GlassDialMotion.radiusScale(beatPhase: GlassDialMotion.peakPhase, bpm: 240) - 1.09) < 1e-12)
        #expect(abs(GlassDialMotion.radiusScale(beatPhase: 0.9, bpm: 240) - 1) < 0.00036)
    }

    @Test
    func analyticMotionCrossesRestWithoutPausingAndWrapsWithContinuousDerivatives() {
        let epsilon = 1e-6
        for bpm in [30.0, 120, 240] {
            func radius(_ phase: Double) -> Double {
                GlassDialMotion.radiusScale(beatPhase: phase, bpm: bpm)
            }
            #expect(abs(radius(1 - epsilon) - radius(epsilon)) < 1e-10)
            #expect(abs(radius(epsilon) - 1) / epsilon < 0.0001)
            #expect(abs(radius(1 - epsilon) - 1) / epsilon < 0.0001)
            for phase in [1.0 / 3, 2.0 / 3] {
                #expect(abs(radius(phase) - 1) < 1e-12)
                let leftVelocity = (radius(phase) - radius(phase - epsilon)) / epsilon
                let rightVelocity = (radius(phase + epsilon) - radius(phase)) / epsilon
                #expect(abs(leftVelocity) > 0.03 && abs(rightVelocity) > 0.03)
                #expect(abs(leftVelocity - rightVelocity) < 0.001)
            }
            for phase in [GlassDialMotion.peakPhase, GlassDialMotion.compressionPhase, 0.7418575990345566] {
                let velocity = (radius(phase + epsilon) - radius(phase - epsilon)) / (2 * epsilon)
                #expect(abs(velocity) < 1e-7)
            }
            // Both sides tend to zero acceleration at beat wrap; no easing join
            // contributes an acceleration discontinuity elsewhere in the cycle.
            let h = 1e-5
            let startAcceleration = (radius(2 * h) - 2 * radius(h) + radius(0)) / (h * h)
            let endAcceleration = (radius(1) - 2 * radius(1 - h) + radius(1 - 2 * h)) / (h * h)
            #expect(abs(startAcceleration) < 0.02 && abs(endAcceleration) < 0.02)
        }
    }

    @Test
    func transportRateAndLiveEditsPreserveTheSameBouncePhase() {
        let slow = MetronomeClockSegment(hostAnchor: 10, settings: MetronomeSettings(bpm: 60))
        let fast = MetronomeClockSegment(hostAnchor: 10, settings: MetronomeSettings(bpm: 120))
        // The rebound occurs at the same musical phase, twice as soon at twice BPM.
        let phase = GlassDialMotion.peakPhase
        let slowRebound = slow.hostTime(forBeatPosition: phase)
        let fastRebound = fast.hostTime(forBeatPosition: phase)
        #expect(abs((slowRebound - 10) - 2 * (fastRebound - 10)) < 1e-12)
        #expect(abs(slow.snapshot(at: slowRebound).beatPhase - phase) < 1e-12)
        #expect(abs(fast.snapshot(at: fastRebound).beatPhase - phase) < 1e-12)
        #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: 240)
                > GlassDialMotion.radiusScale(beatPhase: phase, bpm: 30))

        let host = 10.25
        let before = slow.snapshot(at: host)
        let rebased = slow.rebased(settings: MetronomeSettings(bpm: 61), at: host)
        let after = rebased.snapshot(at: host)
        #expect(after.beatPhase == before.beatPhase)
        let oldRadius = GlassDialMotion.radiusScale(beatPhase: before.beatPhase, bpm: 60)
        let newRadius = GlassDialMotion.radiusScale(beatPhase: after.beatPhase, bpm: 61)
        #expect(abs(newRadius - oldRadius) < 0.000129)
        // Excursion changes with BPM; it is phase continuity, not exact amplitude
        // equality under an arbitrary instantaneous tempo jump, that is preserved.
        for bpm in 30..<240 {
            for index in 0...100 {
                let phase = Double(index) / 100
                let radius = GlassDialMotion.radiusScale(beatPhase: phase, bpm: Double(bpm))
                let edited = GlassDialMotion.radiusScale(beatPhase: phase, bpm: Double(bpm + 1))
                #expect(abs(edited - radius) <= 0.000129)
            }
        }
    }

    @Test
    func staticModesAndMalformedInputsRestWhileFiniteTempoIsNormalized() {
        let phase = GlassDialMotion.peakPhase
        #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: 120, isRunning: false) == 1)
        #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: 120, reduceMotion: true) == 1)
        for phase in [Double.nan, .infinity, -.infinity, -1, 2, Double.greatestFiniteMagnitude] {
            #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: 120) == 1)
        }
        for bpm in [Double.nan, .infinity, -.infinity] {
            #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: bpm) == 1)
        }
        #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: -100)
                == GlassDialMotion.radiusScale(beatPhase: phase, bpm: 30))
        #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: Double.greatestFiniteMagnitude)
                == GlassDialMotion.radiusScale(beatPhase: phase, bpm: 240))
        #expect(GlassDialMotion.radiusScale(beatPhase: phase, bpm: 120.4)
                == GlassDialMotion.radiusScale(beatPhase: phase, bpm: 120))
    }
}

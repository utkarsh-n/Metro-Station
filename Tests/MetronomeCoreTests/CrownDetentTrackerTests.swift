import Testing
@testable import MetronomeCore

@Suite("Relative crown gestures")
struct CrownDetentTrackerTests {
    @Test
    func touchDownHasNoJumpAndFractionalTravelIsHeld() {
        var crown = CrownDetentTracker(detentDegrees: 8)
        crown.begin(angleDegrees: 120)
        #expect(crown.update(angleDegrees: 120) == 0)
        for jitter in [120.3, 119.8, 120.1, 119.9, 120.0] {
            #expect(crown.update(angleDegrees: jitter) == 0)
        }
        #expect(crown.update(angleDegrees: 125) == 0)
        #expect(crown.residualDegrees == 5)
        #expect(crown.update(angleDegrees: 129) == 1)
        #expect(crown.residualDegrees == 1)
        #expect(crown.update(angleDegrees: 135) == 0)
        #expect(crown.update(angleDegrees: 136) == 1)
        #expect(crown.residualDegrees == 0)
    }

    @Test
    func reversingDirectionRequiresExtraTravelWithoutBoundaryChatter() {
        var crown = CrownDetentTracker(detentDegrees: 20)
        crown.begin(angleDegrees: 0)
        #expect(crown.update(angleDegrees: 20) == 1)
        for jitter in [19.5, 20.5, 19.8, 20.0] {
            #expect(crown.update(angleDegrees: jitter) == 0)
        }
        #expect(crown.update(angleDegrees: 0) == 0) // Twenty degrees back is inside reversal hysteresis.
        #expect(crown.update(angleDegrees: -3.7) == -1)
        #expect(crown.lastDirection == -1)
        #expect(abs(crown.residualDegrees) < 0.2)
        #expect(crown.update(angleDegrees: -23.7) == -1)
    }

    @Test
    func seamCrossingsKeepDirectionAndFineGaugeThreshold() {
        var clockwise = CrownDetentTracker(detentDegrees: 8)
        clockwise.begin(angleDegrees: 179)
        #expect(clockwise.update(angleDegrees: -177) == 0)
        #expect(clockwise.update(angleDegrees: -173) == 1)
        var counterclockwise = CrownDetentTracker(detentDegrees: 8)
        counterclockwise.begin(angleDegrees: -179)
        #expect(counterclockwise.update(angleDegrees: 177) == 0)
        #expect(counterclockwise.update(angleDegrees: 173) == -1)
        let spacing = 300.0 / 210
        var rim = CrownDetentTracker(detentDegrees: spacing)
        rim.begin(angleDegrees: 0)
        #expect(rim.update(angleDegrees: spacing * 0.55) == 0)
        #expect(rim.update(angleDegrees: spacing) == 1)
    }

    @Test
    func largeJumpsCannotQueueFloodsAndResetDiscardsOldGesture() {
        var crown = CrownDetentTracker(detentDegrees: 8)
        crown.begin(angleDegrees: 0)
        #expect(crown.update(angleDegrees: 145) == 1)
        #expect(abs(crown.residualDegrees) < crown.detentDegrees)
        for _ in 0..<20 { #expect(crown.update(angleDegrees: 145) == 0) }
        #expect(crown.update(angleDegrees: .nan) == 0)
        #expect(crown.update(angleDegrees: .infinity) == 0)
        #expect(crown.update(angleDegrees: 152) == 1) // One held fractional degree plus seven fresh degrees.
        crown.reset()
        #expect(crown.residualDegrees == 0 && crown.lastDirection == 0)
        #expect(crown.update(angleDegrees: -120) == 0)
        #expect(crown.update(angleDegrees: -128) == -1)
        let invalid = CrownDetentTracker(detentDegrees: .nan, hysteresisDegrees: .infinity)
        #expect(invalid.detentDegrees == 8 && invalid.hysteresisDegrees == 1.44)
    }
}

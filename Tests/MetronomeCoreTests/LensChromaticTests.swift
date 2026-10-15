import Foundation
import Testing
@testable import MetronomeCore

@Suite("Subtle chromatic lens edges")
struct LensChromaticTests {
    @Test
    func channelSplitIsOnePointAtGaugeSizeAndProportionalToEnhancedTilt() {
        let diagonal = LensRefraction.chromaticPeakRadius / sqrt(2)
        func offset(_ gravity: Double, diameter: Double = 322) -> (x: Double, y: Double) {
            LensRefraction.chromaticOffset(normalizedX: diagonal, normalizedY: diagonal,
                                           gravityX: gravity, gravityY: 0, diameter: diameter)
        }
        #expect(LensRefraction.maximumChannelSplit(diameter: 322) == 1)
        #expect(LensRefraction.maximumChannelSplit(diameter: 644) == 1.2)
        #expect(abs(LensRefraction.maximumChannelSplit(diameter: 161) - 0.5) < 1e-12)
        let full = offset(1)
        let half = offset(0.5)
        #expect(abs(2 * full.x - 1) < 1e-12 && full.y == 0)
        #expect(abs(2 * half.x - 0.8) < 1e-12)
        #expect(abs(offset(-1).x + full.x) < 1e-12)
        #expect(offset(0).x == 0 && offset(0).y == 0)

        for diameter in [1.0, 161, 322, 644, Double.greatestFiniteMagnitude] {
            for x in -12...12 {
                for y in -12...12 {
                    let sampled = LensRefraction.chromaticOffset(
                        normalizedX: Double(x) / 10, normalizedY: Double(y) / 10,
                        gravityX: .greatestFiniteMagnitude, gravityY: -.greatestFiniteMagnitude,
                        diameter: diameter
                    )
                    #expect(sampled.x.isFinite && sampled.y.isFinite)
                    #expect(2 * hypot(sampled.x, sampled.y) <= LensRefraction.maximumChannelSplit(diameter: diameter) + 1e-12)
                }
            }
        }
    }

    @Test
    func diagonalArcsHaveSmoothRadialJoinsAndZeroCenterAxesAndRim() {
        func diagonalWeight(_ radius: Double) -> Double {
            LensRefraction.chromaticWeight(normalizedX: radius / sqrt(2), normalizedY: radius / sqrt(2))
        }
        #expect(diagonalWeight(0) == 0)
        #expect(diagonalWeight(0.4) == 0)
        #expect(abs(diagonalWeight(LensRefraction.chromaticPeakRadius) - 1) < 1e-12)
        #expect(diagonalWeight(0.9) > 0.5 && diagonalWeight(0.9) < 1)
        #expect(diagonalWeight(1) < 1e-12 && diagonalWeight(1.1) == 0)
        #expect(LensRefraction.chromaticWeight(normalizedX: 0.82, normalizedY: 0) == 0)
        #expect(LensRefraction.chromaticWeight(normalizedX: 0, normalizedY: -0.82) == 0)
        let quarterTurn = LensRefraction.chromaticWeight(normalizedX: -0.6, normalizedY: 0.6)
        #expect(abs(quarterTurn - LensRefraction.chromaticWeight(normalizedX: 0.6, normalizedY: 0.6)) < 1e-12)

        let h = 1e-6
        for join in [LensRefraction.chromaticInnerStart, LensRefraction.chromaticPeakRadius, 1] {
            let leftVelocity = (diagonalWeight(join) - diagonalWeight(join - h)) / h
            let rightVelocity = (diagonalWeight(join + h) - diagonalWeight(join)) / h
            let leftCurvature = (diagonalWeight(join) - 2 * diagonalWeight(join - h) + diagonalWeight(join - 2 * h)) / (h * h)
            let rightCurvature = (diagonalWeight(join + 2 * h) - 2 * diagonalWeight(join + h) + diagonalWeight(join)) / (h * h)
            #expect(abs(leftVelocity - rightVelocity) < 1e-4)
            #expect(abs(leftCurvature - rightCurvature) < 0.02)
        }
        // Smooth angular suppression also has zero slope at the axial arcs.
        let radius = LensRefraction.chromaticPeakRadius
        let angularEpsilon = 1e-5
        let nearAxis = LensRefraction.chromaticWeight(normalizedX: radius * cos(angularEpsilon),
                                                     normalizedY: radius * sin(angularEpsilon))
        #expect(nearAxis / angularEpsilon < 1e-4)
    }

    @Test
    func malformedAndStaticInputsCannotCreateColorSeparation() {
        let diagonal = LensRefraction.chromaticPeakRadius / sqrt(2)
        let disabled = LensRefraction.chromaticOffset(normalizedX: diagonal, normalizedY: diagonal,
                                                     gravityX: 1, gravityY: 1, diameter: 322, enabled: false)
        #expect(disabled.x == 0 && disabled.y == 0)
        for invalid in [Double.nan, .infinity, -.infinity] {
            #expect(LensRefraction.maximumChannelSplit(diameter: invalid) == 0)
            #expect(LensRefraction.chromaticWeight(normalizedX: invalid, normalizedY: diagonal) == 0)
            let offset = LensRefraction.chromaticOffset(normalizedX: diagonal, normalizedY: diagonal,
                                                       gravityX: invalid, gravityY: 1, diameter: 322)
            #expect(offset.x == 0 && offset.y == 0)
        }
        #expect(LensRefraction.maximumChannelSplit(diameter: -1) == 0)
        #expect(LensRefraction.maximumChannelSplit(diameter: 0) == 0)
        #expect(LensRefraction.chromaticWeight(normalizedX: .greatestFiniteMagnitude,
                                              normalizedY: .greatestFiniteMagnitude) == 0)
    }
}

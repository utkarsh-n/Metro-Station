import Foundation
import Testing
@testable import MetronomeCore

@Suite("Bounded lens refraction")
struct LensRefractionTests {
    @Test
    func moderateTiltIsEnhancedWithoutChangingDirectionOrExceedingUnitMagnitude() {
        let half = LensRefraction.enhancedTilt(x: 0.3, y: 0.4)
        #expect(abs(half.x - 0.48) < 1e-12 && abs(half.y - 0.64) < 1e-12)
        #expect(abs(hypot(half.x, half.y) - 0.8) < 1e-12)
        let opposite = LensRefraction.enhancedTilt(x: -0.3, y: -0.4)
        #expect(opposite.x == -half.x && opposite.y == -half.y)

        var previousMagnitude = 0.0
        for index in 0...200 {
            let magnitude = Double(index) / 100
            let tilt = LensRefraction.enhancedTilt(x: magnitude * 0.6, y: magnitude * 0.8)
            let enhancedMagnitude = hypot(tilt.x, tilt.y)
            #expect(enhancedMagnitude >= previousMagnitude - 1e-12)
            #expect(enhancedMagnitude <= 1 + 1e-12)
            #expect(abs(tilt.x * 0.8 - tilt.y * 0.6) < 1e-12)
            previousMagnitude = enhancedMagnitude
        }
        let largest = Double.greatestFiniteMagnitude
        let hostile = LensRefraction.enhancedTilt(x: largest, y: -largest / 2)
        #expect(hostile.x.isFinite && hostile.y.isFinite)
        #expect(abs(hypot(hostile.x, hostile.y) - 1) < 1e-12)
        #expect(abs(hostile.y / hostile.x + 0.5) < 1e-12)
        let epsilon = 1e-5
        let belowUnit = LensRefraction.enhancedTilt(x: 1 - epsilon, y: 0)
        let aboveUnit = LensRefraction.enhancedTilt(x: 1 + epsilon, y: 0)
        #expect(abs(aboveUnit.x - belowUnit.x) / (2 * epsilon) < 1e-5)
    }

    @Test
    func broadInteriorWarpReleasesWithContinuousVelocityAndCurvatureAtTheRim() {
        func weight(_ radius: Double) -> Double {
            LensRefraction.weight(normalizedX: radius, normalizedY: 0)
        }
        #expect(weight(0) == 1)
        #expect(abs(weight(0.5) - 0.92) < 1e-12)
        #expect(weight(0.8) > 0.79)
        #expect(weight(0.9) > 0.4)
        #expect(weight(1) == 0 && weight(1.01) == 0)
        #expect(abs(weight(0.5) - LensRefraction.weight(normalizedX: 0.3, normalizedY: 0.4)) < 1e-12)

        // The narrow feather has a large third derivative; sample close enough
        // to its joins to measure the limiting, continuous second derivative.
        let h = 1e-6
        for join in [LensRefraction.rimStart, 1] {
            let leftVelocity = (weight(join) - weight(join - h)) / h
            let rightVelocity = (weight(join + h) - weight(join)) / h
            let leftCurvature = (weight(join) - 2 * weight(join - h) + weight(join - 2 * h)) / (h * h)
            let rightCurvature = (weight(join + 2 * h) - 2 * weight(join + h) + weight(join)) / (h * h)
            #expect(abs(leftVelocity - rightVelocity) < 1e-4)
            #expect(abs(leftCurvature - rightCurvature) < 0.012)
        }
        #expect(abs(weight(1 - h)) / h < 1e-5)
        var previous = 1.0
        for index in 0...1000 {
            let value = weight(Double(index) / 1000)
            #expect(value >= 0 && value <= 1)
            #expect(value <= previous + 1e-12)
            previous = value
        }
    }

    @Test
    func samplingDisplacementIsBoundedInPointsAndStationaryAtTheLensRim() {
        #expect(abs(LensRefraction.maximumShift(diameter: 322) - 8.05) < 1e-12)
        #expect(LensRefraction.maximumShift(diameter: 500) == 9.5)
        let center = LensRefraction.sampleOffset(normalizedX: 0, normalizedY: 0,
                                                gravityX: 0.5, gravityY: 0, diameter: 322)
        #expect(abs(center.x - 6.44) < 1e-12 && center.y == 0)
        let diameters = [1.0, 160, 322, 500, Double.greatestFiniteMagnitude]
        let gravities = [(0.0, 0.0), (0.3, -0.4), (1.0, 0.0), (9.0, -12.0)]
        for diameter in diameters {
            for gravity in gravities {
                for x in -10...10 {
                    for y in -10...10 {
                        let offset = LensRefraction.sampleOffset(
                            normalizedX: Double(x) / 10, normalizedY: Double(y) / 10,
                            gravityX: gravity.0, gravityY: gravity.1, diameter: diameter
                        )
                        #expect(offset.x.isFinite && offset.y.isFinite)
                        #expect(hypot(offset.x, offset.y) <= LensRefraction.maximumShift(diameter: diameter) + 1e-12)
                        if x * x + y * y >= 100 {
                            #expect(abs(offset.x) < 1e-12 && abs(offset.y) < 1e-12)
                        }
                    }
                }
            }
        }
    }

    @Test
    func staticModeAndMalformedInputsReturnFiniteZeroDisplacement() {
        let disabled = LensRefraction.sampleOffset(normalizedX: 0.5, normalizedY: 0,
                                                  gravityX: 1, gravityY: 0.5, diameter: 322, enabled: false)
        #expect(disabled.x == 0 && disabled.y == 0)
        for invalid in [Double.nan, .infinity, -.infinity] {
            let invalidTilt = LensRefraction.enhancedTilt(x: invalid, y: 0.5)
            #expect(invalidTilt.x == 0 && invalidTilt.y == 0)
            #expect(LensRefraction.weight(normalizedX: 0, normalizedY: invalid) == 0)
            #expect(LensRefraction.maximumShift(diameter: invalid) == 0)
            let offset = LensRefraction.sampleOffset(normalizedX: invalid, normalizedY: 0,
                                                    gravityX: 1, gravityY: 0, diameter: 322)
            #expect(offset.x == 0 && offset.y == 0)
        }
        for diameter in [0.0, -1, -Double.greatestFiniteMagnitude] {
            #expect(LensRefraction.maximumShift(diameter: diameter) == 0)
        }
        #expect(LensRefraction.weight(normalizedX: .greatestFiniteMagnitude,
                                     normalizedY: .greatestFiniteMagnitude) == 0)
        let smallest = LensRefraction.enhancedTilt(x: .leastNonzeroMagnitude, y: 0)
        #expect(smallest.x.isFinite && smallest.x > 0 && smallest.y == 0)
    }
}

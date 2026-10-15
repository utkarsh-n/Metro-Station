import Testing
@testable import MetronomeCore

@Suite("Perceptual tick response")
struct PillTickResponseTests {
    @Test
    func slowPulseHasPredictablePeakAndMonotonicRelease() {
        let interval = 0.5
        let attack = PillTickResponse.attackDuration(pulseInterval: interval)
        let support = PillTickResponse.duration(pulseInterval: interval)
        #expect(attack == 0.020)
        #expect(support == 0.200)
        #expect(PillTickResponse.value(tickElapsed: 0, pulseInterval: interval) == 0)
        #expect(PillTickResponse.value(tickElapsed: attack / 2, pulseInterval: interval) == 0.5)
        #expect(PillTickResponse.value(tickElapsed: attack, pulseInterval: interval) == 1)

        var previous = 0.0
        for index in 1...100 {
            let elapsed = attack * Double(index) / 100
            let response = PillTickResponse.value(tickElapsed: elapsed, pulseInterval: interval)
            #expect(response >= previous && response <= 1)
            previous = response
        }
        for index in 1...100 {
            let elapsed = attack + (support - attack) * Double(index) / 100
            let response = PillTickResponse.value(tickElapsed: elapsed, pulseInterval: interval)
            #expect(response >= 0 && response <= previous)
            previous = response
        }
        #expect(previous == 0)
        // The perceptual display outlasts the audible tick; it does not alter DSP.
        #expect(TickSynthesis.duration == 0.055)
        #expect(PillTickResponse.value(tickElapsed: TickSynthesis.duration, pulseInterval: interval) > 0)
        #expect(PillTickResponse.value(tickElapsed: support, pulseInterval: interval) == 0)
        #expect(PillTickResponse.value(tickElapsed: 10_000, pulseInterval: interval) == 0)
    }

    @Test(arguments: [0.034375, 0.0625, 0.25, 2.0])
    func onsetPeakAndEndHaveContinuousZeroSlope(interval: Double) {
        let support = PillTickResponse.duration(pulseInterval: interval)
        let attack = PillTickResponse.attackDuration(pulseInterval: interval)
        let epsilon = support * 1e-6
        func value(_ elapsed: Double) -> Double {
            PillTickResponse.value(tickElapsed: elapsed, pulseInterval: interval)
        }
        // Normalize slopes by support, so the check has the same meaning at all
        // tempos. Both one-sided derivatives converge to zero at each join.
        #expect(value(-epsilon) == 0 && value(0) == 0)
        #expect(value(epsilon) / epsilon * support < 0.001)
        #expect(value(attack) == 1)
        #expect((1 - value(attack - epsilon)) / epsilon * support < 0.001)
        #expect((1 - value(attack + epsilon)) / epsilon * support < 0.001)
        #expect(value(support - epsilon) / epsilon * support < 0.001)
        #expect(value(support) == 0 && value(support + epsilon) == 0)
    }

    @Test
    func supportedRhythmsSettleBeforeEveryActualPulseInterval() {
        for bpm in [30.0, 120.0, 240.0] {
            for subdivision in 1...4 {
                for swing in [0.0, 0.45] {
                    let settings = MetronomeSettings(bpm: bpm, subdivision: subdivision, swing: swing)
                    for pulse in 0..<subdivision {
                        let interval = MetronomeTiming.pulseDuration(index: pulse, settings: settings)
                        let support = PillTickResponse.duration(pulseInterval: interval)
                        let attack = PillTickResponse.attackDuration(pulseInterval: interval)
                        #expect(support > 0 && support <= interval * 0.8)
                        #expect(support <= PillTickResponse.maximumDuration)
                        #expect(attack > 0 && attack <= support * 0.25)
                        #expect(PillTickResponse.value(tickElapsed: attack, pulseInterval: interval) == 1)
                        #expect(PillTickResponse.value(tickElapsed: interval, pulseInterval: interval) == 0)
                        for index in 0...100 {
                            let response = PillTickResponse.value(tickElapsed: interval * Double(index) / 100,
                                                                  pulseInterval: interval)
                            #expect(response.isFinite && response >= 0 && response <= 1)
                        }
                    }
                }
            }
        }
        let fastest = MetronomeSettings(bpm: 240, subdivision: 4, swing: 0.45)
        let shortInterval = MetronomeTiming.pulseDuration(index: 1, settings: fastest)
        #expect(abs(shortInterval - 0.034375) < 1e-12)
        #expect(abs(PillTickResponse.duration(pulseInterval: shortInterval) - 0.0275) < 1e-12)
        #expect(abs(PillTickResponse.attackDuration(pulseInterval: shortInterval) - 0.006875) < 1e-12)
    }

    @Test
    func invalidAndExtremeInputsNeverProduceAVisibleOrNonfiniteResponse() {
        for age: Double? in [nil, -1, -.infinity, .infinity, .nan, Double.greatestFiniteMagnitude] {
            #expect(PillTickResponse.value(tickElapsed: age, pulseInterval: 0.5) == 0)
        }
        for interval in [-1.0, 0, -.infinity, .infinity, .nan] {
            #expect(PillTickResponse.duration(pulseInterval: interval) == 0)
            #expect(PillTickResponse.attackDuration(pulseInterval: interval) == 0)
            #expect(PillTickResponse.value(tickElapsed: 0.01, pulseInterval: interval) == 0)
        }
        #expect(PillTickResponse.duration(pulseInterval: Double.greatestFiniteMagnitude) == 0.2)
        #expect(PillTickResponse.value(tickElapsed: 0.02,
                                      pulseInterval: Double.greatestFiniteMagnitude) == 1)
        #expect(PillTickResponse.value(tickElapsed: Double.leastNonzeroMagnitude,
                                      pulseInterval: Double.leastNonzeroMagnitude) == 0)
    }
}

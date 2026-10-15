import Testing
@testable import MetronomeCore

@Suite("Whole tempo and musical crown targets")
struct TempoAdjustmentTests {
    @Test
    func restoredFractionalTemposBecomeWholeAndBounded() {
        let pairs: [(Double, Double)] = [
            (119.1, 119), (119.49, 119), (119.5, 120), (120.1, 120),
            (30.49, 30), (30.5, 31), (239.5, 240),
            (-100, 30), (999, 240), (.greatestFiniteMagnitude, 240),
            (.nan, 120), (.infinity, 120), (-.infinity, 120)
        ]
        for (restored, expected) in pairs {
            let migrated = TempoAdjustment.wholeBPM(restored)
            #expect(migrated == expected)
            #expect(migrated.rounded() == migrated)
            #expect(TempoAdjustment.wholeBPM(migrated) == migrated)
        }
    }

    @Test
    func musicalStepsFollowCurrentBandAndCanonicalBoundaries() {
        #expect(TempoAdjustment.nextMarkingBPM(from: 120, direction: 1) == 168)
        #expect(TempoAdjustment.nextMarkingBPM(from: 120, direction: -1) == 108)
        #expect(TempoAdjustment.nextMarkingBPM(from: 150, direction: 1) == 168)
        #expect(TempoAdjustment.nextMarkingBPM(from: 150, direction: -1) == 108)
        let canonical = [30.0, 60, 76, 108, 120, 168, 200]
        for index in canonical.indices {
            if index + 1 < canonical.count {
                #expect(TempoAdjustment.nextMarkingBPM(from: canonical[index], direction: 1) == canonical[index + 1])
            }
            if index > 0 {
                #expect(TempoAdjustment.nextMarkingBPM(from: canonical[index], direction: -1) == canonical[index - 1])
            }
        }
    }

    @Test
    func extremeBandsAndDirectionInputDoNotCreateWrongWayJumps() {
        #expect(TempoAdjustment.nextMarkingBPM(from: 240, direction: 1) == 240)
        #expect(TempoAdjustment.nextMarkingBPM(from: 210.2, direction: .max) == 210)
        #expect(TempoAdjustment.nextMarkingBPM(from: 30, direction: -1) == 30)
        #expect(TempoAdjustment.nextMarkingBPM(from: 45.2, direction: .min) == 45)
        #expect(TempoAdjustment.nextMarkingBPM(from: 150.4, direction: 0) == 150)
        #expect(TempoAdjustment.nextMarkingBPM(from: .nan, direction: 1) == 168)
        for bpm in 30...240 {
            for direction in [-1, 1] {
                let target = TempoAdjustment.nextMarkingBPM(from: Double(bpm), direction: direction)
                #expect(target.isFinite && target.rounded() == target && target >= 30 && target <= 240)
                #expect(direction > 0 ? target >= Double(bpm) : target <= Double(bpm))
            }
        }
    }
}

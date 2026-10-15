import Testing
@testable import MetronomeCore

@Suite("Tap tempo")
struct TapTempoTests {
    @Test
    func estimatesTempoAndRejectsMissedTap() {
        var tracker = TapTempoTracker()
        #expect(tracker.tap(at: 0) == nil)
        #expect(tracker.tap(at: 0.5) == 120)
        #expect(tracker.tap(at: 1) == 120)
        #expect(tracker.tap(at: 1.5) == 120)
        // A missed tap makes one doubled interval; established taps dominate the median.
        #expect(tracker.tap(at: 2.5) == 120)
        #expect(tracker.tap(at: 3) == 120)
    }

    @Test
    func accidentalDoubleTapDoesNotShiftLastTap() {
        var tracker = TapTempoTracker()
        _ = tracker.tap(at: 1)
        #expect(tracker.tap(at: 1.05) == nil)
        #expect(tracker.tap(at: 1.5) == 120)
        #expect(tracker.tapCount == 2)
        #expect(tracker.tap(at: 1.55) == 120)
        #expect(tracker.tap(at: 2) == 120)
    }

    @Test
    func longPauseOrTimeReversalResetsSequence() {
        var tracker = TapTempoTracker()
        _ = tracker.tap(at: 0)
        _ = tracker.tap(at: 0.5)
        #expect(tracker.tap(at: 4) == nil)
        #expect(tracker.tapCount == 1)
        #expect(tracker.tap(at: 5) == 60)
        #expect(tracker.tap(at: 3) == nil)
        #expect(tracker.tapCount == 1)
        #expect(tracker.tap(at: .nan) == nil)
        #expect(tracker.tap(at: 3.25) == 240)
        tracker.reset()
        #expect(tracker.estimate == nil)
        #expect(tracker.tapCount == 0)
    }

    @Test
    func incompleteOutlierSequenceStillReturnsFiniteValue() {
        var tracker = TapTempoTracker()
        _ = tracker.tap(at: 0)
        _ = tracker.tap(at: 0.5)
        let estimate = tracker.tap(at: 1.5)
        #expect(estimate != nil)
        #expect(estimate!.isFinite)
        #expect(estimate! >= 30 && estimate! <= 240)
    }
}

import Foundation

/// Shared targets for the fine BPM crown, musical-marking crown, and restored preferences.
public enum TempoAdjustment {
    public static func wholeBPM(_ value: Double) -> Double {
        guard value.isFinite else { return 120 }
        return min(240, max(30, value)).rounded(.toNearestOrAwayFromZero)
    }

    /// Moves one musical band and lands on its canonical lower boundary.
    /// At the outermost band, turning farther outward leaves the current whole tempo unchanged.
    public static func nextMarkingBPM(from value: Double, direction: Int) -> Double {
        let bpm = wholeBPM(value)
        guard direction != 0 else { return bpm }
        let markings = TempoMarking.allCases
        let current = TempoMarking.forBPM(bpm)
        guard let index = markings.firstIndex(of: current) else { return bpm }
        let next = index + (direction > 0 ? 1 : -1)
        guard markings.indices.contains(next) else { return bpm }
        return markings[next].approximateRange.lowerBound
    }
}

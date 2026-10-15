import Foundation

/// Estimates tempo from a short sequence; a long pause or time reversal starts a new sequence.
public struct TapTempoTracker: Sendable {
    public private(set) var tapCount = 0
    private var lastTap: Double?
    private var intervals: [Double] = []

    public init() {}

    public mutating func reset() {
        tapCount = 0
        lastTap = nil
        intervals.removeAll(keepingCapacity: true)
    }

    /// Returns nil until two usable taps. Very short accidental double taps are ignored.
    public mutating func tap(at time: Double) -> Double? {
        guard time.isFinite else { return nil }
        guard let previous = lastTap else {
            lastTap = time
            tapCount = 1
            return nil
        }
        let interval = time - previous
        if interval <= 0 || interval > 2.5 {
            reset()
            lastTap = time
            tapCount = 1
            return nil
        }
        if interval < 0.15 { return estimate }
        lastTap = time
        tapCount += 1
        intervals.append(interval)
        if intervals.count > 7 { intervals.removeFirst() }
        return estimate
    }

    public var estimate: Double? {
        guard !intervals.isEmpty else { return nil }
        let sorted = intervals.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
        // Reject isolated missed taps / stray taps relative to the established rhythm.
        let inliers = intervals.filter { abs($0 - median) <= median * 0.22 }
        let average = inliers.isEmpty ? median : inliers.reduce(0, +) / Double(inliers.count)
        return min(240, max(30, 60 / average))
    }
}

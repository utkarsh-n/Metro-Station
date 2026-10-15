#if DEBUG
import Foundation
import QuartzCore
import UIKit

/// Opt-in device evidence, fed only by UIKit touches delivered to the boundary.
/// It never drives a control or changes a recognizer's behavior.
@MainActor
final class PhysicalScrollAudit: NSObject {
    static let shared = PhysicalScrollAudit()

    let isEnabled = ProcessInfo.processInfo.arguments.contains("--physical-qa")
    private let maximumCompletedRecords = 128
    private let maximumStoredSamples = 600
    private var active: [UUID: ActiveInteraction] = [:]
    private var completed: [InteractionRecord] = []
    private var displayLink: CADisplayLink?
    private var lastWriteError: String?

    var controlTouchesStayedStationary: Bool {
        !completed.isEmpty && completed.allSatisfy { record in
            record.maxOffsetDrift <= 0.1 && record.maxMarkerMinYDrift <= 0.1
                && record.sampleCount > 0 && record.omittedSampleCount == 0
        }
    }

    private var artifactURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhysicalQA", isDirectory: true)
            .appendingPathComponent("scroll-\(ProcessInfo.processInfo.processIdentifier).json")
    }

    func begin(identifier: String, scrollView: UIScrollView, marker: UIView,
               boundary: UIGestureRecognizer, touch: UITouch) -> UUID? {
        guard isEnabled, active.count < 8, let window = marker.window,
              window === scrollView.window, !marker.bounds.isEmpty,
              marker.bounds.contains(touch.location(in: marker)) else { return nil }

        let id = UUID()
        let now = ProcessInfo.processInfo.systemUptime
        let offset = Point(scrollView.contentOffset)
        let frame = Rect(marker.convert(marker.bounds, to: window))
        let panState = stateName(scrollView.panGestureRecognizer.state)
        let boundaryState = stateName(boundary.state)
        let record = InteractionRecord(
            id: id.uuidString, identifier: identifier,
            touchType: touch.type.rawValue, touchTimestamp: touch.timestamp,
            touchPointInMarker: Point(touch.location(in: marker)),
            touchPointInWindow: Point(touch.location(in: window)),
            markerBounds: Rect(marker.bounds),
            beginTimestamp: now, beginUnixTime: Date().timeIntervalSince1970,
            baselineOffset: offset, finalOffset: offset,
            markerFrameInWindowAtBegin: frame, markerFrameInWindowAtEnd: frame,
            baselineMarkerMinY: frame.y, finalMarkerMinY: frame.y,
            beginPanState: panState, finalPanState: panState,
            beginBoundaryState: boundaryState, finalBoundaryState: boundaryState)
        let interaction = ActiveInteraction(record: record, scrollView: scrollView,
                                            marker: marker, boundary: boundary)
        active[id] = interaction
        sample(interaction, timestamp: now)
        startDisplayLinkIfNeeded()
        flush()
        return id
    }

    func end(_ id: UUID, outcome: String, finalTouch: UITouch? = nil) {
        guard let interaction = active[id] else { return }
        let now = ProcessInfo.processInfo.systemUptime
        sample(interaction, timestamp: now)
        interaction.record.endTimestamp = now
        interaction.record.endUnixTime = Date().timeIntervalSince1970
        interaction.record.outcome = outcome
        if let finalTouch, let marker = interaction.marker, let window = marker.window {
            interaction.record.finalTouchPointInMarker = Point(finalTouch.location(in: marker))
            interaction.record.finalTouchPointInWindow = Point(finalTouch.location(in: window))
            interaction.record.finalTouchTimestamp = finalTouch.timestamp
        }
        active[id] = nil
        completed.append(interaction.record)
        if completed.count > maximumCompletedRecords {
            completed.removeFirst(completed.count - maximumCompletedRecords)
        }
        if active.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
        }
        // Synchronous atomic write on the main thread makes the final sample
        // durable before XCTest terminates the app. No audio thread is involved.
        flush()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(sampleDisplayFrame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func sampleDisplayFrame(_ link: CADisplayLink) {
        let now = ProcessInfo.processInfo.systemUptime
        for interaction in active.values { sample(interaction, timestamp: now) }
    }

    private func sample(_ interaction: ActiveInteraction, timestamp: Double) {
        guard let scrollView = interaction.scrollView else {
            interaction.record.unavailableScrollSampleCount += 1
            return
        }
        let offset = Point(scrollView.contentOffset)
        let dx = offset.x - interaction.record.baselineOffset.x
        let dy = offset.y - interaction.record.baselineOffset.y
        interaction.record.maxOffsetDrift = max(interaction.record.maxOffsetDrift, hypot(dx, dy))
        interaction.record.maxHorizontalOffsetDrift = max(interaction.record.maxHorizontalOffsetDrift, abs(dx))
        interaction.record.maxVerticalOffsetDrift = max(interaction.record.maxVerticalOffsetDrift, abs(dy))
        interaction.record.finalOffset = offset
        interaction.record.finalPanState = stateName(scrollView.panGestureRecognizer.state)
        if let boundary = interaction.boundary {
            interaction.record.finalBoundaryState = stateName(boundary.state)
        }
        var markerMinY: Double?
        if let marker = interaction.marker, let window = marker.window,
           window === scrollView.window, !marker.bounds.isEmpty {
            let frame = Rect(marker.convert(marker.bounds, to: window))
            markerMinY = frame.y
            interaction.record.markerFrameInWindowAtEnd = frame
            interaction.record.finalMarkerMinY = frame.y
            interaction.record.maxMarkerMinYDrift = max(
                interaction.record.maxMarkerMinYDrift,
                abs(frame.y - interaction.record.baselineMarkerMinY))
        } else {
            interaction.record.unavailableMarkerSampleCount += 1
        }
        interaction.record.sampleCount += 1
        if interaction.record.samples.count < maximumStoredSamples {
            interaction.record.samples.append(Sample(
                timestamp: timestamp, offset: offset, markerMinY: markerMinY,
                panState: interaction.record.finalPanState,
                boundaryState: interaction.record.finalBoundaryState))
        } else {
            interaction.record.omittedSampleCount += 1
        }
    }

    private func flush() {
        guard isEnabled else { return }
        let document = AuditDocument(
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            deviceModel: UIDevice.current.model, systemVersion: UIDevice.current.systemVersion,
            isPhysicalDevice: isPhysicalDevice,
            artifactPath: artifactURL.path,
            writtenUnixTime: Date().timeIntervalSince1970,
            lastWriteError: lastWriteError,
            controlTouchesStayedStationary: controlTouchesStayedStationary,
            records: completed + active.values.map(\.record).sorted { $0.beginTimestamp < $1.beginTimestamp })
        do {
            try FileManager.default.createDirectory(at: artifactURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(document).write(to: artifactURL, options: .atomic)
            lastWriteError = nil
        } catch {
            lastWriteError = String(describing: error)
            NSLog("Physical scroll audit write failed: %@", String(describing: error))
        }
    }

    private var isPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    private func stateName(_ state: UIGestureRecognizer.State) -> String {
        switch state {
        case .possible: "possible"
        case .began: "began"
        case .changed: "changed"
        case .ended: "ended"
        case .cancelled: "cancelled"
        case .failed: "failed"
        @unknown default: "unknown"
        }
    }

    private final class ActiveInteraction {
        var record: InteractionRecord
        weak var scrollView: UIScrollView?
        weak var marker: UIView?
        weak var boundary: UIGestureRecognizer?

        init(record: InteractionRecord, scrollView: UIScrollView, marker: UIView,
             boundary: UIGestureRecognizer) {
            self.record = record
            self.scrollView = scrollView
            self.marker = marker
            self.boundary = boundary
        }
    }

    private struct AuditDocument: Encodable {
        let formatVersion = 1
        let launchFlag = "--physical-qa"
        let source = "UIKitBoundaryTouches"
        let sampleRateHz = 30
        let processIdentifier: Int32
        let bundleIdentifier: String?
        let appVersion: String?
        let appBuild: String?
        let deviceModel: String
        let systemVersion: String
        let isPhysicalDevice: Bool
        let artifactPath: String
        let writtenUnixTime: Double
        let lastWriteError: String?
        let controlTouchesStayedStationary: Bool
        let records: [InteractionRecord]
    }

    private struct InteractionRecord: Encodable {
        let id: String
        let identifier: String
        let touchType: Int
        let touchTimestamp: Double
        let touchPointInMarker: Point
        let touchPointInWindow: Point
        let markerBounds: Rect
        let beginTimestamp: Double
        let beginUnixTime: Double
        var endTimestamp: Double?
        var endUnixTime: Double?
        var outcome: String?
        let baselineOffset: Point
        var finalOffset: Point
        var maxOffsetDrift = 0.0
        var maxHorizontalOffsetDrift = 0.0
        var maxVerticalOffsetDrift = 0.0
        let markerFrameInWindowAtBegin: Rect
        var markerFrameInWindowAtEnd: Rect
        let baselineMarkerMinY: Double
        var finalMarkerMinY: Double
        var maxMarkerMinYDrift = 0.0
        let beginPanState: String
        var finalPanState: String
        let beginBoundaryState: String
        var finalBoundaryState: String
        var sampleCount = 0
        var unavailableScrollSampleCount = 0
        var unavailableMarkerSampleCount = 0
        var omittedSampleCount = 0
        var finalTouchPointInMarker: Point?
        var finalTouchPointInWindow: Point?
        var finalTouchTimestamp: Double?
        var samples: [Sample] = []
    }

    private struct Sample: Encodable {
        let timestamp: Double
        let offset: Point
        let markerMinY: Double?
        let panState: String
        let boundaryState: String
    }

    private struct Point: Encodable {
        let x: Double
        let y: Double
        init(_ point: CGPoint) { x = Double(point.x); y = Double(point.y) }
    }

    private struct Rect: Encodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        init(_ rect: CGRect) {
            x = Double(rect.minX); y = Double(rect.minY)
            width = Double(rect.width); height = Double(rect.height)
        }
    }
}
#endif

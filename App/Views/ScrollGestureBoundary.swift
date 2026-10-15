import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

extension View {
    /// Touches beginning inside this control belong to the control for the
    /// complete touch sequence, rather than to an ancestor's scroll pan.
    func scrollGestureBoundary(identifier: String = "control") -> some View {
        modifier(ScrollGestureBoundaryModifier(identifier: identifier))
    }
}

private struct ScrollGestureBoundaryModifier: ViewModifier {
    let identifier: String

    func body(content: Content) -> some View {
        content.background {
            ScrollBoundaryMarker(identifier: identifier)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct ScrollBoundaryMarker: UIViewRepresentable {
    let identifier: String

    func makeCoordinator() -> ScrollBoundaryCoordinator { ScrollBoundaryCoordinator() }

    func makeUIView(context: Context) -> ScrollBoundaryMarkerView {
        let view = ScrollBoundaryMarkerView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.coordinator = context.coordinator
        context.coordinator.identifier = identifier
        context.coordinator.marker = view
        return view
    }

    func updateUIView(_ view: ScrollBoundaryMarkerView, context: Context) {
        view.coordinator = context.coordinator
        context.coordinator.identifier = identifier
        context.coordinator.marker = view
        context.coordinator.updateAttachment()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ScrollBoundaryMarkerView,
                      context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else { return nil }
        return CGSize(width: max(0, width), height: max(0, height))
    }

    static func dismantleUIView(_ view: ScrollBoundaryMarkerView, coordinator: ScrollBoundaryCoordinator) {
        view.coordinator = nil
        coordinator.detach()
        coordinator.marker = nil
    }
}

@MainActor
private final class ScrollBoundaryMarkerView: UIView {
    weak var coordinator: ScrollBoundaryCoordinator?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        coordinator?.updateAttachment()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        coordinator?.updateAttachment()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        coordinator?.updateAttachment()
    }
}

@MainActor
private final class ScrollBoundaryCoordinator: NSObject, UIGestureRecognizerDelegate {
    var identifier = "control"
    weak var marker: ScrollBoundaryMarkerView?
    private weak var scrollView: UIScrollView?
    private var recognizer: ImmediateControlTouchRecognizer?
    #if DEBUG
    private var auditID: UUID?
    #endif

    func updateAttachment() {
        guard let marker, marker.window != nil else {
            detach()
            return
        }
        var ancestor = marker.superview
        var containingScrollView: UIScrollView?
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                containingScrollView = scroll
                break
            }
            ancestor = view.superview
        }
        guard let containingScrollView else {
            detach()
            return
        }
        if scrollView === containingScrollView,
           recognizer?.view === containingScrollView { return }

        detach()
        let boundary = ImmediateControlTouchRecognizer(target: nil, action: nil)
        boundary.cancelsTouchesInView = false
        boundary.delaysTouchesBegan = false
        boundary.delaysTouchesEnded = false
        boundary.requiresExclusiveTouchType = false
        boundary.scrollPan = containingScrollView.panGestureRecognizer
        boundary.delegate = self
        #if DEBUG
        boundary.onAuditBegan = { [weak self] touch, recognizer in
            guard let self, let marker = self.marker, let scrollView = self.scrollView else { return }
            self.auditID = PhysicalScrollAudit.shared.begin(identifier: self.identifier,
                scrollView: scrollView, marker: marker, boundary: recognizer, touch: touch)
        }
        boundary.onAuditEnded = { [weak self] outcome, touch in
            guard let self, let auditID = self.auditID else { return }
            self.auditID = nil
            PhysicalScrollAudit.shared.end(auditID, outcome: outcome, finalTouch: touch)
        }
        #endif
        scrollView = containingScrollView
        recognizer = boundary
        containingScrollView.addGestureRecognizer(boundary)
        // The delegate establishes the failure requirement lazily for each
        // sequence. Reparenting never leaves a permanent require(toFail:) link.
    }

    func detach() {
        guard let recognizer else {
            scrollView = nil
            return
        }
        recognizer.endAttachment()
        recognizer.delegate = nil
        recognizer.scrollPan = nil
        recognizer.view?.removeGestureRecognizer(recognizer)
        self.recognizer = nil
        scrollView = nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let marker, let scrollView, marker.window === scrollView.window,
              !marker.isHidden, marker.alpha > 0.01, !marker.bounds.isEmpty,
              marker.bounds.contains(touch.location(in: marker)) else {
            // An unrelated scroll touch must not wait on a merely possible
            // recognizer whose delegate has declined the touch.
            recognizer?.rejectUnrelatedSequence()
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === recognizer && otherGestureRecognizer === scrollView?.panGestureRecognizer
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        otherGestureRecognizer !== scrollView?.panGestureRecognizer
    }
}

@MainActor
private final class ImmediateControlTouchRecognizer: UIGestureRecognizer {
    weak var scrollPan: UIGestureRecognizer?
    private var trackedTouches = Set<ObjectIdentifier>()
    #if DEBUG
    var onAuditBegan: ((UITouch, UIGestureRecognizer) -> Void)?
    var onAuditEnded: ((String, UITouch?) -> Void)?
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        trackedTouches.formUnion(touches.map { ObjectIdentifier($0) })
        if state == .possible {
            state = .began
            #if DEBUG
            if let touch = touches.min(by: { $0.timestamp < $1.timestamp }) {
                onAuditBegan?(touch, self)
            }
            #endif
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        trackedTouches.subtract(touches.map { ObjectIdentifier($0) })
        if trackedTouches.isEmpty, state == .began || state == .changed {
            state = .ended
            #if DEBUG
            onAuditEnded?("ended", touches.max(by: { $0.timestamp < $1.timestamp }))
            #endif
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        trackedTouches.removeAll()
        if state == .began || state == .changed { state = .cancelled }
        else if state == .possible { state = .failed }
        #if DEBUG
        onAuditEnded?("cancelled", touches.max(by: { $0.timestamp < $1.timestamp }))
        #endif
    }

    override func reset() {
        super.reset()
        trackedTouches.removeAll()
        #if DEBUG
        onAuditEnded?("reset", nil)
        #endif
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        preventedGestureRecognizer === scrollPan
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func rejectUnrelatedSequence() {
        if state == .possible { state = .failed }
    }

    func endAttachment() {
        if state == .began || state == .changed { state = .cancelled }
        else if state == .possible { state = .failed }
        trackedTouches.removeAll()
        #if DEBUG
        onAuditEnded?("detached", nil)
        #endif
    }
}

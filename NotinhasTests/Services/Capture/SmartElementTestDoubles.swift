//
//  SmartElementTestDoubles.swift
//  NotinhasTests
//
//  Shared fakes/spies for SmartElementQueryService tests so each test file
//  stays under the project's 200-LOC modularization threshold.
//

import AppKit
import Combine
import Foundation
@testable import Notinhas

final class FakeAXSnapshotProvider: AXSnapshotProviding {
    private var queue: [AXElementSnapshot?]

    init(snapshotForCall: [AXElementSnapshot?]) {
        queue = snapshotForCall
    }

    func snapshot(at _: CGPoint, pid _: Int32?) -> AXElementSnapshot? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
}

final class CountingAXSnapshotProvider: AXSnapshotProviding {
    private let snapshot: AXElementSnapshot?
    private(set) var callCount = 0

    init(snapshot: AXElementSnapshot?) {
        self.snapshot = snapshot
    }

    func snapshot(at _: CGPoint, pid _: Int32?) -> AXElementSnapshot? {
        callCount += 1
        return snapshot
    }
}

@MainActor
final class FakeSmartElementQueryProvider: SmartElementQueryProviding {
    let subject = PassthroughSubject<CGRect?, Never>()
    var permissionGranted = true
    private(set) var updatedPIDs: [Int32?] = []
    private(set) var cancelCount = 0

    var elementDetectedPublisher: AnyPublisher<CGRect?, Never> {
        subject.eraseToAnyPublisher()
    }

    func updateMouseLocation(pid: Int32?) {
        updatedPIDs.append(pid)
    }

    func cancelPendingQueries() {
        cancelCount += 1
        subject.send(nil)
    }

    func ensureAccessibilityPermission() -> Bool {
        permissionGranted
    }
}

final class FakeWindowOwnerResolver: SmartElementWindowOwnerResolving {
    var owner: SmartElementWindowOwner?
    private(set) var points: [CGPoint] = []

    func resolveOwner(at point: CGPoint) -> SmartElementWindowOwner? {
        points.append(point)
        return owner
    }
}

@MainActor
final class FakeSmartElementCapturePerformer: SmartElementCapturePerforming {
    private(set) var capturedRects: [CGRect] = []

    func captureRect(_ rect: CGRect) async {
        capturedRects.append(rect)
    }
}

@MainActor
final class FakeSmartElementOverlayWindow: SmartElementOverlayWindowProviding {
    var displayID: CGDirectDisplayID?
    var frame: CGRect
    var currentHighlightRect: CGRect?
    weak var eventDelegate: SmartElementOverlayWindowDelegate?
    private(set) var highlightedRects: [CGRect?] = []
    private(set) var didOrderFront = false
    private(set) var didClose = false

    init(displayID: CGDirectDisplayID?, frame: CGRect) {
        self.displayID = displayID
        self.frame = frame
    }

    func setFrame(_ frameRect: NSRect, display _: Bool) {
        frame = frameRect
    }

    func orderFrontRegardless() {
        didOrderFront = true
    }

    func orderOut(_: Any?) {}

    func close() {
        didClose = true
    }

    func makeKey() {}

    func makeFirstResponder(_: NSResponder?) -> Bool {
        true
    }

    func updateBounds(_: CGRect) {}

    func updateHighlight(_ rect: CGRect?) {
        currentHighlightRect = rect
        highlightedRects.append(rect)
    }
}

struct FakeSmartElementWindowListSource: SmartElementWindowListSource {
    let windows: [[String: Any]]

    func copyOnScreenWindowInfo() -> [[String: Any]] {
        windows
    }
}

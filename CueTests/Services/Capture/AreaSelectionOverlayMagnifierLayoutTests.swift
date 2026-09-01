//
//  AreaSelectionOverlayMagnifierLayoutTests.swift
//  NotinhasTests
//
//  Unit tests for magnifier layout and rendering: corner-flip positioning,
//  contentsRect centering, overlay-setting compatibility, and empty-backdrop fallback.
//

import AppKit
@testable import Cue
import XCTest

@MainActor
final class AreaSelectionOverlayMagnifierLayoutTests: AreaSelectionOverlayTestCase {
    func testMagnifierZoom_flipsNearCorners() throws {
        // GIVEN: A valid backdrop
        let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
        let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
        overlayView.applyBackdrop(backdrop)

        // Set zoom manually to 5x to trigger magnifier setup
        overlayView.testScrollWheel(deltaY: 4.0, modifierFlags: .command)

        // WHEN: Cursor is near bottom-left (10, 10)
        try overlayView.mouseMoved(with: XCTUnwrap(NSEvent.mouseEvent(
            with: .mouseMoved,
            location: CGPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0,
        )))

        // THEN: Magnifier is placed at top-right (x = 10 + 20 = 30)
        guard let containerLayer = overlayView.testMagnifierContainerLayer else {
            XCTFail("magnifierContainerLayer not found")
            return
        }
        XCTAssertEqual(containerLayer.frame.origin.x, 30.0)

        // WHEN: Cursor is near top-right (790, 590) - screen bounds 800x600
        try overlayView.mouseMoved(with: XCTUnwrap(NSEvent.mouseEvent(
            with: .mouseMoved,
            location: CGPoint(x: 790, y: 590),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0,
        )))

        // THEN: Magnifier flips to top-left/bottom
        // originX = 790 - gap (20) - size (130) = 640
        // originY = 590 - gap (20) - size (130) = 440
        XCTAssertEqual(containerLayer.frame.origin.x, 640.0)
        XCTAssertEqual(containerLayer.frame.origin.y, 440.0)
    }

    func testMagnifierZoom_worksWithShowSelectionAreaOverlaySetting() throws {
        let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
        let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)

        // 1. GIVEN: Show selection area overlay is ON (true)
        UserDefaults.standard.set(true, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
        overlayView.clearBackdrop()
        overlayView.applyBackdrop(backdrop)

        // WHEN: Zooming
        overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)

        // THEN: Zoom works and magnifier container layer is shown
        XCTAssertGreaterThan(overlayView.testMagnifierZoom, 1.0)
        XCTAssertNotNil(overlayView.testMagnifierContainerLayer)
        XCTAssertFalse(try XCTUnwrap(overlayView.testMagnifierContainerLayer?.isHidden))

        // 2. GIVEN: Show selection area overlay is OFF (false)
        UserDefaults.standard.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
        overlayView.clearBackdrop()
        overlayView.applyBackdrop(backdrop)

        // WHEN: Zooming
        overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)

        // THEN: Zoom works and magnifier container layer is shown
        XCTAssertGreaterThan(overlayView.testMagnifierZoom, 1.0)
        XCTAssertNotNil(overlayView.testMagnifierContainerLayer)
        XCTAssertFalse(try XCTUnwrap(overlayView.testMagnifierContainerLayer?.isHidden))
    }

    func testMagnifierZoom_contentsRectCenteredOnCursor() throws {
        let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
        let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
        overlayView.applyBackdrop(backdrop)

        // Set zoom manually to 5x to trigger magnifier setup
        overlayView.testScrollWheel(deltaY: 4.0, modifierFlags: .command)

        // Move cursor to (200, 150)
        try overlayView.mouseMoved(with: XCTUnwrap(NSEvent.mouseEvent(
            with: .mouseMoved,
            location: CGPoint(x: 200, y: 150),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0,
        )))

        guard let imgLayer = overlayView.testMagnifierImageLayer else {
            XCTFail("magnifierImageLayer not found")
            return
        }

        let contentsRect = imgLayer.contentsRect
        let centerX = contentsRect.origin.x + contentsRect.size.width / 2.0
        let centerY = contentsRect.origin.y + contentsRect.size.height / 2.0

        XCTAssertEqual(centerX, 0.25, accuracy: 1e-5)
        XCTAssertEqual(centerY, 0.25, accuracy: 1e-5)
    }

    func testMagnifierZoom_worksWithEmptyBackdropsInitially() {
        let controller = AreaSelectionController.shared
        let capturer = RecordingAreaSelectionBackdropCapturer()
        controller.setBackdropCapturerForTesting(capturer)
        defer {
            controller.cancelSelection()
            controller.resetBackdropCapturerForTesting()
        }

        // GIVEN: backdrop-less session — controller must request a capturer (synthetic under XCTest)
        let expectation = XCTestExpectation(description: "Synthetic backdrop applied via capturer seam")

        controller.startSelection(mode: .recording) { _, _ in }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertGreaterThanOrEqual(capturer.callCount, 1, "empty-backdrop session must invoke capturer")

            let targetDisplayID = ScreenUtility.activeDisplayID()
            let mirror = Mirror(reflecting: controller)
            if let pool = mirror.children.first(where: { $0.label == "windowPool" })?
                .value as? [CGDirectDisplayID: AreaSelectionWindow],
                let window = pool[targetDisplayID] {
                XCTAssertNotNil(window.overlayView.testSnapshotLayer.contents)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }
}

/// Counts capturer calls while forwarding to the synthetic (TCC-free) implementation.
private final class RecordingAreaSelectionBackdropCapturer: AreaSelectionBackdropCapturing, @unchecked Sendable {
    private let lock = NSLock()
    private let inner = SyntheticAreaSelectionBackdropCapturer()
    private(set) var callCount = 0

    func captureBackdrop(
        displayID: CGDirectDisplayID,
        captureRect: CGRect,
        scaleFactor: CGFloat,
        isVisible: Bool,
    ) async -> AreaSelectionBackdrop? {
        recordCapture()
        return await inner.captureBackdrop(
            displayID: displayID,
            captureRect: captureRect,
            scaleFactor: scaleFactor,
            isVisible: isVisible,
        )
    }

    private func recordCapture() {
        lock.lock()
        callCount += 1
        lock.unlock()
    }
}

//
//  CaptureFloatingToolbarPlacementTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureFloatingToolbarPlacementTests: XCTestCase {
    func testCaptureFloatingToolbarPlacement_usesOutsideGapWhenBelowSelectionFits() {
        let toolbarSize = CGSize(width: 240, height: 44)
        let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let selectionRect = CGRect(x: 300, y: 220, width: 400, height: 300)

        let origin = CaptureFloatingToolbarPlacement.frameOrigin(
            toolbarSize: toolbarSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertEqual(origin.x, selectionRect.midX - toolbarSize.width / 2)
        XCTAssertEqual(
            origin.y,
            selectionRect.minY - toolbarSize.height - CaptureFloatingToolbarPlacement.outsideSelectionGap,
        )
    }

    func testCaptureFloatingToolbarPlacement_usesInsideBottomInsetNearScreenBottom() {
        let toolbarSize = CGSize(width: 240, height: 44)
        let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let selectionRect = CGRect(x: 300, y: 24, width: 400, height: 300)

        let origin = CaptureFloatingToolbarPlacement.frameOrigin(
            toolbarSize: toolbarSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertEqual(
            origin.y,
            selectionRect.minY + CaptureFloatingToolbarPlacement.insideSelectionBottomInset,
        )
    }

    func testCaptureFloatingToolbarPlacement_clampsInsideInsetToVisibleScreen() {
        let toolbarSize = CGSize(width: 240, height: 44)
        let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 100)
        let selectionRect = CGRect(x: 300, y: 24, width: 400, height: 60)

        let origin = CaptureFloatingToolbarPlacement.frameOrigin(
            toolbarSize: toolbarSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertEqual(
            origin.y,
            screenFrame.maxY - toolbarSize.height - CaptureFloatingToolbarPlacement.screenEdgeInset,
        )
    }

    func testCaptureFloatingToolbarPlacement_keepsOversizedToolbarAtVisibleOrigin() {
        let toolbarSize = CGSize(width: 1400, height: 1000)
        let screenFrame = CGRect(x: 200, y: 100, width: 1200, height: 900)
        let selectionRect = CGRect(x: 500, y: 400, width: 200, height: 200)

        let origin = CaptureFloatingToolbarPlacement.frameOrigin(
            toolbarSize: toolbarSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertEqual(origin.x, screenFrame.minX + CaptureFloatingToolbarPlacement.screenEdgeInset)
        XCTAssertEqual(origin.y, screenFrame.minY + CaptureFloatingToolbarPlacement.screenEdgeInset)
    }

    func testPairedFrameOrigins_placesPairBelowSelectionWithGap() {
        let leadingSize = CGSize(width: 320, height: 58)
        let trailingSize = CGSize(width: 200, height: 58)
        let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let selectionRect = CGRect(x: 300, y: 220, width: 400, height: 300)
        let pairHeight = max(leadingSize.height, trailingSize.height)
        let pairWidth = leadingSize.width + CaptureFloatingToolbarPlacement.interToolbarGap + trailingSize.width

        let origins = CaptureFloatingToolbarPlacement.pairedFrameOrigins(
            leadingSize: leadingSize,
            trailingSize: trailingSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertEqual(
            origins.leading.y,
            selectionRect.minY - pairHeight - CaptureFloatingToolbarPlacement.outsideSelectionGap,
        )
        XCTAssertEqual(origins.leading.x, selectionRect.midX - pairWidth / 2)
        XCTAssertEqual(
            origins.trailing?.x,
            origins.leading.x + leadingSize.width + CaptureFloatingToolbarPlacement.interToolbarGap,
        )
        XCTAssertEqual(origins.trailing?.y, origins.leading.y)
    }

    func testPairedFrameOrigins_trailingNilMatchesSinglePlacement() {
        let leadingSize = CGSize(width: 240, height: 44)
        let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let selectionRect = CGRect(x: 300, y: 220, width: 400, height: 300)

        let origins = CaptureFloatingToolbarPlacement.pairedFrameOrigins(
            leadingSize: leadingSize,
            trailingSize: nil,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        let expected = CaptureFloatingToolbarPlacement.frameOrigin(
            toolbarSize: leadingSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertNil(origins.trailing)
        XCTAssertEqual(origins.leading, expected)
    }

    func testPairedFrameOrigins_clampsPairNearTrailingScreenEdge() throws {
        let leadingSize = CGSize(width: 320, height: 58)
        let trailingSize = CGSize(width: 200, height: 58)
        let screenFrame = CGRect(x: 0, y: 0, width: 600, height: 900)
        let selectionRect = CGRect(x: 420, y: 220, width: 160, height: 300)

        let origins = CaptureFloatingToolbarPlacement.pairedFrameOrigins(
            leadingSize: leadingSize,
            trailingSize: trailingSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertGreaterThanOrEqual(
            origins.leading.x,
            screenFrame.minX + CaptureFloatingToolbarPlacement.screenEdgeInset,
        )
        XCTAssertEqual(
            origins.trailing?.x,
            origins.leading.x + leadingSize.width + CaptureFloatingToolbarPlacement.interToolbarGap,
        )
        XCTAssertGreaterThan(try XCTUnwrap(origins.trailing?.x), origins.leading.x)
    }

    func testPairedFrameOrigins_pinsOversizedPairLeadingEdge() throws {
        let leadingSize = CGSize(width: 500, height: 58)
        let trailingSize = CGSize(width: 400, height: 58)
        let screenFrame = CGRect(x: 0, y: 0, width: 600, height: 900)
        let selectionRect = CGRect(x: 200, y: 220, width: 200, height: 300)

        let origins = CaptureFloatingToolbarPlacement.pairedFrameOrigins(
            leadingSize: leadingSize,
            trailingSize: trailingSize,
            anchorRect: selectionRect,
            screenFrame: screenFrame,
        )

        XCTAssertEqual(
            origins.leading.x,
            screenFrame.minX + CaptureFloatingToolbarPlacement.screenEdgeInset,
        )
        XCTAssertEqual(
            origins.trailing?.x,
            origins.leading.x + leadingSize.width + CaptureFloatingToolbarPlacement.interToolbarGap,
        )
        XCTAssertGreaterThan(try XCTUnwrap(origins.trailing?.x), origins.leading.x)
    }
}

//
//  AreaSelectionOverlayBackdropTransitionTests.swift
//  NotinhasTests
//
//  Unit tests for the final visible and invisible backdrop state.
//

import AppKit
@testable import Notinhas
import XCTest

@MainActor
final class AreaSelectionOverlayBackdropTransitionTests: AreaSelectionOverlayTestCase {
    func testApplyBackdrop_visibleBackdropShowsLatestContents() {
        let image1 = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
        let backdrop1 = AreaSelectionBackdrop(displayID: 0, image: image1, scaleFactor: 1.0)
        overlayView.applyBackdrop(backdrop1)
        XCTAssertNotNil(overlayView.testSnapshotLayer.contents, "Backdrop must be cached after first apply")

        let image2 = createSolidColorImage(color: .black, size: CGSize(width: 800, height: 600))
        let backdrop2 = AreaSelectionBackdrop(displayID: 0, image: image2, scaleFactor: 1.0)
        overlayView.applyBackdrop(backdrop2)

        XCTAssertTrue(
            (overlayView.testSnapshotLayer.contents as AnyObject) === (image2 as AnyObject),
            "snapshotLayer.contents must be updated to the new image",
        )
        XCTAssertFalse(
            overlayView.testSnapshotLayer.isHidden,
            "Snapshot layer must remain visible for a visible backdrop",
        )
    }

    func testApplyBackdrop_invisibleBackdropStaysHidden() {
        let image1 = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
        let backdrop1 = AreaSelectionBackdrop(displayID: 0, image: image1, scaleFactor: 1.0, isVisible: false)
        overlayView.applyBackdrop(backdrop1)

        let image2 = createSolidColorImage(color: .gray, size: CGSize(width: 800, height: 600))
        let backdrop2 = AreaSelectionBackdrop(displayID: 0, image: image2, scaleFactor: 1.0, isVisible: false)
        overlayView.applyBackdrop(backdrop2)

        XCTAssertTrue(
            overlayView.testSnapshotLayer.isHidden,
            "Invisible backdrop must keep snapshotLayer hidden even on re-apply",
        )
    }
}

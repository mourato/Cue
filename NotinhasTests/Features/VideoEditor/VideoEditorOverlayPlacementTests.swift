#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorOverlayPlacementTests.swift
    //  NotinhasTests
//

    import CoreGraphics
    @testable import Notinhas
    import XCTest

    final class VideoEditorOverlayPlacementTests: XCTestCase {
        func testPointInContent_noZoom_mapsNormalizedDirectly() {
            let point = VideoEditorOverlayPlacement.pointInContent(
                CGPoint(x: 0.25, y: 0.75),
                contentSize: CGSize(width: 800, height: 600),
            )
            XCTAssertEqual(point.x, 200, accuracy: 0.01)
            XCTAssertEqual(point.y, 450, accuracy: 0.01)
        }

        func testPointInContent_zoom_centersAnchorPoint() {
            let center = VideoEditorOverlayPlacement.pointInContent(
                CGPoint(x: 0.5, y: 0.5),
                contentSize: CGSize(width: 800, height: 600),
                zoomLevel: 2,
                zoomCenter: CGPoint(x: 0.5, y: 0.5),
            )
            XCTAssertEqual(center.x, 400, accuracy: 0.01)
            XCTAssertEqual(center.y, 300, accuracy: 0.01)
        }

        func testPointInContent_zoom_shiftsOffCenterPoint() {
            let point = VideoEditorOverlayPlacement.pointInContent(
                CGPoint(x: 0.25, y: 0.25),
                contentSize: CGSize(width: 800, height: 600),
                zoomLevel: 2,
                zoomCenter: CGPoint(x: 0.5, y: 0.5),
            )
            XCTAssertEqual(point.x, 0, accuracy: 0.01)
            XCTAssertEqual(point.y, 0, accuracy: 0.01)
        }
    }
#endif

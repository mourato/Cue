#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorPointerArtworkTests.swift
    //  NotinhasTests
//

    import CoreGraphics
    @testable import Notinhas
    import XCTest

    @MainActor
    final class VideoEditorPointerArtworkTests: XCTestCase {
        func testCapture_defaultArrow_hasAnchorAndSize() {
            let artwork = RecordingPointerArtworkCapture.defaultArtwork()
            XCTAssertNotNil(artwork)
            XCTAssertFalse(try XCTUnwrap(artwork?.imageData).isEmpty)
            XCTAssertGreaterThan(try XCTUnwrap(artwork?.referenceSize.width), 0)
            XCTAssertGreaterThan(try XCTUnwrap(artwork?.referenceSize.height), 0)
        }

        func testNormalizedAnchor_isWithinZeroAndOne() {
            guard let artwork = RecordingPointerArtworkCapture.defaultArtwork() else {
                XCTFail("missing artwork")
                return
            }
            let anchor = artwork.normalizedAnchor
            XCTAssertGreaterThanOrEqual(anchor.x, 0)
            XCTAssertLessThanOrEqual(anchor.x, 1)
            XCTAssertGreaterThanOrEqual(anchor.y, 0)
            XCTAssertLessThanOrEqual(anchor.y, 1)
        }
    }
#endif

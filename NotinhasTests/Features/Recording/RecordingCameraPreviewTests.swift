#if NOTINHAS_VIDEO_MODULE
    @testable import Notinhas
    import XCTest

    final class RecordingCameraPreviewTests: XCTestCase {
        func testPlacementStaysInsideSelectionWithInset() {
            let selection = CGRect(x: 100, y: 200, width: 1200, height: 800)
            let preview = RecordingCameraPreviewPlacement.frame(in: selection)
            let safeBounds = selection.insetBy(
                dx: RecordingCameraPreviewPlacement.inset,
                dy: RecordingCameraPreviewPlacement.inset,
            )

            XCTAssertTrue(safeBounds.contains(preview))
        }

        func testPlacementUsesSixteenByNineAspectRatio() {
            let selection = CGRect(x: 0, y: 0, width: 1000, height: 600)
            let preview = RecordingCameraPreviewPlacement.frame(in: selection)

            XCTAssertEqual(preview.width / preview.height, 16 / 9, accuracy: 0.001)
        }

        func testPlacementFitsShortSelectionWithoutOverflow() {
            let selection = CGRect(x: 50, y: 80, width: 300, height: 130)
            let preview = RecordingCameraPreviewPlacement.frame(in: selection)

            XCTAssertTrue(selection.contains(preview))
            XCTAssertGreaterThan(preview.width, 0)
            XCTAssertGreaterThan(preview.height, 0)
        }
    }
#endif

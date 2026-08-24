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

        func testPlacementSupportsEveryPreviewShape() {
            let selection = CGRect(x: 0, y: 0, width: 1200, height: 800)

            for shape in RecordingCameraPreviewShape.allCases {
                let preview = RecordingCameraPreviewPlacement.frame(
                    in: selection,
                    configuration: RecordingCameraPreviewConfiguration(shape: shape),
                )

                XCTAssertTrue(selection.insetBy(dx: 16, dy: 16).contains(preview))
                XCTAssertEqual(
                    preview.width / preview.height,
                    shape == .vertical ? 9 / 16 : shape == .rectangle ? 16 / 9 : 1,
                    accuracy: 0.001,
                )
            }
        }

        func testPlacementSizePresetsGrowWithinTheSelection() {
            let selection = CGRect(x: 0, y: 0, width: 1600, height: 900)
            let widths = RecordingCameraPreviewSize.allCases.map { size in
                RecordingCameraPreviewPlacement.frame(
                    in: selection,
                    configuration: RecordingCameraPreviewConfiguration(size: size),
                ).width
            }

            XCTAssertEqual(widths, widths.sorted())
            XCTAssertGreaterThan(widths.last ?? 0, widths.first ?? 0)
        }

        func testClampedOriginKeepsDraggedPreviewInsideSelection() {
            let selection = CGRect(x: 100, y: 200, width: 1200, height: 800)
            let origin = RecordingCameraPreviewPlacement.clampedOrigin(
                CGPoint(x: -500, y: 5000),
                size: CGSize(width: 240, height: 135),
                in: selection,
            )

            XCTAssertEqual(origin.x, selection.minX + 16)
            XCTAssertEqual(origin.y, selection.maxY - 16 - 135)
        }

        func testNormalizedCenterRestoresSessionPosition() {
            let selection = CGRect(x: 100, y: 200, width: 1200, height: 800)
            let configuration = RecordingCameraPreviewConfiguration(
                size: .medium,
                shape: .square,
            )
            let preview = RecordingCameraPreviewPlacement.frame(
                in: selection,
                configuration: configuration,
                normalizedCenter: CGPoint(x: 0.25, y: 0.75),
            )

            XCTAssertEqual((preview.midX - selection.minX) / selection.width, 0.25, accuracy: 0.001)
            XCTAssertEqual((preview.midY - selection.minY) / selection.height, 0.75, accuracy: 0.001)
        }
    }
#endif

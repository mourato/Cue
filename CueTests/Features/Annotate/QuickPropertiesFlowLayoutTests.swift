import CoreGraphics
@testable import Cue
import XCTest

final class QuickPropertiesFlowLayoutTests: XCTestCase {
    func testSingleRowFitsWithinMaxWidth() {
        let items = [
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 30, height: 24), isRowLeadingDivider: false),
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 180, height: 24), isRowLeadingDivider: false),
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 190, height: 24), isRowLeadingDivider: false),
        ]

        let result = QuickPropertiesFlowLayoutEngine.layout(
            items: items,
            maxWidth: 500,
            horizontalSpacing: 12,
            verticalSpacing: 12,
        )

        XCTAssertEqual(result.size.width, 424, accuracy: 0.001)
        XCTAssertEqual(result.size.height, 24, accuracy: 0.001)
        XCTAssertTrue(result.skippedDividerIndices.isEmpty)
        XCTAssertEqual(result.placements[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(result.placements[1], CGPoint(x: 42, y: 0))
        XCTAssertEqual(result.placements[2], CGPoint(x: 234, y: 0))
    }

    func testWrapsToSecondRowWhenControlsOverflow() {
        let items = [
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 30, height: 24), isRowLeadingDivider: false),
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 180, height: 24), isRowLeadingDivider: false),
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 190, height: 24), isRowLeadingDivider: false),
        ]

        let result = QuickPropertiesFlowLayoutEngine.layout(
            items: items,
            maxWidth: 300,
            horizontalSpacing: 12,
            verticalSpacing: 8,
        )

        XCTAssertEqual(result.size.width, 222, accuracy: 0.001)
        XCTAssertEqual(result.size.height, 56, accuracy: 0.001)
        XCTAssertEqual(result.placements[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(result.placements[1], CGPoint(x: 42, y: 0))
        XCTAssertEqual(result.placements[2], CGPoint(x: 0, y: 32))
    }

    func testSkipsLeadingDividerAtStartOfWrappedRow() {
        let items = [
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 250, height: 24), isRowLeadingDivider: false),
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 1, height: 24), isRowLeadingDivider: true),
            QuickPropertiesFlowLayoutItem(size: CGSize(width: 100, height: 24), isRowLeadingDivider: false),
        ]

        let result = QuickPropertiesFlowLayoutEngine.layout(
            items: items,
            maxWidth: 260,
            horizontalSpacing: 12,
            verticalSpacing: 8,
        )

        XCTAssertEqual(result.skippedDividerIndices, [1])
        XCTAssertEqual(result.placements[2], CGPoint(x: 0, y: 32))
        XCTAssertEqual(result.size.height, 56, accuracy: 0.001)
    }
}

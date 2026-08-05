//
//  CaptureSelectionGeometryTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureSelectionGeometryTests: XCTestCase {
    func testNormalized_standardizesNegativeExtents() {
        let rect = CGRect(x: 100, y: 100, width: -80, height: -60)

        let normalized = CaptureSelectionGeometry.normalized(rect)

        XCTAssertEqual(normalized.origin, CGPoint(x: 20, y: 40))
        XCTAssertEqual(normalized.size, CGSize(width: 80, height: 60))
    }

    func testNormalized_clampsDegenerateDimensionsToMinimum() {
        let rect = CGRect(x: 10, y: 20, width: 0.2, height: 0.3)

        let normalized = CaptureSelectionGeometry.normalized(rect)

        XCTAssertEqual(normalized.width, CaptureSelectionGeometry.defaultMinSize)
        XCTAssertEqual(normalized.height, CaptureSelectionGeometry.defaultMinSize)
    }

    func testResizedRect_freeCornerResizeExpandsBottomRight() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 100)

        let resized = CaptureSelectionGeometry.resizedRect(
            original: original,
            handle: .bottomRight,
            translation: CGPoint(x: 40, y: -30),
            aspectLocked: false,
            aspectRatio: nil,
        )

        XCTAssertEqual(resized.origin, CGPoint(x: 100, y: 70))
        XCTAssertEqual(resized.size, CGSize(width: 240, height: 130))
    }

    func testResizedRect_lockedCornerResizeMaintainsAspectRatio() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 100)
        let ratio: CGFloat = 2

        let resized = CaptureSelectionGeometry.resizedRect(
            original: original,
            handle: .bottomRight,
            translation: CGPoint(x: 40, y: -30),
            aspectLocked: true,
            aspectRatio: ratio,
        )

        XCTAssertEqual(resized.width / resized.height, ratio, accuracy: 0.001)
        XCTAssertEqual(resized.origin.x, original.origin.x)
        XCTAssertEqual(resized.maxY, original.maxY, accuracy: 0.001)
    }

    func testRectBySettingWidth_lockedUpdatesHeightFromRatio() {
        let rect = CGRect(x: 50, y: 80, width: 200, height: 100)
        let ratio: CGFloat = 2

        let updated = CaptureSelectionGeometry.rectBySettingWidth(
            rect,
            width: 300,
            aspectLocked: true,
            aspectRatio: ratio,
        )

        XCTAssertEqual(updated.width, 300)
        XCTAssertEqual(updated.height, 150, accuracy: 0.001)
        XCTAssertEqual(updated.midX, rect.midX, accuracy: 0.001)
        XCTAssertEqual(updated.midY, rect.midY, accuracy: 0.001)
    }

    func testRectBySettingHeight_lockedUpdatesWidthFromRatio() {
        let rect = CGRect(x: 50, y: 80, width: 200, height: 100)
        let ratio: CGFloat = 2

        let updated = CaptureSelectionGeometry.rectBySettingHeight(
            rect,
            height: 50,
            aspectLocked: true,
            aspectRatio: ratio,
        )

        XCTAssertEqual(updated.height, 50)
        XCTAssertEqual(updated.width, 100, accuracy: 0.001)
        XCTAssertEqual(updated.midX, rect.midX, accuracy: 0.001)
        XCTAssertEqual(updated.midY, rect.midY, accuracy: 0.001)
    }

    func testRectBySettingWidth_unlockedPreservesHeight() {
        let rect = CGRect(x: 50, y: 80, width: 200, height: 100)

        let updated = CaptureSelectionGeometry.rectBySettingWidth(
            rect,
            width: 320,
            aspectLocked: false,
            aspectRatio: nil,
        )

        XCTAssertEqual(updated.width, 320)
        XCTAssertEqual(updated.height, 100)
    }

    func testResizedRect_lockedTopKeepsBottomEdgeFixed() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 100)

        let resized = CaptureSelectionGeometry.resizedRect(
            original: original,
            handle: .top,
            translation: CGPoint(x: 0, y: 40),
            aspectLocked: true,
            aspectRatio: 2,
        )

        XCTAssertEqual(resized.minY, original.minY, accuracy: 0.001)
        XCTAssertEqual(resized.width / resized.height, 2, accuracy: 0.001)
    }

    func testResizedRect_lockedBottomKeepsTopEdgeFixed() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 100)

        let resized = CaptureSelectionGeometry.resizedRect(
            original: original,
            handle: .bottom,
            translation: CGPoint(x: 0, y: -40),
            aspectLocked: true,
            aspectRatio: 2,
        )

        XCTAssertEqual(resized.maxY, original.maxY, accuracy: 0.001)
        XCTAssertEqual(resized.width / resized.height, 2, accuracy: 0.001)
    }
}

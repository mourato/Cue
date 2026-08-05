//
//  CaptureSelectionChromeTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureSelectionChromeTests: XCTestCase {
    private let rect = CGRect(x: 100, y: 100, width: 200, height: 120)
    private let hitSize = CaptureSelectionChromeMetrics.handleHitSize
    private let cornerLength = CaptureSelectionChromeMetrics.cornerHandleLength
    private let edgeLength = CaptureSelectionChromeMetrics.edgeHandleLength
    private let thickness = CaptureSelectionChromeMetrics.handleThickness

    // MARK: - Hit geometry (Recording / AppKit convention)

    func testHitGeometry_mapsTopLeftCorner() {
        let topLeft = CGPoint(x: rect.minX, y: rect.maxY)
        XCTAssertEqual(
            CaptureSelectionHandleGeometry.handle(at: topLeft, in: rect, hitSize: hitSize),
            .topLeft,
        )
    }

    func testHitGeometry_hitRectsAreNonEmptyForAllHandles() {
        for handle in CaptureSelectionHandleGeometry.allHandles {
            let hitRect = CaptureSelectionHandleGeometry.hitRect(for: handle, in: rect, hitSize: hitSize)
            XCTAssertFalse(hitRect.isEmpty, "Expected non-empty hit rect for \(handle)")
        }
    }

    func testHitGeometry_topEdgeSpansBetweenCorners() {
        let topEdgePoint = CGPoint(x: rect.minX + 40, y: rect.maxY)
        XCTAssertEqual(
            CaptureSelectionHandleGeometry.handle(at: topEdgePoint, in: rect, hitSize: hitSize),
            .top,
        )

        let topHit = CaptureSelectionHandleGeometry.hitRect(for: .top, in: rect, hitSize: hitSize)
        XCTAssertEqual(topHit.minX, rect.minX + hitSize)
        XCTAssertEqual(topHit.width, rect.width - hitSize * 2)
        XCTAssertTrue(topHit.contains(topEdgePoint))
    }

    // MARK: - Corner L-bar rects (AppKit convention)

    func testCornerHandleBars_topLeftMatchesRecordingMath() {
        let anchor = CGPoint(x: rect.minX, y: rect.maxY)
        let bars = CaptureSelectionHandleGeometry.cornerHandleBars(
            for: .topLeft,
            anchor: anchor,
            metrics: (cornerLength: cornerLength, thickness: thickness),
        )

        let halfThickness = thickness / 2
        XCTAssertEqual(
            bars.horizontal,
            CGRect(
                x: anchor.x - halfThickness,
                y: anchor.y - halfThickness,
                width: cornerLength,
                height: thickness,
            ),
        )
        XCTAssertEqual(
            bars.vertical,
            CGRect(
                x: anchor.x - halfThickness,
                y: anchor.y - cornerLength + halfThickness,
                width: thickness,
                height: cornerLength,
            ),
        )
    }

    func testCornerHandleBars_bottomRightMatchesRecordingMath() {
        let anchor = CGPoint(x: rect.maxX, y: rect.minY)
        let bars = CaptureSelectionHandleGeometry.cornerHandleBars(
            for: .bottomRight,
            anchor: anchor,
            metrics: (cornerLength: cornerLength, thickness: thickness),
        )

        let halfThickness = thickness / 2
        XCTAssertEqual(
            bars.horizontal,
            CGRect(
                x: anchor.x - cornerLength + halfThickness,
                y: anchor.y - halfThickness,
                width: cornerLength,
                height: thickness,
            ),
        )
        XCTAssertEqual(
            bars.vertical,
            CGRect(
                x: anchor.x - halfThickness,
                y: anchor.y - halfThickness,
                width: thickness,
                height: cornerLength,
            ),
        )
    }

    // MARK: - Edge handle bar rects (AppKit convention)

    func testEdgeHandleBar_topMatchesRecordingMath() {
        let anchor = CGPoint(x: rect.midX, y: rect.maxY)
        let bar = CaptureSelectionHandleGeometry.edgeHandleBar(
            for: .top,
            anchor: anchor,
            metrics: (edgeLength: edgeLength, thickness: thickness),
        )

        let halfLength = edgeLength / 2
        let halfThickness = thickness / 2
        XCTAssertEqual(
            bar,
            CGRect(
                x: anchor.x - halfLength,
                y: anchor.y - halfThickness,
                width: edgeLength,
                height: thickness,
            ),
        )
    }

    func testEdgeHandleBar_leftMatchesRecordingMath() {
        let anchor = CGPoint(x: rect.minX, y: rect.midY)
        let bar = CaptureSelectionHandleGeometry.edgeHandleBar(
            for: .left,
            anchor: anchor,
            metrics: (edgeLength: edgeLength, thickness: thickness),
        )

        let halfLength = edgeLength / 2
        let halfThickness = thickness / 2
        XCTAssertEqual(
            bar,
            CGRect(
                x: anchor.x - halfThickness,
                y: anchor.y - halfLength,
                width: thickness,
                height: edgeLength,
            ),
        )
    }

    // MARK: - SwiftUI coordinate space

    func testHitGeometry_topLeftOrigin_mapsCornerAtMinY() {
        let localRect = CGRect(x: 0, y: 0, width: 200, height: 120)
        let topLeft = CGPoint(x: 0, y: 0)
        XCTAssertEqual(
            CaptureSelectionHandleGeometry.handle(
                at: topLeft,
                in: localRect,
                hitSize: hitSize,
                coordinateSpace: .topLeftOrigin,
            ),
            .topLeft,
        )
    }

    func testCornerHandleBars_topLeftOrigin_matchesRecordingCenteredLayout() {
        let anchor = CGPoint(x: 0, y: 0)
        let bars = CaptureSelectionHandleGeometry.cornerHandleBars(
            for: .topLeft,
            anchor: anchor,
            metrics: (cornerLength: cornerLength, thickness: thickness),
            coordinateSpace: .topLeftOrigin,
        )

        let halfThickness = thickness / 2
        XCTAssertEqual(
            bars.horizontal,
            CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: cornerLength, height: thickness),
        )
        XCTAssertEqual(
            bars.vertical,
            CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: thickness, height: cornerLength),
        )
    }

    func testHandleBars_largeRectangleAreSharedAcrossCoordinateSpaces() {
        let bottomLeftBars = CaptureSelectionHandleGeometry.handleBars(
            in: rect,
            coordinateSpace: .bottomLeftOrigin,
        )
        let topLeftBars = CaptureSelectionHandleGeometry.handleBars(
            in: CGRect(origin: .zero, size: rect.size),
            coordinateSpace: .topLeftOrigin,
        )

        XCTAssertEqual(bottomLeftBars.count, 12)
        XCTAssertEqual(topLeftBars.count, 12)
        XCTAssertEqual(
            bottomLeftBars.map { CGSize(width: $0.width, height: $0.height) },
            topLeftBars.map { CGSize(width: $0.width, height: $0.height) },
        )
    }

    func testHandleStyle_usesRoundedEndsAndCoordinateAwareShadow() {
        XCTAssertEqual(
            CaptureSelectionChromeMetrics.handleCornerRadius,
            CaptureSelectionChromeMetrics.handleThickness / 2,
        )
        XCTAssertEqual(
            CaptureSelectionChromeMetrics.handleShadowOffset(for: .bottomLeftOrigin),
            CGSize(width: 0, height: -1),
        )
        XCTAssertEqual(
            CaptureSelectionChromeMetrics.handleShadowOffset(for: .topLeftOrigin),
            CGSize(width: 0, height: 1),
        )
    }

    // MARK: - Adaptive layout

    func testLayout_largeRectangle_keepsAllHandlesAndDefaultMetrics() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 120)
        let layout = CaptureSelectionChromeLayout.layout(for: rect)

        XCTAssertEqual(layout.cornerLength, cornerLength)
        XCTAssertEqual(layout.edgeLength, edgeLength)
        XCTAssertEqual(layout.availableHandles, Set(CaptureSelectionResizeHandle.allCases))
    }

    func testLayout_compactRectangle_suppressesEdgeHandles() {
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        let layout = CaptureSelectionChromeLayout.layout(for: rect)

        XCTAssertTrue(layout.availableHandles.contains(.topLeft))
        XCTAssertFalse(layout.availableHandles.contains(.top))
        XCTAssertFalse(layout.availableHandles.contains(.left))
    }

    func testHitGeometry_cornerWinsOverEdgeAtSharedAnchor() {
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        let layout = CaptureSelectionChromeLayout.layout(for: rect)
        let cornerPoint = CGPoint(x: rect.minX, y: rect.minY)

        XCTAssertEqual(
            CaptureSelectionHandleGeometry.handle(
                at: cornerPoint,
                in: rect,
                hitSize: hitSize,
                coordinateSpace: .topLeftOrigin,
                layout: layout,
            ),
            .topLeft,
        )
    }

    func testConfirmedResize_clampsAtSharedMinimum() {
        let original = CGRect(x: 0, y: 0, width: 80, height: 80)
        let resized = CaptureSelectionGeometry.resizedRect(
            original: original,
            handle: .right,
            translation: CGPoint(x: -60, y: 0),
            aspectLocked: false,
            aspectRatio: nil,
            minSize: CaptureSelectionChromeMetrics.confirmedMinimumSize,
        )

        XCTAssertEqual(resized.width, CaptureSelectionChromeMetrics.confirmedMinimumSize, accuracy: 0.001)
    }

    func testConfirmedArea_normalizesTinyInitialRectToSharedMinimum() {
        let confirmed = CaptureSelectionGeometry.normalized(
            CGRect(x: 10, y: 20, width: 6, height: 8),
            minSize: CaptureSelectionChromeMetrics.confirmedMinimumSize,
        )

        XCTAssertEqual(confirmed.width, CaptureSelectionChromeMetrics.confirmedMinimumSize)
        XCTAssertEqual(confirmed.height, CaptureSelectionChromeMetrics.confirmedMinimumSize)
    }
}

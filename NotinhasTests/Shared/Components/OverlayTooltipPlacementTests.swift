import CoreGraphics
@testable import Notinhas
import XCTest

final class OverlayTooltipPlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 120, height: 40)

    func testBelowPlacesTooltipUnderAnchorWhenItFits() {
        let anchor = CGRect(x: 400, y: 700, width: 40, height: 28) // near top
        let frame = OverlayTooltipPlacement.frame(
            anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .below,
        )
        // "below" = lower y = anchor.minY - gap - height
        XCTAssertEqual(frame.origin.y, 700 - OverlayTooltipPlacement.gap - 40, accuracy: 0.001)
        // horizontally centered on the anchor
        XCTAssertEqual(frame.midX, anchor.midX, accuracy: 0.001)
    }

    func testBelowFlipsToAboveWhenNoRoomUnderAnchor() {
        let anchor = CGRect(x: 400, y: 10, width: 40, height: 28) // near bottom
        let frame = OverlayTooltipPlacement.frame(
            anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .below,
        )
        // flipped: "above" = anchor.maxY + gap
        XCTAssertEqual(frame.origin.y, anchor.maxY + OverlayTooltipPlacement.gap, accuracy: 0.001)
    }

    func testAbovePlacesTooltipOverAnchorWhenItFits() {
        let anchor = CGRect(x: 400, y: 100, width: 40, height: 28)
        let frame = OverlayTooltipPlacement.frame(
            anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .above,
        )
        XCTAssertEqual(frame.origin.y, anchor.maxY + OverlayTooltipPlacement.gap, accuracy: 0.001)
    }

    func testHorizontalClampKeepsTooltipOnScreen() {
        let anchor = CGRect(x: 980, y: 400, width: 20, height: 20) // far right
        let frame = OverlayTooltipPlacement.frame(
            anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .below,
        )
        XCTAssertLessThanOrEqual(
            frame.maxX,
            screen.maxX - OverlayTooltipPlacement.screenMargin + 0.001,
        )
        XCTAssertGreaterThanOrEqual(
            frame.minX,
            screen.minX + OverlayTooltipPlacement.screenMargin - 0.001,
        )
    }
}

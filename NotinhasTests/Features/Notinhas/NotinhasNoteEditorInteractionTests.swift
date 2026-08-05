import CoreGraphics
@testable import Notinhas
import XCTest

final class NotinhasNoteEditorInteractionTests: XCTestCase {
    private let container = CGRect(x: 0, y: 0, width: 800, height: 600)
    private let panelSize = CGSize(width: 300, height: 200)
    private let selection = CGRect(x: 120, y: 140, width: 28, height: 28)

    func testInitialPlacementUsesAutomaticOriginOnce() {
        var placement = NotinhasNoteEditorPanelPlacement()

        let first = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        let second = placement.resolvedOrigin(
            selectionBounds: CGRect(x: 500, y: 400, width: 28, height: 28),
            panelSize: panelSize,
            in: container,
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.x, selection.maxX + 24, accuracy: 0.001)
    }

    func testPlacementRetainsOriginAcrossNoteChangesUntilReset() {
        var placement = NotinhasNoteEditorPanelPlacement()
        _ = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )

        placement.applyDrag(
            from: CGPoint(x: 180, y: 120),
            translation: CGSize(width: 40, height: 20),
            panelSize: panelSize,
            in: container,
        )

        let retained = placement.resolvedOrigin(
            selectionBounds: CGRect(x: 500, y: 400, width: 28, height: 28),
            panelSize: panelSize,
            in: container,
        )

        XCTAssertEqual(retained.x, 220, accuracy: 0.001)
        XCTAssertEqual(retained.y, 140, accuracy: 0.001)
    }

    func testResetClearsTransientOrigin() {
        var placement = NotinhasNoteEditorPanelPlacement()
        _ = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.reset()

        let automatic = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )

        XCTAssertEqual(automatic.x, selection.maxX + 24, accuracy: 0.001)
    }

    func testResolvedOriginReclampsAfterWorkAreaShrinks() {
        var placement = NotinhasNoteEditorPanelPlacement()
        _ = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.applyDrag(
            from: CGPoint(x: 420, y: 320),
            translation: .zero,
            panelSize: panelSize,
            in: container,
        )

        let shrunkenContainer = CGRect(x: 0, y: 0, width: 360, height: 280)
        placement.reclamp(panelSize: panelSize, in: shrunkenContainer)
        let reclamped = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: shrunkenContainer,
        )

        XCTAssertLessThanOrEqual(reclamped.x + panelSize.width, shrunkenContainer.maxX - 12)
        XCTAssertLessThanOrEqual(reclamped.y + panelSize.height, shrunkenContainer.maxY - 12)
    }

    func testDisplayOriginIsStableWhenCalledRepeatedly() {
        var placement = NotinhasNoteEditorPanelPlacement()
        _ = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )

        let first = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        let second = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        let third = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(second, third)
    }

    func testSubPointContainerNoiseDoesNotMoveSeededOrigin() {
        var placement = NotinhasNoteEditorPanelPlacement()
        let seeded = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )

        let noisyContainer = CGRect(x: 0, y: 0, width: 800.3, height: 600.2)
        let afterDisplay = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: noisyContainer,
        )
        placement.reclamp(panelSize: panelSize, in: noisyContainer)
        let afterReclamp = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: noisyContainer,
        )

        XCTAssertEqual(afterDisplay, seeded)
        XCTAssertEqual(afterReclamp, seeded)
    }

    func testReclampIgnoredDuringActiveDrag() {
        var placement = NotinhasNoteEditorPanelPlacement()
        _ = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.beginDrag(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.updateDrag(
            translation: CGSize(width: 50, height: 30),
            panelSize: panelSize,
            in: container,
        )
        let duringDrag = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )

        let shrunkenContainer = CGRect(x: 0, y: 0, width: 360, height: 280)
        placement.reclamp(panelSize: panelSize, in: shrunkenContainer)
        let afterIgnoredReclamp = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: shrunkenContainer,
        )

        XCTAssertEqual(afterIgnoredReclamp, duringDrag)

        placement.endDrag()
        placement.reclamp(panelSize: panelSize, in: shrunkenContainer)
        let afterEndDrag = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: shrunkenContainer,
        )

        XCTAssertLessThanOrEqual(afterEndDrag.x + panelSize.width, shrunkenContainer.maxX - 12)
        XCTAssertLessThanOrEqual(afterEndDrag.y + panelSize.height, shrunkenContainer.maxY - 12)
        XCTAssertNotEqual(afterEndDrag, duringDrag)
    }

    func testEndDragThenReclampRecoversFromMidDragContainerShrink() {
        var placement = NotinhasNoteEditorPanelPlacement()
        _ = placement.resolvedOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.beginDrag(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.updateDrag(
            translation: CGSize(width: 400, height: 300),
            panelSize: panelSize,
            in: container,
        )
        let shrunkenContainer = CGRect(x: 0, y: 0, width: 360, height: 280)
        // Simulate ignored onChange during drag:
        placement.reclamp(panelSize: panelSize, in: shrunkenContainer)
        placement.endDrag()
        placement.reclamp(panelSize: panelSize, in: shrunkenContainer)
        let recovered = placement.displayOrigin(
            selectionBounds: selection,
            panelSize: panelSize,
            in: shrunkenContainer,
        )
        XCTAssertLessThanOrEqual(recovered.x + panelSize.width, shrunkenContainer.maxX - 12)
        XCTAssertLessThanOrEqual(recovered.y + panelSize.height, shrunkenContainer.maxY - 12)
    }

    func testBeginDragUsesSeededOriginAndEndDragClearsAnchor() {
        var placement = NotinhasNoteEditorPanelPlacement()

        placement.beginDrag(
            selectionBounds: selection,
            panelSize: panelSize,
            in: container,
        )
        placement.updateDrag(
            translation: CGSize(width: 30, height: 10),
            panelSize: panelSize,
            in: container,
        )
        placement.endDrag()

        let retained = placement.displayOrigin(
            selectionBounds: CGRect(x: 500, y: 400, width: 28, height: 28),
            panelSize: panelSize,
            in: container,
        )

        XCTAssertEqual(retained.x, selection.maxX + 24 + 30, accuracy: 0.001)
        XCTAssertEqual(retained.y, selection.midY - panelSize.height / 2 + 10, accuracy: 0.001)
    }
}

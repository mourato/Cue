//
//  AllDisplayFrozenSessionPreparerTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

@MainActor
final class AllDisplayFrozenSessionPreparerTests: XCTestCase {
    func testConnectedDisplayIDs_matchesCurrentScreens() {
        let expected = Set(NSScreen.screens.compactMap(\.displayID))
        XCTAssertEqual(AllDisplayFrozenSessionPreparer.connectedDisplayIDs(from: NSScreen.screens), expected)
    }

    func testValidateCompleteSession_rejectsPartialSnapshots() {
        guard let snapshot = makeSnapshot(displayID: 10) else {
            XCTFail("Failed to create snapshot")
            return
        }
        let session = FrozenAreaCaptureSession.fromSnapshot(snapshot)

        XCTAssertThrowsError(
            try AllDisplayFrozenSessionPreparer.validateCompleteSession(session, expectedDisplayIDs: [10, 20])
        )
    }

    func testValidateCompleteSession_acceptsFullSnapshotSet() throws {
        guard let first = makeSnapshot(displayID: 10), let second = makeSnapshot(displayID: 20) else {
            XCTFail("Failed to create snapshots")
            return
        }
        let session = FrozenAreaCaptureSession.fromSnapshots([first, second])

        XCTAssertNoThrow(try AllDisplayFrozenSessionPreparer.validateCompleteSession(
            session,
            expectedDisplayIDs: [10, 20]
        ))
    }

    func testPrioritizedCaptureOrder_putsPriorityDisplayFirst() {
        let order = AllDisplayFrozenSessionPreparer.prioritizedCaptureOrder(
            displayIDs: [10, 20, 30],
            priorityDisplayID: 20
        )
        XCTAssertEqual(order.priority, 20)
        XCTAssertEqual(order.remaining, [10, 30])
    }

    func testPrioritizedCaptureOrder_fallsBackWhenPriorityMissing() {
        let order = AllDisplayFrozenSessionPreparer.prioritizedCaptureOrder(
            displayIDs: [40, 10],
            priorityDisplayID: 99
        )
        XCTAssertEqual(order.priority, 10)
        XCTAssertEqual(order.remaining, [40])
    }

    func testPrioritizedCaptureOrder_emptySet() {
        let order = AllDisplayFrozenSessionPreparer.prioritizedCaptureOrder(
            displayIDs: [],
            priorityDisplayID: 1
        )
        XCTAssertNil(order.priority)
        XCTAssertTrue(order.remaining.isEmpty)
    }

    func testAreaSelectionResult_usesIntersectingDisplayIDs() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let selection = ScreenCaptureViewModel.areaSelectionResult(for: rect)

        XCTAssertEqual(selection.rect, rect)
        XCTAssertFalse(selection.displayIDs.isEmpty)
        XCTAssertTrue(selection.displayIDs.contains(selection.displayID))
    }

    private func makeSnapshot(displayID: CGDirectDisplayID) -> FrozenDisplaySnapshot? {
        guard let image = TestImageFactory.solidColor(width: 200, height: 200, red: 10, green: 20, blue: 30) else {
            return nil
        }
        return FrozenDisplaySnapshot(
            displayID: displayID,
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            scaleFactor: 2,
            colorSpaceName: nil,
            image: image
        )
    }
}

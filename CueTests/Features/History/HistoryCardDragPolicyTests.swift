//
//  HistoryCardDragPolicyTests.swift
//  CueTests
//

@testable import Cue
import XCTest

final class HistoryCardDragPolicyTests: XCTestCase {
    func testShouldBeginExportRequiresDistanceBeyondThreshold() {
        let under = HistoryCardDragPolicy.exportDistanceThreshold
        XCTAssertFalse(
            HistoryCardDragPolicy.shouldBeginExport(translation: CGSize(width: under, height: 0))
        )
        XCTAssertTrue(
            HistoryCardDragPolicy.shouldBeginExport(
                translation: CGSize(width: under + 0.5, height: 0)
            )
        )
        XCTAssertTrue(
            HistoryCardDragPolicy.shouldBeginExport(
                translation: CGSize(width: 0, height: -(under + 1))
            )
        )
    }
}

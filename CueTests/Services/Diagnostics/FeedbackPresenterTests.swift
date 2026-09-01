//
//  FeedbackPresenterTests.swift
//  NotinhasTests
//
//  Pure placement tests for coordinated feedback panel slots.
//

@testable import Cue
import XCTest

final class FeedbackPresenterTests: XCTestCase {
    private let visibleFrame = CGRect(x: 100, y: 200, width: 1200, height: 800)
    private let panelSize = CGSize(width: 380, height: 72)

    func testBottomCenterFrameUsesStandardMargin() {
        let frame = FeedbackPanelPlacement.frame(
            in: visibleFrame,
            panelSize: panelSize,
            slot: .bottomCenter,
        )

        XCTAssertEqual(frame.origin.x, visibleFrame.midX - panelSize.width / 2, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, visibleFrame.minY + FeedbackPanelPlacement.standardMargin, accuracy: 0.001)
        XCTAssertEqual(frame.size, panelSize)
    }

    func testTopCenterFrameUsesStandardMargin() {
        let frame = FeedbackPanelPlacement.frame(
            in: visibleFrame,
            panelSize: panelSize,
            slot: .topCenter,
        )

        XCTAssertEqual(frame.origin.x, visibleFrame.midX - panelSize.width / 2, accuracy: 0.001)
        XCTAssertEqual(
            frame.origin.y,
            visibleFrame.maxY - panelSize.height - FeedbackPanelPlacement.standardMargin,
            accuracy: 0.001,
        )
        XCTAssertEqual(frame.size, panelSize)
    }

    func testRaisedBottomCenterSitsAboveBottomCenter() {
        let bottomCenter = FeedbackPanelPlacement.frame(
            in: visibleFrame,
            panelSize: panelSize,
            slot: .bottomCenter,
        )
        let raised = FeedbackPanelPlacement.frame(
            in: visibleFrame,
            panelSize: panelSize,
            slot: .bottomCenterRaised,
        )

        let expectedDelta = FeedbackPanelPlacement.raisedBottomMargin - FeedbackPanelPlacement.standardMargin
        XCTAssertEqual(raised.origin.y - bottomCenter.origin.y, expectedDelta, accuracy: 0.001)
        XCTAssertGreaterThan(raised.origin.y, bottomCenter.origin.y)
    }

    func testPromptSizeFrameStaysWithinHorizontalBounds() {
        let frame = FeedbackPanelPlacement.frame(
            in: visibleFrame,
            panelSize: panelSize,
            slot: .bottomCenterRaised,
        )

        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX)
        XCTAssertEqual(frame.width, panelSize.width)
    }

    func testInfoToneUsesFeedbackStyleHelpers() {
        let style = FeedbackStyle(tone: .info)
        XCTAssertEqual(style.iconName, "info.circle.fill")
        XCTAssertGreaterThan(style.textColor(usesSolidFallback: false).redComponent, 0.9)
        XCTAssertGreaterThan(style.solidBackgroundColor.alphaComponent, 0)
    }

    func testAppToastPositionMapsToFeedbackPanelSlot() {
        XCTAssertEqual(AppToastPosition.topCenter.feedbackPanelSlot, .topCenter)
        XCTAssertEqual(AppToastPosition.bottomCenter.feedbackPanelSlot, .bottomCenter)
    }
}

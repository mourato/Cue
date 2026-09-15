//
//  HistoryFloatingLayoutTests.swift
//  NotinhasTests
//
//  Unit tests for HistoryFloatingLayout math and HistoryFloatingTimeFilter.
//

import AppKit
@testable import Cue
import SwiftUI
import XCTest

@MainActor
final class HistoryFloatingLayoutTests: XCTestCase {
    // MARK: - panel size

    func testPanelWidthUsesNinetyPercentOfVisibleWidth() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            XCTSkip("No NSScreen available in test environment")
            return
        }

        let width = HistoryFloatingLayout.panelWidth(on: screen)

        XCTAssertEqual(
            width,
            screen.visibleFrame.width * HistoryFloatingLayout.panelWidthRatio,
            accuracy: 0.0001
        )
    }

    func testPanelSizeUsesContentDerivedHeightClampedToVisibleFrame() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            XCTSkip("No NSScreen available in test environment")
            return
        }

        let size = HistoryFloatingLayout.panelSize(on: screen)
        let safeFrame = screen.visibleFrame.insetBy(dx: 20, dy: 20)

        XCTAssertEqual(
            size.width,
            screen.visibleFrame.width * HistoryFloatingLayout.panelWidthRatio,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            size.height,
            min(HistoryFloatingLayout.panelHeight, safeFrame.height),
            accuracy: 0.0001
        )
    }

    func testPanelHeightMatchesHeaderRowAndContentPadding() {
        let expected =
            HistoryFloatingLayout.contentTopPadding
                + HistoryFloatingLayout.headerHeight
                + HistoryFloatingLayout.sectionSpacing
                + HistoryFloatingLayout.rowHeight
                + HistoryFloatingLayout.contentBottomPadding

        XCTAssertEqual(HistoryFloatingLayout.panelHeight, expected, accuracy: 0.0001)
    }

    func testCardAndRowHeightsDeriveFromSharedMetrics() {
        let expectedPreview = HistoryFloatingLayout.cardContentWidth / HistoryFloatingLayout.cardPreviewAspectRatio
        XCTAssertEqual(HistoryFloatingLayout.cardPreviewHeight, expectedPreview, accuracy: 0.0001)

        let expectedCard =
            (HistoryFloatingLayout.cardChromePadding * 2)
                + expectedPreview
                + HistoryFloatingLayout.cardInnerSpacing
                + HistoryFloatingLayout.cardTitleLineHeight
                + HistoryFloatingLayout.cardTitleMetaSpacing
                + HistoryFloatingLayout.cardMetaLineHeight
        XCTAssertEqual(HistoryFloatingLayout.cardHeight, expectedCard, accuracy: 0.0001)

        let expectedRow = expectedCard + (HistoryFloatingLayout.rowVerticalPadding * 2)
        XCTAssertEqual(HistoryFloatingLayout.rowHeight, expectedRow, accuracy: 0.0001)
    }

    // MARK: - baseCornerRadius

    func testBaseCornerRadius() {
        XCTAssertEqual(HistoryFloatingLayout.baseCornerRadius, 32)
    }

    func testTopPanelPaddingIsEightPoints() {
        XCTAssertEqual(HistoryFloatingLayout.topPanelPadding, 8)
    }

    // MARK: - HistoryFloatingTimeFilter

    func testTimeFilterAllIncludesAnyDate() {
        let now = Date()
        XCTAssertTrue(HistoryFloatingTimeFilter.all.includes(now.addingTimeInterval(-1_000_000), relativeTo: now))
        XCTAssertTrue(HistoryFloatingTimeFilter.all.includes(now.addingTimeInterval(100), relativeTo: now))
    }

    func testTimeFilterLast24HoursExcludesOlder() {
        let now = Date()
        XCTAssertTrue(HistoryFloatingTimeFilter.last24Hours.includes(now.addingTimeInterval(-3600), relativeTo: now))
        XCTAssertFalse(HistoryFloatingTimeFilter.last24Hours.includes(
            now.addingTimeInterval(-100_000),
            relativeTo: now
        ))
    }

    func testTimeFilterLast7DaysExcludesOlder() {
        let now = Date()
        XCTAssertTrue(HistoryFloatingTimeFilter.last7Days.includes(now.addingTimeInterval(-100_000), relativeTo: now))
        XCTAssertFalse(HistoryFloatingTimeFilter.last7Days.includes(
            now.addingTimeInterval(-1_000_000),
            relativeTo: now
        ))
    }

    func testTimeFilterLast30DaysExcludesOlder() {
        let now = Date()
        XCTAssertTrue(HistoryFloatingTimeFilter.last30Days.includes(
            now.addingTimeInterval(-1_000_000),
            relativeTo: now
        ))
        XCTAssertFalse(HistoryFloatingTimeFilter.last30Days.includes(
            now.addingTimeInterval(-10_000_000),
            relativeTo: now
        ))
    }

    func testTimeFilterAllCasesAreUnique() {
        let all = HistoryFloatingTimeFilter.allCases
        XCTAssertEqual(Set(all).count, all.count)
    }

    func testHistoryFloatingPanelCmdAPostNotification() {
        let panel = HistoryFloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100))
        let expectation = expectation(forNotification: .historySelectAll, object: panel, handler: nil)

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )

        guard let event else {
            XCTFail("Failed to create Cmd+A event")
            return
        }

        let handled = panel.performKeyEquivalent(with: event)
        XCTAssertTrue(handled)

        wait(for: [expectation], timeout: 1.0)
    }

    func testHistoryFloatingPanelCmdANoNotificationWhenTextInputActive() {
        let panel = HistoryFloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100))

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 50, height: 50))
        panel.contentView?.addSubview(textView)
        let madeFirstResponder = panel.makeFirstResponder(textView)
        XCTAssertTrue(madeFirstResponder)

        let observer = NotificationCenter.default.addObserver(
            forName: .historySelectAll,
            object: panel,
            queue: nil
        ) { _ in
            XCTFail("Notification should not be posted when text input is active")
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )

        guard let event else {
            XCTFail("Failed to create Cmd+A event")
            return
        }

        let handled = panel.performKeyEquivalent(with: event)
        XCTAssertFalse(handled)
    }
}

//
//  HistoryFloatingLayoutTests.swift
//  NotinhasTests
//
//  Unit tests for HistoryFloatingLayout math and HistoryFloatingTimeFilter.
//

import AppKit
@testable import Cue
import XCTest

@MainActor
final class HistoryFloatingLayoutTests: XCTestCase {
    // MARK: - basePanelSize

    func testBasePanelSize() {
        let size = HistoryFloatingLayout.basePanelSize
        XCTAssertEqual(size, CGSize(width: 1280, height: 360))
    }

    func testBasePanelSize_fitsAtLeastFiveFullCardsInFirstRow() {
        // Row geometry shares the view's layout constants: content padding per
        // side plus the row inset per side.
        let availableWidth = HistoryFloatingLayout.basePanelSize.width
            - (HistoryFloatingLayout.contentHorizontalPadding * 2)
            - (HistoryFloatingLayout.rowHorizontalPadding * 2)
        let fiveCardsWidth = (HistoryFloatingLayout.cardWidth * 5)
            + (HistoryFloatingLayout.cardSpacing * 4)
        XCTAssertGreaterThanOrEqual(availableWidth, fiveCardsWidth)
    }

    // MARK: - baseCornerRadius

    func testBaseCornerRadius() {
        XCTAssertEqual(HistoryFloatingLayout.baseCornerRadius, 32)
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
            relativeTo: now,
        ))
    }

    func testTimeFilterLast7DaysExcludesOlder() {
        let now = Date()
        XCTAssertTrue(HistoryFloatingTimeFilter.last7Days.includes(now.addingTimeInterval(-100_000), relativeTo: now))
        XCTAssertFalse(HistoryFloatingTimeFilter.last7Days.includes(
            now.addingTimeInterval(-1_000_000),
            relativeTo: now,
        ))
    }

    func testTimeFilterLast30DaysExcludesOlder() {
        let now = Date()
        XCTAssertTrue(HistoryFloatingTimeFilter.last30Days.includes(
            now.addingTimeInterval(-1_000_000),
            relativeTo: now,
        ))
        XCTAssertFalse(HistoryFloatingTimeFilter.last30Days.includes(
            now.addingTimeInterval(-10_000_000),
            relativeTo: now,
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
            keyCode: 0,
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
            queue: nil,
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
            keyCode: 0,
        )

        guard let event else {
            XCTFail("Failed to create Cmd+A event")
            return
        }

        let handled = panel.performKeyEquivalent(with: event)
        XCTAssertFalse(handled)
    }
}

//
//  AnnotateOverlayTooltipKeysTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

@MainActor
final class AnnotateOverlayTooltipKeysTests: XCTestCase {
    private var manager: AnnotateShortcutManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
    }

    override func tearDown() async throws {
        manager.resetToDefaults()
        try await super.tearDown()
    }

    func testToolKeys_returnsDefaultShortcutWhenEnabled() {
        XCTAssertEqual(
            AnnotateOverlayTooltipKeys.toolKeys(for: .rectangle, manager: manager),
            ["R"],
        )
    }

    func testToolKeys_returnsEmptyWhenShortcutDisabled() {
        manager.setShortcutEnabled(false, for: .rectangle)
        XCTAssertEqual(
            AnnotateOverlayTooltipKeys.toolKeys(for: .rectangle, manager: manager),
            [],
        )
    }

    func testToolKeys_returnsEmptyWhenShortcutCleared() {
        manager.setShortcut(nil, for: .rectangle)
        XCTAssertEqual(
            AnnotateOverlayTooltipKeys.toolKeys(for: .rectangle, manager: manager),
            [],
        )
    }

    func testActionKeys_returnsDisplayPartsWhenEnabled() {
        XCTAssertEqual(
            AnnotateOverlayTooltipKeys.actionKeys(for: .copyAndClose, manager: manager),
            AnnotateShortcutManager.defaultCopyAndClose.displayParts,
        )
    }

    func testActionKeys_returnsEmptyWhenDisabled() {
        manager.setActionShortcutEnabled(false, for: .copyAndClose)
        XCTAssertEqual(
            AnnotateOverlayTooltipKeys.actionKeys(for: .copyAndClose, manager: manager),
            [],
        )
    }
}

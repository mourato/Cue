//
//  AllInOneCaptureShortcutTests.swift
//  NotinhasTests
//
//  Unit tests for the optional All-In-One global shortcut.
//

import Carbon.HIToolbox
@testable import Notinhas
import XCTest

final class AllInOneCaptureShortcutTests: XCTestCase {
    func testDefaultAllInOneShortcut_matchesRecommendedCmdShiftZero() {
        let config = ShortcutConfig.defaultAllInOne
        XCTAssertEqual(config.keyCode, UInt32(kVK_ANSI_0))
        XCTAssertEqual(config.modifiers, UInt32(cmdKey | shiftKey))
    }

    func testAllInOneKind_isPresentInAllCases() {
        XCTAssertTrue(GlobalShortcutKind.allCases.contains(.allInOne))
    }

    func testAllInOneKind_isNotSystemConflictRelevant() {
        XCTAssertFalse(GlobalShortcutKind.allInOne.isSystemConflictRelevant)
    }

    func testAllInOneKind_hasNonEmptyDisplayName() {
        XCTAssertFalse(GlobalShortcutKind.allInOne.displayName.isEmpty)
    }

    func testAllInOneKind_configKey() {
        XCTAssertEqual(GlobalShortcutKind.allInOne.configKey, "all_in_one")
    }

    @MainActor
    func testKeyboardShortcutManager_allInOne_resolvesNilWhenCleared() {
        let manager = KeyboardShortcutManager.shared
        let initial = manager.shortcut(for: .allInOne)
        addTeardownBlock { @MainActor in
            manager.setAllInOneShortcut(initial)
        }

        manager.setAllInOneShortcut(nil)
        XCTAssertNil(
            manager.shortcut(for: .allInOne),
            "Clearing the All-In-One shortcut must resolve to nil, never the seeded recommended combo",
        )
    }

    @MainActor
    func testKeyboardShortcutManager_setAllInOneShortcut_persistsThenClears() {
        let manager = KeyboardShortcutManager.shared
        let initial = manager.shortcut(for: .allInOne)
        addTeardownBlock { @MainActor in
            manager.setAllInOneShortcut(initial)
        }

        let binding = ShortcutConfig(keyCode: UInt32(kVK_ANSI_0), modifiers: UInt32(cmdKey | shiftKey))
        manager.setAllInOneShortcut(binding)
        XCTAssertEqual(manager.shortcut(for: .allInOne), binding)

        manager.setAllInOneShortcut(nil)
        XCTAssertNil(manager.shortcut(for: .allInOne))
    }
}

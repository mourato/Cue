//
//  AnnotateShortcutManagerTests.swift
//  NotinhasTests
//
//  Unit tests for AnnotateShortcutManager lookup, conflict detection, and enable/disable.
//

@testable import Notinhas
import XCTest

@MainActor
final class AnnotateShortcutManagerTests: XCTestCase {
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

    // MARK: - Lookup

    func testToolForKey_findsMappedTool() {
        manager.setShortcut("r", for: .rectangle)
        XCTAssertEqual(manager.tool(for: "r"), .rectangle)
    }

    func testToolForKey_findsMappedNumericKey() {
        manager.setShortcut("1", for: .rectangle)
        XCTAssertEqual(manager.tool(for: "1"), .rectangle)
    }

    func testToolForKey_returnsNilForUnmappedKey() {
        XCTAssertNil(manager.tool(for: "z"))
    }

    func testShortcutForTool_returnsSetValue() {
        manager.setShortcut("t", for: .text)
        XCTAssertEqual(manager.shortcut(for: .text), "t")
    }

    // MARK: - Enable / Disable

    func testIsShortcutEnabled_defaultIsTrue() {
        XCTAssertTrue(manager.isShortcutEnabled(for: .rectangle))
    }

    func testSetShortcutEnabled_disablesAndEnables() {
        manager.setShortcutEnabled(false, for: .rectangle)
        XCTAssertFalse(manager.isShortcutEnabled(for: .rectangle))

        manager.setShortcutEnabled(true, for: .rectangle)
        XCTAssertTrue(manager.isShortcutEnabled(for: .rectangle))
    }

    func testToolForKey_skipsDisabledShortcuts() {
        manager.setShortcut("r", for: .rectangle)
        manager.setShortcutEnabled(false, for: .rectangle)
        XCTAssertNil(manager.tool(for: "r"))
    }

    // MARK: - Conflicts

    func testConflictingTool_findsConflict() {
        manager.setShortcut("x", for: .rectangle)
        manager.setShortcut("x", for: .circle)
        XCTAssertEqual(manager.conflictingTool(for: "x", excluding: .circle), .rectangle)
    }

    func testConflictingTool_findsNumericConflict() {
        manager.setShortcut("2", for: .rectangle)
        manager.setShortcut("2", for: .circle)
        XCTAssertEqual(manager.conflictingTool(for: "2", excluding: .circle), .rectangle)
    }

    func testConflictingTool_excludesSelf() {
        manager.setShortcut("x", for: .rectangle)
        XCTAssertNil(manager.conflictingTool(for: "x", excluding: .rectangle))
    }

    func testConflictingTool_ignoresDisabledTools() {
        manager.setShortcut("x", for: .rectangle)
        manager.setShortcutEnabled(false, for: .rectangle)
        manager.setShortcut("x", for: .circle)
        XCTAssertNil(manager.conflictingTool(for: "x", excluding: .circle))
    }

    // MARK: - Reset

    func testResetToDefaults_restoresDefaults() {
        manager.setShortcut("z", for: .rectangle)
        manager.setShortcutEnabled(false, for: .rectangle)
        manager.resetToDefaults()
        XCTAssertEqual(manager.shortcut(for: .rectangle), AnnotationToolType.rectangle.defaultShortcut)
        XCTAssertTrue(manager.isShortcutEnabled(for: .rectangle))
    }

    // MARK: - Action Shortcuts

    func testActionShortcutEnabled_defaultIsTrue() {
        XCTAssertTrue(manager.isActionShortcutEnabled(for: .copyAndClose))
    }

    func testSetActionShortcutEnabled_toggles() {
        manager.setActionShortcutEnabled(false, for: .copyAndClose)
        XCTAssertFalse(manager.isActionShortcutEnabled(for: .copyAndClose))
        manager.setActionShortcutEnabled(true, for: .copyAndClose)
        XCTAssertTrue(manager.isActionShortcutEnabled(for: .copyAndClose))
    }

    func testShortcutForAction_returnsConfig() {
        XCTAssertNotNil(manager.shortcut(for: .copyAndClose))
        XCTAssertNotNil(manager.shortcut(for: .toggleSidebar))
    }

    func testAutoRedactSensitiveDataShortcut_defaultsToUnsetButEnabled() {
        XCTAssertNil(manager.shortcut(for: .autoRedactSensitiveData))
        XCTAssertTrue(manager.isActionShortcutEnabled(for: .autoRedactSensitiveData))
    }

    func testSpotlightShortcut_isConfigurableAndMappable() {
        XCTAssertTrue(AnnotateShortcutManager.configurableTools.contains(.spotlight))
        XCTAssertEqual(manager.shortcut(for: .spotlight), "s")

        manager.setShortcut("k", for: .spotlight)
        XCTAssertEqual(manager.shortcut(for: .spotlight), "k")
        XCTAssertEqual(manager.tool(for: "k"), .spotlight)
    }

    func testNotinhasNoteShortcut_defaultsToN_andCounterIsNotConfigurable() {
        XCTAssertFalse(AnnotateShortcutManager.configurableTools.contains(.counter))
        XCTAssertTrue(AnnotateShortcutManager.configurableTools.contains(.notinhasNote))
        XCTAssertEqual(AnnotationToolType.notinhasNote.defaultShortcut, "n")
        XCTAssertEqual(manager.shortcut(for: .notinhasNote), "n")
    }

    func testCounterAbsorptionShortcutMigration_movesNoteShortcutFromIToN() {
        let noteKey = "annotate.shortcut.\(AnnotationToolType.notinhasNote.rawValue)"
        let migrationKey = "annotate.shortcut.counterAbsorption.v1"
        let counterKey = "annotate.shortcut.\(AnnotationToolType.counter.rawValue)"
        UserDefaults.standard.set("i", forKey: noteKey)
        UserDefaults.standard.set("n", forKey: counterKey)
        UserDefaults.standard.set(false, forKey: migrationKey)
        manager.setShortcut("i", for: .notinhasNote)

        manager.migrateCounterAbsorptionShortcutsIfNeeded()

        XCTAssertEqual(manager.shortcut(for: .notinhasNote), "n")
        XCTAssertNil(UserDefaults.standard.string(forKey: counterKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: migrationKey))
    }

    func testCounterAbsorptionShortcutMigration_keepsIWhenNIsTaken() {
        let noteKey = "annotate.shortcut.\(AnnotationToolType.notinhasNote.rawValue)"
        let migrationKey = "annotate.shortcut.counterAbsorption.v1"
        UserDefaults.standard.set("i", forKey: noteKey)
        UserDefaults.standard.set(false, forKey: migrationKey)
        manager.setShortcut("i", for: .notinhasNote)
        manager.setShortcut("n", for: .pencil)

        manager.migrateCounterAbsorptionShortcutsIfNeeded()

        XCTAssertEqual(manager.shortcut(for: .notinhasNote), "i")
        XCTAssertEqual(manager.shortcut(for: .pencil), "n")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: migrationKey))
    }

    func testCounterAbsorptionShortcutMigration_removesOrphanDisabledCounter() {
        let migrationKey = "annotate.shortcut.counterAbsorption.v1"
        UserDefaults.standard.set(true, forKey: migrationKey)
        manager.setShortcutEnabled(false, for: .counter)
        XCTAssertFalse(manager.isShortcutEnabled(for: .counter))

        manager.migrateCounterAbsorptionShortcutsIfNeeded()

        XCTAssertTrue(manager.isShortcutEnabled(for: .counter))
    }
}

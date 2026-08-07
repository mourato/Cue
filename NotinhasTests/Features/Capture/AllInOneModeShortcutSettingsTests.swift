//
//  AllInOneModeShortcutSettingsTests.swift
//  NotinhasTests
//
//  Persistence, defaults, migration, and conflict checks for AIO mode shortcuts.
//

import Carbon.HIToolbox
@testable import Notinhas
import XCTest

@MainActor
final class AllInOneModeShortcutSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaultsFactory.make()
        AllInOneModeShortcutSettings.defaults = defaults
    }

    override func tearDown() {
        AllInOneModeShortcutSettings.defaults = .standard
        super.tearDown()
    }

    func testDefaultShortcuts_areDistinctSingleKeys() {
        var seen = Set<UInt32>()
        for mode in AllInOneCaptureMode.allCases {
            let shortcut = AllInOneModeShortcutSettings.defaultShortcut(for: mode)
            XCTAssertEqual(shortcut.modifiers, 0)
            XCTAssertFalse(seen.contains(shortcut.keyCode), "Duplicate default for \(mode)")
            seen.insert(shortcut.keyCode)
        }
    }

    func testDefaultWindowShortcut_isKeyA() {
        let shortcut = AllInOneModeShortcutSettings.defaultShortcut(for: .window)
        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_A))
    }

    func testSetAndRead_roundtrips() throws {
        let shortcut = CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: 0)
        AllInOneModeShortcutSettings.setShortcut(shortcut, for: .area)

        let loaded = try XCTUnwrap(AllInOneModeShortcutSettings.shortcut(for: .area))
        XCTAssertEqual(loaded.keyCode, UInt32(kVK_ANSI_Z))
        XCTAssertEqual(loaded.modifiers, 0)
    }

    func testSetShortcut_stripsModifiers() throws {
        let independent = CaptureOverlayShortcut(
            keyCode: UInt32(kVK_ANSI_W),
            modifiers: UInt32(cmdKey),
        )
        AllInOneModeShortcutSettings.setShortcut(independent, for: .window)

        let loaded = try XCTUnwrap(AllInOneModeShortcutSettings.shortcut(for: .window))
        XCTAssertEqual(loaded.keyCode, UInt32(kVK_ANSI_W))
        XCTAssertEqual(loaded.modifiers, 0)
    }

    func testSetNil_clearsShortcut() {
        AllInOneModeShortcutSettings.setShortcut(nil, for: .timer)
        XCTAssertNil(AllInOneModeShortcutSettings.shortcut(for: .timer))
    }

    func testReset_fallsBackToDefault() throws {
        AllInOneModeShortcutSettings.setShortcut(
            CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: 0),
            for: .ocr,
        )
        AllInOneModeShortcutSettings.resetShortcut(for: .ocr)

        let loaded = try XCTUnwrap(AllInOneModeShortcutSettings.shortcut(for: .ocr))
        XCTAssertEqual(loaded, AllInOneModeShortcutSettings.defaultShortcut(for: .ocr))
    }

    func testConflictingMode_detectsDuplicateKey() {
        AllInOneModeShortcutSettings.setShortcut(
            CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_X), modifiers: 0),
            for: .area,
        )
        AllInOneModeShortcutSettings.setShortcut(
            CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_X), modifiers: 0),
            for: .fullscreen,
        )

        let conflict = AllInOneModeShortcutSettings.conflictingMode(
            for: CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_X), modifiers: 0),
            excluding: .area,
        )
        XCTAssertEqual(conflict, .fullscreen)
    }

    func testMigrateFromApplicationCapture_childKeyMovesToWindow() throws {
        let legacy = CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: 0)
        let data = try JSONEncoder().encode(legacy)
        defaults.set(data, forKey: PreferencesKeys.areaApplicationCaptureShortcut)

        let window = try XCTUnwrap(AllInOneModeShortcutSettings.shortcut(for: .window))
        XCTAssertEqual(window.keyCode, UInt32(kVK_ANSI_Q))
        XCTAssertNil(defaults.data(forKey: PreferencesKeys.areaApplicationCaptureShortcut))
    }

    func testMigrateFromApplicationCapture_independentIgnored() throws {
        let legacy = CaptureOverlayShortcut(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: UInt32(cmdKey | shiftKey),
        )
        let data = try JSONEncoder().encode(legacy)
        defaults.set(data, forKey: PreferencesKeys.areaApplicationCaptureShortcut)

        let window = try XCTUnwrap(AllInOneModeShortcutSettings.shortcut(for: .window))
        XCTAssertEqual(window, AllInOneModeShortcutSettings.defaultShortcut(for: .window))
    }

    func testMatching_ignoresStoredShortcutForHiddenMode() throws {
        AllInOneModeShortcutSettings.setShortcut(
            CaptureOverlayShortcut(keyCode: UInt32(kVK_ANSI_Z), modifiers: 0),
            for: .recording,
        )
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_Z),
        ))

        XCTAssertNil(AllInOneModeShortcutSettings.mode(matching: event, in: [.area]))
        XCTAssertNotNil(AllInOneModeShortcutSettings.shortcut(for: .recording))
    }
}

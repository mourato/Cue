//
//  AllInOneModeShortcutSettings.swift
//  Notinhas
//
//  Child-only (session-scoped) single-key shortcuts for All-In-One HUD modes.
//

import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
enum AllInOneModeShortcutSettings {
    /// Test hook: override to inject isolated UserDefaults in unit tests.
    static var defaults: UserDefaults = .standard

    private static let explicitEmptyShortcutData = Data("null".utf8)
    private static let migratedFromApplicationCaptureKey =
        "shortcuts.allInOne.migratedFromApplicationCapture"

    static func preferenceKey(for mode: AllInOneCaptureMode) -> String {
        "shortcuts.allInOne.mode.\(mode.rawValue)"
    }

    static func defaultShortcut(for mode: AllInOneCaptureMode) -> CaptureOverlayShortcut {
        CaptureOverlayShortcut(keyCode: defaultKeyCode(for: mode), modifiers: 0)
    }

    static func shortcut(for mode: AllInOneCaptureMode) -> CaptureOverlayShortcut? {
        migrateFromApplicationCaptureIfNeeded()
        return loadShortcut(forKey: preferenceKey(for: mode), defaultValue: defaultShortcut(for: mode))
    }

    static func setShortcut(_ shortcut: CaptureOverlayShortcut?, for mode: AllInOneCaptureMode) {
        migrateFromApplicationCaptureIfNeeded()
        let key = preferenceKey(for: mode)
        guard let shortcut else {
            defaults.set(explicitEmptyShortcutData, forKey: key)
            return
        }
        // Child-only: ignore modifier combos.
        let child = CaptureOverlayShortcut(keyCode: shortcut.keyCode, modifiers: 0)
        guard let data = try? JSONEncoder().encode(child) else { return }
        defaults.set(data, forKey: key)
    }

    static func resetShortcut(for mode: AllInOneCaptureMode) {
        defaults.removeObject(forKey: preferenceKey(for: mode))
    }

    static func resetAllModeShortcuts() {
        for mode in AllInOneCaptureMode.allCases {
            resetShortcut(for: mode)
        }
    }

    static func matches(_ event: NSEvent, mode: AllInOneCaptureMode) -> Bool {
        shortcut(for: mode)?.matches(event) ?? false
    }

    /// First available mode whose child shortcut matches the event.
    static func mode(
        matching event: NSEvent,
        in availableModes: [AllInOneCaptureMode],
    ) -> AllInOneCaptureMode? {
        availableModes.first { matches(event, mode: $0) }
    }

    /// True when another mode already uses the same single key.
    static func conflictingMode(
        for candidate: CaptureOverlayShortcut,
        excluding excluded: AllInOneCaptureMode,
    ) -> AllInOneCaptureMode? {
        AllInOneCaptureMode.allCases.first { mode in
            guard mode != excluded, let existing = shortcut(for: mode) else { return false }
            return existing.keyCode == candidate.keyCode && existing.modifiers == 0
        }
    }

    // MARK: - Migration

    /// Moves legacy Capture Area → Application Capture child key onto AIO `.window`.
    static func migrateFromApplicationCaptureIfNeeded() {
        guard !defaults.bool(forKey: migratedFromApplicationCaptureKey) else { return }
        defaults.set(true, forKey: migratedFromApplicationCaptureKey)

        let legacyKey = PreferencesKeys.areaApplicationCaptureShortcut
        defer { defaults.removeObject(forKey: legacyKey) }

        let windowKey = preferenceKey(for: .window)
        // Do not overwrite an already-configured window shortcut.
        if defaults.data(forKey: windowKey) != nil {
            return
        }

        guard let data = defaults.data(forKey: legacyKey) else { return }

        if data == explicitEmptyShortcutData {
            defaults.set(explicitEmptyShortcutData, forKey: windowKey)
            return
        }

        guard let legacy = try? JSONDecoder().decode(CaptureOverlayShortcut.self, from: data) else {
            return
        }
        // Only child (single-key) bindings migrate; independent globals are dropped.
        guard !legacy.isIndependent else { return }
        if let encoded = try? JSONEncoder().encode(CaptureOverlayShortcut(keyCode: legacy.keyCode, modifiers: 0)) {
            defaults.set(encoded, forKey: windowKey)
        }
    }

    // MARK: - Private

    private static func defaultKeyCode(for mode: AllInOneCaptureMode) -> UInt32 {
        switch mode {
        case .area: UInt32(kVK_ANSI_R)
        case .fullscreen: UInt32(kVK_ANSI_F)
        case .window: UInt32(kVK_ANSI_A)
        case .annotate: UInt32(kVK_ANSI_M)
        case .scrolling: UInt32(kVK_ANSI_S)
        case .timer: UInt32(kVK_ANSI_T)
        case .ocr: UInt32(kVK_ANSI_O)
        case .recording: UInt32(kVK_ANSI_V)
        }
    }

    private static func loadShortcut(
        forKey key: String,
        defaultValue: CaptureOverlayShortcut,
    ) -> CaptureOverlayShortcut? {
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: key) {
            if data == explicitEmptyShortcutData {
                return nil
            }
            if let shortcut = try? decoder.decode(CaptureOverlayShortcut.self, from: data) {
                return CaptureOverlayShortcut(keyCode: shortcut.keyCode, modifiers: 0)
            }
        }
        return defaultValue
    }
}

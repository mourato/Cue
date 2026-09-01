//
//  CaptureOverlayShortcutSettings.swift
//  Notinhas
//
//  Shared persistence for shortcuts used by recording application mode overlays.
//

import AppKit
import Carbon.HIToolbox
import Foundation

struct CaptureOverlayShortcut: Equatable, Codable {
    let keyCode: UInt32
    let modifiers: UInt32

    var isIndependent: Bool {
        modifiers != 0
    }

    var independentShortcutConfig: ShortcutConfig? {
        guard isIndependent else { return nil }
        return ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
    }

    var displayParts: [String] {
        if let independentShortcutConfig {
            return independentShortcutConfig.displayParts
        }
        return [ShortcutConfig.keyCodeToDisplayString(keyCode)]
    }

    var displayString: String {
        displayParts.joined(separator: " ")
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(from event: NSEvent) {
        guard event.type == .keyDown, event.keyCode != UInt16(kVK_Escape) else { return nil }

        let keyCode = UInt32(event.keyCode)
        let modifiers = Self.carbonModifiers(from: event)

        if modifiers == 0 {
            guard Self.isAllowedSingleKey(event) else { return nil }
        } else {
            guard ShortcutConfig(from: event) != nil else { return nil }
        }

        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Child-only recording: accepts a single key without modifiers.
    init?(childKeyFrom event: NSEvent) {
        guard event.type == .keyDown, event.keyCode != UInt16(kVK_Escape) else { return nil }
        guard Self.carbonModifiers(from: event) == 0 else { return nil }
        guard Self.isAllowedSingleKey(event) else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = 0
    }

    func matches(_ event: NSEvent) -> Bool {
        guard UInt32(event.keyCode) == keyCode else { return false }
        return Self.carbonModifiers(from: event) == modifiers
    }

    static func inlineDisplay(parts: [String]) -> String {
        guard let last = parts.last else { return "" }
        let modifiers = parts.dropLast().joined()
        return modifiers.isEmpty ? last : "\(modifiers)\(last)"
    }

    private static func carbonModifiers(from event: NSEvent) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if event.modifierFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if event.modifierFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if event.modifierFlags.contains(.function) {
            carbonModifiers |= ShortcutConfig.functionCarbonModifier
        }
        return carbonModifiers
    }

    private static func isAllowedSingleKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else {
            return false
        }
        guard let character = event.charactersIgnoringModifiers?.lowercased().first else {
            return false
        }
        return character.isLetter || character.isNumber || character == " "
    }
}

enum CaptureOverlayShortcutKind: Hashable {
    case applicationRecording

    var displayName: String {
        switch self {
        case .applicationRecording:
            L10n.PreferencesShortcuts.applicationRecordingTitle
        }
    }
}

@MainActor
enum CaptureOverlayShortcutSettings {
    /// Test hook: override to inject isolated UserDefaults in unit tests.
    static var defaults: UserDefaults = .standard
    private static let explicitEmptyShortcutData = Data("null".utf8)

    static let defaultRecordingApplicationCaptureShortcut = CaptureOverlayShortcut(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: 0,
    )

    static var recordingApplicationCaptureShortcut: CaptureOverlayShortcut? {
        shortcut(
            forKey: PreferencesKeys.recordingApplicationCaptureShortcut,
            defaultValue: defaultRecordingApplicationCaptureShortcut,
        )
    }

    static var recordingApplicationCaptureShortcutDisplay: String {
        recordingApplicationCaptureShortcut?.displayString ?? L10n.Common.none
    }

    static var recordingApplicationCaptureIndependentShortcut: ShortcutConfig? {
        recordingApplicationCaptureShortcut?.independentShortcutConfig
    }

    static func effectiveRecordingApplicationCaptureDisplay(parentShortcut: ShortcutConfig?) -> String {
        effectiveDisplay(shortcut: recordingApplicationCaptureShortcut, parentShortcut: parentShortcut)
    }

    static func setRecordingApplicationCaptureShortcut(_ shortcut: CaptureOverlayShortcut?) {
        setShortcut(shortcut, forKey: PreferencesKeys.recordingApplicationCaptureShortcut)
    }

    static func resetRecordingApplicationCaptureShortcut() {
        defaults.removeObject(forKey: PreferencesKeys.recordingApplicationCaptureShortcut)
    }

    static func matchesRecordingApplicationCaptureShortcut(_ event: NSEvent) -> Bool {
        recordingApplicationCaptureShortcut?.matches(event) ?? false
    }

    static func shortcut(for kind: CaptureOverlayShortcutKind) -> CaptureOverlayShortcut? {
        switch kind {
        case .applicationRecording:
            recordingApplicationCaptureShortcut
        }
    }

    private static func shortcut(
        forKey key: String,
        defaultValue: CaptureOverlayShortcut,
    ) -> CaptureOverlayShortcut? {
        let decoder = JSONDecoder()
        if let data = Self.defaults.data(forKey: key) {
            if data == explicitEmptyShortcutData {
                return nil
            }
            if let shortcut = try? decoder.decode(CaptureOverlayShortcut.self, from: data) {
                return shortcut
            }
        }

        return legacyShortcut(forKey: key) ?? defaultValue
    }

    private static func setShortcut(_ shortcut: CaptureOverlayShortcut?, forKey key: String) {
        guard let shortcut else {
            defaults.set(explicitEmptyShortcutData, forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        Self.defaults.set(data, forKey: key)
    }

    private static func effectiveDisplay(
        shortcut: CaptureOverlayShortcut?,
        parentShortcut: ShortcutConfig?,
    ) -> String {
        guard let shortcut else { return L10n.Common.none }
        if shortcut.isIndependent {
            return CaptureOverlayShortcut.inlineDisplay(parts: shortcut.displayParts)
        }
        let childDisplay = CaptureOverlayShortcut.inlineDisplay(parts: shortcut.displayParts)
        guard let parentShortcut else { return childDisplay }
        let parentDisplay = CaptureOverlayShortcut.inlineDisplay(parts: parentShortcut.displayParts)
        return "\(parentDisplay) \(childDisplay)"
    }

    private static func legacyShortcut(forKey key: String) -> CaptureOverlayShortcut? {
        guard let character = normalizedLegacyShortcut(from: defaults.string(forKey: key)),
              let keyCode = legacyKeyCode(for: character) else {
            return nil
        }
        return CaptureOverlayShortcut(keyCode: keyCode, modifiers: 0)
    }

    private static func normalizedLegacyShortcut(from rawValue: String?) -> Character? {
        guard let rawValue else { return nil }
        if rawValue == " " {
            return " "
        }
        guard let shortcut = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .first,
            shortcut.isLetter || shortcut.isNumber
        else {
            return nil
        }
        return shortcut
    }

    private static func legacyKeyCode(for character: Character) -> UInt32? {
        switch character {
        case "a": UInt32(kVK_ANSI_A)
        case "b": UInt32(kVK_ANSI_B)
        case "c": UInt32(kVK_ANSI_C)
        case "d": UInt32(kVK_ANSI_D)
        case "e": UInt32(kVK_ANSI_E)
        case "f": UInt32(kVK_ANSI_F)
        case "g": UInt32(kVK_ANSI_G)
        case "h": UInt32(kVK_ANSI_H)
        case "i": UInt32(kVK_ANSI_I)
        case "j": UInt32(kVK_ANSI_J)
        case "k": UInt32(kVK_ANSI_K)
        case "l": UInt32(kVK_ANSI_L)
        case "m": UInt32(kVK_ANSI_M)
        case "n": UInt32(kVK_ANSI_N)
        case "o": UInt32(kVK_ANSI_O)
        case "p": UInt32(kVK_ANSI_P)
        case "q": UInt32(kVK_ANSI_Q)
        case "r": UInt32(kVK_ANSI_R)
        case "s": UInt32(kVK_ANSI_S)
        case "t": UInt32(kVK_ANSI_T)
        case "u": UInt32(kVK_ANSI_U)
        case "v": UInt32(kVK_ANSI_V)
        case "w": UInt32(kVK_ANSI_W)
        case "x": UInt32(kVK_ANSI_X)
        case "y": UInt32(kVK_ANSI_Y)
        case "z": UInt32(kVK_ANSI_Z)
        case " ": UInt32(kVK_Space)
        default: nil
        }
    }
}

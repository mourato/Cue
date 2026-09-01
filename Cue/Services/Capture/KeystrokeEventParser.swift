#if CUE_VIDEO_MODULE
//
    //  KeystrokeEventParser.swift
    //  Notinhas
//
    //  Shared key-name resolution and shortcut filtering for live overlays
    //  and recorded keystroke metadata.
//

    import AppKit
    import Foundation

    struct ParsedKeystrokeEvent: Equatable {
        var modifiers: [String]
        var key: String
        var displayString: String
    }

    enum KeystrokeEventParser {
        static func parse(_ event: NSEvent) -> ParsedKeystrokeEvent? {
            guard !event.isARepeat else { return nil }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasCommand = flags.contains(.command)
            let hasOption = flags.contains(.option)
            let hasControl = flags.contains(.control)
            let hasShift = flags.contains(.shift)
            let hasModifier = hasCommand || hasOption || hasControl

            guard let keyName = keyDisplayName(for: event.keyCode, event: event) else { return nil }

            let isSpecialKey = specialKeyName(for: event.keyCode) != nil
            guard hasModifier || isSpecialKey else { return nil }

            var modifiers: [String] = []
            if hasControl {
                modifiers.append("⌃")
            }
            if hasOption {
                modifiers.append("⌥")
            }
            if hasShift {
                modifiers.append("⇧")
            }
            if hasCommand {
                modifiers.append("⌘")
            }

            var parts = modifiers
            parts.append(keyName)
            return ParsedKeystrokeEvent(
                modifiers: modifiers,
                key: keyName,
                displayString: parts.joined(separator: " "),
            )
        }

        static func keyDisplayName(for keyCode: UInt16, event: NSEvent) -> String? {
            if let special = specialKeyName(for: keyCode) {
                return special
            }

            let mapped = ShortcutConfig.keyCodeToDisplayString(UInt32(keyCode))
            if mapped != "?" {
                return mapped
            }

            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                return chars.uppercased()
            }

            return nil
        }

        static func specialKeyName(for keyCode: UInt16) -> String? {
            switch keyCode {
            case 36: "⏎"
            case 48: "⇥"
            case 49: "␣"
            case 51: "⌫"
            case 53: "⎋"
            case 76: "⌤"
            case 117: "⌦"
            case 123: "←"
            case 124: "→"
            case 125: "↓"
            case 126: "↑"
            case 122: "F1"
            case 120: "F2"
            case 99: "F3"
            case 118: "F4"
            case 96: "F5"
            case 97: "F6"
            case 98: "F7"
            case 100: "F8"
            case 101: "F9"
            case 109: "F10"
            case 103: "F11"
            case 111: "F12"
            case 115: "Home"
            case 119: "End"
            case 116: "PgUp"
            case 121: "PgDn"
            default: nil
            }
        }
    }
#endif

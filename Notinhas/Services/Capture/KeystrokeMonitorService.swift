#if NOTINHAS_VIDEO_MODULE
//
    //  KeystrokeMonitorService.swift
    //  Notinhas
//
    //  Detects global keyboard events and builds human-readable keystroke
    //  display strings (e.g. "⌘ ⇧ S") for the keystroke overlay.
//

    import AppKit
    import Foundation

    @MainActor
    final class KeystrokeMonitorService {
        private var globalKeyDownMonitor: Any?
        private var localKeyDownMonitor: Any?
        private var isRunning = false

        /// Called with the formatted keystroke string (e.g. "⌘ ⇧ S")
        var onKeystroke: ((String) -> Void)?

        func start() {
            guard !isRunning else { return }
            isRunning = true

            globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.keyDown],
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleKeyDown(event)
                }
            }

            localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.keyDown],
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleKeyDown(event)
                }
                return event
            }
        }

        func stop() {
            isRunning = false

            if let m = globalKeyDownMonitor {
                NSEvent.removeMonitor(m)
            }
            if let m = localKeyDownMonitor {
                NSEvent.removeMonitor(m)
            }
            globalKeyDownMonitor = nil
            localKeyDownMonitor = nil
            onKeystroke = nil
        }

        // MARK: - Event Processing

        private func handleKeyDown(_ event: NSEvent) {
            guard let parsed = KeystrokeEventParser.parse(event) else { return }
            onKeystroke?(parsed.displayString)
        }

        // MARK: - Key Code Mapping (legacy tests)

        /// Whether the keyCode is a special key (Return, Tab, arrows, function keys, etc.)
        static func isSpecialKey(_ keyCode: UInt16) -> Bool {
            KeystrokeEventParser.specialKeyName(for: keyCode) != nil
        }

        /// Resolve a display name for the given keyCode.
        static func keyDisplayName(for keyCode: UInt16, event: NSEvent) -> String? {
            KeystrokeEventParser.keyDisplayName(for: keyCode, event: event)
        }

        /// Maps macOS virtual key codes to human-readable special key symbols
        static func specialKeyName(for keyCode: UInt16) -> String? {
            KeystrokeEventParser.specialKeyName(for: keyCode)
        }
    }
#endif

//
//  CueShortcutsExporter.swift
//  Notinhas
//
//  Shortcut TOML export helpers.
//

import Foundation

@MainActor
extension CueConfigurationExporter {
    static func writeShortcuts(_ writer: inout SimpleTOMLWriter) {
        let manager = KeyboardShortcutManager.shared
        writer.section("shortcuts")
        writer.value("enabled", manager.isEnabled)

        for kind in GlobalShortcutKind.allCases {
            writeGlobalShortcut(&writer, kind: kind, manager: manager)
        }

        for mode in AllInOneCaptureMode.allCases {
            writeOverlayShortcut(
                &writer,
                section: "shortcuts.overlay.all_in_one.\(mode.rawValue)",
                shortcut: AllInOneModeShortcutSettings.shortcut(for: mode),
            )
        }
        writeOverlayShortcut(
            &writer,
            section: "shortcuts.overlay.recording_application_capture",
            shortcut: CaptureOverlayShortcutSettings.recordingApplicationCaptureShortcut,
        )

        writeQuickAccessShortcut(&writer)
        writeAnnotateToolShortcuts(&writer)
        writeAnnotateActionShortcuts(&writer)
    }

    private static func writeQuickAccessShortcut(_ writer: inout SimpleTOMLWriter) {
        let manager = QuickAccessManager.shared
        writer.section("shortcuts.quick_access.edit_latest_capture")
        writer.value("enabled", manager.openEditorShortcutEnabled)
        guard let shortcut = manager.openEditorShortcut else {
            writer.value("key", "")
            writer.stringArray("modifiers", [])
            return
        }
        writer.value("key", CueConfigurationShortcutCodec.exportKey(shortcut))
        writer.stringArray("modifiers", CueConfigurationShortcutCodec.exportModifiers(shortcut))
    }

    private static func writeGlobalShortcut(
        _ writer: inout SimpleTOMLWriter,
        kind: GlobalShortcutKind,
        manager: KeyboardShortcutManager,
    ) {
        writer.section("shortcuts.global.\(kind.configKey)")
        writer.value("enabled", manager.isShortcutEnabled(for: kind))

        guard let shortcut = manager.shortcut(for: kind) else {
            writer.value("key", "")
            writer.stringArray("modifiers", [])
            return
        }

        writer.value("key", CueConfigurationShortcutCodec.exportKey(shortcut))
        writer.stringArray("modifiers", CueConfigurationShortcutCodec.exportModifiers(shortcut))
    }

    private static func writeOverlayShortcut(
        _ writer: inout SimpleTOMLWriter,
        section: String,
        shortcut: CaptureOverlayShortcut?,
    ) {
        writer.section(section)
        guard let shortcut else {
            writer.value("enabled", false)
            writer.value("key", "")
            writer.stringArray("modifiers", [])
            return
        }

        writer.value("enabled", true)
        let config = ShortcutConfig(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        writer.value("key", CueConfigurationShortcutCodec.exportKey(config))
        writer.stringArray("modifiers", CueConfigurationShortcutCodec.exportModifiers(config))
    }

    private static func writeAnnotateToolShortcuts(_ writer: inout SimpleTOMLWriter) {
        let manager = AnnotateShortcutManager.shared
        writer.section("shortcuts.annotate_tools")
        writer.stringArray(
            "disabled",
            AnnotateShortcutManager.configurableTools
                .filter { !manager.isShortcutEnabled(for: $0) }
                .map(\.rawValue)
                .sorted(),
        )
        for tool in AnnotateShortcutManager.configurableTools {
            writer.value(String(tool.rawValue), manager.shortcut(for: tool).map(String.init) ?? "")
        }
    }

    private static func writeAnnotateActionShortcuts(_ writer: inout SimpleTOMLWriter) {
        let manager = AnnotateShortcutManager.shared
        writer.section("shortcuts.annotate_actions")
        writer.stringArray(
            "disabled",
            AnnotateActionShortcutKind.allCases
                .filter { !manager.isActionShortcutEnabled(for: $0) }
                .map(\.rawValue)
                .sorted(),
        )

        for kind in AnnotateActionShortcutKind.allCases {
            writer.section("shortcuts.annotate_actions.\(kind.configKey)")
            writer.value("enabled", manager.isActionShortcutEnabled(for: kind))
            guard let shortcut = manager.shortcut(for: kind) else {
                writer.value("key", "")
                writer.stringArray("modifiers", [])
                continue
            }
            writer.value("key", CueConfigurationShortcutCodec.exportKey(shortcut))
            writer.stringArray("modifiers", CueConfigurationShortcutCodec.exportModifiers(shortcut))
        }
    }
}

extension GlobalShortcutKind {
    var configKey: String {
        switch self {
        case .fullscreen: "fullscreen"
        case .area: "area"
        case .allInOne: "all_in_one"
        case .areaAnnotate: "area_annotate"
        case .activeWindow: "active_window"
        case .scrollingCapture: "scrolling_capture"
        case .recording: "recording"
        case .pauseResumeRecording: "pause_resume_recording"
        case .togglePenRecording: "toggle_pen_recording"
        case .restartRecording: "restart_recording"
        case .deleteRecording: "delete_recording"
        case .annotate: "annotate"
        case .videoEditor: "video_editor"
        case .shortcutList: "shortcut_list"
        case .ocr: "ocr"
        case .smartElement: "smart_element"
        case .objectCutout: "object_cutout"
        case .history: "history"
        }
    }
}

extension AnnotateActionShortcutKind {
    var configKey: String {
        switch self {
        case .copyAndClose: "copy_and_close"
        case .toggleSidebar: "toggle_sidebar"
        case .togglePin: "toggle_pin"
        case .autoRedactSensitiveData: "auto_redact_sensitive_data"
        }
    }
}

//
//  NotinhasConfigurationImporterTests.swift
//  NotinhasTests
//
//  Unit tests for TOML configuration import validation and application.
//

@testable import Notinhas
import XCTest

@MainActor
final class NotinhasConfigurationImporterTests: XCTestCase {
    func testImportAppliesCaptureAndRecordingSettingsToProvidedDefaults() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [capture.screenshot]
        format = "webp"
        show_cursor = true

        [recording]
        fps = 60
        show_camera_preview_during_recording = false
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        #if NOTINHAS_VIDEO_MODULE
            XCTAssertGreaterThanOrEqual(result.appliedChangeCount, 3)
        #else
            XCTAssertGreaterThanOrEqual(result.appliedChangeCount, 2)
        #endif
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "webp")
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotShowCursor) as? Bool, true)
        #if NOTINHAS_VIDEO_MODULE
            XCTAssertEqual(defaults.object(forKey: PreferencesKeys.recordingFPS) as? Int, 60)
            XCTAssertEqual(
                defaults.object(forKey: PreferencesKeys.recordingShowCameraPreviewDuringRecording) as? Bool,
                false,
            )
        #endif
    }

    func testImportAppliesImageUploadSettings() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [uploads]
        optimize_images = false
        image_format = "jpeg"
        maximum_dimension = 2560
        jpeg_quality = 0.73
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.uploadOptimizeImages) as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.uploadImageFormat), "jpeg")
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.uploadMaximumDimension) as? Int, 2560)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.uploadJPEGQuality) as? Double, 0.73)
    }

    func testImportRejectsImageUploadSettingsOutsideSupportedRanges() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [uploads]
        maximum_dimension = 256
        jpeg_quality = 1.1
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.appliedChangeCount, 0)
    }

    func testImportRejectsUnsupportedSchemaBeforeMutatingDefaults() {
        let defaults = UserDefaultsFactory.make()
        defaults.set("png", forKey: PreferencesKeys.screenshotFormat)
        let source = """
        schema_version = 99

        [capture.screenshot]
        format = "webp"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.appliedChangeCount, 0)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "png")
    }

    func testImportRejectsInvalidEnumsBeforeApplyingAnyMutation() {
        let defaults = UserDefaultsFactory.make()
        defaults.set("png", forKey: PreferencesKeys.screenshotFormat)
        let source = """
        schema_version = 1

        [capture.screenshot]
        format = "bmp"
        show_cursor = true
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.appliedChangeCount, 0)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "png")
        XCTAssertNil(defaults.object(forKey: PreferencesKeys.screenshotShowCursor))
    }

    func testImportRejectsUnknownShortcutModifiers() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [shortcuts.global.fullscreen]
        key = "3"
        modifiers = ["command", "hyper"]
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.appliedChangeCount, 0)
    }

    func testImportExpandsTildePathsAgainstUserHomeDirectory() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [general]
        export_location = "~/Desktop"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(
            defaults.string(forKey: PreferencesKeys.exportLocation),
            NotinhasConfigurationPaths.expandedUserPath("~/Desktop"),
        )
    }

    func testImportAppliesQuickAccessTwoFingerSwipeSetting() {
        let defaults = UserDefaultsFactory.make()
        let manager = QuickAccessManager.shared
        let original = manager.twoFingerSwipeToDismissEnabled
        manager.twoFingerSwipeToDismissEnabled = true
        defer { manager.twoFingerSwipeToDismissEnabled = original }
        let source = """
        schema_version = 1

        [quick_access]
        two_finger_swipe_to_dismiss = false
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertFalse(manager.twoFingerSwipeToDismissEnabled)
    }

    func testImportWithoutAnnotateShortcutSectionDoesNotResetActionEnablement() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        let original = manager.isActionShortcutEnabled(for: .copyAndClose)
        manager.setActionShortcutEnabled(false, for: .copyAndClose)
        defer { manager.setActionShortcutEnabled(original, for: .copyAndClose) }

        let source = """
        schema_version = 1

        [capture.screenshot]
        show_cursor = true
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertFalse(manager.isActionShortcutEnabled(for: .copyAndClose))
    }

    func testImportAnnotateToolAcceptsNumericShortcut() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_tools]
        rectangle = "1"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(manager.shortcut(for: .rectangle), "1")
    }

    func testImportAnnotateToolNormalizesUppercaseShortcut() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_tools]
        rectangle = "R"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(manager.shortcut(for: .rectangle), "r")
        XCTAssertEqual(manager.tool(for: "r"), .rectangle)
    }

    func testImportAnnotateToolAcceptsSpecialCharacterShortcut() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_tools]
        rectangle = "="
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(manager.shortcut(for: .rectangle), "=")
    }

    func testImportAnnotateToolAllowsEmptyShortcut() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        manager.setShortcut("9", for: .rectangle)
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_tools]
        rectangle = ""
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertNil(manager.shortcut(for: .rectangle))
    }

    func testImportAnnotateToolRejectsMultiCharacterShortcut() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        manager.setShortcut("9", for: .rectangle)
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_tools]
        rectangle = "12"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.appliedChangeCount, 0)
        XCTAssertEqual(manager.shortcut(for: .rectangle), "9")
    }

    func testImportAnnotateActionAllowsEmptyShortcutWhileEnabled() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_actions.auto_redact_sensitive_data]
        enabled = true
        key = ""
        modifiers = []
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertNil(manager.shortcut(for: .autoRedactSensitiveData))
        XCTAssertTrue(manager.isActionShortcutEnabled(for: .autoRedactSensitiveData))
    }

    func testImportAnnotateActionAppliesAutoRedactShortcut() {
        let defaults = UserDefaultsFactory.make()
        let manager = AnnotateShortcutManager.shared
        manager.resetToDefaults()
        defer { manager.resetToDefaults() }

        let source = """
        schema_version = 1

        [shortcuts.annotate_actions.auto_redact_sensitive_data]
        enabled = true
        key = "r"
        modifiers = ["command", "shift"]
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertNotNil(manager.shortcut(for: .autoRedactSensitiveData))
        XCTAssertTrue(manager.isActionShortcutEnabled(for: .autoRedactSensitiveData))
    }

    func testImportAppliesNewConfigurationFields() {
        let defaults = UserDefaultsFactory.make()
        let manager = QuickAccessManager.shared

        let originalHide = manager.hideCardWhenWindowOpen
        let originalStyle = manager.animationStyle
        let originalLeftAction = QuickAccessSwipeActionStore.shared.swipeLeftAction
        let originalRightAction = QuickAccessSwipeActionStore.shared.swipeRightAction
        let originalTrackpadMode = QuickAccessTrackpadSwipeModeStore.shared.mode

        defer {
            manager.hideCardWhenWindowOpen = originalHide
            manager.animationStyle = originalStyle
            QuickAccessSwipeActionStore.shared.setAction(.left, action: originalLeftAction)
            QuickAccessSwipeActionStore.shared.setAction(.right, action: originalRightAction)
            QuickAccessTrackpadSwipeModeStore.shared.setMode(originalTrackpadMode)
        }

        let source = """
        schema_version = 1

        [general]
        show_menu_bar_icon = false

        [capture.screenshot]
        freeze_area = true
        show_selection_area_overlay = false
        reverse_magnifier_zoom_direction = true

        [recording]
        video_editor_zoom_transition_duration = 0.55

        [annotate]
        combine_save_as_edit = false

        [quick_access]
        trackpad_swipe_mode = "natural"
        swipe_left_action = "pinToScreen"
        swipe_right_action = "none"
        hide_card_when_window_open = false
        animation_style = "scale"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)

        // general
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.showMenuBarIcon) as? Bool, false)

        // capture.screenshot
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotFreezeArea) as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotReverseMagnifierZoomDirection) as? Bool, true)

        // recording
        #if NOTINHAS_VIDEO_MODULE
            XCTAssertEqual(defaults.object(forKey: PreferencesKeys.videoEditorZoomTransitionDuration) as? Double, 0.55)
        #endif

        // annotate
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.annotateCombineSaveAsEdit) as? Bool, false)

        // quick access
        XCTAssertEqual(QuickAccessTrackpadSwipeModeStore.shared.mode, .natural)
        XCTAssertEqual(QuickAccessSwipeActionStore.shared.swipeLeftAction, .pinToScreen)
        XCTAssertNil(QuickAccessSwipeActionStore.shared.swipeRightAction)
        XCTAssertFalse(manager.hideCardWhenWindowOpen)
        XCTAssertEqual(manager.animationStyle, .scale)
    }

    #if NOTINHAS_VIDEO_MODULE
        func testImportRejectsOutOfRangeVideoEditorZoomTransitionDuration() {
            let defaults = UserDefaultsFactory.make()
            let source = """
            schema_version = 1

            [recording]
            video_editor_zoom_transition_duration = 10.0
            """

            let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)
            XCTAssertTrue(result.hasErrors)
            XCTAssertNil(defaults.object(forKey: PreferencesKeys.videoEditorZoomTransitionDuration))
        }
    #endif

    func testImportRejectsInvalidEnumValues() {
        let defaults = UserDefaultsFactory.make()

        let sourceInvalidTrackpad = """
        schema_version = 1
        [quick_access]
        trackpad_swipe_mode = "invalid_mode"
        """
        let result1 = NotinhasConfigurationImporter.importTOML(sourceInvalidTrackpad, defaults: defaults)
        XCTAssertTrue(result1.hasErrors)

        let sourceInvalidLeftAction = """
        schema_version = 1
        [quick_access]
        swipe_left_action = "invalid_action"
        """
        let result2 = NotinhasConfigurationImporter.importTOML(sourceInvalidLeftAction, defaults: defaults)
        XCTAssertTrue(result2.hasErrors)

        let sourceInvalidAnim = """
        schema_version = 1
        [quick_access]
        animation_style = "invalid_style"
        """
        let result3 = NotinhasConfigurationImporter.importTOML(sourceInvalidAnim, defaults: defaults)
        XCTAssertTrue(result3.hasErrors)
    }

    func testImportIgnoresLegacyUpdatesSectionWhileApplyingOtherFields() {
        let defaults = UserDefaultsFactory.make()
        defaults.set(true, forKey: PreferencesKeys.playSounds)
        defaults.set("stable", forKey: PreferencesKeys.updateChannel)

        let source = """
        schema_version = 1

        [general]
        play_sounds = false

        [updates]
        check_automatically = false
        download_automatically = true
        channel = "beta"
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(defaults.bool(forKey: PreferencesKeys.playSounds), false)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.updateChannel), "stable")
    }

    func testImportAcceptsLegacyIncludeSnapzyKeyAlias() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [capture.screenshot]
        include_snapzy = true
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotIncludeOwnApp) as? Bool, true)
    }

    func testImportAcceptsNotinhasIncludeOwnAppKey() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [capture.screenshot]
        include_own_app = true
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotIncludeOwnApp) as? Bool, true)
    }

    func testExportUsesNotinhasTomlKeys() {
        let exported = NotinhasConfigurationExporter.exportTOML(defaults: UserDefaultsFactory.make())

        XCTAssertTrue(exported.contains("notinhas_min_version"))
        XCTAssertTrue(exported.contains("include_own_app"))
        XCTAssertFalse(exported.contains("snapzy_min_version"))
        XCTAssertFalse(exported.contains("include_snapzy"))
    }

    func testImportSelectionSnappingKeys() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [capture.screenshot]
        selection_snap_distance = 12
        selection_color_sensitivity = 4
        show_selection_snap_guides = false
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.captureSelectionSnapDistance) as? Int, 12)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.captureSelectionColorSensitivity) as? Int, 4)
        XCTAssertEqual(defaults.object(forKey: PreferencesKeys.captureSelectionShowSnapGuides) as? Bool, false)
    }

    func testImportSelectionSnappingKeysClampOutOfRangeValues() {
        let defaults = UserDefaultsFactory.make()
        let source = """
        schema_version = 1

        [capture.screenshot]
        selection_snap_distance = 99
        selection_color_sensitivity = 0
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: defaults)

        XCTAssertTrue(result.hasErrors)
        XCTAssertNil(defaults.object(forKey: PreferencesKeys.captureSelectionSnapDistance))
        XCTAssertNil(defaults.object(forKey: PreferencesKeys.captureSelectionColorSensitivity))
    }

    func testValidateLegacyCloudActionsIgnoresRetiredValues() {
        let source = """
        schema_version = 1

        [quick_access]
        swipe_left_action = "uploadToCloud"

        [quick_access.slots]
        top_leading = "uploadToCloud"
        """

        XCTAssertFalse(NotinhasConfigurationImporter.validateTOML(source).contains { $0.severity == .error })
    }

    func testImportLegacyCloudEnabledActionsPreservesDefaults() {
        let store = QuickAccessActionConfigurationStore.shared
        let originalOrder = store.actionOrder
        let originalEnabledActions = store.enabledActions
        let originalSlotAssignments = store.slotAssignments
        defer {
            store.applyConfiguration(
                order: originalOrder,
                enabledActions: originalEnabledActions,
                slotAssignments: originalSlotAssignments,
            )
        }

        store.resetToDefaults()
        let source = """
        schema_version = 1

        [quick_access]
        enabled_actions = ["uploadToCloud"]
        """

        let result = NotinhasConfigurationImporter.importTOML(source, defaults: UserDefaultsFactory.make())

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(store.enabledActions, QuickAccessActionKind.defaultEnabledActions)
    }
}

//
//  CueServiceTests.swift
//  NotinhasTests
//
//  Tests for configuration file materialization.
//

@testable import Cue
import XCTest

@MainActor
final class CueConfigurationServiceTests: XCTestCase {
    func testConfigFileURLAppendsConfigTomlToSelectedDirectory() {
        let directory = URL(fileURLWithPath: "/Users/example/.config/snapzy", isDirectory: true)

        let url = CueConfigurationService.shared.configFileURL(inDirectory: directory)

        XCTAssertEqual(url.path, "/Users/example/.config/snapzy/config.toml")
    }

    func testSuggestedConfigDirectoryMatchingUsesCanonicalPath() {
        let expectedDirectory = CueConfigurationPaths.suggestedConfigDirectoryURL

        XCTAssertTrue(CueConfigurationService.shared.isSuggestedConfigDirectory(expectedDirectory))
        XCTAssertFalse(
            CueConfigurationService.shared.isSuggestedConfigDirectory(
                expectedDirectory.deletingLastPathComponent(),
            ),
        )
    }

    func testSuggestedConfigParentDirectoryMatchingUsesCanonicalPath() {
        let expectedParentDirectory = CueConfigurationPaths.suggestedConfigDirectoryURL
            .deletingLastPathComponent()

        XCTAssertTrue(CueConfigurationService.shared.isSuggestedConfigParentDirectory(expectedParentDirectory))
        XCTAssertFalse(
            CueConfigurationService.shared.isSuggestedConfigParentDirectory(
                expectedParentDirectory.appendingPathComponent("snapzy"),
            ),
        )
    }

    func testSuggestedConfigRootDirectoryMatchingUsesCanonicalPath() {
        let expectedRootDirectory = CueConfigurationPaths.userHomeDirectory

        XCTAssertTrue(CueConfigurationService.shared.isSuggestedConfigRootDirectory(expectedRootDirectory))
        XCTAssertFalse(
            CueConfigurationService.shared.isSuggestedConfigRootDirectory(
                expectedRootDirectory.appendingPathComponent(".config", isDirectory: true),
            ),
        )
    }

    func testEnsureConfigExistsCreatesParentDirectoryAndFile() throws {
        let homeDirectory = temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let url = CueConfigurationPaths.suggestedConfigURL(homeDirectory: homeDirectory)

        let returnedURL = try CueConfigurationService.shared.ensureConfigExists(at: url)

        XCTAssertEqual(returnedURL.path, url.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let source = try String(contentsOf: url, encoding: .utf8)
        let document = try SimpleTOMLParser.parse(source)
        XCTAssertEqual(document.value(at: "schema_version")?.intValue, 1)
        XCTAssertEqual(document.value(at: "quick_access", "two_finger_swipe_to_dismiss")?.boolValue, true)
    }

    func testExportIncludesQuickAccessTwoFingerSwipeSetting() throws {
        let manager = QuickAccessManager.shared
        let original = manager.twoFingerSwipeToDismissEnabled
        manager.twoFingerSwipeToDismissEnabled = false
        defer { manager.twoFingerSwipeToDismissEnabled = original }

        let source = CueConfigurationExporter.exportTOML(defaults: UserDefaultsFactory.make())
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertEqual(document.value(at: "quick_access", "two_finger_swipe_to_dismiss")?.boolValue, false)
    }

    func testExportIncludesQuickAccessCornerButtonScale() throws {
        let manager = QuickAccessManager.shared
        let original = manager.cornerButtonScale
        manager.cornerButtonScale = 1.5
        defer { manager.cornerButtonScale = original }

        let source = CueConfigurationExporter.exportTOML(defaults: UserDefaultsFactory.make())
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertEqual(document.value(at: "quick_access", "corner_button_scale")?.doubleValue, 1.5)
    }

    func testEnsureConfigExistsDoesNotOverwriteExistingFile() throws {
        let homeDirectory = temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let url = CueConfigurationPaths.suggestedConfigURL(homeDirectory: homeDirectory)
        let existingSource = """
        schema_version = 1

        [general]
        language = "system"
        """

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try existingSource.write(to: url, atomically: true, encoding: .utf8)

        try CueConfigurationService.shared.ensureConfigExists(at: url)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), existingSource)
    }

    func testImportBackupReplacingManagedConfigWritesSelectedTomlToManagedFile() throws {
        let directory = temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let backupURL = directory.appendingPathComponent("backup.toml")
        let managedURL = directory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("snapzy", isDirectory: true)
            .appendingPathComponent("config.toml")
        let source = "schema_version = 1\n"

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: backupURL, atomically: true, encoding: .utf8)

        let result = try CueConfigurationService.shared.importBackupReplacingManagedConfig(
            from: backupURL,
            managedConfigURL: managedURL,
        )

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), source)
    }

    func testImportBackupReplacingManagedConfigDoesNotOverwriteWhenInvalid() throws {
        let directory = temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let backupURL = directory.appendingPathComponent("invalid.toml")
        let managedURL = directory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("snapzy", isDirectory: true)
            .appendingPathComponent("config.toml")
        let existingSource = "schema_version = 1\n"
        let invalidSource = """
        schema_version = 99

        [capture.screenshot]
        format = "webp"
        """

        try FileManager.default.createDirectory(
            at: managedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try existingSource.write(to: managedURL, atomically: true, encoding: .utf8)
        try invalidSource.write(to: backupURL, atomically: true, encoding: .utf8)

        let result = try CueConfigurationService.shared.importBackupReplacingManagedConfig(
            from: backupURL,
            managedConfigURL: managedURL,
        )

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), existingSource)
    }

    func testSyncDecisionAlreadyCurrentWhenSourcesMatch() {
        let defaults = UserDefaultsFactory.make()
        let source = "schema_version = 1\n"

        let decision = CueConfigurationService.syncDecision(
            fileSource: source,
            currentSource: source,
            defaults: defaults,
        )

        XCTAssertEqual(decision, .alreadyCurrent)
    }

    func testSyncDecisionAutoSyncsWhenFileMatchesLastAppliedSignature() {
        let defaults = UserDefaultsFactory.make()
        let fileSource = "schema_version = 1\n"
        let currentSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"
        CueConfigurationAutoImporter.markCurrentFileApplied(fileSource, defaults: defaults)

        let decision = CueConfigurationService.syncDecision(
            fileSource: fileSource,
            currentSource: currentSource,
            defaults: defaults,
        )

        XCTAssertEqual(decision, .syncAutomatically)
    }

    func testSyncDecisionAsksBeforeReplacingExternallyChangedFile() {
        let defaults = UserDefaultsFactory.make()
        let fileSource = "schema_version = 1\n\n[general]\nplay_sounds = true\n"
        let currentSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

        let decision = CueConfigurationService.syncDecision(
            fileSource: fileSource,
            currentSource: currentSource,
            defaults: defaults,
        )

        XCTAssertEqual(decision, .askBeforeReplacing)
    }

    func testPrepareManagedConfigForOpeningCreatesMissingFileFromCurrentSettings() throws {
        try withRestoredLastAppliedSignature {
            let directory = temporaryHomeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let managedURL = directory.appendingPathComponent("config.toml")

            let result = try CueConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)

            XCTAssertEqual(result.status, .synced)
            XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
            let source = try String(contentsOf: managedURL, encoding: .utf8)
            XCTAssertTrue(CueConfigurationAutoImporter.isCurrentFileApplied(source))
        }
    }

    func testPrepareManagedConfigForOpeningAutoSyncsStaleAppOwnedFile() throws {
        try withRestoredLastAppliedSignature {
            let directory = temporaryHomeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let managedURL = directory.appendingPathComponent("config.toml")
            let staleSource = "schema_version = 1\n"

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try staleSource.write(to: managedURL, atomically: true, encoding: .utf8)
            CueConfigurationAutoImporter.markCurrentFileApplied(staleSource)

            let result = try CueConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)
            let syncedSource = try String(contentsOf: managedURL, encoding: .utf8)

            XCTAssertEqual(result.status, .synced)
            XCTAssertNotEqual(syncedSource, staleSource)
            XCTAssertTrue(CueConfigurationAutoImporter.isCurrentFileApplied(syncedSource))
        }
    }

    func testPrepareManagedConfigForOpeningDoesNotOverwriteExternalChangesWithoutConfirmation() throws {
        try withRestoredLastAppliedSignature {
            let directory = temporaryHomeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let managedURL = directory.appendingPathComponent("config.toml")
            let externalSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try externalSource.write(to: managedURL, atomically: true, encoding: .utf8)

            let result = try CueConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)

            XCTAssertEqual(result.status, .needsConfirmation)
            XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), externalSource)
        }
    }

    func testSyncManagedConfigToCurrentSettingsOverwritesAfterConfirmation() throws {
        try withRestoredLastAppliedSignature {
            let directory = temporaryHomeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let managedURL = directory.appendingPathComponent("config.toml")
            let externalSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try externalSource.write(to: managedURL, atomically: true, encoding: .utf8)

            try CueConfigurationService.shared.syncManagedConfigToCurrentSettings(at: managedURL)
            let syncedSource = try String(contentsOf: managedURL, encoding: .utf8)

            XCTAssertNotEqual(syncedSource, externalSource)
            XCTAssertTrue(CueConfigurationAutoImporter.isCurrentFileApplied(syncedSource))
        }
    }

    func testSyncManagedConfigToCurrentSettingsIfUnchangedOverwritesApprovedFile() throws {
        try withRestoredLastAppliedSignature {
            let directory = temporaryHomeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let managedURL = directory.appendingPathComponent("config.toml")
            let externalSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try externalSource.write(to: managedURL, atomically: true, encoding: .utf8)

            let result = try CueConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)
            try CueConfigurationService.shared.syncManagedConfigToCurrentSettingsIfUnchanged(
                at: managedURL,
                expectedFileSignature: result.observedFileSignature,
            )

            let syncedSource = try String(contentsOf: managedURL, encoding: .utf8)
            XCTAssertNotEqual(syncedSource, externalSource)
            XCTAssertTrue(CueConfigurationAutoImporter.isCurrentFileApplied(syncedSource))
        }
    }

    func testSyncManagedConfigToCurrentSettingsIfUnchangedDoesNotOverwriteChangedFile() throws {
        try withRestoredLastAppliedSignature {
            let directory = temporaryHomeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let managedURL = directory.appendingPathComponent("config.toml")
            let approvedSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"
            let changedSource = "schema_version = 1\n\n[general]\nplay_sounds = true\n"

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try approvedSource.write(to: managedURL, atomically: true, encoding: .utf8)

            let result = try CueConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)
            try changedSource.write(to: managedURL, atomically: true, encoding: .utf8)

            XCTAssertThrowsError(
                try CueConfigurationService.shared.syncManagedConfigToCurrentSettingsIfUnchanged(
                    at: managedURL,
                    expectedFileSignature: result.observedFileSignature,
                ),
            ) { error in
                XCTAssertTrue(error is CueConfigurationSyncError)
            }
            XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), changedSource)
        }
    }

    func testExportIncludesNewConfigurationFields() throws {
        let defaults = UserDefaultsFactory.make()
        defaults.set(false, forKey: PreferencesKeys.showMenuBarIcon)
        defaults.set(true, forKey: PreferencesKeys.screenshotFreezeArea)
        defaults.set(false, forKey: PreferencesKeys.screenshotShowSelectionAreaOverlay)
        defaults.set(true, forKey: PreferencesKeys.screenshotReverseMagnifierZoomDirection)
        defaults.set(0.65, forKey: PreferencesKeys.videoEditorZoomTransitionDuration)
        defaults.set(false, forKey: PreferencesKeys.annotateCombineSaveAsEdit)

        let manager = QuickAccessManager.shared
        let originalHide = manager.hideCardWhenWindowOpen
        let originalStyle = manager.animationStyle
        let originalLeftAction = QuickAccessSwipeActionStore.shared.swipeLeftAction
        let originalRightAction = QuickAccessSwipeActionStore.shared.swipeRightAction
        let originalTrackpadMode = QuickAccessTrackpadSwipeModeStore.shared.mode

        manager.hideCardWhenWindowOpen = false
        manager.animationStyle = .scale
        QuickAccessSwipeActionStore.shared.setAction(.left, action: .pinToScreen)
        QuickAccessSwipeActionStore.shared.setAction(.right, action: nil)
        QuickAccessTrackpadSwipeModeStore.shared.setMode(.natural)

        defer {
            manager.hideCardWhenWindowOpen = originalHide
            manager.animationStyle = originalStyle
            QuickAccessSwipeActionStore.shared.setAction(.left, action: originalLeftAction)
            QuickAccessSwipeActionStore.shared.setAction(.right, action: originalRightAction)
            QuickAccessTrackpadSwipeModeStore.shared.setMode(originalTrackpadMode)
        }

        let source = CueConfigurationExporter.exportTOML(defaults: defaults)
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertEqual(document.value(at: "general", "show_menu_bar_icon")?.boolValue, false)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "freeze_area")?.boolValue, true)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "show_selection_area_overlay")?.boolValue, false)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "reverse_magnifier_zoom_direction")?.boolValue, true)
        #if CUE_VIDEO_MODULE
            XCTAssertEqual(document.value(at: "recording", "video_editor_zoom_transition_duration")?.doubleValue, 0.65)
        #endif
        XCTAssertEqual(document.value(at: "annotate", "combine_save_as_edit")?.boolValue, false)
        XCTAssertEqual(document.value(at: "quick_access", "trackpad_swipe_mode")?.stringValue, "natural")
        XCTAssertEqual(document.value(at: "quick_access", "swipe_left_action")?.stringValue, "pinToScreen")
        XCTAssertEqual(document.value(at: "quick_access", "swipe_right_action")?.stringValue, "none")
        XCTAssertEqual(document.value(at: "quick_access", "hide_card_when_window_open")?.boolValue, false)
        XCTAssertEqual(document.value(at: "quick_access", "animation_style")?.stringValue, "scale")
    }

    func testExportOmitsLegacyUpdatesSection() throws {
        let defaults = UserDefaultsFactory.make()
        defaults.set("beta", forKey: PreferencesKeys.updateChannel)

        let source = CueConfigurationExporter.exportTOML(defaults: defaults)
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertNil(document.value(at: "updates", "check_automatically"))
        XCTAssertNil(document.value(at: "updates", "download_automatically"))
        XCTAssertNil(document.value(at: "updates", "channel"))
    }

    func testDefaultDocumentIncludesSelectionSnappingKeys() throws {
        let source = CueConfigurationDefaultDocument.toml()
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertEqual(document.value(at: "capture", "screenshot", "selection_snap_distance")?.intValue, 5)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "selection_color_sensitivity")?.intValue, 3)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "show_selection_snap_guides")?.boolValue, true)
        XCTAssertEqual(document.value(at: "uploads", "optimize_images")?.boolValue, true)
        XCTAssertEqual(document.value(at: "uploads", "image_format")?.stringValue, "webp")
        XCTAssertEqual(document.value(at: "uploads", "maximum_dimension")?.intValue, 2048)
        XCTAssertEqual(document.value(at: "uploads", "jpeg_quality")?.doubleValue, 0.9)
    }

    func testExportIncludesSelectionSnappingKeys() throws {
        let defaults = UserDefaultsFactory.make()
        defaults.set(8, forKey: PreferencesKeys.captureSelectionSnapDistance)
        defaults.set(2, forKey: PreferencesKeys.captureSelectionColorSensitivity)
        defaults.set(false, forKey: PreferencesKeys.captureSelectionShowSnapGuides)

        let source = CueConfigurationExporter.exportTOML(defaults: defaults)
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertEqual(document.value(at: "capture", "screenshot", "selection_snap_distance")?.intValue, 8)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "selection_color_sensitivity")?.intValue, 2)
        XCTAssertEqual(document.value(at: "capture", "screenshot", "show_selection_snap_guides")?.boolValue, false)
    }

    func testExportIncludesImageUploadSettings() throws {
        let defaults = UserDefaultsFactory.make()
        defaults.set(false, forKey: PreferencesKeys.uploadOptimizeImages)
        defaults.set("jpeg", forKey: PreferencesKeys.uploadImageFormat)
        defaults.set(2560, forKey: PreferencesKeys.uploadMaximumDimension)
        defaults.set(0.73, forKey: PreferencesKeys.uploadJPEGQuality)

        let source = CueConfigurationExporter.exportTOML(defaults: defaults)
        let document = try SimpleTOMLParser.parse(source)

        XCTAssertEqual(document.value(at: "uploads", "optimize_images")?.boolValue, false)
        XCTAssertEqual(document.value(at: "uploads", "image_format")?.stringValue, "jpeg")
        XCTAssertEqual(document.value(at: "uploads", "maximum_dimension")?.intValue, 2560)
        XCTAssertEqual(document.value(at: "uploads", "jpeg_quality")?.doubleValue, 0.73)
    }

    private func temporaryHomeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("snapzy-config-service-\(UUID().uuidString)", isDirectory: true)
    }

    private func withRestoredLastAppliedSignature(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let key = PreferencesKeys.configurationLastAppliedSignature
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        try body()
    }
}

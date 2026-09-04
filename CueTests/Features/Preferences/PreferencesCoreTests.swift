//
//  PreferencesCoreTests.swift
//  NotinhasTests
//
//  Unit tests for persisted preferences value models.
//

import AppKit
import CoreGraphics
@testable import Cue
import ImageIO
import XCTest

final class PreferencesCoreTests: XCTestCase {
    func testHistoryBackgroundStyleStored_readsValidValueAndFallsBackToDefault() throws {
        let defaults = try makeDefaults()
        XCTAssertEqual(HistoryBackgroundStyle.currentStoredStyle(userDefaults: defaults), .hud)

        defaults.set(HistoryBackgroundStyle.solid.rawValue, forKey: PreferencesKeys.historyBackgroundStyle)
        XCTAssertEqual(HistoryBackgroundStyle.currentStoredStyle(userDefaults: defaults), .solid)

        defaults.set("invalid", forKey: PreferencesKeys.historyBackgroundStyle)
        XCTAssertEqual(HistoryBackgroundStyle.currentStoredStyle(userDefaults: defaults), .hud)
    }

    func testAnnotateClipboardImageBehaviorStored_readsValidValueAndFallsBackToAsk() throws {
        let defaults = try makeDefaults()
        XCTAssertEqual(AnnotateClipboardImageBehavior.stored(userDefaults: defaults), .ask)

        defaults.set(
            AnnotateClipboardImageBehavior.loadAutomatically.rawValue,
            forKey: PreferencesKeys.annotateClipboardImageOpenBehavior,
        )
        XCTAssertEqual(AnnotateClipboardImageBehavior.stored(userDefaults: defaults), .loadAutomatically)

        defaults.set("invalid", forKey: PreferencesKeys.annotateClipboardImageOpenBehavior)
        XCTAssertEqual(AnnotateClipboardImageBehavior.stored(userDefaults: defaults), .ask)
    }

    func testAnnotateQuickPropertiesSyncPreference_defaultsToEnabled() throws {
        let defaults = try makeDefaults()
        XCTAssertTrue(AnnotateQuickPropertiesSyncPreference.isEnabled(userDefaults: defaults))

        defaults.set(false, forKey: PreferencesKeys.annotateQuickPropertiesSyncEnabled)
        XCTAssertFalse(AnnotateQuickPropertiesSyncPreference.isEnabled(userDefaults: defaults))

        defaults.set(true, forKey: PreferencesKeys.annotateQuickPropertiesSyncEnabled)
        XCTAssertTrue(AnnotateQuickPropertiesSyncPreference.isEnabled(userDefaults: defaults))
    }

    func testCombineSaveAsEditPreference_defaultsToEnabled() throws {
        let defaults = try makeDefaults()
        XCTAssertTrue(CombineSaveAsEditPreference.isEnabled(userDefaults: defaults))

        defaults.set(false, forKey: PreferencesKeys.annotateCombineSaveAsEdit)
        XCTAssertFalse(CombineSaveAsEditPreference.isEnabled(userDefaults: defaults))

        defaults.set(true, forKey: PreferencesKeys.annotateCombineSaveAsEdit)
        XCTAssertTrue(CombineSaveAsEditPreference.isEnabled(userDefaults: defaults))
    }

    func testPreferencesTabsRemainUniqueAndHashable() {
        let tabs: Set<PreferencesTab> = [
            .general,
            .capture,
            .annotate,
            .quickAccess,
            .history,
            .shortcuts,
            .permissions,
            .advanced,
        ]

        XCTAssertEqual(tabs.count, 8)
    }

    func testPreferencesNumericPickerValue_sanitizesAndBoundsCustomInput() {
        XCTAssertEqual(
            PreferencesNumericPickerValue.sanitizedText("1,5 seconds", allowsFraction: true),
            "1.5",
        )
        XCTAssertEqual(
            PreferencesNumericPickerValue.sanitizedText("12.5", allowsFraction: false),
            "125",
        )
        XCTAssertEqual(
            PreferencesNumericPickerValue.normalizedValue(
                from: "99",
                range: 0.5 ... 5.0,
                step: 0.5,
            ),
            5.0,
        )
        XCTAssertEqual(
            PreferencesNumericPickerValue.normalizedValue(
                from: "invalid",
                range: 1 ... 20,
                step: 1,
            ),
            nil,
        )
        XCTAssertEqual(
            PreferencesNumericPickerValue.normalizedValue(
                from: "50",
                range: 0.2 ... 1.0,
                step: 0.05,
                inputScale: 100,
            ),
            0.5,
        )
    }

    @MainActor
    func testSelectedPreferencesTab_persistsAcrossLaunches() throws {
        let defaults = try makeDefaults()
        let state = PreferencesNavigationState(userDefaults: defaults)
        XCTAssertEqual(state.selectedTab, .general)

        state.selectedTab = .shortcuts
        XCTAssertEqual(
            defaults.string(forKey: PreferencesKeys.selectedPreferencesTab),
            PreferencesTab.shortcuts.rawValue,
        )

        let relaunched = PreferencesNavigationState(userDefaults: defaults)
        XCTAssertEqual(relaunched.selectedTab, .shortcuts)
    }

    @MainActor
    func testSelectedPreferencesTab_fallsBackToGeneralForMissingOrInvalidValue() throws {
        let defaults = try makeDefaults()
        XCTAssertEqual(PreferencesNavigationState(userDefaults: defaults).selectedTab, .general)

        defaults.set("not-a-tab", forKey: PreferencesKeys.selectedPreferencesTab)
        XCTAssertEqual(PreferencesNavigationState(userDefaults: defaults).selectedTab, .general)
    }

    func testTotalLogFileSize_sumsFilesAndIgnoresMissingDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreferencesCoreTests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try Data(repeating: 0x41, count: 1024).write(to: tempDir.appendingPathComponent("a.log"))
        try Data(repeating: 0x42, count: 2048).write(to: tempDir.appendingPathComponent("b.log"))

        XCTAssertEqual(DiagnosticLogger.totalLogFileSize(at: tempDir), 3072)
        XCTAssertEqual(
            DiagnosticLogger.totalLogFileSize(at: tempDir.appendingPathComponent("missing")),
            0,
        )
    }

    @MainActor
    func testDownsampledPreviewImage_boundsLongestEdge() async throws {
        let sourceURL = try makeLargeJPEG()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let image = await SystemWallpaperManager.downsampledPreviewImage(at: sourceURL, maxPixelSize: 256)
        let size = try XCTUnwrap(image?.size)
        XCTAssertLessThanOrEqual(max(size.width, size.height), 256)
    }

    @MainActor
    func testDownsampledPreviewImage_coalescesCachesAndRetriesFailures() async throws {
        let sourceURL = try makeLargeJPEG()
        let retryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreferencesCoreTests.\(UUID().uuidString).jpg")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: retryURL)
        }

        async let firstRequest = SystemWallpaperManager.downsampledPreviewImage(at: sourceURL, maxPixelSize: 256)
        async let secondRequest = SystemWallpaperManager.downsampledPreviewImage(at: sourceURL, maxPixelSize: 256)
        let (firstResult, secondResult) = await (firstRequest, secondRequest)
        let firstImage = try XCTUnwrap(firstResult)
        let secondImage = try XCTUnwrap(secondResult)
        XCTAssertTrue(firstImage === secondImage)

        let cachedResult = await SystemWallpaperManager.downsampledPreviewImage(at: sourceURL, maxPixelSize: 256)
        let cachedImage = try XCTUnwrap(cachedResult)
        XCTAssertTrue(firstImage === cachedImage)

        let differentSizeResult = await SystemWallpaperManager.downsampledPreviewImage(at: sourceURL, maxPixelSize: 128)
        let differentSizeImage = try XCTUnwrap(differentSizeResult)
        XCTAssertFalse(firstImage === differentSizeImage)

        let failedImage = await SystemWallpaperManager.downsampledPreviewImage(at: retryURL, maxPixelSize: 192)
        XCTAssertNil(failedImage)
        try FileManager.default.copyItem(at: sourceURL, to: retryURL)
        let retriedImage = await SystemWallpaperManager.downsampledPreviewImage(at: retryURL, maxPixelSize: 192)
        XCTAssertNotNil(retriedImage)
    }

    private func makeLargeJPEG() throws -> URL {
        let width = 1200
        let height = 800
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else {
            throw XCTSkip("Unable to create test bitmap context")
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            throw XCTSkip("Unable to render test image")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreferencesCoreTests.\(UUID().uuidString).jpg")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            throw XCTSkip("Unable to create test JPEG destination")
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw XCTSkip("Unable to finalize test JPEG")
        }
        return url
    }

    private func makeDefaults(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) throws -> UserDefaults {
        let suiteName = "NotinhasTests.PreferencesCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName), file: file, line: line)
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

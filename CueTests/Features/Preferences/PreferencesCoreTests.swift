//
//  PreferencesCoreTests.swift
//  NotinhasTests
//
//  Unit tests for persisted preferences value models.
//

@testable import Cue
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

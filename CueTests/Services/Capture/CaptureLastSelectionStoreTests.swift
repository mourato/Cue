//
//  CaptureLastSelectionStoreTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

final class CaptureLastSelectionStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaultsFactory.make()
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    func testSaveAndLoad_roundTripsRect() {
        let rect = CGRect(x: 120, y: 240, width: 640, height: 360)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        CaptureLastSelectionStore.save(rect, userDefaults: defaults)

        let loaded = CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens)

        XCTAssertEqual(loaded, CaptureSelectionGeometry.normalized(rect))
    }

    func testLoad_returnsNilWhenDefaultsAreEmpty() {
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        XCTAssertNil(CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens))
    }

    func testIsEnabled_defaultsToTrueAndHonorsPreference() {
        XCTAssertTrue(CaptureLastSelectionStore.isEnabled(userDefaults: defaults))

        defaults.set(false, forKey: PreferencesKeys.captureAllInOneRememberLastSelection)

        XCTAssertFalse(CaptureLastSelectionStore.isEnabled(userDefaults: defaults))
    }

    func testIsEnabled_fallsBackToLegacyRecordingPreference() {
        defaults.set(false, forKey: PreferencesKeys.recordingRememberLastArea)

        XCTAssertFalse(CaptureLastSelectionStore.isEnabled(userDefaults: defaults))
    }

    func testIsEnabled_prefersSharedPreferenceOverLegacyRecordingValue() {
        defaults.set(true, forKey: PreferencesKeys.captureAllInOneRememberLastSelection)
        defaults.set(false, forKey: PreferencesKeys.recordingRememberLastArea)

        XCTAssertTrue(CaptureLastSelectionStore.isEnabled(userDefaults: defaults))
    }

    func testMigrateLegacyRecordingPreference_copiesMissingSharedValueOnce() {
        defaults.set(false, forKey: PreferencesKeys.recordingRememberLastArea)

        CaptureLastSelectionStore.migrateLegacyRecordingPreferenceIfNeeded(userDefaults: defaults)

        XCTAssertEqual(
            defaults.object(forKey: PreferencesKeys.captureAllInOneRememberLastSelection) as? Bool,
            false
        )
    }

    func testMigrateLegacyRecordingPreference_keepsExistingSharedValue() {
        defaults.set(true, forKey: PreferencesKeys.captureAllInOneRememberLastSelection)
        defaults.set(false, forKey: PreferencesKeys.recordingRememberLastArea)

        CaptureLastSelectionStore.migrateLegacyRecordingPreferenceIfNeeded(userDefaults: defaults)

        XCTAssertEqual(
            defaults.object(forKey: PreferencesKeys.captureAllInOneRememberLastSelection) as? Bool,
            true
        )
    }

    func testRestoredRect_requiresEnabledPreference() {
        let rect = CGRect(x: 120, y: 240, width: 640, height: 360)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        CaptureLastSelectionStore.save(rect, userDefaults: defaults)
        defaults.set(false, forKey: PreferencesKeys.captureAllInOneRememberLastSelection)

        XCTAssertNil(CaptureLastSelectionStore.restoredRect(userDefaults: defaults, screens: screens))
    }

    func testSave_writesSharedKeyInsteadOfLegacyRecordingKey() {
        let rect = CGRect(x: 120, y: 240, width: 640, height: 360)

        CaptureLastSelectionStore.save(rect, userDefaults: defaults)

        XCTAssertNotNil(defaults.dictionary(forKey: PreferencesKeys.captureAllInOneLastAreaRect))
        XCTAssertNil(defaults.dictionary(forKey: PreferencesKeys.recordingLastAreaRect))
    }

    func testLoad_fallsBackToLegacyRecordingArea() {
        let rect = CGRect(x: 120, y: 240, width: 640, height: 360)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        defaults.set(
            ["x": rect.origin.x, "y": rect.origin.y, "width": rect.width, "height": rect.height],
            forKey: PreferencesKeys.recordingLastAreaRect
        )

        XCTAssertEqual(CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens), rect)
    }

    func testLoad_prefersSharedAreaOverLegacyRecordingArea() {
        let shared = CGRect(x: 10, y: 20, width: 300, height: 200)
        let legacy = CGRect(x: 400, y: 400, width: 100, height: 100)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        CaptureLastSelectionStore.save(shared, userDefaults: defaults)
        defaults.set(
            ["x": legacy.origin.x, "y": legacy.origin.y, "width": legacy.width, "height": legacy.height],
            forKey: PreferencesKeys.recordingLastAreaRect
        )

        XCTAssertEqual(CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens), shared)
    }

    func testLoad_rejectsInvalidSharedAreaWithoutUsingLegacyFallback() {
        let legacy = CGRect(x: 10, y: 20, width: 300, height: 200)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        defaults.set(
            ["x": CGFloat.infinity, "y": 20, "width": 300, "height": 200],
            forKey: PreferencesKeys.captureAllInOneLastAreaRect
        )
        defaults.set(
            ["x": legacy.origin.x, "y": legacy.origin.y, "width": legacy.width, "height": legacy.height],
            forKey: PreferencesKeys.recordingLastAreaRect
        )

        XCTAssertNil(CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens))
    }

    func testLoad_rejectsRectThatDoesNotIntersectAnyScreen() {
        let rect = CGRect(x: 5000, y: 5000, width: 200, height: 200)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        CaptureLastSelectionStore.save(rect, userDefaults: defaults)

        XCTAssertNil(CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens))
    }

    func testLoad_rejectsNonFiniteOrNonPositiveDimensions() {
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        defaults.set(
            ["x": CGFloat.infinity, "y": 100, "width": 0, "height": 200],
            forKey: PreferencesKeys.captureAllInOneLastAreaRect
        )

        XCTAssertNil(CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens))
    }

    func testLoad_acceptsRectThatPartiallyIntersectsAScreen() throws {
        let rect = CGRect(x: 1400, y: 800, width: 200, height: 200)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        CaptureLastSelectionStore.save(rect, userDefaults: defaults)

        let loaded = CaptureLastSelectionStore.load(userDefaults: defaults, screens: screens)

        XCTAssertNotNil(loaded)
        XCTAssertTrue(try screens[0].intersects(XCTUnwrap(loaded)))
    }

    func testIsRectVisibleOnScreens_requiresIntersection() {
        let onScreen = CGRect(x: 100, y: 100, width: 200, height: 200)
        let offScreen = CGRect(x: 3000, y: 3000, width: 200, height: 200)
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        XCTAssertTrue(CaptureLastSelectionStore.isRectVisibleOnScreens(onScreen, screens: screens))
        XCTAssertFalse(CaptureLastSelectionStore.isRectVisibleOnScreens(offScreen, screens: screens))
    }
}

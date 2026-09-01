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
            forKey: PreferencesKeys.captureAllInOneLastAreaRect,
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

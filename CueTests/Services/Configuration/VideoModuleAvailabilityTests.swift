//
//  VideoModuleAvailabilityTests.swift
//  NotinhasTests
//
//  Tests for compile-time and runtime Video module availability.
//

@testable import Cue
import XCTest

final class VideoModuleAvailabilityTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaultsFactory.make()
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    func testRuntimeDefaultIsOffWhenKeyUnset() {
        defaults.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
        XCTAssertFalse(VideoModuleAvailability.isEnabled(using: defaults))
    }

    func testSetEnabledRoundTrip() throws {
        try XCTSkipUnless(
            VideoModuleAvailability.isCompiledIn,
            "Requires CUE_VIDEO_MODULE (Notinhas Video / Debug+Video)",
        )

        XCTAssertFalse(VideoModuleAvailability.isEnabled(using: defaults))

        VideoModuleAvailability.setEnabled(true, using: defaults)
        XCTAssertTrue(VideoModuleAvailability.isEnabled(using: defaults))

        VideoModuleAvailability.setEnabled(false, using: defaults)
        XCTAssertFalse(VideoModuleAvailability.isEnabled(using: defaults))
    }

    func testDisabledWhenNotCompiledIn() throws {
        try XCTSkipUnless(
            !VideoModuleAvailability.isCompiledIn,
            "Only meaningful on default Notinhas builds without CUE_VIDEO_MODULE",
        )

        defaults.set(true, forKey: PreferencesKeys.videoModuleEnabled)
        VideoModuleAvailability.setEnabled(true, using: defaults)
        XCTAssertFalse(VideoModuleAvailability.isEnabled(using: defaults))
    }
}

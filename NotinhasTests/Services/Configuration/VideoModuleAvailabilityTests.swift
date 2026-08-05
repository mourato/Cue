//
//  VideoModuleAvailabilityTests.swift
//  NotinhasTests
//
//  Tests for compile-time and runtime Video module availability.
//

@testable import Notinhas
import XCTest

final class VideoModuleAvailabilityTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
        super.tearDown()
    }

    func testRuntimeDefaultIsOffWhenKeyUnset() {
        UserDefaults.standard.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
        XCTAssertFalse(VideoModuleAvailability.isEnabled)
    }

    func testSetEnabledRoundTrip() throws {
        try XCTSkipUnless(
            VideoModuleAvailability.isCompiledIn,
            "Requires NOTINHAS_VIDEO_MODULE (Notinhas Video / Debug+Video)",
        )

        XCTAssertFalse(VideoModuleAvailability.isEnabled)

        VideoModuleAvailability.setEnabled(true)
        XCTAssertTrue(VideoModuleAvailability.isEnabled)

        VideoModuleAvailability.setEnabled(false)
        XCTAssertFalse(VideoModuleAvailability.isEnabled)
    }

    func testDisabledWhenNotCompiledIn() throws {
        try XCTSkipUnless(
            !VideoModuleAvailability.isCompiledIn,
            "Only meaningful on default Notinhas builds without NOTINHAS_VIDEO_MODULE",
        )

        UserDefaults.standard.set(true, forKey: PreferencesKeys.videoModuleEnabled)
        VideoModuleAvailability.setEnabled(true)
        XCTAssertFalse(VideoModuleAvailability.isEnabled)
    }
}

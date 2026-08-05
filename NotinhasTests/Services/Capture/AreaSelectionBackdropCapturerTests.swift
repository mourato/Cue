//
//  AreaSelectionBackdropCapturerTests.swift
//  NotinhasTests
//
//  Unit tests for backdrop capturer policy and synthetic captures (no Screen Recording TCC).
//

import CoreGraphics
@testable import Notinhas
import XCTest

final class AreaSelectionBackdropCapturerTests: XCTestCase {
    func testPolicy_outsideXCTest_usesLiveCapturer() {
        XCTAssertTrue(
            AreaSelectionBackdropCapturerPolicy.shouldUseLiveCapturer(
                environment: [:],
                xctestRuntimePresent: { false },
            ),
        )
        XCTAssertTrue(
            AreaSelectionBackdropCapturerPolicy.makeDefault(
                environment: [:],
                xctestRuntimePresent: { false },
            ) is LiveAreaSelectionBackdropCapturer,
        )
    }

    func testPolicy_underXCTest_defaultsToSynthetic() {
        XCTAssertFalse(
            AreaSelectionBackdropCapturerPolicy.shouldUseLiveCapturer(
                environment: ["XCTestConfigurationFilePath": "/tmp/NotinhasTests.xctestconfiguration"],
                xctestRuntimePresent: { false },
            ),
        )
        XCTAssertTrue(
            AreaSelectionBackdropCapturerPolicy.makeDefault(
                environment: ["XCTestConfigurationFilePath": "/tmp/NotinhasTests.xctestconfiguration"],
                xctestRuntimePresent: { false },
            ) is SyntheticAreaSelectionBackdropCapturer,
        )
    }

    func testPolicy_underXCTest_canOptInLiveCapturer() {
        let environment = [
            "XCTestConfigurationFilePath": "/tmp/NotinhasTests.xctestconfiguration",
            AreaSelectionBackdropCapturerPolicy.allowScreenCaptureInTestsEnvironmentKey: "1",
        ]
        XCTAssertTrue(
            AreaSelectionBackdropCapturerPolicy.shouldUseLiveCapturer(
                environment: environment,
                xctestRuntimePresent: { false },
            ),
        )
        XCTAssertTrue(
            AreaSelectionBackdropCapturerPolicy.makeDefault(
                environment: environment,
                xctestRuntimePresent: { false },
            ) is LiveAreaSelectionBackdropCapturer,
        )
    }

    func testSyntheticCapturer_returnsBackdropWithoutScreenCaptureAPIs() async throws {
        let capturer = SyntheticAreaSelectionBackdropCapturer(pixelSize: 32)
        let backdrop = await capturer.captureBackdrop(
            displayID: 7,
            captureRect: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            scaleFactor: 2,
            isVisible: false,
        )

        let unwrapped = try XCTUnwrap(backdrop)
        XCTAssertEqual(unwrapped.displayID, 7)
        XCTAssertEqual(unwrapped.scaleFactor, 2)
        XCTAssertFalse(unwrapped.isVisible)
        XCTAssertEqual(unwrapped.image.width, 32)
        XCTAssertEqual(unwrapped.image.height, 32)
    }
}

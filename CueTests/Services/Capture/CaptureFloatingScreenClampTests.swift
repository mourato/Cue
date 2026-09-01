//
//  CaptureFloatingScreenClampTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

final class CaptureFloatingScreenClampTests: XCTestCase {
    func testClampedOrigin_clampsWithinRange() {
        XCTAssertEqual(
            CaptureFloatingScreenClamp.clampedOrigin(50, minimum: 10, maximum: 100),
            50,
        )
        XCTAssertEqual(
            CaptureFloatingScreenClamp.clampedOrigin(5, minimum: 10, maximum: 100),
            10,
        )
        XCTAssertEqual(
            CaptureFloatingScreenClamp.clampedOrigin(150, minimum: 10, maximum: 100),
            100,
        )
    }

    func testClampedOrigin_reversedRangeReturnsMinimum() {
        XCTAssertEqual(
            CaptureFloatingScreenClamp.clampedOrigin(75, minimum: 100, maximum: 10),
            100,
        )
    }

    func testClampedOrigin_equalBoundsReturnsBound() {
        XCTAssertEqual(
            CaptureFloatingScreenClamp.clampedOrigin(42, minimum: 50, maximum: 50),
            50,
        )
    }
}

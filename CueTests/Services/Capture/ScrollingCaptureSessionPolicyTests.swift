//
//  ScrollingCaptureSessionPolicyTests.swift
//  NotinhasTests
//
//  Unit tests for scrolling capture scroll acceptance and streaming commits.
//

@testable import Cue
import XCTest

final class ScrollingCaptureSessionPolicyTests: XCTestCase {
    func testPreciseVerticalScrollPassesThroughUnscaled() {
        XCTAssertEqual(
            ScrollingCaptureSessionPolicy.scaledScrollDeltaY(
                deltaX: 0,
                deltaY: -12,
                hasPreciseDeltas: true,
            ),
            -12,
        )
    }

    func testImpreciseWheelScrollScalesUp() {
        XCTAssertEqual(
            ScrollingCaptureSessionPolicy.scaledScrollDeltaY(
                deltaX: 0,
                deltaY: -1,
                hasPreciseDeltas: false,
            ),
            -18,
        )
    }

    func testHorizontalDominantScrollIsDropped() {
        XCTAssertNil(
            ScrollingCaptureSessionPolicy.scaledScrollDeltaY(
                deltaX: 10,
                deltaY: 4,
                hasPreciseDeltas: true,
            ),
        )
    }

    func testSubThresholdScrollIsDropped() {
        XCTAssertNil(
            ScrollingCaptureSessionPolicy.scaledScrollDeltaY(
                deltaX: 0,
                deltaY: 0.4,
                hasPreciseDeltas: true,
            ),
        )
    }

    func testStreamingCommitFiresDuringActiveScroll() {
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.05,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.2,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
    }

    func testStreamingCommitWaitsForMinimumInterval() {
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.05,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.05,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
    }
}

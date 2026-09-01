//
//  CaptureSelectionCursorPolicyTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

@MainActor
final class CaptureSelectionCursorPolicyTests: XCTestCase {
    func testPolicy_hudZoneAlwaysArrow() {
        XCTAssertEqual(
            CaptureSelectionCursorPolicy.cursorKind(zone: .hud, phase: .initialAreaSelection),
            .arrow,
        )
        XCTAssertEqual(
            CaptureSelectionCursorPolicy.cursorKind(zone: .hud, phase: .confirmedRefinement),
            .arrow,
        )
    }

    func testPolicy_resizeHandleMapsToResizeCursor() {
        XCTAssertEqual(
            CaptureSelectionCursorPolicy.cursorKind(zone: .resizeHandle(.left), phase: .confirmedRefinement),
            .resize(.left),
        )
    }

    func testPolicy_outsideInitialSelectionUsesCrosshair() {
        XCTAssertEqual(
            CaptureSelectionCursorPolicy.cursorKind(zone: .outside, phase: .initialAreaSelection),
            .crosshair,
        )
    }

    func testArbiter_hudExclusionOverridesOverlayCandidate() {
        let arbiter = AllInOneCaptureCursorArbiter()
        let hudFrame = CGRect(x: 100, y: 100, width: 200, height: 40)
        arbiter.hudExclusionFrames = { [hudFrame] }
        arbiter.overlayCandidate = { _ in .resize(.right) }

        XCTAssertEqual(arbiter.resolvedCursor(at: CGPoint(x: 150, y: 120)), .arrow)
        XCTAssertEqual(arbiter.resolvedCursor(at: CGPoint(x: 10, y: 10)), .resize(.right))
    }

    func testArbiter_usesFallbackWhenOverlayCandidateIsUnavailable() {
        let arbiter = AllInOneCaptureCursorArbiter()
        arbiter.fallbackCursor = { .crosshair }

        XCTAssertEqual(arbiter.resolvedCursor(at: CGPoint(x: 10, y: 10)), .crosshair)
    }
}

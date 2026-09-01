#if CUE_VIDEO_MODULE
//
    //  VideoEditorZoomSegmentSynthesizerTests.swift
    //  NotinhasTests
//
    //  Unit tests for click-driven automatic zoom segment synthesis.
//

    import CoreGraphics
    @testable import Cue
    import XCTest

    final class VideoEditorZoomSegmentSynthesizerTests: XCTestCase {
        func testSegments_emptyPresses_returnsEmpty() {
            XCTAssertTrue(
                VideoEditorZoomSegmentSynthesizer.segments(from: [], duration: 10).isEmpty,
            )
        }

        func testSegments_invalidDuration_returnsEmpty() {
            let presses = [RecordedMousePress(
                time: 1,
                normalizedX: 0.5,
                normalizedY: 0.5,
                button: 0,
                phase: .down,
            )]
            XCTAssertTrue(
                VideoEditorZoomSegmentSynthesizer.segments(from: presses, duration: 0).isEmpty,
            )
        }

        func testSegments_singleClick_usesScreendropTimingWindow() {
            let presses = [RecordedMousePress(
                time: 2,
                normalizedX: 0.4,
                normalizedY: 0.6,
                button: 0,
                phase: .down,
            )]

            let segments = VideoEditorZoomSegmentSynthesizer.segments(from: presses, duration: 10)
            XCTAssertEqual(segments.count, 1)
            let segment = segments[0]
            XCTAssertEqual(segment.startTime, 1.7, accuracy: 0.001)
            XCTAssertEqual(segment.endTime, 4.5, accuracy: 0.001)
            XCTAssertEqual(segment.zoomLevel, 1.5, accuracy: 0.001)
            XCTAssertEqual(segment.zoomType, .auto)
            XCTAssertTrue(segment.isImplicit)
            XCTAssertEqual(segment.zoomCenter.x, 0.4, accuracy: 0.001)
            XCTAssertEqual(segment.zoomCenter.y, 0.6, accuracy: 0.001)
        }

        func testSegments_ignoresClicksInTailExclusionWindow() {
            let presses = [RecordedMousePress(
                time: 9.5,
                normalizedX: 0.5,
                normalizedY: 0.5,
                button: 0,
                phase: .down,
            )]

            XCTAssertTrue(
                VideoEditorZoomSegmentSynthesizer.segments(from: presses, duration: 10).isEmpty,
            )
        }

        func testSegments_mergesNearbyClicksWithinJoinTolerance() {
            let presses = [
                RecordedMousePress(time: 1, normalizedX: 0.2, normalizedY: 0.2, button: 0, phase: .down),
                RecordedMousePress(time: 3, normalizedX: 0.8, normalizedY: 0.8, button: 0, phase: .down),
            ]

            let segments = VideoEditorZoomSegmentSynthesizer.segments(from: presses, duration: 12)
            XCTAssertEqual(segments.count, 1)
            let segment = segments[0]
            XCTAssertEqual(segment.startTime, 0.7, accuracy: 0.001)
            XCTAssertEqual(segment.endTime, 5.5, accuracy: 0.001)
        }

        func testSegments_ignoresMouseUpEvents() {
            let presses = [
                RecordedMousePress(time: 2, normalizedX: 0.5, normalizedY: 0.5, button: 0, phase: .up),
            ]

            XCTAssertTrue(
                VideoEditorZoomSegmentSynthesizer.segments(from: presses, duration: 10).isEmpty,
            )
        }
    }
#endif

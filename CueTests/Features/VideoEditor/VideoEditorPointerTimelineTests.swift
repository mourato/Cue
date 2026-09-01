#if CUE_VIDEO_MODULE
//
    //  VideoEditorPointerTimelineTests.swift
    //  NotinhasTests
//

    import CoreGraphics
    @testable import Cue
    import XCTest

    final class VideoEditorPointerTimelineTests: XCTestCase {
        func testBuild_emptyMetadata_returnsEmpty() {
            XCTAssertEqual(
                VideoEditorPointerTimeline.build(metadata: nil, duration: 5),
                .empty,
            )
        }

        func testBuild_travelSamples_producesSmoothMotion() throws {
            let metadata = RecordingMetadata(
                captureSize: CGSize(width: 1920, height: 1080),
                samplesPerSecond: 60,
                mouseSamples: [
                    RecordedMouseSample(time: 0, normalizedX: 0.1, normalizedY: 0.1, isInsideCapture: true),
                    RecordedMouseSample(time: 1, normalizedX: 0.9, normalizedY: 0.9, isInsideCapture: true),
                ],
            )
            let timeline = VideoEditorPointerTimeline.build(metadata: metadata, duration: 2)
            let early = timeline.frame(at: 0.2)
            let late = timeline.frame(at: 1.5)
            XCTAssertNotNil(early)
            XCTAssertNotNil(late)
            XCTAssertLessThan(try XCTUnwrap(early?.location.x), try XCTUnwrap(late?.location.x))
            XCTAssertLessThan(try XCTUnwrap(early?.location.y), try XCTUnwrap(late?.location.y))
        }

        func testBuild_click_generatesPressPulse() {
            let metadata = RecordingMetadata(
                captureSize: CGSize(width: 1920, height: 1080),
                samplesPerSecond: 60,
                mouseSamples: [
                    RecordedMouseSample(time: 0, normalizedX: 0.5, normalizedY: 0.5, isInsideCapture: true),
                ],
                mousePresses: [
                    RecordedMousePress(time: 1, normalizedX: 0.5, normalizedY: 0.5, button: 0, phase: .down),
                ],
            )
            let timeline = VideoEditorPointerTimeline.build(metadata: metadata, duration: 3)
            let duringPulse = timeline.frame(at: 1.1)
            let afterPulse = timeline.frame(at: 2)
            XCTAssertNotNil(duringPulse?.press)
            XCTAssertNil(afterPulse?.press)
        }

        func testBuild_outsideCapture_fadesPointerUntilItReenters() throws {
            let metadata = RecordingMetadata(
                captureSize: CGSize(width: 1920, height: 1080),
                samplesPerSecond: 60,
                mouseSamples: [
                    RecordedMouseSample(time: 0, normalizedX: 0.5, normalizedY: 0.5, isInsideCapture: true),
                    RecordedMouseSample(time: 1, normalizedX: 1, normalizedY: 0.5, isInsideCapture: false),
                    RecordedMouseSample(time: 2, normalizedX: 0.25, normalizedY: 0.75, isInsideCapture: true),
                ],
                mousePresses: [
                    RecordedMousePress(
                        time: 1.5,
                        normalizedX: 1,
                        normalizedY: 0.5,
                        button: 0,
                        phase: .down,
                    ),
                ],
            )

            let timeline = VideoEditorPointerTimeline.build(metadata: metadata, duration: 3)
            XCTAssertLessThan(try XCTUnwrap(timeline.frame(at: 1.8)?.opacity), 0.1)
            XCTAssertNil(timeline.frame(at: 1.55)?.press)
            XCTAssertGreaterThan(try XCTUnwrap(timeline.frame(at: 2.8)?.opacity), 0.8)
        }

        func testBuild_smoothingPresets_changeMotionProfile() throws {
            let metadata = RecordingMetadata(
                captureSize: CGSize(width: 1920, height: 1080),
                samplesPerSecond: 60,
                mouseSamples: [
                    RecordedMouseSample(time: 0, normalizedX: 0.1, normalizedY: 0.1, isInsideCapture: true),
                    RecordedMouseSample(time: 1, normalizedX: 0.9, normalizedY: 0.9, isInsideCapture: true),
                ],
            )

            let original = VideoEditorPointerTimeline.build(
                metadata: metadata,
                duration: 2,
                smoothingPreset: .original,
            )
            let smooth = VideoEditorPointerTimeline.build(
                metadata: metadata,
                duration: 2,
                smoothingPreset: .smooth,
            )
            let fast = VideoEditorPointerTimeline.build(
                metadata: metadata,
                duration: 2,
                smoothingPreset: .fast,
            )

            let originalX = try XCTUnwrap(original.frame(at: 1.5)?.location.x)
            let smoothX = try XCTUnwrap(smooth.frame(at: 1.5)?.location.x)
            let fastX = try XCTUnwrap(fast.frame(at: 1.5)?.location.x)
            XCTAssertNotEqual(originalX, smoothX)
            XCTAssertNotEqual(originalX, fastX)
            XCTAssertLessThan(smoothX, fastX)
        }
    }
#endif

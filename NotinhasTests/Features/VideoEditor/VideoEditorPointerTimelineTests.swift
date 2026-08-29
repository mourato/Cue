#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorPointerTimelineTests.swift
    //  NotinhasTests
//

    import CoreGraphics
    @testable import Notinhas
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
    }
#endif

#if CUE_VIDEO_MODULE
//
    //  VideoEditorViewportTimelineTests.swift
    //  NotinhasTests
//
    //  Unit tests for damped-spring viewport timeline (Plan 110 / Phase A).
//

    import CoreGraphics
    @testable import Cue
    import XCTest

    final class VideoEditorViewportTimelineTests: XCTestCase {
        func testBuild_invalidDuration_returnsIdentity() {
            let segment = ZoomSegment(startTime: 0, duration: 2, zoomLevel: 2)
            let timeline = VideoEditorViewportTimeline.build(
                segments: [segment],
                metadata: nil,
                duration: 0,
            )
            XCTAssertEqual(timeline, .identity)
        }

        func testBuild_pinnedSegment_holdsCenter() {
            let center = CGPoint(x: 0.3, y: 0.7)
            let segment = ZoomSegment(
                startTime: 1,
                duration: 2,
                zoomLevel: 2,
                zoomCenter: center,
                zoomType: .manual,
                anchorMode: .pinned,
            )
            let timeline = VideoEditorViewportTimeline.build(
                segments: [segment],
                metadata: nil,
                duration: 5,
            )

            let duringZoom = timeline.frame(at: 2)
            XCTAssertEqual(duringZoom.magnification, 2, accuracy: 0.05)
            XCTAssertEqual(duringZoom.anchor.x, center.x, accuracy: 0.02)
            XCTAssertEqual(duringZoom.anchor.y, center.y, accuracy: 0.02)
        }

        func testBuild_pointerSegment_followsRecordedTravel() {
            let metadata = RecordingMetadata(
                captureSize: CGSize(width: 1920, height: 1080),
                samplesPerSecond: 60,
                mouseSamples: [
                    RecordedMouseSample(time: 0, normalizedX: 0.2, normalizedY: 0.2, isInsideCapture: true),
                    RecordedMouseSample(time: 2, normalizedX: 0.8, normalizedY: 0.8, isInsideCapture: true),
                ],
                mousePresses: [
                    RecordedMousePress(
                        time: 1,
                        normalizedX: 0.5,
                        normalizedY: 0.5,
                        button: 0,
                        phase: .down,
                    ),
                ],
            )
            let segment = ZoomSegment(
                startTime: 0.5,
                duration: 2,
                zoomLevel: 2,
                zoomCenter: CGPoint(x: 0.5, y: 0.5),
                zoomType: .auto,
                anchorMode: .pointer,
            )
            let timeline = VideoEditorViewportTimeline.build(
                segments: [segment],
                metadata: metadata,
                duration: 4,
            )

            let early = timeline.frame(at: 1)
            let late = timeline.frame(at: 2.5)
            XCTAssertGreaterThan(late.anchor.x, early.anchor.x)
            XCTAssertGreaterThan(late.anchor.y, early.anchor.y)
            XCTAssertGreaterThan(late.magnification, 1.01)
        }

        func testBuild_springsEaseIntoZoom() {
            let segment = ZoomSegment(
                startTime: 1,
                duration: 3,
                zoomLevel: 2,
                zoomCenter: CGPoint(x: 0.5, y: 0.5),
                zoomType: .manual,
                anchorMode: .pinned,
            )
            let timeline = VideoEditorViewportTimeline.build(
                segments: [segment],
                metadata: nil,
                duration: 6,
            )

            let before = timeline.frame(at: 0.5).magnification
            let start = timeline.frame(at: 1.05).magnification
            let settled = timeline.frame(at: 2.5).magnification

            XCTAssertEqual(before, 1, accuracy: 0.001)
            XCTAssertGreaterThan(start, before)
            XCTAssertLessThan(start, settled)
            XCTAssertEqual(settled, 2, accuracy: 0.08)
        }

        func testResolvedCameraState_usesViewportTimelineWhenProvided() {
            let segment = ZoomSegment(
                startTime: 0,
                duration: 2,
                zoomLevel: 2,
                zoomCenter: CGPoint(x: 0.4, y: 0.6),
                zoomType: .manual,
                anchorMode: .pinned,
            )
            let timeline = VideoEditorViewportTimeline.build(
                segments: [segment],
                metadata: nil,
                duration: 3,
            )
            let state = VideoEditorAutoFocusEngine.resolvedCameraState(
                at: 1,
                segments: [segment],
                autoFocusPaths: [:],
                transitionDuration: 0.5,
                viewportTimeline: timeline,
            )

            XCTAssertGreaterThan(state.zoomLevel, 1.5)
            XCTAssertEqual(state.center.x, 0.4, accuracy: 0.05)
            XCTAssertEqual(state.center.y, 0.6, accuracy: 0.05)
        }
    }
#endif

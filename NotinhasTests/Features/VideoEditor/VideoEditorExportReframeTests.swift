#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorExportReframeTests.swift
    //  NotinhasTests
//

    import CoreGraphics
    @testable import Notinhas
    import XCTest

    final class VideoEditorExportReframeTests: XCTestCase {
        func testBuild_producesTrackForAspectPreset() {
            let viewport = VideoEditorViewportTimeline.build(
                segments: [],
                metadata: nil,
                duration: 2,
            )
            let track = VideoEditorReframeTrack.build(
                preset: .ratio9x16,
                sourceSize: CGSize(width: 1920, height: 1080),
                viewportTimeline: viewport,
                duration: 2,
                focus: { _ in CGPoint(x: 0.5, y: 0.5) },
            )
            XCTAssertNotNil(track)
            let frame = track?.frame(at: 1)
            XCTAssertNotNil(frame)
            XCTAssertGreaterThanOrEqual(frame?.magnification ?? 0, 1)
        }

        func testBuild_returnsNilForOriginalPreset() {
            let viewport = VideoEditorViewportTimeline.identity
            let track = VideoEditorReframeTrack.build(
                preset: .original,
                sourceSize: CGSize(width: 1280, height: 720),
                viewportTimeline: viewport,
                duration: 1,
                focus: { _ in nil },
            )
            XCTAssertNil(track)
        }

        @MainActor
        func testUsesReframeExport_whenFillAndAspectPreset() {
            let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/sample.mov"))
            state.exportSettings.dimensionPreset = .ratio9x16
            state.exportContentMode = .fill
            XCTAssertTrue(state.usesReframeExport)

            state.exportContentMode = .fit
            XCTAssertFalse(state.usesReframeExport)
        }
    }
#endif

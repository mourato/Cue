#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    import CoreGraphics
    @testable import Notinhas
    import XCTest

    final class VideoEditorCameraOverlayTests: XCTestCase {
        func testLayoutUsesTopLeftNormalizedPresetsAndAspectFit() {
            var layout = VideoEditorCameraOverlayLayout.default
            layout.position = .bottomTrailing
            layout.size = .small
            let frame = layout.cameraFrame(
                in: CGSize(width: 1600, height: 900),
                cameraSize: CGSize(width: 640, height: 480),
            )
            XCTAssertLessThan(frame.maxX, 1600)
            XCTAssertGreaterThan(frame.minX, 1000)
            XCTAssertGreaterThan(frame.minY, 600)
            XCTAssertEqual(frame.width / frame.height, 640.0 / 480.0, accuracy: 0.001)
        }

        func testTrackResolutionUsesRoleAndRealTrackID() async throws {
            let composition = AVMutableComposition()
            let camera = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 42))
            let screen = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 7))
            let metadata = RecordingMetadata(captureSize: CGSize(width: 1280, height: 720), samplesPerSecond: 30,
                                             mouseSamples: [], videoSourceTracks: [
                                                 RecordingVideoSourceTrack(trackID: 7, role: .screen),
                                                 RecordingVideoSourceTrack(
                                                     trackID: 42,
                                                     role: .camera,
                                                     captureSize: CGSize(width: 480, height: 640),
                                                 ),
                                             ])
            let result = try await VideoEditorState.resolveVideoTracks([camera, screen], metadata: metadata)
            XCTAssertEqual(result?.screenTrackID, screen.trackID)
            XCTAssertEqual(result?.cameraTrackID, camera.trackID)
            XCTAssertEqual(result?.cameraSize, CGSize(width: 480, height: 640))
        }

        func testInvalidCameraIDFallsBackToScreenOnly() async throws {
            let composition = AVMutableComposition()
            let screen = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 7))
            let metadata = RecordingMetadata(captureSize: CGSize(width: 1280, height: 720), samplesPerSecond: 30,
                                             mouseSamples: [], videoSourceTracks: [
                                                 RecordingVideoSourceTrack(trackID: 7, role: .screen),
                                                 RecordingVideoSourceTrack(trackID: 999, role: .camera),
                                             ])
            let result = try await VideoEditorState.resolveVideoTracks([screen], metadata: metadata)
            XCTAssertEqual(result?.screenTrackID, screen.trackID)
            XCTAssertNil(result?.cameraTrackID)
            XCTAssertTrue(result?.cameraMetadataWasInvalid == true)
        }

        func testCameraMetadataWithoutScreenRoleIsInvalid() async throws {
            let composition = AVMutableComposition()
            let camera = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 42))
            let metadata = RecordingMetadata(captureSize: CGSize(width: 1280, height: 720), samplesPerSecond: 30,
                                             mouseSamples: [], videoSourceTracks: [
                                                 RecordingVideoSourceTrack(trackID: 42, role: .camera),
                                             ])
            let result = try await VideoEditorState.resolveVideoTracks([camera], metadata: metadata)
            XCTAssertNil(result?.cameraTrackID)
            XCTAssertTrue(result?.cameraMetadataWasInvalid == true)
        }

        func testCameraMetadataWithDuplicateRolesIsInvalid() async throws {
            let composition = AVMutableComposition()
            let screen = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 7))
            let camera = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: 42))
            let metadata = RecordingMetadata(captureSize: CGSize(width: 1280, height: 720), samplesPerSecond: 30,
                                             mouseSamples: [], videoSourceTracks: [
                                                 RecordingVideoSourceTrack(trackID: 7, role: .screen),
                                                 RecordingVideoSourceTrack(trackID: 42, role: .camera),
                                                 RecordingVideoSourceTrack(trackID: 7, role: .screen),
                                             ])
            let result = try await VideoEditorState.resolveVideoTracks([screen, camera], metadata: metadata)
            XCTAssertNil(result?.cameraTrackID)
            XCTAssertTrue(result?.cameraMetadataWasInvalid == true)
        }

        func testLayoutOffsetForPaddedCanvasPreservesNormalizedCameraPlacement() {
            let layout = VideoEditorCameraOverlayLayout.default
            let base = layout.cameraFrame(
                in: CGSize(width: 1280, height: 720),
                cameraSize: CGSize(width: 640, height: 480),
            )
            let padded = base.offsetBy(dx: 40, dy: 40)
            XCTAssertEqual(padded.minX, base.minX + 40, accuracy: 0.001)
            XCTAssertEqual(padded.minY, base.minY + 40, accuracy: 0.001)
        }

        func testInstructionCarriesOnlyResolvedSourceIDs() {
            let instruction = ZoomVideoCompositionInstruction(
                timeRange: .zero,
                zooms: [],
                autoFocusPaths: [:],
                trackID: 7,
                renderSize: CGSize(width: 1280, height: 720),
                transitionDuration: 0.4,
                cameraTrackID: 42,
            )
            XCTAssertEqual(
                instruction.requiredSourceTrackIDs?.compactMap { ($0 as? NSNumber)?.intValue }.sorted(),
                [7, 42],
            )
        }

        func testScreenOnlyInstructionKeepsSingleTrackFastPath() {
            let instruction = ZoomVideoCompositionInstruction(
                timeRange: .zero,
                zooms: [],
                autoFocusPaths: [:],
                trackID: 7,
                renderSize: CGSize(width: 1280, height: 720),
                transitionDuration: 0.4,
            )
            XCTAssertEqual(instruction.requiredSourceTrackIDs?.compactMap { ($0 as? NSNumber)?.intValue }, [7])
        }

        func testCompositorDoesNotGuessScreenTrackWhenExplicitIDIsMissing() async throws {
            let asset = AVMutableComposition()
            _ = try XCTUnwrap(asset.addMutableTrack(withMediaType: .video, preferredTrackID: 7))
            let compositor = ZoomCompositor(
                zooms: [],
                renderSize: CGSize(width: 1280, height: 720),
                screenTrackID: 999,
            )

            do {
                _ = try await compositor.createVideoComposition(
                    for: asset,
                    timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 600)),
                )
                XCTFail("An explicit missing screen track ID must not fall back to the first track")
            } catch ZoomCompositor.ZoomCompositorError.noVideoTrack {
                // Expected.
            }
        }

        @MainActor
        func testCameraLayoutChangesParticipateInDirtyState() {
            let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/notinhas-camera-overlay-test.mov"))
            state.markAsSaved()
            XCTAssertFalse(state.hasUnsavedChanges)
            var changedLayout = state.cameraOverlayLayout
            changedLayout.position = .topLeading
            state.cameraOverlayLayout = changedLayout
            XCTAssertTrue(state.hasUnsavedChanges)
            state.markAsSaved()
            XCTAssertFalse(state.hasUnsavedChanges)
        }
    }
#endif

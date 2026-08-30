#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorRenderRecipeTests.swift
    //  NotinhasTests
//

    import Foundation
    @testable import Notinhas
    import XCTest

    @MainActor
    final class VideoEditorRenderRecipeTests: XCTestCase {
        func testCacheKey_isStableForIdenticalState() {
            let url = URL(fileURLWithPath: "/tmp/sample.mov")
            let stateA = VideoEditorState(url: url)
            let stateB = VideoEditorState(url: url)
            let fingerprint = "test|100|0"
            let recipeA = VideoEditorRenderRecipe.capture(from: stateA, sourceFingerprint: fingerprint)
            let recipeB = VideoEditorRenderRecipe.capture(from: stateB, sourceFingerprint: fingerprint)
            XCTAssertEqual(recipeA.cacheKey(), recipeB.cacheKey())
        }

        func testCacheKey_changesWhenCursorScaleChanges() {
            let url = URL(fileURLWithPath: "/tmp/sample.mov")
            let stateA = VideoEditorState(url: url)
            let stateB = VideoEditorState(url: url)
            stateB.cursorScale = 2.0
            let fingerprint = "test|100|0"
            let keyA = VideoEditorRenderRecipe.capture(from: stateA, sourceFingerprint: fingerprint).cacheKey()
            let keyB = VideoEditorRenderRecipe.capture(from: stateB, sourceFingerprint: fingerprint).cacheKey()
            XCTAssertNotEqual(keyA, keyB)
        }

        func testCacheKey_changesWhenCameraLayoutChanges() {
            let url = URL(fileURLWithPath: "/tmp/sample.mov")
            let state = VideoEditorState(url: url)
            let fingerprint = "test|100|0"
            let baseline = VideoEditorRenderRecipe.capture(from: state, sourceFingerprint: fingerprint)

            var reactsToZoom = state.cameraOverlayLayout
            reactsToZoom.reactsToZoom.toggle()
            var position = state.cameraOverlayLayout
            position.position = .topLeading
            var size = state.cameraOverlayLayout
            size.size = .large

            for layout in [reactsToZoom, position, size] {
                let changedState = VideoEditorState(url: url)
                changedState.cameraOverlayLayout = layout
                XCTAssertNotEqual(
                    baseline.cacheKey(),
                    VideoEditorRenderRecipe.capture(from: changedState, sourceFingerprint: fingerprint).cacheKey(),
                )
            }
        }

        func testRecipeUsesCurrentExporterImplementationVersion() {
            let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/sample.mov"))
            let recipe = VideoEditorRenderRecipe.capture(from: state, sourceFingerprint: "test|100|0")
            XCTAssertEqual(recipe.exporterImplementationVersion, 2)
            XCTAssertFalse(recipe.cameraOverlayLayoutPayload.isEmpty)
        }
    }
#endif

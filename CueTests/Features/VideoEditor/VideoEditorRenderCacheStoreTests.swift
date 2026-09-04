#if CUE_VIDEO_MODULE
//
    //  VideoEditorRenderCacheStoreTests.swift
    //  NotinhasTests
//

    @testable import Cue
    import Foundation
    import XCTest

    final class VideoEditorRenderCacheStoreTests: XCTestCase {
        private var tempRoot: URL!

        override func setUp() {
            super.setUp()
            tempRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("notinhas-render-cache-tests-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        }

        override func tearDown() {
            try? FileManager.default.removeItem(at: tempRoot)
            super.tearDown()
        }

        @MainActor
        func testLookup_missBeforeStore() {
            let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/sample.mov"))
            let fingerprint = "test|1|0"
            let recipe = VideoEditorRenderRecipe.capture(from: state, sourceFingerprint: fingerprint)
            let key = recipe.cacheKey()

            let result = VideoEditorRenderCacheStore.lookup(
                cacheKey: key,
                sourceFingerprint: fingerprint,
                recipe: recipe,
                cacheRoot: tempRoot,
            )
            XCTAssertNil(result)
        }

        @MainActor
        func testStoreThenLookup_missWhenRecipeChanges() throws {
            let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/sample.mov"))
            let fingerprint = "test|1|0"
            let recipe = VideoEditorRenderRecipe.capture(from: state, sourceFingerprint: fingerprint)
            let key = recipe.cacheKey()

            let rendered = tempRoot.appendingPathComponent("source.mov")
            try Data([0x00, 0x00, 0x00, 0x08]).write(to: rendered)

            try VideoEditorRenderCacheStore.store(
                renderedFile: rendered,
                cacheKey: key,
                sourceFingerprint: fingerprint,
                recipe: recipe,
                cacheRoot: tempRoot,
            )

            var changed = VideoEditorState(url: URL(fileURLWithPath: "/tmp/sample-other.mov"))
            changed.cursorScale = 2.5
            let changedRecipe = VideoEditorRenderRecipe.capture(from: changed, sourceFingerprint: fingerprint)
            XCTAssertNotEqual(recipe.cacheKey(), changedRecipe.cacheKey())

            let miss = VideoEditorRenderCacheStore.lookup(
                cacheKey: changedRecipe.cacheKey(),
                sourceFingerprint: fingerprint,
                recipe: changedRecipe,
                cacheRoot: tempRoot,
            )
            XCTAssertNil(miss)
        }

        func testEntryDirectory_rejectsInvalidKey() {
            XCTAssertThrowsError(
                try VideoEditorRenderCacheStore.entryDirectory(for: "../escape", cacheRoot: tempRoot),
            )
        }
    }
#endif

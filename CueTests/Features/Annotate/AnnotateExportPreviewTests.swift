import AppKit
@testable import Cue
import XCTest

@MainActor
final class AnnotateExportPreviewTests: XCTestCase {
    private func makeStateWithImage() throws -> AnnotateState {
        let cgImage = try XCTUnwrap(TestImageFactory.solidColor(width: 200, height: 100))
        let image = NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 100))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-test.png")
        return AnnotateState(image: image, url: url, appliesDefaultCanvasPresetOnNewImages: false)
    }

    private func makeRenderableNote(text: String = "Note") -> NotinhasVisualNote {
        NotinhasVisualNote(
            text: text,
            target: .point(CGPoint(x: 50, y: 50)),
            color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            creationOrder: 1,
        )
    }

    func testShowsNotinhasExportPreviewRequiresPreviewModeAndRenderableNotes() throws {
        let state = try makeStateWithImage()
        XCTAssertFalse(state.showsNotinhasExportPreview)

        state.notinhasNotes = [makeRenderableNote()]
        XCTAssertFalse(state.showsNotinhasExportPreview)

        state.editorMode = .preview
        XCTAssertTrue(state.showsNotinhasExportPreview)

        state.notinhasNotes = [makeRenderableNote(text: "   ")]
        XCTAssertFalse(state.showsNotinhasExportPreview)
    }

    func testRefreshNotinhasExportPreviewBuildsWiderComposition() throws {
        let state = try makeStateWithImage()
        state.notinhasNotes = [makeRenderableNote()]
        state.editorMode = .preview

        state.refreshNotinhasExportPreview()

        let previewImage = try XCTUnwrap(state.notinhasExportPreviewImage)
        XCTAssertGreaterThan(previewImage.size.width, 200)
    }

    func testRefreshNotinhasExportPreviewClearsWhenLeavingPreview() throws {
        let state = try makeStateWithImage()
        state.notinhasNotes = [makeRenderableNote()]
        state.editorMode = .preview
        XCTAssertNotNil(state.notinhasExportPreviewImage)

        state.editorMode = .annotate
        XCTAssertNil(state.notinhasExportPreviewImage)
    }

    func testEnteringPreviewBuildsExportImageSynchronously() throws {
        let state = try makeStateWithImage()
        state.notinhasNotes = [makeRenderableNote()]

        state.editorMode = .preview

        XCTAssertTrue(state.showsNotinhasExportPreview)
        let previewImage = try XCTUnwrap(state.notinhasExportPreviewImage)
        XCTAssertGreaterThan(previewImage.size.width, 200)
    }
}

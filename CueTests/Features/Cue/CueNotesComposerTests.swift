import AppKit
@testable import Cue
import XCTest

final class CueNotesComposerTests: XCTestCase {
    private let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

    func testComposeAddsPanelWhenRenderableNotesExist() {
        let base = NSImage(size: NSSize(width: 200, height: 100))
        let note = CueVisualNote(
            text: "Button color",
            target: .point(CGPoint(x: 20, y: 20)),
            color: red,
            creationOrder: 1,
        )

        let composed = CueNotesComposer.compose(
            baseImage: base,
            notes: [note],
            panelSide: .right,
        )

        XCTAssertGreaterThan(composed.size.width, base.size.width)
        XCTAssertGreaterThanOrEqual(composed.size.height, base.size.height)
    }

    func testComposeReturnsBaseImageWhenNoRenderableNotes() {
        let base = NSImage(size: NSSize(width: 120, height: 80))
        let note = CueVisualNote(text: " ", target: .point(.zero), color: red, creationOrder: 1)

        let composed = CueNotesComposer.compose(
            baseImage: base,
            notes: [note],
            panelSide: .left,
        )

        XCTAssertEqual(composed.size, base.size)
    }

    func testExportPanelPrimaryTextIsDarkInk() {
        let ink = CueNotesPanelStyle.primaryText.usingColorSpace(.deviceRGB) ?? CueNotesPanelStyle.primaryText
        let background = CueNotesPanelStyle.background.usingColorSpace(.deviceRGB) ?? CueNotesPanelStyle
            .background

        XCTAssertLessThan(ink.brightnessComponent, 0.35)
        XCTAssertGreaterThan(background.brightnessComponent, 0.9)
    }
}

@testable import Cue
import SwiftUI
import XCTest

@MainActor
final class CueAnnotateStateTests: XCTestCase {
    private func makeState() -> AnnotateState {
        AnnotateState(defaults: UserDefaultsFactory.make())
    }

    private func makeNote(text: String = "Note") -> CueVisualNote {
        CueVisualNote(
            text: text,
            target: .point(.zero),
            color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            creationOrder: 1,
        )
    }

    func testAddingNoteCreatesOneUndoCheckpoint() {
        let state = makeState()
        let note = makeNote()

        state.notinhasAddNote(note)
        XCTAssertEqual(state.cueNotes, [note])

        state.undo()
        XCTAssertTrue(state.cueNotes.isEmpty)
    }

    func testUpdatingNoteUndoRestoresOriginalValue() {
        let state = makeState()
        let original = makeNote(text: "Before")
        var edited = original
        edited.text = "After"
        state.cueNotes = [original]

        state.notinhasUpdateNote(edited)
        state.undo()

        XCTAssertEqual(state.cueNotes, [original])
    }

    func testDeletingNoteUndoRestoresNote() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]

        state.notinhasDeleteNote(id: note.id)
        state.undo()

        XCTAssertEqual(state.cueNotes, [note])
    }

    func testMovingNoteCreatesOneUndoCheckpoint() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

        state.notinhasBeginMovingNote(id: note.id)
        state.notinhasUpdateMovingNote(
            to: CGPoint(x: 30, y: 0),
            imageBounds: bounds,
            from: .zero,
        )
        XCTAssertEqual(state.cueNotes[0].target, note.target)
        XCTAssertNotNil(state.cueMovePreviewTarget)
        state.notinhasCommitMovingNote()

        guard case .point(let movedPoint) = state.cueNotes[0].target else {
            return XCTFail("Expected point target")
        }
        XCTAssertEqual(movedPoint.x, 30, accuracy: 0.001)

        state.undo()
        XCTAssertEqual(state.cueNotes[0].target, note.target)
    }

    func testResizingRectNoteCreatesOneUndoCheckpoint() {
        let state = makeState()
        let note = CueVisualNote(
            target: .rect(CGRect(x: 20, y: 30, width: 80, height: 60)),
            color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            creationOrder: 1,
        )
        state.cueNotes = [note]
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

        state.notinhasBeginMovingNote(id: note.id)
        state.notinhasUpdateResizingNote(
            to: CGPoint(x: 70, y: 50),
            imageBounds: bounds,
            handle: .bottomRight,
        )
        state.notinhasCommitMovingNote()

        XCTAssertEqual(state.cueNotes[0].target, .rect(CGRect(x: 20, y: 50, width: 50, height: 40)))
        state.undo()
        XCTAssertEqual(state.cueNotes[0].target, note.target)
    }

    func testDrawingRectAnchorsPinAtDragStartCorner() {
        let state = makeState()
        let color = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)

        state.notinhasBeginDrawing(at: CGPoint(x: 100, y: 200), color: color)
        state.notinhasUpdateDrawing(to: CGPoint(x: 180, y: 120), imageBounds: bounds)

        XCTAssertEqual(state.cueDraftNote?.target.pinCorner, .topLeft)
        guard case .rect(let rect, let pinCorner) = state.cueDraftNote?.target else {
            return XCTFail("Expected rect draft")
        }
        XCTAssertEqual(pinCorner, .topLeft)
        XCTAssertEqual(rect.minX, 100, accuracy: 0.001)
        XCTAssertEqual(rect.maxY, 200, accuracy: 0.001)
    }

    func testMovingNotePreviewDoesNotPublishUntilCommit() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

        state.notinhasBeginMovingNote(id: note.id)
        state.notinhasUpdateMovingNote(
            to: CGPoint(x: 12, y: 8),
            imageBounds: bounds,
            from: .zero,
        )

        XCTAssertEqual(state.cueNotes[0].target, note.target)
        XCTAssertNotNil(state.cueMovePreviewTarget)
        XCTAssertNotEqual(state.notinhasResolvedTarget(for: note.id), note.target)
    }

    func testCancelMovingNoteClearsPreviewWithoutMutatingNotes() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

        state.notinhasBeginMovingNote(id: note.id)
        state.notinhasUpdateMovingNote(
            to: CGPoint(x: 30, y: 0),
            imageBounds: bounds,
            from: .zero,
        )
        state.notinhasCancelMovingNote()

        XCTAssertEqual(state.cueNotes[0].target, note.target)
        XCTAssertNil(state.cueMovePreviewTarget)
        XCTAssertNil(state.notinhasMovingNoteID)
        XCTAssertFalse(state.canUndo)
    }

    func testCloseEditorCancelsInProgressMove() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

        state.activateTool(.cueNote)
        state.notinhasBeginMovingNote(id: note.id)
        state.notinhasUpdateMovingNote(
            to: CGPoint(x: 40, y: 10),
            imageBounds: bounds,
            from: .zero,
        )
        state.activateTool(.selection)

        XCTAssertEqual(state.cueNotes[0].target, note.target)
        XCTAssertNil(state.notinhasMovingNoteID)
        XCTAssertFalse(state.canUndo)
    }

    func testSelectNoteWithoutEditingClearsEditingID() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        state.notinhasSelectNote(id: note.id, beginEditing: true)
        XCTAssertEqual(state.notinhasEditingNoteID, note.id)

        state.notinhasSelectNote(id: note.id, beginEditing: false)
        XCTAssertEqual(state.notinhasSelectedNoteID, note.id)
        XCTAssertNil(state.notinhasEditingNoteID)
    }

    func testLiveAppearanceUpdateDoesNotCreateUndoCheckpoint() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        var live = note
        live.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        live.areaStrokeWidth = 5

        state.notinhasApplyLiveAppearance(live)

        XCTAssertEqual(state.cueNotes[0].color, live.color)
        XCTAssertEqual(state.cueNotes[0].areaStrokeWidth, AnnotationStrokeWidth.regular.points)
        XCTAssertEqual(state.cueNotes[0].text, note.text)
        XCTAssertFalse(state.canUndo)
    }

    func testLiveAppearanceClampsAreaStrokeWidth() {
        let state = makeState()
        let note = makeNote()
        state.cueNotes = [note]
        var live = note
        live.areaStrokeWidth = 99

        state.notinhasApplyLiveAppearance(live)

        XCTAssertEqual(
            state.cueNotes[0].areaStrokeWidth,
            AnnotationStrokeWidth.maxPoints,
            accuracy: 0.001,
        )
    }

    func testCommitNoteEditClampsAreaStrokeWidth() {
        let state = makeState()
        let original = makeNote(text: "Before")
        state.cueNotes = [original]
        var draft = original
        draft.areaStrokeWidth = 0

        state.notinhasCommitNoteEdit(draft: draft, openingSnapshot: original)

        XCTAssertEqual(
            state.cueNotes[0].areaStrokeWidth,
            AnnotationStrokeWidth.minPoints,
            accuracy: 0.001,
        )
    }

    func testRevertNoteRestoresOpeningSnapshot() {
        let state = makeState()
        let original = makeNote(text: "Before")
        state.cueNotes = [original]
        var edited = original
        edited.text = "After"
        edited.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        edited.areaStyle = .hatched
        edited.pinControlValue = 9
        state.cueNotes = [edited]

        state.notinhasRevertNote(to: original)

        XCTAssertEqual(state.cueNotes[0].text, original.text)
        XCTAssertEqual(state.cueNotes[0].color, original.color)
        XCTAssertEqual(state.cueNotes[0].areaStyle, original.areaStyle)
        XCTAssertEqual(state.cueNotes[0].pinControlValue, 9)
        XCTAssertFalse(state.canUndo)
    }

    func testSaveAfterLiveAppearanceCreatesOneUndoCheckpoint() {
        let state = makeState()
        let original = makeNote(text: "Before")
        state.cueNotes = [original]
        var live = original
        live.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        state.notinhasApplyLiveAppearance(live)

        var saved = live
        saved.text = "After"
        state.notinhasCommitNoteEdit(draft: saved, openingSnapshot: original)

        XCTAssertEqual(state.cueNotes[0].text, "After")
        state.undo()
        XCTAssertEqual(state.cueNotes, [original])
    }

    func testCloseEditorRevertsLiveAppearance() {
        let state = makeState()
        let original = makeNote(text: "Keep")
        state.cueNotes = [original]
        state.notinhasEditorOpeningSnapshot = original
        state.notinhasEditingNoteID = original.id
        var live = original
        live.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        state.notinhasApplyLiveAppearance(live)

        state.notinhasCloseEditor(discardIfEmpty: true, revertLiveAppearance: true)

        XCTAssertEqual(state.cueNotes[0].color, original.color)
        XCTAssertNil(state.notinhasEditingNoteID)
        XCTAssertNil(state.notinhasEditorOpeningSnapshot)
        XCTAssertFalse(state.canUndo)
    }

    func testCommitNoteEditPreservesPinControlValue() {
        let state = makeState()
        var original = makeNote(text: "Before")
        original.pinControlValue = 4
        state.cueNotes = [original]
        state.notinhasSelectedNoteID = original.id
        state.activateTool(.cueNote)
        state.quickStrokeWidthBinding.wrappedValue = 8

        var draft = original
        draft.text = "After"
        draft.color = RGBAColor(red: 0, green: 1, blue: 0, alpha: 1)
        state.notinhasCommitNoteEdit(draft: draft, openingSnapshot: original)

        XCTAssertEqual(state.cueNotes[0].text, "After")
        XCTAssertEqual(state.cueNotes[0].color, draft.color)
        XCTAssertEqual(state.cueNotes[0].pinControlValue, 8)
    }

    func testCommitNoteEditRemembersColorForNextAnnotation() {
        let defaults = UserDefaultsFactory.make()
        let state = AnnotateState(defaults: defaults)
        let original = makeNote()
        state.cueNotes = [original]
        var draft = original
        draft.color = CuePaletteColor.green.rgba

        state.notinhasCommitNoteEdit(draft: draft, openingSnapshot: original)

        let reloadedState = AnnotateState(defaults: defaults)
        reloadedState.activateTool(.rectangle)
        XCTAssertEqual(
            RGBAColor(color: reloadedState.quickStrokeColorBinding.wrappedValue),
            CuePaletteColor.green.rgba,
        )
    }
}

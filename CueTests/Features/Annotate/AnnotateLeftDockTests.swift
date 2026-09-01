//
//  AnnotateLeftDockTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

final class AnnotateLeftDockTests: XCTestCase {
    @MainActor private static var retainedAnnotateStates: [AnnotateState] = []

    @MainActor
    private func makeAnnotateState() -> AnnotateState {
        let state = AnnotateState()
        Self.retainedAnnotateStates.append(state)
        return state
    }

    @MainActor
    private func makeNote(text: String = "Note") -> CueVisualNote {
        CueVisualNote(
            text: text,
            target: .point(.zero),
            color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            creationOrder: 1,
        )
    }

    @MainActor
    func testAddingFirstNoteOpensNotesDock() {
        let state = makeAnnotateState()
        XCTAssertEqual(state.leftDock, .hidden)

        state.notinhasAddNote(makeNote())

        XCTAssertEqual(state.leftDock, .notes)
    }

    @MainActor
    func testRemovingLastNoteHidesNotesDock() {
        let state = makeAnnotateState()
        let note = makeNote()
        state.notinhasAddNote(note)
        XCTAssertEqual(state.leftDock, .notes)

        state.notinhasDeleteNote(id: note.id)

        XCTAssertTrue(state.cueNotes.isEmpty)
        XCTAssertEqual(state.leftDock, .hidden)
    }

    @MainActor
    func testAddBackgroundOpensBackgroundAndHidesNotes() {
        let state = makeAnnotateState()
        state.notinhasAddNote(makeNote())
        XCTAssertEqual(state.leftDock, .notes)

        state.toggleSidebarVisibility()

        XCTAssertEqual(state.leftDock, .background)
    }

    @MainActor
    func testDismissBackgroundRestoresNotesWhenNotesRemain() {
        let state = makeAnnotateState()
        state.notinhasAddNote(makeNote())
        state.toggleSidebarVisibility()
        XCTAssertEqual(state.leftDock, .background)

        state.toggleSidebarVisibility()

        XCTAssertEqual(state.leftDock, .notes)
    }

    @MainActor
    func testDismissBackgroundHidesDockWhenNoNotesRemain() {
        let state = makeAnnotateState()

        state.toggleSidebarVisibility()
        XCTAssertEqual(state.leftDock, .background)

        state.toggleSidebarVisibility()

        XCTAssertEqual(state.leftDock, .hidden)
    }

    @MainActor
    func testAddingNoteWhileBackgroundOpenKeepsBackgroundDock() {
        let state = makeAnnotateState()
        state.toggleSidebarVisibility()
        XCTAssertEqual(state.leftDock, .background)

        state.notinhasAddNote(makeNote())

        XCTAssertEqual(state.leftDock, .background)
    }

    @MainActor
    func testToggleSidebarVisibilitySkipsPreviewMode() {
        let state = makeAnnotateState()

        state.toggleSidebarVisibility()
        XCTAssertEqual(state.leftDock, .background)

        state.editorMode = .preview
        state.toggleSidebarVisibility()
        XCTAssertEqual(state.leftDock, .background)

        state.editorMode = .annotate
        state.toggleSidebarVisibility()
        XCTAssertEqual(state.leftDock, .hidden)
    }
}

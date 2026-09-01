import AppKit
import Foundation

// MARK: - Notinhas Annotate State

extension AnnotateState {
    func notinhasAddNote(_ note: CueVisualNote) {
        saveState()
        cueNotes.append(note)
        notinhasSelectedNoteID = note.id
        notinhasEditingNoteID = note.id
    }

    func notinhasUpdateNote(_ note: CueVisualNote) {
        guard let index = cueNotes.firstIndex(where: { $0.id == note.id }) else { return }
        guard cueNotes[index] != note else { return }
        saveState()
        cueNotes[index] = note
    }

    /// Commits editor-owned fields (text, color, areaStyle, areaStrokeWidth) and records one
    /// undo checkpoint back to `openingSnapshot` for those fields. Preserves live
    /// `pinControlValue` and `target`.
    func notinhasCommitNoteEdit(draft: CueVisualNote, openingSnapshot: CueVisualNote) {
        guard let index = cueNotes.firstIndex(where: { $0.id == draft.id }) else { return }
        var committed = cueNotes[index]
        committed.text = draft.text
        committed.color = draft.color
        committed.areaStyle = draft.areaStyle
        committed.areaStrokeWidth = CueVisualNote.clampedAreaStrokeWidth(draft.areaStrokeWidth)

        var checkpoint = openingSnapshot
        checkpoint.pinControlValue = committed.pinControlValue
        checkpoint.target = committed.target

        guard committed != cueNotes[index] || checkpoint != committed else { return }
        if checkpoint != committed {
            var checkpointNotes = cueNotes
            checkpointNotes[index] = checkpoint
            saveNotinhasNotesUndoCheckpoint(checkpointNotes)
        }
        cueNotes[index] = committed
        if committed.color != openingSnapshot.color {
            rememberNotinhasColor(committed.color)
        }
    }

    /// Mutates color, area style, and stroke width without creating an undo checkpoint.
    /// Text is not applied here.
    func notinhasApplyLiveAppearance(_ note: CueVisualNote) {
        guard let index = cueNotes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = cueNotes[index]
        updated.color = note.color
        updated.areaStyle = note.areaStyle
        updated.areaStrokeWidth = CueVisualNote.clampedAreaStrokeWidth(note.areaStrokeWidth)
        guard cueNotes[index].color != updated.color
            || cueNotes[index].areaStyle != updated.areaStyle
            || cueNotes[index].areaStrokeWidth != updated.areaStrokeWidth else { return }
        cueNotes[index] = updated
    }

    /// Restores editor-owned fields from the opening snapshot without an undo checkpoint.
    /// Preserves live `pinControlValue` and `target` (changed outside the editor).
    func notinhasRevertNote(to snapshot: CueVisualNote) {
        guard let index = cueNotes.firstIndex(where: { $0.id == snapshot.id }) else { return }
        var restored = snapshot
        restored.pinControlValue = cueNotes[index].pinControlValue
        restored.target = cueNotes[index].target
        guard cueNotes[index] != restored else { return }
        cueNotes[index] = restored
    }

    func notinhasDeleteNote(id: UUID) {
        guard cueNotes.contains(where: { $0.id == id }) else { return }
        saveState()
        cueNotes.removeAll { $0.id == id }
        if notinhasSelectedNoteID == id {
            notinhasSelectedNoteID = nil
        }
        if notinhasEditingNoteID == id {
            notinhasEditingNoteID = nil
        }
        notinhasEditorOpeningSnapshot = nil
    }

    func notinhasSelectNote(id: UUID?, beginEditing: Bool = true) {
        notinhasSelectedNoteID = id
        if beginEditing, let id {
            notinhasEditingNoteID = id
        } else {
            notinhasEditingNoteID = nil
        }
    }

    func notinhasBeginMovingNote(id: UUID) {
        guard let note = cueNotes.first(where: { $0.id == id }) else { return }
        notinhasMovingNoteID = id
        notinhasMoveOriginalTarget = note.target
        cueMovePreviewTarget = nil
    }

    func notinhasUpdateMovingNote(
        to imagePoint: CGPoint,
        imageBounds: CGRect,
        from startPoint: CGPoint,
    ) {
        guard notinhasMovingNoteID != nil,
              let original = notinhasMoveOriginalTarget else { return }
        let delta = CGPoint(x: imagePoint.x - startPoint.x, y: imagePoint.y - startPoint.y)
        cueMovePreviewTarget = CueNoteGeometry.translated(
            original,
            by: delta,
            within: imageBounds,
        )
    }

    func notinhasUpdateResizingNote(
        to imagePoint: CGPoint,
        imageBounds: CGRect,
        handle: CueNoteGeometry.ResizeHandle,
    ) {
        guard notinhasMovingNoteID != nil,
              let original = notinhasMoveOriginalTarget else { return }
        cueMovePreviewTarget = CueNoteGeometry.resized(
            original,
            handle: handle,
            to: imagePoint,
            within: imageBounds,
        )
    }

    /// Resolved target for canvas drawing and hit tests while a move gesture is active.
    func notinhasResolvedTarget(for noteID: UUID) -> CueNoteTarget? {
        guard let note = cueNotes.first(where: { $0.id == noteID }) else { return nil }
        if noteID == notinhasMovingNoteID, let preview = cueMovePreviewTarget {
            return preview
        }
        return note.target
    }

    func notinhasCommitMovingNote() {
        guard let id = notinhasMovingNoteID,
              let original = notinhasMoveOriginalTarget,
              let index = cueNotes.firstIndex(where: { $0.id == id }) else {
            notinhasCancelMovingNote()
            return
        }

        let finalTarget = cueMovePreviewTarget ?? cueNotes[index].target
        if finalTarget != original {
            var checkpointNotes = cueNotes
            checkpointNotes[index].target = original
            saveNotinhasNotesUndoCheckpoint(checkpointNotes)
        }
        cueNotes[index].target = finalTarget

        notinhasMovingNoteID = nil
        notinhasMoveOriginalTarget = nil
        cueMovePreviewTarget = nil
    }

    func notinhasCancelMovingNote() {
        notinhasMovingNoteID = nil
        notinhasMoveOriginalTarget = nil
        cueMovePreviewTarget = nil
    }

    /// Closes the note editor. Pass `revertLiveAppearance` to restore the opening snapshot
    /// (Cancel, click-away, tool switch). Save commits first, then closes without reverting.
    func notinhasCloseEditor(discardIfEmpty: Bool = true, revertLiveAppearance: Bool = false) {
        notinhasCancelMovingNote()
        if revertLiveAppearance, let snapshot = notinhasEditorOpeningSnapshot {
            notinhasRevertNote(to: snapshot)
        }
        if discardIfEmpty,
           let editingID = notinhasEditingNoteID,
           let note = cueNotes.first(where: { $0.id == editingID }),
           note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cueNotes.removeAll { $0.id == editingID }
        }
        notinhasEditingNoteID = nil
        cueDraftNote = nil
        notinhasIsDrawingNote = false
        cueNoteDrawStart = nil
        notinhasEditorOpeningSnapshot = nil
    }

    func cueNote(at point: CGPoint) -> CueVisualNote? {
        for note in cueNotes.reversed() {
            var candidate = note
            if let resolved = notinhasResolvedTarget(for: note.id) {
                candidate.target = resolved
            }
            if CueNoteGeometry.hitTest(note: candidate, at: point) {
                return note
            }
        }
        return nil
    }

    func notinhasDisplayNumber(for noteID: UUID) -> Int? {
        guard let note = cueNotes.first(where: { $0.id == noteID }) else { return nil }
        return CueNoteGeometry.canvasDisplayNumber(for: noteID, in: cueNotes)
    }

    func notinhasRestoreNotes(_ notes: [CueVisualNote]) {
        notinhasCancelMovingNote()
        cueNotes = notes
        notinhasSelectedNoteID = nil
        notinhasEditingNoteID = nil
        notinhasEditorOpeningSnapshot = nil
        cueDraftNote = nil
        notinhasIsDrawingNote = false
        cueNoteDrawStart = nil
    }

    func notinhasClearDrawingState() {
        cueDraftNote = nil
        notinhasIsDrawingNote = false
        cueNoteDrawStart = nil
    }

    func notinhasBeginDrawing(at point: CGPoint, color: RGBAColor) {
        cueNoteDrawStart = point
        notinhasIsDrawingNote = true
        cueDraftNote = CueVisualNote(
            target: .point(point),
            color: color,
            pinControlValue: defaultNotinhasPinControlValue(),
            creationOrder: CueNoteGeometry.nextCreationOrder(in: cueNotes),
        )
    }

    func notinhasUpdateDrawing(to point: CGPoint, imageBounds: CGRect) {
        guard let start = cueNoteDrawStart, var draft = cueDraftNote else { return }
        let distance = hypot(point.x - start.x, point.y - start.y)
        if CueNoteGeometry.shouldCreateRect(dragDistance: distance) {
            let pinCorner = CueRectPinCorner.fromDrag(start: start, end: point)
            draft.target = .rect(
                CueNoteGeometry.clampedRect(from: start, to: point, within: imageBounds),
                pinCorner,
            )
        } else {
            draft.target = .point(CueNoteGeometry.clampedPoint(start, within: imageBounds))
        }
        cueDraftNote = draft
    }

    func notinhasCommitDraft(color: RGBAColor) {
        guard var draft = cueDraftNote else { return }
        draft.color = color
        notinhasAddNote(draft)
        notinhasClearDrawingState()
    }

    var showsNotinhasExportPreview: Bool {
        editorMode == .preview
            && !CueNoteGeometry.orderedRenderableNotes(cueNotes).isEmpty
    }

    func refreshNotinhasExportPreview() {
        guard showsNotinhasExportPreview else {
            notinhasExportPreviewImage = nil
            return
        }
        // Uses renderFinalImage(state:) verbatim so Copy and Preview cannot drift.
        notinhasExportPreviewImage = AnnotateExporter.renderFinalImage(state: self)
    }
}

import AppKit
import Foundation

// MARK: - Notinhas Annotate State

extension AnnotateState {
    func notinhasAddNote(_ note: NotinhasVisualNote) {
        saveState()
        notinhasNotes.append(note)
        notinhasSelectedNoteID = note.id
        notinhasEditingNoteID = note.id
    }

    func notinhasUpdateNote(_ note: NotinhasVisualNote) {
        guard let index = notinhasNotes.firstIndex(where: { $0.id == note.id }) else { return }
        guard notinhasNotes[index] != note else { return }
        saveState()
        notinhasNotes[index] = note
    }

    /// Commits editor-owned fields (text, color, areaStyle, areaStrokeWidth) and records one
    /// undo checkpoint back to `openingSnapshot` for those fields. Preserves live
    /// `pinControlValue` and `target`.
    func notinhasCommitNoteEdit(draft: NotinhasVisualNote, openingSnapshot: NotinhasVisualNote) {
        guard let index = notinhasNotes.firstIndex(where: { $0.id == draft.id }) else { return }
        var committed = notinhasNotes[index]
        committed.text = draft.text
        committed.color = draft.color
        committed.areaStyle = draft.areaStyle
        committed.areaStrokeWidth = NotinhasVisualNote.clampedAreaStrokeWidth(draft.areaStrokeWidth)

        var checkpoint = openingSnapshot
        checkpoint.pinControlValue = committed.pinControlValue
        checkpoint.target = committed.target

        guard committed != notinhasNotes[index] || checkpoint != committed else { return }
        if checkpoint != committed {
            var checkpointNotes = notinhasNotes
            checkpointNotes[index] = checkpoint
            saveNotinhasNotesUndoCheckpoint(checkpointNotes)
        }
        notinhasNotes[index] = committed
        if committed.color != openingSnapshot.color {
            rememberNotinhasColor(committed.color)
        }
    }

    /// Mutates color, area style, and stroke width without creating an undo checkpoint.
    /// Text is not applied here.
    func notinhasApplyLiveAppearance(_ note: NotinhasVisualNote) {
        guard let index = notinhasNotes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = notinhasNotes[index]
        updated.color = note.color
        updated.areaStyle = note.areaStyle
        updated.areaStrokeWidth = NotinhasVisualNote.clampedAreaStrokeWidth(note.areaStrokeWidth)
        guard notinhasNotes[index].color != updated.color
            || notinhasNotes[index].areaStyle != updated.areaStyle
            || notinhasNotes[index].areaStrokeWidth != updated.areaStrokeWidth else { return }
        notinhasNotes[index] = updated
    }

    /// Restores editor-owned fields from the opening snapshot without an undo checkpoint.
    /// Preserves live `pinControlValue` and `target` (changed outside the editor).
    func notinhasRevertNote(to snapshot: NotinhasVisualNote) {
        guard let index = notinhasNotes.firstIndex(where: { $0.id == snapshot.id }) else { return }
        var restored = snapshot
        restored.pinControlValue = notinhasNotes[index].pinControlValue
        restored.target = notinhasNotes[index].target
        guard notinhasNotes[index] != restored else { return }
        notinhasNotes[index] = restored
    }

    func notinhasDeleteNote(id: UUID) {
        guard notinhasNotes.contains(where: { $0.id == id }) else { return }
        saveState()
        notinhasNotes.removeAll { $0.id == id }
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
        guard let note = notinhasNotes.first(where: { $0.id == id }) else { return }
        notinhasMovingNoteID = id
        notinhasMoveOriginalTarget = note.target
        notinhasMovePreviewTarget = nil
    }

    func notinhasUpdateMovingNote(
        to imagePoint: CGPoint,
        imageBounds: CGRect,
        from startPoint: CGPoint,
    ) {
        guard notinhasMovingNoteID != nil,
              let original = notinhasMoveOriginalTarget else { return }
        let delta = CGPoint(x: imagePoint.x - startPoint.x, y: imagePoint.y - startPoint.y)
        notinhasMovePreviewTarget = NotinhasNoteGeometry.translated(
            original,
            by: delta,
            within: imageBounds,
        )
    }

    func notinhasUpdateResizingNote(
        to imagePoint: CGPoint,
        imageBounds: CGRect,
        handle: NotinhasNoteGeometry.ResizeHandle,
    ) {
        guard notinhasMovingNoteID != nil,
              let original = notinhasMoveOriginalTarget else { return }
        notinhasMovePreviewTarget = NotinhasNoteGeometry.resized(
            original,
            handle: handle,
            to: imagePoint,
            within: imageBounds,
        )
    }

    /// Resolved target for canvas drawing and hit tests while a move gesture is active.
    func notinhasResolvedTarget(for noteID: UUID) -> NotinhasNoteTarget? {
        guard let note = notinhasNotes.first(where: { $0.id == noteID }) else { return nil }
        if noteID == notinhasMovingNoteID, let preview = notinhasMovePreviewTarget {
            return preview
        }
        return note.target
    }

    func notinhasCommitMovingNote() {
        guard let id = notinhasMovingNoteID,
              let original = notinhasMoveOriginalTarget,
              let index = notinhasNotes.firstIndex(where: { $0.id == id }) else {
            notinhasCancelMovingNote()
            return
        }

        let finalTarget = notinhasMovePreviewTarget ?? notinhasNotes[index].target
        if finalTarget != original {
            var checkpointNotes = notinhasNotes
            checkpointNotes[index].target = original
            saveNotinhasNotesUndoCheckpoint(checkpointNotes)
        }
        notinhasNotes[index].target = finalTarget

        notinhasMovingNoteID = nil
        notinhasMoveOriginalTarget = nil
        notinhasMovePreviewTarget = nil
    }

    func notinhasCancelMovingNote() {
        notinhasMovingNoteID = nil
        notinhasMoveOriginalTarget = nil
        notinhasMovePreviewTarget = nil
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
           let note = notinhasNotes.first(where: { $0.id == editingID }),
           note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notinhasNotes.removeAll { $0.id == editingID }
        }
        notinhasEditingNoteID = nil
        notinhasDraftNote = nil
        notinhasIsDrawingNote = false
        notinhasNoteDrawStart = nil
        notinhasEditorOpeningSnapshot = nil
    }

    func notinhasNote(at point: CGPoint) -> NotinhasVisualNote? {
        for note in notinhasNotes.reversed() {
            var candidate = note
            if let resolved = notinhasResolvedTarget(for: note.id) {
                candidate.target = resolved
            }
            if NotinhasNoteGeometry.hitTest(note: candidate, at: point) {
                return note
            }
        }
        return nil
    }

    func notinhasDisplayNumber(for noteID: UUID) -> Int? {
        guard let note = notinhasNotes.first(where: { $0.id == noteID }) else { return nil }
        return NotinhasNoteGeometry.canvasDisplayNumber(for: noteID, in: notinhasNotes)
    }

    func notinhasRestoreNotes(_ notes: [NotinhasVisualNote]) {
        notinhasCancelMovingNote()
        notinhasNotes = notes
        notinhasSelectedNoteID = nil
        notinhasEditingNoteID = nil
        notinhasEditorOpeningSnapshot = nil
        notinhasDraftNote = nil
        notinhasIsDrawingNote = false
        notinhasNoteDrawStart = nil
    }

    func notinhasClearDrawingState() {
        notinhasDraftNote = nil
        notinhasIsDrawingNote = false
        notinhasNoteDrawStart = nil
    }

    func notinhasBeginDrawing(at point: CGPoint, color: RGBAColor) {
        notinhasNoteDrawStart = point
        notinhasIsDrawingNote = true
        notinhasDraftNote = NotinhasVisualNote(
            target: .point(point),
            color: color,
            pinControlValue: defaultNotinhasPinControlValue(),
            creationOrder: NotinhasNoteGeometry.nextCreationOrder(in: notinhasNotes),
        )
    }

    func notinhasUpdateDrawing(to point: CGPoint, imageBounds: CGRect) {
        guard let start = notinhasNoteDrawStart, var draft = notinhasDraftNote else { return }
        let distance = hypot(point.x - start.x, point.y - start.y)
        if NotinhasNoteGeometry.shouldCreateRect(dragDistance: distance) {
            draft.target = .rect(NotinhasNoteGeometry.clampedRect(from: start, to: point, within: imageBounds))
        } else {
            draft.target = .point(NotinhasNoteGeometry.clampedPoint(start, within: imageBounds))
        }
        notinhasDraftNote = draft
    }

    func notinhasCommitDraft(color: RGBAColor) {
        guard var draft = notinhasDraftNote else { return }
        draft.color = color
        notinhasAddNote(draft)
        notinhasClearDrawingState()
    }

    var showsNotinhasExportPreview: Bool {
        editorMode == .preview
            && !NotinhasNoteGeometry.orderedRenderableNotes(notinhasNotes).isEmpty
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

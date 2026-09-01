import SwiftUI

/// SwiftUI overlay for editing Notinhas notes on the annotate canvas viewport.
/// Empty space must not hit-test so canvas click-away still reaches `DrawingCanvasNSView`.
struct NotinhasNoteEditorCanvasOverlay: View {
    @ObservedObject var state: AnnotateState
    let scale: CGFloat
    let canvasBounds: CGRect
    let hostSize: CGSize
    let foregroundOffset: CGPoint
    let backgroundDisplaySize: CGSize
    let zoomLevel: CGFloat
    let panOffset: CGSize

    @State private var draftNote: NotinhasVisualNote?
    @State private var openingSnapshot: NotinhasVisualNote?
    @State private var panelPlacement = NotinhasNoteEditorPanelPlacement()
    @State private var lastTrackedPanelSize: CGSize?
    @State private var lastTrackedHostSize: CGSize?

    var body: some View {
        if let editingID = state.notinhasEditingNoteID,
           let note = state.notinhasNotes.first(where: { $0.id == editingID }) {
            let workArea = CGRect(origin: .zero, size: hostSize)
            let selectionInForeground = NotinhasNoteGeometry.selectionDisplayBounds(
                for: note.target,
                canvasBounds: canvasBounds,
                displayScale: scale,
                pinDiameter: note.pinDiameter,
            )
            let selectionInWorkArea = NotinhasNoteGeometry.selectionBoundsInEditorWorkArea(
                selectionInForeground: selectionInForeground,
                foregroundOffsetInBackground: foregroundOffset,
                backgroundDisplaySize: backgroundDisplaySize,
                workAreaSize: hostSize,
                zoomLevel: zoomLevel,
                panOffset: panOffset,
            )
            let panelSize = NotinhasNoteGeometry.editorPanelSize(
                isRectangular: note.target.isRectangular,
                in: workArea,
            )
            let origin = panelPlacement.displayOrigin(
                selectionBounds: selectionInWorkArea,
                panelSize: panelSize,
                in: workArea,
            )
            let displayNumber = state.notinhasDisplayNumber(for: editingID) ?? 1

            // Layout host only — no full-bleed clear fill, so empty space passes hits to the canvas.
            ZStack(alignment: .topLeading) {
                NotinhasNoteEditorView(
                    displayNumber: displayNumber,
                    panelWidth: panelSize.width,
                    maxPanelHeight: panelSize.height,
                    text: draftTextBinding(for: note),
                    color: draftColorBinding(for: note),
                    areaStyle: draftAreaStyleBinding(for: note),
                    areaStrokeWidth: draftAreaStrokeWidthBinding(for: note),
                    showsAreaStyle: note.target.isRectangular,
                    onCommit: commitEditing,
                    onCancel: cancelEditing,
                    onDelete: deleteEditing,
                    onPanelDragChanged: { translation in
                        handlePanelDragChanged(
                            translation,
                            selectionBounds: selectionInWorkArea,
                            panelSize: panelSize,
                            workArea: workArea,
                        )
                    },
                    onPanelDragEnded: {
                        endPanelDrag(panelSize: panelSize, workArea: workArea)
                    },
                )
                .offset(x: origin.x, y: origin.y)
            }
            .frame(width: hostSize.width, height: hostSize.height, alignment: .topLeading)
            .onAppear {
                panelPlacement.ensureSeeded(
                    selectionBounds: selectionInWorkArea,
                    panelSize: panelSize,
                    in: workArea,
                )
                lastTrackedPanelSize = panelSize
                lastTrackedHostSize = hostSize
            }
            .task(id: editingID) {
                ensureDraftSeeded(from: note)
            }
            .onChange(of: panelSize) { newPanelSize in
                reconcilePlacementIfNeeded(
                    panelSize: newPanelSize,
                    hostSize: hostSize,
                    workArea: workArea,
                )
            }
            .onChange(of: hostSize) { newHostSize in
                let updatedWorkArea = CGRect(origin: .zero, size: newHostSize)
                reconcilePlacementIfNeeded(
                    panelSize: panelSize,
                    hostSize: newHostSize,
                    workArea: updatedWorkArea,
                )
            }
            .onDisappear {
                panelPlacement.reset()
                lastTrackedPanelSize = nil
                lastTrackedHostSize = nil
            }
        }
    }

    private func reconcilePlacementIfNeeded(
        panelSize: CGSize,
        hostSize: CGSize,
        workArea: CGRect,
    ) {
        guard !panelPlacement.isDragging else { return }

        let panelChanged = lastTrackedPanelSize.map {
            !NotinhasNoteGeometry.sizesAreEffectivelyEqual($0, panelSize)
        } ?? true
        let hostChanged = lastTrackedHostSize.map {
            !NotinhasNoteGeometry.sizesAreEffectivelyEqual($0, hostSize)
        } ?? true
        guard panelChanged || hostChanged else { return }

        panelPlacement.reclamp(panelSize: panelSize, in: workArea)
        lastTrackedPanelSize = panelSize
        lastTrackedHostSize = hostSize
    }

    private func handlePanelDragChanged(
        _ translation: CGSize,
        selectionBounds: CGRect,
        panelSize: CGSize,
        workArea: CGRect,
    ) {
        panelPlacement.beginDrag(
            selectionBounds: selectionBounds,
            panelSize: panelSize,
            in: workArea,
        )
        panelPlacement.updateDrag(
            translation: translation,
            panelSize: panelSize,
            in: workArea,
        )
    }

    private func endPanelDrag(panelSize: CGSize, workArea: CGRect) {
        panelPlacement.endDrag()
        // Mid-drag host/panel onChange is ignored while `isDragging`; reclamp once so a
        // resize that happened without further drag samples cannot leave the origin OOB.
        panelPlacement.reclamp(panelSize: panelSize, in: workArea)
        lastTrackedPanelSize = panelSize
        lastTrackedHostSize = workArea.size
    }

    private func draftTextBinding(for note: NotinhasVisualNote) -> Binding<String> {
        Binding(
            get: { activeDraft(for: note).text },
            set: { newValue in
                updateDraft(from: note) { $0.text = newValue }
            },
        )
    }

    private func draftColorBinding(for note: NotinhasVisualNote) -> Binding<RGBAColor> {
        Binding(
            get: { activeDraft(for: note).color },
            set: { newValue in
                applyLiveAppearance(from: note, color: newValue, areaStyle: nil, areaStrokeWidth: nil)
            },
        )
    }

    private func draftAreaStyleBinding(for note: NotinhasVisualNote) -> Binding<NotinhasAreaStyle> {
        Binding(
            get: { activeDraft(for: note).areaStyle },
            set: { newValue in
                applyLiveAppearance(from: note, color: nil, areaStyle: newValue, areaStrokeWidth: nil)
            },
        )
    }

    private func draftAreaStrokeWidthBinding(for note: NotinhasVisualNote) -> Binding<CGFloat> {
        Binding(
            get: { activeDraft(for: note).areaStrokeWidth },
            set: { newValue in
                applyLiveAppearance(from: note, color: nil, areaStyle: nil, areaStrokeWidth: newValue)
            },
        )
    }

    private func activeDraft(for note: NotinhasVisualNote) -> NotinhasVisualNote {
        if let draftNote, draftNote.id == note.id {
            return draftNote
        }
        return note
    }

    private func ensureDraftSeeded(from note: NotinhasVisualNote) {
        if draftNote?.id != note.id {
            draftNote = note
        }
        if openingSnapshot?.id != note.id {
            openingSnapshot = note
            state.notinhasEditorOpeningSnapshot = note
        }
    }

    private func updateDraft(from note: NotinhasVisualNote, mutate: (inout NotinhasVisualNote) -> Void) {
        ensureDraftSeeded(from: note)
        guard var updated = draftNote, updated.id == note.id else { return }
        mutate(&updated)
        draftNote = updated
    }

    private func commitEditing() {
        if let draftNote, let openingSnapshot {
            state.notinhasCommitNoteEdit(draft: draftNote, openingSnapshot: openingSnapshot)
        }
        state.notinhasCloseEditor(discardIfEmpty: true)
    }

    private func cancelEditing() {
        state.notinhasCloseEditor(discardIfEmpty: true, revertLiveAppearance: true)
    }

    private func deleteEditing() {
        if let editingID = state.notinhasEditingNoteID {
            state.notinhasDeleteNote(id: editingID)
        }
    }

    private func applyLiveAppearance(
        from note: NotinhasVisualNote,
        color: RGBAColor?,
        areaStyle: NotinhasAreaStyle?,
        areaStrokeWidth: CGFloat?,
    ) {
        updateDraft(from: note) { updated in
            if let color {
                updated.color = color
            }
            if let areaStyle {
                updated.areaStyle = areaStyle
            }
            if let areaStrokeWidth {
                updated.areaStrokeWidth = NotinhasVisualNote.clampedAreaStrokeWidth(areaStrokeWidth)
            }
        }

        guard let updated = draftNote else { return }
        var liveNote = updated
        if let stateNote = state.notinhasNotes.first(where: { $0.id == updated.id }) {
            liveNote.text = stateNote.text
        }
        state.notinhasApplyLiveAppearance(liveNote)
    }
}

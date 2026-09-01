//
//  CueNoteEditorPanelPlacement.swift
//  Notinhas
//
//  Transient UI-space placement for the contextual note editor panel.
//

import CoreGraphics
import Foundation

struct CueNoteEditorPanelPlacement: Equatable {
    private(set) var origin: CGPoint?
    private var dragAnchorOrigin: CGPoint?
    private var lastReclampPanelSize: CGSize?
    private var lastReclampContainerSize: CGSize?

    var isDragging: Bool {
        dragAnchorOrigin != nil
    }

    mutating func reset() {
        origin = nil
        dragAnchorOrigin = nil
        lastReclampPanelSize = nil
        lastReclampContainerSize = nil
    }

    /// Non-mutating origin for layout; falls back to automatic placement without persisting.
    func displayOrigin(
        selectionBounds: CGRect,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) -> CGPoint {
        if let origin {
            return origin
        }

        return CueNoteGeometry.editorOrigin(
            forSelectionBounds: selectionBounds,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
    }

    mutating func ensureSeeded(
        selectionBounds: CGRect,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) {
        guard origin == nil else { return }
        origin = CueNoteGeometry.editorOrigin(
            forSelectionBounds: selectionBounds,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
        recordReclampSizes(panelSize: panelSize, containerSize: containerBounds.size)
    }

    mutating func reclamp(
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) {
        guard let origin else { return }
        guard !isDragging else { return }
        let containerSize = containerBounds.size
        if let lastReclampPanelSize,
           let lastReclampContainerSize,
           CueNoteGeometry.sizesAreEffectivelyEqual(lastReclampPanelSize, panelSize),
           CueNoteGeometry.sizesAreEffectivelyEqual(lastReclampContainerSize, containerSize) {
            return
        }
        self.origin = CueNoteGeometry.clampedEditorPanelOrigin(
            origin,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
        recordReclampSizes(panelSize: panelSize, containerSize: containerSize)
    }

    mutating func resolvedOrigin(
        selectionBounds: CGRect,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) -> CGPoint {
        ensureSeeded(
            selectionBounds: selectionBounds,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
        return displayOrigin(
            selectionBounds: selectionBounds,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
    }

    mutating func beginDrag(
        selectionBounds: CGRect,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) {
        if dragAnchorOrigin == nil {
            ensureSeeded(
                selectionBounds: selectionBounds,
                panelSize: panelSize,
                in: containerBounds,
                margin: margin,
            )
            dragAnchorOrigin = displayOrigin(
                selectionBounds: selectionBounds,
                panelSize: panelSize,
                in: containerBounds,
                margin: margin,
            )
        }
    }

    mutating func updateDrag(
        translation: CGSize,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) {
        guard let dragAnchorOrigin else { return }
        applyDrag(
            from: dragAnchorOrigin,
            translation: translation,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
    }

    mutating func endDrag() {
        dragAnchorOrigin = nil
    }

    mutating func applyDrag(
        from startOrigin: CGPoint,
        translation: CGSize,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) {
        let proposed = CGPoint(
            x: startOrigin.x + translation.width,
            y: startOrigin.y + translation.height,
        )
        origin = CueNoteGeometry.clampedEditorPanelOrigin(
            proposed,
            panelSize: panelSize,
            in: containerBounds,
            margin: margin,
        )
        recordReclampSizes(panelSize: panelSize, containerSize: containerBounds.size)
    }

    private mutating func recordReclampSizes(panelSize: CGSize, containerSize: CGSize) {
        lastReclampPanelSize = panelSize
        lastReclampContainerSize = containerSize
    }
}

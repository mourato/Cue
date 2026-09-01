//
//  NotinhasNoteGeometry.swift
//  Notinhas
//
//  Pure geometry helpers for Notinhas notes.
//

import CoreGraphics
import Foundation

nonisolated enum NotinhasNoteGeometry {
    enum ResizeHandle: Equatable {
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
    }

    static let pinDiameter: CGFloat = 28
    static let dragThreshold: CGFloat = 8
    static let minimumRectSize: CGFloat = 24

    static func shouldCreateRect(dragDistance: CGFloat) -> Bool {
        exceedsDragThreshold(dragDistance)
    }

    static func shouldBeginMove(dragDistance: CGFloat) -> Bool {
        exceedsDragThreshold(dragDistance)
    }

    private static func exceedsDragThreshold(_ dragDistance: CGFloat) -> Bool {
        dragDistance >= dragThreshold
    }

    static func translated(
        _ target: NotinhasNoteTarget,
        by delta: CGPoint,
        within bounds: CGRect,
    ) -> NotinhasNoteTarget {
        switch target {
        case .point(let center):
            return .point(clampedPoint(
                CGPoint(x: center.x + delta.x, y: center.y + delta.y),
                within: bounds,
            ))
        case .rect(let rect, let pinCorner):
            let standardized = rect.standardized
            var translated = CGRect(
                x: standardized.origin.x + delta.x,
                y: standardized.origin.y + delta.y,
                width: standardized.width,
                height: standardized.height,
            )
            if translated.width > bounds.width {
                translated.origin.x = bounds.minX
            } else {
                translated.origin.x = max(bounds.minX, min(translated.origin.x, bounds.maxX - translated.width))
            }
            if translated.height > bounds.height {
                translated.origin.y = bounds.minY
            } else {
                translated.origin.y = max(bounds.minY, min(translated.origin.y, bounds.maxY - translated.height))
            }
            return .rect(translated, pinCorner)
        }
    }

    static func resizeHandleCenters(for rect: CGRect) -> [(ResizeHandle, CGPoint)] {
        let standardized = rect.standardized
        return [
            (.topLeft, CGPoint(x: standardized.minX, y: standardized.maxY)),
            (.top, CGPoint(x: standardized.midX, y: standardized.maxY)),
            (.topRight, CGPoint(x: standardized.maxX, y: standardized.maxY)),
            (.left, CGPoint(x: standardized.minX, y: standardized.midY)),
            (.right, CGPoint(x: standardized.maxX, y: standardized.midY)),
            (.bottomLeft, CGPoint(x: standardized.minX, y: standardized.minY)),
            (.bottom, CGPoint(x: standardized.midX, y: standardized.minY)),
            (.bottomRight, CGPoint(x: standardized.maxX, y: standardized.minY)),
        ]
    }

    static func resized(
        _ target: NotinhasNoteTarget,
        handle: ResizeHandle,
        to point: CGPoint,
        within bounds: CGRect,
    ) -> NotinhasNoteTarget {
        guard case .rect(let rect, let pinCorner) = target else { return target }

        let original = rect.standardized
        let imageBounds = bounds.standardized
        let minimumWidth = min(minimumRectSize, imageBounds.width)
        let minimumHeight = min(minimumRectSize, imageBounds.height)
        let clampedPoint = clampedPoint(point, within: imageBounds)
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY

        switch handle {
        case .topLeft:
            minX = min(clampedPoint.x, maxX - minimumWidth)
            maxY = max(clampedPoint.y, minY + minimumHeight)
        case .top:
            maxY = max(clampedPoint.y, minY + minimumHeight)
        case .topRight:
            maxX = max(clampedPoint.x, minX + minimumWidth)
            maxY = max(clampedPoint.y, minY + minimumHeight)
        case .left:
            minX = min(clampedPoint.x, maxX - minimumWidth)
        case .right:
            maxX = max(clampedPoint.x, minX + minimumWidth)
        case .bottomLeft:
            minX = min(clampedPoint.x, maxX - minimumWidth)
            minY = min(clampedPoint.y, maxY - minimumHeight)
        case .bottom:
            minY = min(clampedPoint.y, maxY - minimumHeight)
        case .bottomRight:
            maxX = max(clampedPoint.x, minX + minimumWidth)
            minY = min(clampedPoint.y, maxY - minimumHeight)
        }

        return .rect(
            CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
            pinCorner,
        )
    }

    static func clampedRect(from start: CGPoint, to end: CGPoint, within bounds: CGRect) -> CGRect {
        let standardized = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y),
        ).standardized

        let minSizeRect = minimumSizedRect(standardized)
        return minSizeRect.intersection(bounds.standardized)
    }

    static func clampedPoint(_ point: CGPoint, within bounds: CGRect) -> CGPoint {
        CGPoint(
            x: max(bounds.minX, min(point.x, bounds.maxX)),
            y: max(bounds.minY, min(point.y, bounds.maxY)),
        )
    }

    /// Badge center sits exactly on the chosen vertex of `rect` (image space, y-up).
    static func pinCenter(
        for rect: CGRect,
        pinCorner: NotinhasRectPinCorner = .legacyFallback,
    ) -> CGPoint {
        let standardized = rect.standardized
        switch pinCorner {
        case .topLeft:
            return CGPoint(x: standardized.minX, y: standardized.maxY)
        case .topRight:
            return CGPoint(x: standardized.maxX, y: standardized.maxY)
        case .bottomLeft:
            return CGPoint(x: standardized.minX, y: standardized.minY)
        case .bottomRight:
            return CGPoint(x: standardized.maxX, y: standardized.minY)
        }
    }

    static func pinAnchor(for target: NotinhasNoteTarget) -> CGPoint {
        target.pinCenter
    }

    /// Converts note selection bounds from image space to SwiftUI display space.
    static func selectionDisplayBounds(
        for target: NotinhasNoteTarget,
        canvasBounds: CGRect,
        displayScale: CGFloat,
        pinDiameter: CGFloat = pinDiameter,
    ) -> CGRect {
        let imageBounds = selectionBounds(for: target, pinDiameter: pinDiameter)
        let scaledX = (imageBounds.origin.x - canvasBounds.minX) * displayScale
        let scaledWidth = imageBounds.width * displayScale
        let scaledHeight = imageBounds.height * displayScale
        let flippedY = (canvasBounds.maxY - imageBounds.origin.y - imageBounds.height) * displayScale
        return CGRect(x: scaledX, y: flippedY, width: scaledWidth, height: scaledHeight)
    }

    /// Places the note editor beside the selection (prefer right), then clamps to the container.
    static func editorOrigin(
        forSelectionBounds bounds: CGRect,
        panelSize: CGSize,
        in containerBounds: CGRect,
        gap: CGFloat = 24,
        margin: CGFloat = 12,
    ) -> CGPoint {
        let rightX = bounds.maxX + gap
        let leftX = bounds.minX - panelSize.width - gap
        let fitsRight = rightX + panelSize.width <= containerBounds.maxX - margin
        let fitsLeft = leftX >= containerBounds.minX + margin

        let originX: CGFloat = if fitsRight {
            rightX
        } else if fitsLeft {
            leftX
        } else {
            max(
                containerBounds.minX + margin,
                min(rightX, containerBounds.maxX - panelSize.width - margin),
            )
        }

        var originY = bounds.midY - panelSize.height / 2
        if originY < containerBounds.minY + margin {
            originY = containerBounds.minY + margin
        }
        if originY + panelSize.height > containerBounds.maxY - margin {
            originY = containerBounds.maxY - panelSize.height - margin
        }
        return CGPoint(x: originX, y: originY)
    }

    /// Preferred editor size clamped so the panel never exceeds the container insets.
    /// Height is an upper bound for placement; the SwiftUI editor sizes to its content up to this max.
    static func editorPanelSize(
        isRectangular: Bool,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
        preferredWidth: CGFloat = 300,
        preferredPointHeight: CGFloat = 200,
        preferredRectHeight: CGFloat = 280,
    ) -> CGSize {
        let maxWidth = max(0, containerBounds.width - 2 * margin)
        let maxHeight = max(0, containerBounds.height - 2 * margin)
        let width = min(preferredWidth, maxWidth)
        let preferredHeight = isRectangular ? preferredRectHeight : preferredPointHeight
        let height = min(preferredHeight, maxHeight)
        return CGSize(width: width, height: height)
    }

    /// Returns true when both dimensions differ by at most `epsilon` (sub-point layout noise).
    static func sizesAreEffectivelyEqual(
        _ lhs: CGSize,
        _ rhs: CGSize,
        epsilon: CGFloat = 0.5,
    ) -> Bool {
        abs(lhs.width - rhs.width) <= epsilon && abs(lhs.height - rhs.height) <= epsilon
    }

    /// Clamps a proposed editor-panel origin inside the editor work area.
    static func clampedEditorPanelOrigin(
        _ proposedOrigin: CGPoint,
        panelSize: CGSize,
        in containerBounds: CGRect,
        margin: CGFloat = 12,
    ) -> CGPoint {
        let minX = containerBounds.minX + margin
        let minY = containerBounds.minY + margin
        let maxX = containerBounds.maxX - margin - panelSize.width
        let maxY = containerBounds.maxY - margin - panelSize.height

        let clampedX = maxX < minX ? minX : max(minX, min(proposedOrigin.x, maxX))
        let clampedY = maxY < minY ? minY : max(minY, min(proposedOrigin.y, maxY))
        return CGPoint(x: clampedX, y: clampedY)
    }

    /// Maps selection bounds from foreground display space into the center-pane work area.
    static func selectionBoundsInEditorWorkArea(
        selectionInForeground: CGRect,
        foregroundOffsetInBackground: CGPoint,
        backgroundDisplaySize: CGSize,
        workAreaSize: CGSize,
        zoomLevel: CGFloat,
        panOffset: CGSize,
    ) -> CGRect {
        let selectionInBackground = selectionInForeground.offsetBy(
            dx: foregroundOffsetInBackground.x,
            dy: foregroundOffsetInBackground.y,
        )
        let backgroundOrigin = CGPoint(
            x: (workAreaSize.width - backgroundDisplaySize.width) / 2,
            y: (workAreaSize.height - backgroundDisplaySize.height) / 2,
        )
        let selectionInWorkArea = selectionInBackground.offsetBy(
            dx: backgroundOrigin.x,
            dy: backgroundOrigin.y,
        )
        let pivot = CGPoint(x: workAreaSize.width / 2, y: workAreaSize.height / 2)
        return rectTransformedForViewport(
            selectionInWorkArea,
            zoom: zoomLevel,
            pan: panOffset,
            around: pivot,
        )
    }

    static func rectTransformedForViewport(
        _ rect: CGRect,
        zoom: CGFloat,
        pan: CGSize,
        around pivot: CGPoint,
    ) -> CGRect {
        let mapPoint: (CGPoint) -> CGPoint = { point in
            CGPoint(
                x: pivot.x + (point.x - pivot.x) * zoom + pan.width,
                y: pivot.y + (point.y - pivot.y) * zoom + pan.height,
            )
        }

        let topLeft = mapPoint(rect.origin)
        let bottomRight = mapPoint(CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y),
        )
    }

    static func displayNumber(for note: NotinhasVisualNote, in notes: [NotinhasVisualNote]) -> Int {
        let ordered = orderedRenderableNotes(notes)
        guard let index = ordered.firstIndex(where: { $0.id == note.id }) else {
            return notes.filter(\.hasRenderableContent).count + 1
        }
        return index + 1
    }

    static func nextCreationOrder(in notes: [NotinhasVisualNote]) -> Int {
        (notes.map(\.creationOrder).max() ?? 0) + 1
    }

    static func notesAfterDeletion(
        removing id: UUID,
        from notes: [NotinhasVisualNote],
    ) -> [NotinhasVisualNote] {
        notes.filter { $0.id != id }
    }

    static func orderedRenderableNotes(_ notes: [NotinhasVisualNote]) -> [NotinhasVisualNote] {
        notes
            .filter(\.hasRenderableContent)
            .sorted { lhs, rhs in
                if lhs.creationOrder == rhs.creationOrder {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.creationOrder < rhs.creationOrder
            }
    }

    static func hitTest(note: NotinhasVisualNote, at point: CGPoint) -> Bool {
        selectionBounds(for: note)
            .insetBy(dx: -6, dy: -6)
            .contains(point)
    }

    static func selectionBounds(for note: NotinhasVisualNote) -> CGRect {
        selectionBounds(for: note.target, pinDiameter: note.pinDiameter)
    }

    static func selectionBounds(
        for target: NotinhasNoteTarget,
        pinDiameter: CGFloat = pinDiameter,
    ) -> CGRect {
        switch target {
        case .point(let point):
            return CGRect(
                x: point.x - pinDiameter / 2,
                y: point.y - pinDiameter / 2,
                width: pinDiameter,
                height: pinDiameter,
            )
        case .rect(let rect, let pinCorner):
            let standardized = rect.standardized
            let center = pinCenter(for: standardized, pinCorner: pinCorner)
            let pinBounds = CGRect(
                x: center.x - pinDiameter / 2,
                y: center.y - pinDiameter / 2,
                width: pinDiameter,
                height: pinDiameter,
            )
            return standardized.union(pinBounds)
        }
    }

    static func exportTransformed(
        _ note: NotinhasVisualNote,
        cropOrigin: CGPoint,
        destinationOffset: CGPoint,
    ) -> NotinhasVisualNote {
        var transformed = note
        switch note.target {
        case .point(let point):
            transformed.target = .point(CGPoint(
                x: point.x - cropOrigin.x + destinationOffset.x,
                y: point.y - cropOrigin.y + destinationOffset.y,
            ))
        case .rect(let rect, let pinCorner):
            transformed.target = .rect(
                CGRect(
                    x: rect.origin.x - cropOrigin.x + destinationOffset.x,
                    y: rect.origin.y - cropOrigin.y + destinationOffset.y,
                    width: rect.width,
                    height: rect.height,
                ),
                pinCorner,
            )
        }
        return transformed
    }

    static func canvasDisplayNumber(for noteID: UUID, in notes: [NotinhasVisualNote]) -> Int? {
        let ordered = notes.sorted { lhs, rhs in
            if lhs.creationOrder == rhs.creationOrder {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.creationOrder < rhs.creationOrder
        }
        guard let index = ordered.firstIndex(where: { $0.id == noteID }) else { return nil }
        return index + 1
    }

    private static func minimumSizedRect(_ rect: CGRect) -> CGRect {
        guard rect.width < minimumRectSize || rect.height < minimumRectSize else {
            return rect
        }
        return CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: max(rect.width, minimumRectSize),
            height: max(rect.height, minimumRectSize),
        )
    }
}

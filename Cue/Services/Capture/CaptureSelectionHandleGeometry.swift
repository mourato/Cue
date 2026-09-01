//
//  CaptureSelectionHandleGeometry.swift
//  Notinhas
//

import CoreGraphics

/// Coordinate origin for selection chrome geometry.
enum CaptureSelectionCoordinateSpace {
    /// AppKit / screen coordinates (Y increases upward).
    case bottomLeftOrigin
    /// SwiftUI view coordinates (Y increases downward).
    case topLeftOrigin
}

typealias RecordingResizeHandle = CaptureSelectionResizeHandle

struct CaptureSelectionChromeLayout: Equatable {
    let cornerLength: CGFloat
    let edgeLength: CGFloat
    let availableHandles: Set<CaptureSelectionResizeHandle>

    static func layout(for rect: CGRect) -> CaptureSelectionChromeLayout {
        let standardized = rect.standardized
        let width = standardized.width
        let height = standardized.height
        let hitSize = CaptureSelectionChromeMetrics.handleHitSize

        let maxCornerFromSpan = max(0, (min(width, height) - hitSize) / 2)
        let cornerLength = min(
            CaptureSelectionChromeMetrics.cornerHandleLength,
            max(8, maxCornerFromSpan),
        )
        let edgeLength = CaptureSelectionChromeMetrics.edgeHandleLength

        var availableHandles = Set(CaptureSelectionResizeHandle.allCases)
        let horizontalSpanForEdge = cornerLength * 2 + edgeLength
        let verticalSpanForEdge = cornerLength * 2 + edgeLength

        if width < horizontalSpanForEdge {
            availableHandles.remove(.top)
            availableHandles.remove(.bottom)
        }
        if height < verticalSpanForEdge {
            availableHandles.remove(.left)
            availableHandles.remove(.right)
        }

        return CaptureSelectionChromeLayout(
            cornerLength: cornerLength,
            edgeLength: edgeLength,
            availableHandles: availableHandles,
        )
    }
}

enum CaptureSelectionHandleGeometry {
    static let allHandles: [CaptureSelectionResizeHandle] = CaptureSelectionResizeHandle.allCases

    /// Returns every visible handle bar using the same ordering and adaptive layout in each host.
    static func handleBars(
        in rect: CGRect,
        coordinateSpace: CaptureSelectionCoordinateSpace,
        layout: CaptureSelectionChromeLayout? = nil,
    ) -> [CGRect] {
        let resolvedLayout = layout ?? CaptureSelectionChromeLayout.layout(for: rect)
        var bars: [CGRect] = []

        for (handle, anchor) in cornerAnchors(in: rect, coordinateSpace: coordinateSpace) {
            guard resolvedLayout.availableHandles.contains(handle) else { continue }
            let cornerBars = cornerHandleBars(
                for: handle,
                anchor: anchor,
                coordinateSpace: coordinateSpace,
                layout: resolvedLayout,
            )
            bars.append(cornerBars.horizontal)
            bars.append(cornerBars.vertical)
        }

        for (handle, anchor) in edgeAnchors(in: rect, coordinateSpace: coordinateSpace) {
            guard resolvedLayout.availableHandles.contains(handle) else { continue }
            bars.append(
                edgeHandleBar(
                    for: handle,
                    anchor: anchor,
                    coordinateSpace: coordinateSpace,
                    layout: resolvedLayout,
                ),
            )
        }

        return bars
    }

    // MARK: - Hit testing

    /// Hit-test order: corners first (diagonal resize), then full edge strips between corners.
    static func handle(
        at point: CGPoint,
        in rect: CGRect,
        hitSize: CGFloat = CaptureSelectionChromeMetrics.handleHitSize,
        coordinateSpace: CaptureSelectionCoordinateSpace = .bottomLeftOrigin,
        layout: CaptureSelectionChromeLayout? = nil,
    ) -> CaptureSelectionResizeHandle? {
        let resolvedLayout = layout ?? CaptureSelectionChromeLayout.layout(for: rect)

        for handle in [.topLeft, .topRight, .bottomLeft, .bottomRight] as [CaptureSelectionResizeHandle] {
            guard resolvedLayout.availableHandles.contains(handle) else { continue }
            if hitRect(for: handle, in: rect, hitSize: hitSize, coordinateSpace: coordinateSpace).contains(point) {
                return handle
            }
        }

        for handle in [.top, .bottom, .left, .right] as [CaptureSelectionResizeHandle] {
            guard resolvedLayout.availableHandles.contains(handle) else { continue }
            if hitRect(for: handle, in: rect, hitSize: hitSize, coordinateSpace: coordinateSpace).contains(point) {
                return handle
            }
        }

        return nil
    }

    static func hitRect(
        for handle: CaptureSelectionResizeHandle,
        in rect: CGRect,
        hitSize: CGFloat = CaptureSelectionChromeMetrics.handleHitSize,
        coordinateSpace: CaptureSelectionCoordinateSpace = .bottomLeftOrigin,
    ) -> CGRect {
        let hs = hitSize
        switch coordinateSpace {
        case .bottomLeftOrigin:
            return bottomLeftOriginHitRect(for: handle, in: rect, hitSize: hs)
        case .topLeftOrigin:
            return topLeftOriginHitRect(for: handle, in: rect, hitSize: hs)
        }
    }

    private static func bottomLeftOriginHitRect(
        for handle: CaptureSelectionResizeHandle,
        in rect: CGRect,
        hitSize hs: CGFloat,
    ) -> CGRect {
        switch handle {
        case .topLeft:
            CGRect(x: rect.minX - hs, y: rect.maxY - hs, width: hs * 2, height: hs * 2)
        case .topRight:
            CGRect(x: rect.maxX - hs, y: rect.maxY - hs, width: hs * 2, height: hs * 2)
        case .bottomLeft:
            CGRect(x: rect.minX - hs, y: rect.minY - hs, width: hs * 2, height: hs * 2)
        case .bottomRight:
            CGRect(x: rect.maxX - hs, y: rect.minY - hs, width: hs * 2, height: hs * 2)
        case .top:
            CGRect(
                x: rect.minX + hs,
                y: rect.maxY - hs,
                width: max(0, rect.width - hs * 2),
                height: hs * 2,
            )
        case .bottom:
            CGRect(
                x: rect.minX + hs,
                y: rect.minY - hs,
                width: max(0, rect.width - hs * 2),
                height: hs * 2,
            )
        case .left:
            CGRect(
                x: rect.minX - hs,
                y: rect.minY + hs,
                width: hs * 2,
                height: max(0, rect.height - hs * 2),
            )
        case .right:
            CGRect(
                x: rect.maxX - hs,
                y: rect.minY + hs,
                width: hs * 2,
                height: max(0, rect.height - hs * 2),
            )
        }
    }

    private static func topLeftOriginHitRect(
        for handle: CaptureSelectionResizeHandle,
        in rect: CGRect,
        hitSize hs: CGFloat,
    ) -> CGRect {
        switch handle {
        case .topLeft:
            CGRect(x: rect.minX - hs, y: rect.minY - hs, width: hs * 2, height: hs * 2)
        case .topRight:
            CGRect(x: rect.maxX - hs, y: rect.minY - hs, width: hs * 2, height: hs * 2)
        case .bottomLeft:
            CGRect(x: rect.minX - hs, y: rect.maxY - hs, width: hs * 2, height: hs * 2)
        case .bottomRight:
            CGRect(x: rect.maxX - hs, y: rect.maxY - hs, width: hs * 2, height: hs * 2)
        case .top:
            CGRect(
                x: rect.minX + hs,
                y: rect.minY - hs,
                width: max(0, rect.width - hs * 2),
                height: hs * 2,
            )
        case .bottom:
            CGRect(
                x: rect.minX + hs,
                y: rect.maxY - hs,
                width: max(0, rect.width - hs * 2),
                height: hs * 2,
            )
        case .left:
            CGRect(
                x: rect.minX - hs,
                y: rect.minY + hs,
                width: hs * 2,
                height: max(0, rect.height - hs * 2),
            )
        case .right:
            CGRect(
                x: rect.maxX - hs,
                y: rect.minY + hs,
                width: hs * 2,
                height: max(0, rect.height - hs * 2),
            )
        }
    }

    // MARK: - Handle bar geometry (L-handles)

    /// Returns horizontal and vertical bar rects for a corner L-handle.
    static func cornerHandleBars(
        for corner: CaptureSelectionResizeHandle,
        anchor: CGPoint,
        metrics: (
            cornerLength: CGFloat,
            thickness: CGFloat,
        )? = nil,
        coordinateSpace: CaptureSelectionCoordinateSpace = .bottomLeftOrigin,
        layout: CaptureSelectionChromeLayout? = nil,
    ) -> (horizontal: CGRect, vertical: CGRect) {
        let resolvedMetrics = metrics ?? (
            cornerLength: layout?.cornerLength ?? CaptureSelectionChromeMetrics.cornerHandleLength,
            thickness: CaptureSelectionChromeMetrics.handleThickness,
        )
        let length = resolvedMetrics.cornerLength
        let thickness = resolvedMetrics.thickness
        let halfThickness = thickness / 2

        switch (corner, coordinateSpace) {
        case (.topLeft, .bottomLeftOrigin):
            return (
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: length, height: thickness),
                CGRect(
                    x: anchor.x - halfThickness,
                    y: anchor.y - length + halfThickness,
                    width: thickness,
                    height: length,
                ),
            )
        case (.topRight, .bottomLeftOrigin):
            return (
                CGRect(
                    x: anchor.x - length + halfThickness,
                    y: anchor.y - halfThickness,
                    width: length,
                    height: thickness,
                ),
                CGRect(
                    x: anchor.x - halfThickness,
                    y: anchor.y - length + halfThickness,
                    width: thickness,
                    height: length,
                ),
            )
        case (.bottomLeft, .bottomLeftOrigin):
            return (
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: length, height: thickness),
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: thickness, height: length),
            )
        case (.bottomRight, .bottomLeftOrigin):
            return (
                CGRect(
                    x: anchor.x - length + halfThickness,
                    y: anchor.y - halfThickness,
                    width: length,
                    height: thickness,
                ),
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: thickness, height: length),
            )
        case (.topLeft, .topLeftOrigin):
            return (
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: length, height: thickness),
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: thickness, height: length),
            )
        case (.topRight, .topLeftOrigin):
            return (
                CGRect(
                    x: anchor.x - length + halfThickness,
                    y: anchor.y - halfThickness,
                    width: length,
                    height: thickness,
                ),
                CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: thickness, height: length),
            )
        case (.bottomLeft, .topLeftOrigin):
            return (
                CGRect(
                    x: anchor.x - halfThickness,
                    y: anchor.y - thickness + halfThickness,
                    width: length,
                    height: thickness,
                ),
                CGRect(
                    x: anchor.x - halfThickness,
                    y: anchor.y - length + halfThickness,
                    width: thickness,
                    height: length,
                ),
            )
        case (.bottomRight, .topLeftOrigin):
            return (
                CGRect(
                    x: anchor.x - length + halfThickness,
                    y: anchor.y - thickness + halfThickness,
                    width: length,
                    height: thickness,
                ),
                CGRect(
                    x: anchor.x - halfThickness,
                    y: anchor.y - length + halfThickness,
                    width: thickness,
                    height: length,
                ),
            )
        default:
            return (.zero, .zero)
        }
    }

    /// Returns the bar rect for a mid-edge handle.
    static func edgeHandleBar(
        for edge: CaptureSelectionResizeHandle,
        anchor: CGPoint,
        metrics: (
            edgeLength: CGFloat,
            thickness: CGFloat,
        )? = nil,
        coordinateSpace: CaptureSelectionCoordinateSpace = .bottomLeftOrigin,
        layout: CaptureSelectionChromeLayout? = nil,
    ) -> CGRect {
        let resolvedMetrics = metrics ?? (
            edgeLength: layout?.edgeLength ?? CaptureSelectionChromeMetrics.edgeHandleLength,
            thickness: CaptureSelectionChromeMetrics.handleThickness,
        )
        let length = resolvedMetrics.edgeLength
        let thickness = resolvedMetrics.thickness
        let halfLength = length / 2
        let halfThickness = thickness / 2

        switch (edge, coordinateSpace) {
        case (.top, .bottomLeftOrigin), (.bottom, .bottomLeftOrigin):
            return CGRect(
                x: anchor.x - halfLength,
                y: anchor.y - halfThickness,
                width: length,
                height: thickness,
            )
        case (.left, .bottomLeftOrigin), (.right, .bottomLeftOrigin):
            return CGRect(
                x: anchor.x - halfThickness,
                y: anchor.y - halfLength,
                width: thickness,
                height: length,
            )
        case (.top, .topLeftOrigin), (.bottom, .topLeftOrigin):
            return CGRect(
                x: anchor.x - halfLength,
                y: anchor.y - halfThickness,
                width: length,
                height: thickness,
            )
        case (.left, .topLeftOrigin), (.right, .topLeftOrigin):
            return CGRect(
                x: anchor.x - halfThickness,
                y: anchor.y - halfLength,
                width: thickness,
                height: length,
            )
        default:
            return .zero
        }
    }

    /// Corner anchor points for drawing L-handles around a selection rect.
    static func cornerAnchors(
        in rect: CGRect,
        coordinateSpace: CaptureSelectionCoordinateSpace,
    ) -> [(handle: CaptureSelectionResizeHandle, point: CGPoint)] {
        switch coordinateSpace {
        case .bottomLeftOrigin:
            [
                (.topLeft, CGPoint(x: rect.minX, y: rect.maxY)),
                (.topRight, CGPoint(x: rect.maxX, y: rect.maxY)),
                (.bottomLeft, CGPoint(x: rect.minX, y: rect.minY)),
                (.bottomRight, CGPoint(x: rect.maxX, y: rect.minY)),
            ]
        case .topLeftOrigin:
            [
                (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
                (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
                (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
                (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY)),
            ]
        }
    }

    /// Mid-edge anchor points for drawing edge handles around a selection rect.
    static func edgeAnchors(
        in rect: CGRect,
        coordinateSpace: CaptureSelectionCoordinateSpace,
    ) -> [(handle: CaptureSelectionResizeHandle, point: CGPoint)] {
        switch coordinateSpace {
        case .bottomLeftOrigin:
            [
                (.top, CGPoint(x: rect.midX, y: rect.maxY)),
                (.bottom, CGPoint(x: rect.midX, y: rect.minY)),
                (.left, CGPoint(x: rect.minX, y: rect.midY)),
                (.right, CGPoint(x: rect.maxX, y: rect.midY)),
            ]
        case .topLeftOrigin:
            [
                (.top, CGPoint(x: rect.midX, y: rect.minY)),
                (.bottom, CGPoint(x: rect.midX, y: rect.maxY)),
                (.left, CGPoint(x: rect.minX, y: rect.midY)),
                (.right, CGPoint(x: rect.maxX, y: rect.midY)),
            ]
        }
    }
}

/// Backward-compatible alias for tests and call sites predating the shared module.
typealias RecordingResizeHandleCursorGeometry = CaptureSelectionHandleGeometry

//
//  CaptureSelectionDisplayTopology.swift
//  Cue
//
//  Shared multi-monitor topology, desktop union bounds, and screen resolution
//  for area capture, refinement, and recording overlays.
//

import AppKit
import CoreGraphics

@MainActor
enum CaptureSelectionDisplayTopology {
    /// Bounding rectangle uniting all active display screens in global AppKit coordinates.
    static var unifiedDesktopFrame: CGRect {
        unifiedDesktopFrame(for: NSScreen.screens)
    }

    /// Pure helper computing the union bounding rect of a collection of screens.
    static func unifiedDesktopFrame(for screens: [NSScreen]) -> CGRect {
        screens.reduce(into: CGRect.null) { union, screen in
            union = union.union(screen.frame)
        }
    }

    /// Finds the screen containing `point`, or the nearest screen if the point lies outside all screens.
    static func screenContaining(point: CGPoint, screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        if let direct = screens.first(where: { $0.frame.contains(point) }) {
            return direct
        }
        if let inset = screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }) {
            return inset
        }
        return screens.min(by: { a, b in
            distance(from: point, to: a.frame) < distance(from: point, to: b.frame)
        })
    }

    /// Clamps `rect` so it stays fully within `bounds` (defaulting to the unified desktop frame).
    static func clampRect(_ rect: CGRect, to bounds: CGRect = unifiedDesktopFrame) -> CGRect {
        var origin = rect.origin
        if rect.width <= bounds.width {
            origin.x = max(bounds.minX, min(origin.x, bounds.maxX - rect.width))
        } else {
            origin.x = bounds.minX
        }
        if rect.height <= bounds.height {
            origin.y = max(bounds.minY, min(origin.y, bounds.maxY - rect.height))
        } else {
            origin.y = bounds.minY
        }
        return CGRect(origin: origin, size: rect.size)
    }

    /// Clamps a resized rectangle so its edges do not exceed `bounds` while enforcing `minSize`.
    static func clampResizedRect(
        _ rect: CGRect,
        to bounds: CGRect = unifiedDesktopFrame,
        minSize: CGFloat = CaptureSelectionGeometry.defaultMinSize,
    ) -> CGRect {
        var r = rect
        if r.minX < bounds.minX {
            r.size.width -= (bounds.minX - r.minX)
            r.origin.x = bounds.minX
        }
        if r.minY < bounds.minY {
            r.size.height -= (bounds.minY - r.minY)
            r.origin.y = bounds.minY
        }
        if r.maxX > bounds.maxX {
            r.size.width = bounds.maxX - r.origin.x
        }
        if r.maxY > bounds.maxY {
            r.size.height = bounds.maxY - r.origin.y
        }
        r.size.width = max(r.width, minSize)
        r.size.height = max(r.height, minSize)
        return r
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return sqrt(dx * dx + dy * dy)
    }
}

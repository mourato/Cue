//
//  CaptureSelectionResizeCursor.swift
//  Notinhas
//

import AppKit

@MainActor
enum CaptureSelectionResizeCursor {
    private static let northwestSoutheastCursor: NSCursor = {
        let image = makeDiagonalResizeCursorImage(nwse: true)
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
    }()

    private static let northeastSouthwestCursor: NSCursor = {
        let image = makeDiagonalResizeCursorImage(nwse: false)
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
    }()

    static func cursor(for handle: CaptureSelectionResizeHandle) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight:
            northwestSoutheastCursor
        case .topRight, .bottomLeft:
            northeastSouthwestCursor
        case .top, .bottom:
            .resizeUpDown
        case .left, .right:
            .resizeLeftRight
        }
    }

    private static func makeDiagonalResizeCursorImage(nwse: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()

        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round

        if nwse {
            path.move(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 3, y: 8))
            path.move(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 8, y: 13))
            path.move(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 13, y: 3))
            path.move(to: NSPoint(x: 13, y: 3))
            path.line(to: NSPoint(x: 13, y: 8))
            path.move(to: NSPoint(x: 13, y: 3))
            path.line(to: NSPoint(x: 8, y: 3))
        } else {
            path.move(to: NSPoint(x: 13, y: 13))
            path.line(to: NSPoint(x: 13, y: 8))
            path.move(to: NSPoint(x: 13, y: 13))
            path.line(to: NSPoint(x: 8, y: 13))
            path.move(to: NSPoint(x: 13, y: 13))
            path.line(to: NSPoint(x: 3, y: 3))
            path.move(to: NSPoint(x: 3, y: 3))
            path.line(to: NSPoint(x: 3, y: 8))
            path.move(to: NSPoint(x: 3, y: 3))
            path.line(to: NSPoint(x: 8, y: 3))
        }

        NSColor.white.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 2.5
        path.stroke()

        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        image.unlockFocus()
        return image
    }
}

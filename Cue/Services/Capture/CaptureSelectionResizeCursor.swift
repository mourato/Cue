//
//  CaptureSelectionResizeCursor.swift
//  Notinhas
//

import AppKit

@MainActor
enum CaptureSelectionResizeCursor {
    static func cursor(for handle: CaptureSelectionResizeHandle) -> NSCursor {
        .frameResize(position: position(for: handle), directions: .all)
    }

    static func position(for handle: CaptureSelectionResizeHandle) -> NSCursor.FrameResizePosition {
        switch handle {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        }
    }
}

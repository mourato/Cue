//
//  NotinhasRectPinCorner.swift
//  Notinhas
//
//  Corner of a rectangular note where the numbered badge is anchored.
//

import Foundation

/// Logical corner of a note rectangle used as the numbered-badge anchor.
/// Image space is y-up (AppKit/Core Graphics).
nonisolated enum NotinhasRectPinCorner: String, Codable, Equatable, CaseIterable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    /// Default for legacy sessions that predate persisted pin corners.
    static let legacyFallback = topLeft

    /// Corner of the final rect that coincides with the drag start point.
    static func fromDrag(start: CGPoint, end: CGPoint) -> NotinhasRectPinCorner {
        let dragRight = end.x >= start.x
        let dragUp = end.y >= start.y
        switch (dragRight, dragUp) {
        case (true, true):
            return .bottomLeft
        case (true, false):
            return .topLeft
        case (false, true):
            return .bottomRight
        case (false, false):
            return .topRight
        }
    }

    /// Maps this corner through a 90° image-space rotation.
    func rotated(clockwise: Bool) -> NotinhasRectPinCorner {
        if clockwise {
            switch self {
            case .topLeft: .topRight
            case .topRight: .bottomRight
            case .bottomRight: .bottomLeft
            case .bottomLeft: .topLeft
            }
        } else {
            switch self {
            case .topLeft: .bottomLeft
            case .bottomLeft: .bottomRight
            case .bottomRight: .topRight
            case .topRight: .topLeft
            }
        }
    }
}

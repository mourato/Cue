//
//  NotinhasNoteTarget.swift
//  Notinhas
//
//  Geometry target for a Notinhas visual note.
//

import CoreGraphics
import Foundation

nonisolated enum NotinhasNoteTarget: Codable, Equatable {
    case point(CGPoint)
    case rect(CGRect)

    private enum CodingKeys: String, CodingKey {
        case kind
        case point
        case rect
    }

    private enum Kind: String, Codable {
        case point
        case rect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .point:
            self = try .point(container.decode(CGPoint.self, forKey: .point))
        case .rect:
            self = try .rect(container.decode(CGRect.self, forKey: .rect))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .point(let point):
            try container.encode(Kind.point, forKey: .kind)
            try container.encode(point, forKey: .point)
        case .rect(let rect):
            try container.encode(Kind.rect, forKey: .kind)
            try container.encode(rect, forKey: .rect)
        }
    }

    var isRectangular: Bool {
        if case .rect = self {
            return true
        }
        return false
    }

    var pinCenter: CGPoint {
        switch self {
        case .point(let point):
            point
        case .rect(let rect):
            NotinhasNoteGeometry.pinCenter(for: rect.standardized)
        }
    }

    var selectionBounds: CGRect {
        NotinhasNoteGeometry.selectionBounds(for: self)
    }

    func rotated(oldSize: CGSize, clockwise: Bool) -> NotinhasNoteTarget {
        switch self {
        case .point(let point):
            .point(AnnotateImageRotation.rotatePoint(point, oldSize: oldSize, clockwise: clockwise))
        case .rect(let rect):
            .rect(AnnotateImageRotation.rotateRect(rect, oldSize: oldSize, clockwise: clockwise))
        }
    }
}

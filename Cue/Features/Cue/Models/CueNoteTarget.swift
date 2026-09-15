//
//  CueNoteTarget.swift
//  Notinhas
//
//  Geometry target for a Notinhas visual note.
//

import CoreGraphics
import Foundation

nonisolated enum CueNoteTarget: Codable, Equatable {
    case point(CGPoint)
    /// Rectangular area with the numbered badge anchored at `pinCorner`.
    case rect(CGRect, CueRectPinCorner)

    private enum CodingKeys: String, CodingKey {
        case kind
        case point
        case rect
        case pinCorner
    }

    private enum Kind: String, Codable {
        case point
        case rect
    }

    /// Rectangular note target; defaults to `.topLeft` for call sites without an explicit corner.
    static func rect(_ rect: CGRect, pinCorner: CueRectPinCorner = .legacyFallback) -> CueNoteTarget {
        .rect(rect, pinCorner)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .point:
            self = try .point(container.decode(CGPoint.self, forKey: .point))
        case .rect:
            let rect = try container.decode(CGRect.self, forKey: .rect)
            let pinCorner = try container.decodeIfPresent(
                CueRectPinCorner.self,
                forKey: .pinCorner
            ) ?? .legacyFallback
            self = .rect(rect, pinCorner)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .point(point):
            try container.encode(Kind.point, forKey: .kind)
            try container.encode(point, forKey: .point)
        case let .rect(rect, pinCorner):
            try container.encode(Kind.rect, forKey: .kind)
            try container.encode(rect, forKey: .rect)
            try container.encode(pinCorner, forKey: .pinCorner)
        }
    }

    var isRectangular: Bool {
        if case .rect = self {
            return true
        }
        return false
    }

    var pinCorner: CueRectPinCorner? {
        if case let .rect(_, pinCorner) = self {
            return pinCorner
        }
        return nil
    }

    var pinCenter: CGPoint {
        switch self {
        case let .point(point):
            point
        case let .rect(rect, pinCorner):
            CueNoteGeometry.pinCenter(for: rect.standardized, pinCorner: pinCorner)
        }
    }

    var selectionBounds: CGRect {
        CueNoteGeometry.selectionBounds(for: self)
    }

    func rotated(oldSize: CGSize, clockwise: Bool) -> CueNoteTarget {
        switch self {
        case let .point(point):
            .point(AnnotateImageRotation.rotatePoint(point, oldSize: oldSize, clockwise: clockwise))
        case let .rect(rect, pinCorner):
            .rect(
                AnnotateImageRotation.rotateRect(rect, oldSize: oldSize, clockwise: clockwise),
                pinCorner.rotated(clockwise: clockwise)
            )
        }
    }
}

//
//  AnnotationStrokeWidth.swift
//  Notinhas
//
//  Discrete stroke-width presets for annotate and recording drawing tools.
//  Values match Screendrop's inspector stroke picker (2 / 4 / 6 / 8 / 12).
//

import CoreGraphics
import Foundation

/// Predefined stroke widths for drawn annotations.
nonisolated enum AnnotationStrokeWidth: CGFloat, CaseIterable, Codable, Equatable, Hashable, Identifiable,
    Sendable {
    case thin = 2
    case regular = 4
    case medium = 6
    case thick = 8
    case heavy = 12

    var id: CGFloat {
        rawValue
    }

    /// Point value stored on `AnnotationProperties.strokeWidth`.
    var points: CGFloat {
        rawValue
    }

    static let `default`: AnnotationStrokeWidth = .regular

    static var minPoints: CGFloat {
        allCases.first?.points ?? `default`.points
    }

    static var maxPoints: CGFloat {
        allCases.last?.points ?? `default`.points
    }

    static var pointsRange: ClosedRange<CGFloat> {
        minPoints ... maxPoints
    }

    /// Nearest preset to an arbitrary control value (legacy sessions, mid-gesture).
    static func nearest(to value: CGFloat) -> AnnotationStrokeWidth {
        allCases.min { lhs, rhs in
            let leftDistance = abs(lhs.points - value)
            let rightDistance = abs(rhs.points - value)
            if leftDistance != rightDistance {
                return leftDistance < rightDistance
            }
            return lhs.points < rhs.points
        } ?? .default
    }

    /// Snaps any control value onto a predefined preset.
    static func clamped(_ value: CGFloat) -> CGFloat {
        nearest(to: value).points
    }
}

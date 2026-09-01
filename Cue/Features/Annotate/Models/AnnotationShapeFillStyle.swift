//
//  AnnotationShapeFillStyle.swift
//  Notinhas
//
//  Shared fill styles for annotate shapes and Notinhas note areas.
//  Notes UI exposes outline/tinted/hatched only (no solid).
//

import Foundation

nonisolated enum AnnotationShapeFillStyle: String, Codable, CaseIterable, Equatable, Identifiable {
    case outline
    case solid
    case tinted
    case hatched

    var id: String {
        rawValue
    }

    static let `default` = AnnotationShapeFillStyle.outline

    /// Styles offered for Notinhas note areas (excludes solid).
    static let notinhasCases: [AnnotationShapeFillStyle] = [.outline, .tinted, .hatched]
}

/// Legacy name retained for Notinhas call sites; same shared style enum.
typealias NotinhasAreaStyle = AnnotationShapeFillStyle

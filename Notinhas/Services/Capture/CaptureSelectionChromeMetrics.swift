//
//  CaptureSelectionChromeMetrics.swift
//  Notinhas
//

import CoreGraphics

/// Shared visual and hit-test metrics for capture selection chrome (Recording, All-In-One, Markup).
enum CaptureSelectionChromeMetrics {
    static let handleHitSize: CGFloat = 10
    static let cornerHandleLength: CGFloat = 20
    static let edgeHandleLength: CGFloat = 24
    static let handleThickness: CGFloat = 3
    static let handleCornerRadius: CGFloat = handleThickness / 2
    static let handleShadowDistance: CGFloat = 1
    static let continuousBorderWidth: CGFloat = 1.5

    static func handleShadowOffset(for coordinateSpace: CaptureSelectionCoordinateSpace) -> CGSize {
        switch coordinateSpace {
        case .bottomLeftOrigin:
            CGSize(width: 0, height: -handleShadowDistance)
        case .topLeftOrigin:
            CGSize(width: 0, height: handleShadowDistance)
        }
    }

    /// Minimum size for a confirmed selection rectangle (refinement / annotating / pre-record).
    static let confirmedMinimumSize: CGFloat = 50
    /// Minimum drag extent while creating a new selection area.
    static let creationMinimumSize: CGFloat = 5

    static var minimumSpanForEdgeHandle: CGFloat {
        cornerHandleLength * 2 + edgeHandleLength
    }
}

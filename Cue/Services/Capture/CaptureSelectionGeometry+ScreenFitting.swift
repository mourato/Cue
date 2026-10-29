//
//  CaptureSelectionGeometry+ScreenFitting.swift
//  Cue
//
//  Keeps a selection rect fully on one display.
//

import CoreGraphics

extension CaptureSelectionGeometry {
    /// Moves and, when needed, shrinks `rect` so it lies fully inside the screen it
    /// overlaps most. Returns nil when `rect` overlaps no screen.
    static func fitted(_ rect: CGRect, toScreens screens: [CGRect]) -> CGRect? {
        let rect = rect.standardized
        var screen: CGRect?
        var bestArea: CGFloat = 0
        for candidate in screens {
            let overlap = candidate.intersection(rect)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                screen = candidate
            }
        }
        guard let screen else { return nil }

        let width = min(rect.width, screen.width)
        let height = min(rect.height, screen.height)
        let originX = min(max(rect.minX, screen.minX), screen.maxX - width)
        let originY = min(max(rect.minY, screen.minY), screen.maxY - height)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

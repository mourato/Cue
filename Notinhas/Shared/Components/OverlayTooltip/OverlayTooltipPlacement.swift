import CoreGraphics

enum OverlayTooltipPlacement {
    /// Gap between the anchor and the tooltip bubble, in points.
    static let gap: CGFloat = 6
    /// Minimum inset kept from the visible screen edges.
    static let screenMargin: CGFloat = 8

    /// Computes the tooltip's screen-space origin frame.
    ///
    /// - Horizontally centers the bubble on the anchor, clamped inside `visibleFrame`.
    /// - Vertically places the bubble on `preferred` edge; flips to the other edge
    ///   if the preferred side would run past `visibleFrame`.
    static func frame(
        anchor: CGRect,
        tooltipSize: CGSize,
        visibleFrame: CGRect,
        preferred: OverlayTooltipEdge,
    ) -> CGRect {
        // Horizontal: center on anchor, clamp within [minX+margin, maxX-margin-width]
        let rawX = anchor.midX - tooltipSize.width / 2
        let minX = visibleFrame.minX + screenMargin
        let maxX = visibleFrame.maxX - screenMargin - tooltipSize.width
        let x = maxX >= minX ? min(max(rawX, minX), maxX) : minX

        // Vertical candidates (screen y grows upward):
        //  - below the anchor  → lower y
        //  - above the anchor  → higher y
        let belowY = anchor.minY - gap - tooltipSize.height
        let aboveY = anchor.maxY + gap

        let belowFits = belowY >= visibleFrame.minY + screenMargin
        let aboveFits = aboveY + tooltipSize.height <= visibleFrame.maxY - screenMargin

        let y: CGFloat = switch preferred {
        case .below:
            belowFits || !aboveFits ? belowY : aboveY
        case .above:
            aboveFits || !belowFits ? aboveY : belowY
        }

        return CGRect(x: x, y: y, width: tooltipSize.width, height: tooltipSize.height)
    }
}

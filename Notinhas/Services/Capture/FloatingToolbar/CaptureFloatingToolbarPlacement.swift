//
//  CaptureFloatingToolbarPlacement.swift
//  Notinhas
//
//  Shared placement for floating capture HUD toolbars near a selection anchor.
//

import CoreGraphics

enum CaptureFloatingToolbarPlacement {
    static let screenEdgeInset: CGFloat = 10
    static let outsideSelectionGap: CGFloat = 20
    static let insideSelectionBottomInset: CGFloat = 24
    static let interToolbarGap: CGFloat = 16

    struct PairedOrigins: Equatable {
        let leading: CGPoint
        let trailing: CGPoint?
    }

    static func pairedFrameOrigins(
        leadingSize: CGSize,
        trailingSize: CGSize?,
        anchorRect: CGRect,
        screenFrame: CGRect,
        gap: CGFloat = interToolbarGap,
    ) -> PairedOrigins {
        guard let trailingSize else {
            let leading = frameOrigin(
                toolbarSize: leadingSize,
                anchorRect: anchorRect,
                screenFrame: screenFrame,
            )
            return PairedOrigins(leading: leading, trailing: nil)
        }

        let pairHeight = max(leadingSize.height, trailingSize.height)
        let pairWidth = leadingSize.width + gap + trailingSize.width
        let pairSize = CGSize(width: pairWidth, height: pairHeight)

        let pairOrigin = frameOrigin(
            toolbarSize: pairSize,
            anchorRect: anchorRect,
            screenFrame: screenFrame,
        )

        let trailing = CGPoint(
            x: pairOrigin.x + leadingSize.width + gap,
            y: pairOrigin.y,
        )

        return PairedOrigins(leading: pairOrigin, trailing: trailing)
    }

    static func frameOrigin(
        toolbarSize: CGSize,
        anchorRect rect: CGRect,
        screenFrame: CGRect,
    ) -> CGPoint {
        let x = rect.midX - toolbarSize.width / 2
        let minX = screenFrame.minX + screenEdgeInset
        let maxX = screenFrame.maxX - toolbarSize.width - screenEdgeInset
        let safeX = CaptureFloatingScreenClamp.clampedOrigin(x, minimum: minX, maximum: maxX)

        let minY = screenFrame.minY + screenEdgeInset
        let maxY = screenFrame.maxY - toolbarSize.height - screenEdgeInset
        let belowSelectionY = rect.minY - toolbarSize.height - outsideSelectionGap
        let preferredY = belowSelectionY >= minY
            ? belowSelectionY
            : rect.minY + insideSelectionBottomInset
        let safeY = CaptureFloatingScreenClamp.clampedOrigin(preferredY, minimum: minY, maximum: maxY)

        return CGPoint(x: safeX, y: safeY)
    }
}

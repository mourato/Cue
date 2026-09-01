#if CUE_VIDEO_MODULE
//
    //  VideoEditorOverlayPlacement.swift
    //  Notinhas
//
    //  Maps normalized source coordinates into displayed content space with viewport zoom.
//

    import CoreGraphics

    enum VideoEditorOverlayPlacement {
        /// Maps a normalized top-left source point into SwiftUI content coordinates.
        static func pointInContent(
            _ normalized: CGPoint,
            contentSize: CGSize,
            zoomLevel: CGFloat = 1,
            zoomCenter: CGPoint = ZoomCalculator.neutralCenter,
        ) -> CGPoint {
            guard contentSize.width > 0, contentSize.height > 0 else { return .zero }
            guard zoomLevel > 1.001 else {
                return CGPoint(
                    x: normalized.x * contentSize.width,
                    y: normalized.y * contentSize.height,
                )
            }

            return CGPoint(
                x: contentSize.width / 2 + contentSize.width * zoomLevel * (normalized.x - zoomCenter.x),
                y: contentSize.height / 2 + contentSize.height * zoomLevel * (normalized.y - zoomCenter.y),
            )
        }

        /// Maps a normalized top-left source point into Core Image canvas coordinates (bottom-left origin).
        static func pointInCanvas(
            _ normalized: CGPoint,
            contentRect: CGRect,
            canvasHeight: CGFloat,
            zoomLevel: CGFloat = 1,
            zoomCenter: CGPoint = ZoomCalculator.neutralCenter,
        ) -> CGPoint {
            let topLeft = pointInContent(
                normalized,
                contentSize: contentRect.size,
                zoomLevel: zoomLevel,
                zoomCenter: zoomCenter,
            )
            return CGPoint(
                x: contentRect.minX + topLeft.x,
                y: canvasHeight - (contentRect.minY + topLeft.y),
            )
        }
    }
#endif

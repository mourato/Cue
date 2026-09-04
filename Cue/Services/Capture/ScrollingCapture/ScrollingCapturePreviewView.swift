//
//  ScrollingCapturePreviewView.swift
//  Notinhas
//
//  SwiftUI content for the scrolling capture preview rail.
//

import SwiftUI

enum ScrollingCapturePreviewLayout {
    static let previewWidth: CGFloat = 220
    static let minPreviewHeight: CGFloat = 160
    static let maxPreviewHeight: CGFloat = 420
    static let panelHorizontalMargin: CGFloat = 20
    static let panelScreenEdgeInset: CGFloat = 12
    static let panelTopInset: CGFloat = 20
    /// Card corner radius: largest shared radius (Size.radiusLg), continuous
    /// style per Apple design guidance.
    static let cardCornerRadius: CGFloat = 12
    /// Matches the region overlay stroke inset so the preview aligns with the visible border bottom.
    static let selectionBorderOutset: CGFloat = 1.25

    static func previewHeight(for image: CGImage?, maxAvailableHeight: CGFloat? = nil) -> CGFloat {
        guard let image, image.width > 0, image.height > 0 else {
            return minPreviewHeight
        }

        let ceiling = maxAvailableHeight ?? maxPreviewHeight
        let scaledHeight = previewWidth * CGFloat(image.height) / CGFloat(image.width)
        return min(ceiling, max(minPreviewHeight, scaledHeight))
    }

    static func maxImageHeight(anchorRect: CGRect, visibleFrame: CGRect) -> CGFloat {
        let anchorBottom = anchorRect.minY - selectionBorderOutset
        let ceilingY = visibleFrame.maxY - panelTopInset
        let available = ceilingY - anchorBottom
        return max(minPreviewHeight, available)
    }
}

struct ScrollingCapturePreviewView: View {
    @ObservedObject var model: ScrollingCaptureSessionModel
    var maxImageHeight: CGFloat?

    private var displayedPreviewImage: CGImage? {
        model.previewImage ?? model.livePreviewImage
    }

    private var previewScaling: ScrollingCapturePreviewScaling {
        model.previewImage != nil ? .fitTopAligned : .fit
    }

    /// Image-only card: no header, badge, caption, padding, or border — the
    /// stitched image fills 100% of the floating card, clipped to a
    /// continuous rounded rectangle per Apple design guidance.
    var body: some View {
        let previewHeight = ScrollingCapturePreviewLayout.previewHeight(
            for: displayedPreviewImage,
            maxAvailableHeight: maxImageHeight,
        )

        Group {
            if let previewImage = displayedPreviewImage {
                GeometryReader { geometry in
                    ScrollingCapturePreviewRenderer(
                        image: previewImage,
                        scaling: previewScaling,
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .top,
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ScrollingCapturePreviewLayout.cardCornerRadius,
                            style: .continuous,
                        ),
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: ScrollingCapturePreviewLayout.previewWidth, height: previewHeight)
        .animation(model.phase == .capturing ? nil : .easeInOut(duration: 0.25), value: previewHeight)
    }
}

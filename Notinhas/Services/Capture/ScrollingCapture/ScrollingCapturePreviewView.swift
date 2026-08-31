//
//  ScrollingCapturePreviewView.swift
//  Notinhas
//
//  SwiftUI content for the scrolling capture preview rail.
//

import SwiftUI

enum ScrollingCapturePreviewLayout {
    static let panelWidth: CGFloat = 244
    static let previewWidth: CGFloat = 220
    static let minPreviewHeight: CGFloat = 160
    static let maxPreviewHeight: CGFloat = 420
    static let panelHorizontalMargin: CGFloat = 20
    static let panelScreenEdgeInset: CGFloat = 12
    static let panelTopInset: CGFloat = 20
    static let panelPadding: CGFloat = 12
    static let previewSectionSpacing: CGFloat = 8
    static let previewHeaderApproxHeight: CGFloat = 28
    /// Matches the region overlay stroke inset so the preview aligns with the visible border bottom.
    static let selectionBorderOutset: CGFloat = 1.25

    /// Non-image chrome: panel padding, header row, caption spacing, and caption line.
    static var panelChromeHeight: CGFloat {
        (panelWidth - previewWidth)
            + panelPadding * 2
            + previewSectionSpacing * 2
            + previewHeaderApproxHeight
    }

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
        let available = ceilingY - anchorBottom - panelChromeHeight
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

    private var badgeColor: Color {
        switch model.previewTruthState {
        case .committedOnly:
            .secondary.opacity(0.9)
        case .liveSynced:
            .green.opacity(0.9)
        case .liveAhead:
            .orange.opacity(0.95)
        case .pausedRecovery:
            .yellow.opacity(0.9)
        case .finalizing, .saving:
            .blue.opacity(0.9)
        case .ready:
            .clear
        }
    }

    var body: some View {
        let previewHeight = ScrollingCapturePreviewLayout.previewHeight(
            for: displayedPreviewImage,
            maxAvailableHeight: maxImageHeight,
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L10n.Common.preview)
                    .font(.system(size: 12, weight: .semibold))

                Text(model.previewTruthState.badgeLabel ?? "")
                    .contentTransition(.numericText())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(badgeColor),
                    )
                    .opacity(model.previewTruthState.badgeLabel != nil ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: model.previewTruthState)
            }

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
                        .clipped()
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(L10n.ScrollingCapture.captionLockingFirstFrame + ".")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: ScrollingCapturePreviewLayout.previewWidth, height: previewHeight)
            .animation(model.phase == .capturing ? nil : .easeInOut(duration: 0.25), value: previewHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.08)),
            )

            Text(model.previewCaption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: ScrollingCapturePreviewLayout.panelWidth)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12)),
        )
    }
}

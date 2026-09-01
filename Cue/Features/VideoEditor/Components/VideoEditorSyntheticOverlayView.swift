#if CUE_VIDEO_MODULE
//
    //  VideoEditorSyntheticOverlayView.swift
    //  Notinhas
//
    //  SwiftUI preview overlays for synthetic pointer, clicks, and keystrokes.
//

    import SwiftUI

    struct VideoEditorSyntheticOverlayView: View {
        let pointerFrame: VideoEditorPointerFrame?
        let pointerTimeline: VideoEditorPointerTimeline
        let keystrokeFrame: VideoEditorKeystrokeCaptionFrame?
        let contentRect: CGRect
        let showsSyntheticCursor: Bool
        let showsClickEffects: Bool
        let showsKeystrokes: Bool
        let keystrokePlacement: KeystrokeOverlayPosition
        let cursorScale: CGFloat
        let zoomLevel: CGFloat
        let zoomCenter: CGPoint

        var body: some View {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: contentRect.width, height: contentRect.height)

                if showsClickEffects,
                   let press = pointerFrame?.press {
                    clickEffect(for: press)
                }

                if showsSyntheticCursor,
                   let pointerFrame,
                   pointerFrame.opacity > 0.01 {
                    pointerView(for: pointerFrame)
                }

                if showsKeystrokes,
                   let keystrokeFrame {
                    keystrokeBadge(for: keystrokeFrame)
                }
            }
            .frame(width: contentRect.width, height: contentRect.height)
            .position(x: contentRect.midX, y: contentRect.midY)
            .allowsHitTesting(false)
        }

        @ViewBuilder
        private func pointerView(for pointerFrame: VideoEditorPointerFrame) -> some View {
            let tip = pointInView(pointerFrame.location)
            let artwork = pointerTimeline.artwork(id: pointerFrame.artworkID)
            let anchor = artwork?.normalizedAnchor ?? CGPoint(x: 0.1, y: 0.1)
            let height = contentRect.height
                * VideoEditorPointerArtworkMetrics.heightRatio
                * cursorScale
                * (artwork?.intrinsicScale ?? 1)
            let size = CGSize(width: height * (artwork?.aspectRatio ?? 1), height: height)

            Group {
                if let artwork, let image = VideoEditorPointerArtworkCache.image(for: artwork) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                } else {
                    Image(nsImage: NSCursor.arrow.image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                }
            }
            .scaleEffect(pointerFrame.magnification, anchor: UnitPoint(x: anchor.x, y: anchor.y))
            .rotationEffect(.degrees(pointerFrame.tiltDegrees), anchor: UnitPoint(x: anchor.x, y: anchor.y))
            .blur(radius: pointerFrame.blurRadius)
            .opacity(pointerFrame.opacity)
            .position(
                x: tip.x + (0.5 - anchor.x) * size.width,
                y: tip.y + (0.5 - anchor.y) * size.height,
            )
        }

        @ViewBuilder
        private func clickEffect(for press: VideoEditorPointerPressFrame) -> some View {
            let geometry = VideoEditorPointerPressEffectStyle.geometry(
                progress: press.progress,
                referenceHeight: contentRect.height,
                cursorScale: cursorScale,
            )
            let center = pointInView(press.location)
            ZStack {
                if geometry.impactOpacity > 0.001 {
                    Circle()
                        .fill(Color(red: 0, green: 122 / 255, blue: 1).opacity(geometry.impactOpacity))
                        .frame(width: geometry.impactRadius * 2, height: geometry.impactRadius * 2)
                        .position(center)
                }
                if geometry.rippleOpacity > 0.001 {
                    Circle()
                        .stroke(Color(red: 0, green: 122 / 255, blue: 1).opacity(geometry.rippleOpacity),
                                lineWidth: geometry.rippleLineWidth)
                        .frame(width: geometry.rippleRadius * 2, height: geometry.rippleRadius * 2)
                        .position(center)
                }
            }
        }

        @ViewBuilder
        private func keystrokeBadge(for frame: VideoEditorKeystrokeCaptionFrame) -> some View {
            let metrics = VideoEditorKeystrokeCaptionMetrics(cardHeight: contentRect.height)
            let parts = VideoEditorKeystrokeCaptionMetrics.text(for: frame)
            let label = (Text(parts.modifiers).foregroundColor(.white.opacity(frame.opacity * 0.7))
                + Text(parts.key).foregroundColor(.white.opacity(frame.opacity)))
                .font(.system(size: metrics.fontSize * frame.scale, weight: .medium, design: .monospaced))
                .padding(.horizontal, metrics.paddingHorizontal)
                .padding(.vertical, metrics.paddingVertical)
                .background(Color.black.opacity(frame.opacity * VideoEditorKeystrokeCaptionMetrics.backgroundAlpha))
                .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))

            ZStack(alignment: swiftUIAlignment(for: keystrokePlacement)) {
                Color.clear
                label
                    .padding(metrics.margin)
            }
            .frame(width: contentRect.width, height: contentRect.height)
        }

        private func pointInView(_ normalized: CGPoint) -> CGPoint {
            VideoEditorOverlayPlacement.pointInContent(
                normalized,
                contentSize: contentRect.size,
                zoomLevel: zoomLevel,
                zoomCenter: zoomCenter,
            )
        }

        private func swiftUIAlignment(for placement: KeystrokeOverlayPosition) -> Alignment {
            switch placement {
            case .topLeft: .topLeading
            case .topCenter: .top
            case .topRight: .topTrailing
            case .bottomLeft: .bottomLeading
            case .bottomCenter: .bottom
            case .bottomRight: .bottomTrailing
            }
        }
    }
#endif

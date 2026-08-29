#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorSyntheticOverlayView.swift
    //  Notinhas
//
    //  SwiftUI preview overlays for synthetic pointer, clicks, and keystrokes.
//

    import SwiftUI

    struct VideoEditorSyntheticOverlayView: View {
        let pointerFrame: VideoEditorPointerFrame?
        let keystrokeFrame: VideoEditorKeystrokeCaptionFrame?
        let contentRect: CGRect
        let showsSyntheticCursor: Bool
        let showsClickEffects: Bool
        let showsKeystrokes: Bool
        let keystrokePlacement: KeystrokeOverlayPosition
        let cursorScale: CGFloat

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
                    Image(systemName: "arrow.up.left")
                        .font(.system(size: max(
                            12,
                            contentRect.height * VideoEditorPointerTimeline.cursorHeightRatio * cursorScale,
                        )))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .scaleEffect(pointerFrame.magnification)
                        .opacity(pointerFrame.opacity)
                        .position(pointInView(pointerFrame.location))
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
        private func clickEffect(for press: VideoEditorPointerPressFrame) -> some View {
            let geometry = VideoEditorPointerPressEffectStyle.geometry(
                progress: press.progress,
                referenceHeight: contentRect.height,
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
            CGPoint(
                x: normalized.x * contentRect.width,
                y: normalized.y * contentRect.height,
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

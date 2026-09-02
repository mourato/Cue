#if CUE_VIDEO_MODULE
//
    //  ExportProgressOverlay.swift
    //  Notinhas
//
    //  Modal overlay showing export progress with progress bar
//

    import AppKit
    import SwiftUI

    /// Modal overlay displayed during video export
    struct ExportProgressOverlay: View {
        @ObservedObject var state: VideoEditorState
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

        private let feedbackStyle = FeedbackStyle(tone: .info)

        var body: some View {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                // Progress card
                FeedbackSurface(cornerRadius: 12, style: feedbackStyle) {
                    VStack(spacing: 16) {
                        // Icon
                        if reduceMotion {
                            Image(systemName: "film")
                                .font(.system(size: 32))
                                .foregroundStyle(feedbackStyle.iconColor)
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 32))
                                .foregroundStyle(feedbackStyle.iconColor)
                                .symbolEffect(.pulse, options: .repeating)
                        }

                        // Title
                        Text(L10n.VideoEditor.exportingVideo)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(textColor)

                        // Progress bar
                        VStack(spacing: 8) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(textColor.opacity(0.22))
                                        .frame(height: 8)

                                    // Progress fill
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [feedbackStyle.iconColor, ZoomColors.primaryDark],
                                                startPoint: .leading,
                                                endPoint: .trailing,
                                            ),
                                        )
                                        .frame(
                                            width: max(0, geometry.size.width * CGFloat(state.exportProgress)),
                                            height: 8,
                                        )
                                        .animation(
                                            reduceMotion ? nil : .easeInOut(duration: 0.2),
                                            value: state.exportProgress,
                                        )
                                }
                            }
                            .frame(height: 8)

                            // Percentage
                            Text("\(Int(state.exportProgress * 100))%")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(textColor.opacity(0.78))
                        }

                        // Status message
                        Text(state.exportStatusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(textColor.opacity(0.72))
                    }
                    .padding(24)
                    .frame(width: 280)
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
        }

        private var textColor: Color {
            Color(nsColor: feedbackStyle.textColor(usesSolidFallback: usesSolidFallback))
        }

        private var usesSolidFallback: Bool {
            FeedbackChromePolicy.usesSolidFallback(reduceTransparency: reduceTransparency)
        }
    }

    // MARK: - Preview

    #Preview {
        ExportProgressOverlay(
            state: {
                let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/test.mov"))
                state.isExporting = true
                state.exportProgress = 0.65
                state.exportStatusMessage = "Processing zoom effects..."
                return state
            }(),
        )
    }
#endif

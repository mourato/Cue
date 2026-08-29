#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorExportReframe.swift
    //  Notinhas
//
    //  Export-time reframing with a virtual follow camera (Plan 110 / Phase D).
//

    import CoreGraphics
    import Foundation

    enum VideoEditorExportAspectContentMode: String, Codable, CaseIterable, Sendable {
        case fill
        case fit

        var title: String {
            switch self {
            case .fill: L10n.VideoEditor.exportContentModeFill
            case .fit: L10n.VideoEditor.exportContentModeFit
            }
        }
    }

    struct VideoEditorReframeTrack: Sendable, Equatable {
        static let stepRate: Double = 120

        let preset: ExportDimensionPreset
        let sourceAspect: CGFloat
        private let frames: [VideoEditorViewportFrame]
        private let duration: TimeInterval

        func frame(at time: TimeInterval) -> VideoEditorViewportFrame {
            guard frames.count > 1, duration > 0 else { return frames.first ?? .identity }
            let position = min(max(time, 0), duration) * Self.stepRate
            let index = Int(position)
            guard index < frames.count - 1 else { return frames[frames.count - 1] }
            let fraction = position - Double(index)
            let a = frames[index]
            let b = frames[index + 1]
            return VideoEditorViewportFrame(
                magnification: a.magnification + (b.magnification - a.magnification) * fraction,
                anchor: CGPoint(
                    x: a.anchor.x + (b.anchor.x - a.anchor.x) * fraction,
                    y: a.anchor.y + (b.anchor.y - a.anchor.y) * fraction,
                ),
            )
        }

        private static let deadZoneFraction: CGFloat = 0.28
        private static let smoothingTau: Double = 0.45
        private static let zoomHandoffSpan: Double = 0.2

        static func build(
            preset: ExportDimensionPreset,
            sourceSize: CGSize,
            viewportTimeline: VideoEditorViewportTimeline,
            duration: TimeInterval,
            focus: (TimeInterval) -> CGPoint?,
        ) -> VideoEditorReframeTrack? {
            guard let aspectRatio = preset.aspectRatio,
                  sourceSize.width > 0, sourceSize.height > 0,
                  duration.isFinite, duration > 0 else {
                return nil
            }

            let targetRatio = aspectRatio.width / aspectRatio.height
            let sourceAspect = sourceSize.width / sourceSize.height
            let card = CGSize(width: targetRatio, height: 1)
            let fillScale = max(card.width / sourceAspect, card.height / 1)
            let fill = CGSize(width: sourceAspect * fillScale, height: fillScale)

            let stepCount = max(2, Int((duration * Self.stepRate).rounded()) + 1)
            let dt = 1.0 / Self.stepRate
            var builtFrames: [VideoEditorViewportFrame] = []
            builtFrames.reserveCapacity(stepCount)

            let smoothing = 1 - exp(-dt / Self.smoothingTau)
            var center = CGPoint(x: 0.5, y: 0.5)
            if let initial = focus(0) {
                center = initial
            }

            for step in 0 ..< stepCount {
                let time = Double(step) * dt
                let viewport = viewportTimeline.frame(at: time)
                let magnification = max(1, viewport.magnification)

                let visibleX = min(1, card.width / (fill.width * magnification))
                let visibleY = min(1, card.height / (fill.height * magnification))
                let focusPoint = focus(time) ?? viewport.anchor

                var target = center
                let windowX = visibleX * Self.deadZoneFraction
                let windowY = visibleY * Self.deadZoneFraction
                if focusPoint.x > center.x + windowX {
                    target.x = focusPoint.x - windowX
                }
                if focusPoint.x < center.x - windowX {
                    target.x = focusPoint.x + windowX
                }
                if focusPoint.y > center.y + windowY {
                    target.y = focusPoint.y - windowY
                }
                if focusPoint.y < center.y - windowY {
                    target.y = focusPoint.y + windowY
                }
                center.x += (target.x - center.x) * smoothing
                center.y += (target.y - center.y) * smoothing

                let handoff = min(max((magnification - 1) / Self.zoomHandoffSpan, 0), 1)
                var anchor = CGPoint(
                    x: center.x + (viewport.anchor.x - center.x) * handoff,
                    y: center.y + (viewport.anchor.y - center.y) * handoff,
                )

                anchor.x = min(max(anchor.x, visibleX / 2), 1 - visibleX / 2)
                anchor.y = min(max(anchor.y, visibleY / 2), 1 - visibleY / 2)
                if visibleX >= 1 {
                    anchor.x = 0.5
                }
                if visibleY >= 1 {
                    anchor.y = 0.5
                }
                center = anchor

                builtFrames.append(VideoEditorViewportFrame(magnification: magnification, anchor: anchor))
            }

            return VideoEditorReframeTrack(
                preset: preset,
                sourceAspect: sourceAspect,
                frames: builtFrames,
                duration: duration,
            )
        }

        private init(
            preset: ExportDimensionPreset,
            sourceAspect: CGFloat,
            frames: [VideoEditorViewportFrame],
            duration: TimeInterval,
        ) {
            self.preset = preset
            self.sourceAspect = sourceAspect
            self.frames = frames
            self.duration = duration
        }
    }
#endif

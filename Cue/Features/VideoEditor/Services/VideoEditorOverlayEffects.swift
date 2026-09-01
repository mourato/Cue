#if CUE_VIDEO_MODULE
//
    //  VideoEditorOverlayEffects.swift
    //  Notinhas
//
    //  Post-process click pulses and keystroke captions (Plan 110 / Screendrop parity).
//

    import CoreGraphics
    import Foundation

    struct VideoEditorPointerPressEffectGeometry: Sendable, Equatable {
        var impactRadius: CGFloat
        var impactOpacity: Double
        var rippleRadius: CGFloat
        var rippleOpacity: Double
        var rippleLineWidth: CGFloat
    }

    enum VideoEditorPointerPressEffectStyle {
        static let color = (red: 0.0, green: 122.0 / 255.0, blue: 1.0)
        static let duration: TimeInterval = 0.4
        private static let impactDuration: TimeInterval = 0.12
        private static let rippleDelay: TimeInterval = 0.06

        static func geometry(
            progress: Double,
            referenceHeight: CGFloat,
            cursorScale: CGFloat = 1,
        ) -> VideoEditorPointerPressEffectGeometry {
            let age = min(max(progress, 0), 1) * duration
            let base = referenceHeight * CGFloat(21.0 / 1_080.0) * cursorScale
            let impactProgress = min(max(age / impactDuration, 0), 1)
            let impactEase = easeOutCubic(impactProgress)
            let rippleProgress = min(max((age - rippleDelay) / (duration - rippleDelay), 0), 1)
            let rippleEase = easeOutCubic(rippleProgress)
            return VideoEditorPointerPressEffectGeometry(
                impactRadius: base * CGFloat(0.38 + 0.34 * impactEase),
                impactOpacity: age <= impactDuration ? 0.38 * (1 - impactEase) : 0,
                rippleRadius: base * CGFloat(0.62 + 0.93 * rippleEase),
                rippleOpacity: age >= rippleDelay ? 0.44 * (1 - rippleEase) : 0,
                rippleLineWidth: max(1, base * CGFloat(0.14 - 0.07 * rippleEase)),
            )
        }

        private static func easeOutCubic(_ progress: Double) -> Double {
            let clamped = min(max(progress, 0), 1)
            return 1 - pow(1 - clamped, 3)
        }
    }

    struct VideoEditorKeystrokeCaptionFrame: Sendable, Equatable {
        var modifiers: [String]
        var key: String
        var opacity: Double
        var scale: Double
    }

    struct VideoEditorKeystrokeCaptionTimeline: Sendable, Equatable {
        private static let popInDuration: TimeInterval = 0.16
        private static let holdDuration: TimeInterval = 1.1
        private static let popOutDuration: TimeInterval = 0.3

        private let events: [RecordedKeystrokeEvent]

        static let empty = VideoEditorKeystrokeCaptionTimeline(events: [])

        init(events: [RecordedKeystrokeEvent]) {
            self.events = events
                .filter { $0.time.isFinite && !$0.key.isEmpty }
                .sorted { $0.time < $1.time }
        }

        var isEmpty: Bool {
            events.isEmpty
        }

        static func buildForExport(
            metadata: RecordingMetadata?,
            trimStart: TimeInterval,
            trimEnd: TimeInterval,
            speedMap: SpeedTimeMap?,
        ) -> VideoEditorKeystrokeCaptionTimeline {
            guard var metadata else { return .empty }

            func mappedTime(_ time: TimeInterval) -> TimeInterval {
                let relative = time - trimStart
                if let speedMap {
                    return speedMap.toScaled(max(0, min(relative, speedMap.originalDuration)))
                }
                return relative
            }

            let keystrokes = metadata.keystrokes
                .filter { $0.time >= trimStart && $0.time <= trimEnd }
                .map { stroke in
                    var adjusted = stroke
                    adjusted.time = mappedTime(stroke.time)
                    return adjusted
                }
            return VideoEditorKeystrokeCaptionTimeline(events: keystrokes)
        }

        func frame(at time: TimeInterval) -> VideoEditorKeystrokeCaptionFrame? {
            guard !events.isEmpty, time.isFinite else { return nil }

            var low = 0
            var high = events.count
            while low < high {
                let middle = (low + high) / 2
                if events[middle].time <= time {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            let index = low - 1
            guard index >= 0 else { return nil }

            let event = events[index]
            let naturalEnd = event.time + Self.popInDuration + Self.holdDuration + Self.popOutDuration
            let nextStart = index + 1 < events.count ? events[index + 1].time : nil
            let end = min(naturalEnd, nextStart ?? .greatestFiniteMagnitude)
            guard time < end else { return nil }

            let previousEnd: TimeInterval? = index > 0
                ? events[index - 1].time + Self.popInDuration + Self.holdDuration + Self.popOutDuration
                : nil
            let continuesPreviousCaption = previousEnd.map { $0 > event.time } ?? false

            var opacity = 1.0
            var scale = 1.0

            if !continuesPreviousCaption, time - event.time < Self.popInDuration {
                let progress = min(max((time - event.time) / Self.popInDuration, 0), 1)
                let eased = 1 - pow(1 - progress, 3)
                opacity = eased
                scale = 0.92 + 0.08 * eased
            }

            if naturalEnd <= (nextStart ?? .greatestFiniteMagnitude), time > naturalEnd - Self.popOutDuration {
                let progress = min(max((naturalEnd - time) / Self.popOutDuration, 0), 1)
                let eased = 1 - pow(1 - progress, 3)
                opacity = min(opacity, eased)
                scale = min(scale, 0.97 + 0.03 * eased)
            }

            guard opacity > 0.005 else { return nil }
            return VideoEditorKeystrokeCaptionFrame(
                modifiers: event.modifiers,
                key: event.key,
                opacity: opacity,
                scale: scale,
            )
        }
    }

    struct VideoEditorKeystrokeCaptionMetrics: Sendable {
        let fontSize: CGFloat
        let paddingHorizontal: CGFloat
        let paddingVertical: CGFloat
        let cornerRadius: CGFloat
        let margin: CGFloat

        static let backgroundAlpha = 0.62
        static let modifierAlpha = 0.7

        static func text(for frame: VideoEditorKeystrokeCaptionFrame) -> (modifiers: String, key: String) {
            let modifiers = frame.modifiers.joined(separator: " ")
            return (modifiers.isEmpty ? "" : modifiers + " ", frame.key)
        }

        init(cardHeight: CGFloat) {
            fontSize = max(11, cardHeight * 0.033)
            paddingHorizontal = fontSize * 0.72
            paddingVertical = fontSize * 0.46
            cornerRadius = fontSize * 0.55
            margin = cardHeight * 0.045
        }

        func pillOrigin(
            pillSize: CGSize,
            cardRect: CGRect,
            placement: KeystrokeOverlayPosition,
        ) -> CGPoint {
            let x: CGFloat = switch placement {
            case .topLeft, .bottomLeft:
                cardRect.minX + margin
            case .topCenter, .bottomCenter:
                cardRect.midX - pillSize.width / 2
            case .topRight, .bottomRight:
                cardRect.maxX - margin - pillSize.width
            }
            let y = placement.isTop
                ? cardRect.minY + margin
                : cardRect.maxY - margin - pillSize.height
            return CGPoint(x: x, y: y)
        }
    }

    extension KeystrokeOverlayPosition {
        var isTop: Bool {
            switch self {
            case .topLeft, .topCenter, .topRight: true
            case .bottomLeft, .bottomCenter, .bottomRight: false
            }
        }
    }
#endif

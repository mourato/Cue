#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorPointerTimeline.swift
    //  Notinhas
//
    //  Damped-spring synthetic pointer motion for post-processed overlays (Plan 110).
//

    import CoreGraphics
    import Foundation

    struct VideoEditorPointerPressFrame: Sendable, Equatable {
        var location: CGPoint
        var progress: Double
    }

    struct VideoEditorPointerFrame: Sendable, Equatable {
        var location: CGPoint
        var magnification: Double
        var opacity: Double
        var press: VideoEditorPointerPressFrame?
    }

    struct VideoEditorPointerTimeline: Sendable, Equatable {
        static let stepRate: Double = 120
        static let cursorHeightRatio: CGFloat = 0.032

        private static let anticipationWindow: TimeInterval = 0.5
        private static let interceptWindow: TimeInterval = 0.175
        private static let pressAnticipation: TimeInterval = 0.13
        private static let orphanPressHold: TimeInterval = 0.15
        private static let pulseDuration = VideoEditorPointerPressEffectStyle.duration

        private let frames: [VideoEditorPointerFrame]
        private let duration: TimeInterval

        static let empty = VideoEditorPointerTimeline(frames: [], duration: 0)

        private init(frames: [VideoEditorPointerFrame], duration: TimeInterval) {
            self.frames = frames
            self.duration = duration
        }

        func frame(at time: TimeInterval) -> VideoEditorPointerFrame? {
            guard !frames.isEmpty else { return nil }
            guard frames.count > 1, duration > 0 else { return frames.first }

            let position = min(max(time, 0), duration) * Self.stepRate
            let index = Int(position)
            guard index < frames.count - 1 else { return frames[frames.count - 1] }

            let fraction = position - Double(index)
            let a = frames[index]
            let b = frames[index + 1]
            return VideoEditorPointerFrame(
                location: CGPoint(
                    x: a.location.x + (b.location.x - a.location.x) * fraction,
                    y: a.location.y + (b.location.y - a.location.y) * fraction,
                ),
                magnification: a.magnification + (b.magnification - a.magnification) * fraction,
                opacity: a.opacity + (b.opacity - a.opacity) * fraction,
                press: fraction < 0.5 ? a.press : b.press,
            )
        }

        static func build(
            metadata: RecordingMetadata?,
            duration: TimeInterval,
        ) -> VideoEditorPointerTimeline {
            guard duration.isFinite, duration > 0 else { return .empty }

            let samples = streamEvents(from: metadata)
            guard let firstSample = samples.first else { return .empty }

            let pressSamples = samples.filter { $0.kind == .press }
            let intervals = pressIntervals(from: samples, duration: duration)

            let frameCount = max(2, Int((duration * stepRate).rounded(.up)) + 1)
            let dt = 1 / stepRate
            var xSpring = VideoEditorDampedSpring(position: firstSample.point.x)
            var ySpring = VideoEditorDampedSpring(position: firstSample.point.y)
            var magnificationSpring = VideoEditorDampedSpring(position: 1)
            var opacitySpring = VideoEditorDampedSpring(position: 1)

            var sampleIndex = -1
            var latestPressIndex = -1
            var pressIntervalIndex = 0
            var builtFrames: [VideoEditorPointerFrame] = []
            builtFrames.reserveCapacity(frameCount)

            for frameIndex in 0 ..< frameCount {
                let time = min(Double(frameIndex) * dt, duration)

                while sampleIndex + 1 < samples.count, samples[sampleIndex + 1].time <= time {
                    sampleIndex += 1
                }
                while latestPressIndex + 1 < pressSamples.count,
                      pressSamples[latestPressIndex + 1].time <= time {
                    latestPressIndex += 1
                }
                while pressIntervalIndex < intervals.count, intervals[pressIntervalIndex].end < time {
                    pressIntervalIndex += 1
                }

                let latest = sampleIndex >= 0 ? samples[sampleIndex] : firstSample
                var target = latest.point
                var approachingPress = false
                let upcomingPressIndex = latestPressIndex + 1
                if upcomingPressIndex < pressSamples.count {
                    let press = pressSamples[upcomingPressIndex]
                    let remaining = press.time - time
                    if remaining >= 0, remaining <= anticipationWindow {
                        target = press.point
                        approachingPress = remaining <= interceptWindow
                    }
                }

                let isPressed = pressIntervalIndex < intervals.count
                    && intervals[pressIntervalIndex].contains(time)
                let motion = approachingPress ? PointerSpring.intercept : PointerSpring.glide
                if frameIndex > 0 {
                    xSpring.step(toward: target.x, using: motion, dt: dt)
                    ySpring.step(toward: target.y, using: motion, dt: dt)
                }

                let targetMagnification = isPressed ? 0.8 : 1
                if frameIndex > 0 {
                    magnificationSpring.step(toward: targetMagnification, using: PointerSpring.settle, dt: dt)
                    opacitySpring.step(toward: 1, using: PointerSpring.settle, dt: dt)
                }

                let press: VideoEditorPointerPressFrame?
                if latestPressIndex >= 0 {
                    let event = pressSamples[latestPressIndex]
                    let elapsed = time - event.time
                    press = elapsed <= pulseDuration
                        ? VideoEditorPointerPressFrame(
                            location: event.point,
                            progress: min(max(elapsed / pulseDuration, 0), 1),
                        )
                        : nil
                } else {
                    press = nil
                }

                builtFrames.append(
                    VideoEditorPointerFrame(
                        location: CGPoint(x: xSpring.position, y: ySpring.position),
                        magnification: magnificationSpring.position,
                        opacity: min(max(opacitySpring.position, 0), 1),
                        press: press,
                    ),
                )
            }

            return VideoEditorPointerTimeline(frames: builtFrames, duration: duration)
        }

        static func buildForExport(
            metadata: RecordingMetadata?,
            duration: TimeInterval,
            trimStart: TimeInterval,
            trimEnd: TimeInterval,
            speedMap: SpeedTimeMap?,
        ) -> VideoEditorPointerTimeline {
            build(
                metadata: exportAdjustedMetadata(
                    metadata,
                    trimStart: trimStart,
                    trimEnd: trimEnd,
                    speedMap: speedMap,
                ),
                duration: duration,
            )
        }

        private static func exportAdjustedMetadata(
            _ metadata: RecordingMetadata?,
            trimStart: TimeInterval,
            trimEnd: TimeInterval,
            speedMap: SpeedTimeMap?,
        ) -> RecordingMetadata? {
            guard var metadata else { return nil }

            func mappedTime(_ time: TimeInterval) -> TimeInterval {
                let relative = time - trimStart
                if let speedMap {
                    return speedMap.toScaled(max(0, min(relative, speedMap.originalDuration)))
                }
                return relative
            }

            metadata.mouseSamples = metadata.mouseSamples
                .filter { $0.time >= trimStart && $0.time <= trimEnd }
                .map { sample in
                    var adjusted = sample
                    adjusted.time = mappedTime(sample.time)
                    return adjusted
                }
            metadata.mousePresses = metadata.mousePresses
                .filter { $0.time >= trimStart && $0.time <= trimEnd }
                .map { press in
                    var adjusted = press
                    adjusted.time = mappedTime(press.time)
                    return adjusted
                }
            metadata.keystrokes = metadata.keystrokes
                .filter { $0.time >= trimStart && $0.time <= trimEnd }
                .map { stroke in
                    var adjusted = stroke
                    adjusted.time = mappedTime(stroke.time)
                    return adjusted
                }
            return metadata
        }

        // MARK: - Private

        private struct StreamEvent: Equatable {
            enum Kind { case travel, press, release }

            var time: TimeInterval
            var point: CGPoint
            var kind: Kind
            var button: Int
        }

        private struct PressInterval {
            var start: TimeInterval
            var end: TimeInterval

            func contains(_ time: TimeInterval) -> Bool {
                time >= start && time <= end
            }
        }

        private static func streamEvents(from metadata: RecordingMetadata?) -> [StreamEvent] {
            guard let metadata else { return [] }

            var events: [StreamEvent] = []
            events.reserveCapacity(metadata.mouseSamples.count + metadata.mousePresses.count)

            for sample in metadata.mouseSamples {
                events.append(
                    StreamEvent(
                        time: sample.time,
                        point: normalized(sample.normalizedPoint),
                        kind: .travel,
                        button: 0,
                    ),
                )
            }
            for press in metadata.mousePresses {
                events.append(
                    StreamEvent(
                        time: press.time,
                        point: normalized(press.normalizedPoint),
                        kind: press.phase == .down ? .press : .release,
                        button: press.button,
                    ),
                )
            }

            return events.sorted {
                if $0.time != $1.time {
                    return $0.time < $1.time
                }
                if $0.kind != $1.kind {
                    return $0.kind == .travel
                }
                return $0.button < $1.button
            }
        }

        private static func pressIntervals(
            from samples: [StreamEvent],
            duration: TimeInterval,
        ) -> [PressInterval] {
            let presses = samples.filter { $0.kind == .press || $0.kind == .release }
            var result: [PressInterval] = []
            var unmatched: [Int: [StreamEvent]] = [:]

            for sample in presses {
                if sample.kind == .press {
                    unmatched[sample.button, default: []].append(sample)
                } else if var pending = unmatched[sample.button], !pending.isEmpty {
                    let press = pending.removeFirst()
                    unmatched[sample.button] = pending
                    result.append(
                        PressInterval(
                            start: max(0, press.time - pressAnticipation),
                            end: min(max(sample.time, press.time), duration),
                        ),
                    )
                }
            }

            for pending in unmatched.values {
                for press in pending {
                    result.append(
                        PressInterval(
                            start: max(0, press.time - pressAnticipation),
                            end: min(press.time + orphanPressHold, duration),
                        ),
                    )
                }
            }

            let sorted = result.sorted {
                if $0.start == $1.start {
                    return $0.end < $1.end
                }
                return $0.start < $1.start
            }
            var merged: [PressInterval] = []
            for interval in sorted {
                if let lastIndex = merged.indices.last, interval.start <= merged[lastIndex].end {
                    merged[lastIndex].end = max(merged[lastIndex].end, interval.end)
                } else {
                    merged.append(interval)
                }
            }
            return merged
        }

        private static func normalized(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        }
    }

    private enum PointerSpring {
        static let glide = VideoEditorSpringConstant(tension: 470, friction: 70, inertia: 3)
        static let intercept = VideoEditorSpringConstant(tension: 538, friction: 40, inertia: 1)
        static let settle = VideoEditorSpringConstant(tension: 300, friction: 30, inertia: 0.3)
    }
#endif

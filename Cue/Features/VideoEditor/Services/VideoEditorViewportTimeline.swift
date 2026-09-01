#if CUE_VIDEO_MODULE
//
    //  VideoEditorViewportTimeline.swift
    //  Notinhas
//
    //  Precomputed damped-spring viewport motion for zoom preview/export (Plan 110 / Screendrop parity).
//

    import CoreGraphics
    import Foundation

    struct VideoEditorViewportFrame: Sendable, Equatable {
        var magnification: Double
        var anchor: CGPoint

        static let identity = VideoEditorViewportFrame(
            magnification: 1,
            anchor: CGPoint(x: 0.5, y: 0.5),
        )
    }

    struct VideoEditorViewportTimeline: Sendable, Equatable {
        static let stepRate: Double = 120

        private static let motionProfile = VideoEditorSpringConstant(
            tension: 200,
            friction: 40,
            inertia: 2.25,
        )
        private static let travelComfortWidths = 1.4
        private static let settleGuardWindow: TimeInterval = 0.15
        private static let interiorMargin = 0.9

        private let frames: [VideoEditorViewportFrame]
        private let duration: TimeInterval

        static let identity = VideoEditorViewportTimeline(frames: [.identity], duration: 0)

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

        static func build(
            segments: [ZoomSegment],
            metadata: RecordingMetadata?,
            duration: TimeInterval,
        ) -> VideoEditorViewportTimeline {
            guard duration.isFinite, duration > 0 else { return .identity }

            let pointerSamples = mergedPointerSamples(from: metadata)
            let pressEvents = pointerSamples.filter(\.isPress)
            var activityTargetsBySegmentID: [UUID: [ActivityTarget]] = [:]
            for segment in segments where segment.anchorMode == .smart {
                activityTargetsBySegmentID[segment.id] = activityTargets(
                    for: segment,
                    samples: pointerSamples,
                    presses: metadata?.mousePresses ?? [],
                )
            }

            let frameCount = max(2, Int((duration * stepRate).rounded(.up)) + 1)
            let dt = 1.0 / stepRate

            var halfExtentSpring = VideoEditorDampedSpring(position: 0.5)
            var anchorXSpring = VideoEditorDampedSpring(position: 0.5)
            var anchorYSpring = VideoEditorDampedSpring(position: 0.5)
            var previousActive: ZoomSegment?
            var latestPressIndex = -1

            var builtFrames: [VideoEditorViewportFrame] = []
            builtFrames.reserveCapacity(frameCount)

            for frameIndex in 0 ..< frameCount {
                let time = min(Double(frameIndex) * dt, duration)
                while latestPressIndex + 1 < pressEvents.count,
                      pressEvents[latestPressIndex + 1].time <= time {
                    latestPressIndex += 1
                }

                let active = activeSegment(at: time, in: segments)
                let targetMagnification = max(1, Double(active?.zoomLevel ?? 1))
                let rawTarget = active.map { segment in
                    anchorPoint(
                        for: segment,
                        at: time,
                        samples: pointerSamples,
                        activityTargets: activityTargetsBySegmentID[segment.id] ?? [],
                    )
                } ?? CGPoint(x: 0.5, y: 0.5)
                let targetAnchor = boundedAnchor(
                    rawTarget,
                    magnification: targetMagnification,
                    anchorMode: active?.anchorMode ?? .pinned,
                    boundsBias: Double(active?.boundsBias ?? 0),
                )
                let targetHalfExtent = 1 / (2 * targetMagnification)
                let remainingTravel = hypot(
                    targetAnchor.x - anchorXSpring.position,
                    targetAnchor.y - anchorYSpring.position,
                )
                let pursuitMagnification = remainingTravel > 0.000_1
                    ? min(targetMagnification, max(1, travelComfortWidths / remainingTravel))
                    : targetMagnification
                let pursuitHalfExtent = 1 / (2 * pursuitMagnification)

                let activeChanged = active?.id != previousActive?.id
                let shouldSnap = activeChanged
                    && (active?.skipsEasing == true || previousActive?.skipsEasing == true)

                if shouldSnap {
                    halfExtentSpring.snap(to: targetHalfExtent)
                    anchorXSpring.snap(to: targetAnchor.x)
                    anchorYSpring.snap(to: targetAnchor.y)
                } else if frameIndex > 0 {
                    halfExtentSpring.step(toward: pursuitHalfExtent, using: motionProfile, dt: dt)
                    anchorXSpring.step(toward: targetAnchor.x, using: motionProfile, dt: dt)
                    anchorYSpring.step(toward: targetAnchor.y, using: motionProfile, dt: dt)
                }

                let safeHalfExtent = min(max(halfExtentSpring.position, 0.000_001), 0.5)
                let magnification = max(1, 1 / (2 * safeHalfExtent))
                var anchor = clampToFrame(
                    CGPoint(x: anchorXSpring.position, y: anchorYSpring.position),
                    magnification: magnification,
                )

                if let active,
                   active.anchorMode != .pinned,
                   latestPressIndex >= 0 {
                    let press = pressEvents[latestPressIndex]
                    let elapsed = time - press.time
                    if elapsed >= 0, elapsed <= settleGuardWindow {
                        anchor = settleWithinMargin(
                            press.point,
                            from: anchor,
                            magnification: magnification,
                            interiorMargin: interiorMargin,
                        )
                        anchorXSpring.position = anchor.x
                        anchorYSpring.position = anchor.y
                    }
                }

                builtFrames.append(VideoEditorViewportFrame(magnification: magnification, anchor: anchor))
                previousActive = active
            }

            return VideoEditorViewportTimeline(frames: builtFrames, duration: duration)
        }

        static func buildForExport(
            segments: [ZoomSegment],
            metadata: RecordingMetadata?,
            duration: TimeInterval,
            trimStart: TimeInterval,
            trimEnd: TimeInterval,
            speedMap: SpeedTimeMap?,
        ) -> VideoEditorViewportTimeline {
            let adjustedMetadata = adjustedMetadata(
                metadata,
                trimStart: trimStart,
                trimEnd: trimEnd,
                speedMap: speedMap,
            )
            return build(
                segments: segments.filter(\.isEnabled),
                metadata: adjustedMetadata,
                duration: duration,
            )
        }

        private static func adjustedMetadata(
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
            return metadata
        }

        // MARK: - Private helpers

        private struct PointerSample: Equatable {
            var time: TimeInterval
            var point: CGPoint
            var isPress: Bool
        }

        private struct ActivityTarget: Equatable {
            var activationTime: TimeInterval
            var point: CGPoint
        }

        private struct ActivityGroup {
            var minX: CGFloat
            var maxX: CGFloat
            var minY: CGFloat
            var maxY: CGFloat
            var firstTime: TimeInterval
            var firstPressTime: TimeInterval?

            init(sample: PointerSample) {
                minX = sample.point.x
                maxX = sample.point.x
                minY = sample.point.y
                maxY = sample.point.y
                firstTime = sample.time
                firstPressTime = sample.isPress ? sample.time : nil
            }

            var center: CGPoint {
                CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
            }

            mutating func include(_ sample: PointerSample) {
                minX = min(minX, sample.point.x)
                maxX = max(maxX, sample.point.x)
                minY = min(minY, sample.point.y)
                maxY = max(maxY, sample.point.y)
                if sample.isPress, firstPressTime == nil {
                    firstPressTime = sample.time
                }
            }

            func canInclude(
                _ sample: PointerSample,
                horizontalLimit: CGFloat,
                verticalLimit: CGFloat,
            ) -> Bool {
                min(sample.point.x, minX) >= maxX - horizontalLimit
                    && max(sample.point.x, maxX) <= minX + horizontalLimit
                    && min(sample.point.y, minY) >= maxY - verticalLimit
                    && max(sample.point.y, maxY) <= minY + verticalLimit
            }
        }

        private static func activeSegment(at time: TimeInterval, in segments: [ZoomSegment]) -> ZoomSegment? {
            var selected: ZoomSegment?
            var selectedPrecedence = Int.min

            for segment in segments where segment.isEnabled && segment.contains(time: time) {
                let precedence = segmentPriority(segment)
                if selected == nil
                    || precedence > selectedPrecedence
                    || (precedence == selectedPrecedence && segment.startTime >= selected!.startTime) {
                    selected = segment
                    selectedPrecedence = precedence
                }
            }
            return selected
        }

        private static func segmentPriority(_ segment: ZoomSegment) -> Int {
            if segment.isImplicit {
                return 0
            }
            switch segment.anchorMode {
            case .pointer: return 1
            case .smart: return 2
            case .pinned: return 3
            }
        }

        private static func anchorPoint(
            for segment: ZoomSegment,
            at time: TimeInterval,
            samples: [PointerSample],
            activityTargets: [ActivityTarget],
        ) -> CGPoint {
            switch segment.anchorMode {
            case .pinned:
                normalized(segment.zoomCenter)
            case .pointer:
                trackedPointerPosition(at: time, samples: samples) ?? normalized(segment.zoomCenter)
            case .smart:
                activityTarget(at: time, targets: activityTargets) ?? normalized(segment.zoomCenter)
            }
        }

        private static func activityTargets(
            for segment: ZoomSegment,
            samples: [PointerSample],
            presses: [RecordedMousePress],
        ) -> [ActivityTarget] {
            var cueSamples = samples.filter { $0.time >= segment.startTime && $0.time <= segment.endTime }
            if cueSamples.isEmpty {
                if let preceding = samples.last(where: { $0.time < segment.startTime }) {
                    cueSamples = [preceding]
                } else if let following = samples.first(where: { $0.time > segment.startTime }) {
                    cueSamples = [following]
                }
            }
            guard let first = cueSamples.first else { return [] }

            let magnification = max(Double(segment.zoomLevel), 1)
            let horizontalLimit = CGFloat(0.5 / magnification)
            let verticalLimit = CGFloat(0.7 / magnification)
            var group = ActivityGroup(sample: first)
            var groups: [ActivityGroup] = []

            for sample in cueSamples.dropFirst() {
                if group.canInclude(sample, horizontalLimit: horizontalLimit, verticalLimit: verticalLimit) {
                    group.include(sample)
                } else {
                    groups.append(group)
                    group = ActivityGroup(sample: sample)
                }
            }
            groups.append(group)

            let pressTimes = Set(presses.filter { $0.phase == .down }.map(\.time))
            let focusedGroups = groups.contains { $0.firstPressTime != nil }
                ? groups.filter { group in
                    guard let pressTime = group.firstPressTime else { return false }
                    return pressTimes.contains(where: { abs($0 - pressTime) < 0.001 })
                }
                : groups

            return focusedGroups.map { group in
                let activationTime = group.firstPressTime.map {
                    max(segment.startTime, $0 - 0.3)
                } ?? group.firstTime
                return ActivityTarget(activationTime: activationTime, point: group.center)
            }
        }

        private static func activityTarget(at time: TimeInterval, targets: [ActivityTarget]) -> CGPoint? {
            guard let first = targets.first else { return nil }
            guard time >= first.activationTime else { return nil }

            var low = 0
            var high = targets.count
            while low < high {
                let middle = (low + high) / 2
                if targets[middle].activationTime <= time {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            return targets[max(0, low - 1)].point
        }

        private static func trackedPointerPosition(at time: TimeInterval, samples: [PointerSample]) -> CGPoint? {
            guard let first = samples.first else { return nil }
            guard time >= first.time else { return first.point }

            var low = 0
            var high = samples.count
            while low < high {
                let middle = (low + high) / 2
                if samples[middle].time <= time {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            return samples[max(0, low - 1)].point
        }

        private static func mergedPointerSamples(from metadata: RecordingMetadata?) -> [PointerSample] {
            guard let metadata else { return [] }

            var merged: [(sample: PointerSample, sourceOrder: Int, originalIndex: Int)] = []
            merged.reserveCapacity(metadata.mouseSamples.count + metadata.mousePresses.count)

            for (index, travel) in metadata.mouseSamples.enumerated() {
                merged.append((
                    PointerSample(
                        time: travel.time,
                        point: normalized(travel.normalizedPoint),
                        isPress: false,
                    ),
                    0,
                    index,
                ))
            }
            for (index, press) in metadata.mousePresses.enumerated() where press.phase == .down {
                merged.append((
                    PointerSample(
                        time: press.time,
                        point: normalized(press.normalizedPoint),
                        isPress: true,
                    ),
                    1,
                    index,
                ))
            }

            return merged.sorted { lhs, rhs in
                if lhs.sample.time != rhs.sample.time {
                    return lhs.sample.time < rhs.sample.time
                }
                if lhs.sourceOrder != rhs.sourceOrder {
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                return lhs.originalIndex < rhs.originalIndex
            }.map(\.sample)
        }

        private static func boundedAnchor(
            _ point: CGPoint,
            magnification: Double,
            anchorMode: ZoomAnchorMode,
            boundsBias: Double,
        ) -> CGPoint {
            let rawCenteredTarget = normalized(point)
            guard anchorMode != .pinned else {
                return clampToFrame(rawCenteredTarget, magnification: magnification)
            }

            let halfExtent = 1 / (2 * max(magnification, 1))
            let screenPositionPreservingTarget = CGPoint(
                x: halfExtent + rawCenteredTarget.x * (1 - 2 * halfExtent),
                y: halfExtent + rawCenteredTarget.y * (1 - 2 * halfExtent),
            )
            let bias = min(max(boundsBias, 0), 1)
            let blended = CGPoint(
                x: rawCenteredTarget.x + (screenPositionPreservingTarget.x - rawCenteredTarget.x) * bias,
                y: rawCenteredTarget.y + (screenPositionPreservingTarget.y - rawCenteredTarget.y) * bias,
            )
            return clampToFrame(blended, magnification: magnification)
        }

        private static func clampToFrame(_ point: CGPoint, magnification: Double) -> CGPoint {
            let halfExtent = 1 / (2 * max(magnification, 1))
            return CGPoint(
                x: min(max(point.x, halfExtent), 1 - halfExtent),
                y: min(max(point.y, halfExtent), 1 - halfExtent),
            )
        }

        private static func settleWithinMargin(
            _ point: CGPoint,
            from anchor: CGPoint,
            magnification: Double,
            interiorMargin: Double,
        ) -> CGPoint {
            let halfExtent = 1 / (2 * max(magnification, 1))
            let margin = halfExtent * interiorMargin
            var settled = anchor
            if point.x < settled.x - margin {
                settled.x = point.x + margin
            }
            if point.x > settled.x + margin {
                settled.x = point.x - margin
            }
            if point.y < settled.y - margin {
                settled.y = point.y + margin
            }
            if point.y > settled.y + margin {
                settled.y = point.y - margin
            }
            return clampToFrame(settled, magnification: magnification)
        }

        private static func normalized(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(point.x, 0), 1),
                y: min(max(point.y, 0), 1),
            )
        }
    }
#endif

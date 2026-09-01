#if CUE_VIDEO_MODULE
//
    //  VideoEditorClipTimeline.swift
    //  Notinhas
//
    //  Non-destructive multi-clip edit map (Plan 110 / Phase C).
//

    import Foundation

    struct VideoEditorClipTimeline: Codable, Equatable, Sendable {
        struct Location: Equatable, Sendable {
            var segmentIndex: Int
            var segmentID: UUID
            var editorStart: TimeInterval
            var offset: TimeInterval
            var sourceTime: TimeInterval
        }

        struct Slice: Identifiable, Equatable, Sendable {
            struct ID: Hashable, Sendable {
                var segmentID: UUID
                var sourceStart: TimeInterval
                var sourceEnd: TimeInterval
            }

            var segmentID: UUID
            var sourceStart: TimeInterval
            var sourceEnd: TimeInterval
            var editorStart: TimeInterval
            var editorEnd: TimeInterval

            var id: ID {
                ID(segmentID: segmentID, sourceStart: sourceStart, sourceEnd: sourceEnd)
            }
        }

        var segments: [VideoEditorClipSegment]

        init(segments: [VideoEditorClipSegment]) {
            self.segments = segments
        }

        static func full(sourceDuration: TimeInterval) -> VideoEditorClipTimeline {
            let safeDuration = max(0, sourceDuration.isFinite ? sourceDuration : 0)
            guard safeDuration > 0 else { return VideoEditorClipTimeline(segments: []) }
            return VideoEditorClipTimeline(segments: [
                VideoEditorClipSegment(sourceStart: 0, sourceEnd: safeDuration),
            ])
        }

        static func legacyTrim(
            start: TimeInterval?,
            end: TimeInterval?,
            sourceDuration: TimeInterval,
        ) -> VideoEditorClipTimeline {
            let safeDuration = max(0, sourceDuration.isFinite ? sourceDuration : 0)
            let safeStart = min(max(start ?? 0, 0), safeDuration)
            let safeEnd = min(max(end ?? safeDuration, safeStart), safeDuration)
            guard safeEnd - safeStart >= VideoEditorClipSegment.minimumDuration else {
                return full(sourceDuration: safeDuration)
            }
            return VideoEditorClipTimeline(segments: [
                VideoEditorClipSegment(sourceStart: safeStart, sourceEnd: safeEnd),
            ])
        }

        var duration: TimeInterval {
            segments.reduce(0) { $0 + $1.editorDuration }
        }

        func normalized(to sourceDuration: TimeInterval) -> VideoEditorClipTimeline {
            let safeDuration = max(0, sourceDuration.isFinite ? sourceDuration : 0)
            var seenIDs = Set<UUID>()
            var normalized = segments.compactMap { segment -> VideoEditorClipSegment? in
                let start = min(max(segment.sourceStart, 0), safeDuration)
                let end = min(max(segment.sourceEnd, start), safeDuration)
                guard end - start >= VideoEditorClipSegment.minimumDuration else { return nil }
                let id = seenIDs.insert(segment.id).inserted ? segment.id : UUID()
                return VideoEditorClipSegment(
                    id: id,
                    sourceStart: start,
                    sourceEnd: end,
                    speed: segment.speed,
                ).clampedSpeed()
            }
            .sorted {
                if abs($0.sourceStart - $1.sourceStart) > 0.000_001 {
                    return $0.sourceStart < $1.sourceStart
                }
                return $0.sourceEnd < $1.sourceEnd
            }

            var previousEnd: TimeInterval = 0
            normalized = normalized.compactMap { segment in
                var segment = segment
                segment.sourceStart = max(segment.sourceStart, previousEnd)
                guard segment.duration >= VideoEditorClipSegment.minimumDuration else { return nil }
                previousEnd = segment.sourceEnd
                return segment
            }

            if normalized.isEmpty, safeDuration > 0 {
                return .full(sourceDuration: safeDuration)
            }
            return VideoEditorClipTimeline(segments: normalized)
        }

        func location(at editorTime: TimeInterval) -> Location? {
            guard !segments.isEmpty, duration > 0 else { return nil }
            let clamped = min(max(editorTime, 0), duration)
            var editorStart: TimeInterval = 0

            for (index, segment) in segments.enumerated() {
                let editorEnd = editorStart + segment.editorDuration
                if clamped < editorEnd || index == segments.index(before: segments.endIndex) {
                    let offset = min(max(clamped - editorStart, 0), segment.editorDuration)
                    let sourceOffset = min(offset * segment.speed, segment.duration)
                    return Location(
                        segmentIndex: index,
                        segmentID: segment.id,
                        editorStart: editorStart,
                        offset: offset,
                        sourceTime: segment.sourceStart + sourceOffset,
                    )
                }
                editorStart = editorEnd
            }
            return nil
        }

        func sourceTime(at editorTime: TimeInterval) -> TimeInterval {
            location(at: editorTime)?.sourceTime ?? 0
        }

        func editorTime(forSourceTime sourceTime: TimeInterval) -> TimeInterval? {
            var editorStart: TimeInterval = 0
            for segment in segments {
                if sourceTime >= segment.sourceStart - 0.000_001,
                   sourceTime <= segment.sourceEnd + 0.000_001 {
                    let sourceOffset = min(max(sourceTime - segment.sourceStart, 0), segment.duration)
                    return editorStart + sourceOffset / segment.speed
                }
                editorStart += segment.editorDuration
            }
            return nil
        }

        func split(at editorTime: TimeInterval) -> (timeline: VideoEditorClipTimeline, selectedID: UUID)? {
            guard let location = location(at: editorTime) else { return nil }
            let segment = segments[location.segmentIndex]
            let sourceTime = location.sourceTime
            guard sourceTime - segment.sourceStart >= VideoEditorClipSegment.minimumDuration,
                  segment.sourceEnd - sourceTime >= VideoEditorClipSegment.minimumDuration else {
                return nil
            }

            let trailingID = UUID()
            let leading = VideoEditorClipSegment(
                id: segment.id,
                sourceStart: segment.sourceStart,
                sourceEnd: sourceTime,
                speed: segment.speed,
            )
            let trailing = VideoEditorClipSegment(
                id: trailingID,
                sourceStart: sourceTime,
                sourceEnd: segment.sourceEnd,
                speed: segment.speed,
            )
            var next = segments
            next.replaceSubrange(location.segmentIndex ... location.segmentIndex, with: [leading, trailing])
            return (VideoEditorClipTimeline(segments: next), trailingID)
        }

        func deleting(segmentID: UUID) -> VideoEditorClipTimeline? {
            guard segments.count > 1, segments.contains(where: { $0.id == segmentID }) else {
                return nil
            }
            let next = segments.filter { $0.id != segmentID }
            guard next.reduce(0, { $0 + $1.duration }) >= VideoEditorClipSegment.minimumDuration else {
                return nil
            }
            return VideoEditorClipTimeline(segments: next)
        }

        func replacing(_ replacement: VideoEditorClipSegment) -> VideoEditorClipTimeline {
            guard let index = segments.firstIndex(where: { $0.id == replacement.id }) else {
                return self
            }
            var next = segments
            next[index] = replacement.clampedSpeed()
            return VideoEditorClipTimeline(segments: next)
        }

        func slices(overlapping sourceStart: TimeInterval, sourceEnd: TimeInterval) -> [Slice] {
            guard sourceEnd > sourceStart else { return [] }
            var result: [Slice] = []
            var editorOffset: TimeInterval = 0

            for segment in segments {
                let overlapStart = max(sourceStart, segment.sourceStart)
                let overlapEnd = min(sourceEnd, segment.sourceEnd)
                if overlapEnd > overlapStart {
                    let editorStart = editorOffset + (overlapStart - segment.sourceStart) / segment.speed
                    let editorEnd = editorOffset + (overlapEnd - segment.sourceStart) / segment.speed
                    result.append(
                        Slice(
                            segmentID: segment.id,
                            sourceStart: overlapStart,
                            sourceEnd: overlapEnd,
                            editorStart: editorStart,
                            editorEnd: editorEnd,
                        ),
                    )
                }
                editorOffset += segment.editorDuration
            }
            return result
        }

        func isUnedited(sourceDuration: TimeInterval) -> Bool {
            guard segments.count == 1, let only = segments.first else { return false }
            return abs(only.sourceStart) < 0.000_001
                && abs(only.sourceEnd - sourceDuration) < 0.000_001
                && abs(only.speed - 1) < 0.000_001
        }

        var hasPerClipSpeed: Bool {
            segments.contains { abs($0.speed - 1) > 0.000_1 }
        }

        func editorRange(for segmentID: UUID) -> ClosedRange<TimeInterval>? {
            var editorStart: TimeInterval = 0
            for segment in segments {
                let editorEnd = editorStart + segment.editorDuration
                if segment.id == segmentID {
                    return editorStart ... editorEnd
                }
                editorStart = editorEnd
            }
            return nil
        }

        /// Maps source-time zoom segments into the editor timeline after clip edits.
        static func mapZoomSegmentsToEditorTimeline(
            _ segments: [ZoomSegment],
            clipTimeline: VideoEditorClipTimeline,
        ) -> [ZoomSegment] {
            var mapped: [ZoomSegment] = []
            for segment in segments where segment.isEnabled {
                let sourceEnd = segment.startTime + segment.duration
                for slice in clipTimeline.slices(overlapping: segment.startTime, sourceEnd: sourceEnd) {
                    var copy = segment
                    copy.startTime = slice.editorStart
                    copy.duration = max(0, slice.editorEnd - slice.editorStart)
                    if copy.duration > 0.000_1 {
                        mapped.append(copy)
                    }
                }
            }
            return mapped.sorted { $0.startTime < $1.startTime }
        }
    }
#endif

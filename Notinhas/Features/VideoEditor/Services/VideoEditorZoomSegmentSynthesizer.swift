#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorZoomSegmentSynthesizer.swift
    //  Notinhas
//
    //  Builds implicit Follow Mouse zoom segments from recorded click events.
    //  Constants mirror Screendrop ZoomCueSynthesizer @ 57a48dd.
//

    import CoreGraphics
    import Foundation

    enum VideoEditorZoomSegmentSynthesizer {
        static let preRoll: TimeInterval = 0.3
        static let postRoll: TimeInterval = 2.5
        static let joinTolerance: TimeInterval = 2.5
        static let tailExclusion: TimeInterval = 1.0
        static let trailingGuard: TimeInterval = 0.8
        static let earliestStart: TimeInterval = 0.001
        static let defaultMagnification: CGFloat = 1.5

        private struct Candidate {
            var startTime: TimeInterval
            var endTime: TimeInterval
            var center: CGPoint
        }

        static func segments(from presses: [RecordedMousePress], duration: TimeInterval) -> [ZoomSegment] {
            guard duration.isFinite, duration > 0 else { return [] }

            let latestEligiblePress = duration - tailExclusion
            let candidates = presses
                .filter {
                    $0.phase == .down
                        && $0.time.isFinite
                        && $0.time < latestEligiblePress
                        && (0 ... 1).contains($0.normalizedX)
                        && (0 ... 1).contains($0.normalizedY)
                }
                .sorted { $0.time < $1.time }
                .compactMap { press -> Candidate? in
                    let startTime = max(press.time - preRoll, earliestStart)
                    let endTime = min(press.time + postRoll, duration - trailingGuard)
                    guard endTime > startTime else { return nil }
                    return Candidate(
                        startTime: startTime,
                        endTime: endTime,
                        center: press.normalizedPoint,
                    )
                }

            var merged: [Candidate] = []
            merged.reserveCapacity(candidates.count)
            for candidate in candidates {
                if var previous = merged.last,
                   candidate.startTime <= previous.endTime + joinTolerance {
                    previous.endTime = max(previous.endTime, candidate.endTime)
                    merged[merged.count - 1] = previous
                } else {
                    merged.append(candidate)
                }
            }

            return merged.map { candidate in
                ZoomSegment(
                    startTime: candidate.startTime,
                    duration: candidate.endTime - candidate.startTime,
                    zoomLevel: defaultMagnification,
                    zoomCenter: candidate.center,
                    zoomType: .auto,
                    isImplicit: true,
                ).clamped(to: duration)
            }
        }
    }
#endif

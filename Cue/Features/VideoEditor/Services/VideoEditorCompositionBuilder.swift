#if CUE_VIDEO_MODULE
//
    //  VideoEditorCompositionBuilder.swift
    //  Notinhas
//
    //  Shared gap-closing composition for clip playback and export (Plan 110 / Phase C).
//

    import AVFoundation
    import Foundation

    enum VideoEditorCompositionBuilder {
        /// Builds a playback/export asset from the source asset and non-destructive clip timeline.
        /// Returns the source asset unchanged when the timeline is a single full-speed span.
        static func makeAsset(
            from sourceAsset: AVAsset,
            clipTimeline: VideoEditorClipTimeline,
            sourceDuration: TimeInterval,
        ) throws -> AVAsset {
            let normalized = clipTimeline.normalized(to: sourceDuration)
            if normalized.isUnedited(sourceDuration: sourceDuration), !normalized.hasPerClipSpeed {
                return sourceAsset
            }

            let composition = AVMutableComposition()
            var insertionTime = CMTime.zero
            for clip in normalized.segments {
                let range = CMTimeRange(
                    start: CMTime(seconds: clip.sourceStart, preferredTimescale: 600),
                    duration: CMTime(seconds: clip.duration, preferredTimescale: 600),
                )
                try composition.insertTimeRange(range, of: sourceAsset, at: insertionTime)

                if abs(clip.speed - 1) > 0.000_001 {
                    let insertedRange = CMTimeRange(start: insertionTime, duration: range.duration)
                    let scaledDuration = CMTime(seconds: clip.editorDuration, preferredTimescale: 600)
                    composition.scaleTimeRange(insertedRange, toDuration: scaledDuration)
                    insertionTime = CMTimeAdd(insertionTime, scaledDuration)
                } else {
                    insertionTime = CMTimeAdd(insertionTime, range.duration)
                }
            }
            return composition
        }

        /// Inserts only the screen video track into an existing composition (zoom export path).
        static func insertClips(
            from asset: AVAsset,
            videoTrackID: CMPersistentTrackID?,
            clipTimeline: VideoEditorClipTimeline,
            sourceDuration: TimeInterval,
            into composition: AVMutableComposition,
        ) async throws -> (videoTrack: AVMutableCompositionTrack, duration: CMTime) {
            let sourceTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceTrack = sourceTracks.first(where: { $0.trackID == videoTrackID })
                ?? sourceTracks.first else {
                throw CompositionBuilderError.missingVideoTrack
            }

            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: sourceTrack.trackID,
            ) else {
                throw CompositionBuilderError.failedToAddTrack
            }

            let normalized = clipTimeline.normalized(to: sourceDuration)
            var insertAt = CMTime.zero
            for segment in normalized.segments {
                let sourceRange = CMTimeRange(
                    start: CMTime(seconds: segment.sourceStart, preferredTimescale: 600),
                    duration: CMTime(seconds: segment.duration, preferredTimescale: 600),
                )
                try compositionTrack.insertTimeRange(sourceRange, of: sourceTrack, at: insertAt)
                if abs(segment.speed - 1) > 0.000_001 {
                    let insertedRange = CMTimeRange(
                        start: insertAt,
                        duration: sourceRange.duration,
                    )
                    compositionTrack.scaleTimeRange(
                        insertedRange,
                        toDuration: CMTime(seconds: segment.editorDuration, preferredTimescale: 600),
                    )
                }
                insertAt = CMTimeAdd(insertAt, CMTime(seconds: segment.editorDuration, preferredTimescale: 600))
            }

            return (compositionTrack, insertAt)
        }

        enum CompositionBuilderError: Error {
            case missingVideoTrack
            case failedToAddTrack
        }
    }
#endif

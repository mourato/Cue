import AVFoundation
import Foundation

@MainActor
enum CueVideoUploadTranscoder {
    static func prepare(
        sourceURL: URL,
        maximumBytes: Int64,
        settings: CueVideoUploadSettings,
    ) async throws -> CuePreparedUpload {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueVideoUpload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        do {
            var currentSettings = settings
            for attempt in 0 ... 3 {
                try Task.checkCancellation()
                let outputURL = temporaryDirectory.appendingPathComponent("optimized.mp4")
                try await export(sourceURL: sourceURL, to: outputURL, settings: currentSettings)

                let fileSize = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                if fileSize > 0, Int64(fileSize) <= maximumBytes {
                    return .temporary(url: outputURL, cleanupURL: temporaryDirectory)
                }

                try? FileManager.default.removeItem(at: outputURL)
                guard let reducedSettings = currentSettings.reducedForRetry(attempt + 1) else {
                    throw CueUploadEncodingError.videoCouldNotFitLimit
                }
                currentSettings = reducedSettings
            }

            throw CueUploadEncodingError.videoCouldNotFitLimit
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw CancellationError()
        } catch let error as CueUploadEncodingError {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw CueUploadEncodingError.videoTranscodingFailed
        }
    }

    private static func export(sourceURL: URL, to outputURL: URL, settings: CueVideoUploadSettings) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceTrack = videoTracks.first else {
            throw CueUploadEncodingError.videoTranscodingFailed
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await sourceTrack.load(.naturalSize)
        let preferredTransform = try await sourceTrack.load(.preferredTransform)
        let sourceBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        let sourceWidth = max(sourceBounds.width, 2)
        let sourceHeight = max(sourceBounds.height, 2)
        let scale = min(1, Double(settings.maximumDimension) / Double(max(sourceWidth, sourceHeight)))
        let outputSize = CGSize(
            width: evenDimension(sourceWidth * scale),
            height: evenDimension(sourceHeight * scale),
        )

        let exportAsset: AVAsset
        let exportTrack: AVAssetTrack
        if settings.includesAudio {
            exportAsset = asset
            exportTrack = sourceTrack
        } else {
            let composition = AVMutableComposition()
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid,
            ) else {
                throw CueUploadEncodingError.videoTranscodingFailed
            }
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: .zero,
            )
            exportAsset = composition
            exportTrack = compositionTrack
        }

        guard let exportSession = AVAssetExportSession(
            asset: exportAsset,
            presetName: exportPreset(for: settings.quality),
        ) else {
            throw CueUploadEncodingError.videoTranscodingFailed
        }

        let transformedBounds = sourceBounds
        let transformScale = min(
            outputSize.width / max(transformedBounds.width, 1),
            outputSize.height / max(transformedBounds.height, 1),
        )
        let translation = CGAffineTransform(
            translationX: -transformedBounds.minX,
            y: -transformedBounds.minY,
        )
        let resize = CGAffineTransform(scaleX: transformScale, y: transformScale)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: exportTrack)
        layerInstruction.setTransform(
            preferredTransform.concatenating(translation).concatenating(resize),
            at: .zero,
        )
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        try Task.checkCancellation()
        // AVAssetExportSession is actor-bound on current SDKs; cancellation is observed
        // immediately before and after the native export, and the caller removes the temp file.
        await exportSession.export()
        try Task.checkCancellation()

        guard exportSession.status == .completed,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            throw exportSession.error ?? CueUploadEncodingError.videoTranscodingFailed
        }
    }

    private static func exportPreset(for quality: CueVideoUploadQuality) -> String {
        switch quality {
        case .high: AVAssetExportPresetHighestQuality
        case .balanced: AVAssetExportPreset1920x1080
        case .compact: AVAssetExportPresetMediumQuality
        }
    }

    private static func evenDimension(_ value: CGFloat) -> CGFloat {
        CGFloat(max(2, Int(value.rounded()) & ~1))
    }
}

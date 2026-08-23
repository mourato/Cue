#if NOTINHAS_VIDEO_MODULE
import AVFoundation
import CoreGraphics
import ImageIO

struct VideoFrameExtractionRequest: Sendable, Equatable {
    let sourceURL: URL
    let requestedTime: TimeInterval
    let assetDuration: TimeInterval
    let baseName: String

    var clampedTime: TimeInterval? {
        VideoFrameExtractor.clampTime(requestedTime, duration: assetDuration)
    }
}

struct VideoFrameExtractionResult: Sendable, Equatable {
    let url: URL
    let requestedTime: TimeInterval
    let actualTime: TimeInterval
}

enum VideoFrameExtractionError: LocalizedError {
    case invalidRequestTime
    case couldNotCreateImage
    case couldNotCreatePNG
    case couldNotWritePNG

    var errorDescription: String? {
        switch self {
        case .invalidRequestTime:
            "The video has no valid frame time."
        case .couldNotCreateImage:
            "Could not extract the current video frame."
        case .couldNotCreatePNG, .couldNotWritePNG:
            "Could not save the extracted video frame."
        }
    }
}

enum VideoFrameExtractor {
    static func clampTime(_ requestedTime: TimeInterval, duration: TimeInterval) -> TimeInterval? {
        guard duration.isFinite, duration >= 0, requestedTime.isFinite else { return nil }
        return min(max(requestedTime, 0), duration)
    }

    static func extract(
        request: VideoFrameExtractionRequest,
        outputRoot: URL,
    ) async throws -> VideoFrameExtractionResult {
        guard let clampedTime = request.clampedTime else {
            throw VideoFrameExtractionError.invalidRequestTime
        }

        let outputURL = CaptureOutputNaming.makeUniqueFileURL(
            in: outputRoot,
            baseName: "(request.baseName)-frame",
            fileExtension: "png",
        )

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
                    let generator = AVAssetImageGenerator(asset: AVAsset(url: request.sourceURL))
                    generator.appliesPreferredTrackTransform = true
                    var actualCMTime = CMTime.zero
                    let image = try generator.copyCGImage(
                        at: CMTime(seconds: clampedTime, preferredTimescale: 600),
                        actualTime: &actualCMTime,
                    )
                    guard let destination = CGImageDestinationCreateWithURL(
                        outputURL as CFURL,
                        "public.png" as CFString,
                        1,
                        nil,
                    ) else {
                        throw VideoFrameExtractionError.couldNotCreatePNG
                    }

                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else {
                        throw VideoFrameExtractionError.couldNotWritePNG
                    }
                    guard FileManager.default.fileExists(atPath: outputURL.path),
                          ((try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue ?? 0) > 0
                    else {
                        throw VideoFrameExtractionError.couldNotWritePNG
                    }

                    continuation.resume(returning: VideoFrameExtractionResult(
                        url: outputURL,
                        requestedTime: clampedTime,
                        actualTime: CMTimeGetSeconds(actualCMTime),
                    ))
                } catch {
                    try? FileManager.default.removeItem(at: outputURL)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
#endif

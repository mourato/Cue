#if CUE_VIDEO_MODULE
//
    //  GIFConverter.swift
    //  Notinhas
//
    //  Converts video files to animated GIF (Macshot strategy):
    //  gifski when available (bundled/Homebrew auto-detect, --quality 90-class),
    //  otherwise full-color frames straight to ImageIO with no manual palette cut.
    //  No FFmpeg dependency.
//

    import AVFoundation
    import CoreGraphics
    import CoreVideo
    import Foundation
    import ImageIO
    import UniformTypeIdentifiers

    /// Converts a video file to an animated GIF
    @MainActor
    final class GIFConverter {
        /// GIF generation parameters
        struct Options {
            /// Frame rate for the GIF (higher = smoother but larger)
            var fps: Int = 15

            /// Max output width in pixels (source width used if smaller; 0 keeps the source width)
            var maxWidth: CGFloat = 960

            /// Collapse consecutive duplicate frames, extending the previous frame delay
            var optimize: Bool = true

            /// Output quality 0.1 (low) … 1.0 (high); maps to gifski --quality.
            /// The ImageIO fallback always receives full-color frames.
            var quality: Double = 1.0

            /// Infinite loop by default
            var loopCount: Int = 0

            /// Balanced defaults: 15fps @ up to 960px wide
            nonisolated static let `default` = Options()
        }

        /// Convert a video file to animated GIF
        /// - Parameters:
        ///   - videoURL: URL of the source video
        ///   - options: GIF generation options
        ///   - onProgress: Progress callback (0.0 - 1.0), called on MainActor
        /// - Returns: URL of the generated GIF file
        static func convert(
            videoURL: URL,
            options: Options = .default,
            onProgress: @escaping (Double) -> Void,
        ) async throws -> URL {
            let sourceAccess = SandboxFileAccessManager.shared.beginAccessingURL(videoURL)
            let outputDirectoryAccess = SandboxFileAccessManager.shared.beginAccessingURL(
                videoURL.deletingLastPathComponent(),
            )
            defer {
                sourceAccess.stop()
                outputDirectoryAccess.stop()
            }
            DiagnosticLogger.shared.log(.info, .recording, "GIF conversion pipeline started", context: [
                "file": videoURL.lastPathComponent,
                "fps": "\(options.fps)",
                "maxWidth": "\(Int(options.maxWidth))",
            ])

            let asset = AVURLAsset(url: videoURL)

            // Get video duration
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            guard durationSeconds > 0, durationSeconds.isFinite else {
                DiagnosticLogger.shared.log(.error, .recording, "GIF conversion invalid video duration", context: [
                    "file": videoURL.lastPathComponent,
                    "durationSeconds": "\(durationSeconds)",
                ])
                throw GIFConversionError.invalidVideo
            }

            // Get video dimensions for scaling
            let videoTrack = try? await asset.loadTracks(withMediaType: .video).first

            let naturalSize: CGSize
            if let track = videoTrack {
                naturalSize = await (try? track.load(.naturalSize)) ?? CGSize(width: 640, height: 480)
            } else {
                DiagnosticLogger.shared.log(
                    .warning,
                    .recording,
                    "GIF conversion found no video track; using fallback size",
                    context: [
                        "file": videoURL.lastPathComponent,
                    ],
                )
                naturalSize = CGSize(width: 640, height: 480)
            }

            // Scale only if source exceeds maxWidth — never upscale.
            // A non-positive maxWidth keeps the source width ("Original").
            let effectiveMaxWidth = options.maxWidth > 0 ? options.maxWidth : naturalSize.width
            let scale = min(1.0, effectiveMaxWidth / naturalSize.width)
            let outputWidth = Int(naturalSize.width * scale)
            let outputHeight = Int(naturalSize.height * scale)

            // Preferred path (Macshot): gifski when a binary is available.
            // Optional auto-detect only — any failure falls through to ImageIO.
            if let gifskiBinary = locateGifskiBinary() {
                do {
                    return try await exportViaGifski(
                        binary: gifskiBinary,
                        asset: asset,
                        videoURL: videoURL,
                        outputWidth: outputWidth,
                        outputHeight: outputHeight,
                        durationSeconds: durationSeconds,
                        options: options,
                        onProgress: onProgress,
                    )
                } catch {
                    DiagnosticLogger.shared.log(
                        .warning,
                        .recording,
                        "GIF gifski export failed; falling back to ImageIO",
                        context: ["file": videoURL.lastPathComponent],
                    )
                }
            }

            // Calculate frame times
            let totalFrames = Int(ceil(durationSeconds * Double(options.fps)))
            guard totalFrames > 0 else {
                DiagnosticLogger.shared.log(.error, .recording, "GIF conversion has no frame times", context: [
                    "durationSeconds": String(format: "%.3f", durationSeconds),
                    "fps": "\(options.fps)",
                ])
                throw GIFConversionError.noFrames
            }
            DiagnosticLogger.shared.log(.debug, .recording, "GIF conversion plan", context: [
                "durationSeconds": String(format: "%.3f", durationSeconds),
                "sourceSize": "\(Int(naturalSize.width))x\(Int(naturalSize.height))",
                "outputSize": "\(outputWidth)x\(outputHeight)",
                "expectedFrames": "\(totalFrames)",
            ])

            var frameTimes: [NSValue] = []
            for i in 0 ..< totalFrames {
                let time = CMTime(
                    seconds: Double(i) / Double(options.fps),
                    preferredTimescale: 9600, // High timescale for sub-frame precision
                )
                frameTimes.append(NSValue(time: time))
            }

            // Setup image generator with quality-focused settings
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: outputWidth, height: outputHeight)
            generator.appliesPreferredTrackTransform = true

            // Tight tolerance for accurate frame extraction (reduces ghosting)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.02, preferredTimescale: 9600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.02, preferredTimescale: 9600)

            // Output assembly happens after frame extraction, once the final
            // (possibly optimized) frame count is known.

            // Extract frames — collect with index to preserve ordering
            let orderedFrames = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[CGImage], Error>) in
                let expectedCount = frameTimes.count
                let collector = GIFFrameCollector(
                    expectedCount: expectedCount,
                    videoFileName: videoURL.lastPathComponent,
                    onProgress: onProgress,
                    continuation: continuation,
                )

                generator.generateCGImagesAsynchronously(forTimes: frameTimes) {
                    requestedTime, image, _, _, _ in
                    let requestedSeconds = CMTimeGetSeconds(requestedTime)
                    let frameIndex = Int(round(requestedSeconds * Double(options.fps)))
                    Task { @MainActor in
                        collector.record(image: image, frameIndex: frameIndex)
                    }
                }
            }
            if orderedFrames.count < totalFrames {
                DiagnosticLogger.shared.log(
                    .warning,
                    .recording,
                    "GIF conversion generated fewer frames than expected",
                    context: [
                        "expectedFrames": "\(totalFrames)",
                        "generatedFrames": "\(orderedFrames.count)",
                    ],
                )
            }

            // Collapse duplicates only — frames stay full-color for ImageIO.
            let plannedFrames = GIFFramePlan.process(frames: orderedFrames, options: options)
            DiagnosticLogger.shared.log(.debug, .recording, "GIF conversion frames planned", context: [
                "extractedFrames": "\(orderedFrames.count)",
                "outputFrames": "\(plannedFrames.images.count)",
                "optimize": "\(options.optimize)",
                "quality": String(format: "%.2f", options.quality),
            ])

            // Generate output URL (same directory, .gif extension)
            let gifURL = videoURL.deletingPathExtension().appendingPathExtension("gif")

            // Remove existing GIF if any
            try? FileManager.default.removeItem(at: gifURL)

            // Create GIF destination
            guard let destination = CGImageDestinationCreateWithURL(
                gifURL as CFURL,
                UTType.gif.identifier as CFString,
                plannedFrames.images.count,
                nil,
            ) else {
                DiagnosticLogger.shared.log(.error, .recording, "GIF conversion destination creation failed", context: [
                    "file": gifURL.lastPathComponent,
                    "expectedFrames": "\(plannedFrames.images.count)",
                ])
                throw GIFConversionError.destinationCreationFailed
            }

            // Set GIF-level properties (loop count only — ImageIO picks the color map)
            let gifProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: options.loopCount,
                ],
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

            // Add all frames to GIF destination
            for (idx, frame) in plannedFrames.images.enumerated() {
                let frameProperties: [String: Any] = [
                    kCGImagePropertyGIFDictionary as String: [
                        kCGImagePropertyGIFDelayTime as String: plannedFrames.delays[idx],
                        kCGImagePropertyGIFUnclampedDelayTime as String: plannedFrames.delays[idx],
                    ],
                ]
                CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)

                // Progress for assembly phase (85% → 100%)
                let assemblyProgress = 0.85 + (Double(idx) / Double(plannedFrames.images.count)) * 0.15
                onProgress(assemblyProgress)
                if idx % 8 == 7 {
                    await Task.yield()
                }
            }

            // Finalize GIF
            guard CGImageDestinationFinalize(destination) else {
                DiagnosticLogger.shared.log(.error, .recording, "GIF conversion finalization failed", context: [
                    "file": gifURL.lastPathComponent,
                    "frames": "\(orderedFrames.count)",
                ])
                throw GIFConversionError.finalizationFailed
            }

            onProgress(1.0)

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: gifURL.path)[.size] as? Int) ?? 0
            let fileSizeMB = String(format: "%.1f", Double(fileSize) / 1_048_576.0)
            DiagnosticLogger.shared.log(.info, .recording, "GIF conversion completed", context: [
                "file": gifURL.lastPathComponent,
                "frames": "\(orderedFrames.count)",
                "fileSizeMB": fileSizeMB,
            ])

            return gifURL
        }
    }

    // MARK: - Errors

    enum GIFConversionError: Error, LocalizedError {
        case invalidVideo
        case noFrames
        case destinationCreationFailed
        case finalizationFailed

        var errorDescription: String? {
            switch self {
            case .invalidVideo: L10n.GIF.invalidVideo
            case .noFrames: L10n.GIF.noFramesFromVideo
            case .destinationCreationFailed: L10n.GIF.cannotCreateOutputFile
            case .finalizationFailed: L10n.GIF.finalizeFailed
            }
        }
    }

    /// Frame planning: duplicate collapse only (optimize).
    /// Frames stay full-color — quantization belongs to the encoder
    /// (gifski, or ImageIO's single pass), never to a manual pre-cut.
    enum GIFFramePlan {
        struct PlannedFrames {
            let images: [CGImage]
            let delays: [Double]
        }

        static func process(frames: [CGImage], options: GIFConverter.Options) -> PlannedFrames {
            let baseDelay = 1.0 / Double(max(options.fps, 1))
            var images: [CGImage] = []
            var delays: [Double] = []
            var previousHash: UInt64?
            for frame in frames {
                let hash = thumbnailHash(frame)
                if options.optimize, let previousHash, previousHash == hash, !delays.isEmpty {
                    delays[delays.count - 1] += baseDelay
                    continue
                }
                previousHash = hash
                images.append(frame)
                delays.append(baseDelay)
            }
            return PlannedFrames(images: images, delays: delays)
        }

        /// Exact-match hash over an 8×8 thumbnail. Static screen content extracts
        /// bit-identical frames, so equality is a safe collapse signal.
        static func thumbnailHash(_ image: CGImage) -> UInt64 {
            guard let thumbnail = downsampledRGBA(of: image, maxDimension: 8) else {
                return 0
            }
            var hash: UInt64 = 14_695_981_039_122_823
            for byte in thumbnail.pixels {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            return hash
        }

        /// Collapses consecutive duplicate hashes, extending the previous delay.
        /// Pure helper kept separate for deterministic testing.
        static func collapse(hashes: [UInt64], frameDelay: Double) -> (indices: [Int], delays: [Double]) {
            var indices: [Int] = []
            var delays: [Double] = []
            var previousHash: UInt64?
            for (index, hash) in hashes.enumerated() {
                if let previousHash, previousHash == hash, !delays.isEmpty {
                    delays[delays.count - 1] += frameDelay
                    continue
                }
                previousHash = hash
                indices.append(index)
                delays.append(frameDelay)
            }
            return (indices, delays)
        }

        struct RGBAImage {
            let width: Int
            let height: Int
            var pixels: [UInt8]
        }

        static func downsampledRGBA(of image: CGImage, maxDimension: Int) -> RGBAImage? {
            var width = image.width
            var height = image.height
            guard width > 0, height > 0 else { return nil }
            let longest = max(width, height)
            if longest > maxDimension {
                let scale = Double(maxDimension) / Double(longest)
                width = max(1, Int((Double(width) * scale).rounded()))
                height = max(1, Int((Double(height) * scale).rounded()))
            }
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ), let data = context.data else {
                return nil
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let byteCount = width * height * 4
            var pixels = [UInt8](repeating: 0, count: byteCount)
            pixels.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                memcpy(base, data, byteCount)
            }
            return RGBAImage(width: width, height: height, pixels: pixels)
        }
    }

    // MARK: - Gifski (Macshot strategy, optional auto-detect)

    /// Bundled binary first, then Homebrew locations. Nil when absent —
    /// callers must fall back to ImageIO silently.
    func locateGifskiBinary() -> URL? {
        var candidates: [URL] = []
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent("gifski"))
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/gifski"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/gifski"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Maps the 0.1…1.0 Quality slider to gifski --quality (30…100).
    func gifskiQuality(for quality: Double) -> Int {
        min(100, max(30, Int((min(max(quality, 0.1), 1.0) * 100).rounded())))
    }

    // ponytail: sequential PNG staging + coarse progress; parallelize if slow.
    /// Preferred export: stage full-color PNGs via AVAssetReader, then gifski.
    /// Throws on any failure so the caller falls back to ImageIO.
    @MainActor
    private func exportViaGifski(
        binary: URL,
        asset: AVURLAsset,
        videoURL: URL,
        outputWidth: Int,
        outputHeight: Int,
        durationSeconds: Double,
        options: GIFConverter.Options,
        onProgress: @escaping (Double) -> Void,
    ) async throws -> URL {
        let gifFPS = min(max(options.fps, 1), 50)
        let tracks = try? await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks?.first else { throw GIFConversionError.noFrames }
        let sourceFPS = max(Int(videoTrack.nominalFrameRate.rounded()), gifFPS, 1)
        let gifURL = videoURL.deletingPathExtension().appendingPathExtension("gif")

        let reader = try AVAssetReader(asset: asset)
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        trackOutput.alwaysCopiesSampleData = true
        guard reader.canAdd(trackOutput) else { throw GIFConversionError.noFrames }
        reader.add(trackOutput)

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("gifski-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        // Phase 1 (0–50%): decode, decimate, stage PNGs.
        var framePaths: [String] = []
        var inputIndex = 0
        reader.startReading()
        while reader.status == .reading {
            guard let sampleBuffer = trackOutput.copyNextSampleBuffer(),
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { break }
            inputIndex += 1
            let prevTargetIndex = (inputIndex - 1) * gifFPS / sourceFPS
            let targetIndex = inputIndex * gifFPS / sourceFPS
            guard targetIndex > prevTargetIndex else { continue }
            guard let image = scaledImage(from: pixelBuffer, dstWidth: outputWidth, dstHeight: outputHeight)
            else { continue }
            let path = workDir.appendingPathComponent(String(format: "frame_%06d.png", framePaths.count)).path
            guard writePNG(image, toPath: path) else { throw GIFConversionError.destinationCreationFailed }
            framePaths.append(path)
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            if durationSeconds > 0, pts.isFinite {
                onProgress(min(0.5, pts / durationSeconds * 0.5))
            }
            if framePaths.count % 8 == 0 {
                await Task.yield()
            }
        }
        guard reader.status != .failed, !framePaths.isEmpty else { throw GIFConversionError.noFrames }

        // Phase 2 (50–100%): gifski across all cores.
        onProgress(0.5)
        let tmpGIF = workDir.appendingPathComponent("out.gif")
        let exitCode: Int32 = try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = binary
            proc.arguments = ["--fps", String(gifFPS), "--quality", String(gifskiQuality(for: options.quality)),
                              "-o", tmpGIF.path] + framePaths
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            proc.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        guard exitCode == 0 else { throw GIFConversionError.finalizationFailed }

        try? FileManager.default.removeItem(at: gifURL)
        try FileManager.default.moveItem(at: tmpGIF, to: gifURL)
        onProgress(1.0)
        return gifURL
    }

    /// Full-color sRGB copy of a BGRA buffer, scaled (down only) with high
    /// interpolation. Owns its pixels — safe to encode after unlock.
    private func scaledImage(from pixelBuffer: CVPixelBuffer, dstWidth: Int, dstHeight: Int) -> CGImage? {
        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard srcWidth > 0, srcHeight > 0, dstWidth > 0, dstHeight > 0 else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let srcProvider = CGDataProvider(
            dataInfo: nil, data: baseAddress, size: srcBytesPerRow * srcHeight, releaseData: { _, _, _ in },
        ) else { return nil }
        guard let srcImage = CGImage(
            width: srcWidth, height: srcHeight, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: srcBytesPerRow, space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue
                | CGImageAlphaInfo.premultipliedFirst.rawValue),
            provider: srcProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent,
        ) else { return nil }
        guard let dstContext = CGContext(
            data: nil, width: dstWidth, height: dstHeight, bitsPerComponent: 8, bytesPerRow: dstWidth * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return nil }
        dstContext.interpolationQuality = .high
        dstContext.draw(srcImage, in: CGRect(x: 0, y: 0, width: dstWidth, height: dstHeight))
        return dstContext.makeImage()
    }

    private func writePNG(_ image: CGImage, toPath path: String) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil,
        ) else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    /// Serializes callback bookkeeping on the MainActor. AVAssetImageGenerator
    /// may invoke its callback concurrently; keeping the frame map and
    /// continuation here preserves indexed ordering without shared mutable
    /// captured variables.
    @MainActor
    private final class GIFFrameCollector {
        private let expectedCount: Int
        private let videoFileName: String
        private let onProgress: (Double) -> Void
        private var continuation: CheckedContinuation<[CGImage], Error>?
        private var frameMap: [Int: CGImage] = [:]
        private var completedCount = 0
        private var didFinish = false

        init(
            expectedCount: Int,
            videoFileName: String,
            onProgress: @escaping (Double) -> Void,
            continuation: CheckedContinuation<[CGImage], Error>,
        ) {
            self.expectedCount = expectedCount
            self.videoFileName = videoFileName
            self.onProgress = onProgress
            self.continuation = continuation
        }

        func record(image: CGImage?, frameIndex: Int) {
            guard !didFinish else { return }

            completedCount += 1
            if let image {
                frameMap[frameIndex] = image
            }

            let progress = Double(completedCount) / Double(expectedCount)
            onProgress(progress * 0.85) // Reserve 15% for GIF assembly

            guard completedCount >= expectedCount else { return }

            didFinish = true
            let sorted = (0 ..< expectedCount).compactMap { frameMap[$0] }
            if sorted.isEmpty {
                DiagnosticLogger.shared.log(
                    .error,
                    .recording,
                    "GIF conversion generated no frames",
                    context: [
                        "file": videoFileName,
                        "expectedFrames": "\(expectedCount)",
                    ],
                )
                continuation?.resume(throwing: GIFConversionError.noFrames)
            } else {
                continuation?.resume(returning: sorted)
            }
            continuation = nil
        }
    }
#endif

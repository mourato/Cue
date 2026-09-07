#if CUE_VIDEO_MODULE
//
    //  GIFConverter.swift
    //  Notinhas
//
    //  Converts video files to animated GIF using AVFoundation + ImageIO
    //  Optimizes for visual quality while keeping file size reasonable
    //  No FFmpeg dependency — pure Apple frameworks
//

    import AVFoundation
    import CoreGraphics
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

            /// Output quality 0.1 (low) … 1.0 (high); maps to palette color count
            var quality: Double = 0.75

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

            // Collapse duplicates and quantize the palette per options, then write.
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

            // Set GIF-level properties (loop count + color model)
            let gifProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: options.loopCount,
                    kCGImagePropertyGIFHasGlobalColorMap as String: true,
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

    /// Frame planning: duplicate collapse (optimize) and palette reduction (quality).
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
            let maxColors = GIFPaletteQuantizer.colorCount(for: options.quality)
            guard maxColors < 256 else {
                return PlannedFrames(images: images, delays: delays)
            }
            let quantized = images.map { GIFPaletteQuantizer.quantize($0, maxColors: maxColors) ?? $0 }
            return PlannedFrames(images: quantized, delays: delays)
        }

        /// Exact-match hash over an 8×8 thumbnail. Static screen content extracts
        /// bit-identical frames, so equality is a safe collapse signal.
        static func thumbnailHash(_ image: CGImage) -> UInt64 {
            guard let thumbnail = GIFPaletteQuantizer.downsampledRGBA(of: image, maxDimension: 8) else {
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
    }

    /// Median-cut palette reduction mapping the Quality slider to color counts.
    enum GIFPaletteQuantizer {
        struct RGBAImage {
            let width: Int
            let height: Int
            var pixels: [UInt8]
        }

        /// Maps 0.1 (low) … 1.0 (high) to 16 … 256 colors. 1.0 keeps full color.
        static func colorCount(for quality: Double) -> Int {
            if quality >= 1.0 {
                return 256
            }
            let clamped = min(max(quality, 0.1), 1.0)
            return Int((16.0 + (clamped - 0.1) / 0.9 * 224.0).rounded())
        }

        /// Reduces `image` to at most `maxColors` distinct colors, preserving
        /// dimensions and alpha. Returns nil when pixels are unreadable.
        static func quantize(_ image: CGImage, maxColors: Int) -> CGImage? {
            guard maxColors < 256 else { return image }
            guard let sample = downsampledRGBA(of: image, maxDimension: 480),
                  let full = downsampledRGBA(of: image, maxDimension: max(image.width, image.height))
            else {
                return nil
            }
            let (palette, lookup) = medianCutPalette(pixels: sample.pixels, maxColors: maxColors)
            guard !palette.isEmpty else { return nil }
            var remapped = full.pixels
            remapped.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                var i = 0
                while i + 3 < buffer.count {
                    let bucket = bucketIndex(r: base[i], g: base[i + 1], b: base[i + 2])
                    let color = palette[lookup[bucket]]
                    base[i] = color.0
                    base[i + 1] = color.1
                    base[i + 2] = color.2
                    i += 4
                }
            }
            return makeImage(width: full.width, height: full.height, pixels: remapped)
        }

        // MARK: - Internals

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

        private static let histogramLevels = 32

        private static func bucketIndex(r: UInt8, g: UInt8, b: UInt8) -> Int {
            (Int(r) >> 3) << 10 | (Int(g) >> 3) << 5 | (Int(b) >> 3)
        }

        private static func medianCutPalette(
            pixels: [UInt8],
            maxColors: Int,
        ) -> (palette: [(UInt8, UInt8, UInt8)], lookup: [Int]) {
            let bucketCount = histogramLevels * histogramLevels * histogramLevels
            var counts = [Int](repeating: 0, count: bucketCount)
            var index = 0
            while index + 3 < pixels.count {
                counts[bucketIndex(r: pixels[index], g: pixels[index + 1], b: pixels[index + 2])] += 1
                index += 4
            }
            var boxes: [[Int]] = [counts.indices.filter { counts[$0] > 0 }]
            guard !boxes[0].isEmpty else { return ([], []) }
            while boxes.count < maxColors {
                guard let splitIndex = widestSplittableBox(boxes, counts: counts),
                      let (head, tail) = splitBox(boxes[splitIndex], counts: counts)
                else {
                    break
                }
                boxes[splitIndex] = head
                boxes.append(tail)
            }
            var lookup = [Int](repeating: 0, count: bucketCount)
            var palette: [(UInt8, UInt8, UInt8)] = []
            for (boxIndex, box) in boxes.enumerated() {
                palette.append(centroid(of: box, counts: counts))
                for bucket in box {
                    lookup[bucket] = boxIndex
                }
            }
            return (palette, lookup)
        }

        private static func channelRanges(of box: [Int]) -> (r: Int, g: Int, b: Int) {
            var rMin = 31, rMax = 0, gMin = 31, gMax = 0, bMin = 31, bMax = 0
            for bucket in box {
                let r = (bucket >> 10) & 31, g = (bucket >> 5) & 31, b = bucket & 31
                rMin = min(rMin, r)
                rMax = max(rMax, r)
                gMin = min(gMin, g)
                gMax = max(gMax, g)
                bMin = min(bMin, b)
                bMax = max(bMax, b)
            }
            return (rMax - rMin, gMax - gMin, bMax - bMin)
        }

        private static func widestSplittableBox(_ boxes: [[Int]], counts: [Int]) -> Int? {
            var bestIndex: Int?
            var bestScore = 0
            for (index, box) in boxes.enumerated() where box.count > 1 {
                let ranges = channelRanges(of: box)
                let pixels = box.reduce(0) { $0 + counts[$1] }
                let score = (max(ranges.r, ranges.g, ranges.b) + 1) * pixels
                if score > bestScore {
                    bestScore = score
                    bestIndex = index
                }
            }
            return bestIndex
        }

        private static func splitBox(_ box: [Int], counts: [Int]) -> ([Int], [Int])? {
            let ranges = channelRanges(of: box)
            let channel = if ranges.r >= ranges.g, ranges.r >= ranges.b {
                0
            } else if ranges.g >= ranges.b {
                1
            } else {
                2
            }
            let sorted = box.sorted {
                channelValue($0, channel: channel) < channelValue($1, channel: channel)
            }
            let total = sorted.reduce(0) { $0 + counts[$1] }
            var running = 0
            for (position, bucket) in sorted.enumerated() {
                running += counts[bucket]
                if running >= (total + 1) / 2, position + 1 < sorted.count {
                    let splitPoint = position + 1
                    return (Array(sorted[..<splitPoint]), Array(sorted[splitPoint...]))
                }
            }
            return nil
        }

        private static func channelValue(_ bucket: Int, channel: Int) -> Int {
            switch channel {
            case 0: (bucket >> 10) & 31
            case 1: (bucket >> 5) & 31
            default: bucket & 31
            }
        }

        private static func centroid(of box: [Int], counts: [Int]) -> (UInt8, UInt8, UInt8) {
            var rSum = 0, gSum = 0, bSum = 0, total = 0
            for bucket in box {
                let count = counts[bucket]
                total += count
                // Bucket center restores the dropped low bits.
                rSum += (((bucket >> 10) & 31) * 8 + 4) * count
                gSum += (((bucket >> 5) & 31) * 8 + 4) * count
                bSum += ((bucket & 31) * 8 + 4) * count
            }
            guard total > 0 else { return (0, 0, 0) }
            return (UInt8(min(rSum / total, 255)), UInt8(min(gSum / total, 255)), UInt8(min(bSum / total, 255)))
        }

        private static func makeImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
            let data = Data(pixels)
            guard let provider = CGDataProvider(data: data as CFData) else { return nil }
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent,
            )
        }
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

//
//  HistoryThumbnailGenerator.swift
//  Notinhas
//
//  Lazy thumbnail generation and caching for capture history
//

import AppKit
import AVFoundation
import Foundation
import ImageIO
import os.log
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "Notinhas", category: "HistoryThumbnailGenerator")

/// Generates and caches thumbnails for capture history items
final class HistoryThumbnailGenerator {
    @MainActor static let shared = HistoryThumbnailGenerator()

    private let cacheVersion = "preview-v2"
    private let workerConfiguration: ThumbnailWorkerConfiguration
    private let workerQueue = DispatchQueue(
        label: "com.mourato.notinhas.history-thumbnail-generator.worker",
        qos: .utility,
        attributes: .concurrent,
    )
    private let thumbnailsDirectoryURL: URL
    private let state = HistoryThumbnailState()

    var thumbnailsDirectory: URL {
        thumbnailsDirectoryURL
    }

    init(thumbnailsDirectory: URL? = nil) {
        thumbnailsDirectoryURL = thumbnailsDirectory ?? Self.defaultThumbnailsDirectory()
        workerConfiguration = ThumbnailWorkerConfiguration(
            maxDimension: 208,
            compressionFactor: 0.58,
        )
        do {
            try workerQueue.sync {
                try FileManager.default.createDirectory(
                    at: thumbnailsDirectoryURL,
                    withIntermediateDirectories: true,
                )
            }
        } catch {
            DiagnosticLogger.shared.logError(.history, error, "History thumbnail directory creation failed")
        }
    }

    private static func defaultThumbnailsDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask,
        ).first!
        return appSupport
            .appendingPathComponent("Notinhas", isDirectory: true)
            .appendingPathComponent("HistoryThumbnails", isDirectory: true)
    }

    // MARK: - Public API

    func loadThumbnailImage(for record: CaptureHistoryRecord) async -> NSImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
            loadThumbnailImage(for: record) { image in
                continuation.resume(returning: image)
            }
        }
    }

    func loadThumbnailImage(
        for record: CaptureHistoryRecord,
        completion: @escaping @MainActor @Sendable (NSImage?) -> Void,
    ) {
        let identity = cacheIdentity(for: record)

        if let cachedImage = state.cachedImage(for: identity.cacheKey) {
            Self.deliver(cachedImage, to: completion)
            return
        }

        let shouldStartWork = state.enqueue(completion, for: identity.cacheKey)

        guard shouldStartWork else { return }

        let workerRecord = ThumbnailWorkerRecord(record: record)
        let workerConfigurationSnapshot = workerConfiguration
        let stateSnapshot = state
        workerQueue.async { [identity, stateSnapshot, workerConfigurationSnapshot, workerRecord] in
            let result = Self.resolveThumbnailImage(
                for: workerRecord,
                identity: identity,
                configuration: workerConfigurationSnapshot,
            )

            Task { @MainActor in
                let image = result.map { Self.makeNSImage(from: $0.image) }
                if let result {
                    stateSnapshot.storeInMemory(result.image, identity: identity, cost: result.cacheCost)
                }

                let completions = stateSnapshot.finish(for: identity.cacheKey)
                completions.forEach { $0(image) }
            }
        }
    }

    func preloadThumbnails(for records: [CaptureHistoryRecord]) {
        for record in records {
            loadThumbnailImage(for: record) { _ in }
        }
    }

    /// Generate a thumbnail for a history record and cache it to disk.
    /// Returns the cached thumbnail URL if successful.
    func generate(for record: CaptureHistoryRecord) async -> URL? {
        let identity = cacheIdentity(for: record)
        let workerRecord = ThumbnailWorkerRecord(record: record)
        let preferredURL = workerQueue.sync {
            Self.existingThumbnailURL(for: workerRecord, identity: identity)
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            loadThumbnailImage(for: record) { image in
                guard image != nil else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: preferredURL ?? identity.thumbnailURL)
            }
        }
    }

    /// Load a thumbnail from disk for a record
    func thumbnailURL(for record: CaptureHistoryRecord) -> URL? {
        let identity = cacheIdentity(for: record)
        let workerRecord = ThumbnailWorkerRecord(record: record)
        return workerQueue.sync {
            Self.existingThumbnailURL(for: workerRecord, identity: identity)
        }
    }

    /// Total size of all cached thumbnails in bytes
    func totalThumbnailSize() -> Int64 {
        let directoryURL = thumbnailsDirectoryURL
        return workerQueue.sync {
            Self.totalThumbnailSize(in: directoryURL)
        }
    }

    /// Delete all cached thumbnails and clear thumbnail paths in database
    func clearAllThumbnails() {
        let directoryURL = thumbnailsDirectoryURL
        let thumbnailCount = workerQueue.sync {
            Self.clearThumbnailFiles(in: directoryURL)
        }

        state.clearMemoryCache()

        // Clear all thumbnail paths in database
        DispatchQueue.main.async {
            CaptureHistoryStore.shared.clearAllThumbnailPaths()
            logger.info("All history thumbnails cleared")
            DiagnosticLogger.shared.log(
                .info,
                .history,
                "All history thumbnails cleared",
                context: ["thumbnailCount": "\(thumbnailCount)"],
            )
        }
    }

    /// Delete thumbnail for a specific record ID
    func deleteThumbnail(for recordId: UUID) {
        let directoryURL = thumbnailsDirectoryURL
        workerQueue.sync {
            Self.deleteThumbnailFiles(in: directoryURL, for: recordId)
        }
        state.removeMemoryCacheEntries(for: recordId)
    }

    // MARK: - Private

    private static func deliver(
        _ snapshot: ThumbnailImageSnapshot,
        to completion: @escaping @MainActor @Sendable (NSImage?) -> Void,
    ) {
        Task { @MainActor in
            completion(makeNSImage(from: snapshot))
        }
    }

    private static func makeNSImage(from snapshot: ThumbnailImageSnapshot) -> NSImage {
        NSImage(
            cgImage: snapshot.cgImage,
            size: NSSize(width: snapshot.cgImage.width, height: snapshot.cgImage.height),
        )
    }

    private nonisolated static func resolveThumbnailImage(
        for record: ThumbnailWorkerRecord,
        identity: ThumbnailCacheIdentity,
        configuration: ThumbnailWorkerConfiguration,
    ) -> GeneratedThumbnail? {
        if let cachedURL = existingThumbnailURL(for: record, identity: identity),
           let cachedImage = decodeThumbnail(at: cachedURL) {
            return GeneratedThumbnail(
                url: cachedURL,
                image: cachedImage,
                cacheCost: max(cachedImage.cgImage.width * cachedImage.cgImage.height * 4, 1),
            )
        }

        guard FileManager.default.fileExists(atPath: record.filePath) else {
            logger.debug("File missing, skipping thumbnail: \(record.fileName)")
            DiagnosticLogger.shared.log(
                .debug,
                .history,
                "History thumbnail skipped; source file missing",
                context: ["fileName": record.fileName, "type": record.captureType.rawValue],
            )
            return nil
        }

        let generatedThumbnail: GeneratedThumbnail? = switch record.captureType {
        case .screenshot, .gif:
            generateImageThumbnail(for: record, identity: identity, configuration: configuration)
        case .video:
            generateVideoThumbnail(for: record, identity: identity, configuration: configuration)
        }

        guard let generatedThumbnail else { return nil }

        DispatchQueue.main.async {
            CaptureHistoryStore.shared.updateThumbnailPath(id: record.id, path: generatedThumbnail.url.path)
        }

        return generatedThumbnail
    }

    private nonisolated static func generateImageThumbnail(
        for record: ThumbnailWorkerRecord,
        identity: ThumbnailCacheIdentity,
        configuration: ThumbnailWorkerConfiguration,
    ) -> GeneratedThumbnail? {
        let url = record.fileURL
        let scopedAccess = beginScopedAccess(for: url)
        defer { scopedAccess.stop() }

        guard let cgImage = downsampledImage(at: url, maxDimension: configuration.maxDimension) else {
            logger.warning("Failed to load image for thumbnail: \(record.fileName)")
            DiagnosticLogger.shared.log(
                .warning,
                .history,
                "History image thumbnail generation failed",
                context: ["fileName": record.fileName],
            )
            return nil
        }

        return saveThumbnail(cgImage, identity: identity, configuration: configuration)
    }

    private nonisolated static func generateVideoThumbnail(
        for record: ThumbnailWorkerRecord,
        identity: ThumbnailCacheIdentity,
        configuration: ThumbnailWorkerConfiguration,
    ) -> GeneratedThumbnail? {
        let url = record.fileURL
        let scopedAccess = beginScopedAccess(for: url)
        defer { scopedAccess.stop() }

        let asset = AVURLAsset(url: url)

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(
            width: configuration.maxDimension * 2,
            height: configuration.maxDimension * 2,
        )

        // Extract at mid-point or 1s, whichever is smaller
        let extractTime: TimeInterval = if let duration = record.duration, duration > 0 {
            min(duration / 2, 1.0)
        } else {
            0
        }

        let time = CMTimeMakeWithSeconds(extractTime, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return saveThumbnail(cgImage, identity: identity, configuration: configuration)
        } catch {
            logger.error("Failed to generate video thumbnail: \(error.localizedDescription)")
            DiagnosticLogger.shared.logError(
                .history,
                error,
                "History video thumbnail generation failed",
                context: ["fileName": record.fileName],
            )
            return nil
        }
    }

    /// Security-scoped access is owned by the MainActor service, while thumbnail
    /// decoding/generation remains on the history worker queue.
    private nonisolated static func beginScopedAccess(
        for url: URL,
    ) -> SandboxFileAccessManager.ScopedAccess {
        DispatchQueue.main.sync {
            SandboxFileAccessManager.shared.beginAccessingURL(url)
        }
    }

    private nonisolated static func existingThumbnailURL(
        for record: ThumbnailWorkerRecord,
        identity: ThumbnailCacheIdentity,
    ) -> URL? {
        let currentURL = identity.thumbnailURL

        if FileManager.default.fileExists(atPath: currentURL.path) {
            return currentURL
        }

        guard
            let storedURL = record.storedThumbnailURL,
            storedURL.lastPathComponent == currentURL.lastPathComponent,
            FileManager.default.fileExists(atPath: storedURL.path)
        else {
            return nil
        }

        return storedURL
    }

    private func cacheIdentity(for record: CaptureHistoryRecord) -> ThumbnailCacheIdentity {
        let capturedAtMs = Int64((record.capturedAt.timeIntervalSince1970 * 1000).rounded())
        let signature = "\(capturedAtMs)-\(record.fileSize)"
        let cacheKey = "\(record.id.uuidString)-\(cacheVersion)-\(signature)"
        return ThumbnailCacheIdentity(
            recordId: record.id,
            cacheKey: cacheKey,
            thumbnailURL: thumbnailsDirectoryURL.appendingPathComponent("\(cacheKey).jpg"),
        )
    }

    private static func totalThumbnailSize(in directoryURL: URL) -> Int64 {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
        ) else { return 0 }

        var total: Int64 = 0
        for url in contents {
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    private static func clearThumbnailFiles(in directoryURL: URL) -> Int {
        let fm = FileManager.default
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
            )
        } catch {
            DiagnosticLogger.shared.logError(.history, error, "History thumbnails clear failed to list directory")
            return 0
        }

        for url in contents {
            do {
                try fm.removeItem(at: url)
            } catch {
                DiagnosticLogger.shared.logError(
                    .history,
                    error,
                    "History thumbnail delete failed during clear all",
                    context: ["fileName": url.lastPathComponent],
                )
            }
        }

        return contents.count
    }

    private nonisolated static func deleteThumbnailFiles(
        in directoryURL: URL,
        for recordId: UUID,
        keeping keptURL: URL? = nil,
    ) {
        let prefix = "\(recordId.uuidString)-"
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
        )) ?? []

        for url in contents where url.lastPathComponent.hasPrefix(prefix) {
            if keptURL?.standardizedFileURL == url.standardizedFileURL {
                continue
            }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                DiagnosticLogger.shared.logError(
                    .history,
                    error,
                    "History thumbnail old cache delete failed",
                    context: ["fileName": url.lastPathComponent],
                )
            }
        }

        let legacyURL = directoryURL.appendingPathComponent("\(recordId.uuidString).jpg")
        if keptURL?.standardizedFileURL != legacyURL.standardizedFileURL {
            guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
            do {
                try FileManager.default.removeItem(at: legacyURL)
            } catch {
                DiagnosticLogger.shared.logError(
                    .history,
                    error,
                    "History thumbnail legacy cache delete failed",
                    context: ["fileName": legacyURL.lastPathComponent],
                )
            }
        }
    }

    private nonisolated static func downsampledImage(at url: URL, maxDimension: CGFloat) -> CGImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let maxPixelSize = Int(maxDimension * 2)
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary)
    }

    private nonisolated static func decodeThumbnail(at url: URL) -> ThumbnailImageSnapshot? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            return nil
        }

        return ThumbnailImageSnapshot(cgImage: cgImage)
    }

    private nonisolated static func saveThumbnail(
        _ image: CGImage,
        identity: ThumbnailCacheIdentity,
        configuration: ThumbnailWorkerConfiguration,
    ) -> GeneratedThumbnail? {
        let url = identity.thumbnailURL

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil,
        ) else {
            logger.warning("Failed to create thumbnail destination for \(identity.recordId)")
            DiagnosticLogger.shared.log(
                .warning,
                .history,
                "History thumbnail destination creation failed",
                context: ["recordId": identity.recordId.uuidString],
            )
            return nil
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: configuration.compressionFactor,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            logger.warning("Failed to encode thumbnail as JPEG for \(identity.recordId)")
            DiagnosticLogger.shared.log(
                .warning,
                .history,
                "History thumbnail JPEG encode failed",
                context: ["recordId": identity.recordId.uuidString],
            )
            return nil
        }

        deleteThumbnailFiles(in: url.deletingLastPathComponent(), for: identity.recordId, keeping: url)

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            return GeneratedThumbnail(
                url: url,
                image: ThumbnailImageSnapshot(cgImage: image),
                cacheCost: max(fileSize, 1),
            )
        } catch {
            logger.error("Failed to read thumbnail metadata: \(error.localizedDescription)")
            DiagnosticLogger.shared.logError(
                .history,
                error,
                "History thumbnail metadata read failed",
                context: ["recordId": identity.recordId.uuidString],
            )
            return nil
        }
    }
}

private struct ThumbnailCacheIdentity: Sendable {
    let recordId: UUID
    let cacheKey: String
    let thumbnailURL: URL
}

private struct ThumbnailWorkerConfiguration: Sendable {
    let maxDimension: CGFloat
    let compressionFactor: CGFloat
}

private struct ThumbnailWorkerRecord: Sendable {
    let id: UUID
    let filePath: String
    let fileName: String
    let captureType: ThumbnailCaptureType
    let fileSize: Int64
    let duration: TimeInterval?
    let storedThumbnailURL: URL?

    init(record: CaptureHistoryRecord) {
        id = record.id
        filePath = record.filePath
        fileName = record.fileName
        captureType = ThumbnailCaptureType(record.captureType)
        fileSize = record.fileSize
        duration = record.duration
        storedThumbnailURL = record.thumbnailPath.map { URL(fileURLWithPath: $0) }
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}

private enum ThumbnailCaptureType: Sendable {
    case screenshot
    case video
    case gif

    init(_ captureType: CaptureHistoryType) {
        switch captureType {
        case .screenshot:
            self = .screenshot
        case .video:
            self = .video
        case .gif:
            self = .gif
        }
    }

    var rawValue: String {
        switch self {
        case .screenshot:
            "screenshot"
        case .video:
            "video"
        case .gif:
            "gif"
        }
    }
}

private struct GeneratedThumbnail: Sendable {
    let url: URL
    let image: ThumbnailImageSnapshot
    let cacheCost: Int
}

/// An immutable ImageIO/AVFoundation result transferred to the MainActor before
/// an AppKit NSImage is created. The CGImage is never mutated after creation.
private final class ThumbnailImageSnapshot: Sendable {
    let cgImage: CGImage

    init(cgImage: CGImage) {
        self.cgImage = cgImage
    }
}

/// A lock protects the memory cache, cache-key index, and in-flight completion
/// lists. Workers never capture the generator or access these values directly.
private final class HistoryThumbnailState: @unchecked Sendable {
    private let lock = NSLock()
    private let memoryCache = NSCache<NSString, ThumbnailImageSnapshot>()
    private var inFlightRequests: [String: [@MainActor @Sendable (NSImage?) -> Void]] = [:]
    private var memoryCacheKeysByRecordId: [UUID: Set<String>] = [:]

    init() {
        memoryCache.countLimit = 160
        memoryCache.totalCostLimit = 48 * 1024 * 1024
    }

    func cachedImage(for cacheKey: String) -> ThumbnailImageSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return memoryCache.object(forKey: NSString(string: cacheKey))
    }

    func enqueue(
        _ completion: @escaping @MainActor @Sendable (NSImage?) -> Void,
        for cacheKey: String,
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if inFlightRequests[cacheKey] != nil {
            inFlightRequests[cacheKey]?.append(completion)
            return false
        }

        inFlightRequests[cacheKey] = [completion]
        return true
    }

    func finish(for cacheKey: String) -> [@MainActor @Sendable (NSImage?) -> Void] {
        lock.lock()
        defer { lock.unlock() }
        return inFlightRequests.removeValue(forKey: cacheKey) ?? []
    }

    func storeInMemory(_ image: ThumbnailImageSnapshot, identity: ThumbnailCacheIdentity, cost: Int) {
        lock.lock()
        defer { lock.unlock() }

        memoryCache.setObject(image, forKey: NSString(string: identity.cacheKey), cost: cost)
        var keys = memoryCacheKeysByRecordId[identity.recordId] ?? []
        keys.insert(identity.cacheKey)
        memoryCacheKeysByRecordId[identity.recordId] = keys
    }

    func clearMemoryCache() {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.removeAllObjects()
    }

    func removeMemoryCacheEntries(for recordId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        let keys = memoryCacheKeysByRecordId.removeValue(forKey: recordId) ?? []
        for key in keys {
            memoryCache.removeObject(forKey: NSString(string: key))
        }
    }
}

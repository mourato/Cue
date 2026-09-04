//
//  SystemWallpaperManager.swift
//  Notinhas
//
//  Service to load bundled default wallpapers and cache wallpaper previews
//

import AppKit
import Combine
import Foundation

struct WallpaperImageSnapshot: Sendable {
    let cgImage: CGImage
}

@MainActor
class SystemWallpaperManager: ObservableObject {
    static let shared = SystemWallpaperManager()

    enum SettingsPreviewImageLoadTestEvent: Sendable {
        case requestAdmitted
        case snapshotCreationStarted
    }

    static var settingsPreviewImageLoadTestHook: (@Sendable (SettingsPreviewImageLoadTestEvent) async -> Void)?

    private struct PreviewImageRequestKey: Hashable {
        let url: URL
        let maxPixelSize: CGFloat

        init(url: URL, maxPixelSize: CGFloat) {
            self.url = url.standardizedFileURL
            self.maxPixelSize = maxPixelSize
        }
    }

    private struct PendingPreviewImageRequest {
        let id: UUID
        let task: Task<WallpaperImageSnapshot?, Never>
    }

    private static var settingsPreviewImageCache: [PreviewImageRequestKey: NSImage] = [:]
    private static var pendingSettingsPreviewImageRequests: [PreviewImageRequestKey: PendingPreviewImageRequest] = [:]
    private static let settingsPreviewImageCacheLimit = 20

    @Published var defaultWallpapers: [WallpaperItem] = []
    @Published var customWallpapers: [WallpaperItem] = []
    @Published var isLoading = false
    @Published var accessDenied = false

    // MARK: - Thumbnail Cache (Performance Optimization)

    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let thumbnailSize: CGFloat = 96 // 48pt grid item @2x retina
    private var loadingURLs = Set<URL>()
    private var pendingThumbnailCompletions: [URL: [(NSImage?) -> Void]] = [:]

    // MARK: - Preview Cache (Canvas Display Optimization)

    private let previewCache = NSCache<NSURL, NSImage>()

    /// Preview size from config (default 2048px for retina 1024pt)
    private var previewSize: CGFloat {
        WallpaperQualityConfig.maxResolution
    }

    private let bundledWallpaperSubdirectories = [
        "Wallpapers",
        "Resources/Wallpapers",
    ]
    private let customWallpaperBookmarkKey = PreferencesKeys.customWallpaperBookmarks
    private var customWallpaperBookmarkEntries: [CustomWallpaperBookmarkEntry] = []

    private let bundledDefaultWallpapers: [BundledWallpaperResource] = [
        BundledWallpaperResource(fileName: "default-abstract-blue.jpg", displayName: "Abstract Blue"),
        BundledWallpaperResource(fileName: "default-abstract-amber.jpg", displayName: "Abstract Amber"),
        BundledWallpaperResource(fileName: "default-abstract-cyan.jpg", displayName: "Abstract Cyan"),
        BundledWallpaperResource(fileName: "default-abstract-magenta.jpg", displayName: "Abstract Magenta"),
        BundledWallpaperResource(fileName: "default-abstract-violet.jpg", displayName: "Abstract Violet"),
        BundledWallpaperResource(fileName: "default-helios-dark.jpg", displayName: "Helios Dark"),
        BundledWallpaperResource(fileName: "default-macbook-pro-blue.jpg", displayName: "MacBook Pro Blue"),
        BundledWallpaperResource(fileName: "default-macbook-pro-m3.jpg", displayName: "MacBook Pro M3"),
        BundledWallpaperResource(fileName: "default-macintosh-dark.jpg", displayName: "Macintosh Dark"),
        BundledWallpaperResource(fileName: "default-macintosh-light.jpg", displayName: "Macintosh Light"),
        BundledWallpaperResource(fileName: "default-tahoe-dark.jpg", displayName: "Tahoe Dark"),
        BundledWallpaperResource(fileName: "default-tahoe-light.jpg", displayName: "Tahoe Light"),
    ]

    private struct BundledWallpaperResource {
        let fileName: String
        let displayName: String

        var resourceName: String {
            (fileName as NSString).deletingPathExtension
        }

        var fileExtension: String {
            (fileName as NSString).pathExtension
        }
    }

    private struct CustomWallpaperBookmarkEntry: Codable, Equatable {
        let bookmarkData: Data
    }

    struct WallpaperItem: Identifiable, Hashable {
        var id: URL {
            fullImageURL
        }

        let fullImageURL: URL
        let thumbnailURL: URL?
        let name: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(fullImageURL)
        }

        static func == (lhs: WallpaperItem, rhs: WallpaperItem) -> Bool {
            lhs.fullImageURL == rhs.fullImageURL
        }
    }

    private init() {
        // Configure cache limits
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB max

        // Preview cache: fewer items but larger (2048px images ~4MB each)
        previewCache.countLimit = 20
        previewCache.totalCostLimit = 100 * 1024 * 1024 // 100MB max

        loadCustomWallpapers()
    }

    // MARK: - Custom Wallpaper Persistence

    @discardableResult
    func addCustomWallpaper(_ url: URL) -> WallpaperItem? {
        let normalizedURL = url.standardizedFileURL

        if let existing = customWallpapers.first(where: { $0.fullImageURL.standardizedFileURL == normalizedURL }) {
            return existing
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: normalizedURL.path) else {
            return nil
        }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil,
            )
            var isStale = false
            let scopedURL = (try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale,
            ).standardizedFileURL) ?? normalizedURL
            let item = WallpaperItem(
                fullImageURL: scopedURL,
                thumbnailURL: nil,
                name: wallpaperName(for: scopedURL),
            )

            customWallpaperBookmarkEntries.append(CustomWallpaperBookmarkEntry(bookmarkData: bookmarkData))
            customWallpapers.append(item)
            saveCustomWallpaperBookmarks()
            preloadThumbnails(for: [item])
            return item
        } catch {
            return nil
        }
    }

    func removeCustomWallpaper(_ item: WallpaperItem) {
        guard let index = customWallpapers.firstIndex(of: item) else {
            return
        }

        let url = item.fullImageURL
        customWallpapers.remove(at: index)
        if customWallpaperBookmarkEntries.indices.contains(index) {
            customWallpaperBookmarkEntries.remove(at: index)
        }

        thumbnailCache.removeObject(forKey: url as NSURL)
        previewCache.removeObject(forKey: url as NSURL)
        saveCustomWallpaperBookmarks()
    }

    private func loadCustomWallpapers() {
        guard let data = UserDefaults.standard.data(forKey: customWallpaperBookmarkKey),
              let decodedEntries = try? JSONDecoder().decode([CustomWallpaperBookmarkEntry].self, from: data) else {
            return
        }

        var resolvedEntries: [CustomWallpaperBookmarkEntry] = []
        var resolvedWallpapers: [WallpaperItem] = []
        var seenURLs = Set<URL>()

        for entry in decodedEntries {
            var isStale = false

            guard let resolvedURL = try? URL(
                resolvingBookmarkData: entry.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale,
            ).standardizedFileURL else {
                continue
            }

            guard seenURLs.insert(resolvedURL).inserted else {
                continue
            }

            let fileExists = Self.withSecurityScopedAccess(to: resolvedURL) {
                FileManager.default.fileExists(atPath: resolvedURL.path)
            }

            guard fileExists else {
                continue
            }

            var bookmarkEntry = entry
            if isStale,
               let refreshedBookmarkData = try? Self.withSecurityScopedAccess(to: resolvedURL, {
                   try resolvedURL.bookmarkData(
                       options: .withSecurityScope,
                       includingResourceValuesForKeys: nil,
                       relativeTo: nil,
                   )
               }) {
                bookmarkEntry = CustomWallpaperBookmarkEntry(bookmarkData: refreshedBookmarkData)
            }

            resolvedEntries.append(bookmarkEntry)
            resolvedWallpapers.append(
                WallpaperItem(
                    fullImageURL: resolvedURL,
                    thumbnailURL: nil,
                    name: wallpaperName(for: resolvedURL),
                ),
            )
        }

        customWallpaperBookmarkEntries = resolvedEntries
        customWallpapers = resolvedWallpapers

        if resolvedEntries != decodedEntries {
            saveCustomWallpaperBookmarks()
        }

        preloadThumbnails(for: resolvedWallpapers)
    }

    private func saveCustomWallpaperBookmarks() {
        guard !customWallpaperBookmarkEntries.isEmpty else {
            UserDefaults.standard.removeObject(forKey: customWallpaperBookmarkKey)
            return
        }

        if let data = try? JSONEncoder().encode(customWallpaperBookmarkEntries) {
            UserDefaults.standard.set(data, forKey: customWallpaperBookmarkKey)
        }
    }

    private func wallpaperName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private nonisolated static func withSecurityScopedAccess<T>(
        to url: URL,
        _ operation: () throws -> T,
    ) rethrows -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    // MARK: - Cached Thumbnail Access

    /// Get cached thumbnail or nil if not yet loaded
    func cachedThumbnail(for url: URL) -> NSImage? {
        thumbnailCache.object(forKey: url as NSURL)
    }

    /// Load and cache thumbnail with downsampling (async, non-blocking)
    func loadThumbnail(for item: WallpaperItem, completion: @escaping (NSImage?) -> Void) {
        let url = item.thumbnailURL ?? item.fullImageURL

        // Check cache first
        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        // Prevent duplicate loads while preserving every caller's callback.
        guard !loadingURLs.contains(url) else {
            pendingThumbnailCompletions[url, default: []].append(completion)
            return
        }

        loadingURLs.insert(url)
        pendingThumbnailCompletions[url] = [completion]
        let maxSize = thumbnailSize

        // Load and downsample on background thread
        DispatchQueue.global(qos: .userInitiated).async { [url, maxSize] in
            let snapshot = Self.createDownsampledImageSnapshot(from: url, maxSize: maxSize)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let thumbnail = snapshot.map(Self.makeImage)
                if let thumbnail {
                    thumbnailCache.setObject(thumbnail, forKey: url as NSURL)
                }

                let completions = pendingThumbnailCompletions.removeValue(forKey: url) ?? []
                loadingURLs.remove(url)
                completions.forEach { $0(thumbnail) }
            }
        }
    }

    /// Create downsampled image using ImageIO (memory efficient)
    /// - Parameters:
    ///   - url: Source image URL
    ///   - maxSize: Maximum pixel dimension for the output
    nonisolated static func createDownsampledImageSnapshot(
        from url: URL,
        maxSize: CGFloat,
    ) -> WallpaperImageSnapshot? {
        withSecurityScopedAccess(to: url) {
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
            ]

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
                return nil
            }

            // Get source image dimensions to avoid requesting thumbnail larger than source
            // This prevents "kCGImageSourceThumbnailMaxPixelSize is larger than image-dimension" warnings
            var effectiveMaxSize = maxSize
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
               let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
               let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
                let sourceMaxDimension = max(width, height)
                effectiveMaxSize = min(maxSize, sourceMaxDimension)
            }

            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: effectiveMaxSize,
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary)
            else {
                return nil
            }

            return WallpaperImageSnapshot(cgImage: cgImage)
        }
    }

    @MainActor
    static func makeImage(from snapshot: WallpaperImageSnapshot) -> NSImage {
        NSImage(
            cgImage: snapshot.cgImage,
            size: NSSize(width: snapshot.cgImage.width, height: snapshot.cgImage.height),
        )
    }

    /// Downsampled image for small Settings previews (e.g. Quick Access thumbnails).
    /// The ImageIO snapshot is created off the main thread; the NSImage is built on it.
    /// - Parameters:
    ///   - url: Source image URL
    ///   - maxPixelSize: Maximum pixel dimension for the output
    @MainActor
    static func downsampledPreviewImage(at url: URL, maxPixelSize: CGFloat) async -> NSImage? {
        let key = PreviewImageRequestKey(url: url, maxPixelSize: maxPixelSize)
        if let cached = settingsPreviewImageCache[key] {
            return cached
        }

        let testHook = settingsPreviewImageLoadTestHook
        let request: PendingPreviewImageRequest
        if let pending = pendingSettingsPreviewImageRequests[key] {
            request = pending
        } else {
            let id = UUID()
            let task = Task.detached(priority: .userInitiated) { [
                url = key.url,
                maxPixelSize = key.maxPixelSize,
                testHook,
            ] in
                await testHook?(.snapshotCreationStarted)
                return createDownsampledImageSnapshot(from: url, maxSize: maxPixelSize)
            }
            request = PendingPreviewImageRequest(id: id, task: task)
            pendingSettingsPreviewImageRequests[key] = request
        }

        await testHook?(.requestAdmitted)
        let snapshot = await request.task.value
        if pendingSettingsPreviewImageRequests[key]?.id == request.id {
            pendingSettingsPreviewImageRequests.removeValue(forKey: key)
        }

        if let cached = settingsPreviewImageCache[key] {
            return cached
        }
        guard let snapshot else { return nil }

        let image = makeImage(from: snapshot)
        if settingsPreviewImageCache.count >= settingsPreviewImageCacheLimit {
            settingsPreviewImageCache.removeAll(keepingCapacity: true)
        }
        settingsPreviewImageCache[key] = image
        return image
    }

    // MARK: - Preview Image Loading (Canvas Display)

    /// Load preview-sized image for canvas display (2048px max dimension)
    /// Uses ImageIO downsampling for memory efficiency (~4MB vs 50MB+ full-res)
    func loadPreviewImage(for url: URL, completion: @escaping @MainActor @Sendable (NSImage?) -> Void) {
        // Check cache first
        if let cached = previewCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        // Load and downsample on background thread
        let maxSize = previewSize
        DispatchQueue.global(qos: .userInitiated).async { [url, maxSize] in
            let snapshot = Self.createDownsampledImageSnapshot(from: url, maxSize: maxSize)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let preview = snapshot.map(Self.makeImage)
                if let preview {
                    previewCache.setObject(preview, forKey: url as NSURL)
                }
                completion(preview)
            }
        }
    }

    /// Preload visible thumbnails (call when view appears)
    func preloadThumbnails(for items: [WallpaperItem]) {
        for item in items.prefix(12) { // Keep preloading lightweight while covering bundled defaults
            loadThumbnail(for: item) { _ in }
        }
    }

    @MainActor
    func loadDefaultWallpapers() async {
        guard !isLoading else { return }
        guard defaultWallpapers.isEmpty else { return } // Only load once
        isLoading = true
        accessDenied = false

        let wallpapers = enumerateBundledDefaultWallpapers()
        defaultWallpapers = wallpapers
        accessDenied = wallpapers.isEmpty
        isLoading = false

        // Preload first batch of thumbnails
        preloadThumbnails(for: wallpapers)
    }

    private func enumerateBundledDefaultWallpapers() -> [WallpaperItem] {
        bundledDefaultWallpapers.compactMap { resource in
            guard let url = resolveBundledWallpaperURL(resource) else {
                return nil
            }

            return WallpaperItem(
                fullImageURL: url,
                thumbnailURL: nil,
                name: resource.displayName,
            )
        }
    }

    private func resolveBundledWallpaperURL(_ resource: BundledWallpaperResource) -> URL? {
        let fm = FileManager.default

        for subdirectory in bundledWallpaperSubdirectories {
            if let url = Bundle.main.url(
                forResource: resource.resourceName,
                withExtension: resource.fileExtension,
                subdirectory: subdirectory,
            ) {
                return url
            }

            if let url = Bundle.main.resourceURL?
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(resource.fileName),
                fm.fileExists(atPath: url.path) {
                return url
            }
        }

        if let url = Bundle.main.url(
            forResource: resource.resourceName,
            withExtension: resource.fileExtension,
        ) {
            return url
        }

        if let url = Bundle.main.resourceURL?
            .appendingPathComponent(resource.fileName),
            fm.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }
}

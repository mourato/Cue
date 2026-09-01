#if CUE_VIDEO_MODULE
//
    //  VideoEditorRenderCacheStore.swift
    //  Notinhas
//
    //  Bounded render cache keyed by canonical recipe (Plan 110 / Phase D).
//

    import AVFoundation
    import Foundation

    struct VideoEditorRenderCacheManifest: Codable, Equatable, Sendable {
        static let schemaVersion = 1

        var schemaVersion: Int
        var cacheKey: String
        var sourceFingerprint: String
        var recipe: VideoEditorRenderRecipe
        var outputExtension: String
        var byteSize: Int64
        var createdAt: Date
        var lastUsedAt: Date
    }

    enum VideoEditorRenderCacheStore {
        private static let rootFolderName = "VideoRenderCache"
        private static let manifestFileName = "render-recipe.json"
        private static let renderFileName = "render"

        static func cacheRoot(in fileManager: FileManager = .default) throws -> URL {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )
            let root = support
                .appendingPathComponent(CueStoragePaths.destinationAppSupportFolderName, isDirectory: true)
                .appendingPathComponent(rootFolderName, isDirectory: true)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            return root
        }

        static func entryDirectory(
            for cacheKey: String,
            fileManager: FileManager = .default,
            cacheRoot overrideRoot: URL? = nil,
        ) throws -> URL {
            let root = try overrideRoot ?? cacheRoot(in: fileManager)
            guard !cacheKey.contains("/"), !cacheKey.contains("..") else {
                throw CacheError.invalidKey
            }
            return root.appendingPathComponent(cacheKey, isDirectory: true)
        }

        static func lookup(
            cacheKey: String,
            sourceFingerprint: String,
            recipe: VideoEditorRenderRecipe,
            fileManager: FileManager = .default,
            cacheRoot overrideRoot: URL? = nil,
        ) -> URL? {
            guard let entry = try? entryDirectory(for: cacheKey, fileManager: fileManager, cacheRoot: overrideRoot),
                  let manifest = loadManifest(from: entry, fileManager: fileManager),
                  manifest.sourceFingerprint == sourceFingerprint,
                  manifest.recipe == recipe,
                  let renderURL = existingRenderURL(
                      in: entry,
                      extension: manifest.outputExtension,
                      fileManager: fileManager,
                  ),
                  isPlayableAsset(at: renderURL) else {
                return nil
            }
            touch(manifest: manifest, in: entry, fileManager: fileManager)
            return renderURL
        }

        static func store(
            renderedFile: URL,
            cacheKey: String,
            sourceFingerprint: String,
            recipe: VideoEditorRenderRecipe,
            fileManager: FileManager = .default,
            cacheRoot overrideRoot: URL? = nil,
        ) throws {
            let entry = try entryDirectory(for: cacheKey, fileManager: fileManager, cacheRoot: overrideRoot)
            try fileManager.createDirectory(at: entry, withIntermediateDirectories: true)

            let ext = renderedFile.pathExtension.isEmpty ? "mov" : renderedFile.pathExtension
            let destination = entry.appendingPathComponent("\(renderFileName).\(ext)")
            let tempDestination = entry.appendingPathComponent(".\(renderFileName).\(ext).tmp")

            if fileManager.fileExists(atPath: tempDestination.path) {
                try fileManager.removeItem(at: tempDestination)
            }
            try fileManager.copyItem(at: renderedFile, to: tempDestination)

            let attributes = try fileManager.attributesOfItem(atPath: tempDestination.path)
            let byteSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let now = Date()
            let manifest = VideoEditorRenderCacheManifest(
                schemaVersion: VideoEditorRenderCacheManifest.schemaVersion,
                cacheKey: cacheKey,
                sourceFingerprint: sourceFingerprint,
                recipe: recipe,
                outputExtension: ext,
                byteSize: byteSize,
                createdAt: now,
                lastUsedAt: now,
            )

            let manifestURL = entry.appendingPathComponent(manifestFileName)
            let tempManifestURL = entry.appendingPathComponent(".\(manifestFileName).tmp")
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: tempManifestURL, options: .atomic)
            _ = try fileManager.replaceItemAt(manifestURL, withItemAt: tempManifestURL)

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            _ = try fileManager.replaceItemAt(destination, withItemAt: tempDestination)
        }

        private static func loadManifest(from entry: URL,
                                         fileManager _: FileManager) -> VideoEditorRenderCacheManifest? {
            let manifestURL = entry.appendingPathComponent(manifestFileName)
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(VideoEditorRenderCacheManifest.self, from: data),
                  manifest.schemaVersion == VideoEditorRenderCacheManifest.schemaVersion else {
                return nil
            }
            return manifest
        }

        private static func existingRenderURL(in entry: URL, extension ext: String, fileManager: FileManager) -> URL? {
            let url = entry.appendingPathComponent("\(renderFileName).\(ext)")
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }

        private static func isPlayableAsset(at url: URL) -> Bool {
            let asset = AVURLAsset(url: url)
            return CMTimeGetSeconds(asset.duration) > 0
        }

        private static func touch(manifest: VideoEditorRenderCacheManifest, in entry: URL, fileManager _: FileManager) {
            var updated = manifest
            updated.lastUsedAt = Date()
            let manifestURL = entry.appendingPathComponent(manifestFileName)
            guard let data = try? JSONEncoder().encode(updated) else { return }
            try? data.write(to: manifestURL, options: .atomic)
        }

        enum CacheError: Error {
            case invalidKey
        }
    }
#endif

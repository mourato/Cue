#if CUE_VIDEO_MODULE
//
    //  RecordingMetadata.swift
    //  Notinhas
//
    //  Internal metadata for recordings that need editor-only context.
//

    import CoreGraphics
    import Foundation
    import os.log

    private let recordingMetadataLogger = Logger(subsystem: "Cue", category: "RecordingMetadata")

    struct RecordedPointerArtwork: Codable, Equatable, Sendable {
        struct Point: Codable, Equatable, Sendable {
            var x: Double
            var y: Double
        }

        struct Size: Codable, Equatable, Sendable {
            var width: Double
            var height: Double
        }

        var artworkID: String
        var imageData: Data
        var anchorPoint: Point
        var referenceSize: Size
    }

    struct RecordedMouseSample: Codable, Equatable {
        var time: TimeInterval
        var normalizedX: CGFloat
        var normalizedY: CGFloat
        var isInsideCapture: Bool
        var artworkID: String?

        var normalizedPoint: CGPoint {
            CGPoint(x: normalizedX, y: normalizedY)
        }
    }

    struct RecordedKeystrokeEvent: Codable, Equatable {
        var time: TimeInterval
        var modifiers: [String]
        var key: String
    }

    struct RecordedMousePress: Codable, Equatable {
        enum PressPhase: String, Codable {
            case down
            case up
        }

        var time: TimeInterval
        var normalizedX: CGFloat
        var normalizedY: CGFloat
        var button: Int
        var phase: PressPhase
        var artworkID: String?

        var normalizedPoint: CGPoint {
            CGPoint(x: normalizedX, y: normalizedY)
        }
    }

    enum RecordingCoordinateSpace: String, Codable {
        case bottomLeftNormalized
        case topLeftNormalized
    }

    enum RecordingAudioSourceTrackRole: String, Codable, Equatable {
        case systemAudio
        case microphone

        static func roles(capturesSystemAudio: Bool, capturesMicrophone: Bool) -> [RecordingAudioSourceTrackRole] {
            var roles: [RecordingAudioSourceTrackRole] = []
            if capturesSystemAudio {
                roles.append(.systemAudio)
            }
            if capturesMicrophone {
                roles.append(.microphone)
            }
            return roles
        }
    }

    struct RecordingAudioSourceTrack: Codable, Equatable {
        var trackID: Int
        var role: RecordingAudioSourceTrackRole
    }

    enum RecordingVideoSourceTrackRole: String, Codable, Equatable {
        case screen
        case camera
    }

    struct RecordingVideoSourceTrack: Codable, Equatable {
        var trackID: Int
        var role: RecordingVideoSourceTrackRole
        var captureSize: CGSize?
        var isMirrored: Bool

        init(trackID: Int, role: RecordingVideoSourceTrackRole, captureSize: CGSize? = nil, isMirrored: Bool = false) {
            self.trackID = trackID
            self.role = role
            self.captureSize = captureSize
            self.isMirrored = isMirrored
        }
    }

    struct RecordedCameraOverlayLayout: Codable, Equatable, Sendable {
        var normalizedRect: CGRect
        var shape: RecordingCameraPreviewShape
        var size: RecordingCameraPreviewSize?

        init(
            normalizedRect: CGRect,
            shape: RecordingCameraPreviewShape,
            size: RecordingCameraPreviewSize? = nil,
        ) {
            self.normalizedRect = normalizedRect
            self.shape = shape
            self.size = size
        }
    }

    struct RecordingMetadata: Codable, Equatable {
        static let currentVersion = 11

        var version: Int
        var coordinateSpace: RecordingCoordinateSpace
        var captureSize: CGSize
        var samplesPerSecond: Int
        var mouseSamples: [RecordedMouseSample]
        var mousePresses: [RecordedMousePress]
        var pointerArtwork: [RecordedPointerArtwork]
        var pointerSynthesized: Bool?
        var keystrokes: [RecordedKeystrokeEvent]
        var audioSourceURL: URL?
        var audioSourceTrackRoles: [RecordingAudioSourceTrackRole]
        var audioSourceTracks: [RecordingAudioSourceTrack]
        var videoSourceTracks: [RecordingVideoSourceTrack]
        var cameraOverlayLayout: RecordedCameraOverlayLayout?
        var clickHighlightsWereBaked: Bool?
        var keystrokesWereBaked: Bool?

        init(
            version: Int = RecordingMetadata.currentVersion,
            coordinateSpace: RecordingCoordinateSpace = .topLeftNormalized,
            captureSize: CGSize,
            samplesPerSecond: Int,
            mouseSamples: [RecordedMouseSample],
            mousePresses: [RecordedMousePress] = [],
            pointerArtwork: [RecordedPointerArtwork] = [],
            pointerSynthesized: Bool? = nil,
            keystrokes: [RecordedKeystrokeEvent] = [],
            audioSourceURL: URL? = nil,
            audioSourceTrackRoles: [RecordingAudioSourceTrackRole] = [],
            audioSourceTracks: [RecordingAudioSourceTrack] = [],
            videoSourceTracks: [RecordingVideoSourceTrack] = [],
            cameraOverlayLayout: RecordedCameraOverlayLayout? = nil,
            clickHighlightsWereBaked: Bool? = nil,
            keystrokesWereBaked: Bool? = nil,
        ) {
            self.version = version
            self.coordinateSpace = coordinateSpace
            self.captureSize = captureSize
            self.samplesPerSecond = samplesPerSecond
            self.mouseSamples = mouseSamples
            self.mousePresses = mousePresses
            self.pointerArtwork = pointerArtwork
            self.pointerSynthesized = pointerSynthesized
            self.keystrokes = keystrokes
            self.audioSourceURL = audioSourceURL
            self.audioSourceTrackRoles = audioSourceTrackRoles
            self.audioSourceTracks = audioSourceTracks
            self.videoSourceTracks = videoSourceTracks
            self.cameraOverlayLayout = cameraOverlayLayout
            self.clickHighlightsWereBaked = clickHighlightsWereBaked
            self.keystrokesWereBaked = keystrokesWereBaked
        }

        private enum CodingKeys: String, CodingKey {
            case version
            case coordinateSpace
            case captureSize
            case samplesPerSecond
            case mouseSamples
            case mousePresses
            case pointerArtwork
            case pointerSynthesized
            case keystrokes
            case audioSourceURL
            case audioSourceTrackRoles
            case audioSourceTracks
            case videoSourceTracks
            case cameraOverlayLayout
            case clickHighlightsWereBaked
            case keystrokesWereBaked
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            let decodedCoordinateSpace = try container.decodeIfPresent(
                RecordingCoordinateSpace.self,
                forKey: .coordinateSpace,
            )

            version = decodedVersion
            coordinateSpace = decodedCoordinateSpace ?? (
                decodedVersion >= 2
                    ? .topLeftNormalized
                    : .bottomLeftNormalized
            )
            captureSize = try container.decode(CGSize.self, forKey: .captureSize)
            samplesPerSecond = try container.decode(Int.self, forKey: .samplesPerSecond)
            mouseSamples = try container.decode([RecordedMouseSample].self, forKey: .mouseSamples)
            mousePresses = try container.decodeIfPresent([RecordedMousePress].self, forKey: .mousePresses) ?? []
            pointerArtwork = try container.decodeIfPresent([RecordedPointerArtwork].self, forKey: .pointerArtwork) ?? []
            pointerSynthesized = try container.decodeIfPresent(Bool.self, forKey: .pointerSynthesized)
            keystrokes = try container.decodeIfPresent([RecordedKeystrokeEvent].self, forKey: .keystrokes) ?? []
            audioSourceURL = try container.decodeIfPresent(URL.self, forKey: .audioSourceURL)
            audioSourceTrackRoles = try container.decodeIfPresent(
                [RecordingAudioSourceTrackRole].self,
                forKey: .audioSourceTrackRoles,
            ) ?? []
            audioSourceTracks = try container.decodeIfPresent(
                [RecordingAudioSourceTrack].self,
                forKey: .audioSourceTracks,
            ) ?? []
            videoSourceTracks = try container.decodeIfPresent(
                [RecordingVideoSourceTrack].self,
                forKey: .videoSourceTracks,
            ) ?? []
            cameraOverlayLayout = try container.decodeIfPresent(
                RecordedCameraOverlayLayout.self,
                forKey: .cameraOverlayLayout,
            )
            clickHighlightsWereBaked = try container.decodeIfPresent(Bool.self, forKey: .clickHighlightsWereBaked)
            keystrokesWereBaked = try container.decodeIfPresent(Bool.self, forKey: .keystrokesWereBaked)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(version, forKey: .version)
            try container.encode(coordinateSpace, forKey: .coordinateSpace)
            try container.encode(captureSize, forKey: .captureSize)
            try container.encode(samplesPerSecond, forKey: .samplesPerSecond)
            try container.encode(mouseSamples, forKey: .mouseSamples)
            if !mousePresses.isEmpty {
                try container.encode(mousePresses, forKey: .mousePresses)
            }
            if !pointerArtwork.isEmpty {
                try container.encode(pointerArtwork, forKey: .pointerArtwork)
            }
            try container.encodeIfPresent(pointerSynthesized, forKey: .pointerSynthesized)
            if !keystrokes.isEmpty {
                try container.encode(keystrokes, forKey: .keystrokes)
            }
            try container.encodeIfPresent(audioSourceURL, forKey: .audioSourceURL)
            if !audioSourceTrackRoles.isEmpty {
                try container.encode(audioSourceTrackRoles, forKey: .audioSourceTrackRoles)
            }
            if !audioSourceTracks.isEmpty {
                try container.encode(audioSourceTracks, forKey: .audioSourceTracks)
            }
            if !videoSourceTracks.isEmpty {
                try container.encode(videoSourceTracks, forKey: .videoSourceTracks)
            }
            try container.encodeIfPresent(cameraOverlayLayout, forKey: .cameraOverlayLayout)
            try container.encodeIfPresent(clickHighlightsWereBaked, forKey: .clickHighlightsWereBaked)
            try container.encodeIfPresent(keystrokesWereBaked, forKey: .keystrokesWereBaked)
        }
    }

    @MainActor
    enum RecordingMetadataStore {
        private struct StoreLocation {
            let entriesURL: URL
            let indexURL: URL
            let audioSourcesURL: URL
        }

        private struct MetadataIndex: Codable {
            var entries: [MetadataIndexEntry] = []
        }

        private struct MetadataIndexEntry: Codable, Equatable {
            var id: UUID
            var lastKnownPath: String
            var bookmarkData: Data
            var staleSince: Date?
        }

        private enum CleanupDisposition {
            case keep(MetadataIndexEntry)
            case delete
        }

        private nonisolated static let appSupportFolderName = CueStoragePaths.destinationAppSupportFolderName
        private nonisolated static let capturesFolderName = "Captures"
        private nonisolated static let storeFolderName = "RecordingMetadata"
        private nonisolated static let entriesFolderName = "Entries"
        private nonisolated static let audioSourcesFolderName = "AudioSources"
        private nonisolated static let indexFileName = "index.json"
        private nonisolated static let metadataFileExtension = "json"
        private nonisolated static let legacySidecarExtension = "snapzy-recording.json"
        private nonisolated static let orphanGracePeriod: TimeInterval = 24 * 60 * 60

        private enum StoreLayout {
            case unified
            case legacy

            var pathComponents: [String] {
                switch self {
                case .unified:
                    [RecordingMetadataStore.capturesFolderName, RecordingMetadataStore.storeFolderName]
                case .legacy:
                    [RecordingMetadataStore.storeFolderName]
                }
            }
        }

        static func load(for videoURL: URL) -> RecordingMetadata? {
            do {
                let unifiedLocation = try requiredStoreLocation()
                var unifiedIndex = loadIndex(from: unifiedLocation)

                if let metadata = try loadStoredMetadata(
                    for: videoURL,
                    location: unifiedLocation,
                    index: &unifiedIndex,
                ) {
                    return metadata.canonicalizedForCurrentVersion()
                }

                if let metadata = try migrateLegacySidecarIfNeeded(
                    for: videoURL,
                    location: unifiedLocation,
                    index: &unifiedIndex,
                ) {
                    return metadata.canonicalizedForCurrentVersion()
                }

                for (layout, location) in try allStoreLocationsForRead() where layout == .legacy {
                    var index = loadIndex(from: location)
                    guard let metadata = try loadStoredMetadata(for: videoURL, location: location, index: &index)
                    else {
                        continue
                    }

                    let canonicalMetadata = metadata.canonicalizedForCurrentVersion()
                    try save(canonicalMetadata, for: videoURL)
                    try? deleteStoredMetadata(for: videoURL, location: location, index: &index)
                    return canonicalMetadata
                }
            } catch {
                recordingMetadataLogger
                    .error(
                        "Failed to load recording metadata for \(videoURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)",
                    )
            }

            return nil
        }

        static func save(_ metadata: RecordingMetadata, for videoURL: URL) throws {
            let location = try requiredStoreLocation()
            var index = loadIndex(from: location)

            let existingEntry = resolveEntry(for: videoURL, index: index)?.entry
            let entry = try makeEntry(id: existingEntry?.id ?? UUID(), for: videoURL)
            let metadataURL = metadataURL(for: entry.id, location: location)
            let normalizedMetadata = metadata.canonicalizedForCurrentVersion()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(normalizedMetadata)
            try data.write(to: metadataURL, options: .atomic)

            upsert(entry: entry, into: &index)
            try saveIndex(index, to: location)
            if let legacyLocation = try storeLocation(layout: .legacy, createIfNeeded: false),
               legacyLocation.entriesURL != location.entriesURL {
                var legacyIndex = loadIndex(from: legacyLocation)
                try? deleteStoredMetadata(for: videoURL, location: legacyLocation, index: &legacyIndex)
            }
            try deleteLegacySidecarIfPresent(for: videoURL)
        }

        static func storeAudioSource(from sourceURL: URL) throws -> URL {
            let location = try requiredStoreLocation()
            let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
            let destinationURL = location.audioSourcesURL
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        }

        static func moveAssociation(from oldURL: URL, to newURL: URL) throws {
            let unifiedLocation = try requiredStoreLocation()
            var unifiedIndex = loadIndex(from: unifiedLocation)

            if let resolved = resolveEntry(for: oldURL, index: unifiedIndex) {
                let entry = try makeEntry(id: resolved.entry.id, for: newURL)
                unifiedIndex.entries[resolved.index] = entry
                try saveIndex(unifiedIndex, to: unifiedLocation)
                if let legacyLocation = try storeLocation(layout: .legacy, createIfNeeded: false),
                   legacyLocation.entriesURL != unifiedLocation.entriesURL {
                    var legacyIndex = loadIndex(from: legacyLocation)
                    try? deleteStoredMetadata(for: oldURL, location: legacyLocation, index: &legacyIndex)
                }
                try deleteLegacySidecarIfPresent(for: oldURL)
                try deleteLegacySidecarIfPresent(for: newURL)
                return
            }

            if let legacyLocation = try storeLocation(layout: .legacy, createIfNeeded: false),
               legacyLocation.entriesURL != unifiedLocation.entriesURL {
                var legacyIndex = loadIndex(from: legacyLocation)
                if let metadata = try loadStoredMetadata(for: oldURL, location: legacyLocation, index: &legacyIndex) {
                    try save(metadata, for: newURL)
                    try? deleteStoredMetadata(for: oldURL, location: legacyLocation, index: &legacyIndex)
                    try deleteLegacySidecarIfPresent(for: oldURL)
                    try deleteLegacySidecarIfPresent(for: newURL)
                    return
                }
            }

            if let metadata = try loadLegacySidecarMetadata(for: oldURL) {
                try save(metadata, for: newURL)
                try deleteLegacySidecarIfPresent(for: oldURL)
            }
        }

        static func delete(for videoURL: URL) throws {
            for location in try allStoreLocationsForMaintenance() {
                var index = loadIndex(from: location)
                try deleteStoredMetadata(for: videoURL, location: location, index: &index)
            }

            try deleteLegacySidecarIfPresent(for: videoURL)
        }

        static func performOrphanCleanup(now: Date = Date()) throws {
            for location in try allStoreLocationsForMaintenance() {
                var index = loadIndex(from: location)
                var keptEntries: [MetadataIndexEntry] = []
                var metadataURLsToDelete: [URL] = []

                for entry in index.entries {
                    let metadataURL = metadataURL(for: entry.id, location: location)

                    guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                        metadataURLsToDelete.append(metadataURL)
                        continue
                    }

                    switch cleanupDisposition(for: entry, now: now) {
                    case .keep(let updatedEntry):
                        keptEntries.append(updatedEntry)
                    case .delete:
                        metadataURLsToDelete.append(metadataURL)
                    }
                }

                guard keptEntries != index.entries || !metadataURLsToDelete.isEmpty else {
                    continue
                }

                index.entries = keptEntries
                try saveIndex(index, to: location)

                for metadataURL in metadataURLsToDelete {
                    deleteMetadataFileAndAudioSource(at: metadataURL, location: location)
                }
            }
        }

        private static func storeLocation(
            layout: StoreLayout,
            createIfNeeded: Bool,
        ) throws -> StoreLocation? {
            guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
            else {
                return nil
            }

            let baseURL = appSupportURL
                .appendingPathComponent(appSupportFolderName, isDirectory: true)

            let rootURL = layout.pathComponents.reduce(baseURL) { partial, component in
                partial.appendingPathComponent(component, isDirectory: true)
            }
            let entriesURL = rootURL.appendingPathComponent(entriesFolderName, isDirectory: true)
            let audioSourcesURL = rootURL.appendingPathComponent(audioSourcesFolderName, isDirectory: true)
            let indexURL = rootURL.appendingPathComponent(indexFileName)

            if createIfNeeded {
                try FileManager.default.createDirectory(
                    at: entriesURL,
                    withIntermediateDirectories: true,
                    attributes: nil,
                )
                try FileManager.default.createDirectory(
                    at: audioSourcesURL,
                    withIntermediateDirectories: true,
                    attributes: nil,
                )
            } else if !FileManager.default.fileExists(atPath: rootURL.path) {
                return nil
            }

            return StoreLocation(
                entriesURL: entriesURL,
                indexURL: indexURL,
                audioSourcesURL: audioSourcesURL,
            )
        }

        private static func requiredStoreLocation() throws -> StoreLocation {
            if let location = try storeLocation(layout: .unified, createIfNeeded: true) {
                return location
            }

            throw CocoaError(.fileNoSuchFile)
        }

        private static func allStoreLocationsForRead() throws -> [(layout: StoreLayout, location: StoreLocation)] {
            var result: [(layout: StoreLayout, location: StoreLocation)] = []

            if let unified = try storeLocation(layout: .unified, createIfNeeded: false) {
                result.append((.unified, unified))
            }

            if let legacy = try storeLocation(layout: .legacy, createIfNeeded: false) {
                let alreadyIncluded = result.contains { $0.location.entriesURL == legacy.entriesURL }
                if !alreadyIncluded {
                    result.append((.legacy, legacy))
                }
            }

            return result
        }

        private static func allStoreLocationsForMaintenance() throws -> [StoreLocation] {
            var locations: [StoreLocation] = []

            if let unified = try storeLocation(layout: .unified, createIfNeeded: false) {
                locations.append(unified)
            }

            if let legacy = try storeLocation(layout: .legacy, createIfNeeded: false),
               !locations.contains(where: { $0.entriesURL == legacy.entriesURL }) {
                locations.append(legacy)
            }

            return locations
        }

        private static func loadIndex(from location: StoreLocation) -> MetadataIndex {
            guard FileManager.default.fileExists(atPath: location.indexURL.path),
                  let data = try? Data(contentsOf: location.indexURL)
            else {
                return MetadataIndex()
            }

            do {
                return try JSONDecoder().decode(MetadataIndex.self, from: data)
            } catch {
                recordingMetadataLogger
                    .error(
                        "Failed to decode metadata index at \(location.indexURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)",
                    )
                return MetadataIndex()
            }
        }

        private static func saveIndex(_ index: MetadataIndex, to location: StoreLocation) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(index)
            try data.write(to: location.indexURL, options: .atomic)
        }

        private static func loadStoredMetadata(
            for videoURL: URL,
            location: StoreLocation,
            index: inout MetadataIndex,
        ) throws -> RecordingMetadata? {
            guard let resolved = resolveEntry(for: videoURL, index: index) else {
                return nil
            }

            let metadataURL = metadataURL(for: resolved.entry.id, location: location)
            guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                index.entries.remove(at: resolved.index)
                try saveIndex(index, to: location)
                return nil
            }

            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(RecordingMetadata.self, from: data)

            if index.entries[resolved.index] != resolved.entry {
                index.entries[resolved.index] = resolved.entry
                try saveIndex(index, to: location)
            }

            return metadata
        }

        private static func deleteStoredMetadata(
            for videoURL: URL,
            location: StoreLocation,
            index: inout MetadataIndex,
        ) throws {
            guard let resolved = resolveEntry(for: videoURL, index: index) else {
                return
            }

            let metadataURL = metadataURL(for: resolved.entry.id, location: location)
            index.entries.remove(at: resolved.index)
            try saveIndex(index, to: location)

            deleteMetadataFileAndAudioSource(at: metadataURL, location: location)
        }

        private static func resolveEntry(
            for videoURL: URL,
            index: MetadataIndex,
        ) -> (index: Int, entry: MetadataIndexEntry)? {
            let targetPath = normalizedPath(for: videoURL)

            if let exactIndex = index.entries.firstIndex(where: { $0.lastKnownPath == targetPath }) {
                return (exactIndex, refreshedEntry(index.entries[exactIndex], with: videoURL))
            }

            for (indexPosition, entry) in index.entries.enumerated() {
                guard let bookmarkedURL = resolveBookmarkedURL(for: entry) else { continue }
                guard normalizedPath(for: bookmarkedURL) == targetPath else { continue }
                return (indexPosition, refreshedEntry(entry, with: videoURL))
            }

            return nil
        }

        private static func upsert(entry: MetadataIndexEntry, into index: inout MetadataIndex) {
            if let existingIndex = index.entries.firstIndex(where: { $0.id == entry.id }) {
                index.entries[existingIndex] = entry
            } else {
                index.entries.append(entry)
            }
        }

        private static func makeEntry(id: UUID, for videoURL: URL) throws -> MetadataIndexEntry {
            try MetadataIndexEntry(
                id: id,
                lastKnownPath: normalizedPath(for: videoURL),
                bookmarkData: videoBookmarkData(for: videoURL),
                staleSince: nil,
            )
        }

        private static func refreshedEntry(_ entry: MetadataIndexEntry, with videoURL: URL) -> MetadataIndexEntry {
            var refreshed = entry
            refreshed.lastKnownPath = normalizedPath(for: videoURL)
            refreshed.staleSince = nil

            if let bookmarkData = try? videoBookmarkData(for: videoURL) {
                refreshed.bookmarkData = bookmarkData
            }

            return refreshed
        }

        private static func videoBookmarkData(for videoURL: URL) throws -> Data {
            try SandboxFileAccessManager.shared.withScopedAccess(to: videoURL) {
                try videoURL.standardizedFileURL.bookmarkData(
                    options: [.minimalBookmark],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil,
                )
            }
        }

        private static func resolveBookmarkedURL(for entry: MetadataIndexEntry) -> URL? {
            var isStale = false

            do {
                return try URL(
                    resolvingBookmarkData: entry.bookmarkData,
                    options: [.withoutUI, .withoutMounting],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale,
                )
                .standardizedFileURL
                .resolvingSymlinksInPath()
            } catch {
                return nil
            }
        }

        private static func cleanupDisposition(
            for entry: MetadataIndexEntry,
            now: Date,
        ) -> CleanupDisposition {
            if let bookmarkedURL = resolveBookmarkedURL(for: entry),
               FileManager.default.fileExists(atPath: bookmarkedURL.path) {
                return .keep(refreshedCleanupEntry(entry, resolvedURL: bookmarkedURL))
            }

            let lastKnownURL = URL(fileURLWithPath: entry.lastKnownPath)
            if FileManager.default.fileExists(atPath: lastKnownURL.path) {
                return .keep(refreshedCleanupEntry(entry, resolvedURL: lastKnownURL))
            }

            guard let staleSince = entry.staleSince else {
                var staleEntry = entry
                staleEntry.staleSince = now
                return .keep(staleEntry)
            }

            if now.timeIntervalSince(staleSince) >= orphanGracePeriod {
                return .delete
            }

            return .keep(entry)
        }

        private static func refreshedCleanupEntry(
            _ entry: MetadataIndexEntry,
            resolvedURL: URL,
        ) -> MetadataIndexEntry {
            var refreshed = entry
            refreshed.lastKnownPath = normalizedPath(for: resolvedURL)
            refreshed.staleSince = nil

            if let bookmarkData = try? videoBookmarkData(for: resolvedURL) {
                refreshed.bookmarkData = bookmarkData
            }

            return refreshed
        }

        private static func normalizedPath(for videoURL: URL) -> String {
            videoURL.standardizedFileURL.resolvingSymlinksInPath().path
        }

        private static func metadataURL(for id: UUID, location: StoreLocation) -> URL {
            location.entriesURL
                .appendingPathComponent(id.uuidString)
                .appendingPathExtension(metadataFileExtension)
        }

        private static func deleteMetadataFileAndAudioSource(at metadataURL: URL, location: StoreLocation) {
            if
                let data = try? Data(contentsOf: metadataURL),
                let metadata = try? JSONDecoder().decode(RecordingMetadata.self, from: data),
                let audioSourceURL = metadata.audioSourceURL,
                isStoredAudioSourceURL(audioSourceURL, location: location),
                FileManager.default.fileExists(atPath: audioSourceURL.path) {
                try? FileManager.default.removeItem(at: audioSourceURL)
            }

            if FileManager.default.fileExists(atPath: metadataURL.path) {
                try? FileManager.default.removeItem(at: metadataURL)
            }
        }

        private static func isStoredAudioSourceURL(_ url: URL, location: StoreLocation) -> Bool {
            let sourcePath = url.standardizedFileURL.resolvingSymlinksInPath().path
            let rootPath = location.audioSourcesURL.standardizedFileURL.resolvingSymlinksInPath().path
            return sourcePath.hasPrefix(rootPath + "/")
        }

        private static func migrateLegacySidecarIfNeeded(
            for videoURL: URL,
            location: StoreLocation,
            index: inout MetadataIndex,
        ) throws -> RecordingMetadata? {
            guard let metadata = try loadLegacySidecarMetadata(for: videoURL) else {
                return nil
            }

            let entry = try makeEntry(id: UUID(), for: videoURL)
            let metadataURL = metadataURL(for: entry.id, location: location)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)

            try data.write(to: metadataURL, options: .atomic)
            upsert(entry: entry, into: &index)
            try saveIndex(index, to: location)
            try deleteLegacySidecarIfPresent(for: videoURL)

            return metadata
        }

        private static func loadLegacySidecarMetadata(for videoURL: URL) throws -> RecordingMetadata? {
            let sidecarURL = legacySidecarURL(for: videoURL)

            return try SandboxFileAccessManager.shared.withScopedAccess(to: sidecarURL.deletingLastPathComponent()) {
                guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
                    return nil
                }

                let data = try Data(contentsOf: sidecarURL)
                return try JSONDecoder().decode(RecordingMetadata.self, from: data)
            }
        }

        private static func deleteLegacySidecarIfPresent(for videoURL: URL) throws {
            let sidecarURL = legacySidecarURL(for: videoURL)

            try SandboxFileAccessManager.shared.withScopedAccess(to: sidecarURL.deletingLastPathComponent()) {
                guard FileManager.default.fileExists(atPath: sidecarURL.path) else { return }
                try FileManager.default.removeItem(at: sidecarURL)
            }
        }

        private static func legacySidecarURL(for videoURL: URL) -> URL {
            videoURL
                .deletingPathExtension()
                .appendingPathExtension(legacySidecarExtension)
        }
    }

    private extension RecordingMetadata {
        func canonicalizedForCurrentVersion() -> RecordingMetadata {
            let normalizedSamples: [RecordedMouseSample] = switch coordinateSpace {
            case .topLeftNormalized:
                mouseSamples
            case .bottomLeftNormalized:
                mouseSamples.map { sample in
                    var normalized = sample
                    normalized.normalizedY = (1 - sample.normalizedY).clamped(to: 0 ... 1)
                    return normalized
                }
            }

            let normalizedPresses: [RecordedMousePress] = switch coordinateSpace {
            case .topLeftNormalized:
                mousePresses
            case .bottomLeftNormalized:
                mousePresses.map { press in
                    var normalized = press
                    normalized.normalizedY = (1 - press.normalizedY).clamped(to: 0 ... 1)
                    return normalized
                }
            }

            return RecordingMetadata(
                version: RecordingMetadata.currentVersion,
                coordinateSpace: .topLeftNormalized,
                captureSize: captureSize,
                samplesPerSecond: samplesPerSecond,
                mouseSamples: normalizedSamples,
                mousePresses: normalizedPresses,
                pointerArtwork: pointerArtwork,
                pointerSynthesized: pointerSynthesized,
                keystrokes: keystrokes,
                audioSourceURL: audioSourceURL,
                audioSourceTrackRoles: audioSourceTrackRoles,
                audioSourceTracks: audioSourceTracks,
                videoSourceTracks: videoSourceTracks,
                cameraOverlayLayout: cameraOverlayLayout,
                clickHighlightsWereBaked: clickHighlightsWereBaked,
                keystrokesWereBaked: keystrokesWereBaked,
            )
        }
    }

    private extension CGFloat {
        func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
            Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
        }
    }
#endif

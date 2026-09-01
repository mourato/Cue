#if CUE_VIDEO_MODULE
//
    //  VideoEditorState.swift
    //  Notinhas
//
    //  Central state management for video editor
//

    import AppKit
    import AVFoundation
    import Combine

    // MARK: - Editor Action (Undo/Redo Support)

    /// Represents an undoable editor action
    enum EditorAction: Equatable {
        case trimStart(old: CMTime, new: CMTime)
        case trimEnd(old: CMTime, new: CMTime)
        case addZoom(segment: ZoomSegment)
        case removeZoom(segment: ZoomSegment)
        case updateZoom(old: ZoomSegment, new: ZoomSegment)
        case replaceImplicitZoomSegments(old: [ZoomSegment], new: [ZoomSegment])
        case addSpeed(segment: SpeedSegment)
        case removeSpeed(segment: SpeedSegment)
        case updateSpeed(old: SpeedSegment, new: SpeedSegment)
        case toggleMute(old: Bool, new: Bool)
        case updateBackground(
            oldStyle: BackgroundStyle, newStyle: BackgroundStyle,
            oldPadding: CGFloat, newPadding: CGFloat,
            oldShadow: CGFloat, newShadow: CGFloat,
            oldCorner: CGFloat, newCorner: CGFloat,
        )
        case replaceClipTimeline(old: VideoEditorClipTimeline, new: VideoEditorClipTimeline)
    }

    /// Playback state changes frequently, so it stays isolated from the broader editor model.
    @MainActor
    final class VideoEditorPlaybackState: ObservableObject {
        @Published private(set) var currentTime: CMTime = .zero
        @Published private(set) var isPlaying: Bool = false
        @Published private(set) var isScrubbing: Bool = false

        var formattedCurrentTime: String {
            Self.formatTime(currentTime)
        }

        func setCurrentTime(_ time: CMTime) {
            guard CMTimeCompare(currentTime, time) != 0 else { return }
            currentTime = time
        }

        func setPlaying(_ value: Bool) {
            guard isPlaying != value else { return }
            isPlaying = value
        }

        func setScrubbing(_ value: Bool) {
            guard isScrubbing != value else { return }
            isScrubbing = value
        }

        private static func formatTime(_ time: CMTime) -> String {
            let totalSeconds = Int(CMTimeGetSeconds(time))
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }

            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Observable state for video editor window
    @MainActor
    final class VideoEditorState: ObservableObject {
        private struct AutoFocusPathInput: Equatable {
            let zoomType: ZoomType
            let zoomLevel: CGFloat
            let followSpeed: Double
            let focusMargin: CGFloat

            init(segment: ZoomSegment) {
                zoomType = segment.zoomType
                zoomLevel = segment.zoomLevel
                followSpeed = segment.followSpeed
                focusMargin = segment.focusMargin
            }
        }

        private struct FrameExtractionProfile {
            let frameCount: Int
            let tolerance: CMTime
            let strategyLabel: String
        }

        // MARK: - Video Source

        private(set) var sourceURL: URL
        /// Original file URL to replace (used for "Replace Original" functionality)
        private(set) var originalURL: URL
        private(set) var assetURL: URL
        let asset: AVAsset
        let player: AVPlayer
        let playbackState = VideoEditorPlaybackState()

        // MARK: - Metadata

        @Published private(set) var duration: CMTime = .zero
        @Published private(set) var naturalSize: CGSize = .zero
        @Published private(set) var audioTrackRoles: [VideoEditorAudioTrackRole] = []
        @Published private(set) var hasCameraTrack = false
        @Published private(set) var screenTrackID: CMPersistentTrackID?
        @Published private(set) var cameraTrackID: CMPersistentTrackID?
        @Published private(set) var cameraSize: CGSize = .zero
        @Published private(set) var cameraIsMirrored = false
        @Published private(set) var cameraMetadataWasInvalid = false
        @Published var cameraOverlayLayout = VideoEditorCameraOverlayLayout.default {
            didSet { cameraLayoutMutationCount += 1 }
        }

        private(set) var cameraPlayer: AVPlayer?
        private var cameraComposition: AVMutableComposition?

        // MARK: - Trim Range

        @Published var trimStart: CMTime = .zero {
            didSet { invalidateSpeedMap() }
        }

        @Published var trimEnd: CMTime = .zero {
            didSet { invalidateSpeedMap() }
        }

        // MARK: - Speed Segments (Timelapse)

        @Published var speedSegments: [SpeedSegment] = [] {
            didSet { invalidateSpeedMap() }
        }

        @Published var selectedSpeedId: UUID? = nil

        // MARK: - Clip Timeline (Plan 110 / Phase C)

        @Published var clipTimeline: VideoEditorClipTimeline = .init(segments: []) {
            didSet { syncTrimFromClipTimeline() }
        }

        @Published var selectedClipId: UUID?

        private var initialClipTimeline: VideoEditorClipTimeline = .init(segments: [])

        private var cachedSpeedTimeMap: SpeedTimeMap?

        /// Cached original↔scaled time map. Rebuilt lazily after any change to
        /// `speedSegments`, `trimStart`, or `trimEnd`.
        var speedTimeMap: SpeedTimeMap {
            if let cached = cachedSpeedTimeMap {
                return cached
            }
            let map = SpeedTimeMap(
                speedSegments: speedSegments,
                trimStart: CMTimeGetSeconds(trimStart),
                trimEnd: CMTimeGetSeconds(trimEnd),
            )
            cachedSpeedTimeMap = map
            return map
        }

        private func invalidateSpeedMap() {
            cachedSpeedTimeMap = nil
        }

        /// True when at least one enabled speed segment changes playback rate.
        var hasSpeedSegments: Bool {
            speedSegments.contains { $0.isEnabled && $0.rate != 1.0 }
        }

        /// Final output length after trim + speed scaling. Equals `trimmedDuration` when no
        /// speed segments are active. Clip edits and per-clip speed use `clipTimeline.duration`.
        var effectiveOutputDuration: CMTime {
            if usesClipComposition {
                return CMTime(seconds: clipTimeline.duration, preferredTimescale: 600)
            }
            return hasSpeedSegments ? speedTimeMap.scaledCMDuration() : trimmedDuration
        }

        /// True when the clip lane drives playback/export instead of a single full-span trim.
        var usesClipComposition: Bool {
            guard !isGIF else { return false }
            let sourceSeconds = CMTimeGetSeconds(duration)
            guard sourceSeconds.isFinite, sourceSeconds > 0 else { return false }
            return !clipTimeline.isUnedited(sourceDuration: sourceSeconds) || clipTimeline.hasPerClipSpeed
        }

        /// Timeline duration used for scrubbing and playhead UI.
        var playbackDuration: CMTime {
            usesClipComposition
                ? CMTime(seconds: clipTimeline.duration, preferredTimescale: 600)
                : duration
        }

        var hasClipEdits: Bool {
            guard !isGIF else { return false }
            let sourceSeconds = CMTimeGetSeconds(duration)
            guard sourceSeconds.isFinite, sourceSeconds > 0 else { return false }
            return !clipTimeline.isUnedited(sourceDuration: sourceSeconds)
        }

        var canDeleteSelectedClip: Bool {
            selectedClipId != nil && clipTimeline.segments.count > 1
        }

        var selectedClipSegment: VideoEditorClipSegment? {
            guard let selectedClipId else { return nil }
            return clipTimeline.segments.first { $0.id == selectedClipId }
        }

        /// Maps playhead time to absolute source time for zoom/pointer lookup.
        func sourceTime(atPlayhead time: CMTime) -> TimeInterval {
            let seconds = CMTimeGetSeconds(time)
            if usesClipComposition {
                return clipTimeline.sourceTime(at: seconds)
            }
            return seconds
        }

        /// True when export uses crop-and-follow reframe into a target aspect ratio.
        var usesReframeExport: Bool {
            exportSettings.dimensionPreset.isAspectRatioPreset && exportContentMode == .fill
        }

        /// Preview/export camera state at the editor playhead, including reframe when active.
        func previewCameraState(atPlayhead time: CMTime) -> VideoEditorCameraState {
            let editorSeconds = CMTimeGetSeconds(time)
            if let reframe = makeReframeTrack(
                viewportTimeline: viewportTimeline,
                pointerTimeline: pointerTimeline,
                duration: CMTimeGetSeconds(playbackDuration),
            ) {
                let frame = reframe.frame(at: editorSeconds)
                return VideoEditorCameraState(
                    zoomLevel: CGFloat(frame.magnification),
                    center: frame.anchor,
                )
            }
            return cameraState(at: sourceTime(atPlayhead: time))
        }

        func makeReframeTrack(
            viewportTimeline: VideoEditorViewportTimeline,
            pointerTimeline: VideoEditorPointerTimeline,
            duration: TimeInterval,
        ) -> VideoEditorReframeTrack? {
            guard usesReframeExport,
                  naturalSize.width > 0,
                  naturalSize.height > 0,
                  duration.isFinite,
                  duration > 0 else {
                return nil
            }
            return VideoEditorReframeTrack.build(
                preset: exportSettings.dimensionPreset,
                sourceSize: naturalSize,
                viewportTimeline: viewportTimeline,
                duration: duration,
                focus: { editorTime in
                    if let pointer = pointerTimeline.frame(at: editorTime), pointer.opacity > 0.01 {
                        return pointer.location
                    }
                    return viewportTimeline.frame(at: editorTime).anchor
                },
            )
        }

        // MARK: - Audio Control

        @Published var isMuted: Bool = false {
            didSet {
                player.isMuted = isMuted
            }
        }

        private var initialIsMuted: Bool = false

        /// Sync player preview audio with export audio mode and custom volume settings.
        func syncPlayerAudioWithExportSettings() {
            let shouldMute = exportSettings.audioMode == .mute
            if isMuted != shouldMute {
                isMuted = shouldMute
            } else {
                player.isMuted = shouldMute
            }

            guard exportSettings.audioMode == .custom else {
                player.volume = 1.0
                player.currentItem?.audioMix = nil
                return
            }

            player.volume = 1.0
            let settingsSnapshot = exportSettings
            let audioTrackRolesSnapshot = audioTrackRoles
            let assetSnapshot = asset
            Task { @MainActor [weak self] in
                do {
                    let audioTracks = try await assetSnapshot.loadTracks(withMediaType: .audio)
                    guard let self,
                          exportSettings == settingsSnapshot,
                          exportSettings.audioMode == .custom
                    else { return }

                    player.currentItem?.audioMix = VideoEditorAudioMixFactory.makeAudioMix(
                        for: audioTracks,
                        settings: settingsSnapshot,
                        roles: audioTrackRolesSnapshot,
                    )
                } catch {
                    DiagnosticLogger.shared.logError(.editor, error, "Preview audio mix failed")
                }
            }
        }

        // MARK: - Frame Thumbnails

        @Published private(set) var frameThumbnails: [NSImage] = []
        @Published private(set) var isExtractingFrames: Bool = false

        // MARK: - Zoom Segments

        @Published var zoomSegments: [ZoomSegment] = []
        @Published var selectedZoomId: UUID? = nil
        @Published var isZoomTrackVisible: Bool = true
        @Published var isSpeedTrackVisible: Bool = true
        @Published var isClipTrackVisible: Bool = true
        @Published var isVideoInfoSidebarVisible: Bool = false
        @Published var isLeftSidebarVisible: Bool = false
        @Published var isRightSidebarVisible: Bool = false
        @Published var zoomTransitionDuration: TimeInterval = ZoomCalculator.defaultTransitionDuration {
            didSet {
                let clamped = ZoomCalculator.clampTransitionDuration(zoomTransitionDuration)
                if abs(clamped - zoomTransitionDuration) > 0.0001 {
                    zoomTransitionDuration = clamped
                    return
                }

                UserDefaults.standard.set(clamped, forKey: PreferencesKeys.videoEditorZoomTransitionDuration)
            }
        }

        // MARK: - Auto Focus

        @Published private(set) var recordingMetadata: RecordingMetadata?
        @Published private(set) var autoFocusPaths: [UUID: [AutoFocusCameraSample]] = [:]
        @Published private(set) var viewportTimeline: VideoEditorViewportTimeline = .identity
        @Published var showsSyntheticCursor = false {
            didSet {
                guard !showsSyntheticCursor || canShowSyntheticCursor else {
                    showsSyntheticCursor = false
                    return
                }
                cursorSettingDidChange()
            }
        }

        @Published var showsClickEffects = false {
            didSet { cursorSettingDidChange() }
        }

        @Published var showsKeystrokes = false {
            didSet { cursorSettingDidChange() }
        }

        @Published var cursorScale: CGFloat = VideoEditorStylePreset.defaultCursorScale {
            didSet { cursorSettingDidChange() }
        }

        @Published var cursorSmoothingPreset: VideoEditorCursorSmoothingPreset = .original {
            didSet {
                rebuildOverlayTimelines(duration: CMTimeGetSeconds(duration))
                cursorSettingDidChange()
            }
        }

        @Published var exportContentMode: VideoEditorExportAspectContentMode = .fit
        @Published private(set) var pointerTimeline: VideoEditorPointerTimeline = .empty
        @Published private(set) var keystrokeCaptionTimeline: VideoEditorKeystrokeCaptionTimeline = .empty

        // MARK: - GIF Metadata

        @Published private(set) var gifFrameCount: Int = 0
        @Published private(set) var gifDuration: Double = 0

        // MARK: - Background Settings

        @Published var backgroundStyle: BackgroundStyle = .none {
            didSet {
                handleBackgroundStyleChange()
            }
        }

        @Published var backgroundPadding: CGFloat = 0

        // MARK: - Cached Background Images (Performance Optimization)

        /// Cached background image for performance (avoids disk reads during render)
        @Published private(set) var cachedBackgroundImage: NSImage?

        /// Cached pre-computed blurred image (avoids real-time blur)
        @Published private(set) var cachedBlurredImage: NSImage?

        /// Track URL being loaded to prevent race conditions
        private var loadingBackgroundURL: URL?
        @Published var backgroundShadowIntensity: CGFloat = 0
        @Published var backgroundCornerRadius: CGFloat = 0
        @Published var backgroundAlignment: ImageAlignment = .center
        @Published var backgroundAspectRatio: AspectRatioOption = .auto

        // MARK: - Export State

        @Published var isExporting: Bool = false
        @Published var exportProgress: Float = 0
        @Published var exportStatusMessage: String = "Preparing..."
        @Published var frameExtractionError: String?
        @Published private(set) var isExtractingFrame = false

        // MARK: - Export Settings

        @Published var exportSettings: ExportSettings = .init()
        @Published private(set) var estimatedFileSize: Int64 = 0

        // MARK: - Unsaved Changes

        @Published var hasUnsavedChanges: Bool = false
        private var initialTrimStart: CMTime = .zero
        private var initialTrimEnd: CMTime = .zero
        private var initialZoomSegments: [ZoomSegment] = []
        private var initialSpeedSegments: [SpeedSegment] = []
        private var initialBackgroundStyle: BackgroundStyle = .none
        private var initialBackgroundPadding: CGFloat = 0
        private var initialBackgroundShadowIntensity: CGFloat = 0
        private var initialBackgroundCornerRadius: CGFloat = 0
        private var initialExportSettings: ExportSettings = .init()
        private var initialCameraOverlayLayout = VideoEditorCameraOverlayLayout.default
        private var initialShowsSyntheticCursor = false
        private var initialShowsClickEffects = false
        private var initialShowsKeystrokes = false
        private var initialCursorScale = VideoEditorStylePreset.defaultCursorScale
        private var initialCursorSmoothingPreset: VideoEditorCursorSmoothingPreset = .original
        private var cameraLayoutMutationCount = 0

        @Published var quickAccessItemId: UUID?

        // MARK: - Undo/Redo

        @Published private(set) var canUndo: Bool = false
        @Published private(set) var canRedo: Bool = false
        private var undoStack: [EditorAction] = []
        private var redoStack: [EditorAction] = []
        private let maxUndoStackSize = 50
        private var isUndoingOrRedoing: Bool = false

        // MARK: - Rename State

        @Published var isRenamingFile: Bool = false

        // MARK: - Private

        private var timeObserver: Any?
        private var endObserver: NSObjectProtocol?
        private var cancellables = Set<AnyCancellable>()
        private var autoFocusPathInputs: [UUID: AutoFocusPathInput] = [:]
        private var frameAnnotationAttemptID: UUID?

        // MARK: - Computed Properties

        var trimmedDuration: CMTime {
            CMTimeSubtract(trimEnd, trimStart)
        }

        var hasMouseTrackingData: Bool {
            !(recordingMetadata?.mouseSamples.isEmpty ?? true)
        }

        var autoZoomSegmentCount: Int {
            zoomSegments.filter(\.isAutoMode).count
        }

        var hasAutoZoomSegments: Bool {
            autoZoomSegmentCount > 0
        }

        var recordedClickCount: Int {
            recordingMetadata?.mousePresses.filter { $0.phase == .down }.count ?? 0
        }

        var implicitZoomSegmentCount: Int {
            zoomSegments.filter(\.isImplicit).count
        }

        var canResynthesizeImplicitZoomSegments: Bool {
            recordingMetadata != nil && recordedClickCount > 0
        }

        var usesSyntheticPointer: Bool {
            recordingMetadata?.pointerSynthesized == true
        }

        var canShowSyntheticCursor: Bool {
            usesSyntheticPointer && hasMouseTrackingData
        }

        var shouldRenderSyntheticCursor: Bool {
            canShowSyntheticCursor && showsSyntheticCursor
        }

        var hasRecordedKeystrokes: Bool {
            !(recordingMetadata?.keystrokes.isEmpty ?? true)
        }

        var hasSyntheticOverlays: Bool {
            shouldRenderSyntheticCursor || showsClickEffects || showsKeystrokes
        }

        var currentTime: CMTime {
            playbackState.currentTime
        }

        var isPlaying: Bool {
            playbackState.isPlaying
        }

        var isScrubbing: Bool {
            playbackState.isScrubbing
        }

        var isAutoZoomActiveAtCurrentTime: Bool {
            activeZoomSegment(at: CMTimeGetSeconds(currentTime))?.isAutoMode == true
        }

        var filename: String {
            sourceURL.lastPathComponent
        }

        var fileExtension: String {
            sourceURL.pathExtension.lowercased()
        }

        /// Whether the source file is an animated GIF
        var isGIF: Bool {
            fileExtension == "gif"
        }

        var formattedDuration: String {
            formatTime(duration)
        }

        var formattedCurrentTime: String {
            formatTime(currentTime)
        }

        var formattedTrimmedDuration: String {
            formatTime(trimmedDuration)
        }

        /// Final output length after trim + speed scaling. Differs from trimmed duration only when
        /// speed segments are active.
        var formattedOutputDuration: String {
            formatTime(effectiveOutputDuration)
        }

        var resolutionString: String {
            guard naturalSize.width > 0, naturalSize.height > 0 else { return "—" }
            return "\(Int(naturalSize.width)) × \(Int(naturalSize.height))"
        }

        var aspectRatioString: String {
            guard naturalSize.width > 0, naturalSize.height > 0 else { return "—" }
            let gcdValue = gcd(Int(naturalSize.width), Int(naturalSize.height))
            let w = Int(naturalSize.width) / gcdValue
            let h = Int(naturalSize.height) / gcdValue
            return "\(w):\(h)"
        }

        var fileSizeString: String {
            let size: Int64? = SandboxFileAccessManager.shared.withScopedAccess(to: sourceURL) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
                      let size = attrs[.size] as? Int64
                else { return nil }
                return size
            }
            guard let size else { return "—" }
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }

        var fileCreationDate: Date? {
            SandboxFileAccessManager.shared.withScopedAccess(to: sourceURL) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path) else {
                    return nil
                }
                return attrs[.creationDate] as? Date
            }
        }

        var fileModificationDate: Date? {
            SandboxFileAccessManager.shared.withScopedAccess(to: sourceURL) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path) else {
                    return nil
                }
                return attrs[.modificationDate] as? Date
            }
        }

        private func gcd(_ a: Int, _ b: Int) -> Int {
            b == 0 ? a : gcd(b, a % b)
        }

        // MARK: - Initialization

        init(url: URL, originalURL: URL? = nil) {
            let initialMetadata = Self.loadRecordingMetadata(for: url, originalURL: originalURL)
            let editorAssetURL = Self.editorAssetURL(for: url, metadata: initialMetadata)

            sourceURL = url
            self.originalURL = originalURL ?? url
            assetURL = editorAssetURL
            asset = AVAsset(url: editorAssetURL)
            player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            player.isMuted = SoundManager.isPlaybackSuppressedForTests
            zoomTransitionDuration = Self.loadZoomTransitionDuration()
            recordingMetadata = initialMetadata

            setupTimeObserver()
            setupEndObserver()
            setupChangeTracking()
        }

        private static func loadRecordingMetadata(for url: URL, originalURL: URL?) -> RecordingMetadata? {
            let candidateURLs = [url, originalURL].compactMap(\.self)
                .reduce(into: [URL]()) { urls, url in
                    guard !urls.contains(url) else { return }
                    urls.append(url)
                }

            return candidateURLs.lazy.compactMap { RecordingMetadataStore.load(for: $0) }.first
        }

        static func editorAssetURL(for url: URL, metadata: RecordingMetadata?) -> URL {
            guard
                let audioSourceURL = metadata?.audioSourceURL,
                FileManager.default.fileExists(atPath: audioSourceURL.path)
            else {
                return url
            }

            return audioSourceURL
        }

        static func audioTrackRoles(for audioTracks: [AVAssetTrack],
                                    metadata: RecordingMetadata?) -> [VideoEditorAudioTrackRole] {
            let count = audioTracks.count
            guard count > 0 else { return [] }

            if let metadata,
               metadata.audioSourceURL != nil,
               !metadata.audioSourceTracks.isEmpty {
                let rolesByTrackID = Dictionary(
                    uniqueKeysWithValues: metadata.audioSourceTracks.map { ($0.trackID, $0.role) },
                )
                let resolvedRoles = audioTracks.compactMap { track in
                    rolesByTrackID[Int(track.trackID)].map(Self.videoEditorAudioTrackRole)
                }
                if resolvedRoles.count == count {
                    return resolvedRoles
                }
            }

            if let metadata,
               metadata.audioSourceURL != nil,
               metadata.audioSourceTrackRoles.count == count {
                return metadata.audioSourceTrackRoles.map(Self.videoEditorAudioTrackRole)
            }

            return VideoEditorAudioTrackRole.roles(forAudioTrackCount: count)
        }

        static func audioTrackRoles(forAudioTrackCount count: Int,
                                    metadata: RecordingMetadata?) -> [VideoEditorAudioTrackRole] {
            if let metadata,
               metadata.audioSourceURL != nil,
               metadata.audioSourceTrackRoles.count == count {
                return metadata.audioSourceTrackRoles.map(videoEditorAudioTrackRole)
            }

            return VideoEditorAudioTrackRole.roles(forAudioTrackCount: count)
        }

        static func resolveVideoTracks(
            _ videoTracks: [AVAssetTrack], metadata: RecordingMetadata?,
        ) async throws -> VideoEditorVideoTrackResolution? {
            guard let first = videoTracks.first else { return nil }
            let ids = Set(videoTracks.map(\.trackID))
            guard let metadataTracks = metadata?.videoSourceTracks, !metadataTracks.isEmpty else {
                return VideoEditorVideoTrackResolution(screenTrackID: first.trackID, cameraTrackID: nil,
                                                       cameraSize: nil, cameraIsMirrored: false,
                                                       cameraMetadataWasInvalid: false)
            }
            let screenEntries = metadataTracks.filter { $0.role == .screen }
            let cameraEntries = metadataTracks.filter { $0.role == .camera }
            let cameraWasDeclared = !cameraEntries.isEmpty || metadataTracks.count > 1
            guard screenEntries.count == 1, cameraEntries.count <= 1,
                  !cameraWasDeclared || cameraEntries.count == 1 else {
                return VideoEditorVideoTrackResolution(screenTrackID: first.trackID, cameraTrackID: nil,
                                                       cameraSize: nil, cameraIsMirrored: false,
                                                       cameraMetadataWasInvalid: true)
            }
            let screenEntry = screenEntries[0]
            guard ids.contains(CMPersistentTrackID(screenEntry.trackID)) else {
                return VideoEditorVideoTrackResolution(screenTrackID: first.trackID, cameraTrackID: nil,
                                                       cameraSize: nil, cameraIsMirrored: false,
                                                       cameraMetadataWasInvalid: true)
            }
            let screen = videoTracks.first(where: { $0.trackID == CMPersistentTrackID(screenEntry.trackID) }) ?? first
            guard let camera = cameraEntries.first else {
                return VideoEditorVideoTrackResolution(screenTrackID: screen.trackID, cameraTrackID: nil,
                                                       cameraSize: nil, cameraIsMirrored: false,
                                                       cameraMetadataWasInvalid: false)
            }
            guard camera.trackID != screenEntry.trackID,
                  ids.contains(CMPersistentTrackID(camera.trackID)) else {
                return VideoEditorVideoTrackResolution(screenTrackID: screen.trackID, cameraTrackID: nil,
                                                       cameraSize: nil, cameraIsMirrored: camera.isMirrored,
                                                       cameraMetadataWasInvalid: true)
            }
            guard let cameraTrack = videoTracks.first(where: { $0.trackID == CMPersistentTrackID(camera.trackID) })
            else {
                return VideoEditorVideoTrackResolution(screenTrackID: screen.trackID, cameraTrackID: nil,
                                                       cameraSize: nil, cameraIsMirrored: camera.isMirrored,
                                                       cameraMetadataWasInvalid: true)
            }
            let naturalSize = try await cameraTrack.load(.naturalSize)
            return VideoEditorVideoTrackResolution(screenTrackID: screen.trackID, cameraTrackID: cameraTrack.trackID,
                                                   cameraSize: camera.captureSize ?? naturalSize,
                                                   cameraIsMirrored: camera.isMirrored,
                                                   cameraMetadataWasInvalid: false)
        }

        private static func videoEditorAudioTrackRole(_ role: RecordingAudioSourceTrackRole)
            -> VideoEditorAudioTrackRole {
            switch role {
            case .systemAudio:
                .systemAudio
            case .microphone:
                .microphone
            }
        }

        isolated deinit {
            if let observer = timeObserver {
                player.removeTimeObserver(observer)
            }
            if let observer = endObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            cancellables.removeAll()
        }

        // MARK: - Metadata Loading

        func loadMetadata() async {
            loadRecordingMetadata()

            // GIF files can't be loaded by AVAsset — use GIFResizer metadata
            if isGIF {
                if let metadata = GIFResizer.metadata(for: sourceURL) {
                    naturalSize = metadata.size
                    gifFrameCount = metadata.frameCount
                    gifDuration = metadata.duration
                    DiagnosticLogger.shared.log(
                        .info,
                        .editor,
                        "GIF metadata loaded",
                        context: [
                            "size": "\(Int(metadata.size.width))x\(Int(metadata.size.height))",
                            "frames": "\(metadata.frameCount)",
                        ],
                    )
                } else if let image = SandboxFileAccessManager.shared.withScopedAccess(to: sourceURL, {
                    NSImage(contentsOf: sourceURL)
                }) {
                    naturalSize = CGSize(
                        width: image.representations.first?.pixelsWide ?? Int(image.size.width),
                        height: image.representations.first?.pixelsHigh ?? Int(image.size.height),
                    )
                }
                return
            }

            do {
                let loadedDuration = try await asset.load(.duration)
                duration = loadedDuration
                trimStart = .zero
                trimEnd = loadedDuration
                initialTrimStart = .zero
                initialTrimEnd = loadedDuration
                let sourceSeconds = CMTimeGetSeconds(loadedDuration)
                clipTimeline = .full(sourceDuration: sourceSeconds)
                initialClipTimeline = clipTimeline
                selectedClipId = clipTimeline.segments.first?.id

                if let track = try await asset.loadTracks(withMediaType: .video).first {
                    let size = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    // Apply transform to get correct orientation
                    let transformedSize = size.applying(transform)
                    naturalSize = CGSize(
                        width: abs(transformedSize.width),
                        height: abs(transformedSize.height),
                    )
                }
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let cameraLayoutMutationCountBeforeResolution = cameraLayoutMutationCount
                if let resolution = try await Self.resolveVideoTracks(videoTracks, metadata: recordingMetadata) {
                    screenTrackID = resolution.screenTrackID
                    cameraTrackID = resolution.cameraTrackID
                    cameraSize = resolution.cameraSize ?? .zero
                    cameraIsMirrored = resolution.cameraIsMirrored
                    cameraMetadataWasInvalid = resolution.cameraMetadataWasInvalid
                    hasCameraTrack = resolution.cameraTrackID != nil && !isGIF
                    if cameraLayoutMutationCount == cameraLayoutMutationCountBeforeResolution, !hasCameraTrack {
                        cameraOverlayLayout.isVisible = false
                    }
                    if cameraLayoutMutationCount == cameraLayoutMutationCountBeforeResolution
                        ||
                        (!hasCameraTrack && cameraLayoutMutationCount == cameraLayoutMutationCountBeforeResolution +
                            1) {
                        initialCameraOverlayLayout = cameraOverlayLayout
                    }
                    updateHasUnsavedChanges()
                    if hasCameraTrack {
                        await prepareCameraPreview(trackID: resolution.cameraTrackID!)
                    }
                }
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                let audioTrackCount = audioTracks.count
                audioTrackRoles = Self.audioTrackRoles(for: audioTracks, metadata: recordingMetadata)
                DiagnosticLogger.shared.log(.info, .editor, "Video metadata loaded", context: [
                    "duration": String(format: "%.1fs", CMTimeGetSeconds(loadedDuration)),
                    "size": "\(Int(naturalSize.width))x\(Int(naturalSize.height))",
                    "audioTracks": "\(audioTrackCount)",
                    "audioTrackRoles": audioTrackRoles.map(\.id).joined(separator: ","),
                ])
                // Calculate initial file size estimate after metadata loads
                recalculateEstimatedFileSize()
                applyInitialImplicitZoomSegmentsIfNeeded()
                if zoomSegments.isEmpty {
                    rebuildAutoFocusPaths(for: zoomSegments)
                }
                VideoEditorStylePresetStore.shared.applyActivePreset(to: self)
                establishInitialCursorSettings()
                updateHasUnsavedChanges()
            } catch {
                DiagnosticLogger.shared.logError(.editor, error, "Failed to load video metadata")
                print("Failed to load video metadata: \(error)")
            }
        }

        // MARK: - Playback Control

        func play() {
            // Preserve pitch when playing speed-scaled regions (matches export's .spectral choice).
            player.currentItem?.audioTimePitchAlgorithm = .spectral
            // Start playback at the rate of the speed segment under the playhead (1.0 when none).
            player.rate = currentPreviewRate(at: currentTime)
            cameraPlayer?.rate = player.rate
            playbackState.setPlaying(true)
        }

        /// Playback rate for the speed segment under a given absolute asset time. Returns 1.0 when
        /// no speed segments are active. Used to drive the live preview via `player.rate` so the
        /// editor keeps its absolute-asset-time coordinate system (playhead, trim, zoom overlay,
        /// thumbnails all unchanged). Export remains the frame-accurate path (see VideoEditorExporter).
        func currentPreviewRate(at time: CMTime) -> Float {
            if usesClipComposition {
                let editorSeconds = CMTimeGetSeconds(time)
                guard let location = clipTimeline.location(at: editorSeconds) else { return 1.0 }
                return Float(clipTimeline.segments[location.segmentIndex].speed)
            }
            guard hasSpeedSegments else { return 1.0 }
            let trimRelative = CMTimeGetSeconds(time) - CMTimeGetSeconds(trimStart)
            return Float(speedTimeMap.rate(atOriginal: max(0, trimRelative)))
        }

        func pause() {
            player.pause()
            cameraPlayer?.pause()
            playbackState.setPlaying(false)
        }

        func togglePlayback() {
            if isPlaying {
                pause()
            } else {
                play()
            }
        }

        func toggleMute() {
            let oldValue = isMuted
            isMuted.toggle()
            recordAction(.toggleMute(old: oldValue, new: isMuted))
        }

        func seek(to time: CMTime) {
            let clampedTime = clampTime(time)
            playbackState.setCurrentTime(clampedTime)
            player.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
            cameraPlayer?.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        func stepTimeline(by seconds: Double) {
            let step = CMTime(seconds: seconds, preferredTimescale: 600)
            let steppedTime = CMTimeAdd(currentTime, step)
            let clampedTime = clampTime(steppedTime)
            playbackState.setCurrentTime(clampedTime)
            player.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
            cameraPlayer?.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        // MARK: - Scrubbing

        func startScrubbing() {
            playbackState.setScrubbing(true)
            pause()
        }

        func scrub(to time: CMTime) {
            let clampedTime = clampTime(time)
            playbackState.setCurrentTime(clampedTime)
            player.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
            cameraPlayer?.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        func endScrubbing() {
            playbackState.setScrubbing(false)
        }

        // MARK: - Trim Control

        func setTrimStart(_ time: CMTime, recordUndo: Bool = true) {
            let oldValue = trimStart
            let minDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
            let maxStart = CMTimeSubtract(trimEnd, minDuration)
            let clampedStart = CMTimeClampToRange(time, range: CMTimeRange(start: .zero, end: maxStart))
            trimStart = clampedStart

            // If current time is before new start, seek to start
            if CMTimeCompare(currentTime, trimStart) < 0 {
                seek(to: trimStart)
            }

            if recordUndo, CMTimeCompare(oldValue, clampedStart) != 0 {
                recordAction(.trimStart(old: oldValue, new: clampedStart))
            }
        }

        func setTrimEnd(_ time: CMTime, recordUndo: Bool = true) {
            let oldValue = trimEnd
            let minDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
            let minEnd = CMTimeAdd(trimStart, minDuration)
            let clampedEnd = CMTimeClampToRange(time, range: CMTimeRange(start: minEnd, end: duration))
            trimEnd = clampedEnd

            // If current time is after new end, seek to end
            if CMTimeCompare(currentTime, trimEnd) > 0 {
                seek(to: trimEnd)
            }

            if recordUndo, CMTimeCompare(oldValue, clampedEnd) != 0 {
                recordAction(.trimEnd(old: oldValue, new: clampedEnd))
            }
        }

        func resetTrim() {
            trimStart = .zero
            trimEnd = duration
        }

        // MARK: - Frame Extraction

        func extractFrames() async {
            // GIF files don't use AVAsset — skip frame extraction
            guard !isGIF else { return }
            guard CMTimeGetSeconds(duration) > 0 else { return }

            isExtractingFrames = true
            defer { isExtractingFrames = false }

            let startedAt = Date()
            let profile = await determineFrameExtractionProfile()
            let totalSeconds = CMTimeGetSeconds(duration)
            let cgImages = await generateFrameThumbnails(
                frameCount: profile.frameCount,
                totalSeconds: totalSeconds,
                tolerance: profile.tolerance,
            )

            frameThumbnails = cgImages.map { image in
                NSImage(cgImage: image, size: NSSize(width: 120, height: 68))
            }

            DiagnosticLogger.shared.log(.info, .editor, "Frame strip extracted", context: [
                "strategy": profile.strategyLabel,
                "requestedFrames": "\(profile.frameCount)",
                "generatedFrames": "\(frameThumbnails.count)",
                "elapsedMs": "\(Int(Date().timeIntervalSince(startedAt) * 1000))",
            ])
        }

        /// Extracts the raw, preferred-oriented asset frame at the clicked playhead time.
        /// Editor zoom, background, padding, cursor effects, and speed are intentionally absent.
        func annotateCurrentFrame() async {
            guard !isGIF, !isExtractingFrame else { return }
            let request = VideoFrameExtractionRequest(
                sourceURL: assetURL,
                requestedTime: CMTimeGetSeconds(playbackState.currentTime),
                assetDuration: CMTimeGetSeconds(duration),
                baseName: sourceURL.deletingPathExtension().lastPathComponent,
            )
            guard request.clampedTime != nil else {
                frameExtractionError = VideoFrameExtractionError.invalidRequestTime.localizedDescription
                return
            }

            isExtractingFrame = true
            defer { isExtractingFrame = false }
            let attemptID = UUID()
            frameAnnotationAttemptID = attemptID
            do {
                let result = try await VideoFrameExtractor.extract(
                    request: request,
                    outputRoot: TempCaptureManager.shared.tempCaptureDirectory,
                )
                guard frameAnnotationAttemptID == attemptID, !Task.isCancelled else {
                    if result.url.pathExtension.lowercased() == "png" {
                        try? FileManager.default.removeItem(at: result.url)
                    }
                    return
                }
                await PostCaptureActionHandler.shared.handleVideoFrameCapture(
                    url: result.url,
                    sourceURL: request.sourceURL,
                    requestedTime: result.requestedTime,
                    actualTime: result.actualTime,
                )
            } catch {
                frameExtractionError = error.localizedDescription
                DiagnosticLogger.shared.logError(.editor, error, "Video frame extraction failed")
            }
        }

        func invalidateFrameAnnotationAttempt() {
            frameAnnotationAttemptID = nil
        }

        private func determineFrameExtractionProfile() async -> FrameExtractionProfile {
            guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
                return FrameExtractionProfile(frameCount: 25, tolerance: .zero, strategyLabel: "default-no-track")
            }

            let estimatedDataRate = await (try? track.load(.estimatedDataRate)) ?? 0
            let pixelCount = naturalSize.width * naturalSize.height

            // Guardrail: heavier files (high resolution / high bitrate) get lighter extraction to keep UI responsive.
            if pixelCount >= 7_000_000 || estimatedDataRate >= 80_000_000 {
                return FrameExtractionProfile(
                    frameCount: 12,
                    tolerance: CMTime(value: 1, timescale: 20),
                    strategyLabel: "very-heavy",
                )
            }

            if pixelCount >= 3_700_000 || estimatedDataRate >= 45_000_000 {
                return FrameExtractionProfile(
                    frameCount: 16,
                    tolerance: CMTime(value: 1, timescale: 30),
                    strategyLabel: "heavy",
                )
            }

            return FrameExtractionProfile(frameCount: 25, tolerance: .zero, strategyLabel: "default")
        }

        private func generateFrameThumbnails(
            frameCount: Int,
            totalSeconds: Double,
            tolerance: CMTime,
        ) async -> [CGImage] {
            let safeCount = max(frameCount, 1)
            let targetSize = CGSize(width: 120, height: 68)
            let inputURL = sourceURL

            return await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        let generator = AVAssetImageGenerator(asset: AVAsset(url: inputURL))
                        generator.appliesPreferredTrackTransform = true
                        generator.maximumSize = targetSize
                        generator.requestedTimeToleranceBefore = tolerance
                        generator.requestedTimeToleranceAfter = tolerance

                        var images: [CGImage] = []
                        images.reserveCapacity(safeCount)

                        for i in 0 ..< safeCount {
                            let progress = safeCount > 1 ? Double(i) / Double(safeCount - 1) : 0
                            let time = CMTime(seconds: totalSeconds * progress, preferredTimescale: 600)
                            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                                images.append(cgImage)
                            }
                        }

                        continuation.resume(returning: images)
                    }
                }
            }
        }

        // MARK: - Save State

        func markAsSaved() {
            hasUnsavedChanges = false
            initialTrimStart = trimStart
            initialTrimEnd = trimEnd
            initialClipTimeline = clipTimeline
            initialIsMuted = isMuted
            initialZoomSegments = zoomSegments
            initialSpeedSegments = speedSegments
            initialBackgroundStyle = backgroundStyle
            initialBackgroundPadding = backgroundPadding
            initialBackgroundShadowIntensity = backgroundShadowIntensity
            initialBackgroundCornerRadius = backgroundCornerRadius
            initialExportSettings = exportSettings
            initialCameraOverlayLayout = cameraOverlayLayout
            establishInitialCursorSettings()
            clearUndoHistory()
        }

        private func establishInitialCursorSettings() {
            initialShowsSyntheticCursor = showsSyntheticCursor
            initialShowsClickEffects = showsClickEffects
            initialShowsKeystrokes = showsKeystrokes
            initialCursorScale = cursorScale
            initialCursorSmoothingPreset = cursorSmoothingPreset
        }

        private func cursorSettingDidChange() {
            updateHasUnsavedChanges()
            recalculateEstimatedFileSize()
        }

        // MARK: - Undo/Redo Actions

        /// Record an action for undo support
        private func recordAction(_ action: EditorAction) {
            guard !isUndoingOrRedoing else { return }
            undoStack.append(action)
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
            redoStack.removeAll()
            updateUndoRedoState()
        }

        /// Undo the last action
        func undo() {
            guard let action = undoStack.popLast() else { return }
            DiagnosticLogger.shared.log(.debug, .editor, "Undo", context: ["stackDepth": "\(undoStack.count)"])
            isUndoingOrRedoing = true
            defer {
                isUndoingOrRedoing = false
                updateUndoRedoState()
            }

            switch action {
            case .trimStart(let old, let new):
                trimStart = old
                redoStack.append(.trimStart(old: new, new: old))

            case .trimEnd(let old, let new):
                trimEnd = old
                redoStack.append(.trimEnd(old: new, new: old))

            case .addZoom(let segment):
                zoomSegments.removeAll { $0.id == segment.id }
                if selectedZoomId == segment.id {
                    selectedZoomId = nil
                }
                redoStack.append(.removeZoom(segment: segment))

            case .removeZoom(let segment):
                zoomSegments.append(segment)
                redoStack.append(.addZoom(segment: segment))

            case .updateZoom(let old, let new):
                if let index = zoomSegments.firstIndex(where: { $0.id == new.id }) {
                    zoomSegments[index] = old
                }
                redoStack.append(.updateZoom(old: new, new: old))

            case .replaceImplicitZoomSegments(let old, let new):
                zoomSegments = old
                redoStack.append(.replaceImplicitZoomSegments(old: new, new: old))

            case .addSpeed(let segment):
                speedSegments.removeAll { $0.id == segment.id }
                if selectedSpeedId == segment.id {
                    selectedSpeedId = nil
                }
                redoStack.append(.removeSpeed(segment: segment))

            case .removeSpeed(let segment):
                speedSegments.append(segment)
                redoStack.append(.addSpeed(segment: segment))

            case .updateSpeed(let old, let new):
                if let index = speedSegments.firstIndex(where: { $0.id == new.id }) {
                    speedSegments[index] = old
                }
                redoStack.append(.updateSpeed(old: new, new: old))

            case .toggleMute(let old, _):
                isMuted = old
                redoStack.append(.toggleMute(old: !old, new: old))

            case .updateBackground(
                let oldStyle,
                let newStyle,
                let oldPadding,
                let newPadding,
                let oldShadow,
                let newShadow,
                let oldCorner,
                let newCorner,
            ):
                backgroundStyle = oldStyle
                backgroundPadding = oldPadding
                backgroundShadowIntensity = oldShadow
                backgroundCornerRadius = oldCorner
                redoStack.append(.updateBackground(
                    oldStyle: newStyle,
                    newStyle: oldStyle,
                    oldPadding: newPadding,
                    newPadding: oldPadding,
                    oldShadow: newShadow,
                    newShadow: oldShadow,
                    oldCorner: newCorner,
                    newCorner: oldCorner,
                ))

            case .replaceClipTimeline(let old, let new):
                applyClipTimeline(
                    old,
                    selectedID: old.segments.first?.id,
                    playheadTime: min(CMTimeGetSeconds(currentTime), old.duration),
                    recordUndo: false,
                )
                redoStack.append(.replaceClipTimeline(old: new, new: old))
            }
        }

        /// Redo the last undone action
        func redo() {
            guard let action = redoStack.popLast() else { return }
            DiagnosticLogger.shared.log(.debug, .editor, "Redo", context: ["stackDepth": "\(redoStack.count)"])
            isUndoingOrRedoing = true
            defer {
                isUndoingOrRedoing = false
                updateUndoRedoState()
            }

            switch action {
            case .trimStart(let old, let new):
                trimStart = old
                undoStack.append(.trimStart(old: new, new: old))

            case .trimEnd(let old, let new):
                trimEnd = old
                undoStack.append(.trimEnd(old: new, new: old))

            case .addZoom(let segment):
                zoomSegments.removeAll { $0.id == segment.id }
                if selectedZoomId == segment.id {
                    selectedZoomId = nil
                }
                undoStack.append(.removeZoom(segment: segment))

            case .removeZoom(let segment):
                zoomSegments.append(segment)
                undoStack.append(.addZoom(segment: segment))

            case .updateZoom(let old, let new):
                if let index = zoomSegments.firstIndex(where: { $0.id == new.id }) {
                    zoomSegments[index] = old
                }
                undoStack.append(.updateZoom(old: new, new: old))

            case .replaceImplicitZoomSegments(let old, let new):
                zoomSegments = old
                undoStack.append(.replaceImplicitZoomSegments(old: new, new: old))

            case .addSpeed(let segment):
                speedSegments.removeAll { $0.id == segment.id }
                if selectedSpeedId == segment.id {
                    selectedSpeedId = nil
                }
                undoStack.append(.removeSpeed(segment: segment))

            case .removeSpeed(let segment):
                speedSegments.append(segment)
                undoStack.append(.addSpeed(segment: segment))

            case .updateSpeed(let old, let new):
                if let index = speedSegments.firstIndex(where: { $0.id == new.id }) {
                    speedSegments[index] = old
                }
                undoStack.append(.updateSpeed(old: new, new: old))

            case .toggleMute(let old, _):
                isMuted = old
                undoStack.append(.toggleMute(old: !old, new: old))

            case .updateBackground(
                let oldStyle,
                let newStyle,
                let oldPadding,
                let newPadding,
                let oldShadow,
                let newShadow,
                let oldCorner,
                let newCorner,
            ):
                backgroundStyle = oldStyle
                backgroundPadding = oldPadding
                backgroundShadowIntensity = oldShadow
                backgroundCornerRadius = oldCorner
                undoStack.append(.updateBackground(
                    oldStyle: newStyle,
                    newStyle: oldStyle,
                    oldPadding: newPadding,
                    newPadding: oldPadding,
                    oldShadow: newShadow,
                    newShadow: oldShadow,
                    oldCorner: newCorner,
                    newCorner: oldCorner,
                ))

            case .replaceClipTimeline(let old, let new):
                applyClipTimeline(
                    old,
                    selectedID: old.segments.first?.id,
                    playheadTime: min(CMTimeGetSeconds(currentTime), old.duration),
                    recordUndo: false,
                )
                undoStack.append(.replaceClipTimeline(old: new, new: old))
            }
        }

        private func updateUndoRedoState() {
            canUndo = !undoStack.isEmpty
            canRedo = !redoStack.isEmpty
        }

        private func clearUndoHistory() {
            undoStack.removeAll()
            redoStack.removeAll()
            updateUndoRedoState()
        }

        // MARK: - File Operations

        /// Open the source file location in Finder
        func openInFinder() {
            let sourceAccess = SandboxFileAccessManager.shared.beginAccessingURL(sourceURL)
            defer { sourceAccess.stop() }
            NSWorkspace.shared.activateFileViewerSelecting([sourceURL])
        }

        /// Rename the source file
        func renameFile(to newName: String) throws {
            DiagnosticLogger.shared.log(
                .info,
                .editor,
                "Renaming file",
                context: ["from": sourceURL.lastPathComponent, "to": newName],
            )
            let oldSourceURL = sourceURL
            let directory = sourceURL.deletingLastPathComponent()
            let sourceAccess = SandboxFileAccessManager.shared.beginAccessingURL(oldSourceURL)
            let directoryAccess = SandboxFileAccessManager.shared.beginAccessingURL(directory)
            defer {
                sourceAccess.stop()
                directoryAccess.stop()
            }

            let ext = sourceURL.pathExtension
            let sanitizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !sanitizedName.isEmpty else {
                throw NSError(
                    domain: "VideoEditor",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Filename cannot be empty"],
                )
            }

            let newURL = directoryAccess.url.appendingPathComponent(sanitizedName).appendingPathExtension(ext)

            guard newURL != sourceURL else { return }

            guard !FileManager.default.fileExists(atPath: newURL.path) else {
                throw NSError(
                    domain: "VideoEditor",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "A file with this name already exists"],
                )
            }

            try FileManager.default.moveItem(at: sourceAccess.url, to: newURL)

            do {
                try RecordingMetadataStore.moveAssociation(from: oldSourceURL, to: newURL)
            } catch {
                DiagnosticLogger.shared.logError(.editor, error, "Metadata association move failed during rename")
                print(
                    "[RecordingMetadata] Failed to move metadata association during rename: \(error.localizedDescription)",
                )
            }

            sourceURL = newURL
            if originalURL == oldSourceURL {
                originalURL = newURL
            }
        }

        // MARK: - Zoom Management

        /// Add a new zoom segment at the specified time
        @discardableResult
        func addZoom(at time: TimeInterval) -> UUID {
            DiagnosticLogger.shared.log(
                .debug,
                .editor,
                "Adding zoom segment",
                context: ["time": String(format: "%.2f", time), "type": hasMouseTrackingData ? "auto" : "manual"],
            )
            let videoDuration = CMTimeGetSeconds(duration)
            let defaultZoomType: ZoomType = hasMouseTrackingData ? .auto : .manual
            let segment = ZoomSegment(
                startTime: max(0, time - ZoomSegment.defaultDuration / 2),
                duration: ZoomSegment.defaultDuration,
                zoomLevel: ZoomSegment.defaultZoomLevel,
                zoomCenter: CGPoint(x: 0.5, y: 0.5),
                zoomType: defaultZoomType,
            ).clamped(to: videoDuration)

            zoomSegments.append(segment)
            selectedZoomId = segment.id
            recordAction(.addZoom(segment: segment))
            return segment.id
        }

        /// Remove a zoom segment by ID
        func removeZoom(id: UUID) {
            DiagnosticLogger.shared.log(.debug, .editor, "Removing zoom segment", context: ["id": id.uuidString])
            guard let segment = zoomSegments.first(where: { $0.id == id }) else { return }
            zoomSegments.removeAll { $0.id == id }
            if selectedZoomId == id {
                selectedZoomId = nil
            }
            recordAction(.removeZoom(segment: segment))
        }

        /// Update zoom segment properties
        func updateZoom(
            id: UUID,
            startTime: TimeInterval? = nil,
            duration: TimeInterval? = nil,
            zoomLevel: CGFloat? = nil,
            zoomCenter: CGPoint? = nil,
            zoomType: ZoomType? = nil,
            followSpeed: Double? = nil,
            focusMargin: CGFloat? = nil,
            isEnabled: Bool? = nil,
            anchorMode: ZoomAnchorMode? = nil,
            boundsBias: CGFloat? = nil,
        ) {
            guard let index = zoomSegments.firstIndex(where: { $0.id == id }) else { return }

            var segment = zoomSegments[index]
            let videoDuration = CMTimeGetSeconds(self.duration)

            if let startTime {
                segment.startTime = max(0, min(startTime, videoDuration - ZoomSegment.minDuration))
            }
            if let duration {
                segment.duration = max(ZoomSegment.minDuration, min(duration, videoDuration - segment.startTime))
            }
            if let zoomLevel {
                segment.zoomLevel = max(ZoomSegment.minZoomLevel, min(zoomLevel, ZoomSegment.maxZoomLevel))
            }
            if let zoomCenter {
                segment.zoomCenter = CGPoint(
                    x: max(0, min(zoomCenter.x, 1)),
                    y: max(0, min(zoomCenter.y, 1)),
                )
            }
            if let zoomType {
                segment.zoomType = zoomType
                if zoomType == .manual {
                    segment.anchorMode = .pinned
                } else if segment.anchorMode == .pinned {
                    segment.anchorMode = .pointer
                }
            }
            if let anchorMode {
                segment.anchorMode = anchorMode
            }
            if let boundsBias {
                segment.boundsBias = min(max(boundsBias, 0), 1)
            }
            if let followSpeed {
                segment.followSpeed = AutoFocusSettings.clampFollowSpeed(followSpeed)
            }
            if let focusMargin {
                segment.focusMargin = AutoFocusSettings.clampFocusMargin(focusMargin)
            }
            if let isEnabled {
                segment.isEnabled = isEnabled
            }

            zoomSegments[index] = segment
        }

        func setZoomMode(id: UUID, zoomType: ZoomType) {
            guard zoomType != .auto || hasMouseTrackingData else { return }
            updateZoom(id: id, zoomType: zoomType)
        }

        func cameraState(
            at time: TimeInterval,
            transitionDuration: TimeInterval? = nil,
        ) -> VideoEditorCameraState {
            let effectiveDuration = ZoomCalculator.clampTransitionDuration(
                transitionDuration ?? zoomTransitionDuration,
            )
            return VideoEditorAutoFocusEngine.resolvedCameraState(
                at: time,
                segments: zoomSegments,
                autoFocusPaths: autoFocusPaths,
                transitionDuration: effectiveDuration,
                viewportTimeline: viewportTimeline,
            )
        }

        func autoFocusPath(for segment: ZoomSegment) -> [AutoFocusCameraSample] {
            autoFocusPaths[segment.id] ?? []
        }

        /// Regenerate implicit zoom segments from recorded clicks, preserving manual segments.
        func resynthesizeImplicitZoomSegments() {
            guard let metadata = recordingMetadata else { return }

            let videoDuration = CMTimeGetSeconds(duration)
            guard videoDuration.isFinite, videoDuration > 0 else { return }

            let previousSegments = zoomSegments
            let manualSegments = zoomSegments.filter { !$0.isImplicit }
            let synthesized = VideoEditorZoomSegmentSynthesizer.segments(
                from: metadata.mousePresses,
                duration: videoDuration,
            )
            let merged = (manualSegments + synthesized).sorted { $0.startTime < $1.startTime }
            guard merged != previousSegments else { return }

            zoomSegments = merged
            selectedZoomId = nil
            recordAction(.replaceImplicitZoomSegments(old: previousSegments, new: merged))
            DiagnosticLogger.shared.log(.info, .editor, "Resynthesized implicit zoom segments", context: [
                "implicitCount": "\(synthesized.count)",
                "manualPreserved": "\(manualSegments.count)",
            ])
        }

        /// Select a zoom segment
        func selectZoom(id: UUID?) {
            selectedZoomId = id
        }

        /// Select a zoom segment and open its configuration sidebar.
        func openZoomConfiguration(id: UUID) {
            guard zoomSegments.contains(where: { $0.id == id }) else { return }
            selectedZoomId = id
            isRightSidebarVisible = true
        }

        /// Toggle zoom enabled state
        func toggleZoomEnabled(id: UUID) {
            guard let index = zoomSegments.firstIndex(where: { $0.id == id }) else { return }
            zoomSegments[index].isEnabled.toggle()
        }

        // MARK: - Speed Segment Mutators (Timelapse)

        /// Clamp a desired absolute range to the trim window and to gaps between other enabled
        /// speed segments (no overlap). Returns nil when the remaining room is smaller than the
        /// minimum segment duration.
        private func clampedSpeedRange(
            _ range: ClosedRange<TimeInterval>,
            excluding id: UUID?,
        ) -> (start: TimeInterval, duration: TimeInterval)? {
            let lowerBound = CMTimeGetSeconds(trimStart)
            let upperBound = CMTimeGetSeconds(trimEnd)
            guard upperBound - lowerBound >= SpeedSegment.minDuration else { return nil }

            var start = max(lowerBound, range.lowerBound)
            var end = min(upperBound, range.upperBound)

            // Shrink against the nearest neighbouring segments so the result never overlaps.
            let neighbours = speedSegments.filter { $0.id != id && $0.isEnabled }
            let desiredMid = (start + end) / 2
            for other in neighbours {
                let oStart = max(lowerBound, other.startTime)
                let oEnd = min(upperBound, other.endTime)
                guard oEnd > oStart else { continue }
                // Neighbour fully precedes the desired midpoint → push our start past it.
                if oEnd <= desiredMid {
                    start = max(start, oEnd)
                } else if oStart >= desiredMid {
                    // Neighbour follows the midpoint → pull our end before it.
                    end = min(end, oStart)
                } else {
                    // Neighbour straddles the midpoint → no room.
                    return nil
                }
            }

            guard end - start >= SpeedSegment.minDuration else { return nil }
            return (start, end - start)
        }

        /// Add a speed segment centered at a time, using default duration + rate.
        @discardableResult
        func addSpeed(at time: TimeInterval) -> UUID? {
            let half = SpeedSegment.defaultDuration / 2
            return addSpeed(range: (time - half) ... (time + half), rate: SpeedSegment.defaultRate)
        }

        /// Add a speed segment for an explicit range + rate. Clamps to trim + neighbours.
        @discardableResult
        func addSpeed(range: ClosedRange<TimeInterval>, rate: Double) -> UUID? {
            guard let (start, duration) = clampedSpeedRange(range, excluding: nil) else {
                DiagnosticLogger.shared.log(.debug, .editor, "Speed segment add rejected (no room)")
                return nil
            }
            let segment = SpeedSegment(startTime: start, duration: duration, rate: SpeedSegment.clampRate(rate))
            DiagnosticLogger.shared.log(
                .debug,
                .editor,
                "Adding speed segment",
                context: ["start": String(format: "%.2f", start), "rate": String(format: "%.2f", segment.rate)],
            )
            speedSegments.append(segment)
            selectedSpeedId = segment.id
            recordAction(.addSpeed(segment: segment))
            return segment.id
        }

        /// Remove a speed segment by ID.
        func removeSpeed(id: UUID) {
            guard let segment = speedSegments.first(where: { $0.id == id }) else { return }
            DiagnosticLogger.shared.log(.debug, .editor, "Removing speed segment", context: ["id": id.uuidString])
            speedSegments.removeAll { $0.id == id }
            if selectedSpeedId == id {
                selectedSpeedId = nil
            }
            recordAction(.removeSpeed(segment: segment))
        }

        /// Update a speed segment's rate and/or range. Range changes are clamped against the trim
        /// window + neighbours; an update that loses all room is ignored.
        func updateSpeed(
            id: UUID,
            rate: Double? = nil,
            startTime: TimeInterval? = nil,
            duration: TimeInterval? = nil,
        ) {
            guard let index = speedSegments.firstIndex(where: { $0.id == id }) else { return }
            let old = speedSegments[index]
            var new = old

            if let rate {
                new.rate = SpeedSegment.clampRate(rate)
            }

            if startTime != nil || duration != nil {
                let desiredStart = startTime ?? old.startTime
                let desiredDuration = duration ?? old.duration
                guard let (clampedStart, clampedDuration) = clampedSpeedRange(
                    desiredStart ... (desiredStart + desiredDuration),
                    excluding: id,
                ) else { return }
                new.startTime = clampedStart
                new.duration = clampedDuration
            }

            guard new != old else { return }
            speedSegments[index] = new
            recordAction(.updateSpeed(old: old, new: new))
        }

        /// Select a speed segment (nil clears selection).
        func selectSpeed(id: UUID?) {
            selectedSpeedId = id
        }

        /// Toggle a speed segment's enabled state (undoable — affects output duration).
        func toggleSpeedEnabled(id: UUID) {
            guard let index = speedSegments.firstIndex(where: { $0.id == id }) else { return }
            let old = speedSegments[index]
            var new = old
            new.isEnabled.toggle()
            speedSegments[index] = new
            recordAction(.updateSpeed(old: old, new: new))
        }

        /// Remove every speed segment (undoable — records one removal per segment).
        func removeAllSpeeds() {
            let ids = speedSegments.map(\.id)
            for id in ids {
                removeSpeed(id: id)
            }
        }

        /// Currently selected speed segment, if any.
        var selectedSpeedSegment: SpeedSegment? {
            guard let id = selectedSpeedId else { return nil }
            return speedSegments.first { $0.id == id }
        }

        /// Get the active zoom segment at a given time (enabled segments only - for playback)
        func activeZoomSegment(at time: TimeInterval) -> ZoomSegment? {
            ZoomCalculator.activeSegment(at: time, in: zoomSegments)
        }

        /// Get any zoom segment at a given time (including disabled - for UI interaction)
        func zoomSegment(at time: TimeInterval) -> ZoomSegment? {
            zoomSegments.filter { $0.contains(time: time) }.last
        }

        /// Get the currently selected zoom segment
        var selectedZoomSegment: ZoomSegment? {
            guard let id = selectedZoomId else { return nil }
            return zoomSegments.first { $0.id == id }
        }

        /// Toggle zoom track visibility
        func toggleZoomTrackVisibility() {
            isZoomTrackVisible.toggle()
        }

        /// Toggle video info sidebar visibility
        func toggleVideoInfoSidebar() {
            isVideoInfoSidebarVisible.toggle()
        }

        /// Toggle the left background sidebar visibility.
        func toggleLeftSidebar() {
            isLeftSidebarVisible.toggle()
        }

        /// Toggle the right zoom configuration sidebar visibility.
        func toggleRightSidebar() {
            isRightSidebarVisible.toggle()
        }

        // MARK: - Export Settings Methods

        /// Update export settings and recalculate file size
        func updateExportSettings(_ settings: ExportSettings) {
            exportSettings = settings
            syncPlayerAudioWithExportSettings()
            recalculateEstimatedFileSize()
        }

        /// Recalculate estimated file size based on current settings
        func recalculateEstimatedFileSize() {
            Task { @MainActor in
                estimatedFileSize = await calculateEstimatedFileSize()
            }
        }

        /// Calculate estimated file size based on export settings
        private func calculateEstimatedFileSize() async -> Int64 {
            // Get source file size
            let sourceSize: Int64? = SandboxFileAccessManager.shared.withScopedAccess(to: sourceURL) {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
                      let sourceSize = attrs[.size] as? Int64
                else { return nil }
                return sourceSize
            }
            guard let sourceSize else { return 0 }

            // GIF mode: estimate based on pixel ratio
            if isGIF {
                let exportSize = exportSettings.exportSize(from: naturalSize)
                let originalPixels = naturalSize.width * naturalSize.height
                let newPixels = exportSize.width * exportSize.height
                let pixelRatio = originalPixels > 0 ? newPixels / originalPixels : 1.0
                let estimated = Double(sourceSize) * pixelRatio
                return Int64(max(estimated, 1024))
            }

            let sourceDuration = CMTimeGetSeconds(duration)
            guard sourceDuration > 0 else { return 0 }

            // Calculate trim ratio
            let trimmedDurationSec = CMTimeGetSeconds(trimmedDuration)
            let trimRatio = trimmedDurationSec / sourceDuration

            // Calculate dimension ratio (including background padding)
            let exportSize = exportSettings.exportSize(from: naturalSize)
            let originalPixels = naturalSize.width * naturalSize.height

            // Include background padding in canvas size calculation
            let canvasWidth: CGFloat
            let canvasHeight: CGFloat
            if backgroundStyle != .none && backgroundPadding > 0 {
                canvasWidth = exportSize.width + (backgroundPadding * 2)
                canvasHeight = exportSize.height + (backgroundPadding * 2)
            } else {
                canvasWidth = exportSize.width
                canvasHeight = exportSize.height
            }
            let canvasPixels = canvasWidth * canvasHeight
            let dimensionRatio = originalPixels > 0 ? canvasPixels / originalPixels : 1.0

            // Apply quality multiplier
            let qualityMultiplier = Double(exportSettings.quality.bitrateMultiplier)

            // Audio adjustment (rough estimate: audio is ~10% of file)
            let audioMultiplier = switch exportSettings.audioMode {
            case .mute: 0.9 // Remove audio portion
            case .keep, .custom: 1.0
            }

            // Calculate estimated size
            let estimated = Double(sourceSize) * trimRatio * dimensionRatio * qualityMultiplier * audioMultiplier
            return Int64(max(estimated, 1024)) // Minimum 1KB
        }

        // MARK: - Private Methods

        private func setupTimeObserver() {
            let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main,
            ) { [weak self] time in
                MainActor.assumeIsolated {
                    guard let self, !self.playbackState.isScrubbing else { return }
                    self.playbackState.setCurrentTime(time)

                    if self.usesClipComposition {
                        let end = CMTime(seconds: self.clipTimeline.duration, preferredTimescale: 600)
                        if CMTimeCompare(time, end) >= 0 {
                            self.pause()
                            self.seek(to: .zero)
                            return
                        }
                        if self.isPlaying, self.player.rate != 0 {
                            let desiredRate = self.currentPreviewRate(at: time)
                            if abs(self.player.rate - desiredRate) > 0.001 {
                                self.player.rate = desiredRate
                                self.cameraPlayer?.rate = desiredRate
                            }
                        }
                        return
                    }

                    // Stop at trim end
                    if CMTimeCompare(time, self.trimEnd) >= 0 {
                        self.pause()
                        self.seek(to: self.trimStart)
                        return
                    }

                    // Live timelapse preview: keep player.rate aligned with the speed segment under the
                    // playhead while playing. player.rate == 0 means paused → leave it.
                    if self.isPlaying, self.hasSpeedSegments, self.player.rate != 0 {
                        let desiredRate = self.currentPreviewRate(at: time)
                        if abs(self.player.rate - desiredRate) > 0.001 {
                            self.player.rate = desiredRate
                        }
                    }
                }
            }
        }

        private static func loadZoomTransitionDuration() -> TimeInterval {
            guard let stored = UserDefaults.standard.object(
                forKey: PreferencesKeys.videoEditorZoomTransitionDuration,
            ) as? Double else {
                return ZoomCalculator.defaultTransitionDuration
            }

            return ZoomCalculator.clampTransitionDuration(stored)
        }

        static func autoGenerateZoomOnOpen(defaults: UserDefaults = .standard) -> Bool {
            if defaults.object(forKey: PreferencesKeys.videoEditorAutoGenerateZoomOnOpen) == nil {
                return true
            }
            return defaults.bool(forKey: PreferencesKeys.videoEditorAutoGenerateZoomOnOpen)
        }

        private func applyInitialImplicitZoomSegmentsIfNeeded() {
            guard !isGIF,
                  zoomSegments.isEmpty,
                  Self.autoGenerateZoomOnOpen(),
                  let metadata = recordingMetadata,
                  !metadata.mousePresses.isEmpty
            else {
                return
            }

            let videoDuration = CMTimeGetSeconds(duration)
            guard videoDuration.isFinite, videoDuration > 0 else { return }

            let synthesized = VideoEditorZoomSegmentSynthesizer.segments(
                from: metadata.mousePresses,
                duration: videoDuration,
            )
            guard !synthesized.isEmpty else { return }

            zoomSegments = synthesized
            initialZoomSegments = synthesized
            rebuildAutoFocusPaths(for: synthesized)
            DiagnosticLogger.shared.log(.info, .editor, "Applied initial implicit zoom segments", context: [
                "count": "\(synthesized.count)",
                "clicks": "\(recordedClickCount)",
            ])
        }

        private func setupEndObserver() {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main,
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.pause()
                    self?.seek(to: self?.trimStart ?? .zero)
                }
            }
        }

        private func setupChangeTracking() {
            // Track trim and mute changes
            Publishers.CombineLatest3($trimStart, $trimEnd, $isMuted)
                .dropFirst(3)
                .sink { [weak self] _, _, _ in
                    self?.updateHasUnsavedChanges()
                    self?.recalculateEstimatedFileSize()
                }
                .store(in: &cancellables)

            // Track zoom changes - pass segments directly to avoid stale state reads
            $zoomSegments
                .removeDuplicates()
                .sink { [weak self] segments in
                    guard let self else { return }
                    rebuildAutoFocusPaths(for: segments)
                    // Pass segments directly from publisher to avoid timing issues
                    updateHasUnsavedChanges(currentZoomSegments: segments)
                }
                .store(in: &cancellables)

            // Track speed (timelapse) segment changes
            $speedSegments
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] _ in
                    self?.updateHasUnsavedChanges()
                    self?.recalculateEstimatedFileSize()
                }
                .store(in: &cancellables)

            // Track background changes
            Publishers.CombineLatest4(
                $backgroundStyle,
                $backgroundPadding,
                $backgroundShadowIntensity,
                $backgroundCornerRadius,
            )
            .dropFirst(4)
            .sink { [weak self] _, _, _, _ in
                self?.updateHasUnsavedChanges()
                self?.recalculateEstimatedFileSize()
            }
            .store(in: &cancellables)

            // Track export settings changes for file size estimation
            $exportSettings
                .dropFirst()
                .sink { [weak self] _ in
                    self?.updateHasUnsavedChanges()
                    self?.recalculateEstimatedFileSize()
                }
                .store(in: &cancellables)

            $cameraOverlayLayout
                .dropFirst()
                .sink { [weak self] layout in
                    self?.updateHasUnsavedChanges(currentCameraOverlayLayout: layout)
                }
                .store(in: &cancellables)
        }

        private func updateHasUnsavedChanges(
            currentZoomSegments: [ZoomSegment]? = nil,
            currentCameraOverlayLayout: VideoEditorCameraOverlayLayout? = nil,
        ) {
            // GIF mode: only track dimension changes
            if isGIF {
                let dimensionChanged = exportSettings.dimensionPreset != initialExportSettings.dimensionPreset
                    || exportSettings.customWidth != initialExportSettings.customWidth
                    || exportSettings.customHeight != initialExportSettings.customHeight
                hasUnsavedChanges = dimensionChanged
                return
            }

            let startChanged = CMTimeCompare(trimStart, initialTrimStart) != 0
            let endChanged = CMTimeCompare(trimEnd, initialTrimEnd) != 0
            let muteChanged = isMuted != initialIsMuted
            // Use passed segments if available, otherwise read from self
            let segments = currentZoomSegments ?? zoomSegments
            let zoomsChanged = segments != initialZoomSegments
            let speedsChanged = speedSegments != initialSpeedSegments
            let clipsChanged = clipTimeline != initialClipTimeline
            // Background changes
            let bgStyleChanged = backgroundStyle != initialBackgroundStyle
            let bgPaddingChanged = backgroundPadding != initialBackgroundPadding
            let bgShadowChanged = backgroundShadowIntensity != initialBackgroundShadowIntensity
            let bgCornerChanged = backgroundCornerRadius != initialBackgroundCornerRadius
            let backgroundChanged = bgStyleChanged || bgPaddingChanged || bgShadowChanged || bgCornerChanged
            let exportSettingsChanged = exportSettings != initialExportSettings
            let cameraLayout = currentCameraOverlayLayout ?? cameraOverlayLayout
            let cameraLayoutChanged = cameraLayout != initialCameraOverlayLayout
            let cursorChanged = showsSyntheticCursor != initialShowsSyntheticCursor
                || showsClickEffects != initialShowsClickEffects
                || showsKeystrokes != initialShowsKeystrokes
                || cursorScale != initialCursorScale
                || cursorSmoothingPreset != initialCursorSmoothingPreset

            hasUnsavedChanges = startChanged || endChanged || muteChanged || zoomsChanged || speedsChanged ||
                clipsChanged || backgroundChanged || exportSettingsChanged || cameraLayoutChanged || cursorChanged
        }

        private func prepareCameraPreview(trackID: CMPersistentTrackID) async {
            guard let tracks = try? await asset.loadTracks(withMediaType: .video),
                  let sourceTrack = tracks.first(where: { $0.trackID == trackID }) else { return }
            let composition = AVMutableComposition()
            guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: trackID),
                  let duration = try? await sourceTrack.load(.timeRange) else { return }
            do {
                try track.insertTimeRange(duration, of: sourceTrack, at: .zero)
                let item = AVPlayerItem(asset: composition)
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                cameraComposition = composition
                cameraPlayer = player
                await cameraPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
            } catch {
                DiagnosticLogger.shared.logError(.editor, error, "Camera preview preparation failed")
            }
        }

        private func clampTime(_ time: CMTime) -> CMTime {
            if usesClipComposition {
                let end = CMTime(seconds: clipTimeline.duration, preferredTimescale: 600)
                return CMTimeClampToRange(time, range: CMTimeRange(start: .zero, end: end))
            }
            return CMTimeClampToRange(time, range: CMTimeRange(start: trimStart, end: trimEnd))
        }

        private func formatTime(_ time: CMTime) -> String {
            let totalSeconds = Int(CMTimeGetSeconds(time))
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }

        // MARK: - Background Image Caching (Performance)

        /// Handle background style changes - load and cache images
        private func handleBackgroundStyleChange() {
            DiagnosticLogger.shared.log(
                .debug,
                .editor,
                "Background style changed",
                context: ["style": "\(backgroundStyle)"],
            )
            switch backgroundStyle {
            case .wallpaper(let url), .blurred(let url):
                loadBackgroundImage(from: url)
            default:
                cachedBackgroundImage = nil
                cachedBlurredImage = nil
                loadingBackgroundURL = nil
            }
        }

        /// Load and cache background image using SystemWallpaperManager
        private func loadBackgroundImage(from url: URL) {
            loadingBackgroundURL = url

            SystemWallpaperManager.shared.loadPreviewImage(for: url) { [weak self] image in
                Task { @MainActor in
                    guard let self else { return }
                    // Race condition guard: only apply if still loading this URL
                    guard self.loadingBackgroundURL == url else { return }

                    self.cachedBackgroundImage = image
                    self.loadingBackgroundURL = nil

                    // Pre-compute blur if needed
                    if case .blurred = self.backgroundStyle {
                        self.cachedBlurredImage = self.applyGaussianBlur(
                            to: image,
                            radius: WallpaperQualityConfig.blurRadius,
                        )
                    } else {
                        self.cachedBlurredImage = nil
                    }
                }
            }
        }

        private func loadRecordingMetadata() {
            guard !isGIF else {
                recordingMetadata = nil
                autoFocusPaths = [:]
                autoFocusPathInputs = [:]
                viewportTimeline = .identity
                pointerTimeline = .empty
                keystrokeCaptionTimeline = .empty
                return
            }

            recordingMetadata = Self.loadRecordingMetadata(for: sourceURL, originalURL: originalURL)
            applyOverlayToggleDefaults(from: recordingMetadata)

            rebuildAutoFocusPaths(for: zoomSegments)
        }

        private func applyOverlayToggleDefaults(from metadata: RecordingMetadata?) {
            let synthesized = metadata?.pointerSynthesized == true
            let hasMouseData = !(metadata?.mouseSamples.isEmpty ?? true)
            showsSyntheticCursor = synthesized && hasMouseData
            showsClickEffects = synthesized && hasMouseData
            showsKeystrokes = synthesized && hasMouseData && !(metadata?.keystrokes.isEmpty ?? true)
        }

        private func rebuildAutoFocusPaths(for segments: [ZoomSegment]) {
            guard let recordingMetadata, hasMouseTrackingData else {
                autoFocusPaths = [:]
                autoFocusPathInputs = [:]
                rebuildViewportTimeline(for: segments)
                return
            }

            var rebuiltPaths: [UUID: [AutoFocusCameraSample]] = [:]
            var rebuiltInputs: [UUID: AutoFocusPathInput] = [:]

            for segment in segments where segment.isAutoMode {
                let input = AutoFocusPathInput(segment: segment)
                rebuiltInputs[segment.id] = input

                if autoFocusPathInputs[segment.id] == input,
                   let cachedPath = autoFocusPaths[segment.id] {
                    rebuiltPaths[segment.id] = cachedPath
                    continue
                }

                let builtPath = VideoEditorAutoFocusEngine.buildPath(
                    from: recordingMetadata,
                    segment: segment,
                )
                rebuiltPaths[segment.id] = builtPath

                let metrics = VideoEditorAutoFocusEngine.evaluatePathQuality(
                    metadata: recordingMetadata,
                    segment: segment,
                    path: builtPath,
                )
                DiagnosticLogger.shared.log(.debug, .editor, "Auto-focus path rebuilt", context: [
                    "segmentId": segment.id.uuidString,
                    "sampleCount": "\(metrics.sampleCount)",
                    "lockAccuracy": String(format: "%.3f", metrics.lockAccuracy),
                    "visibilityRate": String(format: "%.3f", metrics.visibilityRate),
                    "meanError": String(format: "%.4f", metrics.meanError),
                ])
            }

            autoFocusPathInputs = rebuiltInputs
            autoFocusPaths = rebuiltPaths
            rebuildViewportTimeline(for: segments)
        }

        private func rebuildViewportTimeline(for segments: [ZoomSegment]) {
            let videoDuration = CMTimeGetSeconds(duration)
            let enabledSegments = segments.filter(\.isEnabled)
            guard videoDuration.isFinite, videoDuration > 0 else {
                viewportTimeline = .identity
                rebuildOverlayTimelines(duration: videoDuration)
                return
            }

            if enabledSegments.isEmpty {
                viewportTimeline = .identity
            } else {
                viewportTimeline = VideoEditorViewportTimeline.build(
                    segments: enabledSegments,
                    metadata: recordingMetadata,
                    duration: videoDuration,
                )
            }
            rebuildOverlayTimelines(duration: videoDuration)
        }

        private func rebuildOverlayTimelines(duration: TimeInterval) {
            guard duration.isFinite, duration > 0 else {
                pointerTimeline = .empty
                keystrokeCaptionTimeline = .empty
                return
            }
            pointerTimeline = VideoEditorPointerTimeline.build(
                metadata: recordingMetadata,
                duration: duration,
                smoothingPreset: cursorSmoothingPreset,
            )
            keystrokeCaptionTimeline = VideoEditorKeystrokeCaptionTimeline(
                events: recordingMetadata?.keystrokes ?? [],
            )
        }

        /// Apply Gaussian blur to image (computed once, reused during render)
        private func applyGaussianBlur(to image: NSImage?, radius: CGFloat) -> NSImage? {
            guard let image,
                  let tiffData = image.tiffRepresentation,
                  let ciImage = CIImage(data: tiffData) else { return nil }

            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(radius, forKey: kCIInputRadiusKey)

            guard let output = filter?.outputImage else { return nil }
            let croppedOutput = output.cropped(to: ciImage.extent)

            let rep = NSCIImageRep(ciImage: croppedOutput)
            let blurred = NSImage(size: rep.size)
            blurred.addRepresentation(rep)
            return blurred
        }

        // MARK: - Clip Timeline (Plan 110 / Phase C)

        func selectClip(id: UUID?) {
            selectedClipId = id
            if id != nil {
                selectedZoomId = nil
                selectedSpeedId = nil
            }
        }

        func splitClip(at editorTime: TimeInterval) {
            guard let result = clipTimeline.split(at: editorTime) else { return }
            applyClipTimeline(
                result.timeline,
                selectedID: result.selectedID,
                playheadTime: min(max(editorTime, 0), result.timeline.duration),
                recordUndo: true,
            )
        }

        func splitClipAtPlayhead() {
            splitClip(at: CMTimeGetSeconds(currentTime))
        }

        func deleteSelectedClip() {
            guard let selectedClipId,
                  let deletedRange = clipTimeline.editorRange(for: selectedClipId),
                  let next = clipTimeline.deleting(segmentID: selectedClipId) else {
                return
            }
            let seekTime = min(deletedRange.lowerBound, next.duration)
            let nextSelection = next.location(at: seekTime)?.segmentID ?? next.segments.last?.id
            applyClipTimeline(
                next,
                selectedID: nextSelection,
                playheadTime: seekTime,
                recordUndo: true,
            )
        }

        func setClipSpeed(_ speed: Double, forClipID id: UUID) {
            guard let segment = clipTimeline.segments.first(where: { $0.id == id }) else { return }
            let clamped = min(
                max(speed, VideoEditorClipSegment.minimumSpeed),
                VideoEditorClipSegment.maximumSpeed,
            )
            guard abs(segment.speed - clamped) > 0.000_001 else { return }
            var replacement = segment
            replacement.speed = clamped
            let next = clipTimeline.replacing(replacement)
            applyClipTimeline(
                next,
                selectedID: id,
                playheadTime: min(CMTimeGetSeconds(currentTime), next.duration),
                recordUndo: true,
            )
        }

        func resetClipTimeline(recordUndo: Bool = true) {
            let sourceSeconds = CMTimeGetSeconds(duration)
            guard sourceSeconds.isFinite, sourceSeconds > 0 else { return }
            let full = VideoEditorClipTimeline.full(sourceDuration: sourceSeconds)
            guard full != clipTimeline else { return }
            applyClipTimeline(
                full,
                selectedID: full.segments.first?.id,
                playheadTime: 0,
                recordUndo: recordUndo,
            )
        }

        private func applyClipTimeline(
            _ requestedTimeline: VideoEditorClipTimeline,
            selectedID: UUID?,
            playheadTime: TimeInterval,
            recordUndo: Bool,
        ) {
            let sourceSeconds = CMTimeGetSeconds(duration)
            let next = requestedTimeline.normalized(to: sourceSeconds)
            guard !next.segments.isEmpty, next != clipTimeline else { return }

            let previousTimeline = clipTimeline
            if recordUndo {
                recordAction(.replaceClipTimeline(old: previousTimeline, new: next))
            }

            pause()
            clipTimeline = next
            selectedClipId = selectedID.flatMap { id in
                next.segments.contains(where: { $0.id == id }) ? id : nil
            } ?? next.segments.first?.id

            rebuildAutoFocusPaths(for: zoomSegments)
            rebuildPlaybackAsset(preserving: min(max(playheadTime, 0), next.duration))
            updateHasUnsavedChanges()
        }

        private func syncTrimFromClipTimeline() {
            guard let first = clipTimeline.segments.first,
                  let last = clipTimeline.segments.last else { return }
            let newStart = CMTime(seconds: first.sourceStart, preferredTimescale: 600)
            let newEnd = CMTime(seconds: last.sourceEnd, preferredTimescale: 600)
            if CMTimeCompare(trimStart, newStart) != 0 {
                trimStart = newStart
            }
            if CMTimeCompare(trimEnd, newEnd) != 0 {
                trimEnd = newEnd
            }
        }

        func applyStylePreset(_ preset: VideoEditorStylePreset) {
            backgroundStyle = preset.backgroundStyle
            backgroundPadding = preset.backgroundPadding
            backgroundCornerRadius = preset.backgroundCornerRadius
            backgroundShadowIntensity = preset.backgroundShadowIntensity
            cursorScale = preset.cursorScale
        }

        private func rebuildPlaybackAsset(preserving editorTime: TimeInterval) {
            guard !isGIF else { return }
            let sourceSeconds = CMTimeGetSeconds(duration)
            guard sourceSeconds.isFinite, sourceSeconds > 0 else { return }

            let clampedTime = min(max(editorTime, 0), clipTimeline.duration)
            let seekTime = CMTime(seconds: clampedTime, preferredTimescale: 600)

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let playbackAsset: AVAsset = if usesClipComposition {
                        try VideoEditorCompositionBuilder.makeAsset(
                            from: asset,
                            clipTimeline: clipTimeline,
                            sourceDuration: sourceSeconds,
                        )
                    } else {
                        asset
                    }

                    let item = AVPlayerItem(asset: playbackAsset)
                    item.audioTimePitchAlgorithm = .spectral
                    player.replaceCurrentItem(with: item)
                    playbackState.setCurrentTime(seekTime)
                    player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)

                    if hasCameraTrack {
                        let sourceTime = sourceTime(atPlayhead: seekTime)
                        let cameraSeek = CMTime(seconds: sourceTime, preferredTimescale: 600)
                        cameraPlayer?.seek(to: cameraSeek, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                } catch {
                    DiagnosticLogger.shared.logError(.editor, error, "Clip playback rebuild failed")
                }
            }
        }
    }
#endif

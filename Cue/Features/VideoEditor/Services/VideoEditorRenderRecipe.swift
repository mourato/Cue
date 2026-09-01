#if CUE_VIDEO_MODULE
//
    //  VideoEditorRenderRecipe.swift
    //  Notinhas
//
    //  Canonical export recipe fingerprint for render cache (Plan 110 / Phase D).
//

    import AVFoundation
    import CryptoKit
    import Foundation

    struct VideoEditorRenderRecipe: Codable, Equatable, Sendable {
        static let schemaVersion = 1
        static let exporterImplementationVersion = 3

        var schemaVersion: Int
        var exporterImplementationVersion: Int
        var sourceFingerprint: String
        var trimStartValue: Int64
        var trimStartTimescale: Int32
        var trimEndValue: Int64
        var trimEndTimescale: Int32
        var clipSegments: [VideoEditorClipSegment]
        var zoomSegmentIDs: [UUID]
        var zoomSegmentPayload: Data
        var speedSegmentIDs: [UUID]
        var speedSegmentPayload: Data
        var exportQuality: String
        var exportDimensionPreset: String
        var exportCustomWidth: Int
        var exportCustomHeight: Int
        var exportAudioMode: String
        var backgroundPayload: Data
        var showsSyntheticCursor: Bool
        var showsClickEffects: Bool
        var showsKeystrokes: Bool
        var cursorScale: Double
        var cursorSmoothingPreset: VideoEditorCursorSmoothingPreset
        var exportContentMode: String
        var cameraOverlayLayoutPayload: Data

        @MainActor
        static func capture(from state: VideoEditorState, sourceFingerprint: String) -> VideoEditorRenderRecipe {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let zoomPayload = (try? encoder.encode(state.zoomSegments)) ?? Data()
            let speedPayload = (try? encoder.encode(state.speedSegments)) ?? Data()
            let backgroundPayload = (try? encoder.encode(VideoEditorStoredBackgroundStyle(from: state))) ?? Data()
            let cameraOverlayLayoutPayload = (try? encoder.encode(state.cameraOverlayLayout)) ?? Data()

            return VideoEditorRenderRecipe(
                schemaVersion: schemaVersion,
                exporterImplementationVersion: exporterImplementationVersion,
                sourceFingerprint: sourceFingerprint,
                trimStartValue: state.trimStart.value,
                trimStartTimescale: state.trimStart.timescale,
                trimEndValue: state.trimEnd.value,
                trimEndTimescale: state.trimEnd.timescale,
                clipSegments: state.clipTimeline.segments,
                zoomSegmentIDs: state.zoomSegments.map(\.id).sorted { $0.uuidString < $1.uuidString },
                zoomSegmentPayload: zoomPayload,
                speedSegmentIDs: state.speedSegments.map(\.id).sorted { $0.uuidString < $1.uuidString },
                speedSegmentPayload: speedPayload,
                exportQuality: state.exportSettings.quality.rawValue,
                exportDimensionPreset: state.exportSettings.dimensionPreset.rawValue,
                exportCustomWidth: state.exportSettings.customWidth,
                exportCustomHeight: state.exportSettings.customHeight,
                exportAudioMode: state.exportSettings.audioMode.rawValue,
                backgroundPayload: backgroundPayload,
                showsSyntheticCursor: state.showsSyntheticCursor,
                showsClickEffects: state.showsClickEffects,
                showsKeystrokes: state.showsKeystrokes,
                cursorScale: Double(state.cursorScale),
                cursorSmoothingPreset: state.cursorSmoothingPreset,
                exportContentMode: state.exportContentMode.rawValue,
                cameraOverlayLayoutPayload: cameraOverlayLayoutPayload,
            )
        }

        func cacheKey() -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(self) else { return UUID().uuidString }
            let digest = SHA256.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }

    struct VideoEditorStoredBackgroundStyle: Codable, Equatable, Sendable {
        var styleKind: String
        var padding: CGFloat
        var cornerRadius: CGFloat
        var shadowIntensity: CGFloat

        @MainActor
        init(from state: VideoEditorState) {
            padding = state.backgroundPadding
            cornerRadius = state.backgroundCornerRadius
            shadowIntensity = state.backgroundShadowIntensity
            styleKind = switch state.backgroundStyle {
            case .none: "none"
            case .gradient(let preset): "gradient:\(preset.rawValue)"
            case .wallpaper(let url): "wallpaper:\(url.path)"
            case .blurred(let url): "blurred:\(url.path)"
            case .solidColor: "solid"
            }
        }
    }

    enum VideoEditorSourceFingerprint {
        static func make(for url: URL) -> String {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            return "\(url.path)|\(size)|\(modified)"
        }
    }
#endif

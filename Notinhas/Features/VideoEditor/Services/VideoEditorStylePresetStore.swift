#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorStylePresetStore.swift
    //  Notinhas
//
    //  Named style presets for background, padding, radius, shadow, and cursor scale (Plan 110 / Phase D).
//

    import Combine
    import Foundation
    import SwiftUI

    struct VideoEditorStylePreset: Identifiable, Equatable, Sendable {
        static let defaultCursorScale: CGFloat = 1.7

        var id: UUID
        var name: String
        var backgroundStyle: BackgroundStyle
        var backgroundPadding: CGFloat
        var backgroundCornerRadius: CGFloat
        var backgroundShadowIntensity: CGFloat
        var cursorScale: CGFloat

        init(
            id: UUID = UUID(),
            name: String,
            backgroundStyle: BackgroundStyle = .none,
            backgroundPadding: CGFloat = 24,
            backgroundCornerRadius: CGFloat = 12,
            backgroundShadowIntensity: CGFloat = 0.35,
            cursorScale: CGFloat = Self.defaultCursorScale,
        ) {
            self.id = id
            self.name = name
            self.backgroundStyle = backgroundStyle
            self.backgroundPadding = backgroundPadding
            self.backgroundCornerRadius = backgroundCornerRadius
            self.backgroundShadowIntensity = backgroundShadowIntensity
            self.cursorScale = cursorScale
        }

        static let studioDefault = VideoEditorStylePreset(
            name: "Studio",
            backgroundStyle: .gradient(.bluePurple),
            backgroundPadding: 48,
            backgroundCornerRadius: 16,
            backgroundShadowIntensity: 0.4,
            cursorScale: defaultCursorScale,
        )
    }

    struct VideoEditorStoredStylePreset: Codable, Equatable, Sendable {
        enum Background: Codable, Equatable, Sendable {
            case none
            case gradient(String)
        }

        var id: UUID
        var name: String
        var background: Background
        var backgroundPadding: CGFloat
        var backgroundCornerRadius: CGFloat
        var backgroundShadowIntensity: CGFloat
        var cursorScale: CGFloat

        init(from preset: VideoEditorStylePreset) {
            id = preset.id
            name = preset.name
            switch preset.backgroundStyle {
            case .none:
                background = .none
            case .gradient(let gradient):
                background = .gradient(gradient.rawValue)
            default:
                background = .none
            }
            backgroundPadding = preset.backgroundPadding
            backgroundCornerRadius = preset.backgroundCornerRadius
            backgroundShadowIntensity = preset.backgroundShadowIntensity
            cursorScale = preset.cursorScale
        }

        var stylePreset: VideoEditorStylePreset {
            let backgroundStyle: BackgroundStyle = switch background {
            case .none: .none
            case .gradient(let raw):
                if let gradient = GradientPreset(rawValue: raw) {
                    .gradient(gradient)
                } else {
                    .none
                }
            }
            return VideoEditorStylePreset(
                id: id,
                name: name,
                backgroundStyle: backgroundStyle,
                backgroundPadding: backgroundPadding,
                backgroundCornerRadius: backgroundCornerRadius,
                backgroundShadowIntensity: backgroundShadowIntensity,
                cursorScale: cursorScale,
            )
        }
    }

    @MainActor
    final class VideoEditorStylePresetStore: ObservableObject {
        static let shared = VideoEditorStylePresetStore()

        private struct Library: Codable {
            var version: Int
            var presets: [VideoEditorStoredStylePreset]
            var activePresetID: UUID?
        }

        private static let libraryKey = "videoEditorStylePresetLibrary.v1"
        static let maximumNameLength = 48

        @Published private(set) var presets: [VideoEditorStylePreset]
        @Published private(set) var activePresetID: UUID?

        var activePreset: VideoEditorStylePreset? {
            guard let activePresetID else { return nil }
            return presets.first { $0.id == activePresetID }
        }

        private let defaults: UserDefaults

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
            let loaded = Self.loadLibrary(from: defaults)
            presets = (loaded.presets.isEmpty ? [VideoEditorStoredStylePreset(from: .studioDefault)] : loaded.presets)
                .map(\.stylePreset)
            activePresetID = loaded.activePresetID ?? presets.first?.id
            if loaded.presets.isEmpty {
                persist()
            }
        }

        func applyActivePreset(to state: VideoEditorState) {
            guard let preset = activePreset else { return }
            state.applyStylePreset(preset)
        }

        @discardableResult
        func savePreset(named rawName: String, from state: VideoEditorState) -> VideoEditorStylePreset? {
            let name = Self.normalizedName(rawName)
            guard !name.isEmpty, preset(named: name) == nil else { return nil }
            let preset = VideoEditorStylePreset(
                name: name,
                backgroundStyle: state.backgroundStyle,
                backgroundPadding: state.backgroundPadding,
                backgroundCornerRadius: state.backgroundCornerRadius,
                backgroundShadowIntensity: state.backgroundShadowIntensity,
                cursorScale: state.cursorScale,
            )
            presets.append(preset)
            persist()
            return preset
        }

        func setActivePreset(id: UUID?) {
            guard id == nil || presets.contains(where: { $0.id == id }) else { return }
            activePresetID = id
            persist()
        }

        func preset(named rawName: String) -> VideoEditorStylePreset? {
            let candidate = Self.normalizedName(rawName)
            guard !candidate.isEmpty else { return nil }
            return presets.first { Self.namesMatch($0.name, candidate) }
        }

        private func persist() {
            let library = Library(
                version: 1,
                presets: presets.map(VideoEditorStoredStylePreset.init),
                activePresetID: activePresetID,
            )
            if let data = try? JSONEncoder().encode(library) {
                defaults.set(data, forKey: Self.libraryKey)
            }
        }

        private static func loadLibrary(from defaults: UserDefaults) -> Library {
            guard let data = defaults.data(forKey: libraryKey),
                  let library = try? JSONDecoder().decode(Library.self, from: data) else {
                return Library(version: 1, presets: [], activePresetID: nil)
            }
            return library
        }

        private static func normalizedName(_ raw: String) -> String {
            String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumNameLength))
        }

        private static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
            lhs.compare(rhs, options: .caseInsensitive) == .orderedSame
        }
    }
#endif

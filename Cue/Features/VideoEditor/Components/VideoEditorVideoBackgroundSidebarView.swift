#if CUE_VIDEO_MODULE
//
    //  VideoEditorVideoBackgroundSidebarView.swift
    //  Notinhas
//
    //  Background customization sidebar for video editor
//

    import AppKit
    import SwiftUI
    import UniformTypeIdentifiers

    /// Sidebar content for video background and padding customization
    struct VideoBackgroundSidebarView: View {
        @ObservedObject var state: VideoEditorState
        @ObservedObject private var stylePresetStore = VideoEditorStylePresetStore.shared
        @StateObject private var wallpaperManager = SystemWallpaperManager.shared

        var body: some View {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    stylePresetSection
                    noneButton
                    gradientSection
                    wallpaperSection
                    colorSection

                    Divider()

                    slidersSection

                    Spacer(minLength: Spacing.lg)
                }
                .padding(Spacing.md)
            }
            .frame(maxHeight: .infinity)
        }

        // MARK: - Style Presets

        private var stylePresetSection: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VideoSidebarSectionHeader(title: L10n.VideoEditor.stylePresets)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(stylePresetStore.presets) { preset in
                            Button {
                                stylePresetStore.setActivePreset(id: preset.id)
                                state.applyStylePreset(preset)
                            } label: {
                                Text(preset.name)
                                    .font(Typography.labelMedium)
                                    .foregroundColor(SidebarColors.labelPrimary)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: Size.radiusSm)
                                            .fill(
                                                stylePresetStore.activePresetID == preset.id
                                                    ? Color.accentColor.opacity(0.28)
                                                    : SidebarColors.itemDefault,
                                            ),
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }

        // MARK: - None Button

        private var noneButton: some View {
            Button {
                state.backgroundStyle = .none
                state.backgroundPadding = 0
            } label: {
                Text(L10n.Common.none)
                    .font(Typography.labelMedium)
                    .foregroundColor(SidebarColors.labelPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Size.radiusSm)
                            .fill(state.backgroundStyle == .none ? Color.accentColor.opacity(0.3) : SidebarColors
                                .itemDefault),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Size.radiusSm)
                            .stroke(
                                state.backgroundStyle == .none ? Color.accentColor : Color.clear,
                                lineWidth: Size.strokeSelected,
                            ),
                    )
            }
            .buttonStyle(.plain)
        }

        // MARK: - Gradient Section

        private var gradientSection: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VideoSidebarSectionHeader(title: L10n.Common.gradients)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: GridConfig.gap),
                        count: GridConfig.backgroundColumns,
                    ),
                    spacing: GridConfig.gap,
                ) {
                    ForEach(GradientPreset.allCases) { preset in
                        VideoGradientPresetButton(
                            preset: preset,
                            isSelected: state.backgroundStyle == .gradient(preset),
                        ) {
                            if state.backgroundPadding <= 0 {
                                state.backgroundPadding = 24
                            }
                            state.backgroundStyle = .gradient(preset)
                        }
                    }
                }
            }
        }

        // MARK: - Wallpaper Section

        private var wallpaperSection: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VideoSidebarSectionHeader(title: L10n.Common.wallpapers)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: GridConfig.gap),
                        count: GridConfig.backgroundColumns,
                    ),
                    spacing: GridConfig.gap,
                ) {
                    // Bundled default wallpapers
                    ForEach(wallpaperManager.defaultWallpapers) { item in
                        VideoDefaultWallpaperButton(
                            item: item,
                            isSelected: isDefaultWallpaperSelected(item),
                        ) {
                            selectDefaultWallpaper(item)
                        }
                    }

                    // Custom wallpapers
                    ForEach(wallpaperManager.customWallpapers) { item in
                        VideoCustomWallpaperButton(
                            url: item.fullImageURL,
                            isSelected: isWallpaperUrlSelected(item.fullImageURL),
                            onRemove: {
                                removeCustomWallpaper(item)
                            },
                        ) {
                            selectCustomWallpaper(item)
                        }
                    }

                    // Add button
                    VideoAddWallpaperButton {
                        addCustomWallpaper()
                    }
                }

                // Loading indicator
                if wallpaperManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(L10n.AnnotateUI.loadingWallpapers)
                            .font(Typography.labelSmall)
                            .foregroundColor(SidebarColors.labelSecondary)
                    }
                }
            }
            .task {
                await wallpaperManager.loadDefaultWallpapers()
            }
        }

        // MARK: - Wallpaper Helpers

        private func isDefaultWallpaperSelected(_ item: SystemWallpaperManager.WallpaperItem) -> Bool {
            if case .wallpaper(let url) = state.backgroundStyle {
                return url == item.fullImageURL
            }
            return false
        }

        private func isWallpaperUrlSelected(_ url: URL) -> Bool {
            if case .wallpaper(let selectedUrl) = state.backgroundStyle {
                return selectedUrl == url
            }
            return false
        }

        private func selectDefaultWallpaper(_ item: SystemWallpaperManager.WallpaperItem) {
            if state.backgroundPadding <= 0 {
                state.backgroundPadding = 24
            }
            state.backgroundStyle = .wallpaper(item.fullImageURL)
        }

        private func selectCustomWallpaper(_ item: SystemWallpaperManager.WallpaperItem) {
            if state.backgroundPadding <= 0 {
                state.backgroundPadding = 24
            }
            state.backgroundStyle = .wallpaper(item.fullImageURL)
        }

        private func addCustomWallpaper() {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.image]
            panel.allowsMultipleSelection = false

            if panel.runModal() == .OK, let url = panel.url {
                if let item = wallpaperManager.addCustomWallpaper(url) {
                    selectCustomWallpaper(item)
                }
            }
        }

        private func removeCustomWallpaper(_ item: SystemWallpaperManager.WallpaperItem) {
            let url = item.fullImageURL
            wallpaperManager.removeCustomWallpaper(item)

            if case .wallpaper(let selectedUrl) = state.backgroundStyle, selectedUrl == url {
                state.backgroundStyle = .none
                state.backgroundPadding = 0
            }
        }

        // MARK: - Color Section

        private var colorSection: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VideoSidebarSectionHeader(title: L10n.Common.colors)
                VideoColorSwatchGrid(selectedColor: colorBinding)
            }
        }

        private var colorBinding: Binding<Color?> {
            Binding(
                get: {
                    if case .solidColor(let color) = state.backgroundStyle {
                        return color
                    }
                    return nil
                },
                set: { newColor in
                    if let color = newColor {
                        if state.backgroundPadding <= 0 {
                            state.backgroundPadding = 24
                        }
                        state.backgroundStyle = .solidColor(color)
                    }
                },
            )
        }

        // MARK: - Sliders Section

        private var slidersSection: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VideoSliderRow(
                    label: L10n.Common.padding,
                    value: Binding(
                        get: { state.backgroundPadding },
                        set: { newValue in
                            state.backgroundPadding = newValue
                            // Auto-apply white background when padding increases from 0
                            if newValue > 0, state.backgroundStyle == .none {
                                state.backgroundStyle = .solidColor(.white)
                            }
                        },
                    ),
                    range: 0 ... 300,
                )
                VideoSliderRow(label: L10n.Common.shadow, value: $state.backgroundShadowIntensity, range: 0 ... 1)
                VideoSliderRow(label: L10n.Common.corners, value: $state.backgroundCornerRadius, range: 0 ... 60)
            }
        }
    }
#endif

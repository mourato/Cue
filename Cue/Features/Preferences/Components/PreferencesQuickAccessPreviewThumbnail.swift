//
//  PreferencesQuickAccessPreviewThumbnail.swift
//  Notinhas
//
//  Screenshot-like thumbnail used by the Quick Access settings preview.
//

import SwiftUI

struct QuickAccessSettingsPreviewThumbnail: View {
    let width: CGFloat
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var lightWallpaperImage: NSImage?
    @State private var darkWallpaperImage: NSImage?

    /// Preview cards render near 200pt; 512px covers @2x with headroom while
    /// keeping the 6016px bundled wallpapers off the main thread and out of RSS.
    private static let thumbnailMaxPixelSize: CGFloat = 512

    private static func bundledWallpaperURL(named resourceName: String) -> URL? {
        [
            Bundle.main.url(forResource: resourceName, withExtension: "jpg", subdirectory: "Wallpapers"),
            Bundle.main.url(forResource: resourceName, withExtension: "jpg", subdirectory: "Resources/Wallpapers"),
            Bundle.main.url(forResource: resourceName, withExtension: "jpg"),
        ]
        .compactMap(\.self)
        .first
    }

    private static func downsampledWallpaper(named resourceName: String) async -> NSImage? {
        guard let url = bundledWallpaperURL(named: resourceName) else { return nil }
        return await SystemWallpaperManager.downsampledPreviewImage(at: url, maxPixelSize: thumbnailMaxPixelSize)
    }

    @MainActor
    private func loadWallpapers() async {
        guard lightWallpaperImage == nil, darkWallpaperImage == nil else { return }
        async let light = Self.downsampledWallpaper(named: "default-tahoe-light")
        async let dark = Self.downsampledWallpaper(named: "default-tahoe-dark")
        let (loadedLight, loadedDark) = await (light, dark)
        lightWallpaperImage = loadedLight
        darkWallpaperImage = loadedDark
    }

    private var previewWallpaperImage: NSImage? {
        switch colorScheme {
        case .dark:
            return darkWallpaperImage ?? lightWallpaperImage
        case .light:
            return lightWallpaperImage ?? darkWallpaperImage
        @unknown default:
            return lightWallpaperImage ?? darkWallpaperImage
        }
    }

    var body: some View {
        ZStack {
            wallpaperBackground

            LinearGradient(
                colors: [
                    Color.black.opacity(0.04),
                    Color.black.opacity(0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
        .frame(width: width, height: height)
        .clipped()
        .task {
            await loadWallpapers()
        }
    }

    @ViewBuilder
    private var wallpaperBackground: some View {
        if let image = previewWallpaperImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else {
            fallbackWallpaperGradient
        }
    }

    private var fallbackWallpaperGradient: some View {
        ZStack {
            LinearGradient(
                colors: fallbackGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            RoundedRectangle(cornerRadius: height * 0.7)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.72, blue: 1.0).opacity(0.52),
                            Color(red: 0.14, green: 0.54, blue: 1.0).opacity(0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: width * 0.78, height: height * 1.34)
                .rotationEffect(.degrees(-24))
                .offset(x: width * 0.28, y: -height * 0.08)
                .blur(radius: 5)
        }
    }

    private var fallbackGradientColors: [Color] {
        switch colorScheme {
        case .dark:
            return [
                Color(red: 0.02, green: 0.03, blue: 0.24),
                Color(red: 0.04, green: 0.26, blue: 0.78),
                Color(red: 0.58, green: 0.42, blue: 0.94),
            ]
        case .light:
            return [
                Color(red: 0.68, green: 0.84, blue: 0.98),
                Color(red: 0.88, green: 0.94, blue: 0.98),
                Color(red: 0.78, green: 0.74, blue: 0.96),
            ]
        @unknown default:
            return [
                Color(red: 0.68, green: 0.84, blue: 0.98),
                Color(red: 0.88, green: 0.94, blue: 0.98),
                Color(red: 0.78, green: 0.74, blue: 0.96),
            ]
        }
    }
}

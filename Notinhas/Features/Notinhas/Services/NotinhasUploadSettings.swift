import CoreGraphics
import Foundation
import ImageIO

enum NotinhasUploadImageFormat: String, CaseIterable, Identifiable, Sendable {
    case webp
    case jpeg
    case png

    private var metadata: (displayName: String, fileExtension: String, contentType: String) {
        switch self {
        case .webp: ("WebP", "webp", "image/webp")
        case .jpeg: ("JPEG", "jpg", "image/jpeg")
        case .png: ("PNG", "png", "image/png")
        }
    }

    var id: String {
        rawValue
    }

    var displayName: String {
        metadata.displayName
    }

    var fileExtension: String {
        metadata.fileExtension
    }

    var contentType: String {
        metadata.contentType
    }
}

struct NotinhasUploadEncodingSettings: Equatable, Sendable {
    static let defaultMaximumDimension = 2048
    static let defaultJPEGQuality = 0.9

    let optimizeImages: Bool
    let imageFormat: NotinhasUploadImageFormat
    let maximumDimension: Int
    let jpegQuality: Double

    @MainActor
    static func current(defaults: UserDefaults = .standard) -> Self {
        let storedDimension = (defaults.object(forKey: PreferencesKeys.uploadMaximumDimension) as? NSNumber)?
            .doubleValue
            ?? Double(defaultMaximumDimension)
        let storedQuality = (defaults.object(forKey: PreferencesKeys.uploadJPEGQuality) as? NSNumber)?.doubleValue
            ?? defaultJPEGQuality
        let format = defaults.string(forKey: PreferencesKeys.uploadImageFormat)
            .flatMap(NotinhasUploadImageFormat.init(rawValue:))
            ?? .webp

        return Self(
            optimizeImages: defaults.object(forKey: PreferencesKeys.uploadOptimizeImages) as? Bool ?? true,
            imageFormat: format,
            maximumDimension: min(max(Int(storedDimension.rounded()), 512), 8192),
            jpegQuality: min(max(storedQuality, 0.5), 1.0),
        )
    }
}

struct NotinhasEncodedImage: Equatable, Sendable {
    let data: Data
    let fileExtension: String
    let contentType: String
}

struct NotinhasPreparedUpload: Sendable {
    let url: URL
    private let cleanupURL: URL?

    var isTemporary: Bool {
        cleanupURL != nil
    }

    static func original(_ url: URL) -> Self {
        Self(url: url, cleanupURL: nil)
    }

    static func temporary(url: URL, cleanupURL: URL) -> Self {
        Self(url: url, cleanupURL: cleanupURL)
    }

    func cleanup() {
        guard let cleanupURL else { return }
        try? FileManager.default.removeItem(at: cleanupURL)
    }
}

enum NotinhasUploadEncodingError: Error {
    case invalidImageData
    case failedToCreateBitmap
    case failedToEncode
}

nonisolated enum NotinhasUploadImageEncoder {
    private static let optimizableExtensions: Set<String> = [
        "bmp", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp",
    ]

    static func encode(fileURL: URL, settings: NotinhasUploadEncodingSettings) throws -> NotinhasEncodedImage {
        let originalData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let originalExtension = fileURL.pathExtension.lowercased()

        guard settings.optimizeImages, optimizableExtensions.contains(originalExtension) else {
            return NotinhasEncodedImage(
                data: originalData,
                fileExtension: originalExtension.isEmpty ? "bin" : originalExtension,
                contentType: contentType(for: originalExtension),
            )
        }

        return try encode(imageData: originalData, settings: settings)
    }

    static func encode(imageData: Data, settings: NotinhasUploadEncodingSettings) throws -> NotinhasEncodedImage {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) == 1 else {
            throw NotinhasUploadEncodingError.invalidImageData
        }

        let image: CGImage? = if settings.optimizeImages {
            CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: settings.maximumDimension,
                ] as CFDictionary,
            )
        } else {
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        guard let image else { throw NotinhasUploadEncodingError.failedToCreateBitmap }

        return try encode(rasterImage: image, settings: settings)
    }

    static func encode(image: CGImage, settings: NotinhasUploadEncodingSettings) throws -> NotinhasEncodedImage {
        let image = settings.optimizeImages ? try downsample(image, maximumDimension: settings.maximumDimension) : image
        return try encode(rasterImage: image, settings: settings)
    }

    private static func encode(
        rasterImage image: CGImage,
        settings: NotinhasUploadEncodingSettings,
    ) throws -> NotinhasEncodedImage {
        let hasAlpha = switch image.alphaInfo {
        case .alphaOnly, .premultipliedFirst, .premultipliedLast, .first, .last:
            true
        case .none, .noneSkipFirst, .noneSkipLast:
            false
        @unknown default:
            true
        }

        // JPEG cannot carry transparency. WebP preserves it without changing the local source.
        let format: NotinhasUploadImageFormat = if settings.optimizeImages {
            hasAlpha && settings.imageFormat == .jpeg ? .webp : settings.imageFormat
        } else {
            // The in-memory Annotate render has no source URL to pass through.
            // Use lossless PNG when optimization is disabled.
            .png
        }
        let encodedData: Data?

        switch format {
        case .webp:
            encodedData = WebPEncoderService.encode(image, quality: CGFloat(settings.jpegQuality))
        case .jpeg, .png:
            let destinationData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                destinationData,
                format == .jpeg ? "public.jpeg" as CFString : "public.png" as CFString,
                1,
                nil,
            ) else {
                throw NotinhasUploadEncodingError.failedToCreateBitmap
            }

            let properties: CFDictionary? = if format == .jpeg {
                [kCGImageDestinationLossyCompressionQuality: settings.jpegQuality] as CFDictionary
            } else {
                nil
            }
            CGImageDestinationAddImage(destination, image, properties)
            encodedData = CGImageDestinationFinalize(destination) ? destinationData as Data : nil
        }

        guard let encodedData, !encodedData.isEmpty else {
            throw NotinhasUploadEncodingError.failedToEncode
        }

        return NotinhasEncodedImage(
            data: encodedData,
            fileExtension: format.fileExtension,
            contentType: format.contentType,
        )
    }

    private static func downsample(_ image: CGImage, maximumDimension: Int) throws -> CGImage {
        let largestDimension = max(image.width, image.height)
        guard largestDimension > maximumDimension else { return image }

        let scale = Double(maximumDimension) / Double(largestDimension)
        let targetWidth = max(1, Int((Double(image.width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(image.height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: targetWidth,
                  height: targetHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
              ) else {
            throw NotinhasUploadEncodingError.failedToCreateBitmap
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let resizedImage = context.makeImage() else {
            throw NotinhasUploadEncodingError.failedToCreateBitmap
        }
        return resizedImage
    }

    static func prepare(
        fileURL: URL,
        settings: NotinhasUploadEncodingSettings,
    ) async throws -> NotinhasPreparedUpload {
        guard settings.optimizeImages, optimizableExtensions.contains(fileURL.pathExtension.lowercased()) else {
            return .original(fileURL)
        }

        let encoded = try await Task.detached(priority: .userInitiated) {
            try encode(fileURL: fileURL, settings: settings)
        }.value

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotinhasUpload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let originalBaseName = fileURL.deletingPathExtension().lastPathComponent
        let baseName = originalBaseName.isEmpty ? "image" : originalBaseName
        let temporaryURL = temporaryDirectory
            .appendingPathComponent("\(baseName).\(encoded.fileExtension)")

        do {
            try encoded.data.write(to: temporaryURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        }

        return .temporary(url: temporaryURL, cleanupURL: temporaryDirectory)
    }

    private static func contentType(for fileExtension: String) -> String {
        switch fileExtension {
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "webp": "image/webp"
        case "gif": "image/gif"
        case "heic": "image/heic"
        case "heif": "image/heif"
        case "bmp": "image/bmp"
        case "tif", "tiff": "image/tiff"
        default: "application/octet-stream"
        }
    }
}

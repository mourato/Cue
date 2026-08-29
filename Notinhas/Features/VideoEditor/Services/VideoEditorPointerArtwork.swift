#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorPointerArtwork.swift
    //  Notinhas
//
    //  Metrics and rendering helpers for recorded pointer artwork.
//

    import AppKit
    import CoreGraphics
    import Foundation

    enum VideoEditorPointerArtworkMetrics {
        static let heightRatio: CGFloat = 0.032
    }

    extension RecordedPointerArtwork {
        var normalizedAnchor: CGPoint {
            let width = max(referenceSize.width, 1)
            let height = max(referenceSize.height, 1)
            return CGPoint(
                x: min(max(anchorPoint.x / width, 0), 1),
                y: min(max(anchorPoint.y / height, 0), 1),
            )
        }

        var aspectRatio: CGFloat {
            guard referenceSize.width > 0, referenceSize.height > 0 else { return 1 }
            return CGFloat(referenceSize.width / referenceSize.height)
        }

        var intrinsicScale: CGFloat {
            guard referenceSize.height > 0 else { return 1 }
            return min(max(CGFloat(referenceSize.height / 16), 0.75), 2.5)
        }
    }

    enum VideoEditorPointerArtworkCache {
        static func image(for artwork: RecordedPointerArtwork) -> NSImage? {
            let cacheKey = "\(artwork.artworkID)-\(artwork.imageData.hashValue)"
            if let cached = cache[cacheKey] {
                return cached
            }
            guard let image = NSImage(data: artwork.imageData) else { return nil }
            cache[cacheKey] = image
            return image
        }

        static func cgImage(for artwork: RecordedPointerArtwork) -> CGImage? {
            guard let image = image(for: artwork),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }
            return cgImage
        }

        private nonisolated(unsafe) static var cache: [String: NSImage] = [:]
    }
#endif

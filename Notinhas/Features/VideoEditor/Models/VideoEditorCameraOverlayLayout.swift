#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    import CoreGraphics
    import Foundation

    enum VideoEditorCameraOverlayPosition: String, Codable, CaseIterable, Identifiable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
        var id: String {
            rawValue
        }
    }

    enum VideoEditorCameraOverlaySize: String, Codable, CaseIterable, Identifiable {
        case small, medium, large
        var id: String {
            rawValue
        }

        var fraction: CGFloat {
            switch self { case .small: 0.22
            case .medium: 0.30
            case .large: 0.38 }
        }
    }

    struct VideoEditorCameraOverlayLayout: Codable, Equatable {
        var isVisible = true
        var position: VideoEditorCameraOverlayPosition = .bottomTrailing
        var size: VideoEditorCameraOverlaySize = .small
        var margin: CGFloat = 0.04

        static let `default` = Self()

        func normalizedRect(canvasSize: CGSize, cameraSize: CGSize) -> CGRect {
            guard canvasSize.width > 0, canvasSize.height > 0,
                  cameraSize.width > 0, cameraSize.height > 0 else { return .zero }
            let width = min(size.fraction, 1)
            let aspect = cameraSize.width / cameraSize.height
            let height = min(width / max(aspect * canvasSize.width / canvasSize.height, 0.01), 1)
            let x = position == .topTrailing || position == .bottomTrailing ? 1 - margin - width : margin
            let y = position == .bottomLeading || position == .bottomTrailing ? 1 - margin - height : margin
            return CGRect(x: x, y: y, width: width, height: height).standardized.clampedToUnitRect()
        }

        func frame(in canvasSize: CGSize, cameraSize: CGSize) -> CGRect {
            normalizedRect(canvasSize: canvasSize, cameraSize: cameraSize)
                .applying(CGAffineTransform(scaleX: canvasSize.width, y: canvasSize.height))
        }

        func cameraFrame(in canvasSize: CGSize, cameraSize: CGSize) -> CGRect {
            let target = frame(in: canvasSize, cameraSize: cameraSize)
            let fitted = VideoEditorExportLayout.aspectFitRect(sourceSize: cameraSize, in: target.size)
            return CGRect(x: target.minX + fitted.minX, y: target.minY + fitted.minY,
                          width: fitted.width, height: fitted.height)
        }
    }

    private extension CGRect {
        func clampedToUnitRect() -> CGRect {
            let x = min(max(minX, 0), 1), y = min(max(minY, 0), 1)
            return CGRect(x: x, y: y, width: min(width, 1 - x), height: min(height, 1 - y))
        }
    }

    struct VideoEditorVideoTrackResolution: Equatable {
        let screenTrackID: CMPersistentTrackID
        let cameraTrackID: CMPersistentTrackID?
        let cameraSize: CGSize?
        let cameraIsMirrored: Bool
        let cameraMetadataWasInvalid: Bool
    }
#endif

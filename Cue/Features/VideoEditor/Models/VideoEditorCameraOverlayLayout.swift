#if CUE_VIDEO_MODULE
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
        case small, medium, large, huge
        var id: String {
            rawValue
        }

        var fraction: CGFloat {
            switch self {
            case .small: 0.28
            case .medium: 0.34
            case .large: 0.42
            case .huge: 0.50
            }
        }
    }

    struct VideoEditorCameraOverlayLayout: Codable, Equatable {
        var isVisible = true
        var position: VideoEditorCameraOverlayPosition = .bottomTrailing {
            didSet {
                if position != oldValue, let capturedNormalizedRect {
                    self.capturedNormalizedRect = Self.anchoredRect(
                        capturedNormalizedRect,
                        position: position,
                        margin: margin,
                    )
                }
            }
        }

        var size: VideoEditorCameraOverlaySize = .small {
            didSet {
                if size != oldValue, let capturedNormalizedRect {
                    self.capturedNormalizedRect = Self.resizedRect(
                        capturedNormalizedRect,
                        size: size,
                    )
                }
            }
        }

        var margin: CGFloat = 0.04 {
            didSet {
                if margin != oldValue, let capturedNormalizedRect {
                    self.capturedNormalizedRect = Self.anchoredRect(
                        capturedNormalizedRect,
                        position: position,
                        margin: margin,
                    )
                }
            }
        }

        var reactsToZoom = true
        var shape: RecordingCameraPreviewShape = .rectangle {
            didSet {
                if shape != oldValue, let capturedNormalizedRect {
                    self.capturedNormalizedRect = Self.reshapedRect(
                        capturedNormalizedRect,
                        from: oldValue,
                        to: shape,
                    )
                }
            }
        }

        var capturedNormalizedRect: CGRect?

        static let `default` = Self()

        private enum CodingKeys: String, CodingKey {
            case isVisible
            case position
            case size
            case margin
            case reactsToZoom
            case shape
            case capturedNormalizedRect
        }

        init(
            isVisible: Bool = true,
            position: VideoEditorCameraOverlayPosition = .bottomTrailing,
            size: VideoEditorCameraOverlaySize = .small,
            margin: CGFloat = 0.04,
            reactsToZoom: Bool = true,
            shape: RecordingCameraPreviewShape = .rectangle,
            capturedNormalizedRect: CGRect? = nil,
        ) {
            self.isVisible = isVisible
            self.position = position
            self.size = size
            self.margin = margin
            self.reactsToZoom = reactsToZoom
            self.shape = shape
            self.capturedNormalizedRect = capturedNormalizedRect
        }

        init(recordedLayout: RecordedCameraOverlayLayout) {
            self.init(
                size: recordedLayout.size
                    .map { VideoEditorCameraOverlaySize(rawValue: $0.rawValue) ?? .small } ?? .small,
                shape: recordedLayout.shape,
                capturedNormalizedRect: recordedLayout.normalizedRect,
            )
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
            position = try container.decodeIfPresent(VideoEditorCameraOverlayPosition.self, forKey: .position)
                ?? .bottomTrailing
            size = try container.decodeIfPresent(VideoEditorCameraOverlaySize.self, forKey: .size) ?? .small
            margin = try container.decodeIfPresent(CGFloat.self, forKey: .margin) ?? 0.04
            reactsToZoom = try container.decodeIfPresent(Bool.self, forKey: .reactsToZoom) ?? true
            shape = try container.decodeIfPresent(RecordingCameraPreviewShape.self, forKey: .shape) ?? .rectangle
            capturedNormalizedRect = try container.decodeIfPresent(CGRect.self, forKey: .capturedNormalizedRect)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(isVisible, forKey: .isVisible)
            try container.encode(position, forKey: .position)
            try container.encode(size, forKey: .size)
            try container.encode(margin, forKey: .margin)
            try container.encode(reactsToZoom, forKey: .reactsToZoom)
            try container.encode(shape, forKey: .shape)
            try container.encodeIfPresent(capturedNormalizedRect, forKey: .capturedNormalizedRect)
        }

        var usesCapturedGeometry: Bool {
            sanitizedCapturedNormalizedRect != nil
        }

        func normalizedRect(canvasSize: CGSize, cameraSize: CGSize) -> CGRect {
            guard canvasSize.width > 0, canvasSize.height > 0,
                  cameraSize.width > 0, cameraSize.height > 0 else { return .zero }

            if let sanitizedCapturedNormalizedRect {
                return sanitizedCapturedNormalizedRect
            }

            let width = min(size.fraction, 1)
            let aspect = cameraSize.width / cameraSize.height
            let height = min(width / max(aspect * canvasSize.width / canvasSize.height, 0.01), 1)
            return Self.anchoredRect(
                CGRect(x: 0, y: 0, width: width, height: height),
                position: position,
                margin: margin,
            )
        }

        func frame(in canvasSize: CGSize, cameraSize: CGSize) -> CGRect {
            normalizedRect(canvasSize: canvasSize, cameraSize: cameraSize)
                .applying(CGAffineTransform(scaleX: canvasSize.width, y: canvasSize.height))
        }

        func cameraFrame(in canvasSize: CGSize, cameraSize: CGSize) -> CGRect {
            let target = frame(in: canvasSize, cameraSize: cameraSize)
            let fitted = VideoEditorExportLayout.aspectFitRect(sourceSize: cameraSize, in: target.size)
            if usesCapturedGeometry {
                return target
            }
            return CGRect(x: target.minX + fitted.minX, y: target.minY + fitted.minY,
                          width: fitted.width, height: fitted.height)
        }

        func cameraFrame(in canvasSize: CGSize, cameraSize: CGSize, zoomLevel: CGFloat) -> CGRect {
            let sanitizedZoomLevel = zoomLevel.isFinite ? max(zoomLevel, 1) : 1
            guard reactsToZoom, sanitizedZoomLevel > 1 else {
                return cameraFrame(in: canvasSize, cameraSize: cameraSize)
            }

            let baseRect = normalizedRect(canvasSize: canvasSize, cameraSize: cameraSize)
            let width = baseRect.width / sanitizedZoomLevel
            let height = baseRect.height / sanitizedZoomLevel
            let x: CGFloat
            let y: CGFloat
            if usesCapturedGeometry {
                x = baseRect.midX - width / 2
                y = baseRect.midY - height / 2
            } else {
                x = position == .topTrailing || position == .bottomTrailing
                    ? baseRect.maxX - width
                    : baseRect.minX
                y = position == .bottomLeading || position == .bottomTrailing
                    ? baseRect.maxY - height
                    : baseRect.minY
            }
            let target = CGRect(x: x, y: y, width: width, height: height)
                .standardized
                .clampedToUnitRect()
                .applying(CGAffineTransform(scaleX: canvasSize.width, y: canvasSize.height))
            let fitted = VideoEditorExportLayout.aspectFitRect(sourceSize: cameraSize, in: target.size)
            if usesCapturedGeometry {
                return target
            }
            return CGRect(x: target.minX + fitted.minX, y: target.minY + fitted.minY,
                          width: fitted.width, height: fitted.height)
        }

        private var sanitizedCapturedNormalizedRect: CGRect? {
            guard let rect = capturedNormalizedRect,
                  rect.minX.isFinite,
                  rect.minY.isFinite,
                  rect.maxX.isFinite,
                  rect.maxY.isFinite,
                  rect.width.isFinite,
                  rect.height.isFinite,
                  rect.width > 0,
                  rect.height > 0
            else { return nil }

            let clamped = rect.standardized.clampedToUnitRect()
            return clamped.width > 0 && clamped.height > 0 ? clamped : nil
        }

        private static func anchoredRect(
            _ rect: CGRect,
            position: VideoEditorCameraOverlayPosition,
            margin: CGFloat,
        ) -> CGRect {
            let safeMargin = min(max(margin, 0), 1)
            // An oversized margin falls back to edge placement to preserve the selected corner.
            let horizontalMargin = safeMargin <= 1 - rect.width ? safeMargin : 0
            let verticalMargin = safeMargin <= 1 - rect.height ? safeMargin : 0
            let x = position == .topTrailing || position == .bottomTrailing
                ? 1 - horizontalMargin - rect.width
                : horizontalMargin
            let y = position == .bottomLeading || position == .bottomTrailing
                ? 1 - verticalMargin - rect.height
                : verticalMargin
            return CGRect(x: x, y: y, width: rect.width, height: rect.height)
                .standardized
                .clampedToUnitRect()
        }

        private static func resizedRect(
            _ rect: CGRect,
            size: VideoEditorCameraOverlaySize,
        ) -> CGRect {
            let width = min(size.fraction, 1)
            let height = width * rect.height / max(rect.width, 0.0001)
            return centeredRect(width: width, height: height, at: rect.midX, y: rect.midY)
        }

        private static func reshapedRect(
            _ rect: CGRect,
            from oldShape: RecordingCameraPreviewShape,
            to newShape: RecordingCameraPreviewShape,
        ) -> CGRect {
            let height = rect.height * oldShape.aspectRatio / max(newShape.aspectRatio, 0.0001)
            return centeredRect(width: rect.width, height: height, at: rect.midX, y: rect.midY)
        }

        private static func centeredRect(width: CGFloat, height: CGFloat, at x: CGFloat, y: CGFloat) -> CGRect {
            CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
                .standardized
                .clampedToUnitRect()
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

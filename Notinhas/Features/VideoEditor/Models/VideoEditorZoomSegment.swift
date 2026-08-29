#if NOTINHAS_VIDEO_MODULE
//
    //  ZoomSegment.swift
    //  Notinhas
//
    //  Data model for zoom segments in video timeline
//

    import Foundation

    /// Represents a zoom effect segment on the video timeline
    struct ZoomSegment: Identifiable, Codable, Equatable, Hashable {
        let id: UUID
        var startTime: TimeInterval // seconds from video start
        var duration: TimeInterval // zoom duration in seconds
        var zoomLevel: CGFloat // 1.0 (100%) to 4.0 (400%)
        var zoomCenter: CGPoint // normalized 0-1 for x,y position
        var zoomType: ZoomType
        var followSpeed: Double
        var focusMargin: CGFloat
        var isEnabled: Bool
        var isImplicit: Bool
        var anchorMode: ZoomAnchorMode
        var boundsBias: CGFloat
        var skipsEasing: Bool

        // MARK: - Computed Properties

        var endTime: TimeInterval {
            startTime + duration
        }

        // MARK: - Constants

        static let defaultDuration: TimeInterval = 2.0
        static let defaultZoomLevel: CGFloat = 2.0
        static let minDuration: TimeInterval = 0.5
        static let maxDuration: TimeInterval = 30.0
        static let minZoomLevel: CGFloat = 1.0
        static let maxZoomLevel: CGFloat = 4.0

        // MARK: - Initialization

        init(
            id: UUID = UUID(),
            startTime: TimeInterval,
            duration: TimeInterval = ZoomSegment.defaultDuration,
            zoomLevel: CGFloat = ZoomSegment.defaultZoomLevel,
            zoomCenter: CGPoint = CGPoint(x: 0.5, y: 0.5),
            zoomType: ZoomType = .manual,
            followSpeed: Double = AutoFocusSettings.defaultFollowSpeed,
            focusMargin: CGFloat = AutoFocusSettings.defaultFocusMargin,
            isEnabled: Bool = true,
            isImplicit: Bool = false,
            anchorMode: ZoomAnchorMode? = nil,
            boundsBias: CGFloat = 0.25,
            skipsEasing: Bool = false,
        ) {
            self.id = id
            self.startTime = max(0, startTime)
            self.duration = max(Self.minDuration, min(duration, Self.maxDuration))
            self.zoomLevel = max(Self.minZoomLevel, min(zoomLevel, Self.maxZoomLevel))
            self.zoomCenter = CGPoint(
                x: max(0, min(zoomCenter.x, 1)),
                y: max(0, min(zoomCenter.y, 1)),
            )
            self.zoomType = zoomType
            self.followSpeed = AutoFocusSettings.clampFollowSpeed(followSpeed)
            self.focusMargin = AutoFocusSettings.clampFocusMargin(focusMargin)
            self.isEnabled = isEnabled
            self.isImplicit = isImplicit
            self.anchorMode = anchorMode ?? (zoomType == .auto ? .pointer : .pinned)
            self.boundsBias = boundsBias.clamped(to: 0 ... 1)
            self.skipsEasing = skipsEasing
        }

        // MARK: - Validation

        /// Check if a given time falls within this zoom segment
        func contains(time: TimeInterval) -> Bool {
            time >= startTime && time < endTime
        }

        /// Check if this segment overlaps with another
        func overlaps(with other: ZoomSegment) -> Bool {
            startTime < other.endTime && endTime > other.startTime
        }

        /// Clamp segment to video duration
        func clamped(to videoDuration: TimeInterval) -> ZoomSegment {
            var clamped = self
            clamped.startTime = max(0, min(startTime, videoDuration - Self.minDuration))
            clamped.duration = min(duration, videoDuration - clamped.startTime)
            return clamped
        }
    }

    // MARK: - Zoom Type

    enum ZoomType: String, Codable, CaseIterable, Equatable {
        case auto // follow recorded mouse path within the zoom item's range
        case manual // user-defined camera framing

        var displayName: String {
            switch self {
            case .auto: L10n.VideoEditor.auto
            case .manual: L10n.VideoEditor.manual
            }
        }

        var iconName: String {
            switch self {
            case .auto: "cursorarrow.click"
            case .manual: "hand.tap"
            }
        }
    }

    enum ZoomAnchorMode: String, Codable, CaseIterable, Equatable {
        case pointer
        case smart
        case pinned

        var displayName: String {
            switch self {
            case .pointer: L10n.VideoEditor.anchorPointer
            case .smart: L10n.VideoEditor.anchorSmart
            case .pinned: L10n.VideoEditor.anchorPinned
            }
        }
    }

    // MARK: - Zoom Segment Extensions

    extension ZoomSegment {
        var autoFocusSettings: AutoFocusSettings {
            AutoFocusSettings(
                isEnabled: zoomType == .auto,
                zoomLevel: zoomLevel,
                followSpeed: followSpeed,
                focusMargin: focusMargin,
            )
        }

        var isAutoMode: Bool {
            zoomType == .auto
        }

        /// Create a zoom segment centered at a specific time
        static func centered(
            at time: TimeInterval,
            duration: TimeInterval = defaultDuration,
            zoomLevel: CGFloat = defaultZoomLevel,
            center: CGPoint = CGPoint(x: 0.5, y: 0.5),
            type: ZoomType = .manual,
        ) -> ZoomSegment {
            ZoomSegment(
                startTime: max(0, time - duration / 2),
                duration: duration,
                zoomLevel: zoomLevel,
                zoomCenter: center,
                zoomType: type,
            )
        }

        /// Formatted zoom level string (e.g., "2x", "1.5x")
        var formattedZoomLevel: String {
            if zoomLevel == floor(zoomLevel) {
                String(format: "%.0fx", zoomLevel)
            } else {
                String(format: "%.1fx", zoomLevel)
            }
        }

        /// Formatted duration string
        var formattedDuration: String {
            if duration < 1 {
                String(format: "%.1fs", duration)
            } else if duration == floor(duration) {
                String(format: "%.0fs", duration)
            } else {
                String(format: "%.1fs", duration)
            }
        }
    }

    private extension CGFloat {
        func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
            Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
        }
    }
#endif

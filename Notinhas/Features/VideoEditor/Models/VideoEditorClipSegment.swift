#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorClipSegment.swift
    //  Notinhas
//
    //  Non-destructive clip range on the source recording (Plan 110 / Phase C).
//

    import Foundation

    struct VideoEditorClipSegment: Identifiable, Codable, Equatable, Sendable {
        static let minimumDuration: TimeInterval = 0.12
        static let minimumSpeed: Double = 1
        static let maximumSpeed: Double = 8

        var id: UUID
        var sourceStart: TimeInterval
        var sourceEnd: TimeInterval
        var speed: Double

        init(
            id: UUID = UUID(),
            sourceStart: TimeInterval,
            sourceEnd: TimeInterval,
            speed: Double = 1,
        ) {
            self.id = id
            self.sourceStart = sourceStart
            self.sourceEnd = sourceEnd
            self.speed = speed
        }

        var duration: TimeInterval {
            max(0, sourceEnd - sourceStart)
        }

        var editorDuration: TimeInterval {
            duration / max(speed, Self.minimumSpeed)
        }

        func clampedSpeed() -> VideoEditorClipSegment {
            var copy = self
            copy.speed = min(max(speed.isFinite ? speed : 1, Self.minimumSpeed), Self.maximumSpeed)
            return copy
        }
    }
#endif

#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorOverlayEffectsTests.swift
    //  NotinhasTests
//

    import CoreGraphics
    @testable import Notinhas
    import XCTest

    final class VideoEditorOverlayEffectsTests: XCTestCase {
        func testClickGeometry_startsWithImpactAndRipple() {
            let start = VideoEditorPointerPressEffectStyle.geometry(
                progress: 0,
                referenceHeight: 1080,
            )
            XCTAssertGreaterThan(start.impactOpacity, 0)
            XCTAssertEqual(start.rippleOpacity, 0, accuracy: 0.001)

            let mid = VideoEditorPointerPressEffectStyle.geometry(
                progress: 0.5,
                referenceHeight: 1080,
            )
            XCTAssertGreaterThan(mid.rippleRadius, start.rippleRadius)
        }

        func testKeystrokeCaptionTimeline_popInAndFadeOut() {
            let timeline = VideoEditorKeystrokeCaptionTimeline(events: [
                RecordedKeystrokeEvent(time: 1, modifiers: ["⌘"], key: "K"),
            ])
            XCTAssertNil(timeline.frame(at: 0.5))
            XCTAssertNotNil(timeline.frame(at: 1.05))
            XCTAssertNil(timeline.frame(at: 3))
        }

        func testMetadataV8_roundTripsPointerSynthesizedAndKeystrokes() throws {
            let metadata = RecordingMetadata(
                coordinateSpace: .topLeftNormalized,
                captureSize: CGSize(width: 1280, height: 720),
                samplesPerSecond: 60,
                mouseSamples: [],
                pointerSynthesized: true,
                keystrokes: [
                    RecordedKeystrokeEvent(time: 0.5, modifiers: ["⌘", "⇧"], key: "S"),
                ],
            )
            let data = try JSONEncoder().encode(metadata)
            let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: data)
            XCTAssertEqual(decoded.version, 8)
            XCTAssertEqual(decoded.pointerSynthesized, true)
            XCTAssertEqual(decoded.keystrokes, metadata.keystrokes)
        }
    }
#endif

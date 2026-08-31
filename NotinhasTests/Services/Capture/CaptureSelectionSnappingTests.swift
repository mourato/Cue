//
//  CaptureSelectionSnappingTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureSelectionSnappingTests: XCTestCase {
    private let configuration = CaptureSelectionSnappingConfiguration(snapDistance: 5, colorSensitivity: 3)
    private let desktop = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    func testConfigurationFromPreferences_clampsSharedSettings() throws {
        let suiteName = "CaptureSelectionSnappingTests.configuration"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(19, forKey: PreferencesKeys.captureSelectionSnapDistance)
        defaults.set(4, forKey: PreferencesKeys.captureSelectionColorSensitivity)

        XCTAssertEqual(
            CaptureSelectionSnappingConfiguration.fromPreferences(defaults),
            CaptureSelectionSnappingConfiguration(snapDistance: 19, colorSensitivity: 4),
        )
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testResolve_noCandidateOutsideRadius_returnsProposedRect() {
        let proposed = CGRect(x: 100, y: 100, width: 200, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: 80, source: .semantic),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .left,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )

        XCTAssertEqual(result.rect, proposed)
        XCTAssertTrue(result.appliedSources.isEmpty)
    }

    func testResolve_semanticCandidateWinsOverCloserColorCandidate() {
        let proposed = CGRect(x: 105, y: 100, width: 195, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: 104, source: .color),
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: 103, source: .semantic),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .left,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )

        XCTAssertEqual(result.rect.minX, 103, accuracy: 0.001)
        XCTAssertEqual(result.appliedSources[.minX], .semantic)
    }

    func testResolve_visualCandidateWinsOverColorCandidateAtEqualDistance() {
        let proposed = CGRect(x: 100, y: 100, width: 195, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .maxX, coordinate: 302, source: .color),
            CaptureSelectionSnappingCandidate(edge: .maxX, coordinate: 298, source: .visual),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .right,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )

        XCTAssertEqual(result.rect.maxX, 298, accuracy: 0.001)
        XCTAssertEqual(result.appliedSources[.maxX], .visual)
    }

    func testResolve_colorSensitivityChangesEligibility() {
        let proposed = CGRect(x: 100, y: 100, width: 200, height: 120)
        let backdrop = makeTwoRegionBackdrop(leftColor: (240, 240, 240), rightColor: (235, 235, 235))
        let screenFrame = CGRect(x: 0, y: 0, width: 400, height: 300)

        let strict = CaptureSelectionSnappingConfiguration(snapDistance: 20, colorSensitivity: 1)
        let loose = CaptureSelectionSnappingConfiguration(snapDistance: 20, colorSensitivity: 5)

        let strictCandidates = CaptureSelectionSnapping.imageCandidates(
            proposedRect: proposed,
            handle: .right,
            backdrop: backdrop,
            screenFrame: screenFrame,
            configuration: strict,
        )
        let looseCandidates = CaptureSelectionSnapping.imageCandidates(
            proposedRect: proposed,
            handle: .right,
            backdrop: backdrop,
            screenFrame: screenFrame,
            configuration: loose,
        )

        XCTAssertTrue(looseCandidates.count >= strictCandidates.count)
    }

    func testBoundaryIndex_findsStrongBoundaryAcrossSelectionSpan() throws {
        let backdrop = makeTwoRegionBackdrop(leftColor: (0, 0, 0), rightColor: (255, 255, 255))
        let index = try XCTUnwrap(
            CaptureSelectionBoundaryIndex(
                image: backdrop.image,
                drawRect: CGRect(x: 0, y: 0, width: 400, height: 300),
            ),
        )
        let proposed = CGRect(x: 175, y: 40, width: 20, height: 220)
        let candidates = CaptureSelectionSnapping.imageCandidates(
            proposedRect: proposed,
            handle: .right,
            backdrop: backdrop,
            screenFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            configuration: CaptureSelectionSnappingConfiguration(snapDistance: 20, colorSensitivity: 3),
            boundaryIndex: index,
        )

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .right,
            candidates: candidates,
            configuration: CaptureSelectionSnappingConfiguration(snapDistance: 20, colorSensitivity: 3),
            minSize: 1,
        )

        XCTAssertEqual(result.rect.maxX, 200, accuracy: 0.01)
        XCTAssertEqual(result.appliedCoordinates[.maxX] ?? -1, 200, accuracy: 0.01)
    }

    func testSnapMovingPoint_snapsCursorCornerToBoundary() throws {
        let backdrop = makeTwoRegionBackdrop(leftColor: (0, 0, 0), rightColor: (255, 255, 255))
        let index = try XCTUnwrap(
            CaptureSelectionBoundaryIndex(
                image: backdrop.image,
                drawRect: CGRect(x: 0, y: 0, width: 400, height: 300),
            ),
        )
        let anchor = CGPoint(x: 120, y: 80)
        let moving = CGPoint(x: 188, y: 180)
        let result = CaptureSelectionSnapping.snapMovingPoint(
            point: moving,
            anchor: anchor,
            boundaryIndex: index,
            configuration: CaptureSelectionSnappingConfiguration(snapDistance: 20, colorSensitivity: 3),
        )

        XCTAssertEqual(result.rect.maxX, 200, accuracy: 0.01)
        XCTAssertEqual(result.appliedCoordinates[.maxX] ?? -1, 200, accuracy: 0.01)
    }

    func testResolve_leftEdgeSnapsWithinRadius() {
        let proposed = CGRect(x: 102, y: 100, width: 200, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: 100, source: .semantic),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .left,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )

        XCTAssertEqual(result.rect.minX, 100, accuracy: 0.001)
        XCTAssertEqual(result.rect.width, 202, accuracy: 0.001)
    }

    func testResolve_cornerResolvesHorizontalAndVerticalEdgesIndependently() {
        let proposed = CGRect(x: 102, y: 98, width: 200, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: 100, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .maxY, coordinate: 220, source: .visual),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .topLeft,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )

        XCTAssertEqual(result.rect.minX, 100, accuracy: 0.001)
        XCTAssertEqual(result.rect.maxY, 220, accuracy: 0.001)
    }

    func testResolve_moveHandleSetIsEmpty() {
        XCTAssertTrue(CaptureSelectionSnapping.activeEdges(for: .left).contains(.minX))
        XCTAssertFalse(CaptureSelectionSnapping.activeEdges(for: .left).contains(.maxY))
    }

    func testResolve_rawPointerBeyondRadiusImmediatelyReturnsUnsnappedRect() {
        let first = CGRect(x: 100, y: 100, width: 200, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: 100, source: .semantic),
        ]

        let snapped = CaptureSelectionSnapping.resolve(
            proposedRect: first,
            handle: .left,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )
        XCTAssertEqual(snapped.rect.minX, 100, accuracy: 0.001)

        let beyondRadius = CGRect(x: 90, y: 100, width: 210, height: 120)
        let unsnapped = CaptureSelectionSnapping.resolve(
            proposedRect: beyondRadius,
            handle: .left,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )
        XCTAssertEqual(unsnapped.rect, beyondRadius)
        XCTAssertTrue(unsnapped.appliedSources.isEmpty)
    }

    func testResolve_preservesMinimumSize() {
        let proposed = CGRect(x: 100, y: 100, width: 10, height: 10)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .maxX, coordinate: 104, source: .semantic),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .right,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
            minSize: 50,
        )

        XCTAssertGreaterThanOrEqual(result.rect.width, 50)
        XCTAssertGreaterThanOrEqual(result.rect.height, 50)
    }

    func testResolve_aspectLockedCornerPreservesRatio() {
        let start = CGRect(x: 100, y: 100, width: 200, height: 100)
        let proposed = CGRect(x: 90, y: 90, width: 220, height: 130)
        let snapped = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .bottomRight,
            candidates: [],
            configuration: configuration,
            desktopBounds: desktop,
        ).rect

        let locked = CaptureSelectionGeometry.resizedRect(
            original: start,
            handle: .bottomRight,
            translation: CGPoint(
                x: snapped.width - start.width,
                y: snapped.minY - start.minY,
            ),
            aspectLocked: true,
            aspectRatio: 2,
            minSize: CaptureSelectionSnapping.refinementMinimumSize,
        )

        XCTAssertEqual(locked.width / locked.height, 2, accuracy: 0.01)
    }

    func testImageCandidates_detectsSharpVerticalBoundary() {
        let backdrop = makeTwoRegionBackdrop(leftColor: (20, 20, 20), rightColor: (240, 240, 240))
        let screenFrame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let proposed = CGRect(x: 10, y: 10, width: 85, height: 80)

        let candidates = CaptureSelectionSnapping.imageCandidates(
            proposedRect: proposed,
            handle: .right,
            backdrop: backdrop,
            screenFrame: screenFrame,
            configuration: CaptureSelectionSnappingConfiguration(snapDistance: 40, colorSensitivity: 4),
            sampler: CaptureSelectionSnappingCGImageSampler(image: backdrop.image),
        )

        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.contains { $0.source == .visual || $0.source == .color })
    }

    func testImageCandidates_returnsBoundaryNearProposedEdge() {
        let backdrop = makeTwoRegionBackdrop(
            leftColor: (20, 20, 20),
            rightColor: (240, 240, 240),
            width: 200,
            height: 100,
        )
        let screenFrame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let proposed = CGRect(x: 10, y: 10, width: 85, height: 80)

        let candidates = CaptureSelectionSnapping.imageCandidates(
            proposedRect: proposed,
            handle: .right,
            backdrop: backdrop,
            screenFrame: screenFrame,
            configuration: CaptureSelectionSnappingConfiguration(snapDistance: 20, colorSensitivity: 4),
            sampler: CaptureSelectionSnappingCGImageSampler(image: backdrop.image),
        )

        let candidate = candidates.first { $0.edge == .maxX }
        XCTAssertEqual(candidate?.coordinate ?? -1, 100.5, accuracy: 1)
    }

    func testResolve_crossingBoundaryImmediatelyDefeatsAttraction() {
        let proposed = CGRect(x: 100, y: 100, width: 202, height: 120)
        let candidates = [
            CaptureSelectionSnappingCandidate(edge: .maxX, coordinate: 300, source: .color),
        ]

        let result = CaptureSelectionSnapping.resolve(
            proposedRect: proposed,
            handle: .right,
            candidates: candidates,
            configuration: configuration,
            desktopBounds: desktop,
        )

        XCTAssertEqual(result.rect, proposed)
        XCTAssertTrue(result.appliedSources.isEmpty)
    }

    func testImageCandidates_rejectsSinglePixelNoise() {
        let backdrop = makeNoisyUniformBackdrop()
        let screenFrame = CGRect(x: 0, y: 0, width: 64, height: 64)
        let proposed = CGRect(x: 10, y: 10, width: 40, height: 40)

        let candidates = CaptureSelectionSnapping.imageCandidates(
            proposedRect: proposed,
            handle: .right,
            backdrop: backdrop,
            screenFrame: screenFrame,
            configuration: CaptureSelectionSnappingConfiguration(snapDistance: 10, colorSensitivity: 1),
            sampler: CaptureSelectionSnappingCGImageSampler(image: backdrop.image),
        )

        XCTAssertTrue(candidates.filter { $0.source == .visual }.isEmpty)
    }

    func testConfiguration_clampsPreferenceValues() {
        let config = CaptureSelectionSnappingConfiguration(snapDistance: 99, colorSensitivity: 99)
        XCTAssertEqual(config.snapDistance, 20)
        XCTAssertEqual(config.colorSensitivity, 5)
    }

    func testConfiguration_snapGuidesDefaultToEnabledAndRespectPreference() throws {
        let suiteName = "CaptureSelectionSnappingTests.guides"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        XCTAssertTrue(CaptureSelectionSnappingConfiguration.fromPreferences(defaults).showSnapGuides)
        defaults.set(false, forKey: PreferencesKeys.captureSelectionShowSnapGuides)
        XCTAssertFalse(CaptureSelectionSnappingConfiguration.fromPreferences(defaults).showSnapGuides)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testHandleCursorGeometry_mapsCornersBeforeEdges() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 120)
        let topLeft = CGPoint(x: 100, y: 220)
        XCTAssertEqual(RecordingResizeHandleCursorGeometry.handle(at: topLeft, in: rect, hitSize: 10), .topLeft)
    }

    func testHandleCursorGeometry_hitRectsCoverAllHandles() {
        let rect = CGRect(x: 50, y: 50, width: 300, height: 200)
        for handle in RecordingResizeHandleCursorGeometry.allHandles {
            let hitRect = RecordingResizeHandleCursorGeometry.hitRect(for: handle, in: rect, hitSize: 10)
            XCTAssertFalse(hitRect.isEmpty)
        }
    }

    func testHandleCursorGeometry_edgeHitSpansFullSideBetweenCorners() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 120)
        let hitSize: CGFloat = 10

        // Mid-edge away from the visual grip still resizes that edge.
        let topEdgeAwayFromMid = CGPoint(x: rect.minX + 40, y: rect.maxY)
        XCTAssertEqual(
            RecordingResizeHandleCursorGeometry.handle(at: topEdgeAwayFromMid, in: rect, hitSize: hitSize),
            .top,
        )

        let leftEdgeAwayFromMid = CGPoint(x: rect.minX, y: rect.minY + 40)
        XCTAssertEqual(
            RecordingResizeHandleCursorGeometry.handle(at: leftEdgeAwayFromMid, in: rect, hitSize: hitSize),
            .left,
        )

        let topHit = RecordingResizeHandleCursorGeometry.hitRect(for: .top, in: rect, hitSize: hitSize)
        XCTAssertEqual(topHit.minX, rect.minX + hitSize)
        XCTAssertEqual(topHit.width, rect.width - hitSize * 2)
        XCTAssertTrue(topHit.contains(topEdgeAwayFromMid))
    }

    func testPerceptualDifference_increasesWithContrast() {
        let low = (r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.5), a: CGFloat(1))
        let near = (r: CGFloat(0.52), g: CGFloat(0.52), b: CGFloat(0.52), a: CGFloat(1))
        let far = (r: CGFloat(0.9), g: CGFloat(0.9), b: CGFloat(0.9), a: CGFloat(1))

        XCTAssertLessThan(
            CaptureSelectionSnapping.perceptualDifference(low, near),
            CaptureSelectionSnapping.perceptualDifference(low, far),
        )
    }

    // MARK: - Fixtures

    private func makeTwoRegionBackdrop(
        leftColor: (UInt8, UInt8, UInt8),
        rightColor: (UInt8, UInt8, UInt8),
        width: Int = 200,
        height: Int = 100,
    ) -> AreaSelectionBackdrop {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let boundary = width / 2
        for y in 0 ..< height {
            for x in 0 ..< width {
                let color = x < boundary ? leftColor : rightColor
                let offset = (y * width + x) * 4
                pixels[offset] = color.0
                pixels[offset + 1] = color.1
                pixels[offset + 2] = color.2
                pixels[offset + 3] = 255
            }
        }

        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        )!

        return AreaSelectionBackdrop(displayID: 1, image: image, scaleFactor: 1, isVisible: true)
    }

    private func makeNoisyUniformBackdrop(size: Int = 64) -> AreaSelectionBackdrop {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for index in 0 ..< (size * size) {
            let offset = index * 4
            let noise: UInt8 = index == 32 ? 255 : 128
            pixels[offset] = noise
            pixels[offset + 1] = noise
            pixels[offset + 2] = noise
            pixels[offset + 3] = 255
        }

        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        let image = CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        )!

        return AreaSelectionBackdrop(displayID: 1, image: image, scaleFactor: 1, isVisible: true)
    }

    func testScreenBoundaryCandidates_alignDesktopEdges() {
        let desktop = CGRect(x: 10, y: 20, width: 300, height: 200)
        let candidates = CaptureSelectionSnapping.screenBoundaryCandidates(for: desktop)

        XCTAssertEqual(candidates.count, 4)
        XCTAssertTrue(candidates.contains { $0.edge == .minX && $0.coordinate == desktop.minX })
        XCTAssertTrue(candidates.contains { $0.edge == .maxY && $0.coordinate == desktop.maxY })
    }

    func testTopLeftAdapter_matchesBottomLeftResizeForEquivalentRect() {
        let container = CGSize(width: 400, height: 300)
        let topLeftRect = CGRect(x: 100, y: 80, width: 120, height: 90)
        let resizedTopLeft = CaptureSelectionResizeAdapter.resizedRect(
            original: topLeftRect,
            handle: .right,
            translation: CGPoint(x: 20, y: 0),
            coordinateSpace: .topLeftOrigin,
            containerSize: container,
            minSize: CaptureSelectionChromeMetrics.confirmedMinimumSize,
        )

        XCTAssertEqual(resizedTopLeft.width, 140, accuracy: 0.001)
        XCTAssertEqual(resizedTopLeft.minY, topLeftRect.minY, accuracy: 0.001)
    }
}

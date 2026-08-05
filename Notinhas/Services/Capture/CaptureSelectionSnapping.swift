//
//  CaptureSelectionSnapping.swift
//  Notinhas
//
//  Pure configuration, candidate types, image sampling, and stateless rectangle
//  resolution for All-In-One capture selection edge snapping.
//

import CoreGraphics
import Foundation

// MARK: - Configuration

struct CaptureSelectionSnappingConfiguration: Equatable, Sendable {
    static let defaultSnapDistance: CGFloat = 5
    static let snapDistanceRange: ClosedRange<Int> = 1 ... 20
    static let defaultColorSensitivity = 3
    static let colorSensitivityRange: ClosedRange<Int> = 1 ... 5

    let snapDistance: CGFloat
    let colorSensitivity: Int

    static func fromPreferences(_ defaults: UserDefaults = .standard) -> CaptureSelectionSnappingConfiguration {
        let snapDistance = defaults.object(forKey: PreferencesKeys.captureSelectionSnapDistance) as? Int
            ?? Int(defaultSnapDistance)
        let colorSensitivity = defaults.object(forKey: PreferencesKeys.captureSelectionColorSensitivity) as? Int
            ?? defaultColorSensitivity
        return CaptureSelectionSnappingConfiguration(
            snapDistance: CGFloat(snapDistance),
            colorSensitivity: colorSensitivity,
        )
    }

    init(snapDistance: CGFloat = Self.defaultSnapDistance, colorSensitivity: Int = Self.defaultColorSensitivity) {
        self.snapDistance = Self.clampedSnapDistance(snapDistance)
        self.colorSensitivity = Self.clampedColorSensitivity(colorSensitivity)
    }

    static func clampedSnapDistance(_ value: CGFloat) -> CGFloat {
        CGFloat(min(max(Int(value.rounded()), snapDistanceRange.lowerBound), snapDistanceRange.upperBound))
    }

    static func clampedColorSensitivity(_ value: Int) -> Int {
        min(max(value, colorSensitivityRange.lowerBound), colorSensitivityRange.upperBound)
    }

    var colorDifferenceThreshold: CGFloat {
        let normalized = CGFloat(colorSensitivity - Self.colorSensitivityRange.lowerBound)
            / CGFloat(Self.colorSensitivityRange.upperBound - Self.colorSensitivityRange.lowerBound)
        return 0.34 - normalized * 0.24
    }

    var visualEdgeThreshold: CGFloat {
        colorDifferenceThreshold + 0.08
    }
}

// MARK: - Candidates

enum CaptureSelectionSnappingEdge: CaseIterable, Equatable, Sendable {
    case minX
    case maxX
    case minY
    case maxY
}

enum CaptureSelectionSnappingSource: Int, CaseIterable, Equatable, Sendable {
    case semantic = 0
    case visual = 1
    case color = 2
}

struct CaptureSelectionSnappingCandidate: Equatable, Sendable {
    let edge: CaptureSelectionSnappingEdge
    let coordinate: CGFloat
    let source: CaptureSelectionSnappingSource
}

struct CaptureSelectionSnappingResult: Equatable, Sendable {
    let rect: CGRect
    let appliedSources: [CaptureSelectionSnappingEdge: CaptureSelectionSnappingSource]
}

// MARK: - Image Sampling Protocol

protocol CaptureSelectionSnappingPixelSampling: Sendable {
    func rgba(at pixel: CGPoint, width: Int, height: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)?
}

struct CaptureSelectionSnappingCGImageSampler: CaptureSelectionSnappingPixelSampling {
    let pixels: [UInt8]
    let bytesPerRow: Int

    init?(image: CGImage) {
        guard let data = image.dataProvider?.data as Data? else { return nil }
        pixels = [UInt8](data)
        bytesPerRow = image.bytesPerRow
    }

    func rgba(at pixel: CGPoint, width: Int, height: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        let x = Int(pixel.x.rounded())
        let y = Int(pixel.y.rounded())
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let offset = y * bytesPerRow + x * 4
        guard offset + 3 < pixels.count else { return nil }
        let scale: CGFloat = 1 / 255
        return (
            CGFloat(pixels[offset]) * scale,
            CGFloat(pixels[offset + 1]) * scale,
            CGFloat(pixels[offset + 2]) * scale,
            CGFloat(pixels[offset + 3]) * scale,
        )
    }
}

// MARK: - Resolver

enum CaptureSelectionSnapping {
    static let refinementMinimumSize: CGFloat = CaptureSelectionChromeMetrics.confirmedMinimumSize

    static func screenBoundaryCandidates(for desktopBounds: CGRect) -> [CaptureSelectionSnappingCandidate] {
        [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: desktopBounds.minX, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .maxX, coordinate: desktopBounds.maxX, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .minY, coordinate: desktopBounds.minY, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .maxY, coordinate: desktopBounds.maxY, source: .semantic),
        ]
    }

    static func activeEdges(for handle: CaptureSelectionResizeHandle) -> Set<CaptureSelectionSnappingEdge> {
        switch handle {
        case .topLeft:
            [.minX, .maxY]
        case .top:
            [.maxY]
        case .topRight:
            [.maxX, .maxY]
        case .left:
            [.minX]
        case .right:
            [.maxX]
        case .bottomLeft:
            [.minX, .minY]
        case .bottom:
            [.minY]
        case .bottomRight:
            [.maxX, .minY]
        }
    }

    static func coordinate(for edge: CaptureSelectionSnappingEdge, in rect: CGRect) -> CGFloat {
        switch edge {
        case .minX: rect.minX
        case .maxX: rect.maxX
        case .minY: rect.minY
        case .maxY: rect.maxY
        }
    }

    static func resolve(
        proposedRect: CGRect,
        handle: CaptureSelectionResizeHandle,
        candidates: [CaptureSelectionSnappingCandidate],
        configuration: CaptureSelectionSnappingConfiguration,
        desktopBounds: CGRect? = nil,
        minSize: CGFloat = refinementMinimumSize,
    ) -> CaptureSelectionSnappingResult {
        let normalizedProposed = CaptureSelectionGeometry.normalized(proposedRect, minSize: minSize)
        var rect = normalizedProposed
        var appliedSources: [CaptureSelectionSnappingEdge: CaptureSelectionSnappingSource] = [:]

        for edge in activeEdges(for: handle) {
            let proposedCoordinate = coordinate(for: edge, in: normalizedProposed)
            guard let candidate = bestCandidate(
                for: edge,
                proposedCoordinate: proposedCoordinate,
                candidates: candidates,
                snapDistance: configuration.snapDistance,
            ) else {
                continue
            }
            rect = rectBySetting(edge: edge, coordinate: candidate.coordinate, in: rect)
            appliedSources[edge] = candidate.source
        }

        rect = CaptureSelectionGeometry.normalized(rect, minSize: minSize)
        if let desktopBounds {
            rect = clamp(rect, within: desktopBounds, handle: handle, minSize: minSize)
        }

        return CaptureSelectionSnappingResult(rect: rect, appliedSources: appliedSources)
    }

    static func bestCandidate(
        for edge: CaptureSelectionSnappingEdge,
        proposedCoordinate: CGFloat,
        candidates: [CaptureSelectionSnappingCandidate],
        snapDistance: CGFloat,
    ) -> CaptureSelectionSnappingCandidate? {
        candidates
            .filter { candidate in
                candidate.edge == edge
                    && abs(candidate.coordinate - proposedCoordinate) <= snapDistance
                    && isOnApproachSide(candidate.coordinate, of: proposedCoordinate, edge: edge)
            }
            .min { lhs, rhs in
                let lhsPriority = lhs.source.rawValue
                let rhsPriority = rhs.source.rawValue
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                let lhsDistance = abs(lhs.coordinate - proposedCoordinate)
                let rhsDistance = abs(rhs.coordinate - proposedCoordinate)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.coordinate < rhs.coordinate
            }
    }

    private static func isOnApproachSide(
        _ candidateCoordinate: CGFloat,
        of proposedCoordinate: CGFloat,
        edge: CaptureSelectionSnappingEdge,
    ) -> Bool {
        switch edge {
        case .minX, .minY:
            candidateCoordinate <= proposedCoordinate
        case .maxX, .maxY:
            candidateCoordinate >= proposedCoordinate
        }
    }

    static func rectBySetting(edge: CaptureSelectionSnappingEdge, coordinate: CGFloat, in rect: CGRect) -> CGRect {
        var result = rect
        switch edge {
        case .minX:
            let delta = coordinate - result.minX
            result.origin.x += delta
            result.size.width -= delta
        case .maxX:
            result.size.width = coordinate - result.minX
        case .minY:
            let delta = coordinate - result.minY
            result.origin.y += delta
            result.size.height -= delta
        case .maxY:
            result.size.height = coordinate - result.minY
        }
        return result
    }

    static func clamp(
        _ rect: CGRect,
        within desktop: CGRect,
        handle: CaptureSelectionResizeHandle,
        minSize: CGFloat,
    ) -> CGRect {
        var result = CaptureSelectionGeometry.normalized(rect, minSize: minSize)
        let active = activeEdges(for: handle)

        if active.contains(.minX), result.minX < desktop.minX {
            let delta = desktop.minX - result.minX
            result.origin.x += delta
            result.size.width -= delta
        }
        if active.contains(.minY), result.minY < desktop.minY {
            let delta = desktop.minY - result.minY
            result.origin.y += delta
            result.size.height -= delta
        }
        if active.contains(.maxX), result.maxX > desktop.maxX {
            result.size.width = desktop.maxX - result.minX
        }
        if active.contains(.maxY), result.maxY > desktop.maxY {
            result.size.height = desktop.maxY - result.minY
        }

        return CaptureSelectionGeometry.normalized(result, minSize: minSize)
    }

    // MARK: - Screen / Pixel Mapping

    static func screenPointToPixel(
        _ point: CGPoint,
        screenFrame: CGRect,
        imageSize: CGSize,
    ) -> CGPoint? {
        guard screenFrame.width > 0, screenFrame.height > 0, imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }
        let localX = point.x - screenFrame.minX
        let localY = point.y - screenFrame.minY
        let pixelX = localX / screenFrame.width * imageSize.width
        let pixelY = imageSize.height - 1 - (localY / screenFrame.height * imageSize.height)
        return CGPoint(x: pixelX, y: pixelY)
    }

    static func pixelCoordinateToScreen(
        _ coordinate: CGFloat,
        edge: CaptureSelectionSnappingEdge,
        screenFrame: CGRect,
        imageSize: CGSize,
        rect _: CGRect,
    ) -> CGFloat? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        switch edge {
        case .minX, .maxX:
            let pixelX = coordinate
            let localX = pixelX / imageSize.width * screenFrame.width
            return screenFrame.minX + localX
        case .minY, .maxY:
            let pixelY = coordinate
            let localYFromTop = pixelY / imageSize.height * screenFrame.height
            let localY = screenFrame.height - localYFromTop
            return screenFrame.minY + localY
        }
    }

    // MARK: - Image Candidate Detection

    static func imageCandidates(
        proposedRect: CGRect,
        handle: CaptureSelectionResizeHandle,
        backdrop: AreaSelectionBackdrop,
        screenFrame: CGRect,
        configuration: CaptureSelectionSnappingConfiguration,
        sampler: CaptureSelectionSnappingPixelSampling? = nil,
    ) -> [CaptureSelectionSnappingCandidate] {
        guard backdrop.isVisible else { return [] }
        let image = backdrop.image
        let width = image.width
        let height = image.height
        guard width > 1, height > 1 else { return [] }

        let pixelSampler = sampler ?? CaptureSelectionSnappingCGImageSampler(image: image)
        guard let pixelSampler else { return [] }

        var candidates: [CaptureSelectionSnappingCandidate] = []
        for edge in activeEdges(for: handle) {
            if let visual = detectVisualCandidate(
                proposedRect: proposedRect,
                edge: edge,
                screenFrame: screenFrame,
                imageSize: CGSize(width: width, height: height),
                configuration: configuration,
                sampler: pixelSampler,
                width: width,
                height: height,
            ) {
                candidates.append(visual)
            }
            if let color = detectColorCandidate(
                proposedRect: proposedRect,
                edge: edge,
                screenFrame: screenFrame,
                imageSize: CGSize(width: width, height: height),
                configuration: configuration,
                sampler: pixelSampler,
                width: width,
                height: height,
            ) {
                candidates.append(color)
            }
        }
        return candidates
    }

    private static func detectVisualCandidate(
        proposedRect: CGRect,
        edge: CaptureSelectionSnappingEdge,
        screenFrame: CGRect,
        imageSize: CGSize,
        configuration: CaptureSelectionSnappingConfiguration,
        sampler: CaptureSelectionSnappingPixelSampling,
        width: Int,
        height: Int,
    ) -> CaptureSelectionSnappingCandidate? {
        scanForTransition(
            proposedRect: proposedRect,
            edge: edge,
            screenFrame: screenFrame,
            imageSize: imageSize,
            configuration: configuration,
            sampler: sampler,
            width: width,
            height: height,
            threshold: configuration.visualEdgeThreshold,
            minimumRun: 3,
            source: .visual,
        )
    }

    private static func detectColorCandidate(
        proposedRect: CGRect,
        edge: CaptureSelectionSnappingEdge,
        screenFrame: CGRect,
        imageSize: CGSize,
        configuration: CaptureSelectionSnappingConfiguration,
        sampler: CaptureSelectionSnappingPixelSampling,
        width: Int,
        height: Int,
    ) -> CaptureSelectionSnappingCandidate? {
        scanForTransition(
            proposedRect: proposedRect,
            edge: edge,
            screenFrame: screenFrame,
            imageSize: imageSize,
            configuration: configuration,
            sampler: sampler,
            width: width,
            height: height,
            threshold: configuration.colorDifferenceThreshold,
            minimumRun: 2,
            source: .color,
        )
    }

    private static func scanForTransition(
        proposedRect: CGRect,
        edge: CaptureSelectionSnappingEdge,
        screenFrame: CGRect,
        imageSize: CGSize,
        configuration: CaptureSelectionSnappingConfiguration,
        sampler: CaptureSelectionSnappingPixelSampling,
        width: Int,
        height: Int,
        threshold: CGFloat,
        minimumRun: Int,
        source: CaptureSelectionSnappingSource,
    ) -> CaptureSelectionSnappingCandidate? {
        let edgeScreenCoordinate = coordinate(for: edge, in: proposedRect)
        guard let edgePixelPoint = screenEdgeToPixel(
            edge: edge,
            screenCoordinate: edgeScreenCoordinate,
            rect: proposedRect,
            screenFrame: screenFrame,
            imageSize: imageSize,
        ) else {
            return nil
        }

        let scanAxisIsVertical = edge == .minX || edge == .maxX
        let scanLength = scanAxisIsVertical ? proposedRect.height : proposedRect.width
        let sampleCount = max(3, min(9, Int(scanLength / 24)))
        let pixelRadius = max(
            2,
            Int(
                ceil(
                    configuration.snapDistance
                        / ((edge == .minX || edge == .maxX) ? screenFrame.width : screenFrame.height)
                        * ((edge == .minX || edge == .maxX) ? imageSize.width : imageSize.height),
                ),
            ),
        )

        var bestCoordinate: CGFloat?
        var bestStrength: CGFloat = 0

        for index in 0 ..< sampleCount {
            let t = CGFloat(index + 1) / CGFloat(sampleCount + 1)
            let scanPoint = scanAxisIsVertical
                ? CGPoint(
                    x: edgePixelPoint.x,
                    y: edgePixelPoint.y + (t - 0.5) * scanLength / screenFrame.height * imageSize.height,
                )
                : CGPoint(
                    x: edgePixelPoint.x + (t - 0.5) * scanLength / screenFrame.width * imageSize.width,
                    y: edgePixelPoint.y,
                )

            guard let transition = strongestTransitionAlongNormal(
                at: scanPoint,
                edge: edge,
                pixelRadius: pixelRadius,
                threshold: threshold,
                minimumRun: minimumRun,
                sampler: sampler,
                width: width,
                height: height,
            ) else {
                continue
            }

            if transition.strength > bestStrength {
                bestStrength = transition.strength
                bestCoordinate = transition.pixelCoordinate
            }
        }

        guard let bestCoordinate,
              let screenCoordinate = pixelEdgeToScreen(
                  edge: edge,
                  pixelCoordinate: bestCoordinate,
                  screenFrame: screenFrame,
                  imageSize: imageSize,
              ) else {
            return nil
        }

        return CaptureSelectionSnappingCandidate(edge: edge, coordinate: screenCoordinate, source: source)
    }

    private static func strongestTransitionAlongNormal(
        at point: CGPoint,
        edge: CaptureSelectionSnappingEdge,
        pixelRadius: Int,
        threshold: CGFloat,
        minimumRun: Int,
        sampler: CaptureSelectionSnappingPixelSampling,
        width: Int,
        height: Int,
    ) -> (pixelCoordinate: CGFloat, strength: CGFloat)? {
        let isHorizontalEdge = edge == .minX || edge == .maxX
        let inwardVector = switch edge {
        case .minX:
            CGPoint(x: 1, y: 0)
        case .maxX:
            CGPoint(x: -1, y: 0)
        case .minY:
            CGPoint(x: 0, y: -1)
        case .maxY:
            CGPoint(x: 0, y: 1)
        }
        let outwardVector = CGPoint(x: -inwardVector.x, y: -inwardVector.y)
        let innerSamples = (1 ... 3).compactMap { offset -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? in
            let inwardSample = CGPoint(
                x: point.x + inwardVector.x * CGFloat(offset),
                y: point.y + inwardVector.y * CGFloat(offset),
            )
            return sampler.rgba(at: inwardSample, width: width, height: height)
        }
        guard !innerSamples.isEmpty else {
            return nil
        }
        let innerColor = (
            r: innerSamples.reduce(CGFloat.zero) { $0 + $1.r } / CGFloat(innerSamples.count),
            g: innerSamples.reduce(CGFloat.zero) { $0 + $1.g } / CGFloat(innerSamples.count),
            b: innerSamples.reduce(CGFloat.zero) { $0 + $1.b } / CGFloat(innerSamples.count),
            a: innerSamples.reduce(CGFloat.zero) { $0 + $1.a } / CGFloat(innerSamples.count),
        )

        var run = 0
        var firstTransitionOffset: Int?
        var bestStrength: CGFloat = 0

        for offset in 1 ... pixelRadius {
            let outer = CGPoint(
                x: point.x + outwardVector.x * CGFloat(offset),
                y: point.y + outwardVector.y * CGFloat(offset),
            )
            guard let outerColor = sampler.rgba(at: outer, width: width, height: height) else {
                run = 0
                firstTransitionOffset = nil
                continue
            }

            let difference = perceptualDifference(innerColor, outerColor)
            if difference >= threshold {
                run += 1
                if run >= minimumRun {
                    firstTransitionOffset = firstTransitionOffset ?? offset - minimumRun + 1
                    bestStrength = max(bestStrength, difference)
                }
            } else {
                run = 0
                firstTransitionOffset = nil
            }
        }

        guard let firstTransitionOffset else { return nil }
        let transitionPixel = isHorizontalEdge
            ? point.x + outwardVector.x * (CGFloat(firstTransitionOffset) - 0.5)
            : point.y + outwardVector.y * (CGFloat(firstTransitionOffset) - 0.5)
        return (transitionPixel, bestStrength)
    }

    static func perceptualDifference(
        _ lhs: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
        _ rhs: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
    ) -> CGFloat {
        let lumaL = 0.299 * lhs.r + 0.587 * lhs.g + 0.114 * lhs.b
        let lumaR = 0.299 * rhs.r + 0.587 * rhs.g + 0.114 * rhs.b
        let lumaDifference = abs(lumaL - lumaR)
        let colorDifference = (abs(lhs.r - rhs.r) + abs(lhs.g - rhs.g) + abs(lhs.b - rhs.b)) / 3
        return lumaDifference * 0.58 + colorDifference * 0.42
    }

    private static func screenEdgeToPixel(
        edge: CaptureSelectionSnappingEdge,
        screenCoordinate: CGFloat,
        rect: CGRect,
        screenFrame: CGRect,
        imageSize: CGSize,
    ) -> CGPoint? {
        switch edge {
        case .minX:
            screenPointToPixel(
                CGPoint(x: screenCoordinate, y: rect.midY),
                screenFrame: screenFrame,
                imageSize: imageSize,
            )
        case .maxX:
            screenPointToPixel(
                CGPoint(x: screenCoordinate, y: rect.midY),
                screenFrame: screenFrame,
                imageSize: imageSize,
            )
        case .minY:
            screenPointToPixel(
                CGPoint(x: rect.midX, y: screenCoordinate),
                screenFrame: screenFrame,
                imageSize: imageSize,
            )
        case .maxY:
            screenPointToPixel(
                CGPoint(x: rect.midX, y: screenCoordinate),
                screenFrame: screenFrame,
                imageSize: imageSize,
            )
        }
    }

    private static func pixelEdgeToScreen(
        edge: CaptureSelectionSnappingEdge,
        pixelCoordinate: CGFloat,
        screenFrame: CGRect,
        imageSize: CGSize,
    ) -> CGFloat? {
        switch edge {
        case .minX, .maxX:
            let localX = pixelCoordinate / imageSize.width * screenFrame.width
            return screenFrame.minX + localX
        case .minY, .maxY:
            let localYFromTop = pixelCoordinate / imageSize.height * screenFrame.height
            let localY = screenFrame.height - localYFromTop
            return screenFrame.minY + localY
        }
    }

    static func semanticCandidates(for rect: CGRect) -> [CaptureSelectionSnappingCandidate] {
        [
            CaptureSelectionSnappingCandidate(edge: .minX, coordinate: rect.minX, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .maxX, coordinate: rect.maxX, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .minY, coordinate: rect.minY, source: .semantic),
            CaptureSelectionSnappingCandidate(edge: .maxY, coordinate: rect.maxY, source: .semantic),
        ]
    }
}

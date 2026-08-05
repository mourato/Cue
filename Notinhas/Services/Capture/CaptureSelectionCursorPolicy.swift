//
//  CaptureSelectionCursorPolicy.swift
//  Notinhas
//
//  Pure cursor classification and commit policy for capture selection hosts.
//

import AppKit
import CoreGraphics

enum CaptureSelectionCursorZone: Equatable {
    case hud
    case resizeHandle(CaptureSelectionResizeHandle)
    case insideSelection
    case outside
}

enum CaptureSelectionCursorKind: Equatable {
    case arrow
    case crosshair
    case resize(CaptureSelectionResizeHandle)
    case openHand
}

enum CaptureSelectionCursorPhase: Equatable {
    case initialAreaSelection
    case confirmedRefinement
    case markupSelecting
    case markupAnnotating
}

enum CaptureSelectionCursorPolicy {
    static func cursorKind(
        zone: CaptureSelectionCursorZone,
        phase: CaptureSelectionCursorPhase,
    ) -> CaptureSelectionCursorKind {
        switch zone {
        case .hud:
            .arrow
        case let .resizeHandle(handle):
            .resize(handle)
        case .insideSelection:
            phase == .markupAnnotating ? .openHand : .arrow
        case .outside:
            switch phase {
            case .initialAreaSelection, .markupSelecting:
                .crosshair
            case .confirmedRefinement, .markupAnnotating:
                .arrow
            }
        }
    }

    @MainActor
    static func apply(_ kind: CaptureSelectionCursorKind, markupSelectingCrosshair: Bool = false) {
        switch kind {
        case .arrow:
            NSCursor.arrow.set()
        case .crosshair:
            if markupSelectingCrosshair {
                NSCursor.vectorScreenshotCrosshairLight.set()
            } else {
                NSCursor.crosshair.set()
            }
        case let .resize(handle):
            CaptureSelectionResizeCursor.cursor(for: handle).set()
        case .openHand:
            NSCursor.openHand.set()
        }
    }
}

/// Single All-In-One cursor owner: HUD exclusion always wins over overlay candidates.
@MainActor
final class AllInOneCaptureCursorArbiter {
    var hudExclusionFrames: () -> [CGRect] = { [] }
    var fallbackCursor: (() -> CaptureSelectionCursorKind?)?
    var overlayCandidate: ((CGPoint) -> CaptureSelectionCursorKind?)?

    func resolvedCursor(at location: CGPoint) -> CaptureSelectionCursorKind? {
        if CaptureFloatingCursorExclusion.contains(location, in: hudExclusionFrames()) {
            return .arrow
        }
        return overlayCandidate?(location) ?? fallbackCursor?()
    }

    func commit(at location: CGPoint, markupSelectingCrosshair: Bool = false) {
        guard let kind = resolvedCursor(at: location) else { return }
        CaptureSelectionCursorPolicy.apply(kind, markupSelectingCrosshair: markupSelectingCrosshair)
    }
}

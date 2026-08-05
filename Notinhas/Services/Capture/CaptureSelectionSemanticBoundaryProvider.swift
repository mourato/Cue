//
//  CaptureSelectionSemanticBoundaryProvider.swift
//  Notinhas
//
//  Non-prompting semantic boundary lookup for capture selection snapping.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
protocol CaptureSelectionSemanticBoundaryProviding: AnyObject {
    func semanticRect(at screenPoint: CGPoint, ownerPID: Int32?) -> CGRect?
    func semanticCandidates(
        at screenPoint: CGPoint,
        ownerPID: Int32?,
        handle: CaptureSelectionResizeHandle,
    ) -> [CaptureSelectionSnappingCandidate]
    func clearCache()
}

@MainActor
final class CaptureSelectionSemanticBoundaryProvider: CaptureSelectionSemanticBoundaryProviding {
    private let snapshotProvider: AXSnapshotProviding
    private let isTrusted: () -> Bool

    private var cachedInputRect: CGRect?
    private var cachedRect: CGRect?
    private var cachedOwnerPID: Int32?

    init(
        snapshotProvider: AXSnapshotProviding = AXAccessibilitySnapshotProvider(),
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
    ) {
        self.snapshotProvider = snapshotProvider
        self.isTrusted = isTrusted
    }

    func semanticRect(at screenPoint: CGPoint, ownerPID: Int32?) -> CGRect? {
        guard isTrusted() else {
            clearCache()
            return nil
        }

        if let cachedInputRect,
           let cachedRect,
           cachedOwnerPID == ownerPID,
           cachedInputRect.contains(screenPoint) {
            return cachedRect
        }

        guard
            let snapshot = snapshotProvider.snapshot(at: screenPoint, pid: ownerPID),
            let meaningful = AXElementInspector.findMeaningful(snapshot),
            let rect = AXElementInspector.screenRect(forTopLeftRect: meaningful.rect),
            rect.width > 0,
            rect.height > 0
        else {
            clearCache()
            return nil
        }

        cachedInputRect = meaningful.rect
        cachedRect = rect
        cachedOwnerPID = ownerPID
        return rect
    }

    func clearCache() {
        cachedInputRect = nil
        cachedRect = nil
        cachedOwnerPID = nil
    }

    func semanticCandidates(
        at screenPoint: CGPoint,
        ownerPID: Int32?,
        handle: CaptureSelectionResizeHandle,
    ) -> [CaptureSelectionSnappingCandidate] {
        guard let rect = semanticRect(at: screenPoint, ownerPID: ownerPID) else {
            return []
        }

        let activeEdges = CaptureSelectionSnapping.activeEdges(for: handle)
        return CaptureSelectionSnapping.semanticCandidates(for: rect)
            .filter { activeEdges.contains($0.edge) }
    }
}

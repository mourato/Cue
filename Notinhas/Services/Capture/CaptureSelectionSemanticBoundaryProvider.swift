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
    private var lastSemanticCandidatesQueryAt: TimeInterval?
    private var cachedSemanticCandidates: [CaptureSelectionSnappingCandidate] = []
    private var cachedSemanticCandidatesOwnerPID: Int32?
    private let minimumSemanticQueryInterval: TimeInterval

    init(
        snapshotProvider: AXSnapshotProviding = AXAccessibilitySnapshotProvider(),
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        minimumSemanticQueryInterval: TimeInterval = 1.0 / 30.0,
    ) {
        self.snapshotProvider = snapshotProvider
        self.isTrusted = isTrusted
        self.minimumSemanticQueryInterval = max(0, minimumSemanticQueryInterval)
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
        lastSemanticCandidatesQueryAt = nil
        cachedSemanticCandidates = []
        cachedSemanticCandidatesOwnerPID = nil
    }

    func semanticCandidates(
        at screenPoint: CGPoint,
        ownerPID: Int32?,
        handle: CaptureSelectionResizeHandle,
    ) -> [CaptureSelectionSnappingCandidate] {
        guard isTrusted() else {
            clearCache()
            return []
        }

        let now = ProcessInfo.processInfo.systemUptime
        if let lastQueryAt = lastSemanticCandidatesQueryAt,
           now - lastQueryAt < minimumSemanticQueryInterval,
           cachedSemanticCandidatesOwnerPID == ownerPID {
            return filteredSemanticCandidates(for: handle)
        }

        let candidates: [CaptureSelectionSnappingCandidate] = if let rect = semanticRect(
            at: screenPoint,
            ownerPID: ownerPID,
        ) {
            CaptureSelectionSnapping.semanticCandidates(for: rect)
        } else {
            []
        }

        lastSemanticCandidatesQueryAt = now
        cachedSemanticCandidates = candidates
        cachedSemanticCandidatesOwnerPID = ownerPID
        return filteredSemanticCandidates(for: handle)
    }

    private func filteredSemanticCandidates(
        for handle: CaptureSelectionResizeHandle,
    ) -> [CaptureSelectionSnappingCandidate] {
        let activeEdges = CaptureSelectionSnapping.activeEdges(for: handle)
        return cachedSemanticCandidates.filter { activeEdges.contains($0.edge) }
    }
}

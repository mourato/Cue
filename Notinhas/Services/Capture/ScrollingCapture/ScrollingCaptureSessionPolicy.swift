//
//  ScrollingCaptureSessionPolicy.swift
//  Notinhas
//
//  Pure policy helpers for scrolling capture preview and commit scheduling.
//

import Foundation

enum ScrollingCaptureSessionPolicy {
    static func previewOutputChanged(
        previousAcceptedFrameCount: Int,
        previousOutputHeight: Int,
        acceptedFrameCount: Int,
        outputHeight: Int,
    ) -> Bool {
        acceptedFrameCount != previousAcceptedFrameCount || outputHeight != previousOutputHeight
    }

    static func shouldPublishLivePreviewFrame(
        hasCommittedPreview: Bool,
        capturedAt: TimeInterval,
        lastPublishedAt: TimeInterval?,
        minimumInterval: TimeInterval,
    ) -> Bool {
        guard hasCommittedPreview else { return true }
        guard let lastPublishedAt else { return true }
        return capturedAt - lastPublishedAt >= minimumInterval
    }

    static func previewCommitLagMs(
        latestCapturedAt: TimeInterval?,
        lastCommittedObservationAt: TimeInterval?,
        isUsingLivePreview: Bool,
        toleranceMs: Int,
    ) -> Int {
        guard let latestCapturedAt else { return 0 }
        if let lastCommittedObservationAt {
            return max(
                0,
                Int(((latestCapturedAt - lastCommittedObservationAt) * 1_000).rounded()),
            )
        }
        return isUsingLivePreview ? toleranceMs + 1 : 0
    }

    /// Schedules a stitch commit while scroll is still active, without waiting for settle.
    static func shouldScheduleStreamingCommit(
        hasPendingMotion: Bool,
        idleDuration: TimeInterval,
        activeScrollThreshold: TimeInterval,
        timeSinceLastRefresh: TimeInterval?,
        minimumStreamingInterval: TimeInterval,
        canStartRefresh: Bool,
    ) -> Bool {
        guard hasPendingMotion, canStartRefresh else { return false }
        guard idleDuration < activeScrollThreshold else { return false }
        guard let timeSinceLastRefresh else { return true }
        return timeSinceLastRefresh >= minimumStreamingInterval
    }

    static func preferredCommitFrameSource(
        hasOnDemandFrame: Bool,
        hasStreamFrame: Bool,
    ) -> ScrollingCaptureCommitFrameSource? {
        if hasOnDemandFrame {
            return .onDemand
        }
        if hasStreamFrame {
            return .stream
        }
        return nil
    }

    static func shouldUpdateStitchedPreview(
        outputChanged: Bool,
        outcome: ScrollingCaptureStitchOutcome,
    ) -> Bool {
        if outputChanged {
            return true
        }
        if case .initialized = outcome {
            return true
        }
        return false
    }
}

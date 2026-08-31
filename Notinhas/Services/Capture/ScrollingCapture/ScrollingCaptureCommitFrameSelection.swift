//
//  ScrollingCaptureCommitFrameSelection.swift
//  Notinhas
//
//  Builds and selects commit frames for scrolling capture stitch updates.
//

import CoreGraphics
import Foundation

struct ScrollingCaptureCommitFrame {
    let image: CGImage
    let sequenceNumber: Int?
    let source: ScrollingCaptureCommitFrameSource
    let frameAgeMs: Int?
    let isDuplicateFrame: Bool
}

enum ScrollingCaptureCommitFrameSelection {
    static func streamFrameForCommit(
        ring: ScrollingCaptureFrameRing,
    ) -> ScrollingCaptureFrame? {
        if let lastCommittedSequenceNumber = ring.lastCommittedSequenceNumber {
            return ring.latestFrame(after: lastCommittedSequenceNumber)
        }
        return ring.latest
    }

    static func makeOnDemandFrame(
        streamFrame: ScrollingCaptureFrame?,
        normalizedImage: CGImage,
    ) -> ScrollingCaptureCommitFrame {
        ScrollingCaptureCommitFrame(
            image: normalizedImage,
            sequenceNumber: streamFrame?.sequenceNumber,
            source: .onDemand,
            frameAgeMs: nil,
            isDuplicateFrame: false,
        )
    }

    static func makeStreamFrame(
        streamFrame: ScrollingCaptureFrame,
        normalizedImage: CGImage,
        lastCommittedSequenceNumber: Int?,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime,
    ) -> ScrollingCaptureCommitFrame {
        let isDuplicate = lastCommittedSequenceNumber
            .map { streamFrame.sequenceNumber <= $0 } ?? false
        let frameAgeMs = max(0, Int(((now - streamFrame.capturedAt) * 1_000).rounded()))
        return ScrollingCaptureCommitFrame(
            image: normalizedImage,
            sequenceNumber: streamFrame.sequenceNumber,
            source: .stream,
            frameAgeMs: frameAgeMs,
            isDuplicateFrame: isDuplicate,
        )
    }

    static func selectedFrame(
        onDemandFrame: ScrollingCaptureCommitFrame?,
        streamFrame: ScrollingCaptureCommitFrame?,
    ) -> ScrollingCaptureCommitFrame? {
        guard
            let selectedSource = ScrollingCaptureSessionPolicy.preferredCommitFrameSource(
                hasOnDemandFrame: onDemandFrame != nil,
                hasStreamFrame: streamFrame != nil,
            )
        else {
            return nil
        }

        switch selectedSource {
        case .onDemand:
            return onDemandFrame
        case .stream:
            return streamFrame
        }
    }
}

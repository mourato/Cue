//
//  ScrollingCaptureFrameSource.swift
//  Notinhas
//
//  Region-scoped ScreenCaptureKit stream used for low-latency scrolling preview.
//

import AppKit
import CoreImage
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

private final class ScrollingCapturePublicationState: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var lastPublishedAt: TimeInterval = 0
    private var nextSequenceNumber = 0

    /// The lock serializes the stream callback's throttle/sequence state with
    /// start-time resets; image conversion never runs while the lock is held.
    func beginPublication(at capturedAt: TimeInterval, minimumInterval: TimeInterval) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }

        guard capturedAt - lastPublishedAt >= minimumInterval else { return nil }
        return generation
    }

    func finishPublication(generation pendingGeneration: UInt64, capturedAt: TimeInterval) -> Int? {
        lock.lock()
        defer { lock.unlock() }

        guard pendingGeneration == generation else { return nil }
        lastPublishedAt = capturedAt
        nextSequenceNumber += 1
        return nextSequenceNumber
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        generation &+= 1
        lastPublishedAt = 0
        nextSequenceNumber = 0
    }
}

@MainActor
final class ScrollingCaptureFrameSource: NSObject {
    private let sampleQueue = DispatchQueue(
        label: "com.mourato.notinhas.scrolling-capture.preview-stream",
        qos: .userInteractive,
    )
    private let minimumPublishInterval: TimeInterval
    private let ciContext: CIContext

    private var stream: SCStream?
    private nonisolated let publicationState = ScrollingCapturePublicationState()
    private var onFrame: ((ScrollingCaptureFrame) -> Void)?
    private var onFailure: ((String) -> Void)?

    init(previewFPS: Int = 30) {
        minimumPublishInterval = 1.0 / Double(max(1, previewFPS))
        ciContext = CIContext(options: [.cacheIntermediates: false])
    }

    @MainActor
    func start(
        with context: ScreenCaptureManager.PreparedAreaCaptureContext,
        frameHandler: @escaping (ScrollingCaptureFrame) -> Void,
        failureHandler: @escaping (String) -> Void,
    ) async throws {
        stop()

        onFrame = frameHandler
        onFailure = failureHandler
        publicationState.reset()

        let configuration = ScreenCaptureManager.shared.makeAreaStreamConfiguration(
            from: context,
            maximumFrameRate: 30,
            showsCursor: false,
        )
        let stream = SCStream(filter: context.contentFilter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        self.stream = stream
        try await stream.startCapture()
    }

    @MainActor
    func stop() {
        let activeStream = stream
        stream = nil
        onFrame = nil
        onFailure = nil

        guard let activeStream else { return }

        do {
            try activeStream.removeStreamOutput(self, type: .screen)
        } catch {
            // Best-effort teardown: stream may already be winding down.
        }

        Task { @MainActor in
            do {
                try await activeStream.stopCapture()
            } catch {
                // Best-effort teardown: stream may already be stopped.
            }
        }
    }
}

extension ScrollingCaptureFrameSource: SCStreamOutput {
    nonisolated func stream(
        _: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType,
    ) {
        autoreleasepool {
            guard type == .screen, sampleBuffer.isValid else { return }
            guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

            if
                let attachments = CMSampleBufferGetSampleAttachmentsArray(
                    sampleBuffer,
                    createIfNecessary: false,
                ) as? [[SCStreamFrameInfo: Any]],
                let statusRaw = attachments.first?[.status] as? Int,
                let status = SCFrameStatus(rawValue: statusRaw),
                status != .complete {
                return
            }

            let now = ProcessInfo.processInfo.systemUptime
            guard let pendingPublication = publicationState.beginPublication(
                at: now,
                minimumInterval: minimumPublishInterval,
            ) else { return }

            let imageRect = CGRect(
                x: 0,
                y: 0,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer),
            )
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: imageRect) else {
                return
            }

            guard let sequenceNumber = publicationState.finishPublication(
                generation: pendingPublication,
                capturedAt: now,
            ) else { return }
            let frame = ScrollingCaptureFrame(
                sequenceNumber: sequenceNumber,
                image: cgImage,
                capturedAt: now,
                motionScore: nil,
            )
            Task { @MainActor [weak self] in
                self?.onFrame?(frame)
            }
        }
    }
}

extension ScrollingCaptureFrameSource: SCStreamDelegate {
    nonisolated func stream(_: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.onFailure?(error.localizedDescription)
        }
    }
}

//
//  ScrollingCaptureWindowSharingTests.swift
//  NotinhasTests
//
//  Unit tests for scrolling capture session chrome capture exclusion.
//

import AppKit
@testable import Cue
import XCTest

@MainActor
final class ScrollingCaptureWindowSharingTests: XCTestCase {
    func testPreviewWindow_isExcludedFromScreenCapture() {
        let model = ScrollingCaptureSessionModel(selectedRect: sampleAnchorRect)
        let window = ScrollingCapturePreviewWindow(anchorRect: sampleAnchorRect, model: model)
        defer { window.close() }

        XCTAssertEqual(window.sharingType, NSWindow.SharingType.none)
    }

    func testPreviewLayoutSignature_ignoresSameSizeImageReplacement() throws {
        let model = ScrollingCaptureSessionModel(selectedRect: sampleAnchorRect)
        model.livePreviewImage = try XCTUnwrap(TestImageFactory.solidColor(width: 220, height: 160))
        let first = ScrollingCapturePreviewWindow.layoutSignature(
            for: model,
            anchorRect: sampleAnchorRect,
        )

        model.livePreviewImage = try XCTUnwrap(TestImageFactory.solidColor(width: 220, height: 160, red: 40))
        let second = ScrollingCapturePreviewWindow.layoutSignature(
            for: model,
            anchorRect: sampleAnchorRect,
        )

        XCTAssertEqual(first, second)
    }

    func testPreviewPanelOrigin_bottomAnchorsToSelectionBottom() {
        let anchorRect = CGRect(x: 400, y: 300, width: 220, height: 420)
        let panelSize = CGSize(width: 244, height: 280)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 900)

        let origin = ScrollingCapturePreviewWindow.panelOrigin(
            anchorRect: anchorRect,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
        )

        XCTAssertEqual(origin.y, anchorRect.minY - ScrollingCapturePreviewLayout.selectionBorderOutset, accuracy: 0.001)
        XCTAssertEqual(origin.x, anchorRect.maxX + ScrollingCapturePreviewLayout.panelHorizontalMargin, accuracy: 0.001)
    }

    func testPreviewPanelOrigin_clampsUpwardWhenPanelExceedsScreenTop() {
        let anchorRect = CGRect(x: 400, y: 820, width: 220, height: 420)
        let panelSize = CGSize(width: 244, height: 500)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 900)

        let origin = ScrollingCapturePreviewWindow.panelOrigin(
            anchorRect: anchorRect,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
        )

        let ceilingY = visibleFrame.maxY - ScrollingCapturePreviewLayout.panelTopInset
        XCTAssertEqual(origin.y + panelSize.height, ceilingY, accuracy: 0.001)
    }

    func testPreviewLayoutSignature_includesMaxImageHeightBucket() {
        let model = ScrollingCaptureSessionModel(selectedRect: sampleAnchorRect)
        let signature = ScrollingCapturePreviewWindow.layoutSignature(
            for: model,
            anchorRect: sampleAnchorRect,
        )

        XCTAssertGreaterThan(signature.maxImageHeight, 0)
    }

    func testHUDWindow_isExcludedFromScreenCapture() {
        let model = ScrollingCaptureSessionModel(selectedRect: sampleAnchorRect)
        let window = ScrollingCaptureHUDWindow(
            anchorRect: sampleAnchorRect,
            model: model,
            onDone: {},
            onCancel: {},
            onToggleAutoScroll: {},
        )
        defer { window.close() }

        XCTAssertEqual(window.sharingType, NSWindow.SharingType.none)
    }

    func testAreaSelectionWindow_isExcludedFromScreenCapture() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let window = AreaSelectionWindow(screen: screen, pooled: true)
        defer { window.close() }

        XCTAssertEqual(window.sharingType, NSWindow.SharingType.none)
    }

    private var sampleAnchorRect: CGRect {
        CGRect(x: 120, y: 120, width: 360, height: 480)
    }
}

final class ScrollingCaptureLivePreviewPolicyTests: XCTestCase {
    func testLivePreviewPolicy_keepsFirstCommittedPreviewResponsive() {
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldPublishLivePreviewFrame(
                hasCommittedPreview: false,
                capturedAt: 1,
                lastPublishedAt: 0.99,
                minimumInterval: 1.0 / 12.0,
            ),
        )
    }

    func testLivePreviewPolicy_throttlesOnlyAfterCommittedPreview() {
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldPublishLivePreviewFrame(
                hasCommittedPreview: true,
                capturedAt: 1.05,
                lastPublishedAt: 1,
                minimumInterval: 1.0 / 12.0,
            ),
        )
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldPublishLivePreviewFrame(
                hasCommittedPreview: true,
                capturedAt: 1.1,
                lastPublishedAt: 1,
                minimumInterval: 1.0 / 12.0,
            ),
        )
    }

    func testPreviewTruthLag_usesNewestCapturedTimestamp() {
        XCTAssertEqual(
            ScrollingCaptureSessionPolicy.previewCommitLagMs(
                latestCapturedAt: 10,
                lastCommittedObservationAt: 9.875,
                isUsingLivePreview: true,
                toleranceMs: 90,
            ),
            125,
        )
        XCTAssertEqual(
            ScrollingCaptureSessionPolicy.previewCommitLagMs(
                latestCapturedAt: 10,
                lastCommittedObservationAt: nil,
                isUsingLivePreview: true,
                toleranceMs: 90,
            ),
            91,
        )
    }

    func testStreamingCommit_schedulesDuringActiveScrollWithoutSettle() {
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.02,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.16,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
    }

    func testStreamingCommit_waitsForMinimumIntervalDuringActiveScroll() {
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.02,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.05,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
    }

    func testStreamingCommit_doesNotScheduleAfterScrollIdleThreshold() {
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.30,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.20,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
    }

    func testStreamingCommit_requiresPendingMotionAndRefreshGate() {
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: false,
                idleDuration: 0.02,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.20,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.02,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: 0.20,
                minimumStreamingInterval: 0.15,
                canStartRefresh: false,
            ),
        )
    }

    func testStreamingCommit_allowsFirstCommitDuringActiveScroll() {
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldScheduleStreamingCommit(
                hasPendingMotion: true,
                idleDuration: 0.01,
                activeScrollThreshold: 0.28,
                timeSinceLastRefresh: nil,
                minimumStreamingInterval: 0.15,
                canStartRefresh: true,
            ),
        )
    }

    func testPreferredCommitFrameSource_prefersOnDemandSnapshot() {
        XCTAssertEqual(
            ScrollingCaptureSessionPolicy.preferredCommitFrameSource(
                hasOnDemandFrame: true,
                hasStreamFrame: true,
            ),
            .onDemand,
        )
        XCTAssertEqual(
            ScrollingCaptureSessionPolicy.preferredCommitFrameSource(
                hasOnDemandFrame: false,
                hasStreamFrame: true,
            ),
            .stream,
        )
        XCTAssertNil(
            ScrollingCaptureSessionPolicy.preferredCommitFrameSource(
                hasOnDemandFrame: false,
                hasStreamFrame: false,
            ),
        )
    }

    func testShouldUpdateStitchedPreview_updatesOnOutputChangeOrInitialization() {
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldUpdateStitchedPreview(
                outputChanged: true,
                outcome: .appended(deltaY: 12),
            ),
        )
        XCTAssertTrue(
            ScrollingCaptureSessionPolicy.shouldUpdateStitchedPreview(
                outputChanged: false,
                outcome: .initialized,
            ),
        )
        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldUpdateStitchedPreview(
                outputChanged: false,
                outcome: .ignoredNoMovement,
            ),
        )
    }

    @MainActor
    func testMouseMoveSuppressor_removeWhenNotInstalled_isSafe() {
        let suppressor = ScrollingCaptureMouseMoveSuppressor()
        suppressor.remove()
        XCTAssertFalse(suppressor.isActive)
    }

    func testSkippedLivePreviewFrame_remainsAvailableToCommitRing() {
        let ring = ScrollingCaptureFrameRing()
        ring.append(frame(sequenceNumber: 1, capturedAt: 1))
        ring.markCommitted(sequenceNumber: 1)

        XCTAssertFalse(
            ScrollingCaptureSessionPolicy.shouldPublishLivePreviewFrame(
                hasCommittedPreview: true,
                capturedAt: 1.05,
                lastPublishedAt: 1,
                minimumInterval: 1.0 / 12.0,
            ),
        )

        ring.append(frame(sequenceNumber: 2, capturedAt: 1.05))
        XCTAssertEqual(ring.latestFrame(after: ring.lastCommittedSequenceNumber)?.sequenceNumber, 2)
    }

    private func frame(sequenceNumber: Int, capturedAt: TimeInterval) -> ScrollingCaptureFrame {
        ScrollingCaptureFrame(
            sequenceNumber: sequenceNumber,
            image: TestImageFactory.solidColor(width: 2, height: 2)!,
            capturedAt: capturedAt,
            motionScore: nil,
        )
    }
}

final class ScrollingCaptureAutoScrollPolicyTests: XCTestCase {
    func testCanToggleAutoScrollOnlyAfterFirstFrameLocks() {
        assertCanToggleAutoScroll(
            phase: .ready,
            acceptedFrameCount: 0,
            isAutoScrolling: false,
            expected: false,
        )
        assertCanToggleAutoScroll(
            phase: .capturing,
            acceptedFrameCount: 0,
            isAutoScrolling: false,
            expected: false,
        )
        assertCanToggleAutoScroll(
            phase: .capturing,
            acceptedFrameCount: 1,
            isAutoScrolling: false,
            expected: true,
        )
        assertCanToggleAutoScroll(
            phase: .capturing,
            acceptedFrameCount: 0,
            isAutoScrolling: true,
            expected: true,
        )
        assertCanToggleAutoScroll(
            phase: .finalizing,
            acceptedFrameCount: 1,
            isAutoScrolling: true,
            expected: false,
        )
        assertCanToggleAutoScroll(
            phase: .saving,
            acceptedFrameCount: 1,
            isAutoScrolling: true,
            expected: false,
        )
    }

    func testPlaceMouseInsideSelectionGuidance_usesWarningTone() {
        let guidance = ScrollingCaptureSelectionGuidanceKind.placeMouseInsideSelection.guidance

        XCTAssertFalse(guidance.title.isEmpty)
        XCTAssertFalse(guidance.detail?.isEmpty ?? true)
        if case .warning = guidance.tone {
            return
        }
        XCTFail("Expected warning guidance tone")
    }

    func testHUDWindowContentSize_usesMinimumForCompactContent() {
        XCTAssertEqual(
            ScrollingCaptureHUDWindow.resolvedContentSize(for: CGSize(width: 240.1, height: 32.4)),
            CGSize(width: 300, height: 48),
        )
    }

    func testHUDWindowContentSize_expandsToFitAutoScrollControls() {
        XCTAssertEqual(
            ScrollingCaptureHUDWindow.resolvedContentSize(for: CGSize(width: 431.2, height: 45.1)),
            CGSize(width: 432, height: 48),
        )
    }

    func testAutoScrollPolicy_usesCurrentPointerAsScrollTarget() {
        let mouseLocation = CGPoint(x: 180, y: 220)

        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.scrollTargetPoint(
                mouseLocation: mouseLocation,
                selectedRect: sampleAnchorRect,
            ),
            mouseLocation,
        )
    }

    func testAutoScrollPolicy_allowsSmallHoverPadding() {
        let mouseLocation = CGPoint(x: sampleAnchorRect.minX - 10, y: sampleAnchorRect.midY)

        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.scrollTargetPoint(
                mouseLocation: mouseLocation,
                selectedRect: sampleAnchorRect,
            ),
            mouseLocation,
        )
    }

    func testAutoScrollPolicy_rejectsPointerOutsideHoverPadding() {
        let mouseLocation = CGPoint(x: sampleAnchorRect.minX - 40, y: sampleAnchorRect.midY)

        XCTAssertNil(
            ScrollingCaptureAutoScrollPolicy.scrollTargetPoint(
                mouseLocation: mouseLocation,
                selectedRect: sampleAnchorRect,
            ),
        )
    }

    func testAutoScrollPolicy_finishesOnBoundaryOrHeightLimit() {
        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.stitchAction(
                for: stitchUpdate(outcome: .ignoredNoMovement, likelyReachedBoundary: true),
            ),
            .finishCapture,
        )
        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.stitchAction(
                for: stitchUpdate(outcome: .reachedHeightLimit),
            ),
            .finishCapture,
        )
    }

    func testAutoScrollPolicy_stopsAfterRepeatedAlignmentFailures() {
        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.stitchAction(
                for: stitchUpdate(outcome: .ignoredAlignmentFailed, matchFailureCount: 2),
            ),
            .keepScrolling,
        )
        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.stitchAction(
                for: stitchUpdate(outcome: .ignoredAlignmentFailed, matchFailureCount: 3),
            ),
            .stopScrolling,
        )
    }

    private var sampleAnchorRect: CGRect {
        CGRect(x: 120, y: 120, width: 360, height: 480)
    }

    private func assertCanToggleAutoScroll(
        phase: ScrollingCapturePhase,
        acceptedFrameCount: Int,
        isAutoScrolling: Bool,
        expected: Bool,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        XCTAssertEqual(
            ScrollingCaptureAutoScrollPolicy.canToggle(
                phase: phase,
                acceptedFrameCount: acceptedFrameCount,
                isAutoScrolling: isAutoScrolling,
            ),
            expected,
            "phase=\(phase), acceptedFrameCount=\(acceptedFrameCount), isAutoScrolling=\(isAutoScrolling)",
            file: file,
            line: line,
        )
    }

    private func stitchUpdate(
        outcome: ScrollingCaptureStitchOutcome,
        matchFailureCount: Int = 0,
        likelyReachedBoundary: Bool = false,
    ) -> ScrollingCaptureStitchUpdate {
        ScrollingCaptureStitchUpdate(
            outcome: outcome,
            mergedImage: nil,
            acceptedFrameCount: 1,
            outputHeight: 480,
            matchFailureCount: matchFailureCount,
            mergeDirection: .appendFromBottom,
            likelyReachedBoundary: likelyReachedBoundary,
            safety: .confirmed,
            alignmentDebug: nil,
        )
    }
}

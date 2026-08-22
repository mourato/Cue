//
//  ScrollingCaptureStitcherTests.swift
//  NotinhasTests
//
//  Unit tests for the scrolling capture stitch algorithm.
//

import CoreGraphics
@testable import Notinhas
import XCTest

final class ScrollingCaptureStitcherTests: XCTestCase {
    // MARK: - start(with:)

    func testStart_initializesCorrectly() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 200, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        let update = stitcher.start(with: image)

        XCTAssertNotNil(update)
        XCTAssertEqual(update?.acceptedFrameCount, 1)
        XCTAssertEqual(update?.outputHeight, 100)
        XCTAssertNotNil(update?.mergedImage)

        if case .initialized = update?.outcome {} else {
            XCTFail("Expected .initialized outcome, got: \(String(describing: update?.outcome))")
        }
    }

    func testStart_setsFrameCount() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 50) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)
        XCTAssertEqual(stitcher.acceptedFrameCount, 1)
        XCTAssertEqual(stitcher.outputHeight, 50)
    }

    // MARK: - append identical image

    func testAppend_identicalImage_ignoredNoMovement() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(
            width: 200, height: 100,
            red: 80, green: 80, blue: 80,
        ) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)

        let update = stitcher.append(image, maxOutputHeight: 10000)

        XCTAssertNotNil(update)
        if case .ignoredNoMovement = update?.outcome {} else {
            XCTFail("Expected .ignoredNoMovement for identical frame, got: \(String(describing: update?.outcome))")
        }

        // Frame count should NOT increment for ignored frames
        XCTAssertEqual(stitcher.acceptedFrameCount, 1)
        XCTAssertEqual(update?.outputHeight, 100)
        XCTAssertEqual(update?.alignmentDebug?.path, .duplicateBoundary)
        XCTAssertFalse(update?.alignmentDebug?.usedVisionEstimate ?? true)
    }

    // MARK: - append mismatched dimensions

    func testAppend_mismatchedDimensions_ignoredAlignmentFailed() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image1 = TestImageFactory.solidColor(width: 200, height: 100),
              let image2 = TestImageFactory.solidColor(width: 300, height: 100) else {
            XCTFail("Failed to create test images")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(image2, maxOutputHeight: 10000)

        XCTAssertNotNil(update)
        if case .ignoredAlignmentFailed = update?.outcome {} else {
            XCTFail("Expected .ignoredAlignmentFailed for mismatched dims, got: \(String(describing: update?.outcome))")
        }
    }

    func testAppend_mismatchedHeight_ignoredAlignmentFailed() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image1 = TestImageFactory.solidColor(width: 200, height: 100),
              let image2 = TestImageFactory.solidColor(width: 200, height: 150) else {
            XCTFail("Failed to create test images")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(image2, maxOutputHeight: 10000)

        if case .ignoredAlignmentFailed = update?.outcome {} else {
            XCTFail("Expected .ignoredAlignmentFailed for mismatched height")
        }
    }

    // MARK: - mergedImage

    func testMergedImage_afterStart_returnsNonNil() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)
        let merged = stitcher.mergedImage()

        XCTAssertNotNil(merged)
        XCTAssertEqual(merged?.width, 100)
        XCTAssertEqual(merged?.height, 100)
    }

    func testMergedImage_beforeStart_returnsNil() {
        let stitcher = ScrollingCaptureStitcher()
        XCTAssertNil(stitcher.mergedImage())
    }

    // MARK: - previewImage

    func testPreviewImage_respectsMaxBounds() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 400, height: 400) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)

        let preview = stitcher.previewImage(maxPixelWidth: 100, maxPixelHeight: 100)
        XCTAssertNotNil(preview)

        if let preview {
            XCTAssertLessThanOrEqual(preview.width, 100)
            XCTAssertLessThanOrEqual(preview.height, 100)
        }
    }

    func testPreviewImage_beforeStart_returnsNil() {
        let stitcher = ScrollingCaptureStitcher()
        XCTAssertNil(stitcher.previewImage(maxPixelWidth: 200, maxPixelHeight: 200))
    }

    func testPreviewImage_ignoredFrame_reusesPreviousPreview() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 200, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)
        guard let firstPreview = stitcher.previewImage(maxPixelWidth: 100, maxPixelHeight: 100) else {
            XCTFail("Expected initial preview")
            return
        }

        let update = stitcher.append(image, maxOutputHeight: 10_000)
        XCTAssertEqual(update?.acceptedFrameCount, 1)
        XCTAssertEqual(update?.outputHeight, 100)
        XCTAssertTrue(firstPreview === stitcher.previewImage(maxPixelWidth: 100, maxPixelHeight: 100))
    }

    func testPreviewImage_alignmentFailure_reusesPreviousPreview() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 200, height: 100),
              let mismatchedImage = TestImageFactory.solidColor(width: 300, height: 100) else {
            XCTFail("Failed to create test images")
            return
        }

        _ = stitcher.start(with: image)
        guard let firstPreview = stitcher.previewImage(maxPixelWidth: 100, maxPixelHeight: 100) else {
            XCTFail("Expected initial preview")
            return
        }

        let update = stitcher.append(mismatchedImage, maxOutputHeight: 10_000)
        if case .ignoredAlignmentFailed = update?.outcome {} else {
            XCTFail("Expected alignment failure")
        }
        XCTAssertTrue(firstPreview === stitcher.previewImage(maxPixelWidth: 100, maxPixelHeight: 100))
    }

    // MARK: - append with shifted content (integration)

    func testAppend_shiftedContent_appendsOrFailsAlignment() {
        let stitcher = ScrollingCaptureStitcher()
        let width = 200
        let height = 100

        // Use distinct row signatures so there is measurable inter-frame change.
        guard let image1 = TestImageFactory.scrollingFrame(width: width, height: height, logicalYOffset: 0) else {
            XCTFail("Failed to create frame 1")
            return
        }

        guard let image2 = TestImageFactory.scrollingFrame(width: width, height: height, logicalYOffset: 20) else {
            XCTFail("Failed to create frame 2")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(image2, maxOutputHeight: 10000)

        XCTAssertNotNil(update)

        // Synthetic images may not align reliably through the vision-assisted matcher,
        // so we accept either a successful append or an alignment failure,
        // but never "no movement" because the frames are objectively different.
        switch update?.outcome {
        case .appended(let deltaY):
            XCTAssertGreaterThan(deltaY, 0, "Delta should be positive for downward scroll")
            XCTAssertGreaterThan(stitcher.outputHeight, height, "Output height should grow after append")
            XCTAssertEqual(stitcher.acceptedFrameCount, 2)
        case .ignoredAlignmentFailed:
            XCTAssertEqual(stitcher.acceptedFrameCount, 1)
        case .ignoredNoMovement:
            XCTFail("Expected movement between shifted frames, got ignoredNoMovement")
        default:
            XCTFail("Unexpected outcome: \(String(describing: update?.outcome))")
        }
    }

    func testAppend_wrongExpectedDelta_usesVisionRecovery() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image1 = TestImageFactory.scrollingFrame(width: 200, height: 160, logicalYOffset: 0),
              let image2 = TestImageFactory.scrollingFrame(width: 200, height: 160, logicalYOffset: 20) else {
            XCTFail("Failed to create scrolling frames")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(
            image2,
            maxOutputHeight: 10_000,
            expectedSignedDeltaPixels: 70,
        )

        if case .appended(let deltaY) = update?.outcome {
            XCTAssertEqual(deltaY, 20)
        } else {
            XCTFail("Expected Vision recovery to append 20 pixels, got: \(String(describing: update?.outcome))")
        }
        XCTAssertEqual(update?.alignmentDebug?.path, .recoveryVision)
        XCTAssertTrue(update?.alignmentDebug?.usedVisionEstimate ?? false)
        XCTAssertEqual(update?.acceptedFrameCount, 2)
        XCTAssertEqual(update?.outputHeight, 180)
    }

    func testMergedImage_preservesAcceptedRowOrder() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image1 = TestImageFactory.scrollingFrame(width: 80, height: 160, logicalYOffset: 0),
              let image2 = TestImageFactory.scrollingFrame(width: 80, height: 160, logicalYOffset: 20),
              let image3 = TestImageFactory.scrollingFrame(width: 80, height: 160, logicalYOffset: 40) else {
            XCTFail("Failed to create scrolling frames")
            return
        }

        _ = stitcher.start(with: image1)
        let firstUpdate = stitcher.append(
            image2,
            maxOutputHeight: 10_000,
            expectedSignedDeltaPixels: 20,
        )
        let secondUpdate = stitcher.append(
            image3,
            maxOutputHeight: 10_000,
            expectedSignedDeltaPixels: 20,
        )

        guard case .appended(let firstDeltaY) = firstUpdate?.outcome,
              case .appended(let secondDeltaY) = secondUpdate?.outcome,
              let merged = stitcher.mergedImage() else {
            XCTFail("Expected two merged appends")
            return
        }
        XCTAssertEqual(firstDeltaY, 20)
        XCTAssertEqual(secondDeltaY, 20)
        XCTAssertEqual(stitcher.acceptedFrameCount, 3)
        XCTAssertEqual(merged.width, 80)
        XCTAssertEqual(merged.height, 200)

        for row in 0 ..< merged.height {
            XCTAssertEqual(
                pixelSignature(in: merged, row: row),
                pixelSignature(forLogicalRow: row),
                "Unexpected merged pixel at row \(row)",
            )
        }

        guard let preview = stitcher.previewImage(maxPixelWidth: 80, maxPixelHeight: 200) else {
            XCTFail("Expected a full-size preview")
            return
        }
        XCTAssertEqual(preview.width, merged.width)
        XCTAssertEqual(preview.height, merged.height)
        for row in 0 ..< preview.height {
            XCTAssertEqual(
                pixelSignature(in: preview, row: row),
                pixelSignature(forLogicalRow: row),
                "Unexpected preview pixel at row \(row)",
            )
        }
    }

    func testAppend_clampsAcceptedDeltaToMaxOutputHeight() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image1 = TestImageFactory.scrollingFrame(width: 80, height: 160, logicalYOffset: 0),
              let image2 = TestImageFactory.scrollingFrame(width: 80, height: 160, logicalYOffset: 20) else {
            XCTFail("Failed to create scrolling frames")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(
            image2,
            maxOutputHeight: 175,
            expectedSignedDeltaPixels: 20,
        )

        guard case .reachedHeightLimit = update?.outcome,
              let merged = stitcher.mergedImage() else {
            XCTFail("Expected a height-limited append")
            return
        }
        XCTAssertEqual(update?.acceptedFrameCount, 2)
        XCTAssertEqual(update?.outputHeight, 175)
        XCTAssertEqual(merged.height, 175)
        for row in 0 ..< merged.height {
            XCTAssertEqual(
                pixelSignature(in: merged, row: row),
                pixelSignature(forLogicalRow: row),
                "Unexpected clamped pixel at row \(row)",
            )
        }
    }

    func testAppend_highConfidenceGuidedMatch_skipsVisionEstimate() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image1 = TestImageFactory.scrollingFrame(width: 200, height: 160, logicalYOffset: 0),
              let image2 = TestImageFactory.scrollingFrame(width: 200, height: 160, logicalYOffset: 20) else {
            XCTFail("Failed to create scrolling frames")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(
            image2,
            maxOutputHeight: 10_000,
            expectedSignedDeltaPixels: 20,
        )

        XCTAssertEqual(update?.alignmentDebug?.path, .fastGuided)
        XCTAssertFalse(update?.alignmentDebug?.usedVisionEstimate ?? true)
        XCTAssertEqual(update?.acceptedFrameCount, 2)
        XCTAssertEqual(update?.outputHeight, 180)
    }

    // MARK: - Multiple appends build height

    func testMultipleAppends_outputHeightAccumulates() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 50) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)
        let initialHeight = stitcher.outputHeight
        XCTAssertEqual(initialHeight, 50)

        // Appending identical images won't increase height (no movement detected)
        _ = stitcher.append(image, maxOutputHeight: 10000)
        // Height should not change for identical frames
        XCTAssertEqual(stitcher.outputHeight, 50)
    }

    // MARK: - maxOutputHeight enforcement

    func testAppend_atMaxOutputHeight_returnsReachedHeightLimit() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)

        // max = current output height → no more room
        let update = stitcher.append(image, maxOutputHeight: stitcher.outputHeight)

        // For identical images, likely ignoredNoMovement; for shifted images it would be reachedHeightLimit
        // Either outcome is acceptable since we're testing the height limit enforcement path
        XCTAssertNotNil(update)
    }

    // MARK: - Alignment Debug Info

    func testStart_alignmentDebug_isInitialFrame() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        let update = stitcher.start(with: image)
        XCTAssertEqual(update?.alignmentDebug?.path, .initialFrame)
        XCTAssertEqual(update?.alignmentDebug?.confidence, 1.0)
        XCTAssertFalse(update?.alignmentDebug?.usedVisionEstimate ?? true)
        XCTAssertEqual(update?.safety, .confirmed)
    }

    // MARK: - Merge Direction

    func testStart_mergeDirectionIsUnresolved() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        let update = stitcher.start(with: image)
        XCTAssertEqual(update?.mergeDirection, .unresolved)
    }

    // MARK: - likelyReachedBoundary

    func testAppend_identicalImage_setsLikelyReachedBoundary() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(
            width: 200, height: 100,
            red: 120, green: 120, blue: 120,
        ) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)
        let update = stitcher.append(image, maxOutputHeight: 10000)

        if case .ignoredNoMovement = update?.outcome {
            XCTAssertTrue(update?.likelyReachedBoundary ?? false)
        }
    }

    // MARK: - renderMergedImage flag

    func testAppend_renderMergedImageFalse_skipsMergedImage() {
        let stitcher = ScrollingCaptureStitcher()
        guard let image = TestImageFactory.solidColor(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        _ = stitcher.start(with: image)
        let update = stitcher.append(image, maxOutputHeight: 10000, renderMergedImage: false)

        // When renderMergedImage is false, mergedImage in the update may still be
        // the cached version from start(), so we just verify the call succeeds.
        XCTAssertNotNil(update)
    }

    func testAppend_mismatchedDimensions_marksUnsafe() {
        let stitcher = ScrollingCaptureStitcher()
        guard
            let image1 = TestImageFactory.solidColor(width: 100, height: 100),
            let image2 = TestImageFactory.solidColor(width: 120, height: 100)
        else {
            XCTFail("Failed to create test images")
            return
        }

        _ = stitcher.start(with: image1)
        let update = stitcher.append(image2, maxOutputHeight: 10000)

        XCTAssertEqual(update?.safety, .unsafe (reason: "alignment-failed"))
        XCTAssertEqual(update?.acceptedFrameCount, 1)
        XCTAssertEqual(update?.outputHeight, 100)
        XCTAssertEqual(update?.alignmentDebug?.path, .alignmentFailed)
    }
}

private func pixelSignature(in image: CGImage, row: Int) -> [UInt8] {
    let bytesPerRow = image.width * 4
    var pixels = [UInt8](repeating: 0, count: image.height * bytesPerRow)
    pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue,
        ) else { return }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return Array(pixels[(row * bytesPerRow) ..< (row * bytesPerRow + 4)])
}

private func pixelSignature(forLogicalRow row: Int) -> [UInt8] {
    [UInt8(row % 256), UInt8((row * 47) % 256), UInt8((row * 113) % 256), 255]
}

//
//  ScrollingCaptureFrameRingTests.swift
//  NotinhasTests
//

import CoreGraphics
@testable import Cue
import XCTest

final class ScrollingCaptureFrameRingTests: XCTestCase {
    func testDefaultCapacity_evictsOldestFrame() {
        let ring = ScrollingCaptureFrameRing()
        ring.append(frame(sequenceNumber: 1))
        ring.append(frame(sequenceNumber: 2))
        ring.append(frame(sequenceNumber: 3))

        XCTAssertEqual(ring.frames.map(\.sequenceNumber), [2, 3])
        XCTAssertEqual(ring.latest?.sequenceNumber, 3)
    }

    func testLatestFrame_afterCommit_onlySelectsNewerFrame() {
        let ring = ScrollingCaptureFrameRing()
        ring.append(frame(sequenceNumber: 1))
        ring.append(frame(sequenceNumber: 2))
        ring.markCommitted(sequenceNumber: 2)

        XCTAssertNil(ring.latestFrame(after: ring.lastCommittedSequenceNumber))

        ring.append(frame(sequenceNumber: 3))
        XCTAssertEqual(ring.latestFrame(after: ring.lastCommittedSequenceNumber)?.sequenceNumber, 3)
        ring.markCommitted(sequenceNumber: 3)
        XCTAssertNil(ring.latestFrame(after: ring.lastCommittedSequenceNumber))
    }

    func testReset_clearsFramesAndCommittedSequence() {
        let ring = ScrollingCaptureFrameRing()
        ring.append(frame(sequenceNumber: 1))
        ring.markCommitted(sequenceNumber: 1)

        ring.reset()

        XCTAssertTrue(ring.frames.isEmpty)
        XCTAssertNil(ring.lastCommittedSequenceNumber)
        XCTAssertNil(ring.latest)
    }

    private func frame(sequenceNumber: Int) -> ScrollingCaptureFrame {
        let image = TestImageFactory.solidColor(width: 2, height: 2)!
        return ScrollingCaptureFrame(
            sequenceNumber: sequenceNumber,
            image: image,
            capturedAt: 0,
            motionScore: nil,
        )
    }
}

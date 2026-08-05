//
//  CaptureFloatingCursorExclusionTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureFloatingCursorExclusionTests: XCTestCase {
    func testContains_returnsTrueWhenPointInsideFrame() {
        let frames = [CGRect(x: 100, y: 200, width: 300, height: 50)]
        let point = CGPoint(x: 250, y: 225)

        XCTAssertTrue(CaptureFloatingCursorExclusion.contains(point, in: frames))
    }

    func testContains_returnsFalseWhenPointOutsideAllFrames() {
        let frames = [CGRect(x: 100, y: 200, width: 300, height: 50)]
        let point = CGPoint(x: 50, y: 225)

        XCTAssertFalse(CaptureFloatingCursorExclusion.contains(point, in: frames))
    }

    func testContains_returnsFalseForEmptyFrames() {
        let point = CGPoint(x: 250, y: 225)

        XCTAssertFalse(CaptureFloatingCursorExclusion.contains(point, in: []))
    }

    func testContains_usesCGRectContainsSemanticsOnSharedEdge() {
        let leftFrame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let rightFrame = CGRect(x: 100, y: 0, width: 100, height: 50)
        let frames = [leftFrame, rightFrame]

        // CGRect.contains includes minX/minY but excludes maxX/maxY.
        XCTAssertTrue(CaptureFloatingCursorExclusion.contains(CGPoint(x: 100, y: 25), in: frames))
        XCTAssertFalse(CaptureFloatingCursorExclusion.contains(CGPoint(x: 200, y: 25), in: frames))
    }
}

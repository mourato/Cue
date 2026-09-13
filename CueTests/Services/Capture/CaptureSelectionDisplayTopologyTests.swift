//
//  CaptureSelectionDisplayTopologyTests.swift
//  CueTests
//
//  Tests for multi-monitor desktop union frame and rect clamping.
//

import AppKit
@testable import Cue
import XCTest

@MainActor
final class CaptureSelectionDisplayTopologyTests: XCTestCase {
    func testUnifiedDesktopFrame_computesUnionOfScreens() {
        let screen1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2 = CGRect(x: 1920, y: 0, width: 2560, height: 1440)

        let union = screen1.union(screen2)
        XCTAssertEqual(union.origin.x, 0)
        XCTAssertEqual(union.origin.y, 0)
        XCTAssertEqual(union.width, 1920 + 2560)
        XCTAssertEqual(union.height, 1440)
    }

    func testClampRect_insideBoundsRemainsUnchanged() {
        let bounds = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        let rect = CGRect(x: 100, y: 200, width: 300, height: 400)

        let clamped = CaptureSelectionDisplayTopology.clampRect(rect, to: bounds)
        XCTAssertEqual(clamped, rect)
    }

    func testClampRect_outsideBoundsClampedWithinFrame() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        // Beyond minX / minY
        let leftTop = CGRect(x: -50, y: -20, width: 200, height: 200)
        let clampedLT = CaptureSelectionDisplayTopology.clampRect(leftTop, to: bounds)
        XCTAssertEqual(clampedLT.origin.x, 0)
        XCTAssertEqual(clampedLT.origin.y, 0)
        XCTAssertEqual(clampedLT.size, CGSize(width: 200, height: 200))

        // Beyond maxX / maxY
        let rightBottom = CGRect(x: 950, y: 900, width: 200, height: 200)
        let clampedRB = CaptureSelectionDisplayTopology.clampRect(rightBottom, to: bounds)
        XCTAssertEqual(clampedRB.origin.x, 800)
        XCTAssertEqual(clampedRB.origin.y, 800)
        XCTAssertEqual(clampedRB.size, CGSize(width: 200, height: 200))
    }

    func testClampResizedRect_respectsBoundsAndMinimumSize() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let oversize = CGRect(x: -100, y: -50, width: 1500, height: 1200)

        let clamped = CaptureSelectionDisplayTopology.clampResizedRect(oversize, to: bounds, minSize: 10)
        XCTAssertGreaterThanOrEqual(clamped.minX, bounds.minX)
        XCTAssertGreaterThanOrEqual(clamped.minY, bounds.minY)
        XCTAssertLessThanOrEqual(clamped.maxX, bounds.maxX)
        XCTAssertLessThanOrEqual(clamped.maxY, bounds.maxY)
        XCTAssertGreaterThanOrEqual(clamped.width, 10)
        XCTAssertGreaterThanOrEqual(clamped.height, 10)
    }

    func testAppKitRect_convertsDisplayLocalTopLeftToGlobalBottomLeft() {
        let screenFrame = CGRect(x: 100, y: 200, width: 1920, height: 1080)
        let rect = CaptureSelectionDisplayTopology.appKitRect(
            fromDisplayLocalTopLeftX: 10,
            y: 20,
            width: 300,
            height: 150,
            screenFrame: screenFrame,
        )
        XCTAssertEqual(rect.origin.x, 110)
        XCTAssertEqual(rect.origin.y, 200 + 1080 - 20 - 150)
        XCTAssertEqual(rect.size, CGSize(width: 300, height: 150))
    }

    func testScreensOrderedForDeepLink_placesMainFirst() {
        let screens = NSScreen.screens
        guard screens.count >= 1 else { return }
        let ordered = CaptureSelectionDisplayTopology.screensOrderedForDeepLink(screens)
        XCTAssertEqual(ordered.count, screens.count)
        if let main = ordered.first?.displayID {
            XCTAssertEqual(main, CGMainDisplayID())
        }
        let first = CaptureSelectionDisplayTopology.screenForDeepLinkDisplay(1, screens: screens)
        XCTAssertEqual(first?.displayID, ordered.first?.displayID)
    }
}

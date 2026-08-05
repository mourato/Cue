//
//  AllInOneCaptureModeTests.swift
//  NotinhasTests
//
//  Unit tests for All-In-One capture mode availability and stability.
//

@testable import Notinhas
import XCTest

final class AllInOneCaptureModeTests: XCTestCase {
    func testAvailableModes_withoutVideo_excludesRecording() {
        let modes = AllInOneCaptureMode.availableModes(videoEnabled: false)

        XCTAssertEqual(
            modes,
            [.area, .fullscreen, .window, .annotate, .scrolling, .timer, .ocr],
        )
        XCTAssertFalse(modes.contains(.recording))
    }

    func testAvailableModes_withVideo_includesRecordingLast() {
        let modes = AllInOneCaptureMode.availableModes(videoEnabled: true)

        XCTAssertEqual(modes.last, .recording)
        XCTAssertTrue(modes.contains(.recording))
        XCTAssertEqual(modes.count, 8)
    }

    func testRawValues_areStable() {
        XCTAssertEqual(AllInOneCaptureMode.area.rawValue, "area")
        XCTAssertEqual(AllInOneCaptureMode.fullscreen.rawValue, "fullscreen")
        XCTAssertEqual(AllInOneCaptureMode.window.rawValue, "window")
        XCTAssertEqual(AllInOneCaptureMode.annotate.rawValue, "annotate")
        XCTAssertEqual(AllInOneCaptureMode.scrolling.rawValue, "scrolling")
        XCTAssertEqual(AllInOneCaptureMode.timer.rawValue, "timer")
        XCTAssertEqual(AllInOneCaptureMode.ocr.rawValue, "ocr")
        XCTAssertEqual(AllInOneCaptureMode.recording.rawValue, "recording")
    }

    func testPreservesSelectionRect_matchesExpectedModes() {
        XCTAssertTrue(AllInOneCaptureMode.area.preservesSelectionRect)
        XCTAssertTrue(AllInOneCaptureMode.annotate.preservesSelectionRect)
        XCTAssertTrue(AllInOneCaptureMode.scrolling.preservesSelectionRect)
        XCTAssertTrue(AllInOneCaptureMode.timer.preservesSelectionRect)
        XCTAssertTrue(AllInOneCaptureMode.ocr.preservesSelectionRect)
        XCTAssertTrue(AllInOneCaptureMode.recording.preservesSelectionRect)
        XCTAssertFalse(AllInOneCaptureMode.fullscreen.preservesSelectionRect)
        XCTAssertFalse(AllInOneCaptureMode.window.preservesSelectionRect)
    }

    func testTitlesAndAccessibilityLabels_areNonEmpty() {
        for videoEnabled in [false, true] {
            for mode in AllInOneCaptureMode.availableModes(videoEnabled: videoEnabled) {
                XCTAssertFalse(mode.title.isEmpty, mode.rawValue)
                XCTAssertFalse(mode.compactTitle.isEmpty, mode.rawValue)
                XCTAssertFalse(mode.accessibilityLabel.isEmpty, mode.rawValue)
                XCTAssertFalse(mode.systemImage.isEmpty, mode.rawValue)
            }
        }
    }

    func testCommandMatrix_routesEveryMode() {
        let rect = CGRect(x: 40, y: 50, width: 320, height: 180)

        XCTAssertEqual(AllInOneCaptureCommand.make(for: .area, rect: rect), .area(rect))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .fullscreen, rect: rect), .fullscreen)
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .window, rect: rect), .window)
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .annotate, rect: rect), .annotate(rect))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .scrolling, rect: rect), .scrolling(rect))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .timer, rect: rect), .timer(rect))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .ocr, rect: rect), .ocr(rect))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .recording, rect: rect), .recording)
    }

    func testCommandMatrix_preservesNoRectFallback() {
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .area, rect: nil), .area(nil))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .annotate, rect: nil), .annotate(nil))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .scrolling, rect: nil), .scrolling(nil))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .timer, rect: nil), .timer(nil))
        XCTAssertEqual(AllInOneCaptureCommand.make(for: .ocr, rect: nil), .ocr(nil))
    }
}

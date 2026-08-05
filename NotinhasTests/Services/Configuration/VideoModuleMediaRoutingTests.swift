//
//  VideoModuleMediaRoutingTests.swift
//  NotinhasTests
//
//  Pure routing tests for History / Quick Access / deep-link video gating.
//

@testable import Notinhas
import XCTest

final class VideoModuleMediaRoutingTests: XCTestCase {
    func testHistoryOpenDestinationScreenshotsAlwaysAnnotate() {
        XCTAssertEqual(
            VideoModuleMediaRouting.historyOpenDestination(for: .screenshot, videoModuleEnabled: false),
            .annotate,
        )
        XCTAssertEqual(
            VideoModuleMediaRouting.historyOpenDestination(for: .screenshot, videoModuleEnabled: true),
            .annotate,
        )
    }

    func testHistoryOpenDestinationVideoAndGifRevealWhenModuleOff() {
        for type in [CaptureHistoryType.video, .gif] {
            XCTAssertEqual(
                VideoModuleMediaRouting.historyOpenDestination(for: type, videoModuleEnabled: false),
                .revealInFinder,
                "\(type) should reveal in Finder when Video module is off",
            )
        }
    }

    func testHistoryOpenDestinationVideoAndGifEditorWhenModuleOn() {
        for type in [CaptureHistoryType.video, .gif] {
            XCTAssertEqual(
                VideoModuleMediaRouting.historyOpenDestination(for: type, videoModuleEnabled: true),
                .videoEditor,
                "\(type) should open Video Editor when Video module is on",
            )
        }
    }

    func testQuickAccessVideoOpenDestination() {
        XCTAssertEqual(
            VideoModuleMediaRouting.quickAccessVideoOpenDestination(videoModuleEnabled: false),
            .revealInFinder,
        )
        XCTAssertEqual(
            VideoModuleMediaRouting.quickAccessVideoOpenDestination(videoModuleEnabled: true),
            .videoEditor,
        )
    }

    func testEditActionAvailableForScreenshotsRegardlessOfModule() {
        XCTAssertTrue(VideoModuleMediaRouting.isEditActionAvailable(isVideo: false, videoModuleEnabled: false))
        XCTAssertTrue(VideoModuleMediaRouting.isEditActionAvailable(isVideo: false, videoModuleEnabled: true))
    }

    func testEditActionHiddenForVideoWhenModuleOff() {
        XCTAssertFalse(VideoModuleMediaRouting.isEditActionAvailable(isVideo: true, videoModuleEnabled: false))
        XCTAssertTrue(VideoModuleMediaRouting.isEditActionAvailable(isVideo: true, videoModuleEnabled: true))
    }

    func testShouldDispatchVideoAction() {
        XCTAssertFalse(VideoModuleMediaRouting.shouldDispatchVideoAction(videoModuleEnabled: false))
        XCTAssertTrue(VideoModuleMediaRouting.shouldDispatchVideoAction(videoModuleEnabled: true))
    }
}

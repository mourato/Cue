//
//  CaptureFloatingHUDWindowTests.swift
//  NotinhasTests
//

import AppKit
@testable import Notinhas
import SwiftUI
import XCTest

@MainActor
final class CaptureFloatingHUDWindowTests: XCTestCase {
    func testFloatingHUD_acceptsFirstMouseWithoutBecomingKey() {
        let window = CaptureFloatingHUDWindow()
        window.setContent(AnyView(Text("HUD")))

        XCTAssertTrue(window.contentView?.acceptsFirstMouse(for: nil) == true)
        XCTAssertFalse(window.canBecomeKey)

        window.close()
    }

    func testFloatingHUD_displayLevelTransitionsTogether() {
        let modeHUD = CaptureFloatingHUDWindow()
        let actionHUD = CaptureFloatingHUDWindow()
        modeHUD.setContent(AnyView(Text("Mode")))
        actionHUD.setContent(AnyView(Text("Action")))

        modeHUD.setDisplayLevel(.aboveCaptureOverlay)
        actionHUD.setDisplayLevel(.aboveCaptureOverlay)

        XCTAssertEqual(modeHUD.displayLevel, .aboveCaptureOverlay)
        XCTAssertEqual(actionHUD.displayLevel, .aboveCaptureOverlay)
        XCTAssertEqual(modeHUD.level, .screenSaver)
        XCTAssertEqual(actionHUD.level, .screenSaver)

        modeHUD.restoreStandardDisplayLevel()
        actionHUD.restoreStandardDisplayLevel()

        XCTAssertEqual(modeHUD.displayLevel, .standard)
        XCTAssertEqual(actionHUD.displayLevel, .standard)
        XCTAssertEqual(modeHUD.level, .popUpMenu)

        modeHUD.close()
        actionHUD.close()
    }

    func testHUDWindow_usesTransparentNonActivatingHost() {
        let window = CaptureFloatingHUDWindow()
        window.setContent(AnyView(Text("HUD")))

        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertTrue(window.contentView is NSHostingView<AnyView>)
        XCTAssertFalse(window.contentView is NSVisualEffectView)

        window.close()
    }
}

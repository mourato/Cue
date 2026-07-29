//
//  AllInOneCaptureCoordinatorTests.swift
//  NotinhasTests
//
//  Unit tests for All-In-One coordinator session state.
//

import Carbon.HIToolbox
@testable import Notinhas
import SwiftUI
import XCTest

@MainActor
final class AllInOneCaptureCoordinatorTests: XCTestCase {
  override func tearDown() {
    AllInOneCaptureCoordinator.shared.cancel()
    super.tearDown()
  }

  func testCoordinator_startsInactive() {
    XCTAssertFalse(AllInOneCaptureCoordinator.shared.isSessionActive)
  }

  func testCoordinator_cancelAfterHUDSession_doesNotCrashAndClearsActiveFlag() {
    let coordinator = AllInOneCaptureCoordinator.shared
    coordinator.seedActiveHUDSessionForTesting()
    XCTAssertTrue(coordinator.isSessionActive)

    coordinator.cancel()

    XCTAssertFalse(coordinator.isSessionActive)

    // Drain the deferred MainActor release of HUD / session state.
    let deferredRelease = expectation(description: "deferred All-In-One teardown release")
    DispatchQueue.main.async {
      deferredRelease.fulfill()
    }
    wait(for: [deferredRelease], timeout: 1.0)
  }

  func testCoordinator_cancelActiveSessionTwice_isIdempotent() {
    let coordinator = AllInOneCaptureCoordinator.shared
    coordinator.seedActiveHUDSessionForTesting()

    coordinator.cancel()
    coordinator.cancel()

    XCTAssertFalse(coordinator.isSessionActive)
  }

  func testCoordinator_reseedAfterCancel_replacesSessionWithoutCrash() {
    let coordinator = AllInOneCaptureCoordinator.shared
    coordinator.seedActiveHUDSessionForTesting()
    coordinator.cancel()
    coordinator.seedActiveHUDSessionForTesting()

    XCTAssertTrue(coordinator.isSessionActive)
    coordinator.cancel()
    XCTAssertFalse(coordinator.isSessionActive)

    let deferredRelease = expectation(description: "deferred All-In-One teardown release")
    DispatchQueue.main.async {
      deferredRelease.fulfill()
    }
    wait(for: [deferredRelease], timeout: 1.0)
  }

  func testFloatingHUD_clearContent_dropsHostingView() {
    let window = CaptureFloatingHUDWindow()
    window.setContent(AnyView(Text("All-In-One")))
    XCTAssertNotNil(window.contentView)

    window.clearContent()

    XCTAssertNil(window.contentView)
    window.close()
  }

  func testSessionState_defaultsToAreaMode() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    XCTAssertEqual(state.selectedMode, .area)
    XCTAssertNil(state.currentRect)
    XCTAssertEqual(state.availableModes, AllInOneCaptureMode.availableModes(videoEnabled: false))
  }

  func testSessionState_activateMode_updatesSelectionAndInvokesAction() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    let rect = CGRect(x: 40, y: 50, width: 320, height: 180)
    state.currentRect = rect
    var activated: AllInOneCaptureMode?
    state.onModeActivated = { activated = $0 }

    state.activateMode(.timer)

    XCTAssertEqual(state.selectedMode, .timer)
    XCTAssertEqual(activated, .timer)
    XCTAssertEqual(state.currentRect, rect)
  }

  func testSessionState_activateSelectedMode_invokesSelectedModeAction() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var activated: AllInOneCaptureMode?
    state.selectedMode = .ocr
    state.onModeActivated = { activated = $0 }

    state.activateSelectedMode()

    XCTAssertEqual(activated, .ocr)
  }

  func testSessionState_activateUnavailableMode_isIgnored() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var activated = false
    state.onModeActivated = { _ in activated = true }

    state.activateMode(.recording)

    XCTAssertEqual(state.selectedMode, .area)
    XCTAssertFalse(activated)
  }

  func testSelectedModeActivationKey_matchesReturnAndKeypadEnterOnly() {
    XCTAssertTrue(AllInOneCaptureCoordinator.isSelectedModeActivationKey(UInt16(kVK_Return)))
    XCTAssertTrue(AllInOneCaptureCoordinator.isSelectedModeActivationKey(UInt16(kVK_ANSI_KeypadEnter)))
    XCTAssertFalse(AllInOneCaptureCoordinator.isSelectedModeActivationKey(UInt16(kVK_ANSI_A)))
  }

  func testFloatingHUD_canBeRaisedAboveCaptureOverlay() {
    let window = CaptureFloatingHUDWindow()
    window.setContent(AnyView(Text("All-In-One")))
    window.showAboveCaptureOverlay()

    XCTAssertEqual(window.displayLevel, .aboveCaptureOverlay)
    XCTAssertEqual(window.level, .screenSaver)
    window.close()
  }

  func testFloatingHUD_acceptsFirstMouseWhileRemainingNonKey() {
    let window = CaptureFloatingHUDWindow()
    window.setContent(AnyView(Text("All-In-One")))
    XCTAssertTrue(window.contentView?.acceptsFirstMouse(for: nil) == true)
    XCTAssertFalse(window.canBecomeKey)
    window.close()
  }

  func testCoordinatorHUDLevelState_restoresStandardOnTeardown() {
    let modeHUD = CaptureFloatingHUDWindow()
    let actionHUD = CaptureFloatingHUDWindow()
    modeHUD.setDisplayLevel(.aboveCaptureOverlay)
    actionHUD.setDisplayLevel(.aboveCaptureOverlay)

    modeHUD.restoreStandardDisplayLevel()
    actionHUD.restoreStandardDisplayLevel()

    XCTAssertEqual(modeHUD.displayLevel, .standard)
    XCTAssertEqual(actionHUD.displayLevel, .standard)
    modeHUD.close()
    actionHUD.close()
  }

  func testFrozenBackdropWindowLevel_isBelowSelectionOverlay() {
    XCTAssertLessThan(AllInOneFrozenBackdropHost.windowLevel, NSWindow.Level.floating)
  }

  func testRefinementOverlay_keyOwnershipControlsCanBecomeKey() {
    guard let screen = NSScreen.main else {
      XCTFail("Expected a main screen")
      return
    }
    let overlay = RecordingRegionOverlayWindow(screen: screen, highlightRect: screen.frame.insetBy(dx: 80, dy: 80))
    defer { overlay.close() }

    XCTAssertFalse(overlay.canBecomeKey)
    overlay.setReceivesKeyboardInput(true)
    XCTAssertTrue(overlay.canBecomeKey)
    overlay.setReceivesKeyboardInput(false)
    XCTAssertFalse(overlay.canBecomeKey)
  }

  func testSessionState_updateRectPublishesSelection() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    let rect = CGRect(x: 40, y: 50, width: 320, height: 180)
    var publishedRect: CGRect?
    state.onRectChanged = { publishedRect = $0 }

    state.updateRect(rect)

    XCTAssertEqual(state.currentRect, rect)
    XCTAssertEqual(publishedRect, rect)
  }

  func testSessionState_cancelInvokesCallback() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var cancelled = false
    state.onCancel = { cancelled = true }

    state.cancel()

    XCTAssertTrue(cancelled)
  }

  func testCaptureCommand_preservesSelectionOnlyForRectBackedModes() {
    let rect = CGRect(x: 20, y: 30, width: 400, height: 240)

    XCTAssertEqual(AllInOneCaptureCommand.make(for: .area, rect: rect), .area(rect))
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .window, rect: rect), .window)
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .fullscreen, rect: rect), .fullscreen)
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .timer, rect: nil), .timer(nil))
  }

  func testCaptureCommand_keepsNilRectForFirstSelectionModes() {
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .area, rect: nil), .area(nil))
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .annotate, rect: nil), .annotate(nil))
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .scrolling, rect: nil), .scrolling(nil))
    XCTAssertEqual(AllInOneCaptureCommand.make(for: .ocr, rect: nil), .ocr(nil))
  }

  func testRefinementController_usesFrozenBackdropsWithoutLiveCaptureTask() {
    guard let image = TestImageFactory.solidColor(width: 40, height: 40, red: 1, green: 2, blue: 3) else {
      XCTFail("Failed to create test image")
      return
    }
    let backdrop = AreaSelectionBackdrop(displayID: 1, image: image, scaleFactor: 2)
    let controller = AllInOneSelectionRefinementController(
      initialRect: CGRect(x: 10, y: 10, width: 120, height: 80),
      frozenBackdrops: [1: backdrop]
    )

    controller.present()

    XCTAssertEqual(controller.backdropCacheCountForTesting, 1)
    controller.tearDown()
  }
}

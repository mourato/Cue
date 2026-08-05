//
//  AppLaunchPolicyTests.swift
//  NotinhasTests
//
//  Unit tests for deciding whether the host app should start interactive UI.
//

import AppKit
@testable import Notinhas
import XCTest

@MainActor
final class AppLaunchPolicyTests: XCTestCase {
    func testShouldStartInteractiveApplication_underXCTestSkipsBeforeScreenAccess() {
        var didRequestScreenCount = false
        let policy = AppLaunchPolicy(
            environment: ["XCTestConfigurationFilePath": "/tmp/NotinhasTests.xctestconfiguration"],
            screenCountProvider: {
                didRequestScreenCount = true
                return 1
            },
            xctestRuntimePresent: { false },
        )

        XCTAssertFalse(policy.shouldStartInteractiveApplication)
        XCTAssertFalse(didRequestScreenCount)
    }

    func testShouldStartInteractiveApplication_headlessDisplaySessionReturnsFalse() {
        let policy = AppLaunchPolicy(
            environment: [:],
            screenCountProvider: { 0 },
            xctestRuntimePresent: { false },
        )

        XCTAssertTrue(policy.isHeadlessDisplaySession)
        XCTAssertFalse(policy.shouldStartInteractiveApplication)
    }

    func testShouldStartInteractiveApplication_interactiveDisplaySessionReturnsTrue() {
        let policy = AppLaunchPolicy(
            environment: [:],
            screenCountProvider: { 1 },
            xctestRuntimePresent: { false },
        )

        XCTAssertFalse(policy.isRunningUnderXCTest)
        XCTAssertFalse(policy.isHeadlessDisplaySession)
        XCTAssertTrue(policy.shouldStartInteractiveApplication)
    }

    func testShouldStartInteractiveApplication_canOptInInteractiveXCTestHost() {
        let policy = AppLaunchPolicy(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/NotinhasTests.xctestconfiguration",
                "NOTINHAS_ALLOW_INTERACTIVE_XCTEST_HOST": "1",
            ],
            screenCountProvider: { 1 },
            xctestRuntimePresent: { false },
        )

        XCTAssertTrue(policy.shouldStartInteractiveApplication)
    }

    func testIsRunningUnderXCTest_detectsInjectBundleWithoutConfigurationPath() {
        let policy = AppLaunchPolicy(
            environment: ["XCInjectBundle": "/tmp/NotinhasTests.xctest"],
            screenCountProvider: { 1 },
            xctestRuntimePresent: { false },
        )

        XCTAssertTrue(policy.isRunningUnderXCTest)
        XCTAssertFalse(policy.shouldStartInteractiveApplication)
    }

    func testIsRunningUnderXCTest_detectsDYLDInsertLibrariesWithoutConfigurationPath() {
        let policy = AppLaunchPolicy(
            environment: [
                "DYLD_INSERT_LIBRARIES": "/usr/lib/libXCTestBundleInject.dylib:/tmp/XCTTargetBootstrapInject.dylib",
            ],
            screenCountProvider: { 1 },
            xctestRuntimePresent: { false },
        )

        XCTAssertTrue(policy.isRunningUnderXCTest)
        XCTAssertFalse(policy.shouldStartInteractiveApplication)
    }

    func testIsRunningUnderXCTest_detectsLinkedXCTestCaseWithoutEnvironmentHints() {
        let policy = AppLaunchPolicy(
            environment: [:],
            screenCountProvider: { 1 },
            xctestRuntimePresent: { true },
        )

        XCTAssertTrue(policy.isRunningUnderXCTest)
        XCTAssertFalse(policy.shouldStartInteractiveApplication)
    }

    func testAppDelegate_skippedLaunchKeepsOpenFilesQueued() {
        let delegate = AppDelegate(
            launchPolicyProvider: {
                AppLaunchPolicy(
                    environment: [:],
                    screenCountProvider: { 0 },
                    xctestRuntimePresent: { false },
                )
            },
        )
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification),
        )
        delegate.application(NSApplication.shared, open: [fileURL])

        XCTAssertFalse(delegate.didFinishLaunchingForTesting)
        XCTAssertFalse(delegate.hasCoordinatorForTesting)
        XCTAssertEqual(delegate.pendingOpenFileURLCountForTesting, 1)
    }
}

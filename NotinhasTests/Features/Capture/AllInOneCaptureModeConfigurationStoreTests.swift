//
//  AllInOneCaptureModeConfigurationStoreTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

@MainActor
final class AllInOneCaptureModeConfigurationStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaultsFactory.make()
    }

    func testDefaults_includeEveryModeInDefaultOrder() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        XCTAssertEqual(store.modeOrder, AllInOneCaptureMode.defaultOrder)
        XCTAssertEqual(store.enabledModes, AllInOneCaptureMode.defaultEnabledModes)
    }

    func testStoredIDs_normalizeUnknownDuplicatesAndMissingModes() {
        defaults.set(["ocr", "ocr", "unknown", "area"], forKey: PreferencesKeys.captureAllInOneModeOrder)
        defaults.set(["unknown"], forKey: PreferencesKeys.captureAllInOneEnabledModes)
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)

        XCTAssertEqual(store.modeOrder, [.ocr, .area, .fullscreen, .window, .annotate, .scrolling, .timer, .recording])
        XCTAssertEqual(store.enabledModes, [.area])
    }

    func testCustomOrderAndVisibility_persistAcrossStores() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        store.moveMode(from: IndexSet(integer: 7), to: 0, videoEnabled: true)
        store.setEnabled(.timer, enabled: false)
        let reloaded = AllInOneCaptureModeConfigurationStore(defaults: defaults)

        XCTAssertEqual(reloaded.modeOrder.first, .recording)
        XCTAssertFalse(reloaded.isEnabled(.timer))
    }

    func testDisablingAndReenabling_preservesOrder() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        store.moveMode(from: IndexSet(integer: 2), to: 0, videoEnabled: true)
        let order = store.modeOrder
        store.setEnabled(.window, enabled: false)
        store.setEnabled(.window, enabled: true)
        XCTAssertEqual(store.modeOrder, order)
    }

    func testLastNonVideoMode_cannotBeDisabled() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        for mode in AllInOneCaptureMode.defaultOrder where mode != .area {
            store.setEnabled(mode, enabled: false)
        }
        XCTAssertFalse(store.canToggle(.area))
        store.setEnabled(.area, enabled: false)
        XCTAssertTrue(store.isEnabled(.area))
    }

    func testVideoFiltering_preservesRecordingPositionAndState() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        store.moveMode(from: IndexSet(integer: 7), to: 2, videoEnabled: true)
        store.setEnabled(.recording, enabled: false)
        XCTAssertFalse(store.orderedModes(videoEnabled: false, includeDisabled: true).contains(.recording))
        XCTAssertEqual(store.modeOrder[2], .recording)
        store.setEnabled(.recording, enabled: true)
        XCTAssertEqual(store.orderedModes(videoEnabled: true, includeDisabled: true)[2], .recording)
    }

    func testMoveWhileVideoOff_preservesHiddenRecordingSlot() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        store.moveMode(from: IndexSet(integer: 7), to: 2, videoEnabled: true)
        store.moveMode(from: IndexSet(integer: 3), to: 0, videoEnabled: false)
        XCTAssertEqual(store.modeOrder[2], .recording)
        XCTAssertEqual(store.orderedModes(videoEnabled: false, includeDisabled: true).first, .annotate)
    }

    func testReset_restoresOrderAndEnablesAllModes() {
        let store = AllInOneCaptureModeConfigurationStore(defaults: defaults)
        store.setEnabled(.area, enabled: false)
        store.resetToDefaults()
        XCTAssertEqual(store.modeOrder, AllInOneCaptureMode.defaultOrder)
        XCTAssertEqual(store.enabledModes, AllInOneCaptureMode.defaultEnabledModes)
    }
}

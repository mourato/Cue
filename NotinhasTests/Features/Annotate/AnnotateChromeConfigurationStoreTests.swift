//
//  AnnotateChromeConfigurationStoreTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

@MainActor
final class AnnotateChromeConfigurationStoreTests: XCTestCase {
  private static var retainedStores: [AnnotateChromeConfigurationStore] = []

  override func tearDown() {
    Self.retainedStores.removeAll()
    super.tearDown()
  }

  func testAnnotateChromeConfigurationStore_usesDefaultOrderAndEnabledItems() {
    let defaults = makeIsolatedDefaults()
    let store = makeStore(defaults: defaults)

    XCTAssertEqual(store.toolbarItemOrder, AnnotateChromeItem.defaultToolbarOrder)
    XCTAssertEqual(store.bottomActionOrder, AnnotateChromeItem.defaultBottomOrder)
    XCTAssertTrue(store.isEnabled(.watermark))
    XCTAssertTrue(store.isEnabled(.selection))
    XCTAssertTrue(store.isEnabled(.undo))
  }

  func testAnnotateChromeConfigurationStore_filtersUnknownIdsAndAppendsMissingItems() {
    let defaults = makeIsolatedDefaults()
    defaults.set(
      [
        AnnotateChromeItem.watermark.rawValue,
        "future-item",
        AnnotateChromeItem.rectangle.rawValue,
      ],
      forKey: PreferencesKeys.annotateChromeToolbarOrder
    )

    let store = makeStore(defaults: defaults)

    XCTAssertEqual(store.toolbarItemOrder.first, .watermark)
    XCTAssertTrue(store.toolbarItemOrder.contains(.rectangle))
    XCTAssertTrue(store.toolbarItemOrder.contains(.saveAs))
    XCTAssertEqual(store.toolbarItemOrder.count, AnnotateChromeItem.defaultToolbarOrder.count)
  }

  func testAnnotateChromeConfigurationStore_togglesMovesAndPersistsChrome() {
    let defaults = makeIsolatedDefaults()
    let store = makeStore(defaults: defaults)

    store.setEnabled(.watermark, enabled: false)
    store.moveToolbarItem(from: IndexSet(integer: 4), to: 1)

    XCTAssertFalse(store.isEnabled(.watermark))
    XCTAssertEqual(store.toolbarItemOrder[1], .rectangle)

    let reloaded = makeStore(defaults: defaults)
    XCTAssertFalse(reloaded.isEnabled(.watermark))
    XCTAssertEqual(reloaded.toolbarItemOrder, store.toolbarItemOrder)

    reloaded.moveBottomAction(from: IndexSet(integer: 0), to: 2)
    XCTAssertEqual(reloaded.bottomActionOrder[1], .newWindow)

    reloaded.resetToDefaults()
    XCTAssertEqual(reloaded.toolbarItemOrder, AnnotateChromeItem.defaultToolbarOrder)
    XCTAssertEqual(reloaded.bottomActionOrder, AnnotateChromeItem.defaultBottomOrder)
    XCTAssertTrue(reloaded.isEnabled(.watermark))
  }

  func testAnnotateChromeConfigurationStore_alwaysOnItemsStayEnabled() {
    let defaults = makeIsolatedDefaults()
    defaults.set([], forKey: PreferencesKeys.annotateChromeEnabledItems)
    let store = makeStore(defaults: defaults)

    XCTAssertTrue(store.isEnabled(.selection))
    XCTAssertTrue(store.isEnabled(.undo))
    XCTAssertTrue(store.isEnabled(.redo))
    XCTAssertTrue(store.isEnabled(.done))

    store.setEnabled(.selection, enabled: false)
    XCTAssertTrue(store.isEnabled(.selection))
  }

  func testPreferencesAnnotateChromeLocalizationKeysResolveWithoutTrapping() {
    // Regression: preferences-annotate.* had no L10n table mapping and crashed
    // opening Preferences → Annotate (EXC_BREAKPOINT in L10n.tableName(for:)).
    let strings = [
      L10n.PreferencesAnnotate.chromeSection,
      L10n.PreferencesAnnotate.chromeToolbarSection,
      L10n.PreferencesAnnotate.chromeBottomSection,
      L10n.PreferencesAnnotate.chromeDescription,
      L10n.PreferencesAnnotate.chromeAlwaysOnFootnote,
      L10n.PreferencesAnnotate.resetChrome,
    ]

    for value in strings {
      XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  func testAnnotateChromeConfigurationStore_effectiveDrawableToolsRespectsOrderAndEnablement() {
    let defaults = makeIsolatedDefaults()
    let store = makeStore(defaults: defaults)

    store.setEnabled(.watermark, enabled: false)
    store.moveToolbarItem(from: IndexSet(integer: 13), to: 4)

    XCTAssertEqual(store.effectiveDrawableTools().first, .notinhasNote)
    XCTAssertFalse(store.effectiveDrawableTools().contains(.watermark))
  }

  private func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "AnnotateChromeConfigurationStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  private func makeStore(defaults: UserDefaults) -> AnnotateChromeConfigurationStore {
    let store = AnnotateChromeConfigurationStore(defaults: defaults)
    Self.retainedStores.append(store)
    return store
  }
}

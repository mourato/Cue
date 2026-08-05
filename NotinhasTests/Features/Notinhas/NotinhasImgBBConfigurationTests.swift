@testable import Notinhas
import XCTest

@MainActor
final class NotinhasImgBBConfigurationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var keychain: MockImgBBKeychainBacking!
    private var store: NotinhasImgBBCredentialStore!

    override func setUp() {
        super.setUp()
        suiteName = "notinhas.imgbb.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        keychain = MockImgBBKeychainBacking()
        store = NotinhasImgBBCredentialStore(defaults: defaults, keychain: keychain)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        keychain = nil
        store = nil
        super.tearDown()
    }

    func testReadPrefersKeychainValue() {
        keychain.storedValue = "keychain-secret"
        // `isConfigured` is a cached snapshot resolved when the store observes the
        // credential (init/save/clear/reload), so seed the Keychain before init to
        // mirror a credential that already exists at launch.
        store = NotinhasImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertEqual(store.apiKey, "keychain-secret")
        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(store.maskedAPIKey, "keyc••••cret")
    }

    func testLegacyUserDefaultsMigratesToKeychain() {
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)

        XCTAssertEqual(store.apiKey, "legacy-secret")
        XCTAssertEqual(keychain.storedValue, "legacy-secret")
        XCTAssertNil(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey))
    }

    func testFailedMigrationPreservesLegacyUserDefaultsValue() {
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)
        keychain.shouldFailUpsert = true

        XCTAssertEqual(store.apiKey, "legacy-secret")
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey), "legacy-secret")
        XCTAssertNil(keychain.storedValue)
    }

    func testWhitespaceValuesAreIgnored() {
        keychain.storedValue = "   "
        defaults.set("  ", forKey: PreferencesKeys.notinhasImgBBAPIKey)

        XCTAssertNil(store.apiKey)
        XCTAssertFalse(store.isConfigured)
        XCTAssertEqual(store.maskedAPIKey, "")
    }

    func testSaveWritesToKeychainAndClearsLegacyValue() throws {
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)

        try store.save(apiKey: "new-secret")

        XCTAssertEqual(keychain.storedValue, "new-secret")
        XCTAssertNil(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey))
        XCTAssertEqual(store.apiKey, "new-secret")
    }

    func testSaveRejectsEmptyKey() {
        XCTAssertThrowsError(try store.save(apiKey: "   ")) { error in
            guard case NotinhasImgBBCredentialError.emptyKey = error else {
                return XCTFail("Expected empty key error, got \(error)")
            }
        }
    }

    func testClearRemovesKeychainAndLegacyValue() {
        keychain.storedValue = "stored-secret"
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)

        store.clear()

        XCTAssertNil(keychain.storedValue)
        XCTAssertNil(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey))
        XCTAssertFalse(store.isConfigured)
    }

    func testMaskedValueFallsBackToSecureSummaryForShortKeys() {
        keychain.storedValue = "short"

        XCTAssertEqual(store.maskedAPIKey, L10n.CloudSettings.storedSecurelyInKeychain)
    }
}

private final class MockImgBBKeychainBacking: ImgBBKeychainBacking {
    var storedValue: String?
    var shouldFailUpsert = false

    func read(context _: String) -> CloudKeychainReadOutcome {
        guard let storedValue else { return .itemNotFound }
        return .success(storedValue)
    }

    func upsert(value: String) throws {
        if shouldFailUpsert {
            throw CloudError.keychainError("mock keychain write failure")
        }
        storedValue = value
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        storedValue = nil
        return []
    }
}

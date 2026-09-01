@testable import Cue
import XCTest

@MainActor
final class CueImgBBConfigurationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var keychain: MockImgBBKeychainBacking!
    private var store: CueImgBBCredentialStore!

    override func setUp() {
        super.setUp()
        suiteName = "notinhas.imgbb.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        keychain = MockImgBBKeychainBacking()
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        keychain = nil
        store = nil
        super.tearDown()
    }

    func testInitUsesPresenceProbeWithoutUnlockingRead() {
        defaults.removeObject(forKey: PreferencesKeys.imgbbCredentialConfigured)
        keychain = MockImgBBKeychainBacking(storedValue: "keychain-secret")
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(keychain.probeCount, 1)
        XCTAssertEqual(keychain.readCount, 0)
        XCTAssertEqual(
            defaults.bool(forKey: PreferencesKeys.imgbbCredentialConfigured),
            true,
        )
    }

    func testInitUsesCachedPresenceFlagWithoutProbing() {
        defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)
        keychain = MockImgBBKeychainBacking(storedValue: "keychain-secret")
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(keychain.probeCount, 0)
        XCTAssertEqual(keychain.readCount, 0)
    }

    func testReadPrefersKeychainValue() {
        keychain = MockImgBBKeychainBacking(storedValue: "keychain-secret")
        defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertEqual(store.apiKey, "keychain-secret")
        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(store.maskedAPIKey, "keyc••••cret")
        XCTAssertEqual(keychain.readCount, 2) // apiKey + maskedAPIKey
    }

    func testLegacyUserDefaultsMigratesToKeychain() {
        defaults.removeObject(forKey: PreferencesKeys.imgbbCredentialConfigured)
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)
        keychain = MockImgBBKeychainBacking()
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(keychain.readCount, 0)
        XCTAssertEqual(keychain.probeCount, 0)
        XCTAssertEqual(store.apiKey, "legacy-secret")
        XCTAssertEqual(keychain.storedValue, "legacy-secret")
        XCTAssertNil(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey))
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.imgbbCredentialConfigured))
    }

    func testFailedMigrationPreservesLegacyUserDefaultsValue() {
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)
        keychain.shouldFailUpsert = true
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertEqual(store.apiKey, "legacy-secret")
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey), "legacy-secret")
        XCTAssertNil(keychain.storedValue)
    }

    func testWhitespaceValuesAreIgnored() {
        keychain.storedValue = "   "
        defaults.set("  ", forKey: PreferencesKeys.notinhasImgBBAPIKey)
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

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
        XCTAssertTrue(store.isConfigured)
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.imgbbCredentialConfigured))
    }

    func testSaveRejectsEmptyKey() {
        XCTAssertThrowsError(try store.save(apiKey: "   ")) { error in
            guard case CueImgBBCredentialError.emptyKey = error else {
                return XCTFail("Expected empty key error, got \(error)")
            }
        }
    }

    func testClearRemovesKeychainAndLegacyValue() {
        keychain.storedValue = "stored-secret"
        defaults.set("legacy-secret", forKey: PreferencesKeys.notinhasImgBBAPIKey)
        defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)

        store.clear()

        XCTAssertNil(keychain.storedValue)
        XCTAssertNil(defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey))
        XCTAssertFalse(store.isConfigured)
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.imgbbCredentialConfigured))
    }

    func testMaskedValueFallsBackToSecureSummaryForShortKeys() {
        keychain.storedValue = "short"
        defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)
        store = CueImgBBCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertEqual(store.maskedAPIKey, L10n.CloudSettings.storedSecurelyInKeychain)
    }
}

private final class MockImgBBKeychainBacking: ImgBBKeychainBacking {
    var storedValue: String?
    var shouldFailUpsert = false
    private(set) var readCount = 0
    private(set) var probeCount = 0

    init(storedValue: String? = nil) {
        self.storedValue = storedValue
    }

    func read(context _: String) -> CloudKeychainReadOutcome {
        readCount += 1
        guard let storedValue else { return .itemNotFound }
        let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .itemNotFound }
        return .success(storedValue)
    }

    func probePresence(context _: String) -> CloudKeychainPresence {
        probeCount += 1
        guard let storedValue else { return .absent }
        let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .absent : .present
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

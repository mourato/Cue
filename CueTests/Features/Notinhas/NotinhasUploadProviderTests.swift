@testable import Cue
import XCTest

@MainActor
final class NotinhasUploadProviderTests: XCTestCase {
    func testImageKitCredentialIsTrimmedMaskedAndClearable() throws {
        let suite = "notinhas.imagekit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let keychain = MockProviderKeychain()
        let store = NotinhasImageKitCredentialStore(defaults: defaults, keychain: keychain)

        try store.save(privateKey: "  fixture-private-key  ")

        XCTAssertEqual(keychain.storedValue, "fixture-private-key")
        XCTAssertEqual(store.privateKey, "fixture-private-key")
        XCTAssertEqual(store.maskedPrivateKey, "fixt••••-key")
        XCTAssertTrue(store.isConfigured)
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.imageKitCredentialConfigured))

        store.clear()
        XCTAssertFalse(store.isConfigured)
        XCTAssertNil(keychain.storedValue)
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.imageKitCredentialConfigured))
        defaults.removePersistentDomain(forName: suite)
    }

    func testImageKitInitProbesWithoutUnlockingRead() throws {
        let suite = "notinhas.imagekit.probe.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let keychain = MockProviderKeychain(storedValue: "fixture-private-key")
        let store = NotinhasImageKitCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(keychain.probeCount, 1)
        XCTAssertEqual(keychain.readCount, 0)
        defaults.removePersistentDomain(forName: suite)
    }

    func testImageKitCredentialRejectsWhitespace() {
        let store = NotinhasImageKitCredentialStore(keychain: MockProviderKeychain())

        XCTAssertThrowsError(try store.save(privateKey: "  ")) { error in
            XCTAssertEqual(error as? NotinhasImageKitCredentialError, .emptyKey)
        }
    }

    func testDefaultsToImgBBAndRecoversInvalidValue() throws {
        let suite = "notinhas.upload-provider.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("retired-provider", forKey: PreferencesKeys.uploadProvider)
        let store = NotinhasUploadConfigurationStore(
            defaults: defaults,
            imgbb: NotinhasImgBBCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
            imageKit: NotinhasImageKitCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
        )

        XCTAssertEqual(store.provider, .imgbb)
        store.select(.imageKit)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.uploadProvider), "imageKit")
        defaults.removePersistentDomain(forName: suite)
    }
}

private final class MockProviderKeychain: ImgBBKeychainBacking, ImageKitKeychainBacking {
    var storedValue: String?
    private(set) var readCount = 0
    private(set) var probeCount = 0

    init(storedValue: String? = nil) {
        self.storedValue = storedValue
    }

    func read(context _: String) -> CloudKeychainReadOutcome {
        readCount += 1
        return storedValue.map(CloudKeychainReadOutcome.success) ?? .itemNotFound
    }

    func probePresence(context _: String) -> CloudKeychainPresence {
        probeCount += 1
        return storedValue == nil ? .absent : .present
    }

    func upsert(value: String) throws {
        storedValue = value
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        storedValue = nil
        return []
    }
}

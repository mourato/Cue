@testable import Notinhas
import XCTest

@MainActor
final class NotinhasUploadProviderTests: XCTestCase {
    func testImageKitCredentialIsTrimmedMaskedAndClearable() throws {
        let keychain = MockProviderKeychain()
        let store = NotinhasImageKitCredentialStore(keychain: keychain)

        try store.save(privateKey: "  fixture-private-key  ")

        XCTAssertEqual(keychain.storedValue, "fixture-private-key")
        XCTAssertEqual(store.privateKey, "fixture-private-key")
        XCTAssertEqual(store.maskedPrivateKey, "fixt••••-key")
        XCTAssertTrue(store.isConfigured)

        store.clear()
        XCTAssertFalse(store.isConfigured)
        XCTAssertNil(keychain.storedValue)
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
            imageKit: NotinhasImageKitCredentialStore(keychain: MockProviderKeychain()),
        )

        XCTAssertEqual(store.provider, .imgbb)
        store.select(.imageKit)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.uploadProvider), "imageKit")
        defaults.removePersistentDomain(forName: suite)
    }
}

private final class MockProviderKeychain: ImgBBKeychainBacking, ImageKitKeychainBacking {
    var storedValue: String?

    func read(context _: String) -> CloudKeychainReadOutcome {
        storedValue.map(CloudKeychainReadOutcome.success) ?? .itemNotFound
    }

    func upsert(value: String) throws {
        storedValue = value
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        storedValue = nil
        return []
    }
}

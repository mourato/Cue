@testable import Cue
import XCTest

@MainActor
final class CueUploadProviderTests: XCTestCase {
    func testImageKitCredentialIsTrimmedMaskedAndClearable() throws {
        let suite = "notinhas.imagekit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let keychain = MockProviderKeychain()
        let store = CueImageKitCredentialStore(defaults: defaults, keychain: keychain)

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
        let store = CueImageKitCredentialStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(keychain.probeCount, 1)
        XCTAssertEqual(keychain.readCount, 0)
        defaults.removePersistentDomain(forName: suite)
    }

    func testImageKitCredentialRejectsWhitespace() {
        let store = CueImageKitCredentialStore(keychain: MockProviderKeychain())

        XCTAssertThrowsError(try store.save(privateKey: "  ")) { error in
            XCTAssertEqual(error as? CueImageKitCredentialError, .emptyKey)
        }
    }

    func testDefaultsToImgBBAndRecoversInvalidValue() throws {
        let suite = "notinhas.upload-provider.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("retired-provider", forKey: PreferencesKeys.uploadProvider)
        let store = CueUploadConfigurationStore(
            defaults: defaults,
            imgbb: CueImgBBCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
            imageKit: CueImageKitCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
        )

        XCTAssertEqual(store.provider, .imgbb)
        store.select(.imageKit)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.uploadProvider), "imageKit")
        defaults.removePersistentDomain(forName: suite)
    }

    func testProviderMediaCapabilitiesKeepVideoOnImageKit() {
        XCTAssertTrue(CueUploadProvider.imgbb.supports(.image))
        XCTAssertTrue(CueUploadProvider.imgbb.supports(.gif))
        XCTAssertFalse(CueUploadProvider.imgbb.supports(.video))
        XCTAssertTrue(CueUploadProvider.imageKit.supports(.image))
        XCTAssertTrue(CueUploadProvider.imageKit.supports(.gif))
        XCTAssertTrue(CueUploadProvider.imageKit.supports(.video))
    }

    func testCloudflareCredentialIsTrimmedStoredAndRestored() throws {
        let suite = "notinhas.cloudflare.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let keychain = MockProviderKeychain()
        let store = CueCloudflareCredentialStore(defaults: defaults, keychain: keychain)

        try store.save(token: "  fixture-token  ")

        XCTAssertEqual(store.token, "fixture-token")
        XCTAssertEqual(keychain.storedValue, "fixture-token")
        XCTAssertTrue(store.isConfigured)
        XCTAssertEqual(store.maskedToken, String(repeating: "•", count: 9) + "oken")

        let relaunched = CueCloudflareCredentialStore(defaults: defaults, keychain: keychain)
        XCTAssertTrue(relaunched.isConfigured)
        XCTAssertEqual(relaunched.token, "fixture-token")

        store.clear()
        XCTAssertFalse(store.isConfigured)
        XCTAssertNil(keychain.storedValue)
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.cloudflareCredentialConfigured))
        defaults.removePersistentDomain(forName: suite)
    }

    func testCloudflareGeneratedTokenIs32RandomBytes() {
        let token = CueCloudflareCredentialStore.generatedToken()

        XCTAssertEqual(token.count, 64)
        XCTAssertTrue(token.allSatisfy(\.isHexDigit))
    }

    func testCloudflareVerificationIgnoresResultAfterWorkerURLChanges() async throws {
        let suite = "notinhas.cloudflare.verify.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let keychain = MockProviderKeychain()
        let credentials = CueCloudflareCredentialStore(defaults: defaults, keychain: keychain)
        try credentials.save(token: "fixture-token")
        defaults.set("https://old.worker.example", forKey: PreferencesKeys.cloudflareWorkerURL)

        let started = expectation(description: "Cloudflare verification started")
        let release = DispatchSemaphore(value: 0)
        ProviderCloudflareURLProtocol.requestHandler = { request in
            if request.url?.absoluteString == "https://old.worker.example/api/setup" {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil,
                    )!,
                    Data("{}".utf8),
                )
            }
            XCTAssertEqual(request.url?.absoluteString, "https://old.worker.example/api/ping")
            started.fulfill()
            release.wait()
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil,
                )!,
                Data(#"{"ok":true}"#.utf8),
            )
        }
        defer {
            release.signal()
            ProviderCloudflareURLProtocol.requestHandler = nil
            defaults.removePersistentDomain(forName: suite)
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [ProviderCloudflareURLProtocol.self]
        let store = CueUploadConfigurationStore(
            defaults: defaults,
            imgbb: CueImgBBCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
            imageKit: CueImageKitCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
            cloudflare: credentials,
            cloudflareService: CueCloudflareUploadService(
                session: URLSession(configuration: sessionConfiguration),
            ),
        )

        let verification = Task { await store.verifyCloudflareConnection() }
        await fulfillment(of: [started], timeout: 1)
        store.setCloudflareWorkerURL("https://new.worker.example")
        release.signal()
        await verification.value

        XCTAssertEqual(store.cloudflareConnectionState, .unconfigured)
        XCTAssertNotEqual(store.cloudflareConnectionState, .connected)
    }

    func testCloudflareSupportsImagesGIFsVideosAndUses95MiBLimit() {
        XCTAssertTrue(CueUploadProvider.cloudflare.supports(.image))
        XCTAssertTrue(CueUploadProvider.cloudflare.supports(.gif))
        XCTAssertTrue(CueUploadProvider.cloudflare.supports(.video))
        XCTAssertEqual(CueCloudflareConfiguration.maximumUploadBytes, 95 * 1_048_576)
    }

    func testImageKitPlanControlsSafeVideoUploadTarget() throws {
        let suite = "notinhas.upload-plan.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = CueUploadConfigurationStore(
            defaults: defaults,
            imgbb: CueImgBBCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
            imageKit: CueImageKitCredentialStore(defaults: defaults, keychain: MockProviderKeychain()),
        )

        XCTAssertEqual(store.imageKitPlan, .free)
        XCTAssertEqual(store.imageKitVideoUploadLimitBytes, 100 * 1_048_576)
        XCTAssertEqual(store.imageKitVideoUploadTargetBytes, 95 * 1_048_576)

        store.selectImageKitPlan(.custom)
        store.setImageKitCustomVideoLimitMB(42)

        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.uploadImageKitPlan), "custom")
        XCTAssertEqual(defaults.integer(forKey: PreferencesKeys.uploadImageKitCustomVideoLimitMB), 42)
        XCTAssertEqual(store.imageKitVideoUploadLimitBytes, 42 * 1_048_576)
        defaults.removePersistentDomain(forName: suite)
    }

    func testVideoUploadSettingsReduceQualityAcrossRetries() {
        let settings = CueVideoUploadSettings(
            maximumDimension: 1_920,
            quality: .high,
            frameRate: 60,
            includesAudio: true,
        )

        XCTAssertEqual(
            settings.reducedForRetry(1),
            CueVideoUploadSettings(maximumDimension: 1_280, quality: .compact, frameRate: 30, includesAudio: true),
        )
        XCTAssertEqual(
            settings.reducedForRetry(2),
            CueVideoUploadSettings(maximumDimension: 960, quality: .compact, frameRate: 24, includesAudio: true),
        )
        XCTAssertEqual(
            settings.reducedForRetry(3),
            CueVideoUploadSettings(maximumDimension: 960, quality: .compact, frameRate: 24, includesAudio: false),
        )
        XCTAssertNil(settings.reducedForRetry(4))
    }
}

private final class MockProviderKeychain: ImgBBKeychainBacking, ImageKitKeychainBacking, CloudflareKeychainBacking {
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

private final class ProviderCloudflareURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let state = ProviderCloudflareHandlerState()

    static var requestHandler: Handler? {
        get { state.handler }
        set { state.handler = newValue }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// URLProtocol callbacks and test setup can run concurrently; the lock protects
/// the handler while the callback invokes a snapshot after unlocking.
private final class ProviderCloudflareHandlerState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedHandler: ProviderCloudflareURLProtocol.Handler?

    var handler: ProviderCloudflareURLProtocol.Handler? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedHandler
        }
        set {
            lock.lock()
            storedHandler = newValue
            lock.unlock()
        }
    }
}

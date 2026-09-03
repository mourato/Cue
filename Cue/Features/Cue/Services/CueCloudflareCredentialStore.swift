import Combine
import Foundation
import Security

protocol CloudflareKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome
    func probePresence(context: String) -> CloudKeychainPresence
    func upsert(value: String) throws
    func delete() -> [CloudKeychainDeleteIssue]
}

struct CloudKeychainCloudflareBacking: CloudflareKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome {
        CloudKeychainStore.read(item: .cloudflareUploadToken, context: context)
    }

    func probePresence(context: String) -> CloudKeychainPresence {
        CloudKeychainStore.probePresence(item: .cloudflareUploadToken, context: context)
    }

    func upsert(value: String) throws {
        try CloudKeychainStore.upsert(item: .cloudflareUploadToken, value: value)
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        CloudKeychainStore.delete(item: .cloudflareUploadToken)
    }
}

@MainActor
final class CueCloudflareCredentialStore: ObservableObject {
    static let shared = CueCloudflareCredentialStore()
    @Published private(set) var isConfigured = false
    @Published private(set) var revision = UUID()
    private let defaults: UserDefaults
    private let keychain: CloudflareKeychainBacking

    init(
        defaults: UserDefaults = .standard,
        keychain: CloudflareKeychainBacking = CloudKeychainCloudflareBacking(),
    ) {
        self.defaults = defaults
        self.keychain = keychain
        reload()
    }

    var token: String? {
        guard case let .success(value) = keychain.read(context: "cloudflare-token-read") else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var maskedToken: String {
        token.map { String(repeating: "•", count: max(4, $0.count - 4)) + $0.suffix(4) } ?? ""
    }

    func reload() {
        if let cached = defaults.object(forKey: PreferencesKeys.cloudflareCredentialConfigured) as? Bool {
            isConfigured = cached
        } else {
            let present = keychain.probePresence(context: "cloudflare-token-presence") == .present
            defaults.set(present, forKey: PreferencesKeys.cloudflareCredentialConfigured)
            isConfigured = present
        }
        revision = UUID()
    }

    func save(token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw CueCloudflareUploadError.missingToken }
        try keychain.upsert(value: value)
        defaults.set(true, forKey: PreferencesKeys.cloudflareCredentialConfigured)
        isConfigured = true
        revision = UUID()
    }

    static func generatedToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func clear() {
        _ = keychain.delete()
        defaults.set(false, forKey: PreferencesKeys.cloudflareCredentialConfigured)
        isConfigured = false
        revision = UUID()
    }
}

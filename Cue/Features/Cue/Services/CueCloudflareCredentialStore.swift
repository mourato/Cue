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
        CloudKeychainStore.readCloudflareToken(context: context)
    }

    func probePresence(context: String) -> CloudKeychainPresence {
        CloudKeychainStore.probeCloudflareToken(context: context)
    }

    func upsert(value: String) throws {
        try CloudKeychainStore.upsertCloudflareToken(value)
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        CloudKeychainStore.deleteCloudflareToken()
        return []
    }
}

@MainActor
final class CueCloudflareCredentialStore: ObservableObject {
    static let shared = CueCloudflareCredentialStore()
    @Published private(set) var isConfigured = false
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
        let key = CueCloudflareConfiguration.workerURLKey + ".configured"
        if let cached = defaults.object(forKey: key) as? Bool {
            isConfigured = cached
        } else {
            let present = keychain.probePresence(context: "cloudflare-token-presence") == .present
            defaults.set(present, forKey: key)
            isConfigured = present
        }
    }

    func save(token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw CueCloudflareUploadError.missingToken }
        try keychain.upsert(value: value)
        defaults.set(true, forKey: CueCloudflareConfiguration.workerURLKey + ".configured")
        isConfigured = true
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
        defaults.set(false, forKey: CueCloudflareConfiguration.workerURLKey + ".configured")
        isConfigured = false
    }
}

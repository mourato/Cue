import Combine
import Foundation

enum NotinhasImageKitCredentialError: LocalizedError, Equatable {
    case emptyKey
    case keychainWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyKey: L10n.CloudSettings.imageKitPrivateKeyEmpty
        case .keychainWriteFailed(let message): L10n.CloudOperation.keychainError(message)
        }
    }
}

protocol ImageKitKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome
    func probePresence(context: String) -> CloudKeychainPresence
    func upsert(value: String) throws
    func delete() -> [CloudKeychainDeleteIssue]
}

struct CloudKeychainImageKitBacking: ImageKitKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome {
        CloudKeychainStore.read(item: .imageKitPrivateKey, context: context)
    }

    func probePresence(context: String) -> CloudKeychainPresence {
        CloudKeychainStore.probePresence(item: .imageKitPrivateKey, context: context)
    }

    func upsert(value: String) throws {
        _ = try CloudKeychainStore.upsert(item: .imageKitPrivateKey, value: value)
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        CloudKeychainStore.delete(item: .imageKitPrivateKey)
    }
}

@MainActor
final class NotinhasImageKitCredentialStore: ObservableObject {
    static let shared = NotinhasImageKitCredentialStore()

    @Published private(set) var revision = UUID()
    /// Cached without unlocking Keychain. See `NotinhasImgBBCredentialStore.isConfigured`.
    @Published private(set) var isConfigured = false

    private let defaults: UserDefaults
    private let keychain: ImageKitKeychainBacking

    init(
        defaults: UserDefaults = .standard,
        keychain: ImageKitKeychainBacking = CloudKeychainImageKitBacking(),
    ) {
        self.defaults = defaults
        self.keychain = keychain
        refreshConfiguredState()
    }

    /// Unlocks Keychain when needed. Call only from explicit upload / Preferences paths.
    var privateKey: String? {
        switch keychain.read(context: "imageKitCredential.read") {
        case .success(let value): normalized(value)
        case .itemNotFound, .authRequired, .interactionNotAllowed, .error: nil
        }
    }

    var maskedPrivateKey: String {
        guard let privateKey else { return "" }
        guard privateKey.count > 8 else { return L10n.CloudSettings.storedSecurelyInKeychain }
        return "\(privateKey.prefix(4))••••\(privateKey.suffix(4))"
    }

    func save(privateKey: String) throws {
        let trimmed = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NotinhasImageKitCredentialError.emptyKey }
        do {
            try keychain.upsert(value: trimmed)
            defaults.set(true, forKey: PreferencesKeys.imageKitCredentialConfigured)
            publishChange()
        } catch {
            throw NotinhasImageKitCredentialError.keychainWriteFailed(error.localizedDescription)
        }
    }

    func clear() {
        _ = keychain.delete()
        defaults.set(false, forKey: PreferencesKeys.imageKitCredentialConfigured)
        publishChange()
    }

    func reload() {
        defaults.removeObject(forKey: PreferencesKeys.imageKitCredentialConfigured)
        publishChange()
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func publishChange() {
        revision = UUID()
        refreshConfiguredState()
    }

    private func refreshConfiguredState() {
        isConfigured = resolveConfiguredPresence()
    }

    private func resolveConfiguredPresence() -> Bool {
        if let cached = defaults.object(forKey: PreferencesKeys.imageKitCredentialConfigured) as? Bool {
            return cached
        }

        let present = keychain.probePresence(context: "imageKitCredential.probe") == .present
        defaults.set(present, forKey: PreferencesKeys.imageKitCredentialConfigured)
        return present
    }
}

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
    func upsert(value: String) throws
    func delete() -> [CloudKeychainDeleteIssue]
}

struct CloudKeychainImageKitBacking: ImageKitKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome {
        CloudKeychainStore.read(item: .imageKitPrivateKey, context: context)
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
    @Published private(set) var isConfigured = false

    private let keychain: ImageKitKeychainBacking

    init(keychain: ImageKitKeychainBacking = CloudKeychainImageKitBacking()) {
        self.keychain = keychain
        refreshConfiguredState()
    }

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
            publishChange()
        } catch {
            throw NotinhasImageKitCredentialError.keychainWriteFailed(error.localizedDescription)
        }
    }

    func clear() {
        _ = keychain.delete()
        publishChange()
    }

    func reload() {
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
        isConfigured = privateKey != nil
    }
}

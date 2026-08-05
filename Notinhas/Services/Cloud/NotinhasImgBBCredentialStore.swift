//
//  NotinhasImgBBCredentialStore.swift
//  Notinhas
//
//  Secure ImgBB API key storage with legacy UserDefaults migration.
//

import Combine
import Foundation

enum NotinhasImgBBCredentialError: LocalizedError {
    case emptyKey
    case keychainWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            L10n.CloudSettings.imgbbAPIKeyEmpty
        case .keychainWriteFailed(let message):
            L10n.CloudOperation.keychainError(message)
        }
    }
}

protocol ImgBBKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome
    func upsert(value: String) throws
    func delete() -> [CloudKeychainDeleteIssue]
}

struct CloudKeychainImgBBBacking: ImgBBKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome {
        CloudKeychainStore.read(item: .imgbbAPIKey, context: context)
    }

    func upsert(value: String) throws {
        _ = try CloudKeychainStore.upsert(item: .imgbbAPIKey, value: value)
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        CloudKeychainStore.delete(item: .imgbbAPIKey)
    }
}

@MainActor
final class NotinhasImgBBCredentialStore: ObservableObject {
    static let shared = NotinhasImgBBCredentialStore()

    @Published private(set) var revision = UUID()

    /// Cached credential-presence flag. Reading the Keychain is a synchronous
    /// `securityd` XPC round-trip (tens of ms), so resolving it on every access
    /// made SwiftUI bodies that read `isConfigured` — the annotate bottom bar and
    /// Quick Access cards — hitch on every unrelated `@Published` update. The
    /// Keychain is now consulted only when the credential can actually change
    /// (init/save/clear/reload).
    @Published private(set) var isConfigured: Bool = false

    private let defaults: UserDefaults
    private let keychain: ImgBBKeychainBacking

    init(
        defaults: UserDefaults = .standard,
        keychain: ImgBBKeychainBacking = CloudKeychainImgBBBacking(),
    ) {
        self.defaults = defaults
        self.keychain = keychain
        refreshConfiguredState()
    }

    var apiKey: String? {
        readAPIKey()
    }

    var maskedAPIKey: String {
        guard let apiKey else { return "" }
        guard apiKey.count > 8 else { return L10n.CloudSettings.storedSecurelyInKeychain }
        let prefix = String(apiKey.prefix(4))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)••••\(suffix)"
    }

    func save(apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NotinhasImgBBCredentialError.emptyKey
        }

        do {
            try keychain.upsert(value: trimmed)
            defaults.removeObject(forKey: PreferencesKeys.notinhasImgBBAPIKey)
            publishChange()
        } catch {
            throw NotinhasImgBBCredentialError.keychainWriteFailed(error.localizedDescription)
        }
    }

    func clear() {
        _ = keychain.delete()
        defaults.removeObject(forKey: PreferencesKeys.notinhasImgBBAPIKey)
        publishChange()
    }

    func reload() {
        publishChange()
    }

    private func readAPIKey() -> String? {
        switch keychain.read(context: "imgbbCredential.read") {
        case .success(let value):
            return normalizedKey(value)
        case .itemNotFound, .authRequired, .interactionNotAllowed, .error:
            break
        }

        guard let legacyValue = legacyUserDefaultsValue() else {
            return nil
        }

        do {
            try keychain.upsert(value: legacyValue)
            defaults.removeObject(forKey: PreferencesKeys.notinhasImgBBAPIKey)
        } catch {
            // Preserve the legacy value when Keychain migration cannot complete.
        }

        return legacyValue
    }

    private func legacyUserDefaultsValue() -> String? {
        guard let stored = defaults.string(forKey: PreferencesKeys.notinhasImgBBAPIKey) else {
            return nil
        }
        return normalizedKey(stored)
    }

    private func normalizedKey(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func publishChange() {
        revision = UUID()
        refreshConfiguredState()
    }

    /// Refresh the cached `isConfigured` flag from the source of truth. Kept off
    /// the hot read path: only invoked at init and after mutations.
    private func refreshConfiguredState() {
        isConfigured = apiKey != nil
    }
}

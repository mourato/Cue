//
//  CueImgBBCredentialStore.swift
//  Notinhas
//
//  Secure ImgBB API key storage with legacy UserDefaults migration.
//

import Combine
import Foundation

enum CueImgBBCredentialError: LocalizedError {
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
    func probePresence(context: String) -> CloudKeychainPresence
    func upsert(value: String) throws
    func delete() -> [CloudKeychainDeleteIssue]
}

struct CloudKeychainImgBBBacking: ImgBBKeychainBacking {
    func read(context: String) -> CloudKeychainReadOutcome {
        CloudKeychainStore.read(item: .imgbbAPIKey, context: context)
    }

    func probePresence(context: String) -> CloudKeychainPresence {
        CloudKeychainStore.probePresence(item: .imgbbAPIKey, context: context)
    }

    func upsert(value: String) throws {
        _ = try CloudKeychainStore.upsert(item: .imgbbAPIKey, value: value)
    }

    func delete() -> [CloudKeychainDeleteIssue] {
        CloudKeychainStore.delete(item: .imgbbAPIKey)
    }
}

@MainActor
final class CueImgBBCredentialStore: ObservableObject {
    static let shared = CueImgBBCredentialStore()

    @Published private(set) var revision = UUID()

    /// Cached credential-presence flag. Reading the Keychain for the secret is a
    /// synchronous `securityd` round-trip that can present a password dialog after
    /// a new code signature. SwiftUI bodies that read `isConfigured` — the annotate
    /// bottom bar and Quick Access cards — must never unlock the secret. Presence is
    /// cached from UserDefaults and a silent Keychain probe, and refreshed only when
    /// the credential can change (init/save/clear/reload).
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

    /// Unlocks Keychain when needed. Call only from explicit upload / Preferences paths.
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
            throw CueImgBBCredentialError.emptyKey
        }

        do {
            try keychain.upsert(value: trimmed)
            defaults.removeObject(forKey: PreferencesKeys.notinhasImgBBAPIKey)
            defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)
            publishChange()
        } catch {
            throw CueImgBBCredentialError.keychainWriteFailed(error.localizedDescription)
        }
    }

    func clear() {
        _ = keychain.delete()
        defaults.removeObject(forKey: PreferencesKeys.notinhasImgBBAPIKey)
        defaults.set(false, forKey: PreferencesKeys.imgbbCredentialConfigured)
        publishChange()
    }

    func reload() {
        defaults.removeObject(forKey: PreferencesKeys.imgbbCredentialConfigured)
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
            defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)
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

    /// Refresh the cached `isConfigured` flag without unlocking the secret.
    private func refreshConfiguredState() {
        isConfigured = resolveConfiguredPresence()
    }

    private func resolveConfiguredPresence() -> Bool {
        // Legacy plaintext keys still count even if an earlier silent probe cached false.
        if legacyUserDefaultsValue() != nil {
            defaults.set(true, forKey: PreferencesKeys.imgbbCredentialConfigured)
            return true
        }

        if let cached = defaults.object(forKey: PreferencesKeys.imgbbCredentialConfigured) as? Bool {
            return cached
        }

        let present = keychain.probePresence(context: "imgbbCredential.probe") == .present
        defaults.set(present, forKey: PreferencesKeys.imgbbCredentialConfigured)
        return present
    }
}

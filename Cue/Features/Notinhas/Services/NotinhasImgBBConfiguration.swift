import Foundation

@MainActor
enum NotinhasImgBBConfiguration {
    /// Legacy UserDefaults key retained for one-time migration only. New writes must use Keychain.
    static let apiKeyUserDefaultsKey = PreferencesKeys.notinhasImgBBAPIKey
    static let panelSideUserDefaultsKey = PreferencesKeys.notinhasNotesPanelSide

    static var apiKey: String? {
        NotinhasImgBBCredentialStore.shared.apiKey
    }

    static var panelSide: NotinhasNotesPanelSide {
        migratePanelSideIfNeeded()
        return NotinhasNotesPanelSide.resolved(from: UserDefaults.standard.string(forKey: panelSideUserDefaultsKey))
    }

    static func migratePanelSideIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: PreferencesKeys.notinhasNotesPanelSide) == nil,
              let legacyValue = defaults.string(forKey: PreferencesKeys.legacyNotinhasNotesPanelSide)
        else { return }
        defaults.set(legacyValue, forKey: PreferencesKeys.notinhasNotesPanelSide)
    }
}

import Foundation

@MainActor
enum CueImgBBConfiguration {
    /// Legacy UserDefaults key retained for one-time migration only. New writes must use Keychain.
    static let apiKeyUserDefaultsKey = PreferencesKeys.notinhasImgBBAPIKey
    static let panelSideUserDefaultsKey = PreferencesKeys.cueNotesPanelSide

    static var apiKey: String? {
        CueImgBBCredentialStore.shared.apiKey
    }

    static var panelSide: CueNotesPanelSide {
        migratePanelSideIfNeeded()
        return CueNotesPanelSide.resolved(from: UserDefaults.standard.string(forKey: panelSideUserDefaultsKey))
    }

    static func migratePanelSideIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: PreferencesKeys.cueNotesPanelSide) == nil,
              let legacyValue = defaults.string(forKey: PreferencesKeys.legacyCueNotesPanelSide)
        else { return }
        defaults.set(legacyValue, forKey: PreferencesKeys.cueNotesPanelSide)
    }
}

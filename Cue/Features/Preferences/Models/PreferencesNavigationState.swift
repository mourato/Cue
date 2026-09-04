//
//  PreferencesNavigationState.swift
//  Notinhas
//
//  Shared navigation state for selecting Preferences tabs programmatically.
//

import Combine
import Foundation

enum PreferencesTab: String, Hashable {
    case general
    case capture
    case annotate
    case quickAccess
    case history
    case shortcuts
    case permissions
    case cloud
    case advanced
}

@MainActor
final class PreferencesNavigationState: ObservableObject {
    static let shared = PreferencesNavigationState()

    @Published var selectedTab: PreferencesTab {
        didSet {
            userDefaults.set(selectedTab.rawValue, forKey: PreferencesKeys.selectedPreferencesTab)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let raw = userDefaults.string(forKey: PreferencesKeys.selectedPreferencesTab)
        selectedTab = raw.flatMap(PreferencesTab.init(rawValue:)) ?? .general
    }
}

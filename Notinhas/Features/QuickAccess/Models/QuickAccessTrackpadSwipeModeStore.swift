//
//  QuickAccessTrackpadSwipeModeStore.swift
//  Notinhas
//
//  Persisted trackpad swipe direction mode for Quick Access cards.
//

import Combine
import Foundation

@MainActor
final class QuickAccessTrackpadSwipeModeStore: ObservableObject {
    static let shared = QuickAccessTrackpadSwipeModeStore()

    @Published private(set) var mode: QuickAccessTrackpadSwipeMode

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawValue = defaults.string(forKey: PreferencesKeys.quickAccessTrackpadSwipeMode),
           let storedMode = QuickAccessTrackpadSwipeMode(rawValue: rawValue) {
            mode = storedMode
        } else {
            mode = .inverted
        }
    }

    func setMode(_ newMode: QuickAccessTrackpadSwipeMode) {
        guard mode != newMode else { return }
        mode = newMode
        defaults.set(newMode.rawValue, forKey: PreferencesKeys.quickAccessTrackpadSwipeMode)
    }

    func resetToDefault() {
        setMode(.inverted)
    }
}

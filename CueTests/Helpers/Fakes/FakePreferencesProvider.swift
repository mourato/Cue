//
//  FakePreferencesProvider.swift
//  NotinhasTests
//
//  In-memory PreferencesProviding fake for unit tests.
//

@testable import Cue
import Foundation

@MainActor
final class FakePreferencesProvider: PreferencesProviding {
    private var actions: [AfterCaptureAction: [CaptureType: Bool]] = [:]

    func setAction(_ action: AfterCaptureAction, for type: CaptureType, enabled: Bool) {
        if actions[action] == nil {
            actions[action] = [:]
        }
        actions[action]?[type] = enabled
    }

    func isActionEnabled(_ action: AfterCaptureAction, for type: CaptureType) -> Bool {
        actions[action]?[type] ?? defaultValue(for: action, type: type)
    }

    private func defaultValue(for action: AfterCaptureAction, type _: CaptureType) -> Bool {
        switch action {
        case .showQuickAccess, .save, .copyFile:
            true
        case .openAnnotate:
            false
        }
    }
}

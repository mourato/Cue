import Foundation

/// Compile + runtime gate for Recording / Video Editor (Notinhas optional module).
enum VideoModuleAvailability {
    static var isCompiledIn: Bool {
        #if CUE_VIDEO_MODULE
            true
        #else
            false
        #endif
    }

    static var isEnabled: Bool {
        isEnabled(using: .standard)
    }

    static func isEnabled(using defaults: UserDefaults) -> Bool {
        guard isCompiledIn else { return false }
        if defaults.object(forKey: PreferencesKeys.videoModuleEnabled) == nil {
            return false
        }
        return defaults.bool(forKey: PreferencesKeys.videoModuleEnabled)
    }

    static func setEnabled(_ enabled: Bool) {
        setEnabled(enabled, using: .standard)
    }

    static func setEnabled(_ enabled: Bool, using defaults: UserDefaults) {
        guard isCompiledIn else { return }
        defaults.set(enabled, forKey: PreferencesKeys.videoModuleEnabled)
        NotificationCenter.default.post(name: .videoModuleAvailabilityDidChange, object: nil)
    }
}

extension Notification.Name {
    static let videoModuleAvailabilityDidChange = Notification.Name("videoModuleAvailabilityDidChange")
}

import Foundation

/// Compile + runtime gate for Recording / Video Editor (Notinhas optional module).
enum VideoModuleAvailability {
    static var isCompiledIn: Bool {
        #if NOTINHAS_VIDEO_MODULE
            true
        #else
            false
        #endif
    }

    static var isEnabled: Bool {
        guard isCompiledIn else { return false }
        if UserDefaults.standard.object(forKey: PreferencesKeys.videoModuleEnabled) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: PreferencesKeys.videoModuleEnabled)
    }

    static func setEnabled(_ enabled: Bool) {
        guard isCompiledIn else { return }
        UserDefaults.standard.set(enabled, forKey: PreferencesKeys.videoModuleEnabled)
        NotificationCenter.default.post(name: .videoModuleAvailabilityDidChange, object: nil)
    }
}

extension Notification.Name {
    static let videoModuleAvailabilityDidChange = Notification.Name("videoModuleAvailabilityDidChange")
}

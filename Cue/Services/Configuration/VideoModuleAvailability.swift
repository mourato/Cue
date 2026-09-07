import Foundation

/// Compile-time gate for Recording / Video Editor.
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
        _ = defaults
        return isCompiledIn
    }

    static func setEnabled(_ enabled: Bool) {
        setEnabled(enabled, using: .standard)
    }

    static func setEnabled(_ enabled: Bool, using defaults: UserDefaults) {
        _ = enabled
        _ = defaults
    }
}

extension Notification.Name {
    static let videoModuleAvailabilityDidChange = Notification.Name("videoModuleAvailabilityDidChange")
}

//
//  FeedbackAccessibilityPolicy.swift
//  Notinhas
//
//  Accessibility semantics for transient feedback surfaces.
//  Programmatic VoiceOver announcements are deferred; hosted SwiftUI exposes labels.
//  Toast labels use the (already localized) message — avoid hardcoded English tone prefixes.
//

import Foundation

enum FeedbackAccessibilityPolicy {
    /// Stable semantic token for tests and future announcement routing (not user-facing copy).
    static func toneAccessibilityToken(for tone: FeedbackTone) -> String {
        switch tone {
        case .info: "info"
        case .success: "success"
        case .warning: "warning"
        case .error: "error"
        }
    }

    /// Passive toast label is the localized message from the call site.
    static func toastAccessibilityLabel(message: String, tone _: FeedbackTone, isProgress _: Bool) -> String {
        message
    }

    /// Progress toasts expose the live message as value; terminal toasts omit value.
    static func toastAccessibilityValue(message: String, isProgress: Bool) -> String? {
        isProgress ? message : nil
    }

    /// Progress handle updates should not trigger programmatic announcements.
    static func shouldAnnounceToastUpdate(previousMessage: String, newMessage: String, isProgress: Bool) -> Bool {
        guard !isProgress else { return false }
        return previousMessage != newMessage
    }
}

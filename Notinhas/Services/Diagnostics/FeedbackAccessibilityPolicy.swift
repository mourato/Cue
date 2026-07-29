//
//  FeedbackAccessibilityPolicy.swift
//  Notinhas
//
//  Accessibility semantics for transient feedback surfaces.
//  Programmatic VoiceOver announcements are deferred; hosted SwiftUI exposes labels.
//

import Foundation

enum FeedbackAccessibilityPolicy {
  static func toneAccessibilityLabel(for tone: FeedbackTone) -> String {
    switch tone {
    case .info: "Information"
    case .success: "Success"
    case .warning: "Warning"
    case .error: "Error"
    }
  }

  /// Passive toast label combines tone and message for VoiceOver.
  static func toastAccessibilityLabel(message: String, tone: FeedbackTone, isProgress: Bool) -> String {
    let prefix = toneAccessibilityLabel(for: tone)
    if isProgress {
      return "\(prefix), in progress. \(message)"
    }
    return "\(prefix). \(message)"
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

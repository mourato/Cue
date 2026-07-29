//
//  FeedbackMotionPolicy.swift
//  Notinhas
//
//  Reduce Motion policy for floating feedback surfaces.
//

import AppKit
import SwiftUI

enum FeedbackMotionPolicy {
  /// AppKit presenter path when SwiftUI environment is unavailable.
  static var appKitShouldReduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  static func shouldReduceMotion(_ reduceMotion: Bool) -> Bool {
    reduceMotion || appKitShouldReduceMotion
  }

  static func usesScaleAnimation(reduceMotion: Bool) -> Bool {
    !shouldReduceMotion(reduceMotion)
  }

  static func usesSpringAnimation(reduceMotion: Bool) -> Bool {
    !shouldReduceMotion(reduceMotion)
  }

  static func toastEntranceScale(reduceMotion: Bool, appeared: Bool) -> CGFloat {
    guard usesScaleAnimation(reduceMotion: reduceMotion) else { return 1.0 }
    return appeared ? 1.0 : 0.96
  }

  static func quickAccessPressScale(reduceMotion: Bool, isPressed: Bool) -> CGFloat {
    guard usesScaleAnimation(reduceMotion: reduceMotion) else { return 1.0 }
    return isPressed ? 0.85 : 1.0
  }

  static func panelFadeDuration(reduceMotion _: Bool) -> TimeInterval {
    // Fade remains acceptable under Reduce Motion.
    0.16
  }
}

//
//  QuickAccessIconButton.swift
//  Notinhas
//
//  Reusable icon button with hover effect and cursor state for quick access cards
//

import AppKit
import SwiftUI

/// Icon button with hover effect and pointer cursor for card action buttons
struct QuickAccessIconButton: View {
  let icon: String
  let action: () -> Void
  var helpText: String?
  /// Resolved scale from `QuickAccessCornerButtonMetrics.resolvedScale(...)`.
  var sizeScale: CGFloat = 1

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isHovering = false
  @State private var isPressed = false

  private var metrics: QuickAccessCornerButtonMetrics {
    QuickAccessCornerButtonMetrics(scale: sizeScale)
  }

  var body: some View {
    Button(action: {
      guard isEnabled else { return }
      if FeedbackMotionPolicy.usesScaleAnimation(reduceMotion: reduceMotion) {
        withAnimation(.easeOut(duration: 0.05)) {
          isPressed = true
        }
      } else {
        isPressed = true
      }
      // Execute action immediately
      action()
      // Reset press state
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isPressed = false
      }
    }) {
      Image(systemName: icon)
        .font(.system(size: metrics.iconFontSize, weight: .bold))
        .foregroundColor(.white
          .opacity(FeedbackLocalStateTokens.quickAccessButtonForegroundOpacity(isEnabled: isEnabled)))
        .frame(width: metrics.touchSize, height: metrics.touchSize)
        .contentShape(Circle())
        .background(
          Circle()
            .fill(buttonBackgroundColor)
        )
        .scaleEffect(FeedbackMotionPolicy.quickAccessPressScale(reduceMotion: reduceMotion, isPressed: isPressed))
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      guard isEnabled else {
        isHovering = false
        NSCursor.arrow.set()
        return
      }
      if FeedbackMotionPolicy.usesScaleAnimation(reduceMotion: reduceMotion) {
        withAnimation(.easeInOut(duration: 0.1)) {
          isHovering = hovering
        }
      } else {
        isHovering = hovering
      }
      if hovering {
        NSCursor.pointingHand.set()
      } else {
        NSCursor.arrow.set()
      }
    }
    .if(helpText != nil) { view in
      view.help(helpText!)
    }
  }

  private var buttonBackgroundColor: Color {
    let state: FeedbackQuickAccessButtonState = if !isEnabled {
      .disabled
    } else if isPressed {
      .pressed
    } else if isHovering {
      .hover
    } else {
      .default
    }
    return FeedbackLocalStateTokens.quickAccessButtonBackground(for: state)
  }
}

/// Shared metrics for Quick Access corner icon buttons (live card + preferences preview).
struct QuickAccessCornerButtonMetrics {
  static let baseIconFontSize: CGFloat = 10
  static let baseTouchSize: CGFloat = 20
  static let basePadding: CGFloat = 6
  static let scaleRange: ClosedRange<Double> = 0.75 ... 1.75

  /// Edge extent from card corner for a given scale (`touchSize + padding`).
  static func edgeExtent(forScale scale: CGFloat) -> CGFloat {
    (baseTouchSize + basePadding) * scale
  }

  /// Largest scale that keeps opposite corner buttons from overlapping on a card.
  static func maximumScale(forOverlayScale overlayScale: CGFloat) -> CGFloat {
    let cardHeight = QuickAccessLayout.scaledCardHeight(max(overlayScale, 0.01))
    let maxFit = cardHeight / (2 * (baseTouchSize + basePadding))
    return max(CGFloat(scaleRange.lowerBound), min(CGFloat(scaleRange.upperBound), maxFit))
  }

  /// Preference scale clamped to the allowed range and to the current overlay card size.
  static func resolvedScale(cornerButtonScale: CGFloat, overlayScale: CGFloat) -> CGFloat {
    let preferred = max(
      CGFloat(scaleRange.lowerBound),
      min(cornerButtonScale, CGFloat(scaleRange.upperBound))
    )
    return min(preferred, maximumScale(forOverlayScale: overlayScale))
  }

  let scale: CGFloat

  init(scale: CGFloat) {
    self.scale = max(CGFloat(Self.scaleRange.lowerBound), min(scale, CGFloat(Self.scaleRange.upperBound)))
  }

  var iconFontSize: CGFloat {
    Self.baseIconFontSize * scale
  }

  var touchSize: CGFloat {
    Self.baseTouchSize * scale
  }

  var padding: CGFloat {
    Self.basePadding * scale
  }
}

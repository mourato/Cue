//
//  FeedbackStyle.swift
//  Notinhas
//
//  Semantic tokens for floating feedback surfaces (toasts, prompts).
//

import AppKit
import SwiftUI

enum FeedbackTone: Equatable, CaseIterable {
    case info
    case success
    case warning
    case error
}

struct FeedbackStyle: Equatable {
    let tone: FeedbackTone

    var iconName: String {
        switch tone {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    var iconColor: Color {
        switch tone {
        case .info: .blue
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }

    /// Optional subtle gradient for spinner arcs; primary icon rendering uses `iconColor`.
    var iconAccentColors: [Color] {
        switch tone {
        case .info: [iconColor, .cyan]
        case .success: [iconColor, .mint]
        case .warning: [iconColor, .yellow]
        case .error: [iconColor, .pink]
        }
    }

    var textColor: NSColor {
        textColor(usesSolidFallback: false)
    }

    var borderColor: NSColor {
        borderColor(usesSolidFallback: false)
    }

    /// HUD material uses light chrome; solid accessibility fallback keeps the inverted pair.
    func textColor(usesSolidFallback: Bool) -> NSColor {
        usesSolidFallback
            ? FeedbackAppearanceTokens.resolvedSolidTextColor
            : FeedbackAppearanceTokens.hudTextColor
    }

    func borderColor(usesSolidFallback: Bool) -> NSColor {
        usesSolidFallback
            ? FeedbackAppearanceTokens.resolvedSolidBorderColor
            : FeedbackAppearanceTokens.hudBorderColor
    }

    var solidBackgroundColor: NSColor {
        FeedbackAppearanceTokens.resolvedSolidBackgroundColor
    }

    var materialOverlayTint: Color {
        switch tone {
        case .info: Color.blue.opacity(0.04)
        case .success: Color.green.opacity(0.04)
        case .warning: Color.orange.opacity(0.05)
        case .error: Color.red.opacity(0.05)
        }
    }
}

// MARK: - Chrome policy

enum FeedbackChromePolicy {
    /// Solid fallback when Reduce Transparency or Increase Contrast is active.
    static func usesSolidFallback(reduceTransparency: Bool) -> Bool {
        reduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

// MARK: - AppToastStyle compatibility

extension AppToastStyle {
    var feedbackTone: FeedbackTone {
        switch self {
        case .info: .info
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }

    var feedbackStyle: FeedbackStyle {
        FeedbackStyle(tone: feedbackTone)
    }

    var iconName: String {
        feedbackStyle.iconName
    }

    var textColor: NSColor {
        feedbackStyle.textColor(usesSolidFallback: true)
    }

    var borderColor: NSColor {
        feedbackStyle.borderColor(usesSolidFallback: true)
    }

    var backgroundColor: NSColor {
        feedbackStyle.solidBackgroundColor
    }

    var iconColor: Color {
        feedbackStyle.iconColor
    }

    var iconGradientColors: [Color] {
        feedbackStyle.iconAccentColors
    }
}

// MARK: - Appearance tokens

enum FeedbackAppearanceTokens {
    /// Light label for `.hudWindow` material (forced dark HUD chrome).
    static let hudTextColor = NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)

    static let hudBorderColor = NSColor(srgbRed: 0.82, green: 0.82, blue: 0.84, alpha: 0.25)

    /// Neutral solid fallback — dark on Light mode, light on Dark mode.
    static var resolvedSolidBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            solidBackgroundColor(isDarkAppearance: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        }
    }

    static var resolvedSolidBorderColor: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                NSColor(srgbRed: 0.82, green: 0.82, blue: 0.84, alpha: 0.25)
            } else {
                NSColor(srgbRed: 0.30, green: 0.30, blue: 0.32, alpha: 0.35)
            }
        }
    }

    static var resolvedSolidTextColor: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            } else {
                NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
            }
        }
    }

    /// Compatibility alias for call sites that still read the solid inverted text token.
    static var resolvedTextColor: NSColor {
        resolvedSolidTextColor
    }

    static var resolvedBorderColor: NSColor {
        resolvedSolidBorderColor
    }

    /// Pure sRGB components for the solid fallback background.
    static func solidBackgroundSRGBComponents(isDarkAppearance: Bool) -> (
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
    ) {
        if isDarkAppearance {
            (0.96, 0.96, 0.97, 0.97)
        } else {
            (0.11, 0.11, 0.12, 0.97)
        }
    }

    /// Builds the solid fallback color for a resolved light/dark appearance.
    static func solidBackgroundColor(isDarkAppearance: Bool) -> NSColor {
        let components = solidBackgroundSRGBComponents(isDarkAppearance: isDarkAppearance)
        return NSColor(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha,
        )
    }

    /// Resolves solid background for a named appearance (unit-test helper).
    static func solidBackgroundColor(for appearanceName: NSAppearance.Name) -> NSColor {
        solidBackgroundColor(isDarkAppearance: appearanceName == .darkAqua)
    }
}

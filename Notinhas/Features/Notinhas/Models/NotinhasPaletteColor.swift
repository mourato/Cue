//
//  NotinhasPaletteColor.swift
//  Notinhas
//
//  Named Notinhas palette colors with AppKit menu swatch images.
//

import AppKit
import Foundation

/// Fixed Notinhas editor palette. Menu items use `menuImage` so AppKit can show
/// a real color circle beside the localized name (SwiftUI `Circle` icons are dropped).
nonisolated enum NotinhasPaletteColor: String, CaseIterable, Identifiable, Hashable {
    case red
    case orange
    case blue
    case green
    case purple
    case black

    var id: String {
        rawValue
    }

    var rgba: RGBAColor {
        switch self {
        case .red:
            RGBAColor(red: 0.95, green: 0.23, blue: 0.21, alpha: 1)
        case .orange:
            RGBAColor(red: 0.98, green: 0.55, blue: 0.09, alpha: 1)
        case .blue:
            RGBAColor(red: 0.20, green: 0.60, blue: 0.95, alpha: 1)
        case .green:
            RGBAColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1)
        case .purple:
            RGBAColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1)
        case .black:
            RGBAColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
        }
    }

    var localizedName: String {
        switch self {
        case .red:
            NotinhasL10n.colorRed
        case .orange:
            NotinhasL10n.colorOrange
        case .blue:
            NotinhasL10n.colorBlue
        case .green:
            NotinhasL10n.colorGreen
        case .purple:
            NotinhasL10n.colorPurple
        case .black:
            NotinhasL10n.colorBlack
        }
    }

    /// Circular swatch suitable for `NSMenuItem.image` / SwiftUI `Image(nsImage:)`.
    func menuImage(diameter: CGFloat = 14) -> NSImage {
        Self.makeSwatchImage(color: rgba.nsColor, diameter: diameter)
    }

    static func matching(_ color: RGBAColor) -> NotinhasPaletteColor? {
        allCases.first { colorsMatch($0.rgba, color) }
    }

    static func makeSwatchImage(color: NSColor, diameter: CGFloat) -> NSImage {
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { bounds in
            let inset = bounds.insetBy(dx: 0.5, dy: 0.5)
            color.setFill()
            NSBezierPath(ovalIn: inset).fill()
            NSColor.black.withAlphaComponent(0.22).setStroke()
            let stroke = NSBezierPath(ovalIn: inset)
            stroke.lineWidth = 1
            stroke.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func colorsMatch(_ lhs: RGBAColor, _ rhs: RGBAColor) -> Bool {
        abs(lhs.red - rhs.red) < 0.02
            && abs(lhs.green - rhs.green) < 0.02
            && abs(lhs.blue - rhs.blue) < 0.02
            && abs(lhs.alpha - rhs.alpha) < 0.02
    }
}

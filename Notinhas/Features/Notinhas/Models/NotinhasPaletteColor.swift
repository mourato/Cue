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
    case magenta
    case black

    var id: String {
        rawValue
    }

    var rgba: RGBAColor {
        switch self {
        case .red:
            RGBAColor(red: 0.850980, green: 0.207843, blue: 0.188235, alpha: 1)
        case .orange:
            RGBAColor(red: 0.929412, green: 0.517647, blue: 0.074510, alpha: 1)
        case .blue:
            RGBAColor(red: 0, green: 0.462745, blue: 0.870588, alpha: 1)
        case .green:
            RGBAColor(red: 0.368627, green: 0.858824, blue: 0.654902, alpha: 1)
        case .purple:
            RGBAColor(red: 0.592157, green: 0.278431, blue: 1, alpha: 1)
        case .magenta:
            RGBAColor(red: 0.909804, green: 0.090196, blue: 0.541176, alpha: 1)
        case .black:
            RGBAColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
        }
    }

    var numeralColor: NSColor {
        self == .green ? .black : .white
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
        case .magenta:
            NotinhasL10n.colorMagenta
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

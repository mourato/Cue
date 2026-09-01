//
//  AnnotateBuiltInColorPalette.swift
//  Notinhas
//
//  Shared built-in annotate + Notes color swatches. Notes hex values win when
//  a named slot exists in both sets; remaining annotate-only swatches are kept.
//  User customs stay in AnnotateColorPaletteStore.
//

import Foundation
import SwiftUI

/// Built-in color dictionary shared by annotate tools and the Notes editor.
nonisolated enum AnnotateBuiltInColorPalette {
    struct Entry: Identifiable {
        let id: String
        let rgba: RGBAColor

        var color: Color {
            rgba.color
        }

        var accessibilityName: String {
            switch id {
            case CuePaletteColor.red.rawValue:
                CueL10n.colorRed
            case CuePaletteColor.orange.rawValue:
                CueL10n.colorOrange
            case "yellow":
                CueL10n.colorYellow
            case CuePaletteColor.green.rawValue:
                CueL10n.colorGreen
            case CuePaletteColor.blue.rawValue:
                CueL10n.colorBlue
            case CuePaletteColor.purple.rawValue:
                CueL10n.colorPurple
            case CuePaletteColor.magenta.rawValue:
                CueL10n.colorMagenta
            case "pink":
                CueL10n.colorPink
            case "gray":
                CueL10n.colorGray
            case "white":
                CueL10n.colorWhite
            case CuePaletteColor.black.rawValue:
                CueL10n.colorBlack
            case "darkGray":
                CueL10n.colorDarkGray
            case "mediumGray":
                CueL10n.colorMediumGray
            case "lightGray":
                CueL10n.colorLightGray
            case "nearWhite":
                CueL10n.colorNearWhite
            default:
                id
            }
        }
    }

    /// Annotation stroke / Notes solids (Notes hex for named overlaps).
    static let annotationEntries: [Entry] = uniqued([
        entry(from: .red),
        entry(from: .orange),
        Entry(id: "yellow", rgba: RGBAColor(red: 1, green: 0.839216, blue: 0, alpha: 1)),
        entry(from: .green),
        entry(from: .blue),
        entry(from: .purple),
        entry(from: .magenta),
        Entry(id: "pink", rgba: RGBAColor(red: 1, green: 0.215686, blue: 0.372549, alpha: 1)),
        Entry(id: "gray", rgba: RGBAColor(red: 0.596078, green: 0.596078, blue: 0.615686, alpha: 1)),
        Entry(id: "white", rgba: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)),
        entry(from: .black),
    ])

    /// Canvas background extras kept after the shared annotation set.
    static let canvasExtendedEntries: [Entry] = uniqued([
        Entry(id: "darkGray", rgba: RGBAColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)),
        Entry(id: "mediumGray", rgba: RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)),
        Entry(id: "lightGray", rgba: RGBAColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)),
        Entry(id: "nearWhite", rgba: RGBAColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)),
    ])

    static let canvasEntries: [Entry] = uniqued(annotationEntries + canvasExtendedEntries)

    static var annotationColors: [Color] {
        annotationEntries.map(\.color)
    }

    static var fillColors: [Color] {
        [.clear] + annotationColors
    }

    static var canvasColors: [Color] {
        canvasEntries.map(\.color)
    }

    static var namedCanvasEntries: [(color: Color, name: String)] {
        canvasEntries.map { ($0.color, $0.accessibilityName) }
    }

    private static func entry(from palette: CuePaletteColor) -> Entry {
        Entry(id: palette.rawValue, rgba: palette.rgba)
    }

    private static func uniqued(_ entries: [Entry]) -> [Entry] {
        var result: [Entry] = []
        for entry in entries {
            if result.contains(where: { colorsMatch($0.rgba, entry.rgba) }) {
                continue
            }
            result.append(entry)
        }
        return result
    }

    private static func colorsMatch(_ lhs: RGBAColor, _ rhs: RGBAColor) -> Bool {
        abs(lhs.red - rhs.red) < 0.001
            && abs(lhs.green - rhs.green) < 0.001
            && abs(lhs.blue - rhs.blue) < 0.001
            && abs(lhs.alpha - rhs.alpha) < 0.001
    }
}

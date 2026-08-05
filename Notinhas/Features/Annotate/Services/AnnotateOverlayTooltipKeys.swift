//
//  AnnotateOverlayTooltipKeys.swift
//  Notinhas
//
//  Maps AnnotateShortcutManager tool/action shortcuts to OverlayTooltip keycap arrays.
//

import Foundation

@MainActor
enum AnnotateOverlayTooltipKeys {
    static func toolKeys(
        for tool: AnnotationToolType,
        manager: AnnotateShortcutManager = .shared,
    ) -> [String] {
        guard manager.isShortcutEnabled(for: tool),
              let key = manager.shortcut(for: tool)
        else { return [] }
        return [String(key).uppercased()]
    }

    static func actionKeys(
        for kind: AnnotateActionShortcutKind,
        manager: AnnotateShortcutManager = .shared,
    ) -> [String] {
        guard manager.isActionShortcutEnabled(for: kind),
              let config = manager.shortcut(for: kind)
        else { return [] }
        return config.displayParts
    }
}

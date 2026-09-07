//
//  PreferencesAnnotateChromeCustomizationView.swift
//  Notinhas
//
//  Annotate toolbar and bottom-bar order and visibility controls.
//

import SwiftUI

enum AnnotateChromeCustomizationSurface {
    case toolbar
    case bottomBar
}

struct AnnotateChromeCustomizationContent: View {
    let surface: AnnotateChromeCustomizationSurface
    @ObservedObject private var chromeStore = AnnotateChromeConfigurationStore.shared

    var body: some View {
        switch surface {
        case .toolbar:
            chromeListSection(
                items: chromeStore.toolbarItemOrder,
                showsFootnote: true,
                showsReset: false,
                onMove: { source, destination in
                    chromeStore.moveToolbarItem(from: source, to: destination)
                },
            )
        case .bottomBar:
            chromeListSection(
                items: chromeStore.bottomActionOrder,
                showsFootnote: false,
                showsReset: true,
                onMove: { source, destination in
                    chromeStore.moveBottomAction(from: source, to: destination)
                },
            )
        }
    }
}

private extension AnnotateChromeCustomizationContent {
    func chromeListSection(
        items: [AnnotateChromeItem],
        showsFootnote: Bool,
        showsReset: Bool,
        onMove: @escaping (IndexSet, Int) -> Void,
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.PreferencesAnnotate.chromeDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            PreferencesReorderToggleList(
                items: items,
                title: { $0.settingsTitle },
                systemImage: { $0.systemImage },
                isEnabled: { item in
                    Binding(
                        get: { chromeStore.isEnabled(item) },
                        set: { chromeStore.setEnabled(item, enabled: $0) },
                    )
                },
                canReorder: { $0.isCustomizable },
                canToggle: { $0.isCustomizable },
                onMove: onMove,
                resetTitle: showsReset ? L10n.PreferencesAnnotate.resetChrome : nil,
                onReset: showsReset ? { chromeStore.resetToDefaults() } : nil,
                reorderPayload: { $0.rawValue },
                accessory: { _ in EmptyView() },
            )

            if showsFootnote {
                Text(L10n.PreferencesAnnotate.chromeAlwaysOnFootnote)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

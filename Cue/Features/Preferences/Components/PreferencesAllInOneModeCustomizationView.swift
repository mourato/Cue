//
//  PreferencesAllInOneModeCustomizationView.swift
//  Notinhas
//
//  All-In-One toolbar mode ordering and visibility controls.
//

import SwiftUI

struct PreferencesAllInOneModeCustomizationContent: View {
    let videoModuleEnabled: Bool
    @ObservedObject private var store = AllInOneCaptureModeConfigurationStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.PreferencesCapture.allInOneModesDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            PreferencesReorderToggleList(
                items: store.orderedModes(videoEnabled: videoModuleEnabled, includeDisabled: true),
                title: { $0.compactTitle },
                isEnabled: { mode in
                    Binding(
                        get: { store.isEnabled(mode) },
                        set: { store.setEnabled(mode, enabled: $0) },
                    )
                },
                canReorder: { _ in true },
                canToggle: { store.canToggle($0) },
                onMove: { source, destination in
                    store.moveMode(from: source, to: destination, videoEnabled: videoModuleEnabled)
                },
                resetTitle: L10n.PreferencesCapture.resetAllInOneModes,
                onReset: { store.resetToDefaults() },
                reorderPayload: { $0.rawValue },
                accessory: { _ in EmptyView() },
            )

            Text(L10n.PreferencesCapture.allInOneModesMinimumFootnote)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

//
//  PreferencesQuickAccessActionCustomizationView.swift
//  Notinhas
//
//  Quick Access card preview and action ordering controls.
//

import SwiftUI
import UniformTypeIdentifiers

struct QuickAccessActionCustomizationView: View {
    @ObservedObject var manager: QuickAccessManager
    @ObservedObject private var actionStore = QuickAccessActionConfigurationStore.shared
    @ObservedObject private var swipeActionStore = QuickAccessSwipeActionStore.shared
    @State private var isReorderingActions = false

    var body: some View {
        Section(L10n.PreferencesQuickAccess.previewSection) {
            HStack {
                Spacer()
                QuickAccessSettingsPreviewCard(
                    scale: CGFloat(manager.overlayScale),
                    cornerButtonScale: CGFloat(manager.cornerButtonScale),
                    actionStore: actionStore,
                    swipeActionStore: swipeActionStore,
                    isReordering: isReorderingActions,
                )
                Spacer()
            }
            .padding(.vertical, 10)
        }

        Section(L10n.PreferencesQuickAccess.quickActionsSection) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.PreferencesQuickAccess.quickActionsDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)

                PreferencesReorderToggleList(
                    items: actionStore.actionOrder,
                    title: { $0.settingsTitle },
                    systemImage: { $0.systemImage },
                    isEnabled: { action in
                        Binding(
                            get: { actionStore.isEnabled(action) },
                            set: { actionStore.setEnabled(action, enabled: $0) },
                        )
                    },
                    canReorder: { _ in true },
                    canToggle: { _ in true },
                    onMove: { source, destination in
                        actionStore.moveAction(from: source, to: destination)
                    },
                    resetTitle: L10n.PreferencesQuickAccess.resetActions,
                    onReset: {
                        actionStore.resetToDefaults()
                        swipeActionStore.resetToDefaults()
                    },
                    reorderUTType: .quickAccessReorder,
                    reorderPayload: { $0.rawValue },
                    accessory: { action in
                        Text(actionStore.assignedSlot(for: action)?.settingsTitle ?? L10n.PreferencesQuickAccess
                            .notOnCard)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    },
                    bodyDragProvider: { action in
                        QuickAccessActionDragPayload.itemProvider(action: action, source: .actionList)
                    },
                    onBodyDragBegan: {
                        isReorderingActions = false
                    },
                    onReorderStateChanged: { isReorderingActions = $0 },
                    bodyDragPreview: { action in
                        QuickAccessActionDragPreview(action: action)
                    },
                )
            }
        }
    }
}

private struct QuickAccessActionDragPreview: View {
    let action: QuickAccessActionKind

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(action.settingsTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1),
        )
        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
        .fixedSize(horizontal: true, vertical: false)
    }
}

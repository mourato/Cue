//
//  AllInOneCaptureToolbarView.swift
//  Notinhas
//
//  Mode strip for the All-In-One capture session.
//

import SwiftUI

struct AllInOneCaptureToolbarView: View {
    @ObservedObject var session: AllInOneCaptureSessionState

    var body: some View {
        HStack(spacing: ToolbarConstants.itemSpacing) {
            ForEach(session.availableModes) { mode in
                CaptureFloatingToolbarIconButton(
                    systemName: mode.systemImage,
                    title: mode.compactTitle,
                    action: { session.activateMode(mode) },
                    accessibilityLabel: mode.accessibilityLabel
                )
                .accessibilityValue(
                    session.selectedMode == mode
                        ? L10n.AllInOne.modeSelectedAccessibilityValue
                        : ""
                )
                .accessibilityAddTraits(session.selectedMode == mode ? .isSelected : [])
            }
        }
        .padding(.horizontal, ToolbarConstants.horizontalPadding)
        .padding(.vertical, ToolbarConstants.verticalPadding)
        .captureFloatingToolbarMaterial()
    }
}

#Preview {
    AllInOneCaptureToolbarView(session: AllInOneCaptureSessionState())
        .padding()
}

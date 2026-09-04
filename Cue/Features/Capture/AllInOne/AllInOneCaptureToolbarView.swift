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
                AllInOneCaptureToolbarModeButton(
                    mode: mode,
                    isSelected: session.selectedMode == mode,
                    action: { session.activateMode(mode) },
                )
            }
        }
        .padding(.horizontal, ToolbarConstants.horizontalPadding)
        .padding(.vertical, ToolbarConstants.verticalPadding)
        .captureFloatingToolbarMaterial()
    }
}

private struct AllInOneCaptureToolbarModeButtonLabel: View {
    let mode: AllInOneCaptureMode
    let isHovered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: mode.systemImage)
                .font(.system(size: ToolbarConstants.iconSize, weight: .medium))

            Text(mode.compactTitle)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.primary.opacity(isHovered ? 1.0 : 0.85))
        .frame(minWidth: 54, minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
                .fill(Color.primary.opacity(isHovered ? 0.1 : 0)),
        )
        .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
        .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isHovered)
    }
}

private struct AllInOneCaptureToolbarModeButton: View {
    let mode: AllInOneCaptureMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            AllInOneCaptureToolbarModeButtonLabel(
                mode: mode,
                isHovered: isHovered,
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityValue(isSelected ? selectedAccessibilityValue : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedAccessibilityValue: String {
        L10n.AllInOne.modeSelectedAccessibilityValue
    }
}

#Preview {
    AllInOneCaptureToolbarView(session: AllInOneCaptureSessionState())
        .padding()
}

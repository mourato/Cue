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

private struct AllInOneCaptureToolbarModeButton: View {
    let mode: AllInOneCaptureMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: ToolbarConstants.iconSize, weight: .medium))

                Text(mode.compactTitle)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(foregroundStyle)
            .frame(width: 54, height: 46)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityValue(isSelected ? selectedAccessibilityValue : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isHovered)
        .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isSelected)
    }

    private var foregroundStyle: Color {
        if isSelected {
            return colorScheme == .dark ? .white : .primary
        }
        return .primary.opacity(isHovered ? 0.95 : 0.72)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
            .fill(backgroundFill)
    }

    private var backgroundFill: Color {
        if isSelected {
            if reduceTransparency {
                let opacity = isHovered ? 0.3 : 0.22
                return colorScheme == .dark ? Color.white.opacity(opacity) : Color.primary.opacity(opacity * 0.65)
            }
            let opacity = colorScheme == .dark
                ? (isHovered ? 0.52 : 0.42)
                : (isHovered ? 0.28 : 0.18)
            return Color.accentColor.opacity(opacity)
        }

        if isHovered {
            return Color.primary.opacity(reduceTransparency ? 0.12 : 0.08)
        }

        return .clear
    }

    private var selectedAccessibilityValue: String {
        L10n.AllInOne.modeSelectedAccessibilityValue
    }
}

#Preview {
    AllInOneCaptureToolbarView(session: AllInOneCaptureSessionState())
        .padding()
}

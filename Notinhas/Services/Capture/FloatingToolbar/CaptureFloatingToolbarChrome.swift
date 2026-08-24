//
//  CaptureFloatingToolbarChrome.swift
//  Notinhas
//
//  Shared SwiftUI chrome for floating capture HUD toolbars (ungated).
//

import SwiftUI

// MARK: - Divider

struct CaptureFloatingToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: ToolbarConstants.dividerHeight)
            .padding(.horizontal, 4)
    }
}

// MARK: - Icon Button

struct CaptureFloatingToolbarIconButtonLabel: View {
    let systemName: String
    var iconSize: CGFloat = ToolbarConstants.iconSize
    let isHovered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(.primary.opacity(isHovered ? 1.0 : 0.85))
            .frame(
                width: ToolbarConstants.iconButtonSize,
                height: ToolbarConstants.iconButtonSize,
            )
            .background(
                RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
                    .fill(Color.primary.opacity(isHovered ? 0.1 : 0)),
            )
            .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
            .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isHovered)
    }
}

struct CaptureFloatingToolbarIconButton: View {
    let systemName: String
    let action: () -> Void
    let accessibilityLabel: String

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            CaptureFloatingToolbarIconButtonLabel(systemName: systemName, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct CaptureFloatingToolbarMaterialBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius, style: .continuous),
                )
        } else {
            content
                .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) :
                    AnyShapeStyle(.ultraThinMaterial))
                .clipShape(RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius)
                        .strokeBorder(Color.primary.opacity(reduceTransparency ? 0.2 : 0.1), lineWidth: 0.5),
                )
        }
    }
}

// MARK: - Material Background

extension View {
    func captureFloatingToolbarMaterial() -> some View {
        modifier(CaptureFloatingToolbarMaterialBackground())
    }
}

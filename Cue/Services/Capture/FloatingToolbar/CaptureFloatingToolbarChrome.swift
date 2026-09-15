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
    let title: String?
    var iconSize: CGFloat = ToolbarConstants.iconSize
    let isHovered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        buttonContent
            .foregroundStyle(.primary.opacity(isHovered ? 1.0 : 0.85))
            .background(
                RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
                    .fill(Color.primary.opacity(isHovered ? 0.1 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
            .animation(reduceMotion ? nil : ToolbarConstants.hoverAnimation, value: isHovered)
    }

    @ViewBuilder
    private var buttonContent: some View {
        if let title {
            VStack(spacing: 3) {
                icon

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 54, minHeight: 46)
        } else {
            icon
                .frame(
                    width: ToolbarConstants.iconButtonSize,
                    height: ToolbarConstants.iconButtonSize
                )
        }
    }

    private var icon: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .medium))
    }
}

struct CaptureFloatingToolbarIconButton: View {
    let systemName: String
    let title: String?
    let action: () -> Void
    let accessibilityLabel: String

    @State private var isHovered = false

    init(
        systemName: String,
        title: String? = nil,
        action: @escaping () -> Void,
        accessibilityLabel: String
    ) {
        self.systemName = systemName
        self.title = title
        self.action = action
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Button(action: action) {
            CaptureFloatingToolbarIconButtonLabel(
                systemName: systemName,
                title: title,
                isHovered: isHovered
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct CaptureFloatingToolbarMaterialBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if !reduceTransparency {
            content
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius, style: .continuous)
                )
        } else {
            content
                .background(AnyShapeStyle(Color(nsColor: .windowBackgroundColor)))
                .clipShape(RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: ToolbarConstants.toolbarCornerRadius)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
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

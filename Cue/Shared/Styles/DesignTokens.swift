//
//  DesignTokens.swift
//  Notinhas
//
//  Centralized design tokens for consistent UI across the app.
//  Based on 8pt grid system.
//

import SwiftUI

// MARK: - Spacing (8pt Grid)

enum Spacing {
    static let xs: CGFloat = 4 // Tight spacing (icons, compact lists)
    static let sm: CGFloat = 8 // Standard gap
    static let md: CGFloat = 16 // Section padding
    static let lg: CGFloat = 24 // Large gaps
    static let xl: CGFloat = 32 // Major sections
}

// MARK: - Sizing

enum Size {
    // Grid items (backgrounds, wallpapers, gradients)
    static let gridItem: CGFloat = 48
    static let gridItemSmall: CGFloat = 40

    // Color swatches
    static let colorSwatch: CGFloat = 32
    static let colorSwatchSmall: CGFloat = 24

    // Corner radii
    static let radiusXs: CGFloat = 4
    static let radiusSm: CGFloat = 6
    static let radiusMd: CGFloat = 8
    static let radiusLg: CGFloat = 12

    // Strokes
    static let strokeDefault: CGFloat = 1
    static let strokeSelected: CGFloat = 2
}

// MARK: - Popover Layout

enum PopoverTokens {
    // Compact selection menus
    static let menuContentInset: CGFloat = Spacing.sm
    static let menuItemSpacing: CGFloat = Spacing.xs
    static let menuItemMinHeight: CGFloat = 28
    static let menuItemHorizontalPadding: CGFloat = Spacing.sm
    static let menuItemVerticalPadding: CGFloat = 6
    static let menuIconSpacing: CGFloat = 7
    static let menuDividerPadding: CGFloat = Spacing.xs
    static let narrowMenuWidth: CGFloat = 180
    static let deviceMenuWidth: CGFloat = 220
    static let outputMenuWidth: CGFloat = 160
    static let zoomMenuWidth: CGFloat = 122
    static let presetMenuWidth: CGFloat = 240

    // Property and settings panels
    static let panelContentInset: CGFloat = 12
    static let panelItemSpacing: CGFloat = Spacing.sm
    static let panelSectionSpacing: CGFloat = Spacing.md
    static let propertyPanelWidth: CGFloat = 196
    static let settingsPanelWidth: CGFloat = 280
    static let infoPanelWidth: CGFloat = 320
    static let infoPanelHeight: CGFloat = 380
    static let speedPanelWidth: CGFloat = 180
    static let colorGridCellSize: CGFloat = 24
    static let colorGridSpacing: CGFloat = 8
    static let colorSwatchSize: CGFloat = 22
    static let noteColorPanelWidth: CGFloat = 220

    // Repeated control geometry
    static let controlSpacing: CGFloat = 6
    static let compactControlSpacing: CGFloat = 5
    static let controlHorizontalPadding: CGFloat = 10
    static let controlVerticalPadding: CGFloat = 5
    static let controlCornerRadius: CGFloat = Size.radiusSm
    static let hoverFill = Color.primary.opacity(0.08)
    static let selectedFill = Color.accentColor.opacity(0.12)
    static let selectedStroke = Color.accentColor.opacity(0.45)

    // Transient feedback and custom overlay surfaces
    static let transientHorizontalPadding: CGFloat = 10
    static let transientVerticalPadding: CGFloat = 6
    static let transientMaxWidth: CGFloat = 260
    static let overlayHorizontalPadding: CGFloat = 10
    static let overlayVerticalPadding: CGFloat = 7
    static let overlayCornerRadius: CGFloat = Size.radiusMd
    static let annotationToolbarHorizontalInset: CGFloat = 10
    static let annotationToolbarCompactInset: CGFloat = 6
    static let annotationToolbarAxisInset: CGFloat = 10
    static let annotationToolbarCornerRadius: CGFloat = 14
    static let annotationToolbarGap: CGFloat = 6
}

struct PopoverMenuItemStyle: ViewModifier {
    let isSelected: Bool

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: .infinity,
                minHeight: PopoverTokens.menuItemMinHeight,
                alignment: .leading,
            )
            .padding(.horizontal, PopoverTokens.menuItemHorizontalPadding)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: PopoverTokens.controlCornerRadius, style: .continuous)
                    .fill(isSelected ? PopoverTokens.selectedFill : isHovering ? PopoverTokens.hoverFill : .clear),
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: PopoverTokens.controlCornerRadius, style: .continuous)
                        .strokeBorder(PopoverTokens.selectedStroke, lineWidth: Size.strokeDefault)
                }
            }
            .onHover { isHovering = $0 }
    }
}

// MARK: - Typography

enum Typography {
    static let labelSmall: Font = .system(size: 10)
    static let labelMedium: Font = .system(size: 11, weight: .medium)
    static let sectionHeader: Font = .system(size: 11, weight: .semibold)
    static let body: Font = .system(size: 12)
}

// MARK: - Toolbar Item Style

struct ToolbarButton: View {
    let icon: String
    var selectedIcon: String?
    let isSelected: Bool
    var highlightColor: Color = .primary
    var selectedForegroundColor: Color?
    var selectedBadgeIcon: String?

    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: displayedIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor),
                )
                .overlay(alignment: .topTrailing) {
                    if let selectedBadgeIcon, isSelected {
                        Image(systemName: selectedBadgeIcon)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(highlightColor)
                            .frame(width: 12, height: 12)
                            .background(Circle().fill(Color.white))
                            .offset(x: 3, y: -3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? NotinhasL10n.selected : "")
        .onHover { isHovering = $0 }
    }

    private var backgroundColor: Color {
        if isSelected {
            return highlightColor.opacity(0.3)
        } else if isHovering {
            return Color.primary.opacity(0.1)
        }
        return Color.clear
    }

    private var displayedIcon: String {
        if isSelected {
            return selectedIcon ?? icon
        }
        return icon
    }

    private var foregroundColor: Color {
        if isSelected {
            return selectedForegroundColor ?? highlightColor
        }
        return .primary
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }
}

// MARK: - Colors (Semantic)

enum SidebarColors {
    // Backgrounds
    static let itemDefault = Color.primary.opacity(0.05)
    static let itemHover = Color.primary.opacity(0.10)
    static let itemSelected = Color.accentColor.opacity(0.15)

    // Borders
    static let borderDefault = Color.secondary.opacity(0.3)
    static let borderHover = Color.secondary.opacity(0.5)
    static let borderSelected = Color.accentColor

    // Text
    static let labelPrimary = Color.primary
    static let labelSecondary = Color.secondary
    static let labelTertiary = Color.secondary.opacity(0.7)

    // Actions
    static let actionButton = Color.primary.opacity(0.08)
    static let actionButtonHover = Color.primary.opacity(0.15)
}

// MARK: - Grid Configuration

enum GridConfig {
    static let backgroundColumns = 6
    static let colorColumns = 8
    static let gap = Spacing.sm
}

// MARK: - Sidebar Item Style Modifier

struct SidebarItemStyle: ViewModifier {
    let isSelected: Bool
    let cornerRadius: CGFloat

    @State private var isHovering = false

    init(isSelected: Bool, cornerRadius: CGFloat = Size.radiusMd) {
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovering && !isSelected ? SidebarColors.itemHover.opacity(0.35) : Color.clear),
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: Size.strokeSelected),
            )
            .onHover { isHovering = $0 }
    }

    private var borderColor: Color {
        if isSelected {
            return SidebarColors.borderSelected
        }
        if isHovering {
            return SidebarColors.borderHover
        }
        return .clear
    }
}

// MARK: - Color Swatch Style Modifier

struct ColorSwatchStyle: ViewModifier {
    let isSelected: Bool

    @State private var isHovering = false

    init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    func body(content: Content) -> some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth),
            )
            .scaleEffect(isHovering && !isSelected ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { isHovering = $0 }
    }

    private var borderColor: Color {
        if isSelected {
            return SidebarColors.borderSelected
        }
        if isHovering {
            return SidebarColors.borderHover
        }
        return Color.secondary.opacity(0.3)
    }

    private var borderWidth: CGFloat {
        isSelected ? Size.strokeSelected : Size.strokeDefault
    }
}

// MARK: - Action Button Style (for + buttons)

struct ActionButtonStyle: ViewModifier {
    let cornerRadius: CGFloat

    @State private var isHovering = false

    init(cornerRadius: CGFloat = Size.radiusMd) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovering ? SidebarColors.actionButtonHover : SidebarColors.actionButton),
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(isHovering ? .primary.opacity(0.5) : .primary.opacity(0.3)),
            )
            .onHover { isHovering = $0 }
    }
}

// MARK: - View Extensions

extension View {
    func popoverMenuItem(isSelected: Bool = false) -> some View {
        modifier(PopoverMenuItemStyle(isSelected: isSelected))
    }

    func sidebarItemStyle(isSelected: Bool, cornerRadius: CGFloat = Size.radiusMd) -> some View {
        modifier(SidebarItemStyle(isSelected: isSelected, cornerRadius: cornerRadius))
    }

    func colorSwatchStyle(isSelected: Bool) -> some View {
        modifier(ColorSwatchStyle(isSelected: isSelected))
    }

    func actionButtonStyle(cornerRadius: CGFloat = Size.radiusMd) -> some View {
        modifier(ActionButtonStyle(cornerRadius: cornerRadius))
    }
}

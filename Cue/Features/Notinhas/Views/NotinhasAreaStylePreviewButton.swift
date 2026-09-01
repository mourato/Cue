//
//  NotinhasAreaStylePreviewButton.swift
//  Notinhas
//
//  Compact visual previews for Notinhas area fill styles.
//

import SwiftUI

/// Glyph-only preview of an area/shape fill style (no button chrome).
struct NotinhasAreaStylePreview: View {
    let style: NotinhasAreaStyle
    let color: Color
    var width: CGFloat = 18
    var height: CGFloat = 14

    var body: some View {
        let rect = RoundedRectangle(cornerRadius: 2, style: .continuous)
        Group {
            switch style {
            case .outline:
                rect
                    .stroke(color, lineWidth: 2)
            case .solid:
                ZStack {
                    rect.fill(color)
                    rect.stroke(color, lineWidth: 1.5)
                }
            case .tinted:
                ZStack {
                    rect.fill(color.opacity(0.22))
                    rect.stroke(color, lineWidth: 1.5)
                }
            case .hatched:
                ZStack {
                    rect.stroke(color, lineWidth: 1.5)
                    NotinhasHatchPreview(color: color)
                        .clipShape(rect)
                }
            }
        }
        .frame(width: width, height: height)
    }
}

struct NotinhasAreaStylePreviewButton: View {
    let style: NotinhasAreaStyle
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NotinhasAreaStylePreview(style: style, color: color)
                .frame(width: 28, height: 22)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06)),
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.12),
                            lineWidth: 1,
                        )
                }
        }
        .buttonStyle(.plain)
        .help(style.localizedName)
        .accessibilityLabel(style.localizedName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? NotinhasL10n.selected : "")
    }
}

private struct NotinhasHatchPreview: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 3.5
            var offset: CGFloat = -size.height
            while offset < size.width + size.height {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                offset += spacing
            }
            context.stroke(path, with: .color(color.opacity(0.55)), lineWidth: 1)
        }
    }
}

extension AnnotationShapeFillStyle {
    var localizedName: String {
        switch self {
        case .outline:
            NotinhasL10n.areaStyleOutline
        case .solid:
            L10n.AnnotateUI.shapeStyleSolid
        case .tinted:
            NotinhasL10n.areaStyleTinted
        case .hatched:
            NotinhasL10n.areaStyleHatched
        }
    }
}

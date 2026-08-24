//
//  AnnotationStrokeWidthPicker.swift
//  Notinhas
//
//  Segmented stroke-width picker with Screendrop-style sized dots.
//

import SwiftUI

/// Discrete stroke-width control: one segment per `AnnotationStrokeWidth` preset.
struct AnnotationStrokeWidthPicker: View {
    @Binding var value: CGFloat
    var controlHeight: CGFloat = 24
    var onSelect: ((CGFloat) -> Void)?

    private var selection: AnnotationStrokeWidth {
        AnnotationStrokeWidth.nearest(to: value)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnnotationStrokeWidth.allCases) { width in
                segment(for: width)
            }
        }
        .padding(2)
        .frame(height: controlHeight)
        .background(
            RoundedRectangle(cornerRadius: Size.radiusSm, style: .continuous)
                .fill(SidebarColors.itemDefault),
        )
        .overlay(
            RoundedRectangle(cornerRadius: Size.radiusSm, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: Size.strokeDefault),
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Common.stroke)
    }

    private func segment(for width: AnnotationStrokeWidth) -> some View {
        let isSelected = selection == width
        let segmentRadius = Size.radiusSm - 2

        return Button {
            let points = width.points
            value = points
            onSelect?(points)
        } label: {
            Circle()
                .fill(isSelected ? Color.primary : Color.secondary.opacity(0.55))
                .frame(width: dotDiameter(for: width), height: dotDiameter(for: width))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: segmentRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: segmentRadius, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: segmentRadius, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: Size.strokeDefault)
                    }
                }
        }
        .help(L10n.Common.strokeWidthOption(Int(width.points)))
        .accessibilityLabel(L10n.Common.strokeWidthOption(Int(width.points)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? L10n.Notinhas.selected : "")
    }

    private func dotDiameter(for width: AnnotationStrokeWidth) -> CGFloat {
        min(width.points + 2, 13)
    }
}

//
//  AnnotateAnnotationPropertiesSection.swift
//  Notinhas
//
//  Sidebar section for editing selected annotation properties
//

import SwiftUI

/// Property editing section for selected annotations
struct AnnotationPropertiesSection: View {
    @ObservedObject var state: AnnotateState

    private var annotation: AnnotationItem? {
        state.selectedAnnotation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SidebarSectionHeader(title: L10n.AnnotateUI.annotation)

            // Stroke color
            strokeColorPicker

            // Stroke width (for non-text)
            if !isTextAnnotation {
                strokeWidthSlider
            }

            if isMagnifyAnnotation {
                magnificationSlider
            }

            // Shape fill style (rectangle / circle)
            if supportsShapeFillStyle {
                shapeFillStylePicker
            }
        }
    }

    // MARK: - Computed Properties

    private var isTextAnnotation: Bool {
        guard let ann = annotation else { return false }
        if case .text = ann.type {
            return true
        }
        return false
    }

    private var isMagnifyAnnotation: Bool {
        guard let ann = annotation else { return false }
        if case .magnify = ann.type {
            return true
        }
        return false
    }

    private var supportsShapeFillStyle: Bool {
        guard let ann = annotation else { return false }
        switch ann.type {
        case .rectangle, .circle: return true
        default: return false
        }
    }

    // MARK: - Subviews

    private var strokeColorPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Common.color)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            ColorPickerRow(
                selectedColor: strokeColorBinding,
                colors: AnnotateBuiltInColorPalette.annotationColors,
            )
        }
    }

    private var strokeWidthSlider: some View {
        CompactSliderRow(
            label: L10n.Common.stroke,
            value: strokeWidthBinding,
            range: 1 ... 20,
        )
    }

    private var magnificationSlider: some View {
        CompactSliderRow(
            label: L10n.AnnotateUI.magnifyZoom,
            value: magnificationBinding,
            range: AnnotationProperties.magnificationRange,
        )
    }

    private var shapeFillStylePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.AnnotateUI.shapeStyle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(AnnotationShapeFillStyle.allCases) { style in
                    NotinhasAreaStylePreviewButton(
                        style: style,
                        isSelected: annotation?.properties.shapeFillStyle == style,
                        color: annotation?.properties.strokeColor ?? .red,
                        action: {
                            guard let id = state.selectedAnnotationId else { return }
                            state.updateAnnotationProperties(
                                id: id,
                                shapeFillStyle: style,
                                recordsUndo: true,
                            )
                        },
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Bindings

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { annotation?.properties.strokeColor ?? .red },
            set: { newColor in
                guard let id = state.selectedAnnotationId else { return }
                state.updateAnnotationPrimaryColor(id: id, color: newColor, recordsUndo: true)
            },
        )
    }

    private var strokeWidthBinding: Binding<CGFloat> {
        Binding(
            get: { annotation?.properties.strokeWidth ?? 3 },
            set: { newWidth in
                guard let id = state.selectedAnnotationId else { return }
                state.updateAnnotationProperties(id: id, strokeWidth: newWidth, recordsUndo: true)
            },
        )
    }

    private var magnificationBinding: Binding<CGFloat> {
        Binding(
            get: { annotation?.properties.magnification ?? MagnifyGeometry.defaultMagnification },
            set: { newMagnification in
                guard let id = state.selectedAnnotationId else { return }
                state.updateAnnotationProperties(id: id, magnification: newMagnification, recordsUndo: true)
            },
        )
    }
}

// MARK: - Supporting Views

struct ColorPickerRow: View {
    @Binding var selectedColor: Color
    let colors: [Color]

    @ObservedObject private var paletteStore = AnnotateColorPaletteStore.shared
    @State private var draftCustomColor = Color.red

    private let columns = Array(repeating: GridItem(.fixed(20), spacing: 4), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        colorSwatch(color)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(paletteStore.customColors, id: \.self) { color in
                    AnnotateColorSwatchButton(
                        color: color,
                        isSelected: AnnotateColorPaletteStore.colorsMatch(selectedColor, color),
                        size: 20,
                        onDelete: {
                            paletteStore.removeColor(color)
                        },
                    ) {
                        selectedColor = color
                    }
                }

                AnnotateCustomColorPickerControl(
                    selectedColor: $selectedColor,
                    draftColor: $draftCustomColor,
                    swatchSize: 20,
                )
            }
        }
    }

    private func colorSwatch(_ color: Color) -> some View {
        ZStack {
            if AnnotateColorPaletteStore.isClear(color) {
                // Show "none" indicator for clear
                Circle()
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    .frame(width: 20, height: 20)
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(
                                AnnotateColorPaletteStore.colorsMatch(selectedColor, color) ? Color.accentColor : Color
                                    .secondary
                                    .opacity(0.5),
                                lineWidth: AnnotateColorPaletteStore.colorsMatch(selectedColor, color) ? 2 : 1,
                            ),
                    )
            }
        }
    }
}

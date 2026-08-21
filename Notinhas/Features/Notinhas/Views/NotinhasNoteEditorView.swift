import SwiftUI

struct NotinhasNoteEditorView: View {
    let displayNumber: Int
    let panelWidth: CGFloat
    let maxPanelHeight: CGFloat
    @Binding var text: String
    @Binding var color: RGBAColor
    @Binding var areaStyle: NotinhasAreaStyle
    @Binding var areaStrokeWidth: CGFloat
    let showsAreaStyle: Bool
    let onCommit: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    var onPanelDragChanged: ((CGSize) -> Void)?
    var onPanelDragEnded: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var showsColorPopover = false

    private let panelShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            noteTextField
            if showsAreaStyle {
                areaStyleControls
                areaStrokeWidthControl
            }
            footer
        }
        .padding(12)
        .frame(width: panelWidth, alignment: .topLeading)
        .frame(maxHeight: maxPanelHeight, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            ZStack {
                panelShape.fill(.regularMaterial)
                panelDragSurface
            }
        }
        .clipShape(panelShape)
        .accessibilityHint(NotinhasL10n.noteEditorDragHint)
        .onAppear { isFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("\(displayNumber)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color.color))
                .allowsHitTesting(false)

            Text(NotinhasL10n.noteEditorTitle)
                .font(.system(size: 13, weight: .semibold))
                .allowsHitTesting(false)

            Spacer(minLength: 0)
                .allowsHitTesting(false)

            colorMenu
        }
    }

    private var noteTextField: some View {
        TextField(NotinhasL10n.noteEditorPlaceholder, text: $text, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3 ... 6)
            .frame(minHeight: 60)
            .focused($isFocused)
            .accessibilityLabel(NotinhasL10n.noteEditorTitle)
            .onSubmit(onCommit)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .overlayTooltip(NotinhasL10n.deleteNote, edge: .above)
            .accessibilityLabel(NotinhasL10n.deleteNote)

            Spacer(minLength: 4)
                .allowsHitTesting(false)

            Button(NotinhasL10n.cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
                .overlayTooltip(NotinhasL10n.cancel, keys: ["esc"], edge: .above)

            Button(NotinhasL10n.save) { onCommit() }
                .keyboardShortcut(.defaultAction)
                .overlayTooltip(NotinhasL10n.save, keys: ["⌘", "⏎"], edge: .above)
        }
    }

    /// Full-panel drag surface behind content. Non-interactive labels use hit-test passthrough
    /// so padding, gaps, and chrome drag; TextField, Menu, buttons, and slider stay on top.
    private var panelDragSurface: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(panelDragGesture)
            .accessibilityHidden(true)
    }

    private var panelDragGesture: some Gesture {
        // Measure in global space: the panel moves itself via `.offset`, so a `.local`
        // gesture would report translation relative to the moving frame and feed back
        // into the offset each frame, making the box tremble while dragging.
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                onPanelDragChanged?(value.translation)
            }
            .onEnded { _ in
                onPanelDragEnded?()
            }
    }

    private var colorMenu: some View {
        Button {
            showsColorPopover.toggle()
        } label: {
            Image(nsImage: NotinhasPaletteColor.makeSwatchImage(color: color.nsColor, diameter: 18))
                .resizable()
                .frame(width: 18, height: 18)
                .frame(width: 28, height: 22)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06)),
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(NotinhasL10n.noteEditorColorButton)
        .accessibilityValue(
            AnnotateBuiltInColorPalette.annotationEntries
                .first { AnnotateColorPaletteStore.colorsMatch($0.color, color.color) }?
                .accessibilityName
                ?? NotinhasPaletteColor.matching(color)?.localizedName
                ?? NotinhasL10n.selected,
        )
        .popover(isPresented: $showsColorPopover, arrowEdge: .bottom) {
            ColorPickerRow(
                selectedColor: colorBinding,
                colors: AnnotateBuiltInColorPalette.annotationColors,
            )
            .padding(12)
            .frame(width: 220)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { color.color },
            set: { newColor in
                guard let rgba = RGBAColor(color: newColor) else { return }
                color = rgba
            },
        )
    }

    private var areaStyleControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NotinhasL10n.areaStylePickerLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)

            HStack(spacing: 6) {
                ForEach(AnnotationShapeFillStyle.notinhasCases) { style in
                    NotinhasAreaStylePreviewButton(
                        style: style,
                        isSelected: areaStyle == style,
                        color: color.color,
                        action: { areaStyle = style },
                    )
                }
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
        }
    }

    private var areaStrokeWidthControl: some View {
        HStack(spacing: 8) {
            Text(NotinhasL10n.areaStrokeWidthLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            SteppedSliderControl(
                value: $areaStrokeWidth,
                step: 0.5,
                in: NotinhasVisualNote.areaStrokeWidthRange,
            )

            Text(areaStrokeWidthLabel)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NotinhasL10n.areaStrokeWidthLabel)
    }

    private var areaStrokeWidthLabel: String {
        if areaStrokeWidth.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(areaStrokeWidth))
        }
        return String(format: "%.1f", areaStrokeWidth)
    }
}

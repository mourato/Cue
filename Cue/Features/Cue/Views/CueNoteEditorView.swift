import SwiftUI

struct CueNoteEditorView: View {
    let displayNumber: Int
    let panelWidth: CGFloat
    let maxPanelHeight: CGFloat
    @Binding var text: String
    @Binding var color: RGBAColor
    @Binding var areaStyle: CueAreaStyle
    @Binding var areaStrokeWidth: CGFloat
    let showsAreaStyle: Bool
    let onCommit: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    var onPanelDragChanged: ((CGSize) -> Void)?
    var onPanelDragEnded: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var showsColorPopover = false
    @State private var showsStylePopover = false
    @State private var showsStrokeWidthPopover = false

    private let panelShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            noteTextField
            footer
        }
        .padding(PopoverTokens.panelContentInset)
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
        .accessibilityHint(CueL10n.noteEditorDragHint)
        .onAppear { isFocused = true }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("\(displayNumber)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color.color))
                .allowsHitTesting(false)

            Text(CueL10n.noteEditorTitle)
                .font(.system(size: 13, weight: .semibold))
                .allowsHitTesting(false)

            Spacer(minLength: 0)
                .allowsHitTesting(false)

            if showsAreaStyle {
                areaStrokeWidthMenu
                areaStyleMenu
            }

            colorMenu
        }
    }

    private var noteTextField: some View {
        TextField(CueL10n.noteEditorPlaceholder, text: $text, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3 ... 6)
            .frame(minHeight: 60)
            .focused($isFocused)
            .accessibilityLabel(CueL10n.noteEditorTitle)
            .onSubmit(onCommit)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .overlayTooltip(CueL10n.deleteNote, edge: .above)
            .accessibilityLabel(CueL10n.deleteNote)

            Spacer(minLength: 4)
                .allowsHitTesting(false)

            Button(CueL10n.cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
                .overlayTooltip(CueL10n.cancel, keys: ["esc"], edge: .above)

            Button(CueL10n.save) { onCommit() }
                .keyboardShortcut(.defaultAction)
                .overlayTooltip(CueL10n.save, keys: ["⌘", "⏎"], edge: .above)
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
            toggleColorPopover()
        } label: {
            compactPopoverTriggerLabel {
                Image(nsImage: CuePaletteColor.makeSwatchImage(color: color.nsColor, diameter: 16))
                    .resizable()
                    .frame(width: 16, height: 16)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CueL10n.noteEditorColorButton)
        .accessibilityValue(
            AnnotateBuiltInColorPalette.annotationEntries
                .first { AnnotateColorPaletteStore.colorsMatch($0.color, color.color) }?
                .accessibilityName
                ?? CuePaletteColor.matching(color)?.localizedName
                ?? CueL10n.selected,
        )
        .popover(isPresented: $showsColorPopover, arrowEdge: .bottom) {
            ColorPickerRow(
                selectedColor: colorBinding,
                colors: AnnotateBuiltInColorPalette.annotationColors,
            )
            .padding(PopoverTokens.panelContentInset)
            .frame(width: PopoverTokens.noteColorPanelWidth)
        }
    }

    private var areaStyleMenu: some View {
        Button {
            toggleStylePopover()
        } label: {
            compactPopoverTriggerLabel {
                CueAreaStylePreview(
                    style: areaStyle,
                    color: color.color,
                    width: 16,
                    height: 12,
                )
            }
        }
        .buttonStyle(.plain)
        .help(CueL10n.areaStylePickerLabel)
        .accessibilityLabel(CueL10n.areaStylePickerLabel)
        .accessibilityValue(areaStyle.localizedName)
        .popover(isPresented: $showsStylePopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: PopoverTokens.panelItemSpacing) {
                Text(CueL10n.areaStylePickerLabel)
                    .font(Typography.labelMedium)
                    .foregroundColor(SidebarColors.labelSecondary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    ForEach(AnnotationShapeFillStyle.notinhasCases) { style in
                        CueAreaStylePreviewButton(
                            style: style,
                            isSelected: areaStyle == style,
                            color: color.color,
                            action: { areaStyle = style },
                        )
                    }
                }
            }
            .padding(PopoverTokens.panelContentInset)
            .frame(minWidth: PopoverTokens.propertyPanelWidth, alignment: .leading)
        }
    }

    private var areaStrokeWidthMenu: some View {
        Button {
            toggleStrokeWidthPopover()
        } label: {
            compactPopoverTriggerLabel {
                Capsule()
                    .fill(Color.primary)
                    .frame(
                        width: 16,
                        height: strokePreviewHeight(for: AnnotationStrokeWidth.nearest(to: areaStrokeWidth)),
                    )
            }
        }
        .buttonStyle(.plain)
        .help(CueL10n.areaStrokeWidthLabel)
        .accessibilityLabel(CueL10n.areaStrokeWidthLabel)
        .accessibilityValue(
            L10n.Common.strokeWidthOption(Int(AnnotationStrokeWidth.nearest(to: areaStrokeWidth).points)),
        )
        .popover(isPresented: $showsStrokeWidthPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: PopoverTokens.panelItemSpacing) {
                Text(CueL10n.areaStrokeWidthLabel)
                    .font(Typography.labelMedium)
                    .foregroundColor(SidebarColors.labelSecondary)
                    .lineLimit(1)

                AnnotationStrokeWidthPicker(value: $areaStrokeWidth)
            }
            .padding(PopoverTokens.panelContentInset)
            .frame(width: PopoverTokens.propertyPanelWidth, alignment: .leading)
        }
    }

    private func compactPopoverTriggerLabel(
        @ViewBuilder content: () -> some View,
    ) -> some View {
        HStack(spacing: 5) {
            content()
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(width: 42, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(SidebarColors.itemDefault),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1),
        )
    }

    private func strokePreviewHeight(for width: AnnotationStrokeWidth) -> CGFloat {
        min(max(width.points, 2), 8)
    }

    private func toggleColorPopover() {
        showsColorPopover.toggle()
        showsStylePopover = false
        showsStrokeWidthPopover = false
    }

    private func toggleStylePopover() {
        showsStylePopover.toggle()
        showsColorPopover = false
        showsStrokeWidthPopover = false
    }

    private func toggleStrokeWidthPopover() {
        showsStrokeWidthPopover.toggle()
        showsColorPopover = false
        showsStylePopover = false
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
}

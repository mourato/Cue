#if CUE_VIDEO_MODULE
//
    //  RecordingAnnotationToolbarView.swift
    //  Notinhas
//
    //  Floating toolbar for annotation tools during recording
    //  Supports horizontal and vertical layouts with tool selection,
    //  color presets, stroke width, clear-mode config, and drag handle
//

    import SwiftUI

    // MARK: - Layout Direction

    enum AnnotationToolbarDirection {
        case horizontal
        case vertical
    }

    // MARK: - Toolbar View

    struct RecordingAnnotationToolbarView: View {
        @ObservedObject var state: RecordingAnnotationState
        @ObservedObject private var shortcutManager = AnnotateShortcutManager.shared
        let direction: AnnotationToolbarDirection

        private let colorPresets: [Color] = [.red, .blue, .green, .yellow, .white]

        var body: some View {
            contentLayout
                .padding(
                    .horizontal,
                    direction == .horizontal
                        ? PopoverTokens.annotationToolbarHorizontalInset
                        : PopoverTokens.annotationToolbarCompactInset,
                )
                .padding(
                    .vertical,
                    direction == .horizontal
                        ? PopoverTokens.annotationToolbarCompactInset
                        : PopoverTokens.annotationToolbarAxisInset,
                )
        }

        // MARK: - Layout

        @ViewBuilder
        private var contentLayout: some View {
            if direction == .horizontal {
                HStack(spacing: ToolbarConstants.itemSpacing) { toolbarContent }
            } else {
                VStack(spacing: ToolbarConstants.itemSpacing) { toolbarContent }
            }
        }

        @ViewBuilder
        private var toolbarContent: some View {
            toolButtons
            divider
            colorPickers
            if state.selectedTool.supportsShapeFillStyle {
                divider
                shapeFillStylePickers
            }
            divider
            widthPickers
            divider
            clearButton
            clearModeButton
        }

        // MARK: - Tool Buttons

        @ViewBuilder
        private var toolButtons: some View {
            let tools = RecordingAnnotationState.availableTools
            ForEach(tools, id: \.self) { tool in
                AnnotationToolbarIconButton(
                    systemName: tool.icon,
                    isSelected: state.selectedTool == tool,
                    action: { state.selectedTool = tool },
                )
                .overlay(alignment: .bottomTrailing) {
                    if state.isShortcutModeActive, let shortcutLabel = shortcutLabel(for: tool) {
                        Text(shortcutLabel)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor),
                            )
                            .offset(x: 4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: state.isShortcutModeActive)
                .help(shortcutHelpText(for: tool))
            }
        }

        // MARK: - Color Presets

        private var colorPickers: some View {
            ForEach(colorPresets, id: \.self) { color in
                Button {
                    state.strokeColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    state.strokeColor == color ? Color.primary : Color.clear,
                                    lineWidth: 2,
                                ),
                        )
                }
                .buttonStyle(.plain)
            }
        }

        // MARK: - Shape Fill Style

        private var shapeFillStylePickers: some View {
            ForEach(AnnotationShapeFillStyle.allCases) { style in
                CueAreaStylePreviewButton(
                    style: style,
                    isSelected: state.shapeFillStyle == style,
                    color: state.strokeColor,
                    action: { state.shapeFillStyle = style },
                )
            }
        }

        // MARK: - Width Presets

        private var widthPickers: some View {
            ForEach(AnnotationStrokeWidth.allCases) { width in
                Button {
                    state.strokeWidth = width.points
                } label: {
                    Circle()
                        .fill(
                            AnnotationStrokeWidth.nearest(to: state.strokeWidth) == width
                                ? Color.primary
                                : Color.primary.opacity(0.4),
                        )
                        .frame(
                            width: min(width.points + 2, 13),
                            height: min(width.points + 2, 13),
                        )
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(L10n.Common.strokeWidthOption(Int(width.points)))
                .accessibilityLabel(L10n.Common.strokeWidthOption(Int(width.points)))
                .accessibilityAddTraits(
                    AnnotationStrokeWidth.nearest(to: state.strokeWidth) == width ? .isSelected : [],
                )
            }
        }

        // MARK: - Clear & Clear Mode

        private var clearButton: some View {
            AnnotationToolbarIconButton(
                systemName: "trash",
                isSelected: false,
                action: { state.clearAll() },
            )
        }

        private var clearModeButton: some View {
            Menu {
                clearModeMenuContent
            } label: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear),
                    )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28, height: 28)
        }

        @ViewBuilder
        private var clearModeMenuContent: some View {
            let currentTool = state.selectedTool
            let currentMode = state.clearMode(for: currentTool)

            Text(L10n.RecordingAnnotation.autoClear(currentTool.displayName))
                .font(.caption)

            Divider()

            ForEach(RecordingAnnotationState.clearModePresets, id: \.self) { mode in
                Button {
                    state.toolClearModes[currentTool] = mode
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if currentMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        // MARK: - Helpers

        private func shortcutLabel(for tool: AnnotationToolType) -> String? {
            guard shortcutManager.isShortcutEnabled(for: tool),
                  let key = shortcutManager.shortcut(for: tool) else {
                return nil
            }
            return String(key).uppercased()
        }

        private func shortcutHelpText(for tool: AnnotationToolType) -> String {
            guard let shortcutLabel = shortcutLabel(for: tool) else { return tool.displayName }
            return L10n.Common.withShortcut(tool.displayName, shortcutLabel)
        }

        // MARK: - Divider

        @ViewBuilder
        private var divider: some View {
            if direction == .horizontal {
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)
            } else {
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 20, height: 1)
                    .padding(.vertical, 2)
            }
        }
    }
#endif

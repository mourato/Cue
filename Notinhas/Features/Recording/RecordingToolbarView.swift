#if NOTINHAS_VIDEO_MODULE
//
    //  RecordingToolbarView.swift
    //  Notinhas
//
    //  Compact pre-record controls for screen, video, and GIF capture.
//

    import SwiftUI

    struct RecordingToolbarView: View {
        @ObservedObject var state: RecordingToolbarState
        let onRecord: () -> Void
        let onCancel: () -> Void

        var body: some View {
            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    mainControls
                    RecordingToolbarHorizontalDivider()
                    recordingOptions
                }
                .captureFloatingToolbarMaterial()
                outputActions
            }
            .frame(maxWidth: 280)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.RecordingToolbar.toolbarAccessibility)
        }

        private var mainControls: some View {
            HStack(spacing: 0) {
                RecordingToolbarPanelCell {
                    ToolbarIconButton(
                        systemName: "xmark",
                        action: onCancel,
                        accessibilityLabel: L10n.RecordingToolbar.cancelRecording,
                    )
                }

                RecordingToolbarDivider()

                RecordingToolbarPanelCell {
                    ToolbarOptionsMenu(state: state, compact: true)
                }

                RecordingToolbarDivider()

                RecordingDimensionsEditor(state: state)
                    .frame(minWidth: 120, maxWidth: 220, minHeight: 40)

                RecordingToolbarDivider()

                RecordingToolbarPanelCell {
                    ToolbarOutputModeDropdown(state: state)
                }
            }
        }

        private var outputActions: some View {
            VStack(spacing: 4) {
                RecordingOutputActionButton(
                    mode: .gif,
                    state: state,
                    onRecord: onRecord,
                )

                RecordingToolbarHorizontalDivider()

                RecordingOutputActionButton(
                    mode: .video,
                    state: state,
                    onRecord: onRecord,
                )
            }
            .padding(4)
            .captureFloatingToolbarMaterial()
        }

        private var recordingOptions: some View {
            HStack(spacing: 0) {
                RecordingToolbarPanelCell {
                    ToolbarMicToggleButton(state: state)
                }

                RecordingToolbarDivider()

                RecordingToolbarPanelCell {
                    ToolbarSystemAudioToggleButton(state: state)
                }

                if state.outputMode != .gif {
                    RecordingToolbarDivider()

                    RecordingToolbarPanelCell {
                        ToolbarCameraToggleButton(state: state)
                    }
                }

                RecordingToolbarDivider()

                RecordingToolbarPanelCell {
                    RecordingToolbarOverlayToggle(
                        state: state,
                        systemName: "cursorarrow.click.2",
                        title: L10n.RecordingToolbar.highlightClicks,
                        preferenceKey: PreferencesKeys.recordingHighlightClicks,
                        keyPath: \.highlightClicks,
                    )
                }

                RecordingToolbarDivider()

                RecordingToolbarPanelCell {
                    RecordingToolbarOverlayToggle(
                        state: state,
                        systemName: "command.square",
                        title: L10n.RecordingToolbar.showKeystrokes,
                        preferenceKey: PreferencesKeys.recordingShowKeystrokes,
                        keyPath: \.showKeystrokes,
                    )
                }
            }
        }
    }

    private struct RecordingToolbarPanelCell<Content: View>: View {
        @ViewBuilder let content: () -> Content

        var body: some View {
            content()
                .frame(width: 40, height: 40)
        }
    }

    private struct RecordingToolbarHorizontalDivider: View {
        var body: some View {
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, 2)
        }
    }

    private struct RecordingDimensionsEditor: View {
        @ObservedObject var state: RecordingToolbarState
        @FocusState private var focusedField: Field?

        private enum Field: Hashable {
            case width
            case height
        }

        private var isEditable: Bool {
            state.captureMode == .area && !state.isPreparingToRecord
        }

        var body: some View {
            HStack(spacing: 6) {
                dimensionField(
                    accessibilityLabel: L10n.AllInOne.widthFieldAccessibility,
                    text: $state.selectionWidthText,
                    field: .width,
                )

                Text("×")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                dimensionField(
                    accessibilityLabel: L10n.AllInOne.heightFieldAccessibility,
                    text: $state.selectionHeightText,
                    field: .height,
                )
            }
            .opacity(isEditable ? 1 : 0.55)
            .onChange(of: focusedField) { oldField, newField in
                guard newField == nil, let oldField else { return }
                commit(oldField)
            }
        }

        private func dimensionField(
            accessibilityLabel: String,
            text: Binding<String>,
            field: Field,
        ) -> some View {
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .frame(width: 64, height: 28)
                .multilineTextAlignment(.center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08)),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1),
                )
                .focused($focusedField, equals: field)
                .disabled(!isEditable)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(text.wrappedValue)
                .onSubmit { commit(field) }
        }

        private func commit(_ field: Field) {
            guard isEditable else { return }

            guard let width = parsedDimension(state.selectionWidthText),
                  let height = parsedDimension(state.selectionHeightText)
            else {
                state.updateSelectionRect(state.selectionRect)
                return
            }

            let updated = switch field {
            case .width:
                CaptureSelectionGeometry.rectBySettingWidth(
                    state.selectionRect,
                    width: width,
                    aspectLocked: false,
                    aspectRatio: nil,
                )
            case .height:
                CaptureSelectionGeometry.rectBySettingHeight(
                    state.selectionRect,
                    height: height,
                    aspectLocked: false,
                    aspectRatio: nil,
                )
            }

            state.onSelectionRectChanged?(updated)
        }

        private func parsedDimension(_ text: String) -> CGFloat? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Int(trimmed), value > 0 else { return nil }
            return CGFloat(value)
        }
    }

    private struct RecordingToolbarOverlayToggle: View {
        @ObservedObject var state: RecordingToolbarState
        let systemName: String
        let title: String
        let preferenceKey: String
        let keyPath: ReferenceWritableKeyPath<RecordingToolbarState, Bool>

        @State private var isHovered = false

        private var isOn: Bool {
            state[keyPath: keyPath]
        }

        var body: some View {
            Button {
                state[keyPath: keyPath].toggle()
                UserDefaults.standard.set(isOn, forKey: preferenceKey)
            } label: {
                ToolbarIconButtonLabel(
                    systemName: systemName,
                    isActive: isOn,
                    isHovered: isHovered,
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help(title)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? L10n.Common.on : L10n.Common.off)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }

    private struct RecordingOutputActionButton: View {
        let mode: RecordingOutputMode
        @ObservedObject var state: RecordingToolbarState
        let onRecord: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button {
                guard !state.isPreparingToRecord else { return }
                state.outputMode = mode
                UserDefaults.standard.set(mode.rawValue, forKey: PreferencesKeys.recordingOutputMode)
                state.onOutputModeChanged?(mode)
                onRecord()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: mode == .gif ? "photo.on.rectangle" : "video")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)

                    HStack(spacing: 4) {
                        Text(L10n.RecordingToolbar.record)
                        Text(mode.displayName)
                    }
                    .font(.system(size: 14, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .frame(minHeight: 32, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(isHovered ? 0.1 : 0)),
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .disabled(state.isPreparingToRecord)
            .accessibilityLabel(L10n.RecordingToolbar.startRecordingAs(mode.displayName))
            .accessibilityHint(L10n.RecordingToolbar.startRecordingHint)
        }
    }

    #Preview {
        RecordingToolbarView(
            state: RecordingToolbarState(),
            onRecord: {},
            onCancel: {},
        )
        .padding()
    }
#endif

#if NOTINHAS_VIDEO_MODULE
//
    //  ToolbarOptionsMenu.swift
    //  Notinhas
//
    //  Options text button with popover for recording toolbar settings
    //  Styled to match Apple's native macOS recording toolbar ("Options▾")
//

    import SwiftUI

    struct ToolbarOptionsMenu: View {
        @ObservedObject var state: RecordingToolbarState
        var compact = false

        @State private var isHovered = false
        @State private var showPopover = false

        var body: some View {
            Button {
                showPopover.toggle()
            } label: {
                if compact {
                    ToolbarIconButtonLabel(
                        systemName: "slider.horizontal.3",
                        isHovered: isHovered || showPopover,
                    )
                } else {
                    HStack(spacing: 2) {
                        Text(L10n.RecordingToolbar.options)
                            .font(.system(size: 13, weight: .regular))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
                            .fill(Color.primary.opacity(isHovered || showPopover ? 0.1 : 0)),
                    )
                    .contentShape(RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius))
                    .animation(ToolbarConstants.hoverAnimation, value: isHovered)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                ToolbarOptionsPopoverContent(state: state)
            }
            .accessibilityLabel(L10n.RecordingToolbar.recordingOptionsAccessibility)
            .accessibilityHint(L10n.RecordingToolbar.recordingOptionsHint)
        }
    }

    // MARK: - Popover Content

    private struct ToolbarOptionsPopoverContent: View {
        @ObservedObject var state: RecordingToolbarState

        var body: some View {
            VStack(alignment: .leading, spacing: PopoverTokens.panelSectionSpacing) {
                // Header
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                    Text(L10n.RecordingToolbar.settingsTitle)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }

                Divider()

                // Format Section
                SettingsSection(title: L10n.RecordingToolbar.formatSection, icon: "film") {
                    HStack(spacing: PopoverTokens.controlSpacing) {
                        ForEach(VideoFormat.allCases, id: \.self) { format in
                            OptionPill(
                                title: format.displayName,
                                isSelected: state.selectedFormat == format,
                            ) {
                                state.selectedFormat = format
                            }
                        }
                    }
                }

                // Quality Section
                SettingsSection(title: L10n.RecordingToolbar.qualitySection, icon: "sparkles") {
                    HStack(spacing: PopoverTokens.controlSpacing) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            OptionPill(
                                title: quality.displayName,
                                isSelected: state.selectedQuality == quality,
                            ) {
                                state.selectedQuality = quality
                            }
                        }
                    }
                }

                Divider()

                // Overlays Section
                SettingsSection(title: L10n.RecordingToolbar.overlaysSection, icon: "square.stack.3d.up") {
                    RightAlignedToggleRow(
                        title: L10n.RecordingToolbar.showCursor,
                        isOn: Binding(
                            get: { state.showCursor },
                            set: { newValue in
                                state.showCursor = newValue
                                UserDefaults.standard.set(newValue, forKey: PreferencesKeys.recordingShowCursor)
                            },
                        ),
                    )
                }
            }
            .padding(PopoverTokens.panelContentInset)
            .frame(width: PopoverTokens.settingsPanelWidth)
        }
    }

    // MARK: - Settings Section

    private struct SettingsSection<Content: View>: View {
        let title: String
        let icon: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: PopoverTokens.panelItemSpacing) {
                HStack(spacing: PopoverTokens.controlSpacing) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct RightAlignedToggleRow: View {
        let title: String
        let isOn: Binding<Bool>

        var body: some View {
            HStack(spacing: PopoverTokens.panelItemSpacing) {
                Text(title)
                    .font(.system(size: 11))
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Option Pill

    private struct OptionPill: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .padding(.horizontal, PopoverTokens.controlHorizontalPadding)
                    .padding(.vertical, PopoverTokens.controlVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: PopoverTokens.controlCornerRadius)
                            .fill(isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.1 : 0.05)),
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
    }

    #Preview {
        ToolbarOptionsMenu(state: RecordingToolbarState())
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    #Preview("Popover Content") {
        ToolbarOptionsPopoverContent(state: RecordingToolbarState())
            .background(Color(NSColor.windowBackgroundColor))
    }
#endif

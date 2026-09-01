#if CUE_VIDEO_MODULE
//
    //  RecordingToolbarCaptureAreaToggle.swift
    //  Notinhas
//
    //  Compact capture-mode menu for the pre-record toolbar.
//

    import SwiftUI

    enum RecordingCaptureMode: String, CaseIterable {
        case area
        case fullscreen
        case application

        var iconName: String {
            switch self {
            case .area: "rectangle.dashed"
            case .fullscreen: "arrow.up.left.and.arrow.down.right"
            case .application: "square.on.square"
            }
        }

        var displayName: String {
            switch self {
            case .area: L10n.RecordingToolbar.areaSelection
            case .fullscreen: L10n.RecordingToolbar.fullscreenCapture
            case .application: L10n.PreferencesShortcuts.applicationRecordingTitle
            }
        }
    }

    struct ToolbarCaptureAreaToggle: View {
        @ObservedObject var state: RecordingToolbarState
        @State private var isHovered = false
        @State private var showPopover = false

        var body: some View {
            Button {
                showPopover.toggle()
            } label: {
                ToolbarIconButtonLabel(
                    systemName: state.captureMode.iconName,
                    isHovered: isHovered || showPopover,
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                captureModePopover
            }
            .help(state.captureMode.displayName)
            .accessibilityLabel(state.captureMode.displayName)
            .accessibilityValue(state.captureMode.displayName)
        }

        private var captureModePopover: some View {
            VStack(alignment: .leading, spacing: PopoverTokens.menuItemSpacing) {
                ForEach(RecordingCaptureMode.allCases, id: \.self) { mode in
                    Button {
                        state.captureMode = mode
                        state.onCaptureModeChanged?(mode)
                        showPopover = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.iconName)
                                .frame(width: 18)

                            Text(mode.displayName)

                            Spacer()

                            if state.captureMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .popoverMenuItem(isSelected: state.captureMode == mode)
                    .accessibilityAddTraits(state.captureMode == mode ? .isSelected : [])
                }
            }
            .padding(PopoverTokens.menuContentInset)
            .frame(width: PopoverTokens.deviceMenuWidth)
        }
    }

    #Preview {
        ToolbarCaptureAreaToggle(state: RecordingToolbarState())
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
#endif

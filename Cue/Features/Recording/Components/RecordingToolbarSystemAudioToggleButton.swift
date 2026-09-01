#if CUE_VIDEO_MODULE
//
    //  ToolbarSystemAudioToggleButton.swift
    //  Notinhas
//
    //  System audio quick toggle for the recording toolbar
    //  Styled to match Apple's native macOS recording toolbar
//

    import SwiftUI

    struct ToolbarSystemAudioToggleButton: View {
        @ObservedObject var state: RecordingToolbarState
        @State private var isHovered = false

        private let speakerIconSize = ToolbarConstants.iconSize - 1

        private var systemName: String {
            state.captureAudio ? "speaker.wave.2.fill" : "speaker.slash.fill"
        }

        private var statusText: String {
            state.captureAudio ? L10n.Common.on : L10n.Common.off
        }

        private var helpText: String {
            "\(L10n.RecordingToolbar.systemAudio): \(statusText)"
        }

        var body: some View {
            Button {
                state.captureAudio.toggle()
            } label: {
                ToolbarIconButtonLabel(
                    systemName: systemName,
                    iconSize: speakerIconSize,
                    isActive: state.captureAudio,
                    isHovered: isHovered,
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help(helpText)
            .accessibilityLabel(L10n.RecordingToolbar.systemAudio)
            .accessibilityValue(statusText)
            .accessibilityAddTraits(state.captureAudio ? .isSelected : [])
        }
    }

    #Preview {
        HStack(spacing: 4) {
            ToolbarSystemAudioToggleButton(state: RecordingToolbarState())
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
#endif

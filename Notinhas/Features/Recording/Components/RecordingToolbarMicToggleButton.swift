#if NOTINHAS_VIDEO_MODULE
//
    //  ToolbarMicToggleButton.swift
    //  Notinhas
//
    //  Microphone input device button for the recording toolbar
    //  Styled to match Apple's native macOS recording toolbar
//

    import AVFoundation
    import SwiftUI

    struct ToolbarMicToggleButton: View {
        @ObservedObject var state: RecordingToolbarState
        @State private var isHovered = false
        @State private var showPermissionDeniedAlert = false
        @State private var showPopover = false

        private var systemName: String {
            state.captureMicrophone ? "mic.fill" : "mic.slash.fill"
        }

        private var accessibilityLabel: String {
            L10n.Microphone.options
        }

        private var tooltipText: String {
            state.captureMicrophone ? L10n.Microphone.on : L10n.Microphone.off
        }

        var body: some View {
            Button {
                showPopover.toggle()
            } label: {
                ToolbarIconButtonLabel(
                    systemName: systemName,
                    isActive: state.captureMicrophone,
                    isHovered: isHovered || showPopover,
                )
            }
            .buttonStyle(.plain)
            .frame(
                width: ToolbarConstants.iconButtonSize,
                height: ToolbarConstants.iconButtonSize,
            )
            .onHover { isHovered = $0 }
            .help(tooltipText)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(tooltipText)
            .accessibilityAddTraits(state.captureMicrophone ? .isSelected : [])
            .accessibilityHint(L10n.Microphone.chooseInput)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                microphonePopoverContent
            }
            .alert(L10n.Microphone.accessRequiredTitle, isPresented: $showPermissionDeniedAlert) {
                Button(L10n.Common.openSystemSettings) {
                    openMicrophoneSettings()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Microphone.preferencesMessage)
            }
        }

        private var microphonePopoverContent: some View {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    selectNoMicrophone()
                    showPopover = false
                } label: {
                    menuItemLabel(
                        title: L10n.Microphone.doNotUse,
                        isSelected: !state.captureMicrophone,
                    )
                }
                .buttonStyle(.borderless)

                Divider()

                ForEach(microphoneMenuDevices) { device in
                    Button {
                        selectMicrophoneDevice(device)
                        showPopover = false
                    } label: {
                        menuItemLabel(
                            title: device.displayName,
                            isSelected: state.captureMicrophone && state.microphoneDeviceID == device.id,
                        )
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .frame(minWidth: 180)
        }

        private var microphoneMenuDevices: [RecordingMicrophoneDevice] {
            RecordingMicrophoneDeviceProvider.availableDevices(
                selectedDeviceID: state.microphoneDeviceID,
            )
            .filter { !$0.isUnavailable }
        }

        @ViewBuilder
        private func menuItemLabel(title: String, isSelected: Bool) -> some View {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }

        private func selectNoMicrophone() {
            state.captureMicrophone = false
        }

        private func selectMicrophoneDevice(_ device: RecordingMicrophoneDevice) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)

            switch status {
            case .notDetermined:
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .audio)
                    await MainActor.run {
                        if granted {
                            enableMicrophone(device)
                        } else {
                            showPermissionDeniedAlert = true
                        }
                    }
                }
            case .authorized:
                enableMicrophone(device)
            case .denied, .restricted:
                showPermissionDeniedAlert = true
            @unknown default:
                enableMicrophone(device)
            }
        }

        private func enableMicrophone(_ device: RecordingMicrophoneDevice) {
            state.microphoneDeviceID = device.id
            state.captureMicrophone = true
            UserDefaults.standard.set(device.id, forKey: PreferencesKeys.recordingMicrophoneDeviceID)
        }

        private func openMicrophoneSettings() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    #Preview {
        HStack(spacing: 4) {
            ToolbarMicToggleButton(state: RecordingToolbarState())
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
#endif

#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    import SwiftUI

    struct ToolbarCameraToggleButton: View {
        @ObservedObject var state: RecordingToolbarState
        @State private var isHovered = false
        @State private var permissionDenied = false
        @State private var showPopover = false

        private var systemName: String {
            state.captureCamera ? "video.fill" : "video.slash.fill"
        }

        private var statusText: String {
            state.captureCamera ? L10n.Camera.on : L10n.Camera.off
        }

        var body: some View {
            Button {
                showPopover.toggle()
            } label: {
                ToolbarIconButtonLabel(
                    systemName: systemName,
                    isActive: state.captureCamera,
                    isHovered: isHovered || showPopover,
                )
            }
            .buttonStyle(.plain)
            .frame(
                width: ToolbarConstants.iconButtonSize,
                height: ToolbarConstants.iconButtonSize,
            )
            .accessibilityLabel(L10n.Camera.options)
            .accessibilityValue(statusText)
            .accessibilityAddTraits(state.captureCamera ? .isSelected : [])
            .onHover { isHovered = $0 }
            .help(statusText)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                cameraPopoverContent
            }
            .onChange(of: state.captureCamera) { enabled in
                guard enabled else {
                    state.onCaptureCameraChanged?(false)
                    return
                }
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .notDetermined:
                    Task { @MainActor in
                        if await AVCaptureDevice.requestAccess(for: .video) {
                            state.onCaptureCameraChanged?(true)
                        } else {
                            state.captureCamera = false
                            permissionDenied = true
                        }
                    }
                case .denied, .restricted:
                    state.captureCamera = false
                    permissionDenied = true
                case .authorized:
                    state.onCaptureCameraChanged?(true)
                @unknown default:
                    break
                }
            }
            .alert(L10n.Camera.accessRequiredTitle, isPresented: $permissionDenied) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Common.openSystemSettings) {
                    NSWorkspace.shared
                        .open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                }
            } message: { Text(L10n.Camera.permissionMessage) }
        }

        private var cameraPopoverContent: some View {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    state.captureCamera = false
                    showPopover = false
                } label: {
                    Label(
                        L10n.Camera.doNotUse,
                        systemImage: state.captureCamera ? "video" : "checkmark",
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)

                Divider()

                ForEach(RecordingCameraDeviceProvider.devices(), id: \.uniqueID) { device in
                    Button {
                        let wasEnabled = state.captureCamera
                        state.cameraDeviceID = device.uniqueID
                        state.captureCamera = true
                        UserDefaults.standard.set(device.uniqueID, forKey: PreferencesKeys.recordingCameraDeviceID)
                        if wasEnabled {
                            state.onCaptureCameraChanged?(true)
                        }
                        showPopover = false
                    } label: {
                        Text(device.localizedName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .frame(minWidth: 180)
        }
    }
#endif

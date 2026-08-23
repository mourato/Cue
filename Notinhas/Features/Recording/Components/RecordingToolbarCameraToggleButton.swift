#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    import SwiftUI

    struct ToolbarCameraToggleButton: View {
        @ObservedObject var state: RecordingToolbarState
        @State private var permissionDenied = false

        var body: some View {
            Menu {
                Button { state.captureCamera = false } label: {
                    Label(L10n.Camera.doNotUse, systemImage: state.captureCamera ? "video" : "checkmark")
                }
                Divider()
                ForEach(RecordingCameraDeviceProvider.devices(), id: \.uniqueID) { device in
                    Button {
                        state.cameraDeviceID = device.uniqueID
                        state.captureCamera = true
                        UserDefaults.standard.set(device.uniqueID, forKey: PreferencesKeys.recordingCameraDeviceID)
                    } label: { Text(device.localizedName) }
                }
            } label: {
                Image(systemName: state.captureCamera ? "video.fill" : "video.slash.fill")
                    .frame(width: ToolbarConstants.iconButtonSize, height: ToolbarConstants.iconButtonSize)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel(L10n.Camera.options)
            .help(state.captureCamera ? L10n.Camera.on : L10n.Camera.off)
            .onChange(of: state.captureCamera) { enabled in
                guard enabled else { return }
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .notDetermined:
                    Task { @MainActor in
                        if await !(AVCaptureDevice.requestAccess(for: .video)) {
                            state.captureCamera = false
                            permissionDenied = true
                        }
                    }
                case .denied, .restricted:
                    state.captureCamera = false
                    permissionDenied = true
                default: break
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
    }
#endif

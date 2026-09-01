#if CUE_VIDEO_MODULE
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
            VStack(alignment: .leading, spacing: PopoverTokens.menuItemSpacing) {
                Button {
                    state.captureCamera = false
                    showPopover = false
                } label: {
                    cameraMenuItemLabel(
                        title: L10n.Camera.doNotUse,
                        isSelected: !state.captureCamera,
                    )
                }
                .buttonStyle(.plain)
                .popoverMenuItem(isSelected: !state.captureCamera)

                Divider()
                    .padding(.vertical, PopoverTokens.menuDividerPadding)

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
                        cameraMenuItemLabel(
                            title: device.localizedName,
                            isSelected: state.captureCamera && state.cameraDeviceID == device.uniqueID,
                        )
                    }
                    .buttonStyle(.plain)
                    .popoverMenuItem(
                        isSelected: state.captureCamera && state.cameraDeviceID == device.uniqueID,
                    )
                }

                if state.captureCamera {
                    Divider()
                        .padding(.vertical, PopoverTokens.menuDividerPadding)
                    previewOptions
                }
            }
            .padding(PopoverTokens.menuContentInset)
            .frame(minWidth: PopoverTokens.deviceMenuWidth)
        }

        private var previewOptions: some View {
            VStack(alignment: .leading, spacing: PopoverTokens.panelItemSpacing) {
                Text(L10n.Camera.previewSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(RecordingCameraPreviewSize.allCases) { size in
                    cameraOptionButton(
                        title: size.displayName,
                        isSelected: state.cameraPreviewSize == size,
                    ) {
                        state.cameraPreviewSize = size
                        state.onCameraPreviewConfigurationChanged?()
                    }
                }

                Divider()
                    .padding(.vertical, PopoverTokens.menuDividerPadding)

                Text(L10n.Camera.previewShape)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(RecordingCameraPreviewShape.allCases) { shape in
                    cameraOptionButton(
                        title: shape.displayName,
                        isSelected: state.cameraPreviewShape == shape,
                    ) {
                        state.cameraPreviewShape = shape
                        state.onCameraPreviewConfigurationChanged?()
                    }
                }

                Divider()
                    .padding(.vertical, PopoverTokens.menuDividerPadding)

                Toggle(
                    L10n.Camera.showDuringRecording,
                    isOn: Binding(
                        get: { state.showCameraPreviewDuringRecording },
                        set: { isVisible in
                            state.showCameraPreviewDuringRecording = isVisible
                            UserDefaults.standard.set(
                                isVisible,
                                forKey: PreferencesKeys.recordingShowCameraPreviewDuringRecording,
                            )
                        },
                    ),
                )
                .accessibilityHint(L10n.Camera.showDuringRecordingDescription)
            }
        }

        private func cameraOptionButton(
            title: String,
            isSelected: Bool,
            action: @escaping () -> Void,
        ) -> some View {
            Button(action: action) {
                HStack {
                    Text(title)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .popoverMenuItem(isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        private func cameraMenuItemLabel(title: String, isSelected: Bool) -> some View {
            HStack(spacing: PopoverTokens.menuItemHorizontalPadding) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 12)
                    .opacity(isSelected ? 1 : 0)

                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
        }
    }
#endif

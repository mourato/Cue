//
//  PreferencesCaptureSettingsView.swift
//  Notinhas
//
//  Capture preferences tab combining screenshot behavior, recording settings, and post-capture actions
//

import AVFoundation
import SwiftUI

private enum CaptureSettingsPane: CaseIterable, Hashable, Identifiable {
    case capture
    #if CUE_VIDEO_MODULE
        case recording
    #endif

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .capture:
            L10n.Preferences.captureTab
        #if CUE_VIDEO_MODULE
            case .recording:
                CaptureType.recording.displayName
        #endif
        }
    }

    static func availablePanes(videoModuleEnabled: Bool) -> [CaptureSettingsPane] {
        #if CUE_VIDEO_MODULE
            videoModuleEnabled ? allCases : [.capture]
        #else
            [.capture]
        #endif
    }
}

struct CaptureSettingsView: View {
    // Screenshot behavior
    @AppStorage(PreferencesKeys.hideDesktopIcons) private var hideDesktopIcons = false
    @AppStorage(PreferencesKeys.hideDesktopWidgets) private var hideDesktopWidgets = false
    @AppStorage(PreferencesKeys.screenshotIncludeOwnApp) private var includeOwnAppInScreenshots = false
    @AppStorage(PreferencesKeys.screenshotShowCursor) private var screenshotShowCursor = false
    @AppStorage(PreferencesKeys.screenshotFreezeArea) private var freezeAreaCapture = false
    @AppStorage(PreferencesKeys.screenshotShowSelectionAreaOverlay) private var showSelectionAreaOverlay = true
    @AppStorage(PreferencesKeys.screenshotReverseMagnifierZoomDirection) private var reverseMagnifierZoomDirection =
        false
    @AppStorage(PreferencesKeys.captureSelectionSnapDistance) private var captureSelectionSnapDistance = Int(
        CaptureSelectionSnappingConfiguration.defaultSnapDistance,
    )
    @AppStorage(PreferencesKeys.captureSelectionColorSensitivity) private var captureSelectionColorSensitivity =
        CaptureSelectionSnappingConfiguration.defaultColorSensitivity
    @AppStorage(PreferencesKeys.captureSelectionShowSnapGuides) private var captureSelectionShowSnapGuides =
        CaptureSelectionSnappingConfiguration.defaultShowSnapGuides

    @AppStorage(PreferencesKeys.screenshotFormat) private var screenshotFormat = "png"
    @AppStorage(PreferencesKeys.scrollingCaptureShowHints) private var scrollingCaptureShowHints = true
    @AppStorage(PreferencesKeys.backgroundCutoutAutoCropEnabled) private var backgroundCutoutAutoCropEnabled = true
    @AppStorage(PreferencesKeys.ocrSuccessNotificationEnabled) private var ocrSuccessNotification = true
    @AppStorage(PreferencesKeys.ocrLinkDetectionEnabled) private var ocrLinkDetection = true
    @AppStorage(PreferencesKeys.screenshotFileNameTemplate)
    private var screenshotFileNameTemplate = CaptureOutputKind.screenshot.defaultTemplate

    #if CUE_VIDEO_MODULE
        /// Recording settings
        @AppStorage(PreferencesKeys.recordingFormat) private var format = "mov"
        @AppStorage(PreferencesKeys.recordingFileNameTemplate)
        private var recordingFileNameTemplate = CaptureOutputKind.recording.defaultTemplate
        @AppStorage(PreferencesKeys.recordingFPS) private var fps = 30
        @AppStorage(PreferencesKeys.recordingQuality) private var quality = "high"
        @AppStorage(PreferencesKeys.recordingMicrophoneDeviceID)
        private var microphoneDeviceID = RecordingMicrophoneDevice.systemDefaultID
        @AppStorage(PreferencesKeys.recordingRememberLastArea) private var rememberLastArea = true
        @AppStorage(PreferencesKeys.recordingIncludeOwnApp) private var includeOwnAppInRecordings = false
        @AppStorage(PreferencesKeys.recordingShowCursor) private var recordingShowCursor = true
        @AppStorage(PreferencesKeys.recordingSmartPointer) private var recordingSmartPointer = false
        @AppStorage(PreferencesKeys.recordingShowCameraPreviewDuringRecording)
        private var recordingShowCameraPreviewDuringRecording = true
        @AppStorage(PreferencesKeys.recordingHoverBarVisible) private var recordingHoverBarVisible = true
        @AppStorage(PreferencesKeys.recordingShowTimeOnMenuBar) private var recordingShowTimeOnMenuBar = true

        @State private var microphoneDevices: [RecordingMicrophoneDevice] = []
    #endif
    @State private var selectedPane: CaptureSettingsPane = .capture
    @State private var videoModuleEnabled = VideoModuleAvailability.isEnabled

    private var availablePanes: [CaptureSettingsPane] {
        CaptureSettingsPane.availablePanes(videoModuleEnabled: videoModuleEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            if availablePanes.count > 1 {
                HStack {
                    Spacer()

                    Picker("", selection: $selectedPane) {
                        ForEach(availablePanes) { pane in
                            Text(pane.title).tag(pane)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 560)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            Form {
                if selectedPane == .capture {
                    Section(L10n.PreferencesCapture.captureEnvironmentSection) {
                        SettingRow(
                            icon: "photo.on.rectangle",
                            title: L10n.PreferencesCapture.includeInScreenshotsTitle,
                            description: L10n.PreferencesCapture.includeInScreenshotsDescription,
                        ) {
                            Toggle("", isOn: $includeOwnAppInScreenshots)
                                .labelsHidden()
                        }

                        #if CUE_VIDEO_MODULE
                            if videoModuleEnabled {
                                SettingRow(
                                    icon: "video",
                                    title: L10n.PreferencesCapture.includeInRecordingsTitle,
                                    description: L10n.PreferencesCapture.includeInRecordingsDescription,
                                ) {
                                    Toggle("", isOn: $includeOwnAppInRecordings)
                                        .labelsHidden()
                                }
                            }
                        #endif

                        SettingRow(
                            icon: "eye.slash",
                            title: L10n.PreferencesCapture.hideDesktopIconsTitle,
                            description: L10n.PreferencesCapture.hideDesktopIconsDescription,
                        ) {
                            Toggle("", isOn: $hideDesktopIcons)
                                .labelsHidden()
                        }

                        SettingRow(
                            icon: "widget.small",
                            title: L10n.PreferencesCapture.hideDesktopWidgetsTitle,
                            description: L10n.PreferencesCapture.hideDesktopWidgetsDescription,
                        ) {
                            Toggle("", isOn: $hideDesktopWidgets)
                                .labelsHidden()
                        }
                    }

                    Section(L10n.PreferencesCapture.selectionSection) {
                        SettingRow(
                            icon: "macwindow",
                            title: L10n.PreferencesCapture.showSelectionAreaOverlayTitle,
                            description: L10n.PreferencesCapture.showSelectionAreaOverlayDescription,
                        ) {
                            Toggle("", isOn: $showSelectionAreaOverlay)
                                .labelsHidden()
                        }

                        SettingRow(
                            icon: "arrow.up.and.down",
                            title: L10n.PreferencesCapture.reverseMagnifierZoomDirectionTitle,
                            description: L10n.PreferencesCapture.reverseMagnifierZoomDirectionDescription,
                        ) {
                            Toggle("", isOn: $reverseMagnifierZoomDirection)
                                .labelsHidden()
                        }

                        SettingRow(
                            icon: "arrow.left.and.right.square",
                            title: L10n.PreferencesCapture.selectionSnapDistanceTitle,
                            description: L10n.PreferencesCapture.selectionSnapDistanceDescription,
                        ) {
                            PreferencesNumericPicker(
                                value: Binding(
                                    get: { Double(captureSelectionSnapDistance) },
                                    set: { captureSelectionSnapDistance = Int($0.rounded()) },
                                ),
                                range: Double(CaptureSelectionSnappingConfiguration.snapDistanceRange.lowerBound)
                                    ... Double(CaptureSelectionSnappingConfiguration.snapDistanceRange.upperBound),
                                presets: [2, 5, 10, 15],
                                step: 1,
                                accessibilityTitle: L10n.PreferencesCapture.selectionSnapDistanceTitle,
                                unit: "px",
                                valueLabel: { "\(Int($0)) px" },
                            )
                        }

                        SettingRow(
                            icon: "eyedropper.halffull",
                            title: L10n.PreferencesCapture.selectionColorSensitivityTitle,
                            description: L10n.PreferencesCapture.selectionColorSensitivityDescription,
                        ) {
                            Picker("", selection: $captureSelectionColorSensitivity) {
                                ForEach(Array(CaptureSelectionSnappingConfiguration.colorSensitivityRange),
                                        id: \.self) { value in
                                    Text(L10n.PreferencesCapture.selectionColorSensitivityLabel(value))
                                        .tag(value)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        SettingRow(
                            icon: "ruler",
                            title: L10n.PreferencesCapture.selectionSnapGuidesTitle,
                            description: L10n.PreferencesCapture.selectionSnapGuidesDescription,
                        ) {
                            Toggle("", isOn: $captureSelectionShowSnapGuides)
                                .labelsHidden()
                        }
                    }

                    PreferencesAllInOneModeCustomizationView(videoModuleEnabled: videoModuleEnabled)

                    Section(L10n.PreferencesCapture.screenshotBehaviorSection) {
                        SettingRow(
                            icon: "snowflake",
                            title: L10n.PreferencesCapture.freezeAreaTitle,
                            description: L10n.PreferencesCapture.freezeAreaDescription,
                        ) {
                            Toggle("", isOn: $freezeAreaCapture)
                                .labelsHidden()
                        }

                        SettingRow(
                            icon: "cursorarrow",
                            title: L10n.PreferencesCapture.showCursorTitle,
                            description: L10n.PreferencesCapture.showCursorDescription,
                        ) {
                            Toggle("", isOn: $screenshotShowCursor)
                                .labelsHidden()
                        }
                    }

                    Section(L10n.PreferencesCapture.specializedCaptureSection) {
                        SettingRow(
                            icon: "lightbulb",
                            title: L10n.PreferencesCapture.showSessionHintsTitle,
                            description: L10n.PreferencesCapture.showSessionHintsDescription,
                        ) {
                            Toggle("", isOn: $scrollingCaptureShowHints)
                                .labelsHidden()
                        }

                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                                .padding(.top, 1)
                            Text(L10n.PreferencesCapture.scrollingCaptureInfo)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)

                        SettingRow(
                            icon: "bell.badge",
                            title: L10n.PreferencesCapture.ocrSuccessNotificationTitle,
                            description: L10n.PreferencesCapture.ocrSuccessNotificationDescription,
                        ) {
                            Toggle("", isOn: $ocrSuccessNotification)
                                .labelsHidden()
                        }

                        SettingRow(
                            icon: "link",
                            title: L10n.PreferencesCapture.ocrLinkDetectionTitle,
                            description: L10n.PreferencesCapture.ocrLinkDetectionDescription,
                        ) {
                            Toggle("", isOn: $ocrLinkDetection)
                                .labelsHidden()
                        }
                    }

                    Section(L10n.PreferencesCapture.outputSection) {
                        SettingRow(
                            icon: "photo",
                            title: L10n.PreferencesCapture.imageFormatTitle,
                            description: L10n.PreferencesCapture.imageFormatDescription,
                        ) {
                            Picker("", selection: $screenshotFormat) {
                                ForEach(ImageFormatOption.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        if screenshotFormat == ImageFormatOption.webp.rawValue {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12))
                                    .padding(.top, 1)
                                Text(L10n.PreferencesCapture.webpWarning)
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }

                        if screenshotFormat == ImageFormatOption.jpeg.rawValue {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                                    .padding(.top, 1)
                                Text(L10n.PreferencesCapture.jpegCutoutNote)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }

                        SettingRow(
                            icon: "textformat",
                            title: L10n.PreferencesCapture.screenshotTemplateTitle,
                            description: L10n.PreferencesCapture.screenshotTemplateDescription,
                        ) {
                            TextField("", text: $screenshotFileNameTemplate)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)
                        }

                        #if CUE_VIDEO_MODULE
                            if videoModuleEnabled {
                                SettingRow(
                                    icon: "textformat.abc",
                                    title: L10n.PreferencesCapture.recordingTemplateTitle,
                                    description: L10n.PreferencesCapture.recordingTemplateDescription,
                                ) {
                                    TextField("", text: $recordingFileNameTemplate)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 260)
                                }
                            }
                        #endif

                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                                .padding(.top, 1)
                            Text(L10n.PreferencesCapture.availableTokens)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.PreferencesCapture.screenshotPreview(screenshotFilenamePreview))
                            #if CUE_VIDEO_MODULE
                                if videoModuleEnabled {
                                    Text(L10n.PreferencesCapture.recordingPreview(recordingFilenamePreview))
                                }
                            #endif
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)

                        HStack {
                            Spacer()
                            Button(L10n.PreferencesCapture.resetNamingDefaults) {
                                resetOutputNamingDefaults()
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                        }
                    }

                    Section(L10n.PreferencesCapture.postProcessingSection) {
                        PreferencesScreenshotDefaultPresetPicker()

                        Text(L10n.PreferencesCapture.removeBackground)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SettingRow(
                            icon: "person.crop.rectangle",
                            title: L10n.PreferencesCapture.autoCropSubjectTitle,
                            description: L10n.PreferencesCapture.autoCropSubjectDescription,
                        ) {
                            Toggle("", isOn: $backgroundCutoutAutoCropEnabled)
                                .labelsHidden()
                        }
                    }

                    Section(L10n.PreferencesCapture.afterCaptureSection) {
                        AfterCaptureMatrixView()
                    }
                }

                // MARK: - Recording

                #if CUE_VIDEO_MODULE
                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.recordingFormatSection) {
                            SettingRow(
                                icon: "film",
                                title: L10n.PreferencesCapture.videoFormatTitle,
                                description: L10n.PreferencesCapture.videoFormatDescription,
                            ) {
                                Picker("", selection: $format) {
                                    Text(verbatim: "MOV").tag("mov")
                                    Text(verbatim: "MP4").tag("mp4")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.recordingQualitySection) {
                            SettingRow(
                                icon: "gauge.with.dots.needle.33percent",
                                title: L10n.PreferencesCapture.frameRateTitle,
                                description: L10n.PreferencesCapture.frameRateDescription,
                            ) {
                                Picker("", selection: $fps) {
                                    Text("30 FPS").tag(30)
                                    Text("60 FPS").tag(60)
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            SettingRow(
                                icon: "sparkles",
                                title: L10n.PreferencesCapture.qualityTitle,
                                description: L10n.PreferencesCapture.qualityDescription,
                            ) {
                                Picker("", selection: $quality) {
                                    ForEach(VideoQuality.allCases, id: \.self) { option in
                                        Text(option.displayName).tag(option.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.recordingBehaviorSection) {
                            SettingRow(
                                icon: "cursorarrow",
                                title: L10n.PreferencesCapture.showCursorTitle,
                                description: L10n.PreferencesCapture.recordingShowCursorDescription,
                            ) {
                                Toggle("", isOn: $recordingShowCursor)
                                    .labelsHidden()
                                    .disabled(recordingSmartPointer)
                            }

                            SettingRow(
                                icon: "cursorarrow.motionlines",
                                title: L10n.PreferencesCapture.recordingSmartPointerTitle,
                                description: L10n.PreferencesCapture.recordingSmartPointerDescription,
                            ) {
                                Toggle("", isOn: $recordingSmartPointer)
                                    .labelsHidden()
                            }

                            SettingRow(
                                icon: "video",
                                title: L10n.Camera.showDuringRecording,
                                description: L10n.Camera.showDuringRecordingDescription,
                            ) {
                                Toggle("", isOn: $recordingShowCameraPreviewDuringRecording)
                                    .labelsHidden()
                            }

                            SettingRow(
                                icon: "rectangle.dashed",
                                title: L10n.PreferencesCapture.rememberLastAreaTitle,
                                description: L10n.PreferencesCapture.rememberLastAreaDescription,
                            ) {
                                Toggle("", isOn: $rememberLastArea)
                                    .labelsHidden()
                            }
                        }
                    }

                    // MARK: - Recording Controls

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.recordingControlsSection) {
                            SettingRow(
                                icon: "menubar.rectangle",
                                title: L10n.PreferencesCapture.hoverBarVisibleTitle,
                                description: L10n.PreferencesCapture.hoverBarVisibleDescription,
                            ) {
                                Toggle("", isOn: $recordingHoverBarVisible)
                                    .labelsHidden()
                            }

                            SettingRow(
                                icon: "timer",
                                title: L10n.PreferencesCapture.menuBarTimeTitle,
                                description: L10n.PreferencesCapture.menuBarTimeDescription,
                            ) {
                                Toggle("", isOn: $recordingShowTimeOnMenuBar)
                                    .labelsHidden()
                            }
                        }
                    }

                    // MARK: - Recording Audio Defaults

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.audioSection) {
                            SettingRow(
                                icon: "mic.badge.plus",
                                title: L10n.PreferencesCapture.microphoneInputTitle,
                                description: L10n.PreferencesCapture.microphoneInputDescription,
                            ) {
                                Picker("", selection: $microphoneDeviceID) {
                                    ForEach(microphoneDevices) { device in
                                        Text(device.displayName).tag(device.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 220)
                            }
                        }
                    }
                #endif
            }
            .formStyle(.grouped)
        }
        .onAppear {
            #if CUE_VIDEO_MODULE
                refreshMicrophoneDevices()
            #endif
            reconcileSelectedPane()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoModuleAvailabilityDidChange)) { _ in
            videoModuleEnabled = VideoModuleAvailability.isEnabled
            reconcileSelectedPane()
        }
    }

    private func reconcileSelectedPane() {
        let available = CaptureSettingsPane.availablePanes(videoModuleEnabled: videoModuleEnabled)
        if !available.contains(selectedPane) {
            selectedPane = available.first ?? .capture
        }
    }

    // MARK: - Helpers

    private var screenshotFilenamePreview: String {
        let sampleContext = CaptureContext(appName: "Safari", windowTitle: "GitHub")
        let baseName = CaptureOutputNaming.resolveTemplateBaseName(
            previewTemplate(screenshotFileNameTemplate, kind: .screenshot),
            kind: .screenshot,
            context: sampleContext,
        )
        return "\(baseName).\(screenshotFileExtension)"
    }

    private var recordingFilenamePreview: String {
        #if CUE_VIDEO_MODULE
            let sampleContext = CaptureContext(appName: "Safari", windowTitle: "GitHub")
            let baseName = CaptureOutputNaming.resolveTemplateBaseName(
                previewTemplate(recordingFileNameTemplate, kind: .recording),
                kind: .recording,
                context: sampleContext,
            )
            return "\(baseName).\(recordingFileExtension)"
        #else
            return ""
        #endif
    }

    private func previewTemplate(_ template: String, kind: CaptureOutputKind) -> String {
        template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? kind.defaultTemplate
            : template
    }

    private var screenshotFileExtension: String {
        ImageFormatOption(rawValue: screenshotFormat)?.format.fileExtension ?? "png"
    }

    private var recordingFileExtension: String {
        #if CUE_VIDEO_MODULE
            VideoFormat(rawValue: format)?.fileExtension ?? "mov"
        #else
            "mov"
        #endif
    }

    #if CUE_VIDEO_MODULE
        private func refreshMicrophoneDevices() {
            microphoneDevices = RecordingMicrophoneDeviceProvider.availableDevices(
                selectedDeviceID: microphoneDeviceID,
            )
        }
    #endif

    // MARK: - Reset Defaults

    private func resetOutputNamingDefaults() {
        screenshotFileNameTemplate = CaptureOutputKind.screenshot.defaultTemplate
        #if CUE_VIDEO_MODULE
            recordingFileNameTemplate = CaptureOutputKind.recording.defaultTemplate
        #endif
    }
}

#Preview {
    CaptureSettingsView()
        .frame(width: 600, height: 550)
}

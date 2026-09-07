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
    // Screenshot behavior & environment
    @AppStorage(PreferencesKeys.screenshotIncludeOwnApp) private var includeOwnAppInScreenshots = false
    @AppStorage(PreferencesKeys.screenshotShowCursor) private var screenshotShowCursor = false
    @AppStorage(PreferencesKeys.screenshotFreezeArea) private var freezeAreaCapture = false
    @AppStorage(PreferencesKeys.captureWindowShadow) private var captureWindowShadow = true
    @AppStorage(PreferencesKeys.screenshotShowSelectionAreaOverlay) private var showSelectionAreaOverlay = true
    @AppStorage(PreferencesKeys.screenshotReverseMagnifierZoomDirection) private var reverseMagnifierZoomDirection =
        false

    // Snapping
    @AppStorage(PreferencesKeys.captureSelectionSnappingEnabled) private var captureSelectionSnappingEnabled = true
    @AppStorage(PreferencesKeys.captureSelectionSnapDistance) private var captureSelectionSnapDistance = Int(
        CaptureSelectionSnappingConfiguration.defaultSnapDistance,
    )
    @AppStorage(PreferencesKeys.captureSelectionColorSensitivity) private var captureSelectionColorSensitivity =
        CaptureSelectionSnappingConfiguration.defaultColorSensitivity
    @AppStorage(PreferencesKeys.captureSelectionShowSnapGuides) private var captureSelectionShowSnapGuides =
        CaptureSelectionSnappingConfiguration.defaultShowSnapGuides
    @State private var showSnappingAdvancedSettings = false

    // Output & Format
    @AppStorage(PreferencesKeys.screenshotFormat) private var screenshotFormat = "png"
    @AppStorage(PreferencesKeys.screenshotJpegQuality) private var screenshotJpegQuality = 0.85
    @AppStorage(PreferencesKeys.screenshotFileNameTemplate)
    private var screenshotFileNameTemplate = CaptureOutputKind.screenshot.defaultTemplate

    // Specialized capture
    @AppStorage(PreferencesKeys.scrollingCaptureShowHints) private var scrollingCaptureShowHints = true
    @AppStorage(PreferencesKeys.backgroundCutoutAutoCropEnabled) private var backgroundCutoutAutoCropEnabled = true
    @AppStorage(PreferencesKeys.ocrSuccessNotificationEnabled) private var ocrSuccessNotification = true
    @AppStorage(PreferencesKeys.ocrLinkDetectionEnabled) private var ocrLinkDetection = true

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
    @State private var isResetScreenshotDefaultsConfirmationPresented = false

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
                    .accessibilityLabel(L10n.Preferences.captureTab)
                    .accessibilityValue(selectedPane.title)
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
                    // MARK: - Output

                    Section(L10n.PreferencesCapture.outputSection) {
                        outputSettings
                    }

                    // MARK: - Capture

                    Section(L10n.PreferencesCapture.captureSection) {
                        SettingRow(
                            icon: "photo.on.rectangle",
                            title: L10n.PreferencesCapture.includeInScreenshotsTitle,
                            description: L10n.PreferencesCapture.includeInScreenshotsDescription,
                        ) {
                            Toggle("", isOn: $includeOwnAppInScreenshots)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.includeInScreenshotsTitle)
                        }

                        SettingRow(
                            icon: "cursorarrow",
                            title: L10n.PreferencesCapture.showCursorTitle,
                            description: L10n.PreferencesCapture.showCursorDescription,
                        ) {
                            Toggle("", isOn: $screenshotShowCursor)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.showCursorTitle)
                        }

                        Text(L10n.PreferencesCapture.showCursorFootnote)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SettingRow(
                            icon: "snowflake",
                            title: L10n.PreferencesCapture.freezeAreaTitle,
                            description: L10n.PreferencesCapture.freezeAreaDescription,
                        ) {
                            Toggle("", isOn: $freezeAreaCapture)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.freezeAreaTitle)
                        }
                    }

                    // MARK: - Window Screenshots

                    Section(L10n.PreferencesCapture.windowScreenshotsSection) {
                        SettingRow(
                            icon: "shadow",
                            title: L10n.PreferencesCapture.windowShadowTitle,
                            description: L10n.PreferencesCapture.windowShadowDescription,
                        ) {
                            Toggle("", isOn: $captureWindowShadow)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.windowShadowTitle)
                        }

                        Text(L10n.PreferencesGeneral.hideDesktopIconsHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Selection & Snapping

                    Section(L10n.PreferencesCapture.selectionSection) {
                        SettingRow(
                            icon: "macwindow",
                            title: L10n.PreferencesCapture.showSelectionAreaOverlayTitle,
                            description: L10n.PreferencesCapture.showSelectionAreaOverlayDescription,
                        ) {
                            Toggle("", isOn: $showSelectionAreaOverlay)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.showSelectionAreaOverlayTitle)
                        }

                        SettingRow(
                            icon: "arrow.up.and.down",
                            title: L10n.PreferencesCapture.reverseMagnifierZoomDirectionTitle,
                            description: L10n.PreferencesCapture.reverseMagnifierZoomDirectionDescription,
                        ) {
                            Toggle("", isOn: $reverseMagnifierZoomDirection)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.reverseMagnifierZoomDirectionTitle)
                        }

                        SettingRow(
                            icon: "magnet",
                            title: L10n.PreferencesCapture.snappingTitle,
                            description: L10n.PreferencesCapture.snappingDescription,
                        ) {
                            Toggle("", isOn: $captureSelectionSnappingEnabled)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.snappingTitle)
                        }

                        if captureSelectionSnappingEnabled {
                            DisclosureGroup(
                                isExpanded: $showSnappingAdvancedSettings,
                                content: {
                                    VStack(spacing: 8) {
                                        SettingRow(
                                            icon: "ruler",
                                            title: L10n.PreferencesCapture.selectionSnapGuidesTitle,
                                            description: L10n.PreferencesCapture.selectionSnapGuidesDescription,
                                        ) {
                                            Toggle("", isOn: $captureSelectionShowSnapGuides)
                                                .labelsHidden()
                                                .accessibilityLabel(L10n.PreferencesCapture.selectionSnapGuidesTitle)
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
                                                range: Double(CaptureSelectionSnappingConfiguration.snapDistanceRange
                                                    .lowerBound)
                                                    ... Double(CaptureSelectionSnappingConfiguration.snapDistanceRange
                                                        .upperBound),
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
                                                ForEach(Array(CaptureSelectionSnappingConfiguration
                                                            .colorSensitivityRange),
                                                id: \.self) { value in
                                                    Text(L10n.PreferencesCapture.selectionColorSensitivityLabel(value))
                                                        .tag(value)
                                                }
                                            }
                                            .labelsHidden()
                                            .accessibilityLabel(L10n.PreferencesCapture.selectionColorSensitivityTitle)
                                            .pickerStyle(.menu)
                                        }
                                    }
                                    .padding(.top, 4)
                                },
                                label: {
                                    Text(L10n.PreferencesCapture.snappingAdvancedSettings)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                },
                            )
                        }
                    }

                    // MARK: - All-In-One Customization

                    PreferencesAllInOneModeCustomizationView(videoModuleEnabled: videoModuleEnabled)

                    // MARK: - Post Processing

                    Section(L10n.PreferencesCapture.postProcessingSection) {
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
                                .accessibilityLabel(L10n.PreferencesCapture.autoCropSubjectTitle)
                        }
                    }

                    // MARK: - Specialized Capture

                    Section(L10n.PreferencesCapture.specializedCaptureSection) {
                        SettingRow(
                            icon: "lightbulb",
                            title: L10n.PreferencesCapture.showSessionHintsTitle,
                            description: L10n.PreferencesCapture.showSessionHintsDescription,
                        ) {
                            Toggle("", isOn: $scrollingCaptureShowHints)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.showSessionHintsTitle)
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
                                .accessibilityLabel(L10n.PreferencesCapture.ocrSuccessNotificationTitle)
                        }

                        SettingRow(
                            icon: "link",
                            title: L10n.PreferencesCapture.ocrLinkDetectionTitle,
                            description: L10n.PreferencesCapture.ocrLinkDetectionDescription,
                        ) {
                            Toggle("", isOn: $ocrLinkDetection)
                                .labelsHidden()
                                .accessibilityLabel(L10n.PreferencesCapture.ocrLinkDetectionTitle)
                        }
                    }

                    Section {
                        HStack {
                            Spacer()
                            Button(L10n.PreferencesCapture.resetScreenshotDefaults, role: .destructive) {
                                isResetScreenshotDefaultsConfirmationPresented = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
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
                                .accessibilityLabel(L10n.PreferencesCapture.videoFormatTitle)
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
                                .accessibilityLabel(L10n.PreferencesCapture.frameRateTitle)
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
                                .accessibilityLabel(L10n.PreferencesCapture.qualityTitle)
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
                                    .accessibilityLabel(L10n.PreferencesCapture.showCursorTitle)
                                    .disabled(recordingSmartPointer)
                            }

                            SettingRow(
                                icon: "cursorarrow.motionlines",
                                title: L10n.PreferencesCapture.recordingSmartPointerTitle,
                                description: L10n.PreferencesCapture.recordingSmartPointerDescription,
                            ) {
                                Toggle("", isOn: $recordingSmartPointer)
                                    .labelsHidden()
                                    .accessibilityLabel(L10n.PreferencesCapture.recordingSmartPointerTitle)
                            }

                            SettingRow(
                                icon: "video",
                                title: L10n.Camera.showDuringRecording,
                                description: L10n.Camera.showDuringRecordingDescription,
                            ) {
                                Toggle("", isOn: $recordingShowCameraPreviewDuringRecording)
                                    .labelsHidden()
                                    .accessibilityLabel(L10n.Camera.showDuringRecording)
                            }

                            SettingRow(
                                icon: "rectangle.dashed",
                                title: L10n.PreferencesCapture.rememberLastAreaTitle,
                                description: L10n.PreferencesCapture.rememberLastAreaDescription,
                            ) {
                                Toggle("", isOn: $rememberLastArea)
                                    .labelsHidden()
                                    .accessibilityLabel(L10n.PreferencesCapture.rememberLastAreaTitle)
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
                                    .accessibilityLabel(L10n.PreferencesCapture.hoverBarVisibleTitle)
                            }

                            SettingRow(
                                icon: "timer",
                                title: L10n.PreferencesCapture.menuBarTimeTitle,
                                description: L10n.PreferencesCapture.menuBarTimeDescription,
                            ) {
                                Toggle("", isOn: $recordingShowTimeOnMenuBar)
                                    .labelsHidden()
                                    .accessibilityLabel(L10n.PreferencesCapture.menuBarTimeTitle)
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
                                .accessibilityLabel(L10n.PreferencesCapture.microphoneInputTitle)
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
        .alert(
            L10n.PreferencesCapture.resetScreenshotDefaultsConfirmationTitle,
            isPresented: $isResetScreenshotDefaultsConfirmationPresented,
        ) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.PreferencesCapture.resetScreenshotDefaultsConfirmButton, role: .destructive) {
                resetScreenshotDefaults()
            }
        } message: {
            Text(L10n.PreferencesCapture.resetScreenshotDefaultsConfirmationMessage)
        }
    }

    private func reconcileSelectedPane() {
        let available = CaptureSettingsPane.availablePanes(videoModuleEnabled: videoModuleEnabled)
        if !available.contains(selectedPane) {
            selectedPane = available.first ?? .capture
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var outputSettings: some View {
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
            .accessibilityLabel(L10n.PreferencesCapture.imageFormatTitle)
            .pickerStyle(.menu)
        }

        if screenshotFormat == ImageFormatOption.jpeg.rawValue {
            SettingRow(
                icon: "slider.horizontal.3",
                title: L10n.PreferencesCapture.jpegQualityTitle,
                description: L10n.PreferencesCapture.jpegQualityDescription,
            ) {
                HStack(spacing: 8) {
                    Slider(
                        value: $screenshotJpegQuality,
                        in: 0.1 ... 1.0,
                        step: 0.05,
                    )
                    .frame(width: 120)
                    .accessibilityLabel(L10n.PreferencesCapture.jpegQualityTitle)
                    .accessibilityValue(Text("\(Int((screenshotJpegQuality * 100).rounded()))%"))

                    Text("\(Int((screenshotJpegQuality * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }

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

        SettingRow(
            icon: "textformat",
            title: L10n.PreferencesCapture.screenshotTemplateTitle,
            description: L10n.PreferencesCapture.screenshotTemplateDescription,
        ) {
            TextField("", text: $screenshotFileNameTemplate)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .accessibilityLabel(L10n.PreferencesCapture.screenshotTemplateTitle)
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
                        .accessibilityLabel(L10n.PreferencesCapture.recordingTemplateTitle)
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

        PreferencesScreenshotDefaultPresetPicker()

        Text(L10n.PreferencesCapture.defaultPresetDescription)
            .font(.caption)
            .foregroundColor(.secondary)
    }

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

    private func resetScreenshotDefaults() {
        screenshotFormat = ImageFormatOption.png.rawValue
        screenshotJpegQuality = 0.85
        includeOwnAppInScreenshots = false
        screenshotShowCursor = false
        freezeAreaCapture = false
        captureWindowShadow = true
        AnnotateCanvasPresetStore.shared.clearDefaultPresetId()
    }
}

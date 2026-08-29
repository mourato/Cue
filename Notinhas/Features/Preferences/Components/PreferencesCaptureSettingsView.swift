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
    #if NOTINHAS_VIDEO_MODULE
        case recording
    #endif

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .capture:
            L10n.Preferences.captureTab
        #if NOTINHAS_VIDEO_MODULE
            case .recording:
                CaptureType.recording.displayName
        #endif
        }
    }

    static func availablePanes(videoModuleEnabled: Bool) -> [CaptureSettingsPane] {
        #if NOTINHAS_VIDEO_MODULE
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
    @AppStorage(PreferencesKeys.ocrSuccessNotificationEnabled) private var ocrSuccessNotification = false
    @AppStorage(PreferencesKeys.ocrLinkDetectionEnabled) private var ocrLinkDetection = true
    @AppStorage(PreferencesKeys.screenshotFileNameTemplate)
    private var screenshotFileNameTemplate = CaptureOutputKind.screenshot.defaultTemplate

    #if NOTINHAS_VIDEO_MODULE
        /// Recording settings
        @AppStorage(PreferencesKeys.recordingFormat) private var format = "mov"
        @AppStorage(PreferencesKeys.recordingFileNameTemplate)
        private var recordingFileNameTemplate = CaptureOutputKind.recording.defaultTemplate
        @AppStorage(PreferencesKeys.recordingFPS) private var fps = 30
        @AppStorage(PreferencesKeys.recordingQuality) private var quality = "high"
        @AppStorage(PreferencesKeys.recordingCaptureAudio) private var captureAudio = true
        @AppStorage(PreferencesKeys.recordingCaptureMicrophone) private var captureMicrophone = false
        @AppStorage(PreferencesKeys.recordingMicrophoneDeviceID)
        private var microphoneDeviceID = RecordingMicrophoneDevice.systemDefaultID
        @AppStorage(PreferencesKeys.recordingRememberLastArea) private var rememberLastArea = true
        @AppStorage(PreferencesKeys.recordingIncludeOwnApp) private var includeOwnAppInRecordings = false
        @AppStorage(PreferencesKeys.recordingShowCursor) private var recordingShowCursor = true
        @AppStorage(PreferencesKeys.recordingSmartPointer) private var recordingSmartPointer = false
        @AppStorage(PreferencesKeys.recordingHoverBarVisible) private var recordingHoverBarVisible = true
        @AppStorage(PreferencesKeys.recordingShowTimeOnMenuBar) private var recordingShowTimeOnMenuBar = true

        // Mouse Highlight settings
        @AppStorage(PreferencesKeys.mouseHighlightSize) private var mouseHighlightSize: Double = 50
        @AppStorage(PreferencesKeys.mouseHighlightAnimationDuration) private var mouseHighlightAnimDuration: Double =
            0.7
        @AppStorage(PreferencesKeys.mouseHighlightRippleCount) private var mouseHighlightRippleCount: Int = 3
        @AppStorage(PreferencesKeys.mouseHighlightOpacity) private var mouseHighlightOpacity: Double = 0.5

        // Keystroke Overlay settings
        @AppStorage(PreferencesKeys.keystrokeFontSize) private var keystrokeFontSize: Double = 16
        @AppStorage(PreferencesKeys.keystrokePosition) private var keystrokePosition: String = KeystrokeOverlayPosition
            .bottomCenter.rawValue
        @AppStorage(PreferencesKeys.keystrokeDisplayDuration) private var keystrokeDisplayDuration: Double = 1.5

        @State private var microphoneDevices: [RecordingMicrophoneDevice] = []

        /// SwiftUI Color binding backed by archived NSColor in UserDefaults
        private var mouseHighlightSwiftColor: Binding<Color> {
            Binding<Color>(
                get: {
                    if let data = UserDefaults.standard.data(forKey: PreferencesKeys.mouseHighlightColor),
                       let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                        return Color(nsColor: nsColor)
                    }
                    return Color(nsColor: MouseHighlightConfiguration.defaultHighlightColor)
                },
                set: { newColor in
                    let nsColor = NSColor(newColor)
                    if let data = try? NSKeyedArchiver.archivedData(
                        withRootObject: nsColor,
                        requiringSecureCoding: true,
                    ) {
                        UserDefaults.standard.set(data, forKey: PreferencesKeys.mouseHighlightColor)
                    }
                },
            )
        }
    #endif

    @State private var showPermissionDeniedAlert = false
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

                        #if NOTINHAS_VIDEO_MODULE
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

                        #if NOTINHAS_VIDEO_MODULE
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
                            #if NOTINHAS_VIDEO_MODULE
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

                #if NOTINHAS_VIDEO_MODULE
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

                    // MARK: - Recording Overlays

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.mouseHighlightSection) {
                            SettingRow(
                                icon: "cursorarrow.click.2",
                                title: L10n.PreferencesCapture.highlightSizeTitle,
                                description: L10n.PreferencesCapture.highlightSizeDescription(Int(mouseHighlightSize)),
                            ) {
                                PreferencesNumericPicker(
                                    value: $mouseHighlightSize,
                                    range: 30 ... 100,
                                    presets: [40, 50, 75, 100],
                                    step: 2,
                                    accessibilityTitle: L10n.PreferencesCapture.highlightSizeTitle,
                                    unit: "px",
                                    valueLabel: { "\(Int($0)) px" },
                                )
                            }

                            SettingRow(
                                icon: "timer",
                                title: L10n.PreferencesCapture.animationDurationTitle,
                                description: L10n.PreferencesCapture.animationDurationDescription(
                                    String(format: "%.1f", mouseHighlightAnimDuration),
                                ),
                            ) {
                                PreferencesNumericPicker(
                                    value: $mouseHighlightAnimDuration,
                                    range: 0.3 ... 2.0,
                                    presets: [0.3, 0.7, 1.0, 1.5, 2.0],
                                    step: 0.1,
                                    accessibilityTitle: L10n.PreferencesCapture.animationDurationTitle,
                                    unit: "s",
                                    valueLabel: { String(format: "%.1f s", $0) },
                                )
                            }

                            SettingRow(
                                icon: "circle.grid.3x3",
                                title: L10n.PreferencesCapture.rippleCountTitle,
                                description: L10n.PreferencesCapture.rippleCountDescription,
                            ) {
                                Picker("", selection: $mouseHighlightRippleCount) {
                                    ForEach(1 ... 5, id: \.self) { count in
                                        Text("\(count)").tag(count)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }

                            SettingRow(
                                icon: "paintpalette",
                                title: L10n.PreferencesCapture.highlightColorTitle,
                                description: L10n.PreferencesCapture.highlightColorDescription,
                            ) {
                                ColorPicker("", selection: mouseHighlightSwiftColor, supportsOpacity: false)
                                    .labelsHidden()
                            }

                            SettingRow(
                                icon: "circle.lefthalf.filled",
                                title: L10n.PreferencesCapture.opacityTitle,
                                description: L10n.PreferencesCapture
                                    .opacityDescription(Int(mouseHighlightOpacity * 100)),
                            ) {
                                PreferencesNumericPicker(
                                    value: $mouseHighlightOpacity,
                                    range: 0.2 ... 1.0,
                                    presets: [0.25, 0.5, 0.75, 1.0],
                                    step: 0.05,
                                    accessibilityTitle: L10n.PreferencesCapture.opacityTitle,
                                    unit: "%",
                                    customInputScale: 100,
                                    valueLabel: { "\(Int($0 * 100))%" },
                                )
                            }

                            HStack {
                                Spacer()
                                Button(L10n.Common.resetToDefault) {
                                    resetMouseHighlightDefaults()
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.keystrokeOverlaySection) {
                            SettingRow(
                                icon: "textformat.size",
                                title: L10n.PreferencesCapture.fontSizeTitle,
                                description: L10n.PreferencesCapture.fontSizeDescription(Int(keystrokeFontSize)),
                            ) {
                                PreferencesNumericPicker(
                                    value: $keystrokeFontSize,
                                    range: 12 ... 32,
                                    presets: [12, 16, 20, 24, 32],
                                    step: 1,
                                    accessibilityTitle: L10n.PreferencesCapture.fontSizeTitle,
                                    unit: "pt",
                                    valueLabel: { "\(Int($0)) pt" },
                                )
                            }

                            SettingRow(
                                icon: "square.and.arrow.down.on.square",
                                title: L10n.PreferencesCapture.positionTitle,
                                description: L10n.PreferencesCapture.positionDescription,
                            ) {
                                Picker("", selection: $keystrokePosition) {
                                    ForEach(KeystrokeOverlayPosition.allCases) { pos in
                                        Text(pos.displayName).tag(pos.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 140)
                            }

                            SettingRow(
                                icon: "clock",
                                title: L10n.PreferencesCapture.displayDurationTitle,
                                description: L10n.PreferencesCapture.displayDurationDescription(
                                    String(format: "%.1f", keystrokeDisplayDuration),
                                ),
                            ) {
                                PreferencesNumericPicker(
                                    value: $keystrokeDisplayDuration,
                                    range: 0.5 ... 5.0,
                                    presets: [0.5, 1.0, 1.5, 2.5, 5.0],
                                    step: 0.5,
                                    accessibilityTitle: L10n.PreferencesCapture.displayDurationTitle,
                                    unit: "s",
                                    valueLabel: { String(format: "%.1f s", $0) },
                                )
                            }

                            HStack {
                                Spacer()
                                Button(L10n.Common.resetToDefault) {
                                    resetKeystrokeDefaults()
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedPane == .recording {
                        Section(L10n.PreferencesCapture.audioSection) {
                            SettingRow(
                                icon: "speaker.wave.3.fill",
                                title: L10n.PreferencesCapture.systemAudioTitle,
                                description: L10n.PreferencesCapture.systemAudioDescription,
                            ) {
                                Toggle("", isOn: $captureAudio)
                                    .labelsHidden()
                            }

                            SettingRow(
                                icon: "mic.fill",
                                title: L10n.Onboarding.microphone,
                                description: L10n.PreferencesCapture.microphoneDescription,
                            ) {
                                Toggle("", isOn: Binding(
                                    get: { captureMicrophone },
                                    set: { newValue in
                                        if newValue {
                                            handleMicrophoneEnable()
                                        } else {
                                            captureMicrophone = false
                                        }
                                    },
                                ))
                                .labelsHidden()
                            }

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
                                .frame(width: 220)
                            }
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
                #endif
            }
            .formStyle(.grouped)
        }
        .onAppear {
            #if NOTINHAS_VIDEO_MODULE
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
        #if NOTINHAS_VIDEO_MODULE
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
        #if NOTINHAS_VIDEO_MODULE
            VideoFormat(rawValue: format)?.fileExtension ?? "mov"
        #else
            "mov"
        #endif
    }

    #if NOTINHAS_VIDEO_MODULE
        private func handleMicrophoneEnable() {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)

            switch status {
            case .notDetermined:
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .audio)
                    await MainActor.run {
                        if granted {
                            captureMicrophone = true
                        } else {
                            showPermissionDeniedAlert = true
                        }
                    }
                }
            case .authorized:
                captureMicrophone = true
            case .denied, .restricted:
                showPermissionDeniedAlert = true
            @unknown default:
                captureMicrophone = true
            }
        }

        private func openMicrophoneSettings() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }

        private func refreshMicrophoneDevices() {
            microphoneDevices = RecordingMicrophoneDeviceProvider.availableDevices(
                selectedDeviceID: microphoneDeviceID,
            )
        }
    #endif

    // MARK: - Reset Defaults

    private func resetOutputNamingDefaults() {
        screenshotFileNameTemplate = CaptureOutputKind.screenshot.defaultTemplate
        #if NOTINHAS_VIDEO_MODULE
            recordingFileNameTemplate = CaptureOutputKind.recording.defaultTemplate
        #endif
    }

    #if NOTINHAS_VIDEO_MODULE
        private func resetMouseHighlightDefaults() {
            mouseHighlightSize = MouseHighlightConfiguration.defaultHighlightSize
            mouseHighlightAnimDuration = MouseHighlightConfiguration.defaultAnimationDuration
            mouseHighlightRippleCount = MouseHighlightConfiguration.defaultRippleCount
            mouseHighlightOpacity = MouseHighlightConfiguration.defaultHighlightOpacity
            UserDefaults.standard.removeObject(forKey: PreferencesKeys.mouseHighlightColor)
        }

        private func resetKeystrokeDefaults() {
            keystrokeFontSize = KeystrokeOverlayConfiguration.defaultFontSize
            keystrokePosition = KeystrokeOverlayConfiguration.defaultPosition.rawValue
            keystrokeDisplayDuration = KeystrokeOverlayConfiguration.defaultDisplayDuration
        }
    #endif
}

#Preview {
    CaptureSettingsView()
        .frame(width: 600, height: 550)
}

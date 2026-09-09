//
//  PreferencesCaptureSettingsView.swift
//  Notinhas
//
//  Screenshot preferences: output, capture environment, annotate chrome, and
//  selection behavior. Screen recording lives in PreferencesScreenRecordingSettingsView.
//

import SwiftUI

struct CaptureSettingsView: View {
    // Screenshot behavior & environment
    @AppStorage(PreferencesKeys.screenshotIncludeOwnApp) private var includeOwnAppInScreenshots = false
    @AppStorage(PreferencesKeys.screenshotShowCursor) private var screenshotShowCursor = false
    @AppStorage(PreferencesKeys.screenshotFreezeArea) private var freezeAreaCapture = false
    @AppStorage(PreferencesKeys.hideDesktopIcons) private var hideDesktopIcons = false
    @AppStorage(PreferencesKeys.hideDesktopWidgets) private var hideDesktopWidgets = false
    @AppStorage(PreferencesKeys.captureWindowShadow) private var captureWindowShadow = true
    @AppStorage(PreferencesKeys.screenshotShowSelectionAreaOverlay) private var showSelectionAreaOverlay = true
    @AppStorage(PreferencesKeys.screenshotReverseMagnifierZoomDirection) private var reverseMagnifierZoomDirection =
        false

    // Annotate
    @AppStorage(PreferencesKeys.annotateClipboardImageOpenBehavior)
    private var annotateClipboardImageOpenBehavior = AnnotateClipboardImageBehavior.ask.rawValue
    @AppStorage(PreferencesKeys.annotateCloseAfterDrag) private var annotateCloseAfterDrag = true
    @AppStorage(PreferencesKeys.annotateBringForwardAfterDrag)
    private var annotateBringForwardAfterDrag = false
    @AppStorage(PreferencesKeys.annotateQuickPropertiesSyncEnabled)
    private var annotateQuickPropertiesSyncEnabled = true
    @AppStorage(PreferencesKeys.annotateCombineSaveAsEdit)
    private var annotateCombineSaveAsEdit = true

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

    // Specialized capture
    @AppStorage(PreferencesKeys.scrollingCaptureShowHints) private var scrollingCaptureShowHints = true
    @AppStorage(PreferencesKeys.backgroundCutoutAutoCropEnabled) private var backgroundCutoutAutoCropEnabled = true
    @AppStorage(PreferencesKeys.ocrSuccessNotificationEnabled) private var ocrSuccessNotification = true

    @State private var isResetScreenshotDefaultsConfirmationPresented = false
    @State private var videoModuleEnabled = VideoModuleAvailability.isEnabled
    @State private var isAllInOneModesPresented = false
    @State private var isAnnotateToolbarPresented = false
    @State private var isAnnotateBottomBarPresented = false

    var body: some View {
        Form {
            // MARK: - Output

            Section {
                outputSettings
            } header: {
                Text(L10n.PreferencesCapture.outputSection)
            } footer: {
                outputSectionFooter
            }

            // MARK: - Capture

            Section {
                SettingRow(
                    title: L10n.PreferencesCapture.includeInScreenshotsTitle,
                    description: L10n.PreferencesCapture.includeInScreenshotsDescription,
                ) {
                    Toggle("", isOn: $includeOwnAppInScreenshots)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.includeInScreenshotsTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.showCursorTitle,
                ) {
                    Toggle("", isOn: $screenshotShowCursor)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.showCursorTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.freezeAreaTitle,
                    description: L10n.PreferencesCapture.freezeAreaDescription,
                ) {
                    Toggle("", isOn: $freezeAreaCapture)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.freezeAreaTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.hideDesktopIconsTitle,
                ) {
                    Toggle("", isOn: $hideDesktopIcons)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.hideDesktopIconsTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.hideDesktopWidgetsTitle,
                ) {
                    Toggle("", isOn: $hideDesktopWidgets)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.hideDesktopWidgetsTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.allInOneModesSection,
                    description: L10n.PreferencesCapture.allInOneModesDescription,
                ) {
                    Button(L10n.PreferencesGeneral.customizeButton) {
                        isAllInOneModesPresented = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(L10n.PreferencesCapture.allInOneModesSection)
                }
            } header: {
                Text(L10n.PreferencesCapture.captureSection)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.PreferencesCapture.showCursorFootnote)
                    Text(L10n.PreferencesGeneral.hideDesktopIconsHint)
                }
            }

            // MARK: - Window Screenshots

            Section(L10n.PreferencesCapture.windowScreenshotsSection) {
                SettingRow(
                    title: L10n.PreferencesCapture.windowShadowTitle,
                ) {
                    Toggle("", isOn: $captureWindowShadow)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.windowShadowTitle)
                }
            }

            // MARK: - Annotate

            Section {
                SettingRow(
                    title: L10n.PreferencesAnnotate.quickPropertiesSyncTitle,
                    description: L10n.PreferencesAnnotate.quickPropertiesSyncDescription,
                ) {
                    Toggle("", isOn: $annotateQuickPropertiesSyncEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.quickPropertiesSyncTitle)
                }

                SettingRow(
                    title: L10n.PreferencesAnnotate.combineSaveAsEditTitle,
                    description: L10n.PreferencesAnnotate.combineSaveAsEditDescription,
                ) {
                    Toggle("", isOn: $annotateCombineSaveAsEdit)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.combineSaveAsEditTitle)
                }

                SettingRow(
                    title: L10n.PreferencesAnnotate.clipboardTitle,
                    description: L10n.PreferencesAnnotate.clipboardDescription,
                ) {
                    Picker("", selection: $annotateClipboardImageOpenBehavior) {
                        ForEach(AnnotateClipboardImageBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior.rawValue)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesAnnotate.clipboardTitle)
                    .standardMenuPickerStyle()
                    .fixedSize()
                    .frame(width: 180, alignment: .trailing)
                }

                SettingRow(
                    title: L10n.PreferencesAnnotate.closeAfterDragTitle,
                    description: L10n.PreferencesAnnotate.closeAfterDragDescription,
                ) {
                    Toggle("", isOn: $annotateCloseAfterDrag)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.closeAfterDragTitle)
                }

                SettingRow(
                    title: L10n.PreferencesAnnotate.bringForwardAfterDragTitle,
                    description: L10n.PreferencesAnnotate.bringForwardAfterDragDescription,
                ) {
                    Toggle("", isOn: $annotateBringForwardAfterDrag)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesAnnotate.bringForwardAfterDragTitle)
                }
                .disabled(annotateCloseAfterDrag)

                SettingRow(
                    title: L10n.PreferencesAnnotate.chromeToolbarSection,
                ) {
                    Button(L10n.PreferencesGeneral.customizeButton) {
                        isAnnotateToolbarPresented = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(L10n.PreferencesAnnotate.chromeToolbarSection)
                }

                SettingRow(
                    title: L10n.PreferencesAnnotate.chromeBottomSection,
                ) {
                    Button(L10n.PreferencesGeneral.customizeButton) {
                        isAnnotateBottomBarPresented = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(L10n.PreferencesAnnotate.chromeBottomSection)
                }
            } header: {
                Text(L10n.PreferencesGeneral.annotateSection)
            } footer: {
                Text(L10n.PreferencesAnnotate.chromeDescription)
            }

            // MARK: - Selection & Snapping

            Section(L10n.PreferencesCapture.selectionSection) {
                SettingRow(
                    title: L10n.PreferencesCapture.showSelectionAreaOverlayTitle,
                    description: L10n.PreferencesCapture.showSelectionAreaOverlayDescription,
                ) {
                    Toggle("", isOn: $showSelectionAreaOverlay)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.showSelectionAreaOverlayTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.reverseMagnifierZoomDirectionTitle,
                    description: L10n.PreferencesCapture.reverseMagnifierZoomDirectionDescription,
                ) {
                    Toggle("", isOn: $reverseMagnifierZoomDirection)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.reverseMagnifierZoomDirectionTitle)
                }

                SettingRow(
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
                                    title: L10n.PreferencesCapture.selectionSnapGuidesTitle,
                                ) {
                                    Toggle("", isOn: $captureSelectionShowSnapGuides)
                                        .labelsHidden()
                                        .accessibilityLabel(L10n.PreferencesCapture.selectionSnapGuidesTitle)
                                }

                                SettingRow(
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
                                    .standardMenuPickerStyle()
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

            // MARK: - Post Processing

            Section(L10n.PreferencesCapture.postProcessingSection) {
                SettingRow(
                    title: L10n.PreferencesCapture.autoCropSubjectTitle,
                    description: L10n.PreferencesCapture.autoCropSubjectDescription,
                ) {
                    Toggle("", isOn: $backgroundCutoutAutoCropEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.autoCropSubjectTitle)
                }
            }

            // MARK: - Specialized Capture

            Section {
                SettingRow(
                    title: L10n.PreferencesCapture.showSessionHintsTitle,
                ) {
                    Toggle("", isOn: $scrollingCaptureShowHints)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.showSessionHintsTitle)
                }

                SettingRow(
                    title: L10n.PreferencesCapture.ocrSuccessNotificationTitle,
                    description: L10n.PreferencesCapture.ocrSuccessNotificationDescription,
                ) {
                    Toggle("", isOn: $ocrSuccessNotification)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.ocrSuccessNotificationTitle)
                }
            } header: {
                Text(L10n.PreferencesCapture.specializedCaptureSection)
            } footer: {
                Text(L10n.PreferencesCapture.scrollingCaptureInfo)
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
        .preferencesFormStyle()
        .onAppear {
            videoModuleEnabled = VideoModuleAvailability.isEnabled
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoModuleAvailabilityDidChange)) { _ in
            videoModuleEnabled = VideoModuleAvailability.isEnabled
        }
        .sheet(isPresented: $isAllInOneModesPresented) {
            PreferencesAllInOneModeCustomizationContent(videoModuleEnabled: videoModuleEnabled)
                .frame(width: 520, height: 480)
                .padding()
        }
        .sheet(isPresented: $isAnnotateToolbarPresented) {
            AnnotateChromeCustomizationContent(surface: .toolbar)
                .frame(width: 520, height: 480)
                .padding()
        }
        .sheet(isPresented: $isAnnotateBottomBarPresented) {
            AnnotateChromeCustomizationContent(surface: .bottomBar)
                .frame(width: 520, height: 480)
                .padding()
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

    // MARK: - Helpers

    @ViewBuilder
    private var outputSectionFooter: some View {
        if screenshotFormat == ImageFormatOption.jpeg.rawValue {
            Text(L10n.PreferencesCapture.jpegCutoutNote)
        } else if screenshotFormat == ImageFormatOption.webp.rawValue {
            Text(L10n.PreferencesCapture.webpWarning)
        }
    }

    @ViewBuilder
    private var outputSettings: some View {
        SettingRow(
            title: L10n.PreferencesCapture.imageFormatTitle,
        ) {
            Picker("", selection: $screenshotFormat) {
                ForEach(ImageFormatOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .labelsHidden()
            .accessibilityLabel(L10n.PreferencesCapture.imageFormatTitle)
            .standardMenuPickerStyle()
        }

        if screenshotFormat == ImageFormatOption.jpeg.rawValue {
            SettingRow(
                title: L10n.PreferencesCapture.jpegQualityTitle,
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
        }

        PreferencesScreenshotDefaultPresetPicker()
    }

    // MARK: - Reset Defaults

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

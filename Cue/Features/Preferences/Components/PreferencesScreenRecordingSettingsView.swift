#if CUE_VIDEO_MODULE
//
    //  PreferencesScreenRecordingSettingsView.swift
    //  Notinhas
//
    //  Screen Recording preferences tab mirroring the reference layout:
    //  General / Cursor / Keystrokes / Video / Audio / GIF.
//

    import AppKit
    import SwiftUI

    struct ScreenRecordingSettingsView: View {
        // MARK: - General

        @AppStorage(PreferencesKeys.recordingHoverBarVisible) private var showControlsWhileRecording = true
        @AppStorage(PreferencesKeys.recordingRememberLastArea) private var rememberLastSelection = true
        @AppStorage(PreferencesKeys.recordingShowTimeOnMenuBar) private var displayTimeInMenuBar = true
        @AppStorage(PreferencesKeys.recordingDimScreenWhileRecording) private var dimScreenWhileRecording = true
        @AppStorage(PreferencesKeys.recordingShowCountdown) private var showCountdown = false

        // MARK: - Cursor & Keystrokes

        @AppStorage(PreferencesKeys.recordingShowCursor) private var showCursor = true
        @AppStorage(PreferencesKeys.recordingHighlightClicks) private var highlightClicks = false
        @AppStorage(PreferencesKeys.recordingShowKeystrokes) private var showKeystrokes = false
        @State private var showClickOptions = false
        @State private var showKeystrokeOptions = false

        // MARK: - Video

        @AppStorage(PreferencesKeys.recordingFormat) private var format = "mov"
        @AppStorage(PreferencesKeys.recordingFPS) private var fps = 30
        @AppStorage(PreferencesKeys.recordingMaxResolution) private var maxResolution = "1080p"
        @AppStorage(PreferencesKeys.recordingScaleRetinaTo1x) private var scaleRetinaTo1x = true

        // MARK: - Audio

        @AppStorage(PreferencesKeys.recordingAudioMono) private var recordMono = false
        @AppStorage(PreferencesKeys.recordingCaptureAudio) private var recordSystemAudio = true
        @AppStorage(PreferencesKeys.recordingAudioTracks) private var audioTracks = "single"

        // MARK: - GIF

        @AppStorage(PreferencesKeys.recordingGifFrameRate) private var gifFrameRate = 15
        @AppStorage(PreferencesKeys.recordingGifMaxWidth) private var gifMaxWidth = 800
        @AppStorage(PreferencesKeys.recordingGifOptimize) private var optimizeGIFs = true
        @AppStorage(PreferencesKeys.recordingGifQuality) private var gifQuality = 0.75

        var body: some View {
            Form {
                Section(L10n.PreferencesScreenRecording.generalSection) {
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.showControlsTitle,
                        isOn: $showControlsWhileRecording,
                    )
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.rememberLastSelectionTitle,
                        isOn: $rememberLastSelection,
                    )
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.displayTimeInMenuBarTitle,
                        isOn: $displayTimeInMenuBar,
                    )
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.dimScreenTitle,
                        isOn: $dimScreenWhileRecording,
                    )
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.showCountdownTitle,
                        isOn: $showCountdown,
                    )
                }

                Section(L10n.PreferencesScreenRecording.cursorSection) {
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesCapture.showCursorTitle,
                        isOn: $showCursor,
                    )
                    ScreenRecordingOptionsRow(
                        title: L10n.PreferencesScreenRecording.highlightClicksTitle,
                        isOn: $highlightClicks,
                        showOptions: $showClickOptions,
                    )
                    .popover(isPresented: $showClickOptions) {
                        ClickHighlightOptionsView()
                    }
                }

                Section(L10n.PreferencesScreenRecording.keystrokesSection) {
                    ScreenRecordingOptionsRow(
                        title: L10n.PreferencesScreenRecording.showKeystrokesTitle,
                        isOn: $showKeystrokes,
                        showOptions: $showKeystrokeOptions,
                    )
                    .popover(isPresented: $showKeystrokeOptions) {
                        KeystrokeOptionsView()
                    }
                }

                Section(L10n.PreferencesScreenRecording.videoSection) {
                    HStack {
                        Text(L10n.PreferencesScreenRecording.videoFormatTitle)
                        Spacer()
                        Picker("", selection: $format) {
                            Text(verbatim: "MOV").tag("mov")
                            Text(verbatim: "MP4").tag("mp4")
                        }
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesScreenRecording.videoFormatTitle)
                        .standardMenuPickerStyle()
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text(L10n.PreferencesScreenRecording.frameRateTitle)
                        Spacer()
                        Picker("", selection: $fps) {
                            ForEach([30, 60], id: \.self) { value in
                                Text(L10n.PreferencesScreenRecording.fpsLabel(value)).tag(value)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesScreenRecording.frameRateTitle)
                        .standardMenuPickerStyle()
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(L10n.PreferencesScreenRecording.maxResolutionTitle)
                            Spacer()
                            Picker("", selection: $maxResolution) {
                                ForEach(["720p", "1080p", "1440p", "2160p", "Original"], id: \.self) { value in
                                    Text(verbatim: value).tag(value)
                                }
                            }
                            .labelsHidden()
                            .accessibilityLabel(L10n.PreferencesScreenRecording.maxResolutionTitle)
                            .standardMenuPickerStyle()
                        }
                        Text(L10n.PreferencesScreenRecording.maxResolutionDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.scaleRetinaTitle,
                        isOn: $scaleRetinaTo1x,
                    )
                }

                Section(L10n.PreferencesScreenRecording.audioSection) {
                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.recordMonoTitle,
                        isOn: $recordMono,
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        ScreenRecordingToggleRow(
                            title: L10n.PreferencesScreenRecording.recordSystemAudioTitle,
                            isOn: $recordSystemAudio,
                        )
                        Text(L10n.PreferencesScreenRecording.recordSystemAudioDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(L10n.PreferencesScreenRecording.audioTracksTitle)
                            Spacer()
                            Picker("", selection: $audioTracks) {
                                Text(L10n.PreferencesScreenRecording.singleTrack).tag("single")
                                Text(L10n.PreferencesScreenRecording.separateTracks).tag("separate")
                            }
                            .labelsHidden()
                            .accessibilityLabel(L10n.PreferencesScreenRecording.audioTracksTitle)
                            .standardMenuPickerStyle()
                        }
                        Text(L10n.PreferencesScreenRecording.audioTracksDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(L10n.PreferencesScreenRecording.gifSection) {
                    HStack {
                        Text(L10n.PreferencesScreenRecording.frameRateTitle)
                        Spacer()
                        Picker("", selection: $gifFrameRate) {
                            ForEach([10, 12, 15, 20, 24, 30], id: \.self) { value in
                                Text(L10n.PreferencesScreenRecording.fpsLabel(value)).tag(value)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesScreenRecording.frameRateTitle)
                        .standardMenuPickerStyle()
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text(L10n.PreferencesScreenRecording.resolutionTitle)
                        Spacer()
                        Picker("", selection: $gifMaxWidth) {
                            ForEach([480, 600, 800, 960, 0], id: \.self) { width in
                                Text(gifResolutionLabel(for: width)).tag(width)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesScreenRecording.resolutionTitle)
                        .standardMenuPickerStyle()
                    }
                    .padding(.vertical, 4)

                    ScreenRecordingToggleRow(
                        title: L10n.PreferencesScreenRecording.optimizeGIFsTitle,
                        isOn: $optimizeGIFs,
                    )

                    HStack {
                        Text(L10n.PreferencesScreenRecording.qualityTitle)
                        Spacer()
                        Text(L10n.PreferencesScreenRecording.low)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $gifQuality, in: 0.1 ... 1.0)
                            .frame(width: 160)
                            .accessibilityLabel(L10n.PreferencesScreenRecording.qualityTitle)
                        Text(L10n.PreferencesScreenRecording.high)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .preferencesFormStyle()
        }

        private func gifResolutionLabel(for width: Int) -> String {
            guard width > 0 else { return L10n.PreferencesScreenRecording.originalResolution }
            if width == 800 {
                return L10n.PreferencesScreenRecording.gifResolutionDefaultLabel(width)
            }
            return L10n.PreferencesScreenRecording.gifResolutionLabel(width)
        }
    }

    // MARK: - Rows

    private struct ScreenRecordingToggleRow: View {
        let title: String
        @Binding var isOn: Bool

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .accessibilityLabel(title)
            }
            .padding(.vertical, 4)
        }
    }

    private struct ScreenRecordingOptionsRow: View {
        let title: String
        @Binding var isOn: Bool
        @Binding var showOptions: Bool

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Button(L10n.PreferencesScreenRecording.optionsButton) {
                    showOptions = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .accessibilityLabel(title)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Click highlight options

    private struct ClickHighlightOptionsView: View {
        @AppStorage(PreferencesKeys.mouseHighlightSize) private var highlightSize = 50.0
        @AppStorage(PreferencesKeys.mouseHighlightAnimationDuration) private var animationDuration = 0.7
        @AppStorage(PreferencesKeys.mouseHighlightRippleCount) private var rippleCount = 3
        @AppStorage(PreferencesKeys.mouseHighlightOpacity) private var highlightOpacity = 0.5

        private var highlightColor: Binding<Color> {
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

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.PreferencesScreenRecording.clickOptionsTitle)
                    .font(.headline)

                HStack {
                    Text(L10n.PreferencesCapture.highlightSizeTitle)
                    Spacer()
                    Slider(value: $highlightSize, in: 20 ... 100, step: 1)
                        .frame(width: 120)
                        .accessibilityLabel(L10n.PreferencesCapture.highlightSizeTitle)
                    Text("\(Int(highlightSize)) px")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                HStack {
                    Text(L10n.PreferencesCapture.rippleCountTitle)
                    Spacer()
                    Stepper(
                        "",
                        value: $rippleCount,
                        in: 1 ... 6,
                    )
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesCapture.rippleCountTitle)
                    Text("\(rippleCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                }

                HStack {
                    Text(L10n.PreferencesCapture.highlightColorTitle)
                    Spacer()
                    ColorPicker("", selection: highlightColor, supportsOpacity: false)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.highlightColorTitle)
                }

                HStack {
                    Text(L10n.PreferencesCapture.opacityTitle)
                    Spacer()
                    Slider(value: $highlightOpacity, in: 0.1 ... 1.0)
                        .frame(width: 120)
                        .accessibilityLabel(L10n.PreferencesCapture.opacityTitle)
                    Text("\(Int((highlightOpacity * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack {
                    Text(L10n.PreferencesCapture.animationDurationTitle)
                    Spacer()
                    Slider(value: $animationDuration, in: 0.1 ... 3.0, step: 0.1)
                        .frame(width: 120)
                        .accessibilityLabel(L10n.PreferencesCapture.animationDurationTitle)
                    Text(String(format: "%.1fs", animationDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }

    // MARK: - Keystroke options

    private struct KeystrokeOptionsView: View {
        @AppStorage(PreferencesKeys.keystrokeFontSize) private var fontSize = 16.0
        @AppStorage(PreferencesKeys.keystrokePosition) private var position =
            KeystrokeOverlayPosition.bottomCenter.rawValue
        @AppStorage(PreferencesKeys.keystrokeDisplayDuration) private var displayDuration = 1.5

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.PreferencesScreenRecording.keystrokeOptionsTitle)
                    .font(.headline)

                HStack {
                    Text(L10n.PreferencesCapture.fontSizeTitle)
                    Spacer()
                    Slider(value: $fontSize, in: 10 ... 48, step: 1)
                        .frame(width: 120)
                        .accessibilityLabel(L10n.PreferencesCapture.fontSizeTitle)
                    Text("\(Int(fontSize))pt")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                HStack {
                    Text(L10n.PreferencesCapture.positionTitle)
                    Spacer()
                    Picker("", selection: $position) {
                        ForEach(KeystrokeOverlayPosition.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesCapture.positionTitle)
                    .standardMenuPickerStyle()
                }

                HStack {
                    Text(L10n.PreferencesCapture.displayDurationTitle)
                    Spacer()
                    Slider(value: $displayDuration, in: 0.3 ... 10.0, step: 0.1)
                        .frame(width: 120)
                        .accessibilityLabel(L10n.PreferencesCapture.displayDurationTitle)
                    Text(String(format: "%.1fs", displayDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }
#endif

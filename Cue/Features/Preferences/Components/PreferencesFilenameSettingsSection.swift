//
//  PreferencesFilenameSettingsSection.swift
//  Cue
//
//  Screenshot/recording filename format controls (Settings → Screenshot).
//

import SwiftUI

struct PreferencesFilenameSettingsSection: View {
    @AppStorage(PreferencesKeys.captureAskForNameAfterCapture) private var askForNameAfterCapture = false
    @AppStorage(PreferencesKeys.screenshotAddRetinaSuffix) private var addRetinaSuffix = true
    @State private var isNameFormatEditorPresented = false

    var body: some View {
        Section(L10n.PreferencesAdvanced.fileNameSection) {
            SettingRow(
                title: L10n.PreferencesAdvanced.askForNameTitle,
            ) {
                Toggle("", isOn: $askForNameAfterCapture)
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesAdvanced.askForNameTitle)
            }

            SettingRow(
                title: L10n.PreferencesAdvanced.fileNameFormatTitle,
            ) {
                Button(L10n.PreferencesAdvanced.customizeButton) {
                    isNameFormatEditorPresented = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            SettingRow(
                title: L10n.PreferencesAdvanced.retinaSuffixTitle,
                description: L10n.PreferencesAdvanced.retinaSuffixDescription,
            ) {
                Toggle("", isOn: $addRetinaSuffix)
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesAdvanced.retinaSuffixTitle)
            }
        }
        .sheet(isPresented: $isNameFormatEditorPresented) {
            PreferencesFilenameFormatEditor()
                .frame(width: 620, height: 260)
                .padding()
        }
    }
}

private struct PreferencesFilenameFormatEditor: View {
    @AppStorage(PreferencesKeys.screenshotFileNameTemplate)
    private var screenshotTemplate = CaptureOutputKind.screenshot.defaultTemplate

    #if CUE_VIDEO_MODULE
        @AppStorage(PreferencesKeys.recordingFileNameTemplate)
        private var recordingTemplate = CaptureOutputKind.recording.defaultTemplate
    #endif

    var body: some View {
        Form {
            TextField(L10n.PreferencesAdvanced.screenshotFileNameFormat, text: $screenshotTemplate)
                .accessibilityLabel(L10n.PreferencesAdvanced.screenshotFileNameFormat)
            #if CUE_VIDEO_MODULE
                TextField(L10n.PreferencesAdvanced.recordingFileNameFormat, text: $recordingTemplate)
                    .accessibilityLabel(L10n.PreferencesAdvanced.recordingFileNameFormat)
            #endif
            Text(L10n.PreferencesAdvanced.fileNameFormatHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

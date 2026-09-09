//
//  PreferencesGeneralSettingsView.swift
//  Notinhas
//
//  General preferences: app shell, sounds, export, after-capture, appearance, help.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(PreferencesKeys.playSounds) private var playSounds = true
    @AppStorage(PreferencesKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PreferencesKeys.exportLocation) private var exportLocation = ""
    @AppStorage(PreferencesKeys.clipboardCopyMode) private var clipboardCopyMode = ClipboardCopyMode.fileAndImage
        .rawValue

    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var startAtLogin = LoginItemManager.isEnabled
    private let fileAccessManager = SandboxFileAccessManager.shared

    var body: some View {
        Form {
            Section(L10n.PreferencesGeneral.appSection) {
                SettingRow(
                    title: L10n.PreferencesGeneral.startAtLoginTitle,
                ) {
                    Toggle("", isOn: $startAtLogin)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesGeneral.startAtLoginTitle)
                        .onChange(of: startAtLogin) { newValue in
                            LoginItemManager.setEnabled(newValue)
                        }
                }

                SettingRow(
                    title: L10n.PreferencesGeneral.menuBarIconTitle,
                    description: L10n.PreferencesGeneral.menuBarIconDescription,
                ) {
                    Toggle("", isOn: $showMenuBarIcon)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesGeneral.menuBarIconTitle)
                        .onChange(of: showMenuBarIcon) { newValue in
                            AppStatusBarController.shared.setMenuBarIconVisible(newValue)
                        }
                }
            }

            Section(L10n.PreferencesGeneral.soundsSection) {
                SettingRow(
                    title: L10n.PreferencesGeneral.playSoundsTitle,
                ) {
                    Toggle("", isOn: $playSounds)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesGeneral.playSoundsTitle)
                }
            }

            Section(L10n.PreferencesGeneral.exportSection) {
                SettingRow(
                    title: L10n.PreferencesGeneral.exportLocationTitle,
                    description: exportLocationDisplay,
                ) {
                    Button(L10n.PreferencesGeneral.chooseButton) {
                        chooseExportLocation()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text(L10n.PreferencesGeneral.exportLocationDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L10n.PreferencesAdvanced.clipboardSection) {
                SettingRow(
                    title: L10n.PreferencesAdvanced.copyToClipboardTitle,
                    description: L10n.PreferencesAdvanced.copyToClipboardDescription,
                ) {
                    Picker("", selection: $clipboardCopyMode) {
                        ForEach(ClipboardCopyMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesAdvanced.copyToClipboardTitle)
                    .standardMenuPickerStyle()
                    .fixedSize()
                }
            }

            Section {
                AfterCaptureMatrixView()
            } header: {
                Text(L10n.PreferencesGeneral.afterCaptureSection)
            } footer: {
                Text(L10n.PreferencesGeneral.afterCaptureDescription)
            }

            Section(L10n.PreferencesGeneral.appearanceSection) {
                PreferencesLanguageSettingRow()

                SettingRow(
                    title: L10n.PreferencesGeneral.themeTitle,
                ) {
                    AppearanceModePicker(selection: $themeManager.preferredAppearance)
                }
            }

            Section(L10n.PreferencesGeneral.helpSection) {
                SettingRow(
                    title: L10n.PreferencesGeneral.restartOnboardingTitle,
                ) {
                    Button(L10n.PreferencesGeneral.restartButton) {
                        restartOnboarding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .preferencesFormStyle()
        .onAppear {
            startAtLogin = LoginItemManager.isEnabled
            initializeExportLocation()
        }
    }

    // MARK: - Helpers

    private var exportLocationDisplay: String {
        if exportLocation.isEmpty {
            return L10n.PreferencesGeneral.defaultSaveLocation
        }

        let folderName = URL(fileURLWithPath: exportLocation).lastPathComponent
        if fileAccessManager.hasPersistedExportPermission {
            return folderName
        }

        return L10n.PreferencesGeneral.accessNotGranted(folderName)
    }

    private func initializeExportLocation() {
        fileAccessManager.ensureExportLocationInitialized()
        exportLocation = fileAccessManager.exportLocationPath
    }

    private func chooseExportLocation() {
        if let url = fileAccessManager.chooseExportDirectory(
            message: L10n.PreferencesGeneral.chooseSaveLocationMessage,
            prompt: L10n.PreferencesGeneral.saveHereButton,
            directoryURL: fileAccessManager.resolvedExportDirectoryURL(),
        ) {
            exportLocation = url.path
        }
    }

    // MARK: - Onboarding

    private func restartOnboarding() {
        OnboardingFlowView.resetOnboarding()
        NSApp.keyWindow?.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .showOnboarding, object: nil)
        }
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 600, height: 500)
}

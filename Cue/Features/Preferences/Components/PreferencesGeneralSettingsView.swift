//
//  PreferencesGeneralSettingsView.swift
//  Notinhas
//
//  General preferences tab with startup, appearance, storage, and help
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(PreferencesKeys.playSounds) private var playSounds = true
    @AppStorage(PreferencesKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PreferencesKeys.exportLocation) private var exportLocation = ""
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var startAtLogin = LoginItemManager.isEnabled
    private let fileAccessManager = SandboxFileAccessManager.shared

    var body: some View {
        Form {
            Section(L10n.PreferencesGeneral.startupSection) {
                SettingRow(
                    icon: "power.circle",
                    title: L10n.PreferencesGeneral.startAtLoginTitle,
                    description: L10n.PreferencesGeneral.startAtLoginDescription,
                ) {
                    Toggle("", isOn: $startAtLogin)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesGeneral.startAtLoginTitle)
                        .onChange(of: startAtLogin) { newValue in
                            LoginItemManager.setEnabled(newValue)
                        }
                }

                SettingRow(
                    icon: "speaker.wave.2",
                    title: L10n.PreferencesGeneral.playSoundsTitle,
                    description: L10n.PreferencesGeneral.playSoundsDescription,
                ) {
                    Toggle("", isOn: $playSounds)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesGeneral.playSoundsTitle)
                }

                SettingRow(
                    icon: "menubar.rectangle",
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

            Section(L10n.PreferencesGeneral.appearanceSection) {
                PreferencesLanguageSettingRow()

                SettingRow(
                    icon: "circle.lefthalf.filled",
                    title: L10n.PreferencesGeneral.themeTitle,
                    description: L10n.PreferencesGeneral.themeDescription,
                ) {
                    AppearanceModePicker(selection: $themeManager.preferredAppearance)
                }
            }

            Section(L10n.PreferencesGeneral.storageSection) {
                SettingRow(
                    icon: "folder.fill",
                    title: L10n.PreferencesGeneral.saveLocationTitle,
                    description: exportLocationDisplay,
                ) {
                    Button(L10n.PreferencesGeneral.chooseButton) {
                        chooseExportLocation()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Section(L10n.PreferencesGeneral.helpSection) {
                SettingRow(
                    icon: "arrow.counterclockwise.circle",
                    title: L10n.PreferencesGeneral.restartOnboardingTitle,
                    description: L10n.PreferencesGeneral.restartOnboardingDescription,
                ) {
                    Button(L10n.PreferencesGeneral.restartButton) {
                        restartOnboarding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
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

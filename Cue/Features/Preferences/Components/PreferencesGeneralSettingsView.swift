//
//  PreferencesGeneralSettingsView.swift
//  Notinhas
//
//  General preferences tab: app, capture, sounds, export, and after-capture
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(PreferencesKeys.playSounds) private var playSounds = true
    @AppStorage(PreferencesKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PreferencesKeys.hideDesktopIcons) private var hideDesktopIcons = false
    @AppStorage(PreferencesKeys.hideDesktopWidgets) private var hideDesktopWidgets = false
    @AppStorage(PreferencesKeys.exportLocation) private var exportLocation = ""
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var startAtLogin = LoginItemManager.isEnabled
    private let fileAccessManager = SandboxFileAccessManager.shared

    var body: some View {
        Form {
            Section(L10n.PreferencesGeneral.appSection) {
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

            Section(L10n.PreferencesGeneral.captureSection) {
                SettingRow(
                    icon: "eye.slash",
                    title: L10n.PreferencesCapture.hideDesktopIconsTitle,
                    description: L10n.PreferencesCapture.hideDesktopIconsDescription,
                ) {
                    Toggle("", isOn: $hideDesktopIcons)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.hideDesktopIconsTitle)
                }

                SettingRow(
                    icon: "widget.small",
                    title: L10n.PreferencesCapture.hideDesktopWidgetsTitle,
                    description: L10n.PreferencesCapture.hideDesktopWidgetsDescription,
                ) {
                    Toggle("", isOn: $hideDesktopWidgets)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesCapture.hideDesktopWidgetsTitle)
                }

                Text(L10n.PreferencesGeneral.hideDesktopIconsHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L10n.PreferencesGeneral.soundsSection) {
                SettingRow(
                    icon: "speaker.wave.2",
                    title: L10n.PreferencesGeneral.playSoundsTitle,
                    description: L10n.PreferencesGeneral.playSoundsDescription,
                ) {
                    Toggle("", isOn: $playSounds)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesGeneral.playSoundsTitle)
                }
            }

            Section(L10n.PreferencesGeneral.exportSection) {
                SettingRow(
                    icon: "folder.fill",
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
                    icon: "circle.lefthalf.filled",
                    title: L10n.PreferencesGeneral.themeTitle,
                    description: L10n.PreferencesGeneral.themeDescription,
                ) {
                    AppearanceModePicker(selection: $themeManager.preferredAppearance)
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

//
//  PreferencesView.swift
//  Notinhas
//
//  Root preferences window with sidebar navigation
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var navigationState = PreferencesNavigationState.shared

    var body: some View {
        NavigationSplitView {
            List(selection: selectedTabBinding) {
                Label(L10n.Preferences.generalTab, systemImage: "gearshape.fill")
                    .tag(PreferencesTab.general)

                Label(L10n.Preferences.captureTab, systemImage: "camera.fill")
                    .tag(PreferencesTab.capture)

                #if CUE_VIDEO_MODULE
                    Label(L10n.Preferences.screenRecordingTab, systemImage: "record.circle")
                        .tag(PreferencesTab.screenRecording)
                #endif

                Label(L10n.Preferences.quickAccessTab, systemImage: "square.stack.fill")
                    .tag(PreferencesTab.quickAccess)

                Label(L10n.Preferences.historyTab, systemImage: "clock.arrow.circlepath")
                    .tag(PreferencesTab.history)

                Label(L10n.Preferences.shortcutsTab, systemImage: "keyboard.fill")
                    .tag(PreferencesTab.shortcuts)

                Label(L10n.Preferences.permissionsTab, systemImage: "lock.shield.fill")
                    .tag(PreferencesTab.permissions)

                Label(L10n.Preferences.cloudTab, systemImage: "icloud.fill")
                    .tag(PreferencesTab.cloud)

                Label(L10n.Preferences.advancedTab, systemImage: "slider.horizontal.3")
                    .tag(PreferencesTab.advanced)
            }
            .listStyle(.sidebar)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            settingsContent
                .navigationTitle(selectedTabTitle)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .title)
        .preferencesHostingWindowChrome()
        .frame(width: 760, height: 550)
    }

    private var selectedTabBinding: Binding<PreferencesTab?> {
        Binding(
            get: { navigationState.selectedTab },
            set: { newValue in
                if let newValue {
                    navigationState.selectedTab = newValue
                }
            },
        )
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch navigationState.selectedTab {
        case .general:
            GeneralSettingsView()
        case .capture:
            CaptureSettingsView()
        #if CUE_VIDEO_MODULE
            case .screenRecording:
                ScreenRecordingSettingsView()
        #else
            case .screenRecording:
                GeneralSettingsView()
        #endif
        case .quickAccess:
            QuickAccessSettingsView()
        case .history:
            HistorySettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .permissions:
            PermissionsSettingsView()
        case .cloud:
            CloudSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }

    private var selectedTabTitle: String {
        switch navigationState.selectedTab {
        case .general: L10n.Preferences.generalTab
        case .capture: L10n.Preferences.captureTab
        case .screenRecording: L10n.Preferences.screenRecordingTab
        case .quickAccess: L10n.Preferences.quickAccessTab
        case .history: L10n.Preferences.historyTab
        case .shortcuts: L10n.Preferences.shortcutsTab
        case .permissions: L10n.Preferences.permissionsTab
        case .cloud: L10n.Preferences.cloudTab
        case .advanced: L10n.Preferences.advancedTab
        }
    }
}

#Preview {
    PreferencesView()
}

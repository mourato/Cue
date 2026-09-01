//
//  PreferencesView.swift
//  Notinhas
//
//  Root preferences window with tabbed interface
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var navigationState = PreferencesNavigationState.shared

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            GeneralSettingsView()
                .tabItem { Label(L10n.Preferences.generalTab, systemImage: "gearshape.fill") }
                .tag(PreferencesTab.general)

            CaptureSettingsView()
                .tabItem { Label(L10n.Preferences.captureTab, systemImage: "camera.fill") }
                .tag(PreferencesTab.capture)

            AnnotateSettingsView()
                .tabItem { Label(L10n.Preferences.annotateTab, systemImage: "pencil.and.scribble") }
                .tag(PreferencesTab.annotate)

            QuickAccessSettingsView()
                .tabItem { Label(L10n.Preferences.quickAccessTab, systemImage: "square.stack.fill") }
                .tag(PreferencesTab.quickAccess)

            HistorySettingsView()
                .tabItem { Label(L10n.Preferences.historyTab, systemImage: "clock.arrow.circlepath") }
                .tag(PreferencesTab.history)

            ShortcutsSettingsView()
                .tabItem { Label(L10n.Preferences.shortcutsTab, systemImage: "keyboard.fill") }
                .tag(PreferencesTab.shortcuts)

            PermissionsSettingsView()
                .tabItem { Label(L10n.Preferences.permissionsTab, systemImage: "lock.shield.fill") }
                .tag(PreferencesTab.permissions)

            CloudSettingsView()
                .tabItem { Label(L10n.Preferences.cloudTab, systemImage: "icloud.fill") }
                .tag(PreferencesTab.cloud)

            AdvancedSettingsView()
                .tabItem { Label(L10n.Preferences.advancedTab, systemImage: "slider.horizontal.3") }
                .tag(PreferencesTab.advanced)
        }
        .frame(width: 760, height: 550)
    }
}

#Preview {
    PreferencesView()
}

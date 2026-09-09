//
//  PreferencesFormChrome.swift
//  Cue
//
//  Shared Preferences page chrome: window toolbar style and form top insets.
//

import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when Preferences content appears so the app shell can apply window chrome.
    static let cuePreferencesContentDidAppear = Notification.Name("cuePreferencesContentDidAppear")
}

enum PreferencesWindowChrome {
    static let defaultWidth: CGFloat = 760
    static let defaultHeight: CGFloat = 550

    /// AppKit Preferences window chrome owned by the app shell.
    /// Settings scenes often ignore SwiftUI `.windowToolbarStyle`; apply the
    /// compact unified toolbar so traffic lights and the sidebar toggle share
    /// one row, and the detail column does not reserve an empty title band.
    /// Also keep the window user-resizable with the documented minimum size.
    @MainActor
    static func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.toolbar?.displayMode = .iconOnly
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: defaultWidth, height: defaultHeight)
    }
}

extension View {
    /// Grouped Preferences form with a tighter top content margin under the toolbar.
    func preferencesFormStyle() -> some View {
        formStyle(.grouped)
            .contentMargins(.top, 8, for: .scrollContent)
    }
}

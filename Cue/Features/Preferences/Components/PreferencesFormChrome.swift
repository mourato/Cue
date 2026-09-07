//
//  PreferencesFormChrome.swift
//  Cue
//
//  Shared Preferences page chrome: window toolbar style and form top insets.
//

import AppKit
import SwiftUI

enum PreferencesWindowChrome {
    /// Settings scenes often ignore SwiftUI `.windowToolbarStyle`. Force the
    /// compact unified toolbar so traffic lights and the sidebar toggle share
    /// one row, and the detail column does not reserve an empty title band.
    @MainActor
    static func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.toolbar?.displayMode = .iconOnly
    }
}

/// Resolves the hosting `NSWindow` for Preferences and applies compact chrome.
private struct PreferencesHostingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        scheduleApply(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        scheduleApply(from: nsView)
    }

    private func scheduleApply(from view: NSView) {
        DispatchQueue.main.async {
            PreferencesWindowChrome.apply(to: view.window)
        }
    }
}

extension View {
    /// Applies AppKit Preferences window chrome to the hosting settings window.
    func preferencesHostingWindowChrome() -> some View {
        background(PreferencesHostingWindowConfigurator())
    }

    /// Grouped Preferences form with a tighter top content margin under the toolbar.
    func preferencesFormStyle() -> some View {
        formStyle(.grouped)
            .contentMargins(.top, 8, for: .scrollContent)
    }
}

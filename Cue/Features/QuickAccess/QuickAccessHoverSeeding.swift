//
//  QuickAccessHoverSeeding.swift
//  Notinhas
//
//  Pure helpers for re-priming Quick Access card hover after remount.
//

import AppKit
import Foundation

enum QuickAccessHoverSeeding {
    /// Whether hover chrome should be seeded when a card appears under a stationary pointer.
    static func shouldSeedHover(mouseLocation: NSPoint, cardFrame: CGRect) -> Bool {
        guard cardFrame.width > 0, cardFrame.height > 0 else { return false }
        return cardFrame.contains(mouseLocation)
    }

    /// Optional XCTest hook invoked after posting a synthetic mouse-moved event.
    @MainActor
    static var onPostSyntheticMouseEvent: ((NSEvent) -> Void)?

    @MainActor
    static func postSyntheticMouseMoved(
        at location: NSPoint = NSEvent.mouseLocation,
        windowNumber: Int = 0,
    ) {
        guard let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: location,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0,
        ) else { return }

        NSApp.postEvent(event, atStart: false)
        onPostSyntheticMouseEvent?(event)
    }
}

enum QuickAccessMouseMonitorPolicy {
    static func shouldReinstallMonitors(isSuspended: Bool) -> Bool {
        !isSuspended
    }
}

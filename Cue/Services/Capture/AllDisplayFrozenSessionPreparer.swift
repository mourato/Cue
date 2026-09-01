//
//  AllDisplayFrozenSessionPreparer.swift
//  Notinhas
//
//  Prepares an all-display FrozenAreaCaptureSession for area selection flows.
//

import AppKit
import Foundation

enum AllDisplayFrozenSessionPreparer {
    nonisolated static func connectedDisplayIDs(from screens: [NSScreen]) -> Set<CGDirectDisplayID> {
        Set(screens.compactMap(\.displayID))
    }

    nonisolated static func validateCompleteSession(
        _ session: FrozenAreaCaptureSession,
        expectedDisplayIDs: Set<CGDirectDisplayID>,
    ) throws {
        let missing = session.missingSnapshotDisplayIDs(for: expectedDisplayIDs)
        guard missing.isEmpty else {
            throw CaptureError.noDisplayFound
        }
    }

    @MainActor
    static func prepare(
        captureManager: ScreenCaptureManager = .shared,
        screens: [NSScreen] = NSScreen.screens,
        showCursor: Bool,
        excludeDesktopIcons: Bool,
        excludeDesktopWidgets: Bool,
        excludeOwnApplication: Bool,
        prefetchedContentTask: ShareableContentPrefetchTask?,
    ) async throws -> (session: FrozenAreaCaptureSession, mode: String) {
        let expectedDisplayIDs = connectedDisplayIDs(from: screens)
        guard !expectedDisplayIDs.isEmpty else {
            throw CaptureError.noDisplayFound
        }

        let shareableContentTask = prefetchedContentTask ?? captureManager.prefetchShareableContent(
            includeDesktopWindows: excludeDesktopIcons || excludeDesktopWidgets,
        )
        let session = try await FrozenAreaCaptureSession.prepare(
            displayIDs: nil,
            showCursor: showCursor,
            excludeDesktopIcons: excludeDesktopIcons,
            excludeDesktopWidgets: excludeDesktopWidgets,
            excludeOwnApplication: excludeOwnApplication,
            prefetchedContentTask: shareableContentTask,
        )
        try validateCompleteSession(session, expectedDisplayIDs: expectedDisplayIDs)
        return (session, "screencapturekit-all")
    }
}

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

    /// Orders connected displays so the cursor/active display is captured first.
    /// Remaining IDs keep a stable numeric order for deterministic follow-up batches.
    nonisolated static func prioritizedCaptureOrder(
        displayIDs: Set<CGDirectDisplayID>,
        priorityDisplayID: CGDirectDisplayID?
    ) -> (priority: CGDirectDisplayID?, remaining: [CGDirectDisplayID]) {
        guard !displayIDs.isEmpty else { return (nil, []) }
        let priority = priorityDisplayID.flatMap { displayIDs.contains($0) ? $0 : nil }
            ?? displayIDs.min()
        let remaining = displayIDs
            .filter { $0 != priority }
            .sorted()
        return (priority, remaining)
    }

    nonisolated static func validateCompleteSession(
        _ session: FrozenAreaCaptureSession,
        expectedDisplayIDs: Set<CGDirectDisplayID>
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
        priorityDisplayID: CGDirectDisplayID? = nil,
        session: FrozenAreaCaptureSession? = nil,
        onSnapshot: (@MainActor (FrozenDisplaySnapshot) -> Void)? = nil
    ) async throws -> (session: FrozenAreaCaptureSession, mode: String) {
        let expectedDisplayIDs = connectedDisplayIDs(from: screens)
        guard !expectedDisplayIDs.isEmpty else {
            throw CaptureError.noDisplayFound
        }

        let shareableContentTask = prefetchedContentTask ?? captureManager.prefetchShareableContent(
            includeDesktopWindows: excludeDesktopIcons || excludeDesktopWidgets
        )
        let order = prioritizedCaptureOrder(
            displayIDs: expectedDisplayIDs,
            priorityDisplayID: priorityDisplayID
        )
        let session = session ?? FrozenAreaCaptureSession.fromSnapshots([])

        func absorb(_ snapshots: [CGDirectDisplayID: FrozenDisplaySnapshot]) {
            for displayID in snapshots.keys.sorted() {
                guard let snapshot = snapshots[displayID] else { continue }
                session.addSnapshot(snapshot)
                onSnapshot?(snapshot)
            }
        }

        if let priority = order.priority {
            let prioritySnapshots = try await captureManager.captureDisplaySnapshots(
                displayIDs: [priority],
                showCursor: showCursor,
                excludeDesktopIcons: excludeDesktopIcons,
                excludeDesktopWidgets: excludeDesktopWidgets,
                excludeOwnApplication: excludeOwnApplication,
                prefetchedContentTask: shareableContentTask
            )
            absorb(prioritySnapshots)
        }

        if !order.remaining.isEmpty {
            let remainingSnapshots = try await captureManager.captureDisplaySnapshots(
                displayIDs: Set(order.remaining),
                showCursor: showCursor,
                excludeDesktopIcons: excludeDesktopIcons,
                excludeDesktopWidgets: excludeDesktopWidgets,
                excludeOwnApplication: excludeOwnApplication,
                prefetchedContentTask: shareableContentTask
            )
            absorb(remainingSnapshots)
        }

        try validateCompleteSession(session, expectedDisplayIDs: expectedDisplayIDs)
        let mode = order.remaining.isEmpty ? "screencapturekit-priority" : "screencapturekit-priority-then-rest"
        return (session, mode)
    }
}

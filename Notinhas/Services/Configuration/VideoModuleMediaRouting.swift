import Foundation

/// Pure routing helpers for optional Video module open/edit behavior.
/// Keeps History / Quick Access / deep-link decisions testable without AppKit side effects.
enum VideoModuleMediaRouting {
    enum MediaOpenDestination: Equatable {
        case annotate
        case videoEditor
        case revealInFinder
    }

    /// Where History should send a capture when the user opens it.
    static func historyOpenDestination(
        for captureType: CaptureHistoryType,
        videoModuleEnabled: Bool = VideoModuleAvailability.isEnabled,
    ) -> MediaOpenDestination {
        switch captureType {
        case .screenshot:
            .annotate
        case .video, .gif:
            videoModuleEnabled ? .videoEditor : .revealInFinder
        }
    }

    /// Where Quick Access should send a video item on edit / double-click / shortcut.
    static func quickAccessVideoOpenDestination(
        videoModuleEnabled: Bool = VideoModuleAvailability.isEnabled,
    ) -> MediaOpenDestination {
        videoModuleEnabled ? .videoEditor : .revealInFinder
    }

    /// Whether the Quick Access Edit action should be offered for an item.
    static func isEditActionAvailable(
        isVideo: Bool,
        videoModuleEnabled: Bool = VideoModuleAvailability.isEnabled,
    ) -> Bool {
        !isVideo || videoModuleEnabled
    }

    /// Whether video deep links / recording shortcuts may dispatch into capture or the editor.
    static func shouldDispatchVideoAction(
        videoModuleEnabled: Bool = VideoModuleAvailability.isEnabled,
    ) -> Bool {
        videoModuleEnabled
    }
}

//
//  NotinhasDeepLinkHandler.swift
//  Notinhas
//
//  Handles notinhas:// automation URLs for external launchers and workflows.
//

import AppKit
import Foundation

@MainActor
struct NotinhasDeepLinkHandler {
    private let screenCaptureViewModel: ScreenCaptureViewModel

    init(screenCaptureViewModel: ScreenCaptureViewModel) {
        self.screenCaptureViewModel = screenCaptureViewModel
    }

    func handle(_ url: URL) {
        guard UserDefaults.standard.object(forKey: PreferencesKeys.urlSchemeEnabled) as? Bool ?? true else {
            DiagnosticLogger.shared.log(
                .info,
                .action,
                "Ignored deeplink because URL scheme is disabled in preferences",
                context: ["url": url.absoluteString],
            )
            return
        }

        guard let action = NotinhasDeepLinkAction(url: url) else {
            DiagnosticLogger.shared.log(
                .warning,
                .action,
                "Ignored unsupported deeplink",
                context: [
                    "scheme": url.scheme ?? "",
                    "host": url.host ?? "",
                    "path": url.path,
                ],
            )
            return
        }

        DiagnosticLogger.shared.log(
            .info,
            .action,
            "Handling deeplink",
            context: ["action": action.logName],
        )

        switch action {
        case .captureFullscreen:
            screenCaptureViewModel.captureFullscreen()
        case .captureArea:
            screenCaptureViewModel.captureArea()
        case .captureAllInOne:
            screenCaptureViewModel.captureAllInOne()
        case .captureApplication:
            screenCaptureViewModel.captureApplication()
        case .captureActiveWindow:
            screenCaptureViewModel.captureActiveWindow()
        case .captureAreaAnnotate:
            screenCaptureViewModel.captureAreaAnnotate()
        case .captureScrolling:
            screenCaptureViewModel.captureScrolling()
        case .captureOCR:
            screenCaptureViewModel.captureOCR()
        case .captureSmartElement:
            SmartElementCaptureController.shared.startCapture()
        case .captureObjectCutout:
            screenCaptureViewModel.captureObjectCutout()
        case .recordScreen:
            guard VideoModuleMediaRouting.shouldDispatchVideoAction() else {
                logIgnoredVideoDeepLink(action: action)
                return
            }
            #if CUE_VIDEO_MODULE
                screenCaptureViewModel.startRecordingFlow()
            #endif
        case .recordApplication:
            guard VideoModuleMediaRouting.shouldDispatchVideoAction() else {
                logIgnoredVideoDeepLink(action: action)
                return
            }
            #if CUE_VIDEO_MODULE
                screenCaptureViewModel.startApplicationRecordingFlow()
            #endif
        case .openAnnotate:
            AnnotateManager.shared.openEmptyAnnotation()
            NSApp.activate(ignoringOtherApps: true)
        case .openCombine(let fileURLs):
            if fileURLs.count >= 2 {
                AnnotateManager.shared.openCombineImages(urls: fileURLs)
            } else {
                CombineImagesCoordinator.shared.presentPicker()
            }
            NSApp.activate(ignoringOtherApps: true)
        case .openVideoEditor:
            guard VideoModuleMediaRouting.shouldDispatchVideoAction() else {
                logIgnoredVideoDeepLink(action: action)
                return
            }
            #if CUE_VIDEO_MODULE
                VideoEditorManager.shared.openEmptyEditor()
            #endif
            NSApp.activate(ignoringOtherApps: true)
        case .openHistory:
            HistoryFloatingManager.shared.toggle()
        case .showShortcuts:
            ShortcutOverlayManager.shared.toggle()
        case .openSettings(let tab):
            AppStatusBarController.shared.openPreferencesWindow(tab: tab)
        }
    }

    private func logIgnoredVideoDeepLink(action: NotinhasDeepLinkAction) {
        DiagnosticLogger.shared.log(
            .info,
            .action,
            "Ignored deeplink because video module is disabled",
            context: ["action": action.logName],
        )
    }
}

enum NotinhasDeepLinkAction: Equatable {
    case captureFullscreen
    case captureArea
    case captureAllInOne
    case captureApplication
    case captureActiveWindow
    case captureAreaAnnotate
    case captureScrolling
    case captureOCR
    case captureSmartElement
    case captureObjectCutout
    case recordScreen
    case recordApplication
    case openAnnotate
    case openCombine([URL])
    case openVideoEditor
    case openHistory
    case showShortcuts
    case openSettings(PreferencesTab?)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "notinhas" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = url.host?.lowercased()
        let pathParts = url.path.split(separator: "/").map { $0.lowercased() }
        let parts = ([host] + pathParts).compactMap(\.self)
        let command = parts.joined(separator: "/")

        switch command {
        case "capture/fullscreen", "capture-screen", "capture-fullscreen", "fullscreen", "screenshot/fullscreen":
            self = .captureFullscreen
        case "capture/area", "capture-area", "area", "screenshot/area":
            self = .captureArea
        case "capture/all-in-one", "capture-all-in-one", "all-in-one", "screenshot/all-in-one":
            self = .captureAllInOne
        case "capture/application", "capture/window", "application-capture", "window-capture", "screenshot/window":
            self = .captureApplication
        case "capture/active-window", "capture/focused-window", "active-window-capture",
             "active-window", "screenshot/active-window":
            self = .captureActiveWindow
        case "capture/area-annotate", "capture-area-annotate", "area-annotate", "screenshot/area-annotate":
            self = .captureAreaAnnotate
        case "capture/scrolling", "scrolling-capture", "capture-scrolling", "scrolling", "screenshot/scrolling":
            self = .captureScrolling
        case "capture/ocr", "capture/text", "capture-text", "ocr", "text":
            self = .captureOCR
        case "capture/smart-element", "smart-element", "capture-smart-element", "smart":
            self = .captureSmartElement
        case "capture/object-cutout", "object-cutout", "capture-object-cutout", "cutout":
            self = .captureObjectCutout
        case "record/screen", "record-screen", "screen-recording", "recording", "record":
            self = .recordScreen
        case "record/application", "record/window", "application-recording", "window-recording", "recording/window":
            self = .recordApplication
        case "open/annotate", "annotate", "open-annotate":
            self = .openAnnotate
        case "open/combine", "combine", "combine-images", "open-combine":
            self = .openCombine(Self.combineFileURLs(from: components))
        case "open/video-editor", "video-editor", "edit-video", "open-video-editor":
            self = .openVideoEditor
        case "open/history", "history", "capture-history":
            self = .openHistory
        case "show/shortcuts", "shortcuts", "keyboard-shortcuts", "show-shortcuts":
            self = .showShortcuts
        case "settings", "preferences":
            self = .openSettings(Self.preferencesTab(from: components, pathParts: pathParts))
        case "settings/about", "preferences/about":
            return nil
        case let value where value.hasPrefix("settings/"):
            self = .openSettings(Self.preferencesTab(from: components, pathParts: pathParts))
        case let value where value.hasPrefix("preferences/"):
            self = .openSettings(Self.preferencesTab(from: components, pathParts: pathParts))
        default:
            return nil
        }
    }

    var logName: String {
        switch self {
        case .captureFullscreen: "captureFullscreen"
        case .captureArea: "captureArea"
        case .captureAllInOne: "captureAllInOne"
        case .captureApplication: "captureApplication"
        case .captureActiveWindow: "captureActiveWindow"
        case .captureAreaAnnotate: "captureAreaAnnotate"
        case .captureScrolling: "captureScrolling"
        case .captureOCR: "captureOCR"
        case .captureSmartElement: "captureSmartElement"
        case .captureObjectCutout: "captureObjectCutout"
        case .recordScreen: "recordScreen"
        case .recordApplication: "recordApplication"
        case .openAnnotate: "openAnnotate"
        case .openCombine(let fileURLs): "openCombine(\(fileURLs.count))"
        case .openVideoEditor: "openVideoEditor"
        case .openHistory: "openHistory"
        case .showShortcuts: "showShortcuts"
        case .openSettings(let tab): "openSettings(\(String(describing: tab)))"
        }
    }

    private static func combineFileURLs(from components: URLComponents?) -> [URL] {
        components?.queryItems?
            .filter { $0.name.lowercased() == "file" }
            .compactMap { item in
                guard let value = item.value, !value.isEmpty else { return nil }
                if let url = URL(string: value), url.isFileURL {
                    return url.standardizedFileURL
                }
                return URL(fileURLWithPath: (value as NSString).expandingTildeInPath).standardizedFileURL
            } ?? []
    }

    private static func preferencesTab(from components: URLComponents?, pathParts: [String]) -> PreferencesTab? {
        let queryTab = components?.queryItems?
            .first(where: { $0.name.lowercased() == "tab" })?
            .value?
            .lowercased()

        let pathTab = pathParts.first
        return preferencesTab(named: queryTab ?? pathTab)
    }

    private static func preferencesTab(named name: String?) -> PreferencesTab? {
        switch name {
        case "general":
            .general
        case "capture", "screenshots", "screenshot":
            .capture
        case "annotate", "annotation", "annotations":
            .annotate
        case "quick-access", "quickaccess":
            .quickAccess
        case "history":
            .history
        case "shortcuts", "keyboard-shortcuts":
            .shortcuts
        case "permissions", "privacy":
            .permissions
        case "uploads":
            .cloud
        case "advanced", "configuration", "config", "toml":
            .advanced
        case "about":
            nil
        default:
            nil
        }
    }
}

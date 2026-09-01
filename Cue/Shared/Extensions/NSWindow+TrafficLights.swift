//
//  NSWindow+TrafficLights.swift
//  Notinhas
//
//  Reusable NSWindow extension for traffic light button positioning
//

import AppKit
import ObjectiveC

// MARK: - Configuration

/// Configuration for traffic light button positioning relative to a custom toolbar.
struct TrafficLightConfiguration: Equatable {
    enum VerticalAlignment: Equatable {
        /// Center on custom toolbar items (`toolbarVerticalPadding` + `toolbarItemHeight`).
        case toolbar
        /// Center inside the system titlebar container (splash / chrome-only windows).
        case titlebar
    }

    var verticalAlignment: VerticalAlignment = .toolbar

    /// Extra top inset above the toolbar padding (window chrome / safe area).
    var toolbarTopPadding: CGFloat = 0

    /// Matches `WindowSpacingConfiguration.toolbarVPadding` so lights center on toolbar items.
    var toolbarVerticalPadding: CGFloat = 8

    /// Height of toolbar controls (matches `ToolbarButton` frame).
    var toolbarItemHeight: CGFloat = 28

    /// Optical vertical nudge after geometric centering (positive moves lights up in AppKit coords).
    var toolbarGap: CGFloat = 0

    /// Leading inset from the window's left edge.
    var horizontalOffset: CGFloat = 12

    /// Gap between close / miniaturize / zoom.
    var buttonSpacing: CGFloat = 8

    static let `default` = TrafficLightConfiguration()

    /// Titlebar-centered layout for windows without a custom toolbar strip.
    static let titlebarCentered = TrafficLightConfiguration(verticalAlignment: .titlebar)
}

// MARK: - NSWindow API

extension NSWindow {
    /// Install stable traffic-light layout for this window.
    ///
    /// Applies after AppKit's layout (next main run-loop turn) and reapplies on
    /// resize / key changes / external frame resets. Do **not** call from
    /// `NSWindow.layoutIfNeeded()` — that path crashes under Swift 6 executor bridging.
    @MainActor
    func installTrafficLightsLayout(config: TrafficLightConfiguration = .default) {
        if let controller = trafficLightsLayoutController {
            controller.updateConfig(config)
            return
        }

        let controller = TrafficLightsLayoutController(window: self, config: config)
        trafficLightsLayoutController = controller
        controller.start()
    }

    /// Position traffic light buttons once using `config`.
    ///
    /// Prefer `installTrafficLightsLayout(config:)` so positions survive AppKit layout.
    @MainActor
    func layoutTrafficLights(config: TrafficLightConfiguration = .default) {
        guard let frames = trafficLightFrames(config: config) else { return }

        frames.close.frame.origin = frames.closeOrigin
        frames.miniaturize.frame.origin = frames.miniaturizeOrigin
        frames.zoom.frame.origin = frames.zoomOrigin
    }

    @MainActor
    fileprivate func trafficLightsNeedLayout(config: TrafficLightConfiguration) -> Bool {
        guard let frames = trafficLightFrames(config: config) else { return false }
        let epsilon: CGFloat = 0.5
        return abs(frames.close.frame.origin.x - frames.closeOrigin.x) > epsilon
            || abs(frames.close.frame.origin.y - frames.closeOrigin.y) > epsilon
            || abs(frames.miniaturize.frame.origin.x - frames.miniaturizeOrigin.x) > epsilon
            || abs(frames.miniaturize.frame.origin.y - frames.miniaturizeOrigin.y) > epsilon
            || abs(frames.zoom.frame.origin.x - frames.zoomOrigin.x) > epsilon
            || abs(frames.zoom.frame.origin.y - frames.zoomOrigin.y) > epsilon
    }

    @MainActor
    private func trafficLightFrames(
        config: TrafficLightConfiguration,
    ) -> (
        close: NSButton,
        miniaturize: NSButton,
        zoom: NSButton,
        closeOrigin: NSPoint,
        miniaturizeOrigin: NSPoint,
        zoomOrigin: NSPoint,
    )? {
        guard let closeButton = standardWindowButton(.closeButton),
              let miniaturizeButton = standardWindowButton(.miniaturizeButton),
              let zoomButton = standardWindowButton(.zoomButton),
              let container = closeButton.superview
        else {
            return nil
        }

        let trafficLightHeight = closeButton.frame.height
        let yPosition: CGFloat
        switch config.verticalAlignment {
        case .toolbar:
            let toolbarItemCenterFromTop = config.toolbarTopPadding
                + config.toolbarVerticalPadding
                + (config.toolbarItemHeight / 2)
            // AppKit button frames are bottom-left relative to the titlebar container.
            yPosition = container.bounds.height
                - toolbarItemCenterFromTop
                - (trafficLightHeight / 2)
                + config.toolbarGap
        case .titlebar:
            yPosition = ((container.bounds.height - trafficLightHeight) / 2) + config.toolbarGap
        }

        let closeOrigin = NSPoint(x: config.horizontalOffset, y: yPosition)
        let miniaturizeOrigin = NSPoint(
            x: closeOrigin.x + closeButton.frame.width + config.buttonSpacing,
            y: yPosition,
        )
        let zoomOrigin = NSPoint(
            x: miniaturizeOrigin.x + miniaturizeButton.frame.width + config.buttonSpacing,
            y: yPosition,
        )

        return (
            closeButton,
            miniaturizeButton,
            zoomButton,
            closeOrigin,
            miniaturizeOrigin,
            zoomOrigin,
        )
    }
}

// MARK: - Associated controller

/// Address token for `objc_setAssociatedObject` only — never read or mutated as shared state.
private enum TrafficLightsAssociation {
    nonisolated(unsafe) static var controller: UInt8 = 0
}

private extension NSWindow {
    @MainActor
    var trafficLightsLayoutController: TrafficLightsLayoutController? {
        get {
            objc_getAssociatedObject(self, &TrafficLightsAssociation.controller)
                as? TrafficLightsLayoutController
        }
        set {
            objc_setAssociatedObject(
                self,
                &TrafficLightsAssociation.controller,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC,
            )
        }
    }
}

/// Keeps traffic lights aligned without overriding `NSWindow.layoutIfNeeded()`.
///
/// Uses selector-based notifications (not `@Sendable` closures) so Swift 6
/// concurrency stays sound on the main actor.
@MainActor
private final class TrafficLightsLayoutController: NSObject {
    private weak var window: NSWindow?
    private var config: TrafficLightConfiguration
    private weak var observedCloseButton: NSView?
    private var isApplying = false
    private var applyScheduled = false
    private var isObservingWindow = false

    init(window: NSWindow, config: TrafficLightConfiguration) {
        self.window = window
        self.config = config
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        guard let window, !isObservingWindow else {
            scheduleApply()
            return
        }

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleWindowEvent),
            name: NSWindow.didResizeNotification,
            object: window,
        )
        center.addObserver(
            self,
            selector: #selector(handleWindowEvent),
            name: NSWindow.didEndLiveResizeNotification,
            object: window,
        )
        center.addObserver(
            self,
            selector: #selector(handleWindowEvent),
            name: NSWindow.didBecomeKeyNotification,
            object: window,
        )
        center.addObserver(
            self,
            selector: #selector(handleWindowEvent),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
        isObservingWindow = true
        scheduleApply()
    }

    func updateConfig(_ config: TrafficLightConfiguration) {
        self.config = config
        scheduleApply()
    }

    @objc private func handleWindowEvent(_ notification: Notification) {
        if notification.name == NSWindow.didResizeNotification {
            apply()
        }
        scheduleApply()
    }

    @objc private func handleCloseButtonFrameChange(_: Notification) {
        guard !isApplying else { return }
        apply()
    }

    private func scheduleApply() {
        guard !applyScheduled else { return }
        applyScheduled = true
        // Defer past AppKit's current layout/display work so our frames stick.
        Task { @MainActor [weak self] in
            guard let self else { return }
            applyScheduled = false
            apply()
        }
    }

    private func apply() {
        guard let window, !isApplying else { return }

        observeCloseButtonFrameIfNeeded()

        guard window.trafficLightsNeedLayout(config: config) else { return }

        isApplying = true
        window.layoutTrafficLights(config: config)
        isApplying = false
    }

    /// Re-apply when AppKit resets button frames outside resize notifications.
    private func observeCloseButtonFrameIfNeeded() {
        guard let closeButton = window?.standardWindowButton(.closeButton) else { return }
        guard observedCloseButton !== closeButton else { return }

        if let observedCloseButton {
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.frameDidChangeNotification,
                object: observedCloseButton,
            )
        }

        observedCloseButton = closeButton
        closeButton.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseButtonFrameChange),
            name: NSView.frameDidChangeNotification,
            object: closeButton,
        )
    }
}

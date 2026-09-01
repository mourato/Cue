//
//  CaptureFloatingHUDWindow.swift
//  Notinhas
//
//  Reusable borderless floating panel for capture HUD toolbars.
//

import AppKit
import SwiftUI

enum CaptureFloatingHUDDisplayLevel: Equatable {
    case standard
    case aboveCaptureOverlay
}

private final class CaptureFloatingHUDHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}

@MainActor
final class CaptureFloatingHUDWindow: NSPanel {
    private var anchorRect: CGRect = .zero
    private var cachedContentSize: CGSize?
    private var hostingView: CaptureFloatingHUDHostingView?
    private(set) var displayLevel: CaptureFloatingHUDDisplayLevel = .standard

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        configureWindow()
    }

    func setContent(_ view: AnyView) {
        let themedView = view.preferredColorScheme(ThemeManager.shared.systemAppearance)
        let hosting = CaptureFloatingHUDHostingView(rootView: AnyView(themedView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear

        let fittingSize = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: fittingSize)

        contentView = hosting
        hostingView = hosting

        setContentSize(fittingSize)
        cachedContentSize = fittingSize
        invalidateShadow()
        installPointerTrackingIfNeeded(on: hosting)
    }

    /// Drops SwiftUI hosting before the panel is released so `@MainActor`
    /// `ObservableObject` graphs are not torn down inside nested coordinator teardown.
    func clearContent() {
        hostingView = nil
        contentView = nil
        cachedContentSize = nil
    }

    private func installPointerTrackingIfNeeded(on view: NSView) {
        for area in view.trackingAreas {
            view.removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil,
        )
        view.addTrackingArea(area)
    }

    func setDisplayLevel(_ level: CaptureFloatingHUDDisplayLevel, orderFront: Bool = false) {
        displayLevel = level
        switch level {
        case .standard:
            self.level = .popUpMenu
        case .aboveCaptureOverlay:
            self.level = .screenSaver
        }
        if orderFront {
            orderFrontRegardless()
        }
    }

    func show(anchorRect: CGRect, screen: NSScreen? = nil) {
        self.anchorRect = anchorRect
        positionNearAnchor(screen: screen)
        orderFrontRegardless()
    }

    func show(at origin: CGPoint) {
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    func showAboveCaptureOverlay() {
        setDisplayLevel(.aboveCaptureOverlay, orderFront: true)
    }

    func restoreStandardDisplayLevel() {
        setDisplayLevel(.standard)
    }

    func updateAnchorRect(_ rect: CGRect) {
        anchorRect = rect
        positionNearAnchor(screen: nil)
    }

    func refreshContentSize(reposition: Bool = true) {
        guard let hostingView else { return }

        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize

        hostingView.frame = CGRect(origin: .zero, size: fittingSize)
        setContentSize(fittingSize)
        cachedContentSize = fittingSize
        invalidateShadow()
        if reposition {
            positionNearAnchor(screen: nil)
        }
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Floating HUDs stay non-key, so AppKit cursor rects rarely apply. Force the
    /// standard arrow whenever the pointer enters this panel (All-In-One / capture chrome).
    override func cursorUpdate(with _: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseEntered(with: event)
    }

    private func configureWindow() {
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        sharingType = .none
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        appearance = ThemeManager.shared.nsAppearance
        acceptsMouseMovedEvents = true
    }

    private func positionNearAnchor(screen: NSScreen?) {
        guard let size = cachedContentSize ?? contentView?.fittingSize else { return }

        let resolvedScreen = screen
            ?? NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) })
            ?? ScreenUtility.activeScreen()
        let screenFrame = resolvedScreen.visibleFrame

        let origin = CaptureFloatingToolbarPlacement.frameOrigin(
            toolbarSize: size,
            anchorRect: anchorRect,
            screenFrame: screenFrame,
        )

        setFrameOrigin(origin)
    }
}

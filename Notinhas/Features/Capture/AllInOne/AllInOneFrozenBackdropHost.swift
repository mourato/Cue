//
//  AllInOneFrozenBackdropHost.swift
//  Notinhas
//
//  Presents per-display static frozen backdrops below All-In-One refinement overlays.
//

import AppKit

@MainActor
final class AllInOneFrozenBackdropHost {
    static let windowLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)

    private final class BackdropPanel: NSPanel {
        init(screen: NSScreen, backdrop: AreaSelectionBackdrop) {
            super.init(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
            )
            isOpaque = true
            backgroundColor = .black
            hasShadow = false
            ignoresMouseEvents = true
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            // Keep the frozen pixels above normal app windows, but below the selection
            // overlays and All-In-One HUDs that are ordered after this host.
            level = AllInOneFrozenBackdropHost.windowLevel

            let imageView = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
            imageView.imageScaling = .scaleAxesIndependently
            imageView.autoresizingMask = [.width, .height]
            imageView.image = NSImage(
                cgImage: backdrop.image,
                size: NSSize(
                    width: CGFloat(backdrop.image.width) / backdrop.scaleFactor,
                    height: CGFloat(backdrop.image.height) / backdrop.scaleFactor,
                ),
            )
            contentView = imageView
        }
    }

    private var panels: [ObjectIdentifier: BackdropPanel] = [:]

    func present(backdrops: [CGDirectDisplayID: AreaSelectionBackdrop]) {
        tearDown()
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID, let backdrop = backdrops[displayID] else { continue }
            let panel = BackdropPanel(screen: screen, backdrop: backdrop)
            panel.setFrame(screen.frame, display: false)
            panel.orderFrontRegardless()
            panels[ObjectIdentifier(screen)] = panel
        }
    }

    func tearDown() {
        for panel in panels.values {
            panel.close()
        }
        panels.removeAll()
    }
}

import AppKit
import SwiftUI

@MainActor
final class OverlayTooltipPresenter {
    static let shared = OverlayTooltipPresenter()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayTooltipBubbleView>?
    private var currentOwner: UUID?

    #if DEBUG
        var testingSuppressPresentation = false
    #endif

    private init() {}

    func show(
        _ content: OverlayTooltipContent,
        anchorScreenFrame: CGRect,
        preferred: OverlayTooltipEdge,
        owner: UUID,
    ) {
        let bubble = OverlayTooltipBubbleView(content: content)
        let host = hostingView ?? NSHostingView(rootView: bubble)
        host.rootView = bubble
        let size = host.fittingSize
        guard size.width > 0, size.height > 0 else { return }

        let screen = NSScreen.screens.first { $0.frame.intersects(anchorScreenFrame) }
            ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        // Claim ownership only after show preconditions succeed, so a failed show
        // does not orphan the previous owner or leave a stuck currentOwner.
        currentOwner = owner

        let frame = OverlayTooltipPlacement.frame(
            anchor: anchorScreenFrame,
            tooltipSize: size,
            visibleFrame: visibleFrame,
            preferred: preferred,
        )

        #if DEBUG
            if testingSuppressPresentation {
                return
            }
        #endif

        let panel = panel ?? makePanel()
        panel.contentView = host
        hostingView = host
        self.panel = panel

        if panel.isVisible {
            panel.setFrame(frame, display: true)
        } else {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    /// Hides the tooltip only if `owner` is the one currently showing.
    func hide(owner: UUID) {
        guard currentOwner == owner else { return }
        currentOwner = nil
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    #if DEBUG
        /// Test seam: current show owner without exposing panel internals.
        var testingCurrentOwner: UUID? {
            currentOwner
        }
    #endif

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

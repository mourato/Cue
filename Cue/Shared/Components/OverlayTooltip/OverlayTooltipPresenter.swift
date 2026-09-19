import AppKit
import SwiftUI

@MainActor
final class OverlayTooltipPresenter {
    static let shared = OverlayTooltipPresenter()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayTooltipBubbleView>?
    private var currentOwner: UUID?
    private var presentationGeneration = 0

    #if DEBUG
        var testingSuppressPresentation = false
    #endif

    private init() {}

    func presentationToken() -> Int {
        presentationGeneration
    }

    func show(
        _ content: OverlayTooltipContent,
        anchorScreenFrame: CGRect,
        preferred: OverlayTooltipEdge,
        owner: UUID,
        token: Int
    ) {
        guard token == presentationGeneration else { return }

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
        presentationGeneration += 1
        currentOwner = owner

        let frame = OverlayTooltipPlacement.frame(
            anchor: anchorScreenFrame,
            tooltipSize: size,
            visibleFrame: visibleFrame,
            preferred: preferred
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
        panel.alphaValue = 1

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
        presentationGeneration += 1
        let generation = presentationGeneration
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().alphaValue = 0
        } completionHandler: {
            guard self.presentationGeneration == generation, self.currentOwner == nil else { return }
            panel.orderOut(nil)
        }
    }

    /// Dismisses the shared panel independently of any SwiftUI view lifecycle.
    func dismissImmediately() {
        presentationGeneration += 1
        currentOwner = nil
        panel?.orderOut(nil)
        panel?.alphaValue = 1
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
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.fullScreenAuxiliary, .transient]
        return panel
    }
}

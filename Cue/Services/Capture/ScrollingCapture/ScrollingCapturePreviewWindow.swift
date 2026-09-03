//
//  ScrollingCapturePreviewWindow.swift
//  Notinhas
//
//  Floating non-interactive preview window for scrolling capture sessions.
//

import AppKit
import Combine
import SwiftUI

struct ScrollingCapturePreviewLayoutSignature: Equatable {
    let anchorRect: CGRect
    let selectedRect: CGRect
    let imageSize: CGSize?
    let caption: String
    let badgeLabel: String?
    let phase: String
    let maxImageHeight: Int
}

final class ScrollingCapturePreviewWindow: NSPanel {
    private var anchorRect: CGRect
    private let model: ScrollingCaptureSessionModel
    private var modelObservation: AnyCancellable?
    private var layoutUpdateScheduled = false
    private var lastLayoutSignature: ScrollingCapturePreviewLayoutSignature?

    init(anchorRect: CGRect, model: ScrollingCaptureSessionModel) {
        self.anchorRect = anchorRect
        self.model = model

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )

        isFloatingPanel = true
        // Keep the preview above the interactive region overlay (.floating)
        // while still leaving the HUD on top at .popUpMenu.
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        sharingType = .none
        hasShadow = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        refreshContentView()
        modelObservation = model.objectWillChange.sink { [weak self] _ in
            self?.scheduleLayoutUpdate()
        }

        updateLayout()
    }

    func updateAnchorRect(_ rect: CGRect) {
        anchorRect = rect
        refreshContentView()
        updateLayout()
    }

    private func refreshContentView() {
        contentView = NSHostingView(
            rootView: ScrollingCapturePreviewView(
                model: model,
                maxImageHeight: currentMaxImageHeight(),
            ),
        )
    }

    private func updateLayout() {
        lastLayoutSignature = Self.layoutSignature(for: model, anchorRect: anchorRect)
        contentView?.invalidateIntrinsicContentSize()
        contentView?.layoutSubtreeIfNeeded()
        let size =
            contentView?.fittingSize
                ?? CGSize(
                    width: ScrollingCapturePreviewLayout.previewWidth,
                    height: 236,
                )
        let targetFrame = Self.panelFrame(
            anchorRect: anchorRect,
            panelSize: size,
            visibleFrame: targetVisibleFrame(),
        )

        if frame != targetFrame {
            if model.phase == .capturing {
                setFrame(targetFrame, display: true)
            } else {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.animator().setFrame(targetFrame, display: true)
                }
            }
        }
    }

    private func scheduleLayoutUpdate() {
        guard !layoutUpdateScheduled else { return }
        layoutUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            layoutUpdateScheduled = false
            let signature = Self.layoutSignature(for: model, anchorRect: anchorRect)
            guard signature != lastLayoutSignature else { return }
            if signature.maxImageHeight != lastLayoutSignature?.maxImageHeight {
                refreshContentView()
            }
            updateLayout()
        }
    }

    static func layoutSignature(
        for model: ScrollingCaptureSessionModel,
        anchorRect: CGRect,
    ) -> ScrollingCapturePreviewLayoutSignature {
        let visibleFrame = targetVisibleFrame(for: anchorRect)
        let maxImageHeight = Int(ScrollingCapturePreviewLayout.maxImageHeight(
            anchorRect: anchorRect,
            visibleFrame: visibleFrame,
        ).rounded())
        return ScrollingCapturePreviewLayoutSignature(
            anchorRect: anchorRect,
            selectedRect: model.selectedRect,
            imageSize: model.activePreviewImage.map { CGSize(width: $0.width, height: $0.height) },
            caption: model.previewCaption,
            badgeLabel: model.previewTruthState.badgeLabel,
            phase: phaseName(model.phase),
            maxImageHeight: maxImageHeight,
        )
    }

    static func panelFrame(
        anchorRect: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect,
    ) -> CGRect {
        let origin = panelOrigin(
            anchorRect: anchorRect,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
        )
        return CGRect(origin: origin, size: panelSize)
    }

    static func panelOrigin(
        anchorRect: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect,
    ) -> CGPoint {
        let x = horizontalOrigin(
            anchorRect: anchorRect,
            panelWidth: panelSize.width,
            visibleFrame: visibleFrame,
        )
        let anchorBottom = anchorRect.minY - ScrollingCapturePreviewLayout.selectionBorderOutset
        let ceilingY = visibleFrame.maxY - ScrollingCapturePreviewLayout.panelTopInset
        let panelBottom = anchorBottom + panelSize.height <= ceilingY
            ? anchorBottom
            : ceilingY - panelSize.height
        return CGPoint(x: x, y: panelBottom)
    }

    static func horizontalOrigin(
        anchorRect: CGRect,
        panelWidth: CGFloat,
        visibleFrame: CGRect,
    ) -> CGFloat {
        let margin = ScrollingCapturePreviewLayout.panelHorizontalMargin
        let inset = ScrollingCapturePreviewLayout.panelScreenEdgeInset
        let preferredX = anchorRect.maxX + margin
        let fallbackX = anchorRect.minX - margin - panelWidth
        return preferredX + panelWidth <= visibleFrame.maxX - inset
            ? preferredX
            : max(visibleFrame.minX + inset, fallbackX)
    }

    private func currentMaxImageHeight() -> CGFloat {
        ScrollingCapturePreviewLayout.maxImageHeight(
            anchorRect: anchorRect,
            visibleFrame: targetVisibleFrame(),
        )
    }

    private func targetVisibleFrame() -> CGRect {
        Self.targetVisibleFrame(for: anchorRect)
    }

    private static func targetVisibleFrame(for anchorRect: CGRect) -> CGRect {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) }) ?? NSScreen.main
        return screen?.visibleFrame ?? .zero
    }

    private static func phaseName(_ phase: ScrollingCapturePhase) -> String {
        switch phase {
        case .ready: "ready"
        case .capturing: "capturing"
        case .finalizing: "finalizing"
        case .saving: "saving"
        }
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

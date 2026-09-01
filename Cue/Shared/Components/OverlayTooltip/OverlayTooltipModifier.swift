import AppKit
import SwiftUI

extension View {
    /// Shows an Arc-like overlay tooltip on hover.
    func overlayTooltip(
        _ title: String,
        keys: [String] = [],
        secondary: String? = nil,
        edge: OverlayTooltipEdge = .below,
        delay: TimeInterval = 0.35,
    ) -> some View {
        modifier(OverlayTooltipModifier(
            content: OverlayTooltipContent(title: title, keys: keys, secondary: secondary),
            edge: edge,
            delay: delay,
        ))
    }
}

enum OverlayTooltipScreenCoordinates {
    /// Converts a SwiftUI `.global` rect (top-left origin, y down) to AppKit screen space.
    static func screenFrame(fromSwiftUIGlobal global: CGRect) -> CGRect? {
        guard global.width > 0, global.height > 0 else { return nil }

        for window in NSApp.windows where window.isVisible && !window.isMiniaturized {
            guard let contentView = window.contentView else { continue }
            let contentHeight = contentView.bounds.height
            let windowRect = CGRect(
                x: global.minX,
                y: contentHeight - global.maxY,
                width: global.width,
                height: global.height,
            )
            let center = CGPoint(x: windowRect.midX, y: windowRect.midY)
            guard contentView.bounds.contains(center) else { continue }
            return window.convertToScreen(windowRect)
        }

        guard let screen = NSScreen.main else { return nil }
        return CGRect(
            x: global.minX,
            y: screen.frame.maxY - global.maxY,
            width: global.width,
            height: global.height,
        )
    }
}

private struct OverlayTooltipModifier: ViewModifier {
    let content: OverlayTooltipContent
    let edge: OverlayTooltipEdge
    let delay: TimeInterval

    @State private var anchorBounds: CGRect = .zero
    @State private var owner = UUID()
    @State private var showWorkItem: DispatchWorkItem?

    func body(content viewContent: Content) -> some View {
        viewContent
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            anchorBounds = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { newValue in
                            anchorBounds = newValue
                        }
                }
                .allowsHitTesting(false)
            }
            .onHover { hovering in
                if hovering {
                    scheduleShow()
                } else {
                    cancelAndHide()
                }
            }
            .onDisappear { cancelAndHide() }
    }

    private func scheduleShow() {
        showWorkItem?.cancel()
        let work = DispatchWorkItem {
            guard let frame = OverlayTooltipScreenCoordinates.screenFrame(fromSwiftUIGlobal: anchorBounds) else {
                return
            }
            OverlayTooltipPresenter.shared.show(
                content,
                anchorScreenFrame: frame,
                preferred: edge,
                owner: owner,
            )
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelAndHide() {
        showWorkItem?.cancel()
        showWorkItem = nil
        OverlayTooltipPresenter.shared.hide(owner: owner)
    }
}

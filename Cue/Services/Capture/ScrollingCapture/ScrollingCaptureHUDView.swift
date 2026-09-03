//
//  ScrollingCaptureHUDView.swift
//  Notinhas
//
//  SwiftUI content for the scrolling capture control HUD.
//

import SwiftUI

struct ScrollingCaptureHUDView: View {
    @ObservedObject var model: ScrollingCaptureSessionModel
    let onDone: () -> Void
    let onCancel: () -> Void
    let onToggleAutoScroll: () -> Void

    /// Buttons-only island: no title, summary, or divider — larger
    /// regular-size actions for cancel, auto scroll, and done.
    var body: some View {
        HStack(spacing: 8) {
            Button(L10n.Common.cancel, action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!model.canCancelSession)

            Button(action: onToggleAutoScroll) {
                Label(
                    model.isAutoScrolling ? L10n.ScrollingCapture.stopAutoScroll : L10n.ScrollingCapture.autoScroll,
                    systemImage: model.isAutoScrolling ? "stop.circle.fill" : "play.circle.fill",
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!model.canToggleAutoScroll)

            Button(L10n.Common.done, action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!model.canFinishCapture)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12)),
        )
    }
}

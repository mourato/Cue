//
//  OCRLinkPromptManager.swift
//  Notinhas
//
//  Floating prompt shown after OCR capture when the recognized text contains
//  web links, offering to open them (CleanShot-style). Unlike AppToastManager
//  the panel accepts mouse input so the links are clickable.
//

import AppKit
import SwiftUI

@MainActor
final class OCRLinkPromptManager {
  static let shared = OCRLinkPromptManager()

  private static let autoDismissDelay: TimeInterval = 10
  fileprivate static let panelWidth: CGFloat = 380

  private var panel: NSPanel?
  private var dismissTask: Task<Void, Never>?
  private var activePresentationID = UUID()

  private init() {}

  func show(links: [URL]) {
    guard !links.isEmpty, let screen = targetScreen() else { return }

    dismissTask?.cancel()
    dismissTask = nil
    panel?.orderOut(nil)
    panel = nil

    let presentationID = UUID()
    activePresentationID = presentationID

    let content = OCRLinkPromptView(
      links: links,
      onOpen: { [weak self] url in
        NSWorkspace.shared.open(url)
        DiagnosticLogger.shared.log(.info, .ocr, "OCR link prompt opened link", context: ["host": url.host ?? ""])
        self?.dismiss(presentationID: presentationID)
      },
      onClose: { [weak self] in
        self?.dismiss(presentationID: presentationID)
      },
      onHoverChange: { [weak self] hovering in
        self?.setHoverPaused(hovering, presentationID: presentationID)
      }
    )

    let hostingView = NSHostingView(rootView: content)
    let fittingSize = hostingView.fittingSize
    let size = CGSize(width: Self.panelWidth, height: max(52, fittingSize.height))

    let frame = FeedbackPanelPlacement.frame(
      in: screen.visibleFrame,
      panelSize: size,
      slot: .bottomCenterRaised
    )

    let newPanel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    newPanel.level = .statusBar
    newPanel.isOpaque = false
    newPanel.backgroundColor = .clear
    newPanel.hasShadow = false
    newPanel.hidesOnDeactivate = false
    newPanel.ignoresMouseEvents = false
    newPanel.becomesKeyOnlyIfNeeded = true
    newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    newPanel.contentView = hostingView
    newPanel.alphaValue = 0
    newPanel.orderFrontRegardless()
    panel = newPanel

    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      newPanel.animator().alphaValue = 1
    }

    scheduleAutoDismiss(presentationID: presentationID)
    DiagnosticLogger.shared.log(
      .info,
      .ocr,
      "OCR link prompt shown",
      context: ["linkCount": "\(links.count)"]
    )
  }

  private func scheduleAutoDismiss(presentationID: UUID) {
    dismissTask?.cancel()
    dismissTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: UInt64(Self.autoDismissDelay * 1_000_000_000))
        self?.dismiss(presentationID: presentationID)
      } catch {
        // Cancelled — a newer presentation or hover pause took over.
      }
    }
  }

  private func setHoverPaused(_ paused: Bool, presentationID: UUID) {
    guard presentationID == activePresentationID else { return }
    if paused {
      dismissTask?.cancel()
      dismissTask = nil
    } else {
      scheduleAutoDismiss(presentationID: presentationID)
    }
  }

  private func dismiss(presentationID: UUID) {
    guard presentationID == activePresentationID else { return }
    dismissTask?.cancel()
    dismissTask = nil

    guard let panel else { return }
    self.panel = nil
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      panel.animator().alphaValue = 0
    } completionHandler: {
      panel.orderOut(nil)
    }
  }

  private func targetScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    if let hovered = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
      return hovered
    }
    return NSScreen.main ?? NSScreen.screens.first
  }
}

// MARK: - View

private struct OCRLinkPromptView: View {
  let links: [URL]
  let onOpen: (URL) -> Void
  let onClose: () -> Void
  let onHoverChange: (Bool) -> Void

  private let feedbackStyle = FeedbackStyle(tone: .info)
  private let cornerRadius: CGFloat = 10

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    let usesSolidFallback = FeedbackChromePolicy.usesSolidFallback(
      reduceTransparency: reduceTransparency
    )
    let textColor = feedbackStyle.textColor(usesSolidFallback: usesSolidFallback)

    FeedbackSurface(cornerRadius: cornerRadius, style: feedbackStyle) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "link.circle.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(feedbackStyle.iconColor)
          .frame(width: 23, height: 23)

        VStack(alignment: .leading, spacing: 6) {
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(nsColor: textColor))

          ForEach(links, id: \.absoluteString) { link in
            OCRLinkRowButton(
              link: link,
              feedbackStyle: feedbackStyle,
              usesSolidFallback: usesSolidFallback
            ) {
              onOpen(link)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color(nsColor: textColor).opacity(0.55))
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Common.close)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(width: OCRLinkPromptManager.panelWidth, alignment: .leading)
    }
    .onHover(perform: onHoverChange)
  }

  private var title: String {
    links.count == 1
      ? L10n.OCR.linkDetectedTitle
      : L10n.OCR.linksDetectedTitle(links.count)
  }
}

private struct OCRLinkRowButton: View {
  let link: URL
  let feedbackStyle: FeedbackStyle
  let usesSolidFallback: Bool
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    let textColor = feedbackStyle.textColor(usesSolidFallback: usesSolidFallback)
    let accentColor = feedbackStyle.iconAccentColors.last ?? feedbackStyle.iconColor

    Button(action: action) {
      HStack(spacing: 6) {
        Text(OCRLinkDetector.displayString(for: link))
          .font(.system(size: 12, weight: .medium))
          .lineLimit(1)
          .truncationMode(.middle)

        Image(systemName: "arrow.up.right")
          .font(.system(size: 9, weight: .bold))
          .opacity(0.7)
      }
      .foregroundColor(
        isHovering
          ? accentColor
          : Color(nsColor: textColor).opacity(0.85)
      )
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(Color(nsColor: textColor).opacity(isHovering ? 0.14 : 0.07))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovering = hovering
    }
    .help(link.absoluteString)
    .accessibilityLabel(L10n.OCR.openLinkAccessibility(link.absoluteString))
  }
}

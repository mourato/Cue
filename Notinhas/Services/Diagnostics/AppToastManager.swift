//
//  AppToastManager.swift
//  Notinhas
//
//  Global lightweight toast presenter for non-blocking user feedback.
//

import AppKit
import Combine
import SwiftUI

enum AppToastStyle: Equatable {
  case info
  case success
  case warning
  case error
}

enum AppToastPosition: Equatable {
  case topCenter
  case bottomCenter
}

enum AppToastIconMode: Equatable {
  case symbol
  case spinner
}

enum AppToastVariant: Equatable, CaseIterable {
  case regular
  case compact

  var iconFontSize: CGFloat {
    switch self {
    case .regular: 15
    case .compact: 12
    }
  }

  var textFontSize: CGFloat {
    switch self {
    case .regular: 13
    case .compact: 10
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .regular: 16
    case .compact: 10
    }
  }

  var verticalPadding: CGFloat {
    switch self {
    case .regular: 11
    case .compact: 6
    }
  }

  var contentSpacing: CGFloat {
    switch self {
    case .regular: 10
    case .compact: 6
    }
  }

  var minWidth: CGFloat {
    switch self {
    case .regular: 80
    case .compact: 60
    }
  }

  var minHeight: CGFloat {
    switch self {
    case .regular: 44
    case .compact: 28
    }
  }

  var cornerRadius: CGFloat {
    switch self {
    case .regular: 10
    case .compact: 8
    }
  }

  var lineLimit: Int {
    switch self {
    case .regular: 3
    case .compact: 2
    }
  }

  var textWeight: Font.Weight {
    switch self {
    case .regular: .medium
    case .compact: .semibold
    }
  }

  var measurementWeight: NSFont.Weight {
    switch self {
    case .regular: .medium
    case .compact: .semibold
    }
  }
}

struct AppToastHandle {
  fileprivate let id: UUID
}

private struct AppToastPresentation: Equatable {
  let message: String
  let style: AppToastStyle
  let variant: AppToastVariant
  let iconMode: AppToastIconMode
}

@MainActor
private final class AppToastViewModel: ObservableObject {
  @Published private(set) var presentation: AppToastPresentation

  init(presentation: AppToastPresentation) {
    self.presentation = presentation
  }

  func update(_ presentation: AppToastPresentation, animated: Bool) {
    let reduceMotion = FeedbackMotionPolicy.appKitShouldReduceMotion
    let useSpring = animated && FeedbackMotionPolicy.usesSpringAnimation(reduceMotion: reduceMotion)
    if useSpring {
      withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
        self.presentation = presentation
      }
    } else {
      self.presentation = presentation
    }
  }
}

@MainActor
final class AppToastManager {
  static let shared = AppToastManager()

  private var panel: NSPanel?
  private var viewModel: AppToastViewModel?
  private var dismissTask: Task<Void, Never>?
  private var activePresentationID = UUID()
  private var activePosition: AppToastPosition = .bottomCenter

  private init() {}

  @discardableResult
  func show(
    message: String,
    style: AppToastStyle = .error,
    position: AppToastPosition = .bottomCenter,
    duration: TimeInterval? = 2.5,
    variant: AppToastVariant = .regular,
    iconMode: AppToastIconMode = .symbol
  ) -> AppToastHandle? {
    let handle = AppToastHandle(id: UUID())
    guard present(
      message: message,
      style: style,
      position: position,
      duration: duration,
      variant: variant,
      iconMode: iconMode,
      presentationID: handle.id
    ) else {
      return nil
    }
    return handle
  }

  func update(
    _ handle: AppToastHandle,
    message: String,
    style: AppToastStyle,
    position: AppToastPosition? = nil,
    duration: TimeInterval? = 2.5,
    variant: AppToastVariant? = nil,
    iconMode: AppToastIconMode = .symbol
  ) {
    guard handle.id == activePresentationID else { return }
    let resolvedVariant = variant ?? viewModel?.presentation.variant ?? .regular
    let resolvedPosition = position ?? activePosition
    _ = present(
      message: message,
      style: style,
      position: resolvedPosition,
      duration: duration,
      variant: resolvedVariant,
      iconMode: iconMode,
      presentationID: handle.id
    )
  }

  func dismiss(_ handle: AppToastHandle) {
    guard handle.id == activePresentationID else { return }
    dismissTask?.cancel()
    dismissTask = nil
    dismissIfNeeded(presentationID: handle.id)
  }

  private func present(
    message: String,
    style: AppToastStyle,
    position: AppToastPosition,
    duration: TimeInterval?,
    variant: AppToastVariant,
    iconMode: AppToastIconMode,
    presentationID: UUID
  ) -> Bool {
    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    guard let frame = frameForToast(message: trimmed, position: position, variant: variant) else { return false }

    dismissTask?.cancel()
    dismissTask = nil
    activePresentationID = presentationID
    activePosition = position

    let presentation = AppToastPresentation(
      message: trimmed,
      style: style,
      variant: variant,
      iconMode: iconMode
    )
    let viewModel = resolveViewModel(for: presentation)
    let isExistingPanelVisible = panel?.isVisible == true

    if let panel {
      if !panel.isVisible {
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
      } else {
        panel.setFrame(frame, display: true, animate: true)
      }
    } else {
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
      newPanel.ignoresMouseEvents = true
      newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
      newPanel.contentView = NSHostingView(rootView: AppToastView(viewModel: viewModel))
      newPanel.alphaValue = 0
      newPanel.orderFrontRegardless()
      panel = newPanel
    }

    viewModel.update(presentation, animated: isExistingPanelVisible)

    if let panel {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = FeedbackMotionPolicy.panelFadeDuration(
          reduceMotion: FeedbackMotionPolicy.appKitShouldReduceMotion
        )
        panel.animator().alphaValue = 1
      }
    }

    guard let duration else { return true }

    dismissTask = Task { [weak self] in
      let delay = max(0.8, duration)
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      self?.dismissIfNeeded(presentationID: presentationID)
    }
    return true
  }

  private func resolveViewModel(for presentation: AppToastPresentation) -> AppToastViewModel {
    if let viewModel {
      return viewModel
    }

    let newViewModel = AppToastViewModel(presentation: presentation)
    viewModel = newViewModel
    return newViewModel
  }

  private func dismissIfNeeded(presentationID: UUID) {
    guard presentationID == activePresentationID else { return }
    guard let panel else { return }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = FeedbackMotionPolicy.panelFadeDuration(
        reduceMotion: FeedbackMotionPolicy.appKitShouldReduceMotion
      )
      panel.animator().alphaValue = 0
    } completionHandler: {
      panel.orderOut(nil)
    }
  }

  private func frameForToast(
    message: String,
    position: AppToastPosition,
    variant: AppToastVariant
  ) -> CGRect? {
    guard let screen = targetScreen() else { return nil }
    let visibleFrame = screen.visibleFrame
    let maxWidth = min(
      FeedbackToastMetrics.defaultMaxWidth,
      visibleFrame.width - FeedbackToastMetrics.screenHorizontalInset
    )
    let size = FeedbackToastMetrics.measuredToastSize(
      for: message,
      maxWidth: maxWidth,
      variant: variant
    )

    return FeedbackPanelPlacement.frame(
      in: visibleFrame,
      panelSize: size,
      slot: position.feedbackPanelSlot
    )
  }

  private func targetScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    if let hovered = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
      return hovered
    }
    return NSScreen.main ?? NSScreen.screens.first
  }
}

private struct AppToastView: View {
  @ObservedObject var viewModel: AppToastViewModel
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  var body: some View {
    let presentation = viewModel.presentation
    let feedbackStyle = presentation.style.feedbackStyle
    let variant = presentation.variant
    let usesSolidFallback = FeedbackChromePolicy.usesSolidFallback(
      reduceTransparency: reduceTransparency
    )
    let isProgress = presentation.iconMode == .spinner

    FeedbackSurface(cornerRadius: variant.cornerRadius, style: feedbackStyle) {
      HStack(alignment: .center, spacing: variant.contentSpacing) {
        FeedbackIconView(
          style: feedbackStyle,
          iconMode: presentation.iconMode == .symbol ? .symbol : .spinner,
          fontSize: variant.iconFontSize
        )

        Text(presentation.message)
          .font(.system(size: variant.textFontSize, weight: variant.textWeight))
          .foregroundColor(Color(nsColor: feedbackStyle.textColor(usesSolidFallback: usesSolidFallback)))
          .lineLimit(variant.lineLimit)
          .multilineTextAlignment(.leading)
      }
      .padding(.horizontal, variant.horizontalPadding)
      .padding(.vertical, variant.verticalPadding)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      FeedbackAccessibilityPolicy.toastAccessibilityLabel(
        message: presentation.message,
        tone: feedbackStyle.tone,
        isProgress: isProgress
      )
    )
    .modifier(ToastAccessibilityValueModifier(message: presentation.message, isProgress: isProgress))
    .scaleEffect(FeedbackMotionPolicy.toastEntranceScale(reduceMotion: reduceMotion, appeared: appeared))
    .onAppear {
      if FeedbackMotionPolicy.usesSpringAnimation(reduceMotion: reduceMotion) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
          appeared = true
        }
      } else {
        appeared = true
      }
    }
  }
}

private struct ToastAccessibilityValueModifier: ViewModifier {
  let message: String
  let isProgress: Bool

  func body(content: Content) -> some View {
    if let value = FeedbackAccessibilityPolicy.toastAccessibilityValue(message: message, isProgress: isProgress) {
      content.accessibilityValue(value)
    } else {
      content
    }
  }
}

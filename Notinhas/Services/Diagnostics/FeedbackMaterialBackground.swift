//
//  FeedbackMaterialBackground.swift
//  Notinhas
//
//  Native HUD material background with solid accessibility fallback.
//

import AppKit
import SwiftUI

struct FeedbackMaterialBackground: NSViewRepresentable {
  let cornerRadius: CGFloat
  let material: NSVisualEffectView.Material
  let solidBackgroundColor: NSColor
  let overlayTint: Color

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  func makeNSView(context _: Context) -> NSView {
    let container = FeedbackMaterialContainerView()
    container.cornerRadius = cornerRadius
    updateContainer(container)
    return container
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    guard let container = nsView as? FeedbackMaterialContainerView else { return }
    container.cornerRadius = cornerRadius
    updateContainer(container)
  }

  private var usesSolidFallback: Bool {
    let accessibilityContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    return reduceTransparency || accessibilityContrast
  }

  private func updateContainer(_ container: FeedbackMaterialContainerView) {
    container.configure(
      cornerRadius: cornerRadius,
      material: material,
      usesSolidFallback: usesSolidFallback,
      solidBackgroundColor: solidBackgroundColor,
      overlayTint: overlayTint,
      colorScheme: colorScheme
    )
  }
}

// MARK: - Container

private final class FeedbackMaterialContainerView: NSView {
  var cornerRadius: CGFloat = 10

  private let effectView = NSVisualEffectView()
  private let solidView = NSView()
  private let tintView = NSView()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    effectView.translatesAutoresizingMaskIntoConstraints = false
    solidView.translatesAutoresizingMaskIntoConstraints = false
    tintView.translatesAutoresizingMaskIntoConstraints = false

    addSubview(effectView)
    addSubview(solidView)
    addSubview(tintView)

    NSLayoutConstraint.activate([
      effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      effectView.topAnchor.constraint(equalTo: topAnchor),
      effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
      solidView.leadingAnchor.constraint(equalTo: leadingAnchor),
      solidView.trailingAnchor.constraint(equalTo: trailingAnchor),
      solidView.topAnchor.constraint(equalTo: topAnchor),
      solidView.bottomAnchor.constraint(equalTo: bottomAnchor),
      tintView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tintView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tintView.topAnchor.constraint(equalTo: topAnchor),
      tintView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(
    cornerRadius: CGFloat,
    material: NSVisualEffectView.Material,
    usesSolidFallback: Bool,
    solidBackgroundColor: NSColor,
    overlayTint: Color,
    colorScheme: ColorScheme
  ) {
    self.cornerRadius = cornerRadius
    applyCornerRadius(to: layer)
    applyCornerRadius(to: effectView.layer)
    applyCornerRadius(to: solidView.layer)
    applyCornerRadius(to: tintView.layer)

    effectView.material = material
    effectView.state = .active
    effectView.blendingMode = .withinWindow
    effectView.wantsLayer = true
    effectView.isHidden = usesSolidFallback

    solidView.wantsLayer = true
    solidView.layer?.backgroundColor = solidBackgroundColor.cgColor
    solidView.isHidden = !usesSolidFallback

    tintView.wantsLayer = true
    tintView.layer?.backgroundColor = NSColor(overlayTint).cgColor
    tintView.isHidden = usesSolidFallback

    _ = colorScheme
  }

  private func applyCornerRadius(to layer: CALayer?) {
    layer?.cornerRadius = cornerRadius
    layer?.cornerCurve = .continuous
    layer?.masksToBounds = true
  }
}

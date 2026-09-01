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
        FeedbackChromePolicy.usesSolidFallback(reduceTransparency: reduceTransparency)
    }

    private func updateContainer(_ container: FeedbackMaterialContainerView) {
        container.configure(
            cornerRadius: cornerRadius,
            material: material,
            usesSolidFallback: usesSolidFallback,
            solidBackgroundColor: solidBackgroundColor,
            overlayTint: overlayTint,
        )
    }
}

// MARK: - Container

private final class FeedbackMaterialContainerView: NSView {
    var cornerRadius: CGFloat = 10

    private let effectView = NSVisualEffectView()
    private let solidView = NSView()
    private let tintView = NSView()

    private var usesSolidFallback = false
    private var solidBackgroundColor: NSColor = .clear
    private var overlayTintColor: NSColor = .clear

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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyResolvedLayerColors()
    }

    func configure(
        cornerRadius: CGFloat,
        material: NSVisualEffectView.Material,
        usesSolidFallback: Bool,
        solidBackgroundColor: NSColor,
        overlayTint: Color,
    ) {
        self.cornerRadius = cornerRadius
        self.usesSolidFallback = usesSolidFallback
        self.solidBackgroundColor = solidBackgroundColor
        overlayTintColor = NSColor(overlayTint)

        applyCornerRadius(to: layer)
        applyCornerRadius(to: effectView.layer)
        applyCornerRadius(to: solidView.layer)
        applyCornerRadius(to: tintView.layer)

        // Keep HUD material on dark chrome so light HUD labels stay readable.
        effectView.appearance = NSAppearance(named: .darkAqua)
        effectView.material = material
        effectView.state = .active
        effectView.blendingMode = .withinWindow
        effectView.wantsLayer = true
        effectView.isHidden = usesSolidFallback

        solidView.wantsLayer = true
        solidView.isHidden = !usesSolidFallback

        tintView.wantsLayer = true
        tintView.isHidden = usesSolidFallback

        applyResolvedLayerColors()
    }

    private func applyResolvedLayerColors() {
        let appearance = effectiveAppearance
        solidView.layer?.backgroundColor = cgColor(for: solidBackgroundColor, appearance: appearance)
        tintView.layer?.backgroundColor = cgColor(for: overlayTintColor, appearance: appearance)
    }

    private func cgColor(for color: NSColor, appearance: NSAppearance) -> CGColor {
        var resolved: CGColor = NSColor.clear.cgColor
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.cgColor
        }
        return resolved
    }

    private func applyCornerRadius(to layer: CALayer?) {
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }
}

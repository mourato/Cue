//
//  FeedbackSurface.swift
//  Notinhas
//
//  Shared native-material chrome for floating feedback UI.
//

import AppKit
import SwiftUI

struct FeedbackSurface<Content: View>: View {
  let cornerRadius: CGFloat
  let style: FeedbackStyle
  let material: NSVisualEffectView.Material
  @ViewBuilder let content: () -> Content

  init(
    cornerRadius: CGFloat,
    style: FeedbackStyle,
    material: NSVisualEffectView.Material = .hudWindow,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.style = style
    self.material = material
    self.content = content
  }

  var body: some View {
    content()
      .background(
        FeedbackMaterialBackground(
          cornerRadius: cornerRadius,
          material: material,
          solidBackgroundColor: style.solidBackgroundColor,
          overlayTint: style.materialOverlayTint
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color(nsColor: style.borderColor), lineWidth: 0.5)
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 4)
      .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
  }
}

// MARK: - Toast metrics

enum FeedbackToastMetrics {
  static let defaultMaxWidth: CGFloat = 560
  static let screenHorizontalInset: CGFloat = 32
  static let minimumTextColumnWidth: CGFloat = 120

  static func measuredToastSize(
    for message: String,
    maxWidth: CGFloat,
    variant: AppToastVariant
  ) -> CGSize {
    let font = NSFont.systemFont(ofSize: variant.textFontSize, weight: variant.measurementWeight)
    let iconFrameWidth = variant.iconFontSize + 8
    let horizontalChrome = (variant.horizontalPadding * 2) + iconFrameWidth + variant.contentSpacing
    let maxTextWidth = max(minimumTextColumnWidth, maxWidth - horizontalChrome)
    let attributed = NSAttributedString(string: message, attributes: [.font: font])
    let textBounds = attributed.boundingRect(
      with: NSSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let width = min(maxWidth, max(variant.minWidth, ceil(textBounds.width + 2) + horizontalChrome))
    let height = max(variant.minHeight, ceil(textBounds.height) + (variant.verticalPadding * 2))
    return CGSize(width: width, height: height)
  }
}

//
//  FeedbackIconView.swift
//  Notinhas
//
//  Semantic icon and spinner for feedback surfaces.
//

import SwiftUI

enum FeedbackIconMode: Equatable {
  case symbol
  case spinner
}

struct FeedbackIconView: View {
  let style: FeedbackStyle
  let iconMode: FeedbackIconMode
  let fontSize: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      switch iconMode {
      case .symbol:
        Image(systemName: style.iconName)
          .font(.system(size: fontSize, weight: .semibold))
          .foregroundStyle(style.iconColor)
          .transition(iconTransition)
      case .spinner:
        if reduceMotion {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(style.iconColor)
            .transition(iconTransition)
        } else {
          FeedbackSpinnerView(
            colors: style.iconAccentColors,
            size: fontSize + 4
          )
          .transition(iconTransition)
        }
      }
    }
    .frame(width: fontSize + 8, height: fontSize + 8)
    // Parent toast / surface owns accessibility copy (localized message).
    .accessibilityHidden(true)
  }

  private var iconTransition: AnyTransition {
    if FeedbackMotionPolicy.usesScaleAnimation(reduceMotion: reduceMotion) {
      return .scale(scale: 0.82).combined(with: .opacity)
    }
    return .opacity
  }
}

private struct FeedbackSpinnerView: View {
  let colors: [Color]
  let size: CGFloat

  @State private var isSpinning = false

  var body: some View {
    Circle()
      .trim(from: 0.18, to: 1)
      .stroke(
        AngularGradient(
          gradient: Gradient(colors: colors.map { $0.opacity(0.15) } + [colors.last ?? .cyan]),
          center: .center
        ),
        style: StrokeStyle(lineWidth: max(2, size * 0.15), lineCap: .round)
      )
      .frame(width: size, height: size)
      .rotationEffect(.degrees(isSpinning ? 360 : 0))
      .onAppear {
        guard !isSpinning else { return }
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
          isSpinning = true
        }
      }
  }
}

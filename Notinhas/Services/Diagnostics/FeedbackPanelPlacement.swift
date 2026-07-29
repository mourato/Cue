//
//  FeedbackPanelPlacement.swift
//  Notinhas
//
//  Pure frame calculation for coordinated feedback panel slots.
//

import CoreGraphics

enum FeedbackPanelSlot: Equatable {
  case topCenter
  case bottomCenter
  case bottomCenterRaised
}

enum FeedbackPanelPlacement {
  static let standardMargin: CGFloat = 36
  static let raisedBottomMargin: CGFloat = 100

  static func margin(for slot: FeedbackPanelSlot) -> CGFloat {
    switch slot {
    case .topCenter, .bottomCenter:
      standardMargin
    case .bottomCenterRaised:
      raisedBottomMargin
    }
  }

  static func frame(
    in visibleFrame: CGRect,
    panelSize size: CGSize,
    slot: FeedbackPanelSlot
  ) -> CGRect {
    let x = visibleFrame.midX - size.width / 2
    let y: CGFloat = switch slot {
    case .topCenter:
      visibleFrame.maxY - size.height - margin(for: .topCenter)
    case .bottomCenter:
      visibleFrame.minY + margin(for: .bottomCenter)
    case .bottomCenterRaised:
      visibleFrame.minY + margin(for: .bottomCenterRaised)
    }

    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }
}

extension AppToastPosition {
  var feedbackPanelSlot: FeedbackPanelSlot {
    switch self {
    case .topCenter: .topCenter
    case .bottomCenter: .bottomCenter
    }
  }
}

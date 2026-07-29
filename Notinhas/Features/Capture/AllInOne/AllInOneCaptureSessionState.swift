//
//  AllInOneCaptureSessionState.swift
//  Notinhas
//
//  Observable session state shared between All-In-One HUD views and the coordinator.
//

import Combine
import CoreGraphics
import Foundation

@MainActor
final class AllInOneCaptureSessionState: ObservableObject {
  @Published var selectedMode: AllInOneCaptureMode = .area
  @Published var currentRect: CGRect?
  @Published private(set) var availableModes: [AllInOneCaptureMode]

  var onModeActivated: (AllInOneCaptureMode) -> Void = { _ in }
  var onRectChanged: (CGRect) -> Void = { _ in }
  var onCancel: () -> Void = {}

  init(videoEnabled: Bool = VideoModuleAvailability.isEnabled) {
    availableModes = AllInOneCaptureMode.availableModes(videoEnabled: videoEnabled)
  }

  func activateMode(_ mode: AllInOneCaptureMode) {
    guard availableModes.contains(mode) else { return }
    selectedMode = mode
    onModeActivated(mode)
  }

  func activateSelectedMode() {
    activateMode(selectedMode)
  }

  func updateRect(_ rect: CGRect) {
    currentRect = rect
    onRectChanged(rect)
  }

  func cancel() {
    onCancel()
  }
}

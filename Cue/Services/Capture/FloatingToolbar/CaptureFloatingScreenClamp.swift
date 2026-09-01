//
//  CaptureFloatingScreenClamp.swift
//  Notinhas
//
//  Shared screen-edge origin clamp for floating capture HUD chrome.
//

import CoreGraphics

/// Clamps floating HUD frame origins against screen edges.
///
/// Capture Markup's `InlineAreaControlGeometry` center clamp uses a mid-frame
/// fallback when the range inverts; do not replace it with this helper without
/// an explicit product decision.
enum CaptureFloatingScreenClamp {
    /// Clamps a leading/trailing origin into `[minimum, maximum]`.
    /// When the toolbar cannot fit (`maximum < minimum`), returns `minimum`
    /// so the leading edge stays on-screen.
    static func clampedOrigin(_ origin: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else {
            return minimum
        }
        return max(minimum, min(origin, maximum))
    }
}

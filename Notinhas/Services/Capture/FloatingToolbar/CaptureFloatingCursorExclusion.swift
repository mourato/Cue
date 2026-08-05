import CoreGraphics

enum CaptureFloatingCursorExclusion {
    /// Returns true when `point` (AppKit screen coordinates) lies inside any HUD frame.
    static func contains(_ point: CGPoint, in frames: [CGRect]) -> Bool {
        frames.contains { $0.contains(point) }
    }
}

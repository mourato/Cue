//
//  CaptureSelectionChromeAppearance.swift
//  Notinhas
//
//  Pure contrast policy for capture selection chrome. Visual contrast is independent
//  from snapping color sensitivity; hosts supply sampled luma or backdrop context.
//

import CoreGraphics

struct CaptureSelectionChromeAppearanceContext: Equatable, Sendable {
    /// Normalized backdrop luminance in 0...1 when known. Higher values mean a lighter backdrop.
    let backdropLuma: CGFloat?

    static let fallbackLuma: CGFloat = 0.5
}

struct CaptureSelectionChromeColors: Equatable, Sendable {
    let strokeRed: CGFloat
    let strokeGreen: CGFloat
    let strokeBlue: CGFloat
    let strokeAlpha: CGFloat
    let shadowOpacity: CGFloat
    let borderWidth: CGFloat
}

enum CaptureSelectionChromeAppearance {
    static func colors(for context: CaptureSelectionChromeAppearanceContext) -> CaptureSelectionChromeColors {
        let luma = context.backdropLuma ?? CaptureSelectionChromeAppearanceContext.fallbackLuma
        if luma >= 0.58 {
            return CaptureSelectionChromeColors(
                strokeRed: 0,
                strokeGreen: 0,
                strokeBlue: 0,
                strokeAlpha: 0.92,
                shadowOpacity: 0.35,
                borderWidth: CaptureSelectionChromeMetrics.continuousBorderWidth,
            )
        }

        return CaptureSelectionChromeColors(
            strokeRed: 1,
            strokeGreen: 1,
            strokeBlue: 1,
            strokeAlpha: 1,
            shadowOpacity: 0.5,
            borderWidth: CaptureSelectionChromeMetrics.continuousBorderWidth,
        )
    }

    /// Samples average luma from an RGBA buffer in 0...1 coordinates.
    static func averageLuma(
        samples: [(r: CGFloat, g: CGFloat, b: CGFloat)],
        fallback: CGFloat = CaptureSelectionChromeAppearanceContext.fallbackLuma,
    ) -> CGFloat {
        guard !samples.isEmpty else { return fallback }
        let total = samples.reduce(CGFloat.zero) { partial, sample in
            partial + (0.2126 * sample.r + 0.7152 * sample.g + 0.0722 * sample.b)
        }
        return total / CGFloat(samples.count)
    }
}

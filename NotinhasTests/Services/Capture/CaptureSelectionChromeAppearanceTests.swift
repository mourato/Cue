//
//  CaptureSelectionChromeAppearanceTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureSelectionChromeAppearanceTests: XCTestCase {
    func testColors_lightBackdrop_usesDarkStroke() {
        let colors = CaptureSelectionChromeAppearance.colors(
            for: CaptureSelectionChromeAppearanceContext(backdropLuma: 0.9),
        )

        XCTAssertLessThan(colors.strokeRed, 0.2)
        XCTAssertGreaterThan(colors.strokeAlpha, 0.8)
    }

    func testColors_darkBackdrop_usesLightStroke() {
        let colors = CaptureSelectionChromeAppearance.colors(
            for: CaptureSelectionChromeAppearanceContext(backdropLuma: 0.1),
        )

        XCTAssertEqual(colors.strokeRed, 1)
        XCTAssertEqual(colors.strokeGreen, 1)
        XCTAssertEqual(colors.strokeBlue, 1)
    }

    func testColors_missingLuma_usesDeterministicFallback() {
        let colors = CaptureSelectionChromeAppearance.colors(
            for: CaptureSelectionChromeAppearanceContext(backdropLuma: nil),
        )

        XCTAssertEqual(
            colors.strokeAlpha,
            CaptureSelectionChromeAppearance.colors(
                for: CaptureSelectionChromeAppearanceContext(backdropLuma: CaptureSelectionChromeAppearanceContext
                    .fallbackLuma),
            ).strokeAlpha,
        )
    }

    func testAverageLuma_isIndependentFromSnappingSensitivity() {
        let samples = [(r: CGFloat(1), g: CGFloat(1), b: CGFloat(1))]
        let luma = CaptureSelectionChromeAppearance.averageLuma(samples: samples)

        XCTAssertEqual(luma, 1, accuracy: 0.001)
        XCTAssertNotEqual(
            CaptureSelectionSnappingConfiguration(colorSensitivity: 1).colorDifferenceThreshold,
            CaptureSelectionSnappingConfiguration(colorSensitivity: 5).colorDifferenceThreshold,
        )
    }
}

//
//  FeedbackSurfaceTests.swift
//  NotinhasTests
//
//  Pure token and sizing tests for shared feedback surfaces.
//

import AppKit
@testable import Notinhas
import XCTest

final class FeedbackSurfaceTests: XCTestCase {
  func testEveryFeedbackToneHasNonEmptyIconName() {
    for tone in FeedbackTone.allCases {
      let style = FeedbackStyle(tone: tone)
      XCTAssertFalse(style.iconName.isEmpty, "Expected icon for \(tone)")
      XCTAssertTrue(style.iconName.contains("."), "Expected SF Symbol name for \(tone)")
    }
  }

  func testEveryToastVariantHasPositiveDimensions() {
    for variant in AppToastVariant.allCases {
      XCTAssertGreaterThan(variant.iconFontSize, 0)
      XCTAssertGreaterThan(variant.textFontSize, 0)
      XCTAssertGreaterThan(variant.horizontalPadding, 0)
      XCTAssertGreaterThan(variant.verticalPadding, 0)
      XCTAssertGreaterThan(variant.contentSpacing, 0)
      XCTAssertGreaterThan(variant.minWidth, 0)
      XCTAssertGreaterThan(variant.minHeight, 0)
      XCTAssertGreaterThan(variant.cornerRadius, 0)
    }
  }

  func testRegularAndCompactVariantsHaveDistinctMinHeights() {
    XCTAssertGreaterThan(AppToastVariant.regular.minHeight, AppToastVariant.compact.minHeight)
  }

  func testSolidFallbackColorsResolveForLightAndDarkAppearances() {
    let lightAppearanceBackground = FeedbackAppearanceTokens.solidBackgroundColor(for: .aqua)
    let darkAppearanceBackground = FeedbackAppearanceTokens.solidBackgroundColor(for: .darkAqua)

    XCTAssertGreaterThan(lightAppearanceBackground.alphaComponent, 0)
    XCTAssertGreaterThan(darkAppearanceBackground.alphaComponent, 0)
    XCTAssertLessThan(
      lightAppearanceBackground.redComponent,
      darkAppearanceBackground.redComponent
    )

    let lightComponents = FeedbackAppearanceTokens.solidBackgroundSRGBComponents(isDarkAppearance: false)
    let darkComponents = FeedbackAppearanceTokens.solidBackgroundSRGBComponents(isDarkAppearance: true)
    XCTAssertGreaterThan(darkComponents.red, lightComponents.red)
  }

  func testMeasuredToastSizeRespectsMaxWidth() {
    let longMessage = String(repeating: "Notinhas feedback ", count: 40)
    let maxWidth: CGFloat = 240

    let size = FeedbackToastMetrics.measuredToastSize(
      for: longMessage,
      maxWidth: maxWidth,
      variant: .regular
    )

    XCTAssertLessThanOrEqual(size.width, maxWidth)
    XCTAssertGreaterThanOrEqual(size.height, AppToastVariant.regular.minHeight)
  }

  func testAppToastStyleCompatibilityShimsDelegateToFeedbackStyle() {
    XCTAssertEqual(AppToastStyle.info.iconName, FeedbackStyle(tone: .info).iconName)
    XCTAssertEqual(AppToastStyle.error.feedbackTone, .error)
  }

  func testMaterialChromeUsesLightHUDTextWhileSolidKeepsInvertedPair() {
    let style = FeedbackStyle(tone: .info)
    let hudText = style.textColor(usesSolidFallback: false)
    XCTAssertGreaterThan(hudText.redComponent, 0.9)

    let solidLightComponents = FeedbackAppearanceTokens.solidBackgroundSRGBComponents(isDarkAppearance: false)
    let solidDarkComponents = FeedbackAppearanceTokens.solidBackgroundSRGBComponents(isDarkAppearance: true)
    // Solid light-mode chip is dark; dark-mode chip is light (inverted pair).
    XCTAssertLessThan(solidLightComponents.red, solidDarkComponents.red)
    XCTAssertGreaterThan(hudText.redComponent, solidLightComponents.red)
  }

  func testChromePolicyUsesSolidFallbackForReduceTransparencyOrIncreaseContrast() {
    XCTAssertTrue(FeedbackChromePolicy.usesSolidFallback(reduceTransparency: true))
  }
}

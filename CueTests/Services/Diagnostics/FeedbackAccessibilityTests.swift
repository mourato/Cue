//
//  FeedbackAccessibilityTests.swift
//  NotinhasTests
//
//  Pure policy and token tests for feedback accessibility and motion.
//

@testable import Cue
import SwiftUI
import XCTest

final class FeedbackAccessibilityTests: XCTestCase {
    func testReducedMotionDisablesScaleAnimation() {
        XCTAssertFalse(FeedbackMotionPolicy.usesScaleAnimation(reduceMotion: true))
        XCTAssertEqual(FeedbackMotionPolicy.toastEntranceScale(reduceMotion: true, appeared: false), 1.0)
        XCTAssertEqual(FeedbackMotionPolicy.quickAccessPressScale(reduceMotion: true, isPressed: true), 1.0)
    }

    func testNormalMotionAllowsShortScaleAnimation() {
        XCTAssertTrue(FeedbackMotionPolicy.usesScaleAnimation(reduceMotion: false))
        XCTAssertEqual(
            FeedbackMotionPolicy.toastEntranceScale(reduceMotion: false, appeared: false),
            0.96,
            accuracy: 0.001,
        )
        XCTAssertEqual(
            FeedbackMotionPolicy.quickAccessPressScale(reduceMotion: false, isPressed: true),
            0.85,
            accuracy: 0.001,
        )
    }

    func testReducedMotionKeepsFadeDuration() {
        XCTAssertEqual(FeedbackMotionPolicy.panelFadeDuration(reduceMotion: true), 0.16, accuracy: 0.001)
        XCTAssertEqual(FeedbackMotionPolicy.panelFadeDuration(reduceMotion: false), 0.16, accuracy: 0.001)
    }

    func testEveryFeedbackToneHasNonEmptyAccessibilityToken() {
        for tone in FeedbackTone.allCases {
            let token = FeedbackAccessibilityPolicy.toneAccessibilityToken(for: tone)
            XCTAssertFalse(token.isEmpty, "Expected accessibility token for \(tone)")
        }
    }

    func testToastAccessibilityLabelUsesLocalizedMessage() {
        let label = FeedbackAccessibilityPolicy.toastAccessibilityLabel(
            message: "Upload complete",
            tone: .success,
            isProgress: false,
        )
        XCTAssertEqual(label, "Upload complete")
    }

    func testProgressToastAccessibilityValueDiffersFromTerminal() {
        XCTAssertEqual(
            FeedbackAccessibilityPolicy.toastAccessibilityValue(message: "Uploading", isProgress: true),
            "Uploading",
        )
        XCTAssertNil(FeedbackAccessibilityPolicy.toastAccessibilityValue(message: "Uploading", isProgress: false))
    }

    func testProgressToastUpdatesDoNotRequestAnnouncement() {
        XCTAssertFalse(
            FeedbackAccessibilityPolicy.shouldAnnounceToastUpdate(
                previousMessage: "Scanning",
                newMessage: "Scanning image",
                isProgress: true,
            ),
        )
    }

    func testLocalStateTokensDistinguishSuccessDestructiveAndDefault() {
        let defaultColor = FeedbackLocalStateTokens.uploadHistoryActionIconColor(for: .default)
        let successColor = FeedbackLocalStateTokens.uploadHistoryActionIconColor(for: .copiedSuccess)
        let destructiveColor = FeedbackLocalStateTokens.uploadHistoryActionIconColor(for: .destructive)

        XCTAssertNotEqual(defaultColor, successColor)
        XCTAssertNotEqual(defaultColor, destructiveColor)
        XCTAssertNotEqual(successColor, destructiveColor)
    }

    func testQuickAccessButtonStateTokensAreDistinguishable() {
        let disabled = FeedbackLocalStateTokens.quickAccessButtonBackground(for: .disabled)
        let defaultState = FeedbackLocalStateTokens.quickAccessButtonBackground(for: .default)
        let hover = FeedbackLocalStateTokens.quickAccessButtonBackground(for: .hover)
        let pressed = FeedbackLocalStateTokens.quickAccessButtonBackground(for: .pressed)

        XCTAssertNotEqual(disabled, defaultState)
        XCTAssertNotEqual(defaultState, hover)
        XCTAssertNotEqual(hover, pressed)
    }
}

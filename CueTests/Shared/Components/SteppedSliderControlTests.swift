@testable import Cue
import Foundation
import SwiftUI
import XCTest

final class SteppedSliderControlTests: XCTestCase {
    func testNudgeIncrementsMidRange() {
        XCTAssertEqual(SteppedValue.nudge(5, by: 1, in: 1 ... 20), 6)
    }

    func testNudgeDecrementsMidRange() {
        XCTAssertEqual(SteppedValue.nudge(5, by: -1, in: 1 ... 20), 4)
    }

    func testNudgeClampsAtUpperBound() {
        XCTAssertEqual(SteppedValue.nudge(20, by: 1, in: 1 ... 20), 20)
    }

    func testNudgeClampsAtLowerBound() {
        XCTAssertEqual(SteppedValue.nudge(1, by: -1, in: 1 ... 20), 1)
    }

    func testNudgeSnapsToStep() {
        XCTAssertEqual(SteppedValue.nudge(5.3, by: 1, in: 1 ... 20), 6)
    }

    func testNudgeFractionalStep() {
        XCTAssertEqual(SteppedValue.nudge(1.0, by: 0.5, in: 1 ... 8), 1.5)
    }

    func testCanNudgeFalseAtBounds() {
        XCTAssertFalse(SteppedValue.canNudge(1, by: -1, in: 1 ... 20))
        XCTAssertFalse(SteppedValue.canNudge(20, by: 1, in: 1 ... 20))
    }

    func testCanNudgeTrueInMidRange() {
        XCTAssertTrue(SteppedValue.canNudge(5, by: -1, in: 1 ... 20))
        XCTAssertTrue(SteppedValue.canNudge(5, by: 1, in: 1 ... 20))
    }

    func testNudgeMatchesSteppedBindingMath() {
        let range: ClosedRange<CGFloat> = 0.05 ... 0.65
        let step: CGFloat = 0.01
        let startValue: CGFloat = 0.37

        let nudged = SteppedValue.nudge(startValue, by: step, in: range)

        var bindingValue = startValue
        let binding = Binding(
            get: { bindingValue },
            set: { bindingValue = $0 },
        ).stepped(by: step, in: range)
        binding.wrappedValue = startValue + step

        XCTAssertEqual(nudged, bindingValue, accuracy: 0.000_001)
    }

    func testDoubleNudgeSnapsFractionalValue() {
        XCTAssertEqual(SteppedValue.nudge(1.0, by: 0.25, in: 0.75 ... 1.75), 1.25)
    }

    func testDoubleBindingClampsAndSnapsAtUpperBound() {
        let range = 0.0 ... 1000.0
        var bindingValue = 975.0
        let binding = Binding(
            get: { bindingValue },
            set: { bindingValue = $0 },
        ).stepped(by: 50, in: range)

        binding.wrappedValue = 1_025

        XCTAssertEqual(bindingValue, 1_000)
    }

    func testDoubleCanNudgeIsDisabledAtEndpoints() {
        XCTAssertFalse(SteppedValue.canNudge(0.75, by: -0.25, in: 0.75 ... 1.75))
        XCTAssertFalse(SteppedValue.canNudge(1.75, by: 0.25, in: 0.75 ... 1.75))
    }
}

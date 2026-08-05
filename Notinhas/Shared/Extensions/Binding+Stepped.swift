//
//  Binding+Stepped.swift
//  Notinhas
//
//  Binding extension to enable step snapping and clamping on sliders
//  without showing native macOS tick marks.
//

import SwiftUI

enum SteppedValue {
    static func snapped<Value: BinaryFloatingPoint>(
        _ value: Value,
        by step: Value,
        in range: ClosedRange<Value>,
    ) -> Value {
        precondition(step != 0, "SteppedValue.snapped requires a non-zero step")
        let snapped = (value / step).rounded() * step
        return Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
    }

    static func nudge<Value: BinaryFloatingPoint>(_ value: Value, by step: Value,
                                                  in range: ClosedRange<Value>) -> Value {
        snapped(value + step, by: step, in: range)
    }

    /// Whether applying `step` (signed) would change `value` after snap+clamp.
    static func canNudge<Value: BinaryFloatingPoint>(
        _ value: Value,
        by step: Value,
        in range: ClosedRange<Value>,
    ) -> Bool {
        abs(nudge(value, by: step, in: range) - value) > 1e-9
    }
}

extension Binding where Value: BinaryFloatingPoint {
    func stepped(by step: Value, in range: ClosedRange<Value>) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = SteppedValue.snapped(newValue, by: step, in: range)
            },
        )
    }
}

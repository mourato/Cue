//
//  SteppedSliderControl.swift
//  Notinhas
//
//  Slider with adjacent minus/plus stepper buttons for discrete value nudging.
//

import SwiftUI

struct SteppedSliderControl<Value: BinaryFloatingPoint>: View {
    @Binding var value: Value
    let step: Value
    let range: ClosedRange<Value>
    var sliderWidth: CGFloat?
    var onEditingChanged: (Bool) -> Void = { _ in }

    init(
        value: Binding<Value>,
        step: Value,
        in range: ClosedRange<Value>,
        sliderWidth: CGFloat? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
    ) {
        _value = value
        self.step = step
        self.range = range
        self.sliderWidth = sliderWidth
        self.onEditingChanged = onEditingChanged
    }

    private var canDecrement: Bool {
        SteppedValue.canNudge(value, by: -step, in: range)
    }

    private var canIncrement: Bool {
        SteppedValue.canNudge(value, by: step, in: range)
    }

    var body: some View {
        HStack(spacing: 4) {
            stepperButton(systemName: "minus", isEnabled: canDecrement, delta: -step)
                .accessibilityLabel(L10n.Common.decrease)

            Slider(
                value: sliderBinding,
                in: Double(range.lowerBound) ... Double(range.upperBound),
                onEditingChanged: onEditingChanged,
            )
            .controlSize(.small)
            .frame(width: sliderWidth)
            .accessibilityValue(Text(String(describing: value)))

            stepperButton(systemName: "plus", isEnabled: canIncrement, delta: step)
                .accessibilityLabel(L10n.Common.increase)
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                value = SteppedValue.snapped(Value(newValue), by: step, in: range)
            },
        )
    }

    private func stepperButton(systemName: String, isEnabled: Bool, delta: Value) -> some View {
        Button {
            onEditingChanged(true)
            value = SteppedValue.nudge(value, by: delta, in: range)
            onEditingChanged(false)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

#if DEBUG
    #Preview {
        struct PreviewHarness: View {
            @State private var value: CGFloat = 4

            var body: some View {
                SteppedSliderControl(
                    value: $value,
                    step: 0.5,
                    in: 1 ... 8,
                    sliderWidth: 96,
                )
                .padding()
            }
        }

        return PreviewHarness()
    }
#endif

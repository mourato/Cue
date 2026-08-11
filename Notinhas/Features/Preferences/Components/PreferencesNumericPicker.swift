//
//  PreferencesNumericPicker.swift
//  Notinhas
//
//  Preset menu with an optional bounded custom numeric value.
//

import SwiftUI

enum PreferencesNumericPickerValue {
    static func sanitizedText(_ text: String, allowsFraction: Bool) -> String {
        var result = ""
        var hasDecimalSeparator = false

        for character in text.replacingOccurrences(of: ",", with: ".") {
            if character.wholeNumberValue != nil {
                result.append(character)
            } else if allowsFraction, character == ".", !hasDecimalSeparator {
                result.append(character)
                hasDecimalSeparator = true
            }
        }

        return result
    }

    static func normalizedValue(
        from text: String,
        range: ClosedRange<Double>,
        step: Double,
        inputScale: Double = 1,
    ) -> Double? {
        guard inputScale > 0,
              let parsed = Double(text.replacingOccurrences(of: ",", with: ".")),
              parsed.isFinite else {
            return nil
        }

        let inputRange = range.lowerBound * inputScale ... range.upperBound * inputScale
        return SteppedValue.snapped(parsed, by: step * inputScale, in: inputRange) / inputScale
    }
}

struct PreferencesNumericPicker: View {
    private struct Preset: Identifiable {
        let id: Int
        let value: Double
    }

    private enum Selection: Hashable {
        case preset(Int)
        case custom
        case special
    }

    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let presets: [Double]
    private let step: Double
    private let accessibilityTitle: String
    private let unit: String
    private let customInputScale: Double
    private let valueLabel: (Double) -> String
    private let specialValue: Double?
    private let specialLabel: String?

    @State private var customText = ""
    @FocusState private var customFieldFocused: Bool

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        presets: [Double],
        step: Double,
        accessibilityTitle: String,
        unit: String = "",
        customInputScale: Double = 1,
        valueLabel: @escaping (Double) -> String,
        specialValue: Double? = nil,
        specialLabel: String? = nil,
    ) {
        _value = value
        self.range = range
        self.presets = presets
        self.step = step
        self.accessibilityTitle = accessibilityTitle
        self.unit = unit
        self.customInputScale = customInputScale
        self.valueLabel = valueLabel
        self.specialValue = specialValue
        self.specialLabel = specialLabel
    }

    private var presetItems: [Preset] {
        presets.enumerated().map { Preset(id: $0.offset, value: $0.element) }
    }

    private var currentSelection: Selection {
        if customFieldFocused {
            return .custom
        }
        if let specialValue, valuesAreEqual(value, specialValue) {
            return .special
        }
        if let presetIndex = presets.firstIndex(where: { valuesAreEqual(value, $0) }) {
            return .preset(presetIndex)
        }
        return .custom
    }

    private var customInputStep: Double {
        step * customInputScale
    }

    private var allowsFraction: Bool {
        customInputStep.rounded() != customInputStep
    }

    private var customFractionDigits: Int {
        var workingStep = customInputStep
        var digits = 0

        while workingStep.rounded() != workingStep, digits < 6 {
            workingStep *= 10
            digits += 1
        }

        return digits
    }

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: selectionBinding) {
                ForEach(presetItems) { preset in
                    Text(valueLabel(preset.value)).tag(Selection.preset(preset.id))
                }

                if let specialLabel {
                    Text(specialLabel).tag(Selection.special)
                }

                Text(L10n.Common.custom).tag(Selection.custom)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityLabel(Text(accessibilityTitle))
            .accessibilityValue(Text(valueLabel(value)))

            if currentSelection == .custom {
                HStack(spacing: 3) {
                    TextField("", text: customTextBinding)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .focused($customFieldFocused)
                        .onSubmit(commitCustomValue)
                        .onChange(of: customFieldFocused) { isFocused in
                            if !isFocused {
                                commitCustomValue()
                            }
                        }
                        .accessibilityLabel(Text(accessibilityTitle))
                        .accessibilityValue(Text(customText + (unit.isEmpty ? "" : " \(unit)")))

                    if !unit.isEmpty {
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            syncCustomText()
        }
        .onChange(of: value) { _ in
            if !customFieldFocused {
                syncCustomText()
            }
        }
    }

    private var selectionBinding: Binding<Selection> {
        Binding(
            get: { currentSelection },
            set: applySelection,
        )
    }

    private var customTextBinding: Binding<String> {
        Binding(
            get: { customText },
            set: { customText = PreferencesNumericPickerValue.sanitizedText($0, allowsFraction: allowsFraction) },
        )
    }

    private func applySelection(_ selection: Selection) {
        switch selection {
        case let .preset(index):
            guard presets.indices.contains(index) else { return }
            value = SteppedValue.snapped(presets[index], by: step, in: range)
            customFieldFocused = false
            syncCustomText()
        case .special:
            guard let specialValue else { return }
            value = SteppedValue.snapped(specialValue, by: step, in: range)
            customFieldFocused = false
            syncCustomText()
        case .custom:
            syncCustomText()
            customFieldFocused = true
        }
    }

    private func commitCustomValue() {
        guard let normalizedValue = PreferencesNumericPickerValue.normalizedValue(
            from: customText,
            range: range,
            step: step,
            inputScale: customInputScale,
        ) else {
            syncCustomText()
            return
        }

        value = normalizedValue
        syncCustomText()
    }

    private func syncCustomText() {
        customText = String(format: "%.\(customFractionDigits)f", value * customInputScale)
    }

    private func valuesAreEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < max(step * 0.001, 0.000001)
    }
}

#if DEBUG
    #Preview {
        struct PreviewHarness: View {
            @State private var value = 5.0

            var body: some View {
                PreferencesNumericPicker(
                    value: $value,
                    range: 1 ... 20,
                    presets: [2, 5, 10, 15],
                    step: 1,
                    accessibilityTitle: "Snap Distance",
                    unit: "px",
                    valueLabel: { "\(Int($0)) px" },
                )
                .padding()
            }
        }

        return PreviewHarness()
    }
#endif

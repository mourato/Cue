//
//  PreferencesQuickAccessSettingsView.swift
//  Notinhas
//
//  Quick Access (floating overlay) settings tab
//

import SwiftUI

struct QuickAccessSettingsView: View {
    private static let overlayScaleRange = 0.75 ... 1.5

    @ObservedObject private var manager = QuickAccessManager.shared
    @ObservedObject private var trackpadSwipeModeStore = QuickAccessTrackpadSwipeModeStore.shared

    @State private var positionIsLeft: Bool = false

    var body: some View {
        Form {
            QuickAccessActionCustomizationView(manager: manager)

            Section(L10n.PreferencesQuickAccess.positionSection) {
                SettingRow(
                    title: L10n.PreferencesQuickAccess.screenEdgeTitle,
                ) {
                    Picker("", selection: $positionIsLeft) {
                        Text(L10n.PreferencesQuickAccess.left).tag(true)
                        Text(L10n.PreferencesQuickAccess.right).tag(false)
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesQuickAccess.screenEdgeTitle)
                    .standardMenuPickerStyle()
                    .onChange(of: positionIsLeft) { newValue in
                        manager.setPosition(newValue ? .bottomLeft : .bottomRight)
                    }
                }
            }

            Section(L10n.PreferencesQuickAccess.appearanceSection) {
                SettingRow(
                    title: L10n.PreferencesQuickAccess.overlaySizeTitle,
                ) {
                    scalePicker(
                        selection: $manager.overlayScale,
                        range: Self.overlayScaleRange,
                        accessibilityLabel: L10n.PreferencesQuickAccess.overlaySizeTitle,
                    )
                }

                SettingRow(
                    title: L10n.PreferencesQuickAccess.cornerButtonSizeTitle,
                    description: L10n.PreferencesQuickAccess.cornerButtonSizeDescription,
                ) {
                    scalePicker(
                        selection: $manager.cornerButtonScale,
                        range: QuickAccessCornerButtonMetrics.scaleRange,
                        accessibilityLabel: L10n.PreferencesQuickAccess.cornerButtonSizeTitle,
                    )
                }
            }

            Section(L10n.PreferencesQuickAccess.behaviorsSection) {
                SettingRow(
                    title: L10n.PreferencesQuickAccess.floatingOverlayTitle,
                ) {
                    Toggle("", isOn: $manager.isEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesQuickAccess.floatingOverlayTitle)
                }

                SettingRow(title: L10n.PreferencesQuickAccess.autoCloseTitle, description: autoCloseDescription) {
                    Toggle("", isOn: $manager.autoDismissEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesQuickAccess.autoCloseTitle)
                }

                SettingRow(
                    title: L10n.PreferencesQuickAccess.hideCardWhenWindowOpenTitle,
                    description: L10n.PreferencesQuickAccess.hideCardWhenWindowOpenDescription,
                ) {
                    Toggle("", isOn: $manager.hideCardWhenWindowOpen)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesQuickAccess.hideCardWhenWindowOpenTitle)
                }

                SettingRow(
                    title: L10n.PreferencesQuickAccess.animationStyleTitle,
                ) {
                    Picker("", selection: $manager.animationStyle) {
                        ForEach(QuickAccessAnimationStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.PreferencesQuickAccess.animationStyleTitle)
                    .standardMenuPickerStyle()
                    .fixedSize()
                    .frame(width: 150, alignment: .trailing)
                }

                if manager.autoDismissEnabled {
                    HStack(spacing: 12) {
                        Text(L10n.PreferencesQuickAccess.closeAfter)
                            .font(.body)

                        Spacer()

                        PreferencesNumericPicker(
                            value: $manager.autoDismissDelay,
                            range: 3 ... 30,
                            presets: [5, 10, 20, 30],
                            step: 1,
                            accessibilityTitle: L10n.PreferencesQuickAccess.closeAfter,
                            unit: "s",
                            valueLabel: { "\(Int($0))s" },
                        )
                    }
                    .padding(.vertical, 4)
                }

                if manager.autoDismissEnabled {
                    SettingRow(
                        title: L10n.PreferencesQuickAccess.pauseOnHoverTitle,
                    ) {
                        Toggle("", isOn: $manager.pauseCountdownOnHover)
                            .labelsHidden()
                            .accessibilityLabel(L10n.PreferencesQuickAccess.pauseOnHoverTitle)
                    }
                }

                SettingRow(
                    title: L10n.PreferencesQuickAccess.dragAndDropTitle,
                ) {
                    Toggle("", isOn: $manager.dragDropEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesQuickAccess.dragAndDropTitle)
                }

                SettingRow(
                    title: L10n.PreferencesQuickAccess.twoFingerSwipeTitle,
                    description: L10n.PreferencesQuickAccess.twoFingerSwipeDescription,
                ) {
                    Toggle("", isOn: $manager.twoFingerSwipeToDismissEnabled)
                        .labelsHidden()
                        .accessibilityLabel(L10n.PreferencesQuickAccess.twoFingerSwipeTitle)
                }

                if manager.twoFingerSwipeToDismissEnabled {
                    SettingRow(
                        title: L10n.PreferencesQuickAccess.swipeSensitivityTitle,
                        description: L10n.PreferencesQuickAccess.swipeSensitivityDescription,
                    ) {
                        PreferencesNumericPicker(
                            value: $manager.swipeSensitivity,
                            range: 0.5 ... 3.0,
                            presets: [0.5, 1.0, 1.5, 2.0, 3.0],
                            step: 0.25,
                            accessibilityTitle: L10n.PreferencesQuickAccess.swipeSensitivityTitle,
                            unit: "%",
                            customInputScale: 100,
                            valueLabel: { "\(Int($0 * 100))%" },
                        )
                    }
                }
            }

            if manager.twoFingerSwipeToDismissEnabled {
                Section {
                    Picker(
                        L10n.PreferencesQuickAccess.trackpadSwipeModeTitle,
                        selection: Binding(
                            get: { trackpadSwipeModeStore.mode },
                            set: { trackpadSwipeModeStore.setMode($0) },
                        ),
                    ) {
                        ForEach(QuickAccessTrackpadSwipeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .accessibilityLabel(L10n.PreferencesQuickAccess.trackpadSwipeModeTitle)
                    .standardMenuPickerStyle()
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.PreferencesQuickAccess.trackpadSwipeModeDescription)
                        Text(L10n.PreferencesQuickAccess.swipeActionsDescription)
                    }
                }
            }
        }
        .preferencesFormStyle()
        .onAppear {
            positionIsLeft = manager.position.isLeftSide
        }
    }

    // MARK: - Helpers

    private func scalePicker(
        selection: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.25,
        accessibilityLabel: String,
    ) -> some View {
        let normalizedSelection = Binding(
            get: { SteppedValue.snapped(selection.wrappedValue, by: step, in: range) },
            set: { selection.wrappedValue = $0 },
        )

        return Picker("", selection: normalizedSelection) {
            ForEach(scaleChoices(in: range, step: step), id: \.self) { scale in
                Text("\(Int(scale * 100))%")
                    .tag(scale)
            }
        }
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
        .standardMenuPickerStyle()
        .fixedSize()
        .frame(width: 100, alignment: .trailing)
        .accessibilityValue(Text("\(Int(normalizedSelection.wrappedValue * 100))%"))
    }

    private func scaleChoices(in range: ClosedRange<Double>, step: Double) -> [Double] {
        let count = Int(((range.upperBound - range.lowerBound) / step).rounded())
        return (0 ... count).map { index in
            min(range.lowerBound + (Double(index) * step), range.upperBound)
        }
    }

    private var autoCloseDescription: String {
        if manager.autoDismissEnabled {
            return L10n.PreferencesQuickAccess.closesAfter(Int(manager.autoDismissDelay))
        }
        return L10n.PreferencesQuickAccess.keepOpenUntilDismissed
    }
}

#Preview {
    QuickAccessSettingsView()
        .frame(width: 600, height: 450)
}

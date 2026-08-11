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
                    icon: "rectangle.leadinghalf.inset.filled",
                    title: L10n.PreferencesQuickAccess.screenEdgeTitle,
                    description: L10n.PreferencesQuickAccess.screenEdgeDescription,
                ) {
                    Picker("", selection: $positionIsLeft) {
                        Text(L10n.PreferencesQuickAccess.left).tag(true)
                        Text(L10n.PreferencesQuickAccess.right).tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: positionIsLeft) { newValue in
                        manager.setPosition(newValue ? .bottomLeft : .bottomRight)
                    }
                }
            }

            Section(L10n.PreferencesQuickAccess.appearanceSection) {
                SettingRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: L10n.PreferencesQuickAccess.overlaySizeTitle,
                    description: L10n.PreferencesQuickAccess.overlaySizeDescription,
                ) {
                    scalePicker(selection: $manager.overlayScale, range: Self.overlayScaleRange)
                }

                SettingRow(
                    icon: "circle.grid.cross",
                    title: L10n.PreferencesQuickAccess.cornerButtonSizeTitle,
                    description: L10n.PreferencesQuickAccess.cornerButtonSizeDescription,
                ) {
                    scalePicker(selection: $manager.cornerButtonScale, range: QuickAccessCornerButtonMetrics.scaleRange)
                }
            }

            Section(L10n.PreferencesQuickAccess.behaviorsSection) {
                SettingRow(
                    icon: "square.on.square",
                    title: L10n.PreferencesQuickAccess.floatingOverlayTitle,
                    description: L10n.PreferencesQuickAccess.floatingOverlayDescription,
                ) {
                    Toggle("", isOn: $manager.isEnabled)
                        .labelsHidden()
                }

                SettingRow(icon: "timer", title: L10n.PreferencesQuickAccess.autoCloseTitle,
                           description: autoCloseDescription) {
                    Toggle("", isOn: $manager.autoDismissEnabled)
                        .labelsHidden()
                }

                SettingRow(
                    icon: "eye.slash",
                    title: L10n.PreferencesQuickAccess.hideCardWhenWindowOpenTitle,
                    description: L10n.PreferencesQuickAccess.hideCardWhenWindowOpenDescription,
                ) {
                    Toggle("", isOn: $manager.hideCardWhenWindowOpen)
                        .labelsHidden()
                }

                SettingRow(
                    icon: "sparkles",
                    title: L10n.PreferencesQuickAccess.animationStyleTitle,
                    description: L10n.PreferencesQuickAccess.animationStyleDescription,
                ) {
                    Picker("", selection: $manager.animationStyle) {
                        ForEach(QuickAccessAnimationStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .frame(width: 150, alignment: .trailing)
                }

                if manager.autoDismissEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(width: 28)

                        Text(L10n.PreferencesQuickAccess.closeAfter)
                            .fontWeight(.medium)

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
                        icon: "cursorarrow.motionlines",
                        title: L10n.PreferencesQuickAccess.pauseOnHoverTitle,
                        description: L10n.PreferencesQuickAccess.pauseOnHoverDescription,
                    ) {
                        Toggle("", isOn: $manager.pauseCountdownOnHover)
                            .labelsHidden()
                    }
                }

                SettingRow(
                    icon: "hand.draw",
                    title: L10n.PreferencesQuickAccess.dragAndDropTitle,
                    description: L10n.PreferencesQuickAccess.dragAndDropDescription,
                ) {
                    Toggle("", isOn: $manager.dragDropEnabled)
                        .labelsHidden()
                }

                SettingRow(
                    icon: "hand.point.right",
                    title: L10n.PreferencesQuickAccess.twoFingerSwipeTitle,
                    description: L10n.PreferencesQuickAccess.twoFingerSwipeDescription,
                ) {
                    Toggle("", isOn: $manager.twoFingerSwipeToDismissEnabled)
                        .labelsHidden()
                }

                if manager.twoFingerSwipeToDismissEnabled {
                    SettingRow(
                        icon: "gauge.with.dots.needle.33percent",
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
                Section(L10n.PreferencesQuickAccess.trackpadSwipeModeTitle) {
                    SettingRow(
                        icon: "arrow.left.arrow.right",
                        title: L10n.PreferencesQuickAccess.trackpadSwipeModeTitle,
                        description: L10n.PreferencesQuickAccess.trackpadSwipeModeDescription,
                    ) {
                        Picker("", selection: Binding(
                            get: { trackpadSwipeModeStore.mode },
                            set: { trackpadSwipeModeStore.setMode($0) },
                        )) {
                            ForEach(QuickAccessTrackpadSwipeMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        .frame(width: 200, alignment: .trailing)
                    }

                    Text(L10n.PreferencesQuickAccess.swipeActionsDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            positionIsLeft = manager.position.isLeftSide
        }
    }

    // MARK: - Helpers

    private func scalePicker(
        selection: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.25,
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
        .pickerStyle(.menu)
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

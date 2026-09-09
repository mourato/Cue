//
//  PreferencesUploadEncodingSettingsSection.swift
//  Cue
//
//  Image upload derivative controls for Settings → Uploads.
//

import SwiftUI

struct PreferencesUploadEncodingSettingsSection: View {
    @AppStorage(PreferencesKeys.uploadOptimizeImages) private var optimizeImages = true
    @AppStorage(PreferencesKeys.uploadImageFormat) private var imageFormat = CueUploadImageFormat.webp.rawValue
    @AppStorage(PreferencesKeys.uploadMaximumDimension) private var maximumDimension =
        CueUploadEncodingSettings.defaultMaximumDimension
    @AppStorage(PreferencesKeys.uploadJPEGQuality) private var jpegQuality =
        CueUploadEncodingSettings.defaultJPEGQuality

    var body: some View {
        Section {
            SettingRow(
                title: L10n.CloudSettings.optimizeImagesTitle,
                description: L10n.CloudSettings.optimizeImagesDescription,
            ) {
                Toggle("", isOn: $optimizeImages)
                    .labelsHidden()
                    .accessibilityLabel(L10n.CloudSettings.optimizeImagesTitle)
            }

            if optimizeImages {
                SettingRow(
                    title: L10n.CloudSettings.uploadImageFormatTitle,
                ) {
                    Picker("", selection: $imageFormat) {
                        ForEach(CueUploadImageFormat.allCases) { format in
                            Text(format.displayName).tag(format.rawValue)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(L10n.CloudSettings.uploadImageFormatTitle)
                    .standardMenuPickerStyle()
                    .fixedSize()
                }

                SettingRow(
                    title: L10n.CloudSettings.uploadMaximumDimensionTitle,
                    description: L10n.CloudSettings.uploadMaximumDimensionDescription,
                ) {
                    PreferencesNumericPicker(
                        value: Binding(
                            get: { Double(maximumDimension) },
                            set: { maximumDimension = Int($0.rounded()) },
                        ),
                        range: 512 ... 8192,
                        presets: [1024, 2048, 4096],
                        step: 64,
                        accessibilityTitle: L10n.CloudSettings.uploadMaximumDimensionTitle,
                        unit: "px",
                        valueLabel: { "\(Int($0)) px" },
                    )
                }

                if imageFormat == CueUploadImageFormat.jpeg.rawValue
                    || imageFormat == CueUploadImageFormat.webp.rawValue {
                    SettingRow(
                        title: L10n.CloudSettings.uploadQualityTitle,
                    ) {
                        HStack(spacing: 8) {
                            Slider(
                                value: $jpegQuality,
                                in: 0.5 ... 1.0,
                                step: 0.01,
                            )
                            .frame(width: 120)
                            .accessibilityLabel(L10n.CloudSettings.uploadQualityTitle)
                            .accessibilityValue(Text("\(Int((jpegQuality * 100).rounded()))%"))

                            Text("\(Int((jpegQuality * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        } header: {
            Text(L10n.CloudSettings.imageEncodingSection)
        } footer: {
            Text(L10n.CloudSettings.imageEncodingFooter)
        }
    }
}

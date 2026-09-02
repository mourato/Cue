import SwiftUI

struct CueVideoUploadOptionsView: View {
    let sourceSize: Int64
    let uploadLimit: Int64
    let onUpload: (CueVideoUploadSettings) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var settings = CueVideoUploadSettings.balanced

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverTokens.panelItemSpacing) {
            Text(L10n.QuickAccess.videoUploadTooLargeTitle)
                .font(.headline)

            Text(
                L10n.QuickAccess.videoUploadTooLargeMessage(
                    sourceSize: ByteCountFormatter.string(fromByteCount: sourceSize, countStyle: .file),
                    uploadLimit: ByteCountFormatter.string(fromByteCount: uploadLimit, countStyle: .file),
                ),
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            LabeledContent(L10n.QuickAccess.videoUploadFormat) {
                Text(L10n.QuickAccess.videoUploadMP4H264)
                    .foregroundStyle(.secondary)
            }

            Picker(L10n.QuickAccess.videoUploadDimensions, selection: $settings.maximumDimension) {
                ForEach([1_920, 1_280, 960], id: \.self) { dimension in
                    Text("\(dimension) px").tag(dimension)
                }
            }

            Picker(L10n.QuickAccess.videoUploadQuality, selection: $settings.quality) {
                ForEach(CueVideoUploadQuality.allCases) { quality in
                    Text(qualityName(quality)).tag(quality)
                }
            }

            Picker(L10n.QuickAccess.videoUploadFrameRate, selection: $settings.frameRate) {
                ForEach([60, 30, 24], id: \.self) { frameRate in
                    Text("\(frameRate) FPS").tag(frameRate)
                }
            }

            Toggle(L10n.QuickAccess.videoUploadAudio, isOn: $settings.includesAudio)

            HStack {
                Spacer()
                Button(L10n.Common.cancel) {
                    dismiss()
                }
                Button(L10n.QuickAccess.videoUploadOptimize) {
                    onUpload(settings)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, Spacing.xs)
        }
        .padding(PopoverTokens.panelContentInset)
        .frame(width: PopoverTokens.settingsPanelWidth)
    }

    private func qualityName(_ quality: CueVideoUploadQuality) -> String {
        switch quality {
        case .high: L10n.QuickAccess.videoUploadQualityHigh
        case .balanced: L10n.QuickAccess.videoUploadQualityBalanced
        case .compact: L10n.QuickAccess.videoUploadQualityCompact
        }
    }
}

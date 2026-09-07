//
//  PreferencesAfterCaptureMatrixView.swift
//  Notinhas
//
//  Grid component for configuring post-capture actions
//

import SwiftUI

struct AfterCaptureMatrixView: View {
    @ObservedObject private var manager = PreferencesManager.shared
    @State private var videoModuleEnabled = VideoModuleAvailability.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 12) {
                Spacer()
                HStack(spacing: 16) {
                    Text(CaptureType.screenshot.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 70)
                    if videoModuleEnabled {
                        Text(CaptureType.recording.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 70)
                    }
                }
            }
            .padding(.bottom, 4)

            ForEach(AfterCaptureAction.allCases, id: \.self) { action in
                actionRow(for: action)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoModuleAvailabilityDidChange)) { _ in
            videoModuleEnabled = VideoModuleAvailability.isEnabled
        }
    }

    private func actionRow(for action: AfterCaptureAction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.displayName)
                    .font(.body)
                Text(description(for: action))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                toggleColumn(captureType: .screenshot, action: action, type: .screenshot)
                if videoModuleEnabled {
                    toggleColumn(captureType: .recording, action: action, type: .recording)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func toggleColumn(captureType: CaptureType, action: AfterCaptureAction, type: CaptureType) -> some View {
        if action.supports(type) {
            Toggle("", isOn: binding(for: action, type: type))
                .labelsHidden()
                .accessibilityLabel(L10n.AfterCapture.accessibilityLabel(
                    action.displayName,
                    captureKind: captureType.displayName,
                ))
                .frame(width: 70)
        } else {
            Text(verbatim: "—")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 70)
                .accessibilityLabel(L10n.AfterCapture.accessibilityLabel(
                    action.displayName,
                    captureKind: captureType.displayName,
                ))
                .accessibilityValue(Text(L10n.AfterCapture.notApplicable))
        }
    }

    private func description(for action: AfterCaptureAction) -> String {
        switch action {
        case .showQuickAccess:
            L10n.AfterCapture.showQuickAccessDescription
        case .copyFile:
            L10n.AfterCapture.copyFileDescription
        case .save:
            L10n.AfterCapture.saveDescription
        case .uploadToCloud:
            L10n.AfterCapture.uploadToCloudDescription
        case .openAnnotate:
            L10n.AfterCapture.openAnnotateDescription
        case .pinToScreen:
            L10n.AfterCapture.pinToScreenDescription
        case .openVideoEditor:
            L10n.AfterCapture.openVideoEditorDescription
        }
    }

    private func binding(for action: AfterCaptureAction, type: CaptureType) -> Binding<Bool> {
        Binding(
            get: { manager.isActionEnabled(action, for: type) },
            set: { manager.setAction(action, for: type, enabled: $0) },
        )
    }
}

#Preview {
    AfterCaptureMatrixView()
        .padding()
}

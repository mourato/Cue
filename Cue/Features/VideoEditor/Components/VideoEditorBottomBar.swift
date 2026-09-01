#if CUE_VIDEO_MODULE
//
    //  VideoEditorBottomBar.swift
    //  Notinhas
//

    import SwiftUI

    struct VideoEditorBottomBar: View {
        @ObservedObject var state: VideoEditorState
        var primaryActionTitle: String = L10n.VideoEditor.convert
        var onCancel: () -> Void
        var onConvert: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    Button(L10n.Common.cancel, action: onCancel)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(primaryActionTitle, action: onConvert)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("s", modifiers: [.command])
                }
                .padding(.horizontal, WindowSpacingConfiguration.default.toolbarHPadding)
                .padding(.vertical, 12)
            }
        }
    }
#endif

//
//  AnnotateMainView.swift
//  Notinhas
//
//  Main container view for annotation window
//

import SwiftUI

private struct AnnotateWorkspaceBackground: View {
    private let dotSpacing: CGFloat = 18
    private let dotRadius: CGFloat = 1.15

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.93))

            Canvas { context, size in
                var path = Path()
                let offset = dotSpacing / 2

                for x in stride(from: offset, through: size.width, by: dotSpacing) {
                    for y in stride(from: offset, through: size.height, by: dotSpacing) {
                        path.addEllipse(in: CGRect(
                            x: x - dotRadius,
                            y: y - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2,
                        ))
                    }
                }

                context.fill(path, with: .color(Color.secondary.opacity(0.14)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Main container for annotation window layout
struct AnnotateMainView: View {
    @StateObject var state: AnnotateState
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Hide toolbar in preview mode
            if state.editorMode != .preview {
                AnnotateToolbarView(state: state)
                    .padding(.top, 0) // Add top padding for traffic lights

                Divider()
                    .background(Color(nsColor: .separatorColor))
            }

            HStack(spacing: 0) {
                if state.leftDock != .hidden, state.editorMode != .preview {
                    AnnotateEditorSideDock {
                        switch state.leftDock {
                        case .background:
                            AnnotateSidebarView(state: state)
                                .equatable()
                        case .notes:
                            CueNotesSidePanelView(
                                notes: state.cueNotes,
                                selectedNoteID: state.notinhasSelectedNoteID,
                                onSelect: { state.notinhasSelectNote(id: $0) },
                                onDelete: { state.notinhasDeleteNote(id: $0) },
                            )
                        case .hidden:
                            EmptyView()
                        }
                    }
                    .transition(.move(edge: .leading))

                    Divider()
                        .background(Color.white.opacity(0.1))
                }

                ZStack(alignment: .top) {
                    if !state.showsNotinhasExportPreview {
                        AnnotateWorkspaceBackground()
                    }

                    Group {
                        if state.showsNotinhasExportPreview, let previewImage = state.notinhasExportPreviewImage {
                            AnnotateExportPreviewView(image: previewImage)
                        } else {
                            AnnotateCanvasView(state: state)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle()) // Constrain hit-test area to frame bounds
                    .clipped() // Prevent canvas content from overlapping toolbar/bottombar
                    .onChange(of: state.cueNotes) { _ in
                        if state.showsNotinhasExportPreview {
                            state.refreshNotinhasExportPreview()
                        }
                    }

                    if state.showsQuickPropertiesBar {
                        AnnotateQuickPropertiesBar(state: state)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .zIndex(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    AnnotateBottomBarView(state: state)
                        .zIndex(2)
                }
            }
        }
        .preferredColorScheme(themeManager.systemAppearance)
        .ignoresSafeArea(.all, edges: .top) // Extend background behind title bar
        .animation(.easeInOut(duration: 0.14), value: state.showsQuickPropertiesBar)
    }
}

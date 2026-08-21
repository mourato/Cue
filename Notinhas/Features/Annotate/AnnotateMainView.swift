//
//  AnnotateMainView.swift
//  Notinhas
//
//  Main container view for annotation window
//

import SwiftUI

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

                if state.showsQuickPropertiesBar {
                    AnnotateQuickPropertiesBar(state: state)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }

            HStack(spacing: 0) {
                if state.leftDock != .hidden, state.editorMode != .preview {
                    AnnotateEditorSideDock {
                        switch state.leftDock {
                        case .background:
                            AnnotateSidebarView(state: state)
                                .equatable()
                        case .notes:
                            NotinhasNotesSidePanelView(
                                notes: state.notinhasNotes,
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
                    .onChange(of: state.notinhasNotes) { _ in
                        if state.showsNotinhasExportPreview {
                            state.refreshNotinhasExportPreview()
                        }
                    }

                    if state.showsQuickPropertiesBar {
                        AnnotateQuickPropertiesBar(state: state)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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

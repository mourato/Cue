//
//  AnnotateEditorSideDock.swift
//  Notinhas
//
//  Shared chrome for the annotate editor left dock (Background or Notes).
//

import SwiftUI

struct AnnotateEditorSideDock<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            content
                .padding(Spacing.md)
        }
        .frame(width: 240)
        .frame(maxHeight: .infinity)
    }
}

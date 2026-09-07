//
//  PreferencesSettingRow.swift
//  Notinhas
//
//  Reusable settings row with title, optional description, and trailing content
//

import SwiftUI

struct SettingRow<Content: View>: View {
    let title: String
    let description: String?
    var tooltip: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        description: String? = nil,
        tooltip: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.description = description
        self.tooltip = tooltip
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let tooltip {
                    Text(title)
                        .font(.body)
                        .hint(tooltip, variant: .icon(.info))
                } else {
                    Text(title)
                        .font(.body)
                }
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            content()
        }
        .padding(.vertical, 4)
    }
}

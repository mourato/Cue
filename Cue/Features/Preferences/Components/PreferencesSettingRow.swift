//
//  PreferencesSettingRow.swift
//  Notinhas
//
//  Reusable settings row with icon, title, description, and trailing content
//

import SwiftUI

struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let description: String?
    var tooltip: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                if let tooltip {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .hint(tooltip, variant: .icon(.info))
                } else {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
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

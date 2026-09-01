//
//  KeyCapView.swift
//  Notinhas
//
//  macOS-native keycap rendering for keyboard shortcuts
//

import SwiftUI

enum KeyCapMetrics {
    static let side: CGFloat = 18
    static let horizontalPadding: CGFloat = 4
    static let cornerRadius: CGFloat = 6
    static let chipSpacing: CGFloat = 2
}

/// Renders a single keyboard key as a compact keycap chip.
struct KeyCapView: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(minWidth: KeyCapMetrics.side, minHeight: KeyCapMetrics.side)
            .padding(.horizontal, KeyCapMetrics.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: KeyCapMetrics.cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.12)),
            )
            .overlay(
                RoundedRectangle(cornerRadius: KeyCapMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1),
            )
    }
}

/// Renders an array of key parts as adjacent keycap chips.
struct KeyCapGroupView: View {
    let parts: [String]

    var body: some View {
        HStack(spacing: KeyCapMetrics.chipSpacing) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                KeyCapView(symbol: part)
            }
        }
    }
}

#Preview("KeyCap Group") {
    VStack(spacing: 16) {
        KeyCapGroupView(parts: ["⌘", "⇧", "3"])
        KeyCapGroupView(parts: ["⌃", "Y"])
        KeyCapGroupView(parts: ["⌥", "⌘", "A"])
        KeyCapView(symbol: "R")
    }
    .padding(32)
}

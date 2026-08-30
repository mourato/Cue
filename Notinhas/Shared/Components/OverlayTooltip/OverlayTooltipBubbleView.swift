import SwiftUI

struct OverlayTooltipBubbleView: View {
    let content: OverlayTooltipContent

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                if let secondary = content.secondary, !secondary.isEmpty {
                    Text(secondary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if !content.keys.isEmpty {
                HStack(spacing: KeyCapMetrics.chipSpacing) {
                    ForEach(Array(content.keys.enumerated()), id: \.offset) { _, key in
                        KeyCapView(symbol: key)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5),
        )
        .fixedSize()
    }
}

#Preview("Overlay Tooltip") {
    VStack(spacing: 16) {
        OverlayTooltipBubbleView(content: .init(title: "Reload this page", keys: ["⌘", "R"]))
        OverlayTooltipBubbleView(content: .init(title: "Save", keys: ["⌘", "⏎"]))
        OverlayTooltipBubbleView(content: .init(title: "Delete note"))
        OverlayTooltipBubbleView(content: .init(
            title: "Note",
            keys: ["N"],
            secondary: "Click to pin · Drag for area",
        ))
    }
    .padding(40)
}

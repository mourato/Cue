//
//  QuickPropertiesFlowLayout.swift
//  Notinhas
//
//  Width-constrained wrapping layout for the annotate quick properties bar.
//

import CoreGraphics
import SwiftUI

struct QuickPropertiesFlowLayoutItem: Equatable {
    let size: CGSize
    let isRowLeadingDivider: Bool
}

struct QuickPropertiesFlowLayoutResult: Equatable {
    let size: CGSize
    let placements: [CGPoint]
    let skippedDividerIndices: [Int]
}

enum QuickPropertiesFlowLayoutEngine {
    static func layout(
        items: [QuickPropertiesFlowLayoutItem],
        maxWidth: CGFloat,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
    ) -> QuickPropertiesFlowLayoutResult {
        guard !items.isEmpty else {
            return QuickPropertiesFlowLayoutResult(size: .zero, placements: [], skippedDividerIndices: [])
        }

        let effectiveMaxWidth = maxWidth.isFinite ? max(maxWidth, 0) : .greatestFiniteMagnitude
        var placements = Array(repeating: CGPoint.zero, count: items.count)
        var skippedDividerIndices: [Int] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for index in items.indices {
            let item = items[index]

            if item.isRowLeadingDivider, x == 0 {
                skippedDividerIndices.append(index)
                continue
            }

            if x > 0, x + item.size.width > effectiveMaxWidth {
                y += rowHeight + verticalSpacing
                contentWidth = max(contentWidth, x - horizontalSpacing)
                x = 0
                rowHeight = 0

                if item.isRowLeadingDivider {
                    skippedDividerIndices.append(index)
                    continue
                }
            }

            placements[index] = CGPoint(x: x, y: y)
            x += item.size.width
            contentWidth = max(contentWidth, x)
            rowHeight = max(rowHeight, item.size.height)
            x += horizontalSpacing
        }

        let totalHeight = y + rowHeight
        return QuickPropertiesFlowLayoutResult(
            size: CGSize(width: contentWidth, height: totalHeight),
            placements: placements,
            skippedDividerIndices: skippedDividerIndices,
        )
    }
}

private struct QuickPropertiesFlowRowLeadingDividerKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    func quickPropertiesFlowRowLeadingDivider(_ isLeadingDivider: Bool = true) -> some View {
        layoutValue(key: QuickPropertiesFlowRowLeadingDividerKey.self, value: isLeadingDivider)
    }
}

struct QuickPropertiesFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let items = subviews.map { subview in
            let size = subview.sizeThatFits(.unspecified)
            let isDivider = subview[QuickPropertiesFlowRowLeadingDividerKey.self]
            return QuickPropertiesFlowLayoutItem(size: size, isRowLeadingDivider: isDivider)
        }

        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        return QuickPropertiesFlowLayoutEngine.layout(
            items: items,
            maxWidth: maxWidth,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
        ).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let items = subviews.map { subview in
            let size = subview.sizeThatFits(.unspecified)
            let isDivider = subview[QuickPropertiesFlowRowLeadingDividerKey.self]
            return QuickPropertiesFlowLayoutItem(size: size, isRowLeadingDivider: isDivider)
        }

        let maxWidth = proposal.width ?? bounds.width
        let result = QuickPropertiesFlowLayoutEngine.layout(
            items: items,
            maxWidth: maxWidth,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
        )
        let skipped = Set(result.skippedDividerIndices)

        for index in subviews.indices {
            guard !skipped.contains(index) else { continue }

            let item = items[index]
            let origin = result.placements[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(item.size),
            )
        }
    }
}

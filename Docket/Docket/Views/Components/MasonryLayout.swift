//
//  MasonryLayout.swift
//  Docket
//
//  Two-column (configurable) masonry: each subview is measured at column width
//  and placed into the currently-shortest column, so variable-height cards pack
//  like a pinboard. Pure Layout — no state, no model knowledge.
//

import SwiftUI

nonisolated struct MasonryLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let heights = columnHeights(subviews: subviews, totalWidth: width).heights
        return CGSize(width: width, height: max((heights.max() ?? 0) - spacing, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidth = self.columnWidth(totalWidth: bounds.width)
        var heights = [CGFloat](repeating: 0, count: columns)

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let column = shortestColumn(heights)
            let x = bounds.minX + CGFloat(column) * (columnWidth + spacing)
            let y = bounds.minY + heights[column]
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: columnWidth, height: size.height)
            )
            heights[column] += size.height + spacing
        }
    }

    // MARK: Internals

    private func columnWidth(totalWidth: CGFloat) -> CGFloat {
        max((totalWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns), 0)
    }

    private func shortestColumn(_ heights: [CGFloat]) -> Int {
        heights.enumerated().min { $0.element < $1.element }?.offset ?? 0
    }

    private func columnHeights(subviews: Subviews, totalWidth: CGFloat) -> (heights: [CGFloat], columnWidth: CGFloat) {
        let columnWidth = self.columnWidth(totalWidth: totalWidth)
        var heights = [CGFloat](repeating: 0, count: columns)
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            heights[shortestColumn(heights)] += size.height + spacing
        }
        return (heights, columnWidth)
    }
}

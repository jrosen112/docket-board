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
    /// Extra transparent space each subview carries around its visible content.
    /// The layout removes it from measurement and placement calculations so
    /// visual column widths and gaps remain unchanged.
    var contentOverflow: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let heights = columnHeights(subviews: subviews, totalWidth: width).heights
        return CGSize(width: width, height: max((heights.max() ?? 0) - spacing, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidth = self.columnWidth(totalWidth: bounds.width)
        let proposedWidth = columnWidth + contentOverflow * 2
        var heights = [CGFloat](repeating: 0, count: columns)

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: proposedWidth, height: nil))
            let contentHeight = max(size.height - contentOverflow * 2, 0)
            let column = shortestColumn(heights)
            let x =
                bounds.minX
                + CGFloat(column) * (columnWidth + spacing)
                - contentOverflow
            let y = bounds.minY + heights[column] - contentOverflow
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: proposedWidth, height: size.height)
            )
            heights[column] += contentHeight + spacing
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
        let proposedWidth = columnWidth + contentOverflow * 2
        var heights = [CGFloat](repeating: 0, count: columns)
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: proposedWidth, height: nil))
            let contentHeight = max(size.height - contentOverflow * 2, 0)
            heights[shortestColumn(heights)] += contentHeight + spacing
        }
        return (heights, columnWidth)
    }
}

//
//  MasonryLayout.swift
//  Docket
//
//  Width-driven masonry: the column count comes from how much width there is,
//  each subview is measured at column width and placed into the currently-
//  shortest column, so variable-height cards pack like a pinboard. Pure Layout
//  — no state, no model knowledge.
//

import SwiftUI

nonisolated struct MasonryLayout: Layout {
    /// The column width the board aims for. Count is derived from the available
    /// width against this, so a wider screen gets *more* cards rather than
    /// bigger ones — an iPad card should read like a phone card, not a blown-up
    /// one. On a standard phone the math lands back on two columns exactly.
    var targetColumnWidth: CGFloat
    /// Floor for narrow widths, so a small phone or a slim split-view pane
    /// still reads as a board rather than a single stack.
    var minimumColumns: Int = 2
    var spacing: CGFloat = 14
    /// Extra transparent space each subview carries around its visible content.
    /// The layout removes it from measurement and placement calculations so
    /// visual column widths and gaps remain unchanged.
    var contentOverflow: CGFloat = 0

    /// How many columns fit `totalWidth` at roughly `targetColumnWidth` each.
    /// Rounded, not floored: at 1.9 targets' worth of width, two slightly-narrow
    /// columns beat one very wide one.
    func columnCount(totalWidth: CGFloat) -> Int {
        guard totalWidth.isFinite, totalWidth > 0, targetColumnWidth > 0 else {
            return minimumColumns
        }
        let fit = (totalWidth + spacing) / (targetColumnWidth + spacing)
        return max(minimumColumns, Int(fit.rounded()))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let heights = columnHeights(subviews: subviews, totalWidth: width).heights
        return CGSize(width: width, height: max((heights.max() ?? 0) - spacing, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columnCount(totalWidth: bounds.width)
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

    func columnWidth(totalWidth: CGFloat) -> CGFloat {
        let columns = columnCount(totalWidth: totalWidth)
        return max((totalWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns), 0)
    }

    private func shortestColumn(_ heights: [CGFloat]) -> Int {
        heights.enumerated().min { $0.element < $1.element }?.offset ?? 0
    }

    private func columnHeights(subviews: Subviews, totalWidth: CGFloat) -> (heights: [CGFloat], columnWidth: CGFloat) {
        let columnWidth = self.columnWidth(totalWidth: totalWidth)
        let proposedWidth = columnWidth + contentOverflow * 2
        var heights = [CGFloat](repeating: 0, count: columnCount(totalWidth: totalWidth))
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: proposedWidth, height: nil))
            let contentHeight = max(size.height - contentOverflow * 2, 0)
            heights[shortestColumn(heights)] += contentHeight + spacing
        }
        return (heights, columnWidth)
    }
}

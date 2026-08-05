//
//  BoardLongPressLayout.swift
//  Docket
//
//  How much room the long-press surface has, and how much the lifted card has
//  to give up to fit.
//
//  The surface is one centered column — picker, lifted card, poster, reaction
//  attributions, action menu — so nothing has to be placed relative to wherever
//  the card happened to sit on the board. That leaves two things to decide.
//
//  The card is the only element whose height varies without bound (a short bar
//  card and a long recipe are the same surface), so when the column overflows
//  the card is what shrinks. The chrome never scales — a picker or a menu row
//  that shrank would stop being reliably tappable.
//
//  A movie's poster is elastic in the other direction: it has a floor it must
//  clear to be worth showing and a ceiling that keeps it from crowding out the
//  card and menu, and in between it simply takes whatever the column has left. That is why it is a
//  panel of its own rather than something inside the card — at a fixed size it
//  would force either a scroll on every movie or a thumbnail.
//
//  Pure arithmetic: no SwiftUI and no theme lookups, so the rules can be
//  verified without rendering anything.
//

import CoreGraphics

/// Sizing rules for a lifted movie's artwork.
nonisolated struct BoardLongPressPosterMetrics: Equatable, Sendable {
    /// Width over height. A poster is 2:3.
    var aspectRatio: CGFloat
    /// Below this the poster is too small to be worth the room it costs, so the
    /// column overflows and scrolls instead of shrinking it further.
    var minimumHeight: CGFloat
    /// Ceiling on how much of the leftover room the poster may take, so it
    /// cannot crowd out the card and menu it sits with.
    var maximumHeight: CGFloat
}

nonisolated struct BoardLongPressMetrics: Equatable, Sendable {
    var pickerHeight: CGFloat
    /// Natural height of the lifted card, before any scaling.
    var cardHeight: CGFloat
    /// Height of the attribution chips, or zero when the item has no reactions.
    var attributionHeight: CGFloat
    var menuHeight: CGFloat
    /// Gap between adjacent elements in the column.
    var spacing: CGFloat
    /// Breathing room kept inside the safe area.
    var screenMargin: CGFloat
    /// How far the card is allowed to shrink before the column is simply
    /// allowed to overflow and scroll instead. Past this, shrinking stops
    /// buying legibility and starts costing it.
    var minimumCardScale: CGFloat
    /// Present only when the lifted item carries poster artwork.
    var poster: BoardLongPressPosterMetrics?
}

nonisolated struct BoardLongPressLayout: Equatable, Sendable {
    /// Scale applied to the lifted card. Always in `minimumCardScale...1`.
    var cardScale: CGFloat
    /// Height of the whole column with `cardScale` applied.
    var columnHeight: CGFloat
    /// Room the column had to work with.
    var availableHeight: CGFloat
    /// Height for the poster panel, or nil when the item has no artwork.
    var posterHeight: CGFloat?
    /// True when the column overflows even at the smallest allowed card, which
    /// is the view's cue to let the surface scroll.
    var scrolls: Bool
}

nonisolated enum BoardLongPressLayoutSolver {
    static func solve(
        containerHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        metrics: BoardLongPressMetrics
    ) -> BoardLongPressLayout {
        let available = max(
            containerHeight - safeAreaTop - safeAreaBottom - metrics.screenMargin * 2,
            0
        )

        // Every gap that exists regardless of the card's size. The attribution
        // row is absent entirely when nobody has reacted, and takes its spacing
        // with it rather than leaving a gap; the poster does the same.
        let attributionChrome =
            metrics.attributionHeight > 0
            ? metrics.attributionHeight + metrics.spacing
            : 0
        let posterChrome =
            metrics.poster.map { $0.minimumHeight + metrics.spacing } ?? 0
        let chrome =
            metrics.pickerHeight
            + metrics.menuHeight
            + attributionChrome
            + posterChrome
            + metrics.spacing * 2

        // The poster's floor is charged to the card before the card is sized,
        // so a movie's card yields room to its own artwork rather than the
        // poster being squeezed into whatever is left.
        let roomForCard = available - chrome
        let fittedScale =
            metrics.cardHeight > 0
            ? roomForCard / metrics.cardHeight
            : 1
        let cardScale = min(max(fittedScale, metrics.minimumCardScale), 1)
        let usedByCard = metrics.cardHeight * cardScale

        // Whatever the card did not need goes to the poster, up to full width.
        let posterHeight = metrics.poster.map { poster in
            let leftover = max(available - chrome - usedByCard, 0)
            return min(poster.minimumHeight + leftover, poster.maximumHeight)
        }
        let columnHeight =
            chrome - posterChrome
            + usedByCard
            + (posterHeight.map { $0 + metrics.spacing } ?? 0)

        return BoardLongPressLayout(
            cardScale: cardScale,
            columnHeight: columnHeight,
            availableHeight: available,
            posterHeight: posterHeight,
            // Rounding noise in measured heights shouldn't flip a column that
            // fits to the letter into a scrolling one.
            scrolls: columnHeight - available > 0.5
        )
    }
}

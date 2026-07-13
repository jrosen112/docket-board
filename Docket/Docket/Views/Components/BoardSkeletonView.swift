import SwiftUI

struct BoardSkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        skeletonCards
            .overlay {
                if !reduceMotion {
                    TimelineView(
                        .animation(
                            minimumInterval: DocketTheme.BoardSkeleton.shimmerFrameInterval
                        )
                    ) { context in
                        shimmer(at: context.date)
                    }
                    .mask(skeletonCards)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading board items")
    }

    private var skeletonCards: some View {
        MasonryLayout(
            columns: DocketTheme.BoardSkeleton.columns,
            spacing: DocketTheme.BoardSkeleton.cardSpacing
        ) {
            ForEach(0..<DocketTheme.BoardSkeleton.cardCount, id: \.self) { index in
                BoardSkeletonCard(index: index)
            }
        }
    }

    private func shimmer(at date: Date) -> some View {
        GeometryReader { geometry in
            let width = DocketTheme.BoardSkeleton.shimmerWidth
            let travel = geometry.size.width + width * 2
            let progress = DocketTheme.BoardSkeleton.shimmerProgress(at: date)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            DocketTheme.BoardSkeleton.shimmerColor,
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: width,
                    height: geometry.size.height
                        * DocketTheme.BoardSkeleton.shimmerHeightMultiplier
                )
                .rotationEffect(DocketTheme.BoardSkeleton.shimmerAngle)
                .offset(
                    x: -width + travel * progress,
                    y: geometry.size.height
                        * DocketTheme.BoardSkeleton.shimmerVerticalOffsetMultiplier
                )
        }
    }
}

private struct BoardSkeletonCard: View {
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DocketTheme.BoardSkeleton.contentSpacing) {
            placeholderLine(
                height: DocketTheme.BoardSkeleton.categoryLineHeight,
                trailingInset: DocketTheme.BoardSkeleton.categoryTrailingInset
            )
            placeholderLine(
                height: DocketTheme.BoardSkeleton.titleLineHeight,
                trailingInset: DocketTheme.BoardSkeleton.titleTrailingInset(for: index)
            )
            placeholderLine(
                height: DocketTheme.BoardSkeleton.detailLineHeight,
                trailingInset: DocketTheme.BoardSkeleton.detailTrailingInset(for: index)
            )

            Spacer(minLength: 0)

            Capsule()
                .fill(DocketTheme.BoardSkeleton.lineFill)
                .frame(
                    width: DocketTheme.BoardSkeleton.statusWidth,
                    height: DocketTheme.BoardSkeleton.statusHeight
                )
            placeholderLine(
                height: DocketTheme.BoardSkeleton.authorLineHeight,
                trailingInset: DocketTheme.BoardSkeleton.authorTrailingInset
            )
        }
        .padding(DocketTheme.BoardSkeleton.cardPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: DocketTheme.BoardSkeleton.cardHeight(for: index),
            maxHeight: DocketTheme.BoardSkeleton.cardHeight(for: index),
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: DocketTheme.BoardSkeleton.cardCornerRadius)
                .fill(DocketTheme.BoardSkeleton.cardFill)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(DocketTheme.BoardSkeleton.stripeFill)
                .frame(width: DocketTheme.BoardSkeleton.stripeWidth)
                .padding(.vertical, DocketTheme.BoardSkeleton.stripeVerticalPadding)
                .padding(.leading, DocketTheme.BoardSkeleton.stripeLeadingPadding)
        }
        .overlay(alignment: .top) {
            Circle()
                .fill(DocketTheme.BoardSkeleton.pinFill)
                .frame(
                    width: DocketTheme.BoardSkeleton.pinSize,
                    height: DocketTheme.BoardSkeleton.pinSize
                )
                .offset(y: DocketTheme.BoardSkeleton.pinOffsetY)
        }
        .rotationEffect(
            .degrees(DocketTheme.rotationDegrees(for: "board-skeleton-\(index)"))
        )
    }

    private func placeholderLine(height: CGFloat, trailingInset: CGFloat) -> some View {
        Capsule()
            .fill(DocketTheme.BoardSkeleton.lineFill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.trailing, trailingInset)
    }
}

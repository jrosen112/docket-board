//
//  BoardLongPressOverlay.swift
//  Docket
//
//  What a long press on a board card opens: a dimmed backdrop and one centered
//  column — tapback picker, the lifted item, who reacted, action menu.
//
//  The item lifts off the board and floats to the middle rather than staying
//  under the finger. That is the whole reason this can be a fixed column: a
//  short bar card pressed at the bottom of the screen and a long recipe pressed
//  at the top produce the same arrangement, so nothing has to be re-anchored or
//  flipped, and the only thing that ever varies is how much the card has to
//  shrink to fit (`BoardLongPressLayoutSolver`).
//
//  Heights are measured rather than assumed, because all four elements are
//  content-sized — the menu grows with the number of boards, the chips with the
//  number of reactions, and the card with whatever the item happens to carry.
//  The column stays invisible for the one layout pass that takes, which is also
//  the pass that positions the card for its flight in from the board.
//

import SwiftUI

struct BoardLongPressOverlay: View {
    let item: any SharedListItem
    let addedBy: String
    let attributions: [BoardReactionAttribution]
    let currentReaction: BoardReactionKind?
    /// Where the card sits on the board, in this overlay's coordinate space,
    /// when that is known. Optional because it comes from a preference read at
    /// the root of the screen: the surface must still open if that read comes
    /// back empty, just without the flight in from the board.
    let sourceFrame: CGRect?
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let actions: [BoardLongPressAction]
    let onSelectReaction: (BoardReactionKind) -> Void
    let onDismiss: () -> Void

    @State private var isShowingEmojiGrid = false
    @State private var heights = MeasuredHeights()
    @State private var cardFrame: CGRect?
    @State private var isLifted = false

    private static let coordinateSpace = "boardLongPress"

    /// Poster artwork, when the item is a movie carrying some. A movie's board
    /// card is nothing but its poster, so lifting one into a panel of text
    /// alone loses the only thing that identified it.
    private var posterData: Data? {
        guard item is Movie else { return nil }
        return item.photoData
    }

    private var layout: BoardLongPressLayout {
        BoardLongPressLayoutSolver.solve(
            containerHeight: containerSize.height,
            safeAreaTop: safeAreaInsets.top,
            safeAreaBottom: safeAreaInsets.bottom,
            metrics: BoardLongPressMetrics(
                pickerHeight: heights.picker,
                cardHeight: heights.card ?? 0,
                attributionHeight: heights.attributions,
                menuHeight: heights.menu,
                spacing: DocketTheme.BoardLongPress.spacing,
                screenMargin: DocketTheme.BoardLongPress.screenMargin,
                minimumCardScale: DocketTheme.BoardLongPress.minimumCardScale,
                poster: posterData == nil
                    ? nil
                    : BoardLongPressPosterMetrics(
                        aspectRatio: DocketTheme.BoardLongPress.posterAspectRatio,
                        minimumHeight: DocketTheme.BoardLongPress.posterMinimumHeight,
                        maximumHeight: DocketTheme.BoardLongPress.posterMaximumHeight
                    )
            )
        )
    }

    /// Everything has to be on screen before the lift can be animated from the
    /// board — the card's resting position is what the flight animates away
    /// from, and that is only known once it has been laid out.
    private var isMeasured: Bool {
        heights.card != nil && heights.picker > 0 && heights.menu > 0
            && (cardFrame != nil || sourceFrame == nil)
    }

    /// Distance from where the card comes to rest back to where it sat on the
    /// board. Applied while un-lifted so the flight starts from the board.
    private var liftOffset: CGSize {
        guard !isLifted, let sourceFrame, let cardFrame else { return .zero }
        return CGSize(
            width: sourceFrame.midX - cardFrame.midX,
            height: sourceFrame.midY - cardFrame.midY
        )
    }

    var body: some View {
        ZStack {
            backdrop
            column
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .onChange(of: isMeasured, initial: true) { _, measured in
            guard measured, !isLifted else { return }
            withAnimation(DocketTheme.BoardLongPress.presentationAnimation) {
                isLifted = true
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
    }

    private var backdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(DocketTheme.ink.opacity(DocketTheme.BoardLongPress.backdropOpacity))
            .ignoresSafeArea()
            .opacity(isLifted ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityLabel("Close")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onDismiss)
    }

    @ViewBuilder
    private var column: some View {
        let stack = VStack(spacing: DocketTheme.BoardLongPress.spacing) {
            picker
            liftedCard
            if let posterData, let posterHeight = layout.posterHeight {
                poster(posterData, height: posterHeight)
            }
            if !attributions.isEmpty {
                chips
            }
            menu
        }
        .frame(width: DocketTheme.BoardLongPress.surfaceWidth)
        .opacity(isMeasured && isLifted ? 1 : 0)

        if layout.scrolls {
            ScrollView {
                stack
                    .padding(.vertical, DocketTheme.BoardLongPress.screenMargin)
                    // Scroll content is placed at the leading edge; the column
                    // is narrower than the screen and has to stay centered.
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        } else {
            stack
        }
    }

    @ViewBuilder
    private var picker: some View {
        Group {
            if isShowingEmojiGrid {
                BoardEmojiGrid(
                    selectedKind: currentReaction,
                    onSelect: onSelectReaction,
                    onBack: {
                        withAnimation(DocketTheme.BoardLongPress.submenuAnimation) {
                            isShowingEmojiGrid = false
                        }
                    }
                )
            } else {
                BoardReactionPickerBar(
                    selectedKind: currentReaction,
                    onSelect: onSelectReaction,
                    onMore: {
                        withAnimation(DocketTheme.BoardLongPress.submenuAnimation) {
                            isShowingEmojiGrid = true
                        }
                    }
                )
            }
        }
        .measuringHeight { heights.picker = $0 }
    }

    private var liftedCard: some View {
        let scale = layout.cardScale

        return BoardItemQuickLookView(
            item: item,
            addedBy: addedBy,
            // Artwork below is already showing what the facts, notes, and
            // footer would repeat, so the card is reduced to naming the item.
            style: posterData == nil ? .full : .title
        )
        // Ideal size regardless of what is proposed. Without this the card
        // is measured *inside* the frame that the measurement computes, so
        // any content that can compress — notes, a wrapped title — feeds
        // its own constraint and the column collapses around it.
        .fixedSize()
        .measuringHeight { heights.card = $0 }
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(Self.coordinateSpace))
        } action: { frame in
            guard sourceFrame != nil else { return }
            // Only the resting position matters; ignore the frame while the
            // card is mid-flight or it would chase its own animation.
            guard !isLifted else { return }
            cardFrame = frame
        }
        .rotationEffect(
            .degrees(isLifted ? 0 : DocketTheme.BoardLongPress.liftInitialRotation)
        )
        .scaleEffect(
            isLifted ? scale : scale * DocketTheme.BoardLongPress.liftInitialScale,
            anchor: .center
        )
        .offset(liftOffset)
        // Reserve only the space the scaled card actually occupies —
        // `scaleEffect` alone would leave the column full of dead space.
        .frame(height: heights.card.map { $0 * scale })
        // Opening the emoji grid takes room from the card. Keyed to the
        // scale alone so this never fights the entrance animation.
        .animation(DocketTheme.BoardLongPress.submenuAnimation, value: scale)
    }

    private func poster(_ data: Data, height: CGFloat) -> some View {
        BoardLongPressPoster(data: data, height: height, title: item.title)
            .opacity(isLifted ? 1 : 0)
            .animation(DocketTheme.BoardLongPress.submenuAnimation, value: height)
    }

    private var chips: some View {
        BoardReactionAttributionChips(attributions: attributions)
            .measuringHeight { heights.attributions = $0 }
            .opacity(isLifted ? 1 : 0)
    }

    private var menu: some View {
        BoardLongPressMenu(actions: actions)
            .measuringHeight { heights.menu = $0 }
            .opacity(isLifted ? 1 : 0)
    }
}

private struct MeasuredHeights: Equatable {
    var picker: CGFloat = 0
    var attributions: CGFloat = 0
    var menu: CGFloat = 0
    /// Natural height of the lifted card. Optional because zero is a real
    /// measurement the solver would act on, and "not yet measured" is not.
    var card: CGFloat?
}

extension View {
    /// The drop shadow shared by every floating piece of the long-press surface.
    func boardLongPressShadow() -> some View {
        shadow(
            color: .black.opacity(DocketTheme.BoardLongPress.shadowOpacity),
            radius: DocketTheme.BoardLongPress.shadowRadius,
            y: DocketTheme.BoardLongPress.shadowY
        )
    }

    fileprivate func measuringHeight(_ action: @escaping (CGFloat) -> Void) -> some View {
        onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: action)
    }
}

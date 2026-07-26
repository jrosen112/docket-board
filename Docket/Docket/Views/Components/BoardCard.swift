//
//  BoardCard.swift
//  Docket
//
//  One pinned card on the board: themed stock, brass pin, category accent
//  stripe, serif title, deterministic slight tilt. Movies with artwork use a
//  full-bleed poster treatment; other items keep the tactile paper layout.
//  Dumb component — everything it shows arrives via init; taps/menus are
//  attached by the parent.
//

import CloudKit
import SwiftUI

struct BoardCard: View {
    @Environment(\.docketSurfacePalette) private var palette

    let item: any SharedListItem
    let reactionGroups: [BoardReactionGroup]
    let onReactionHold: () -> Void
    var showsPin = true

    private var accent: Color { item.category.accent }
    private var cues: [BoardCardCue] { boardCardCues(for: item) }

    @ViewBuilder
    var body: some View {
        if item is Movie,
            item.showsPhotoOnBoard,
            let photoData = item.photoData
        {
            moviePosterCard(photoData)
        } else {
            paperCard
        }
    }

    private var paperCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.category.label.uppercased())
                .font(DocketTheme.BoardCardHeader.categoryFont)
                .tracking(DocketTheme.BoardCardHeader.categoryTracking)
                .foregroundStyle(accent)
                .lineLimit(1)

            if item.showsPhotoOnBoard, let photoData = item.photoData {
                GeometryReader { geometry in
                    BoardCroppedPhoto(
                        data: photoData,
                        position: item.boardPhotoPosition
                    )
                    .frame(
                        width: geometry.size.width,
                        height: DocketTheme.BoardCard.photoHeight
                    )
                    .clipped()
                }
                .frame(height: DocketTheme.BoardCard.photoHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DocketTheme.BoardCard.photoCornerRadius,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)
            } else if let location = boardMapLocation {
                GeometryReader { geometry in
                    LocationMapSnapshotView(location: location)
                        .frame(
                            width: geometry.size.width,
                            height: DocketTheme.BoardCard.photoHeight
                        )
                        .clipped()
                }
                .frame(maxWidth: .infinity)
                .frame(height: DocketTheme.BoardCard.photoHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DocketTheme.BoardCard.photoCornerRadius,
                        style: .continuous
                    )
                )
            }

            Text(item.title)
                .font(DocketTheme.display(17))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !cues.isEmpty {
                BoardCardCueList(
                    cues: cues,
                    foregroundColor: palette.secondaryText
                )
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(palette.bodyText)
                    .lineLimit(2)
            }

            cardStatusLabel(foregroundColor: palette.secondaryText)
                .padding(.top, DocketTheme.StatusBadge.cardTopPadding)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(palette.paper)
                .shadow(color: palette.shadow, radius: 4, x: 0, y: 3)
        )
        .overlay(alignment: .leading) {
            // Category accent stripe along the card's left edge.
            Capsule()
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 12)
                .padding(.leading, 5)
        }
        .overlay(alignment: .top) {
            if showsPin {
                BoardPinHead()
                    .offset(y: DocketTheme.BoardCard.pinOffsetY)
            }
        }
        .overlay(alignment: .topTrailing) {
            reactionCluster
        }
        .rotationEffect(.degrees(DocketTheme.rotationDegrees(for: item.id.recordName)))
    }

    private var boardMapLocation: ItemLocation? {
        guard let locatedItem = item as? any LocatedListItem,
            locatedItem.showsMapOnBoard
        else { return nil }
        return locatedItem.location
    }

    private func moviePosterCard(_ photoData: Data) -> some View {
        ZStack(alignment: .bottomLeading) {
            DocketTheme.ink

            GeometryReader { geometry in
                BoardCroppedPhoto(
                    data: photoData,
                    position: item.boardPhotoPosition
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .accessibilityHidden(true)

            LinearGradient(
                colors: DocketTheme.BoardCard.moviePosterGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: DocketTheme.BoardCard.movieTextSpacing) {
                Text(item.title)
                    .font(DocketTheme.BoardCard.movieTitleFont)
                    .foregroundStyle(DocketTheme.BoardCard.moviePrimaryText)
                    .lineLimit(DocketTheme.BoardCard.movieTitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                if !cues.isEmpty {
                    BoardCardCueList(
                        cues: cues,
                        foregroundColor: DocketTheme.BoardCard.movieSecondaryText
                    )
                }

                HStack(alignment: .bottom, spacing: DocketTheme.BoardCard.categoryFooterSpacing) {
                    posterStatusChip

                    Spacer(minLength: 0)
                    categoryBadge
                }
            }
            .padding(DocketTheme.BoardCard.movieContentPadding)
        }
        .aspectRatio(DocketTheme.BoardCard.movieArtworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DocketTheme.BoardCard.movieCornerRadius,
                style: .continuous
            )
        )
        .background(
            RoundedRectangle(
                cornerRadius: DocketTheme.BoardCard.movieCornerRadius,
                style: .continuous
            )
            .fill(palette.paper)
            .shadow(color: palette.shadow, radius: 5, x: 0, y: 4)
        )
        .overlay(alignment: .top) {
            if showsPin {
                BoardPinHead()
                    .offset(y: DocketTheme.BoardCard.pinOffsetY)
            }
        }
        .overlay(alignment: .topTrailing) {
            reactionCluster
        }
        .rotationEffect(.degrees(DocketTheme.rotationDegrees(for: item.id.recordName)))
    }

    @ViewBuilder
    private var reactionCluster: some View {
        if !reactionGroups.isEmpty {
            BoardReactionCluster(
                groups: reactionGroups,
                onLongPress: onReactionHold
            )
            .offset(
                x: DocketTheme.BoardReaction.clusterOffsetX,
                y: DocketTheme.BoardReaction.clusterOffsetY
            )
        }
    }

    private var categoryBadge: some View {
        Image(systemName: item.category.symbol)
            .font(DocketTheme.BoardCard.categoryBadgeSymbolFont)
            .foregroundStyle(.white)
            .frame(
                width: DocketTheme.BoardCard.categoryBadgeSize,
                height: DocketTheme.BoardCard.categoryBadgeSize
            )
            .background(accent, in: Circle())
            .accessibilityHidden(true)
    }

    private var posterStatusChip: some View {
        cardStatusLabel(foregroundColor: DocketTheme.BoardCard.moviePrimaryText)
            .padding(.horizontal, DocketTheme.BoardCard.movieBadgeHorizontalPadding)
            .padding(.vertical, DocketTheme.BoardCard.movieBadgeVerticalPadding)
            .background(DocketTheme.BoardCard.movieBadgeBackground, in: Capsule())
    }

    private func cardStatusLabel(foregroundColor: Color) -> some View {
        HStack(spacing: DocketTheme.BoardCard.statusSpacing) {
            Circle()
                .fill(item.status.chipColor)
                .frame(
                    width: DocketTheme.BoardCard.statusDotSize,
                    height: DocketTheme.BoardCard.statusDotSize
                )
            Text(item.status.label(for: item.category))
                .lineLimit(1)
        }
        .font(DocketTheme.BoardCard.statusFont)
        .foregroundStyle(foregroundColor)
        .accessibilityElement(children: .combine)
    }
}

private struct BoardCardCueList: View {
    let cues: [BoardCardCue]
    let foregroundColor: Color

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: DocketTheme.BoardCard.cueSpacing
        ) {
            ForEach(cues) { cue in
                HStack(
                    alignment: .firstTextBaseline,
                    spacing: DocketTheme.BoardCard.cueIconSpacing
                ) {
                    Image(systemName: cue.symbol)
                        .font(DocketTheme.BoardCard.cueSymbolFont)
                        .frame(width: DocketTheme.BoardCard.cueSymbolWidth)

                    Text(cue.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(DocketTheme.BoardCard.cueFont)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct BoardReactionCluster: View {
    let groups: [BoardReactionGroup]
    let onLongPress: () -> Void

    private var visibleGroups: ArraySlice<BoardReactionGroup> {
        groups.prefix(DocketTheme.BoardReaction.maximumVisibleKinds)
    }

    private var hiddenKindCount: Int {
        max(groups.count - visibleGroups.count, 0)
    }

    private var accessibilityDescription: String {
        groups.map { group in
            "\(group.kind.label), \(group.count)"
        }
        .joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: DocketTheme.BoardReaction.clusterSpacing) {
            ForEach(visibleGroups) { group in
                HStack(spacing: 1) {
                    Text(group.kind.rawValue)
                    if group.count > 1 {
                        Text("\(group.count)")
                            .font(DocketTheme.BoardReaction.countFont)
                            .foregroundStyle(DocketTheme.ink)
                    }
                }
                .padding(.horizontal, group.count > 1 ? 3 : 1)
                .background {
                    if group.includesCurrentUser {
                        Capsule()
                            .fill(DocketTheme.brass.opacity(0.2))
                    }
                }
            }

            if hiddenKindCount > 0 {
                Text("+\(hiddenKindCount)")
                    .font(DocketTheme.BoardReaction.moreFont)
                    .foregroundStyle(DocketTheme.ink.opacity(0.7))
            }
        }
        .font(DocketTheme.BoardReaction.emojiFont)
        .padding(.horizontal, DocketTheme.BoardReaction.clusterHorizontalPadding)
        .padding(.vertical, DocketTheme.BoardReaction.clusterVerticalPadding)
        .background(
            Capsule()
                .fill(DocketTheme.cream)
                .shadow(
                    color: .black.opacity(DocketTheme.BoardReaction.shadowOpacity),
                    radius: DocketTheme.BoardReaction.shadowRadius,
                    y: DocketTheme.BoardReaction.shadowY
                )
        )
        .overlay {
            Capsule()
                .stroke(DocketTheme.brass.opacity(0.45), lineWidth: 0.75)
        }
        .contentShape(Capsule())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: DocketTheme.BoardReaction.holdDuration)
                .onEnded { _ in onLongPress() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reactions: \(accessibilityDescription)")
        .accessibilityHint("Touch and hold to see who reacted")
        .accessibilityAction(named: "Show who reacted", onLongPress)
    }
}

/// The paper-and-pin silhouette used by the lifted context-menu preview.
/// The surrounding transition capture area stays transparent instead of
/// receiving the system's rectangular highlight.
struct BoardCardPreviewShape: Shape {
    let captureInset: CGFloat
    let rotationDegrees: Double

    func path(in rect: CGRect) -> Path {
        let cardRect = rect.insetBy(dx: captureInset, dy: captureInset)
        var path = Path(
            roundedRect: cardRect,
            cornerRadius: 5,
            style: .continuous
        )
        path.addEllipse(
            in: CGRect(
                x: cardRect.midX - 5.5,
                y: cardRect.minY - 5,
                width: 11,
                height: 11
            )
        )

        let radians = CGFloat(rotationDegrees * .pi / 180)
        let rotation = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: radians)
            .translatedBy(x: -rect.midX, y: -rect.midY)
        return path.applying(rotation)
    }
}

/// The brass push-pin head shared by cards and their removal animation.
struct BoardPinHead: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [DocketTheme.brass, DocketTheme.brass.opacity(0.7)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: 7
                )
            )
            .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 0.5))
            .frame(
                width: DocketTheme.BoardCard.pinSize,
                height: DocketTheme.BoardCard.pinSize
            )
            .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0, y: 1.5)
    }
}

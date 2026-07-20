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

import SwiftUI
import CloudKit

struct BoardCard: View {
    @Environment(\.docketSurfacePalette) private var palette

    let item: any SharedListItem
    let subtitle: String?
    let addedBy: String

    private var accent: Color { item.category.accent }

    @ViewBuilder
    var body: some View {
        if item is Movie,
           item.showsPhotoOnBoard,
           let photoData = item.photoData {
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
                    ItemPhotoImage(data: photoData, contentMode: .fill)
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

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(palette.bodyText)
                    .lineLimit(3)
            }

            StatusChip(status: item.status)
                .padding(.top, DocketTheme.StatusBadge.cardTopPadding)

            Text("— \(addedBy)")
                .font(.caption2.italic())
                .foregroundStyle(palette.mutedText)
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
            PinDot().offset(y: -5)
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
                ItemPhotoImage(data: photoData, contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
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

                if let subtitle {
                    Text(subtitle)
                        .font(DocketTheme.BoardCard.movieSubtitleFont)
                        .foregroundStyle(DocketTheme.BoardCard.movieSecondaryText)
                        .lineLimit(2)
                }

                Text("— \(addedBy)")
                    .font(DocketTheme.BoardCard.movieAuthorFont)
                    .foregroundStyle(DocketTheme.BoardCard.movieMutedText)
                    .lineLimit(1)
            }
            .padding(DocketTheme.BoardCard.movieContentPadding)
        }
        .overlay(alignment: .top) {
            HStack(alignment: .center, spacing: DocketTheme.BoardCard.movieBadgeSpacing) {
                Label("MOVIE", systemImage: "film.fill")
                    .font(DocketTheme.BoardCard.movieBadgeFont)
                    .tracking(DocketTheme.BoardCard.movieBadgeTracking)
                    .foregroundStyle(DocketTheme.BoardCard.moviePrimaryText)
                    .padding(.horizontal, DocketTheme.BoardCard.movieBadgeHorizontalPadding)
                    .padding(.vertical, DocketTheme.BoardCard.movieBadgeVerticalPadding)
                    .background(
                        DocketTheme.BoardCard.movieBadgeBackground,
                        in: Capsule()
                    )

                Spacer(minLength: 0)

                HStack(spacing: DocketTheme.BoardCard.movieStatusSpacing) {
                    Circle()
                        .fill(item.status.chipColor)
                        .frame(
                            width: DocketTheme.BoardCard.movieStatusDotSize,
                            height: DocketTheme.BoardCard.movieStatusDotSize
                        )
                    Text(item.status.label)
                        .lineLimit(1)
                }
                .font(DocketTheme.BoardCard.movieStatusFont)
                .foregroundStyle(DocketTheme.BoardCard.moviePrimaryText)
                .padding(.horizontal, DocketTheme.BoardCard.movieBadgeHorizontalPadding)
                .padding(.vertical, DocketTheme.BoardCard.movieBadgeVerticalPadding)
                .background(
                    DocketTheme.BoardCard.movieBadgeBackground,
                    in: Capsule()
                )
            }
            .padding(DocketTheme.BoardCard.movieBadgeInset)
        }
        .aspectRatio(DocketTheme.BoardCard.moviePosterAspectRatio, contentMode: .fit)
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
            PinDot().offset(y: -5)
        }
        .rotationEffect(.degrees(DocketTheme.rotationDegrees(for: item.id.recordName)))
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

/// The brass "push pin" head at the top of each card.
private struct PinDot: View {
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
            .frame(width: 11, height: 11)
            .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0, y: 1.5)
    }
}

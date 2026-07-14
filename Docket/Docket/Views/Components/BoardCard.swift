//
//  BoardCard.swift
//  Docket
//
//  One pinned card on the board: cream stock, brass pin, category accent
//  stripe, serif title, deterministic slight tilt. Dumb component — everything
//  it shows arrives via init; taps/menus are attached by the parent.
//

import SwiftUI
import CloudKit

struct BoardCard: View {
    let item: any SharedListItem
    let subtitle: String?
    let addedBy: String

    private var accent: Color { item.category.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.category.label.uppercased())
                .font(DocketTheme.BoardCardHeader.categoryFont)
                .tracking(DocketTheme.BoardCardHeader.categoryTracking)
                .foregroundStyle(accent)
                .lineLimit(1)

            Text(item.title)
                .font(DocketTheme.display(17))
                .foregroundStyle(DocketTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DocketTheme.ink.opacity(0.65))
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(DocketTheme.ink.opacity(0.8))
                    .lineLimit(3)
            }

            StatusChip(status: item.status)
                .padding(.top, DocketTheme.StatusBadge.cardTopPadding)

            Text("— \(addedBy)")
                .font(.caption2.italic())
                .foregroundStyle(DocketTheme.ink.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(DocketTheme.cream)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
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

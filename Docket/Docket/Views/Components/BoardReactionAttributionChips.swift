//
//  BoardReactionAttributionChips.swift
//  Docket
//
//  Who reacted to the lifted item, as small paper chips under the card: the
//  emoji, then the faces behind it.
//
//  This is the whole attribution story now — it is always visible while an item
//  is lifted, rather than hidden behind a second gesture on the card's reaction
//  badge. On a two-person board it is usually one chip reading "❤️ Sam".
//
//  Dumb component — everything it shows arrives via init.
//

import SwiftUI

struct BoardReactionAttributionChips: View {
    let attributions: [BoardReactionAttribution]

    var body: some View {
        HStack(spacing: DocketTheme.BoardLongPress.chipSpacing) {
            ForEach(attributions) { attribution in
                chip(attribution)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ attribution: BoardReactionAttribution) -> some View {
        HStack(spacing: DocketTheme.BoardLongPress.chipSpacing) {
            Text(attribution.kind.rawValue)
                .font(DocketTheme.BoardLongPress.chipEmojiFont)

            // One person reads better as a name; more than one would run past
            // the chip, so the faces carry it instead.
            if attribution.people.count == 1, let person = attribution.people.first {
                Text(person.displayName)
                    .font(DocketTheme.BoardLongPress.chipNameFont)
                    .foregroundStyle(DocketTheme.ink.opacity(0.8))
                    .lineLimit(1)
            } else {
                BoardReactionAvatarStack(people: attribution.people)
            }
        }
        .padding(.horizontal, DocketTheme.BoardLongPress.chipHorizontalPadding)
        .padding(.vertical, DocketTheme.BoardLongPress.chipVerticalPadding)
        .background(DocketTheme.cream, in: Capsule())
        .boardLongPressShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(attribution.kind.label) from "
                + attribution.people.map(\.displayName).joined(separator: ", ")
        )
    }
}

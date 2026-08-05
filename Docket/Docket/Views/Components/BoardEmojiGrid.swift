//
//  BoardEmojiGrid.swift
//  Docket
//
//  What the picker's `+` opens: a curated grid of emoji to react with.
//
//  iOS has no public emoji-picker API, and the alternative — driving the system
//  keyboard from a hidden text field — opens whichever keyboard the user last
//  used and covers the surface it was opened from. A fixed grid keeps the
//  interaction inside the long-press surface and on-theme, at the cost of not
//  reaching every emoji in Unicode.
//
//  Dumb component — everything it shows arrives via init.
//

import SwiftUI

struct BoardEmojiGrid: View {
    let selectedKind: BoardReactionKind?
    let onSelect: (BoardReactionKind) -> Void
    let onBack: () -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: DocketTheme.BoardLongPress.emojiGridSpacing
            ),
            count: DocketTheme.BoardLongPress.emojiGridColumns
        )
    }

    var body: some View {
        VStack(spacing: DocketTheme.BoardLongPress.emojiGridSpacing) {
            header

            ScrollView {
                LazyVGrid(
                    columns: columns,
                    spacing: DocketTheme.BoardLongPress.emojiGridSpacing
                ) {
                    ForEach(BoardEmojiCatalog.kinds) { kind in
                        Button {
                            onSelect(kind)
                        } label: {
                            cell(kind)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(kind.label)
                    }
                }
            }
            .frame(maxHeight: DocketTheme.BoardLongPress.emojiGridMaximumHeight)
            .scrollIndicators(.hidden)
        }
        .padding(DocketTheme.BoardLongPress.emojiGridPadding)
        .frame(width: DocketTheme.BoardLongPress.surfaceWidth)
        .background(
            DocketTheme.cream,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.BoardLongPress.cornerRadius,
                style: .continuous
            )
        )
        .boardLongPressShadow()
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(DocketTheme.BoardLongPress.menuChevronFont)
                    .foregroundStyle(DocketTheme.ink.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to tapbacks")

            Spacer(minLength: 4)

            Text("PICK A REACTION")
                .font(DocketTheme.BoardLongPress.emojiGridTitleFont)
                .tracking(DocketTheme.BoardLongPress.emojiGridTitleTracking)
                .foregroundStyle(DocketTheme.ink.opacity(0.5))

            Spacer(minLength: 4)

            // Balances the back button so the title stays centered.
            Color.clear.frame(width: 28, height: 28)
        }
    }

    private func cell(_ kind: BoardReactionKind) -> some View {
        let isSelected = selectedKind == kind
        let highlight =
            isSelected
            ? DocketTheme.brass.opacity(DocketTheme.BoardLongPress.pickerSelectionOpacity)
            : Color.clear

        return Text(kind.rawValue)
            .font(DocketTheme.BoardLongPress.emojiGridFont)
            .frame(
                width: DocketTheme.BoardLongPress.emojiGridCellSize,
                height: DocketTheme.BoardLongPress.emojiGridCellSize
            )
            .background(highlight, in: Circle())
    }
}

/// The emoji the grid offers, in reading order.
///
/// Deliberately a fixed list rather than an exhaustive one: it is meant to
/// cover how two people react to bars, restaurants, recipes, and movies, not to
/// replace a keyboard. `BoardReactionKind` accepts any emoji, so growing this
/// list later costs nothing and invalidates no stored reaction.
nonisolated enum BoardEmojiCatalog {
    static let kinds: [BoardReactionKind] = rawEmoji.compactMap(BoardReactionKind.init(rawValue:))

    /// Kept visible so a test can catch an entry that validation dropped —
    /// `compactMap` would otherwise swallow a mistyped emoji silently.
    static let rawEmoji = [
        // Feeling
        "😍", "🥰", "😂", "🤣", "😭", "🥺", "😅", "😎", "🤔", "😴", "🙄", "😤", "🤯", "🫠",
        // Yes / no
        "🔥", "✨", "💯", "🙌", "👏", "🤌", "👌", "🙏", "💪", "🫶", "👀", "🚫", "😬", "🤢",
        // Eating and drinking
        "🍕", "🌮", "🍣", "🍜", "🍔", "🥐", "🍰", "🍦", "🍫", "🥗", "🍳", "🧀", "🌶️", "🧄",
        "🍷", "🍸", "🍺", "🥂", "☕️", "🧋", "🍹", "🥤",
        // Going out and doing things
        "🎬", "🍿", "🎟️", "🎉", "🕺", "💃", "🎶", "🏖️", "⛰️", "🥾", "🚗", "✈️", "🗺️", "📸",
        // Timing and money
        "⏰", "📅", "💸", "🤑", "🎁", "❤️‍🔥", "💔", "⭐️",
    ]
}

//
//  BoardReactionPickerBar.swift
//  Docket
//
//  The tapback row at the top of the long-press surface: the six standard
//  kinds, a divider, and a `+` that opens the emoji grid.
//
//  A custom emoji the current user already picked is shown inline ahead of the
//  divider, because otherwise there would be no way to take it back — tapping
//  your own reaction is how you remove it.
//
//  Dumb component — everything it shows arrives via init.
//

import SwiftUI

struct BoardReactionPickerBar: View {
    let selectedKind: BoardReactionKind?
    let onSelect: (BoardReactionKind) -> Void
    let onMore: () -> Void

    /// The standard set, plus the user's own pick when it came from the grid.
    private var kinds: [BoardReactionKind] {
        guard let selectedKind, !selectedKind.isStandard else {
            return BoardReactionKind.standard
        }
        return BoardReactionKind.standard + [selectedKind]
    }

    var body: some View {
        HStack(spacing: DocketTheme.BoardLongPress.pickerSpacing) {
            ForEach(kinds) { kind in
                Button {
                    onSelect(kind)
                } label: {
                    emoji(kind)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    selectedKind == kind
                        ? "\(kind.label), selected. Activate to remove"
                        : kind.label
                )
            }

            Rectangle()
                .fill(DocketTheme.ink.opacity(0.15))
                .frame(
                    width: 1,
                    height: DocketTheme.BoardLongPress.pickerDividerHeight
                )
                .padding(.horizontal, 2)

            Button(action: onMore) {
                Image(systemName: "plus")
                    .font(DocketTheme.BoardLongPress.pickerPlusFont)
                    .foregroundStyle(DocketTheme.ink.opacity(0.6))
                    .frame(
                        width: DocketTheme.BoardLongPress.pickerButtonSize,
                        height: DocketTheme.BoardLongPress.pickerButtonSize
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More reactions")
        }
        .padding(.horizontal, DocketTheme.BoardLongPress.pickerPadding)
        .padding(.vertical, DocketTheme.BoardLongPress.pickerPadding)
        .background(DocketTheme.cream, in: Capsule())
        .boardLongPressShadow()
    }

    private func emoji(_ kind: BoardReactionKind) -> some View {
        let isSelected = selectedKind == kind
        let highlight =
            isSelected
            ? DocketTheme.brass.opacity(DocketTheme.BoardLongPress.pickerSelectionOpacity)
            : Color.clear

        return Text(kind.rawValue)
            .font(DocketTheme.BoardLongPress.pickerEmojiFont)
            .frame(
                width: DocketTheme.BoardLongPress.pickerButtonSize,
                height: DocketTheme.BoardLongPress.pickerButtonSize
            )
            .background(highlight, in: Circle())
    }
}

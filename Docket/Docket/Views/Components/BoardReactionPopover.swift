//
//  BoardReactionPopover.swift
//  Docket
//
//  Compact tapback picker and the attribution view shown by holding the
//  reaction cluster on a card.
//

import SwiftUI

struct BoardReactionPickerView: View {
    let selectedKind: BoardReactionKind?
    let onSelect: (BoardReactionKind) -> Void

    var body: some View {
        HStack(spacing: DocketTheme.BoardReaction.pickerSpacing) {
            ForEach(BoardReactionKind.allCases) { kind in
                Button {
                    onSelect(kind)
                } label: {
                    Text(kind.rawValue)
                        .font(DocketTheme.BoardReaction.pickerEmojiFont)
                        .frame(
                            width: DocketTheme.BoardReaction.pickerButtonSize,
                            height: DocketTheme.BoardReaction.pickerButtonSize
                        )
                        .background(
                            selectedKind == kind
                                ? DocketTheme.brass.opacity(0.3)
                                : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    selectedKind == kind
                        ? "\(kind.label), selected. Tap to remove"
                        : kind.label
                )
            }
        }
        .padding(DocketTheme.BoardReaction.popoverPadding)
        .background(DocketTheme.ink, in: Capsule())
        .shadow(
            color: .black.opacity(DocketTheme.BoardReaction.overlayShadowOpacity),
            radius: DocketTheme.BoardReaction.overlayShadowRadius,
            y: DocketTheme.BoardReaction.overlayShadowY
        )
    }
}

struct BoardReactionAttributionView: View {
    let title: String
    let attributions: [BoardReactionAttribution]

    var body: some View {
        VStack(alignment: .leading, spacing: DocketTheme.BoardReaction.popoverSpacing) {
            Text("Reactions to “\(title)”")
                .font(DocketTheme.BoardReaction.popoverTitleFont)
                .foregroundStyle(DocketTheme.ink)
                .lineLimit(2)

            ForEach(attributions) { attribution in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(attribution.kind.rawValue)
                        .font(DocketTheme.BoardReaction.pickerEmojiFont)
                        .accessibilityLabel(attribution.kind.label)
                    Text(attribution.names.joined(separator: ", "))
                        .font(DocketTheme.BoardReaction.attributionNameFont)
                        .foregroundStyle(DocketTheme.ink.opacity(0.82))
                }
            }
        }
        .padding(DocketTheme.BoardReaction.popoverPadding)
        .frame(maxWidth: DocketTheme.BoardReaction.popoverMaximumWidth, alignment: .leading)
        .background(DocketTheme.cream)
    }
}

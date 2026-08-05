//
//  BoardReactionAvatarStack.swift
//  Docket
//
//  Who reacted with one emoji, as overlapping avatars.
//
//  A single person is just their avatar. More than one collapses into a stack
//  with the first person in front, covering the others. Tapping spreads the stack
//  out so every face is visible; tapping again collapses it. The behavior is the
//  same at any participant count — two people who both picked the same tapback
//  read as a stack of two, and the same gesture opens larger boards later.
//
//  Dumb component — it owns only its own expanded state.
//

import SwiftUI

struct BoardReactionAvatarStack: View {
    let people: [BoardReactionPerson]
    var size: CGFloat = DocketTheme.Avatar.stackSize

    @State private var isExpanded = false

    private var isCollapsible: Bool { people.count > 1 }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                ProfileAvatar(
                    initials: person.initials,
                    imageData: person.imageData,
                    size: size,
                    ringColor: DocketTheme.Avatar.stackRingColor
                )
                // Earlier reactors sit in front, so the stack reads front-to-back
                // in the order people reacted.
                .zIndex(Double(people.count - index))
            }
        }
        .animation(DocketTheme.Avatar.stackAnimation, value: isExpanded)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCollapsible else { return }
            isExpanded.toggle()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isCollapsible ? .isButton : [])
        .accessibilityHint(isCollapsible ? "Shows everyone who reacted" : "")
    }

    /// Negative spacing overlaps the avatars when collapsed; expanding relaxes it
    /// to a normal gap so each face is fully visible.
    private var spacing: CGFloat {
        guard isCollapsible, !isExpanded else { return DocketTheme.Avatar.stackExpandedSpacing }
        return -size * DocketTheme.Avatar.stackOverlapFraction
    }

    private var accessibilityLabel: String {
        people.map(\.displayName).joined(separator: ", ")
    }
}

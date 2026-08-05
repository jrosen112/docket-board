//
//  BoardLongPressMenu.swift
//  Docket
//
//  The action menu at the bottom of the long-press surface: pinned cream paper
//  with one row per action.
//
//  Submenus (Duplicate/Move to Board) push in place rather than opening a
//  second floating panel — the surface is already a fixed centered column, and
//  a panel flying out sideways would have nowhere predictable to land. A row
//  with children swaps the menu's contents for those children plus a way back.
//
//  Dumb component — the actions and their handlers arrive via init; the only
//  state it owns is which submenu is open.
//

import SwiftUI

/// One row in the long-press menu. A row either runs a handler or opens
/// `children`; the menu treats a row with children as a submenu regardless of
/// whether it also carries a handler.
struct BoardLongPressAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var isDestructive = false
    var isEnabled = true
    var children: [BoardLongPressAction] = []
    var handler: (() -> Void)?

    var hasChildren: Bool { !children.isEmpty }
}

struct BoardLongPressMenu: View {
    let actions: [BoardLongPressAction]

    @State private var openSubmenuID: BoardLongPressAction.ID?

    private var openSubmenu: BoardLongPressAction? {
        guard let openSubmenuID else { return nil }
        return actions.first { $0.id == openSubmenuID }
    }

    private var visibleActions: [BoardLongPressAction] {
        openSubmenu?.children ?? actions
    }

    var body: some View {
        VStack(spacing: 0) {
            if let openSubmenu {
                backRow(to: openSubmenu)
                divider
            }

            ForEach(Array(visibleActions.enumerated()), id: \.element.id) { index, action in
                if index > 0 {
                    divider
                }
                row(action)
            }
        }
        .frame(width: DocketTheme.BoardLongPress.menuWidth)
        .background(
            DocketTheme.cream,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.BoardLongPress.cornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            BoardPinHead()
                .offset(y: DocketTheme.BoardCard.pinOffsetY)
        }
        .boardLongPressShadow()
        .animation(DocketTheme.BoardLongPress.submenuAnimation, value: openSubmenuID)
    }

    private var divider: some View {
        Rectangle()
            .fill(DocketTheme.BoardLongPress.menuDividerColor)
            .frame(height: 1)
            .padding(.leading, DocketTheme.BoardLongPress.menuRowHorizontalPadding)
    }

    private func row(_ action: BoardLongPressAction) -> some View {
        Button {
            if action.hasChildren {
                openSubmenuID = action.id
            } else {
                action.handler?()
            }
        } label: {
            HStack(spacing: DocketTheme.BoardLongPress.menuRowSpacing) {
                Image(systemName: action.symbol)
                    .font(DocketTheme.BoardLongPress.menuSymbolFont)
                    .frame(width: DocketTheme.BoardLongPress.menuSymbolWidth)

                Text(action.title)
                    .font(DocketTheme.BoardLongPress.menuFont)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if action.hasChildren {
                    Image(systemName: "chevron.right")
                        .font(DocketTheme.BoardLongPress.menuChevronFont)
                        .foregroundStyle(DocketTheme.ink.opacity(0.35))
                }
            }
            .foregroundStyle(tint(for: action))
            .padding(.horizontal, DocketTheme.BoardLongPress.menuRowHorizontalPadding)
            .frame(
                height: DocketTheme.BoardLongPress.menuRowHeight,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .accessibilityHint(action.hasChildren ? "Opens a list of boards" : "")
    }

    private func backRow(to submenu: BoardLongPressAction) -> some View {
        Button {
            openSubmenuID = nil
        } label: {
            HStack(spacing: DocketTheme.BoardLongPress.menuRowSpacing) {
                Image(systemName: "chevron.left")
                    .font(DocketTheme.BoardLongPress.menuChevronFont)
                    .frame(width: DocketTheme.BoardLongPress.menuSymbolWidth)

                Text(submenu.title)
                    .font(DocketTheme.BoardLongPress.menuFont)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .foregroundStyle(DocketTheme.ink.opacity(0.55))
            .padding(.horizontal, DocketTheme.BoardLongPress.menuRowHorizontalPadding)
            .frame(
                height: DocketTheme.BoardLongPress.menuRowHeight,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private func tint(for action: BoardLongPressAction) -> Color {
        guard action.isEnabled else { return DocketTheme.ink.opacity(0.3) }
        return action.isDestructive
            ? DocketTheme.BoardLongPress.menuDestructiveColor
            : DocketTheme.ink
    }
}

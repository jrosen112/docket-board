import SwiftUI
import CloudKit

struct JoinBoardView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.docketSurfacePalette) private var palette

    let invitation: BoardInvitation

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DocketTheme.boardBackground)
                .ignoresSafeArea()

            VStack(spacing: DocketTheme.JoinBoard.sectionSpacing) {
                hero
                boardCard
                actions
            }
            .frame(maxWidth: DocketTheme.JoinBoard.maxContentWidth)
            .padding(.horizontal, DocketTheme.JoinBoard.horizontalPadding)
            .padding(.top, DocketTheme.JoinBoard.topPadding)
            .padding(.bottom, DocketTheme.JoinBoard.bottomPadding)
        }
        .tint(DocketTheme.brass)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.isJoiningBoardInvitation)
    }

    private var hero: some View {
        VStack(spacing: DocketTheme.JoinBoard.heroSpacing) {
            ZStack {
                Circle()
                    .fill(DocketTheme.brass.opacity(0.16))
                Image(systemName: "person.2.fill")
                    .font(DocketTheme.JoinBoard.iconFont)
                    .foregroundStyle(DocketTheme.brass)
            }
            .frame(
                width: DocketTheme.JoinBoard.iconSize,
                height: DocketTheme.JoinBoard.iconSize
            )

            Text("Board Invitation")
                .font(DocketTheme.JoinBoard.titleFont)
                .foregroundStyle(DocketTheme.JoinBoard.titleColor)

            Text(invitationMessage)
                .font(DocketTheme.JoinBoard.bodyFont)
                .foregroundStyle(DocketTheme.JoinBoard.bodyColor)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var boardCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SHARED BOARD")
                .font(DocketTheme.JoinBoard.labelFont)
                .tracking(1.2)
                .foregroundStyle(DocketTheme.JoinBoard.cardLabelColor)

            Text(invitation.space.title)
                .font(DocketTheme.JoinBoard.boardNameFont)
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)

            Text("Items and updates will stay in sync through iCloud.")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DocketTheme.JoinBoard.cardPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.JoinBoard.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(DocketTheme.brass)
                .frame(
                    width: DocketTheme.JoinBoard.pinSize,
                    height: DocketTheme.JoinBoard.pinSize
                )
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .offset(y: DocketTheme.JoinBoard.pinOffsetY)
        }
        .shadow(color: palette.shadow, radius: 9, y: 5)
    }

    private var actions: some View {
        VStack(spacing: DocketTheme.JoinBoard.actionSpacing) {
            Button {
                Task { await store.joinPendingBoardInvitation() }
            } label: {
                HStack(spacing: 9) {
                    if store.isJoiningBoardInvitation {
                        ProgressView()
                    } else {
                        Image(systemName: "person.2.badge.plus")
                    }
                    Text(store.isJoiningBoardInvitation ? "Joining…" : "Join Board")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .docketPrimaryActionStyle()
            .disabled(store.isJoiningBoardInvitation)

            Button("Not Now") {
                store.dismissBoardInvitation()
            }
            .docketSecondaryActionStyle()
            .disabled(store.isJoiningBoardInvitation)
        }
    }

    private var invitationMessage: String {
        if let inviterName = invitation.inviterName {
            return "\(inviterName) invited you to join a board."
        }
        return "You’ve been invited to join a shared board."
    }
}

#Preview {
    JoinBoardView(
        invitation: BoardInvitation(
            space: Space(
                zoneID: .init(zoneName: "preview", ownerName: "friend"),
                access: .joined,
                title: "Weekend Plans"
            ),
            inviterName: "Alex"
        )
    )
    .environment(BoardStore())
}

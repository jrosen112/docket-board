import SwiftUI

enum BoardToolbarTransitionID: Hashable {
    case share
    case add
}

struct BoardBottomToolbar: ToolbarContent {
    let isOwner: Bool
    let transitionNamespace: Namespace.ID
    let onShare: () -> Void
    let onAdd: () -> Void

    var body: some ToolbarContent {
        if isOwner {
            ToolbarItem(placement: .bottomBar) {
                Button(action: onShare) {
                    Label("Share", systemImage: "person.crop.circle.badge.plus")
                }
            }
            .matchedTransitionSource(
                id: BoardToolbarTransitionID.share,
                in: transitionNamespace
            )
        }

        ToolbarSpacer(.flexible, placement: .bottomBar)

        ToolbarItem(placement: .bottomBar) {
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
            }
            .docketPrimaryActionStyle()
        }
        .matchedTransitionSource(
            id: BoardToolbarTransitionID.add,
            in: transitionNamespace
        )
    }
}

import SwiftUI

enum BoardToolbarTransitionID: Hashable {
    case share
    case settings
    case add
}

struct BoardBottomToolbar: ToolbarContent {
    let isAddEnabled: Bool
    let transitionNamespace: Namespace.ID
    let onSettings: () -> Void
    let onAdd: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(id: "docket.board.settings", placement: .bottomBar) {
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .matchedTransitionSource(
            id: BoardToolbarTransitionID.settings,
            in: transitionNamespace
        )

        ToolbarSpacer(.fixed, placement: .bottomBar)

        DefaultToolbarItem(kind: .search, placement: .bottomBar)

        ToolbarSpacer(.fixed, placement: .bottomBar)

        ToolbarItem(id: "docket.board.add", placement: .bottomBar) {
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
            }
            .docketPrimaryActionStyle()
            .disabled(!isAddEnabled)
        }
        .matchedTransitionSource(
            id: BoardToolbarTransitionID.add,
            in: transitionNamespace
        )
    }
}

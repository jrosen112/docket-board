import SwiftUI

enum BoardToolbarTransitionID: Hashable {
    case settings
    case add
}

struct BoardBottomToolbar: ToolbarContent {
    let isAddEnabled: Bool
    let transitionNamespace: Namespace.ID
    let onSettings: () -> Void
    let onAdd: (ItemCategory) -> Void

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
            Menu {
                Section("Add new item:") {
                    ForEach(ItemCategory.supported, id: \.self) { category in
                        Button {
                            onAdd(category)
                        } label: {
                            Label(category.label, systemImage: category.symbol)
                        }
                    }
                }
            } label: {
                Label("Add", systemImage: "plus")
                    .foregroundStyle(.white)
            } primaryAction: {
                onAdd(.restaurant)
            }
            .docketPrimaryMenuStyle()
            .disabled(!isAddEnabled)
            .accessibilityHint("Long-press to choose a category")
        }
        .matchedTransitionSource(
            id: BoardToolbarTransitionID.add,
            in: transitionNamespace
        )
    }
}

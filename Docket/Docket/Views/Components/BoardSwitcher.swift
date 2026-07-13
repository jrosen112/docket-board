import SwiftUI

struct BoardSwitcher: View {
    let currentSpace: Space
    let spaces: [Space]
    let onSelect: (Space) -> Void
    let onCreate: () -> Void

    var body: some View {
        Menu {
            ForEach(spaces) { space in
                Button {
                    onSelect(space)
                } label: {
                    Label(
                        space.title,
                        systemImage: space == currentSpace
                            ? "checkmark"
                            : (space.isOwned ? "person.crop.circle" : "person.2")
                    )
                }
            }
            Divider()
            Button(action: onCreate) {
                Label("New Board", systemImage: "plus")
            }
        } label: {
            HStack(spacing: DocketTheme.BoardSwitcher.labelSpacing) {
                Text(currentSpace.title)
                    .font(DocketTheme.BoardSwitcher.titleFont)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(DocketTheme.BoardSwitcher.chevronFont)
                    .foregroundStyle(DocketTheme.BoardSwitcher.chevronColor)
            }
            .foregroundStyle(DocketTheme.BoardSwitcher.titleColor)
            .contentShape(.rect)
        }
        .accessibilityLabel("Switch board. Current board: \(currentSpace.title)")
    }
}

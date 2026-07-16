import SwiftUI

struct BoardSwitcher: View {
    let currentSpace: Space
    let isEnabled: Bool
    let onOpenManager: () -> Void

    var body: some View {
        Button(action: onOpenManager) {
            HStack(spacing: DocketTheme.BoardSwitcher.labelSpacing) {
                Text(currentSpace.title)
                    .font(DocketTheme.BoardSwitcher.titleFont)
                    .lineLimit(1)
                Image(systemName: "rectangle.stack.fill")
                    .font(DocketTheme.BoardSwitcher.chevronFont)
                    .foregroundStyle(DocketTheme.BoardSwitcher.chevronColor)
            }
            .foregroundStyle(DocketTheme.BoardSwitcher.titleColor)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Manage boards. Current board: \(currentSpace.title)")
    }
}

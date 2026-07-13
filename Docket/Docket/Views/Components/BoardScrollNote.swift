import SwiftUI

struct BoardScrollNote: View {
    let progress: CGFloat
    let createdCount: Int
    let totalCount: Int

    var body: some View {
        Text("You've created \(createdCount) of the \(totalCount) board items.")
            .font(DocketTheme.BoardScrollNote.font)
            .italic()
            .foregroundStyle(DocketTheme.BoardScrollNote.color)
            .opacity(progress)
            .offset(y: DocketTheme.BoardScrollNote.hiddenOffset * (1 - progress))
            .padding(.bottom, DocketTheme.BoardScrollNote.bottomPadding)
            .allowsHitTesting(false)
            .accessibilityHidden(progress < 1)
    }
}

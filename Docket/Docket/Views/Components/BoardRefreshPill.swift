import SwiftUI

struct BoardRefreshPill: View {
    let summary: BoardRefreshSummary
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: DocketTheme.RefreshPill.contentSpacing) {
            Image(systemName: summary.addedItemCount == 0 ? "checkmark" : "plus")
                .font(DocketTheme.RefreshPill.iconFont)
                .foregroundStyle(DocketTheme.RefreshPill.iconColor)

            Text(summary.message)
                .font(DocketTheme.RefreshPill.messageFont)
                .foregroundStyle(DocketTheme.RefreshPill.messageColor)
                .lineLimit(1)
        }
        .padding(.horizontal, DocketTheme.RefreshPill.horizontalPadding)
        .padding(.vertical, DocketTheme.RefreshPill.verticalPadding)
        .glassEffect(
            .regular.tint(DocketTheme.RefreshPill.glassTint),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    DocketTheme.RefreshPill.borderColor,
                    lineWidth: DocketTheme.RefreshPill.borderWidth
                )
        )
        .shadow(
            color: DocketTheme.RefreshPill.shadowColor,
            radius: DocketTheme.RefreshPill.shadowRadius,
            y: DocketTheme.RefreshPill.shadowY
        )
        .offset(y: max(dragOffset, 0))
        .gesture(dismissGesture)
        .accessibilityHint("Swipe down to dismiss")
        .accessibilityAction(named: "Dismiss") { onDismiss() }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                let projectedDistance = max(
                    value.translation.height,
                    value.predictedEndTranslation.height
                )
                if projectedDistance >= DocketTheme.RefreshPill.swipeThreshold {
                    onDismiss()
                } else {
                    withAnimation(
                        .snappy(duration: DocketTheme.RefreshPill.dragReturnDuration)
                    ) {
                        dragOffset = 0
                    }
                }
            }
    }
}

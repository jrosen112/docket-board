import SwiftUI

struct BoardNoticePill: View {
    let message: String
    let systemImage: String
    var isProgress = false
    var isRetryable = false
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: DocketTheme.RefreshPill.contentSpacing) {
            Group {
                if isProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DocketTheme.RefreshPill.iconColor)
                } else {
                    Image(systemName: systemImage)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .font(DocketTheme.RefreshPill.iconFont)
            .foregroundStyle(DocketTheme.RefreshPill.iconColor)
            .frame(width: DocketTheme.RefreshPill.iconWidth)

            Text(message)
                .font(DocketTheme.RefreshPill.messageFont)
                .foregroundStyle(DocketTheme.RefreshPill.messageColor)
                .lineLimit(1)
                .contentTransition(.opacity)
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
        .contentShape(Capsule())
        .onTapGesture {
            if isRetryable { onRetry() }
        }
        .gesture(dismissGesture)
        .accessibilityHint(
            isRetryable
                ? "Double tap to retry, or swipe down to dismiss"
                : "Swipe down to dismiss"
        )
        .accessibilityAction(named: "Retry") {
            if isRetryable { onRetry() }
        }
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

import SwiftUI

/// Owns the two-stage physical removal: pull the pin, then let the paper fall.
/// The parent only toggles `isRemoving` and handles the completed deletion.
struct PhysicalCardRemovalView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isRemoving: Bool
    let direction: CGFloat
    var showsPin = true
    let onAnimationCompleted: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var phase = RemovalPhase.idle
    @State private var feedbackTrigger = 0

    var body: some View {
        ZStack(alignment: .top) {
            content()
                .offset(
                    x: phase == .falling
                        ? direction * DocketTheme.PhysicalDelete.horizontalDrift
                        : 0,
                    y: cardVerticalOffset
                )
                .rotationEffect(.degrees(cardRotation))
                .scaleEffect(phase == .falling ? DocketTheme.PhysicalDelete.fallScale : 1)
                .opacity(phase == .falling ? 0 : 1)

            if showsPin {
                BoardPinHead()
                    .scaleEffect(
                        phase == .idle
                            ? 1
                            : DocketTheme.PhysicalDelete.pinLiftScale
                    )
                    .offset(y: pinVerticalOffset)
                    .opacity(phase == .falling ? 0 : 1)
            }
        }
        .compositingGroup()
        .allowsHitTesting(!isRemoving)
        .accessibilityHidden(isRemoving)
        .sensoryFeedback(
            .impact(weight: .medium, intensity: 0.72),
            trigger: feedbackTrigger
        )
        .task(id: isRemoving) {
            await runRemovalIfNeeded()
        }
    }

    private var cardVerticalOffset: CGFloat {
        switch phase {
        case .idle:
            0
        case .unpinned:
            DocketTheme.PhysicalDelete.cardReleaseOffset
        case .falling:
            DocketTheme.PhysicalDelete.fallDistance
        }
    }

    private var cardRotation: Double {
        switch phase {
        case .idle:
            0
        case .unpinned:
            Double(direction) * -1.2
        case .falling:
            Double(direction) * DocketTheme.PhysicalDelete.fallRotation
        }
    }

    private var pinVerticalOffset: CGFloat {
        DocketTheme.BoardCard.pinOffsetY
            - (phase == .idle ? 0 : DocketTheme.PhysicalDelete.pinLiftDistance)
    }

    @MainActor
    private func runRemovalIfNeeded() async {
        guard isRemoving else {
            phase = .idle
            return
        }

        feedbackTrigger += 1

        if reduceMotion {
            withAnimation(.easeOut(duration: DocketTheme.PhysicalDelete.reducedMotionDuration)) {
                phase = .falling
            }
            try? await Task.sleep(for: DocketTheme.PhysicalDelete.reducedMotionDelay)
        } else {
            withAnimation(.easeOut(duration: DocketTheme.PhysicalDelete.pinLiftDuration)) {
                phase = .unpinned
            }
            try? await Task.sleep(for: DocketTheme.PhysicalDelete.pinLiftDelay)
            guard !Task.isCancelled else { return }

            withAnimation(
                .timingCurve(
                    0.32,
                    0,
                    0.72,
                    1,
                    duration: DocketTheme.PhysicalDelete.fallDuration
                )
            ) {
                phase = .falling
            }
            try? await Task.sleep(for: DocketTheme.PhysicalDelete.fallDelay)
        }

        guard !Task.isCancelled, isRemoving else { return }
        onAnimationCompleted()
    }
}

private enum RemovalPhase {
    case idle
    case unpinned
    case falling
}

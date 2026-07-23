import SwiftUI

/// Owns the inverse of physical removal: settle the paper, then drive its pin
/// into place. The parent stages the card before it enters the data source and
/// supplies a trigger once the save has completed.
struct PhysicalCardInsertionView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isStaged: Bool
    let animationTrigger: UUID?
    let direction: CGFloat
    let onAnimationCompleted: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var phase = InsertionPhase.staged
    @State private var feedbackTrigger = 0

    var body: some View {
        ZStack(alignment: .top) {
            content()
                .offset(y: cardVerticalOffset)
                .rotationEffect(.degrees(cardRotation))
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

            if isStaged {
                BoardPinHead()
                    .scaleEffect(pinScale)
                    .offset(y: pinVerticalOffset)
                    .opacity(pinOpacity)
            }
        }
        .compositingGroup()
        .allowsHitTesting(!isStaged)
        .accessibilityHidden(isStaged && visualPhase != .settled)
        .sensoryFeedback(
            .impact(weight: .medium, intensity: 0.78),
            trigger: feedbackTrigger
        )
        .task(id: animationTrigger) {
            await runInsertionIfNeeded()
        }
    }

    private var visualPhase: InsertionPhase {
        isStaged ? phase : .settled
    }

    private var cardVerticalOffset: CGFloat {
        switch visualPhase {
        case .staged:
            DocketTheme.PhysicalAdd.arrivalDistance
        case .settling, .settled:
            0
        case .pinning:
            DocketTheme.PhysicalAdd.pinImpactCardOffset
        }
    }

    private var cardRotation: Double {
        visualPhase == .staged
            ? Double(direction) * DocketTheme.PhysicalAdd.arrivalRotation
            : 0
    }

    private var cardScale: CGFloat {
        switch visualPhase {
        case .staged:
            DocketTheme.PhysicalAdd.arrivalScale
        case .pinning:
            DocketTheme.PhysicalAdd.pinImpactCardScale
        case .settling, .settled:
            1
        }
    }

    private var cardOpacity: Double {
        visualPhase == .staged ? 0 : 1
    }

    private var pinVerticalOffset: CGFloat {
        switch visualPhase {
        case .staged, .settling:
            DocketTheme.BoardCard.pinOffsetY - DocketTheme.PhysicalAdd.pinDropDistance
        case .pinning, .settled:
            DocketTheme.BoardCard.pinOffsetY
        }
    }

    private var pinScale: CGFloat {
        visualPhase == .pinning ? DocketTheme.PhysicalAdd.pinImpactScale : 1
    }

    private var pinOpacity: Double {
        switch visualPhase {
        case .staged, .settling:
            0
        case .pinning, .settled:
            1
        }
    }

    @MainActor
    private func runInsertionIfNeeded() async {
        guard isStaged, animationTrigger != nil else { return }
        phase = .staged

        if reduceMotion {
            withAnimation(.easeOut(duration: DocketTheme.PhysicalAdd.reducedMotionDuration)) {
                phase = .settled
            }
            try? await Task.sleep(for: DocketTheme.PhysicalAdd.reducedMotionDelay)
        } else {
            try? await Task.sleep(for: DocketTheme.PhysicalAdd.stagingDelay)
            guard !Task.isCancelled, isStaged else { return }

            withAnimation(DocketTheme.PhysicalAdd.arrivalAnimation) {
                phase = .settling
            }
            try? await Task.sleep(for: DocketTheme.PhysicalAdd.arrivalDelay)
            guard !Task.isCancelled, isStaged else { return }

            feedbackTrigger += 1
            withAnimation(.easeIn(duration: DocketTheme.PhysicalAdd.pinDropDuration)) {
                phase = .pinning
            }
            try? await Task.sleep(for: DocketTheme.PhysicalAdd.pinDropDelay)
            guard !Task.isCancelled, isStaged else { return }

            withAnimation(DocketTheme.PhysicalAdd.pinReboundAnimation) {
                phase = .settled
            }
            try? await Task.sleep(for: DocketTheme.PhysicalAdd.completionDelay)
        }

        guard !Task.isCancelled, isStaged else { return }
        onAnimationCompleted()
    }
}

private enum InsertionPhase {
    case staged
    case settling
    case pinning
    case settled
}

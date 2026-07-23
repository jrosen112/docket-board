import SwiftUI

extension View {
    /// Adds Docket's push-pin pull interaction to a scroll view.
    func docketPullToRefresh(
        isEnabled: Bool = true,
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(BoardPullToRefreshModifier(isEnabled: isEnabled, action: action))
    }
}

private struct BoardPullToRefreshModifier: ViewModifier {
    let isEnabled: Bool
    let action: @MainActor () async -> Void

    @State private var pullDistance: CGFloat = 0
    @State private var isArmed = false
    @State private var isRefreshing = false

    func body(content: Content) -> some View {
        content
            .scrollBounceBehavior(.always)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(
                        height: isRefreshing
                            ? DocketTheme.PullToRefresh.refreshHoldSpace : 0
                    )
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .top) {
                BoardPullToRefreshPin(
                    pullDistance: pullDistance,
                    isArmed: isArmed,
                    isRefreshing: isRefreshing
                )
                .zIndex(20)
            }
            .animation(DocketTheme.PullToRefresh.resetAnimation, value: isRefreshing)
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    let topOffset = geometry.contentOffset.y + geometry.contentInsets.top
                    return min(
                        max(-topOffset, 0),
                        DocketTheme.PullToRefresh.maximumTrackedDistance
                    )
                },
                action: updatePullDistance
            )
            .onScrollPhaseChange { oldPhase, newPhase in
                guard oldPhase == .interacting, newPhase != .interacting else { return }
                finishPull()
            }
            .accessibilityAction(named: "Refresh") {
                beginRefresh()
            }
            .onChange(of: isEnabled) { _, enabled in
                guard !enabled, !isRefreshing else { return }
                resetPull()
            }
    }

    private func updatePullDistance(from _: CGFloat, to newDistance: CGFloat) {
        guard isEnabled, !isRefreshing else { return }
        pullDistance = newDistance

        if isArmed {
            isArmed = newDistance >= DocketTheme.PullToRefresh.disarmDistance
        } else {
            isArmed = newDistance >= DocketTheme.PullToRefresh.threshold
        }
    }

    private func finishPull() {
        guard isEnabled, !isRefreshing else { return }
        if isArmed {
            beginRefresh()
        } else {
            resetPull()
        }
    }

    private func beginRefresh() {
        guard isEnabled, !isRefreshing else { return }
        withAnimation(DocketTheme.PullToRefresh.resetAnimation) {
            isRefreshing = true
            isArmed = false
            pullDistance = DocketTheme.PullToRefresh.threshold
        }

        Task { @MainActor in
            await action()
            withAnimation(DocketTheme.PullToRefresh.resetAnimation) {
                isRefreshing = false
                pullDistance = 0
            }
        }
    }

    private func resetPull() {
        withAnimation(DocketTheme.PullToRefresh.resetAnimation) {
            isArmed = false
            pullDistance = 0
        }
    }
}

private struct BoardPullToRefreshPin: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pullDistance: CGFloat
    let isArmed: Bool
    let isRefreshing: Bool

    var body: some View {
        Group {
            if isRefreshing, !reduceMotion {
                TimelineView(
                    .animation(
                        minimumInterval: DocketTheme.PullToRefresh.refreshFrameInterval
                    )
                ) { context in
                    indicator(activityRotation: refreshRotation(at: context.date))
                }
            } else {
                indicator(activityRotation: 0)
            }
        }
        .frame(height: DocketTheme.PullToRefresh.indicatorHeight, alignment: .top)
        .offset(y: indicatorOffset)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.selection, trigger: isArmed) { wasArmed, isArmed in
            !wasArmed && isArmed
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isRefreshing) {
            wasRefreshing,
            isRefreshing in
            !wasRefreshing && isRefreshing
        }
    }

    private var progress: CGFloat {
        min(max(pullDistance / DocketTheme.PullToRefresh.threshold, 0), 1)
    }

    private var isVisible: Bool {
        isRefreshing || pullDistance > 1
    }

    private var indicatorOffset: CGFloat {
        guard !isRefreshing else { return DocketTheme.PullToRefresh.revealedOffset }
        let travel =
            DocketTheme.PullToRefresh.revealedOffset
            - DocketTheme.PullToRefresh.hiddenOffset
        return DocketTheme.PullToRefresh.hiddenOffset + travel * easedProgress
    }

    private var easedProgress: CGFloat {
        1 - pow(1 - progress, 2)
    }

    private func indicator(activityRotation: Double) -> some View {
        ZStack {
            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(
                    DocketTheme.cream.opacity(isRefreshing ? 0.72 : 0),
                    style: StrokeStyle(
                        lineWidth: DocketTheme.PullToRefresh.activityLineWidth,
                        lineCap: .round
                    )
                )
                .frame(
                    width: DocketTheme.PullToRefresh.activityRingSize,
                    height: DocketTheme.PullToRefresh.activityRingSize
                )
                .rotationEffect(.degrees(activityRotation))

            DocketPinIcon(size: DocketTheme.PullToRefresh.pinSymbolSize)
                .rotationEffect(.degrees(pinRotation))
                .scaleEffect(pinScale)
        }
        .frame(
            width: DocketTheme.PullToRefresh.activityRingSize,
            height: DocketTheme.PullToRefresh.activityRingSize
        )
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        .animation(DocketTheme.PullToRefresh.armingAnimation, value: isArmed)
    }

    private var pinRotation: Double {
        guard !isRefreshing, !isArmed else { return 0 }
        return DocketTheme.PullToRefresh.restingRotation * Double(1 - easedProgress)
    }

    private var pinScale: CGFloat {
        guard !isRefreshing else { return 1 }
        let restingScale = DocketTheme.PullToRefresh.restingScale
        let pulledScale = restingScale + (1 - restingScale) * easedProgress
        return isArmed ? DocketTheme.PullToRefresh.armedScale : pulledScale
    }

    private func refreshRotation(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
            * DocketTheme.PullToRefresh.refreshDegreesPerSecond
    }
}

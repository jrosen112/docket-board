import SwiftUI

struct DiceRollOverlay: View {
    let winnerTitle: String
    let accent: Color
    let onComplete: () -> Void

    @State private var firstFace = 1
    @State private var secondFace = 6
    @State private var firstRotation = -8.0
    @State private var secondRotation = 9.0
    @State private var rollScale = 0.88
    @State private var tick = 0
    @State private var isRevealingWinner = false

    var body: some View {
        ZStack {
            Color.black.opacity(DocketTheme.DiceRoll.backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: DocketTheme.DiceRoll.contentSpacing) {
                Text(isRevealingWinner ? "TONIGHT'S PICK" : "ROLLING…")
                    .font(DocketTheme.DiceRoll.eyebrowFont)
                    .tracking(DocketTheme.DiceRoll.eyebrowTracking)
                    .foregroundStyle(accent)

                HStack(spacing: DocketTheme.DiceRoll.diceSpacing) {
                    die(face: firstFace, rotation: firstRotation)
                    die(face: secondFace, rotation: secondRotation)
                }
                .scaleEffect(rollScale)

                Text(isRevealingWinner ? winnerTitle : "Pick for us")
                    .font(DocketTheme.DiceRoll.titleFont)
                    .foregroundStyle(DocketTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(minHeight: DocketTheme.DiceRoll.titleMinimumHeight)
            }
            .padding(DocketTheme.DiceRoll.cardPadding)
            .frame(maxWidth: DocketTheme.DiceRoll.cardMaximumWidth)
            .background(
                RoundedRectangle(
                    cornerRadius: DocketTheme.DiceRoll.cardCornerRadius,
                    style: .continuous
                )
                .fill(DocketTheme.cream)
                .shadow(
                    color: .black.opacity(DocketTheme.DiceRoll.shadowOpacity),
                    radius: DocketTheme.DiceRoll.shadowRadius,
                    y: DocketTheme.DiceRoll.shadowY
                )
            )
            .overlay(alignment: .top) {
                Circle()
                    .fill(DocketTheme.brass)
                    .frame(
                        width: DocketTheme.DiceRoll.pinSize,
                        height: DocketTheme.DiceRoll.pinSize
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(y: DocketTheme.DiceRoll.pinOffset)
            }
            .padding(.horizontal, DocketTheme.DiceRoll.horizontalPadding)
        }
        .allowsHitTesting(true)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: tick)
        .sensoryFeedback(.success, trigger: isRevealingWinner)
        .task { await animateRoll() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isRevealingWinner ? "Tonight's pick is \(winnerTitle)" : "Picking a random item"
        )
    }

    private func die(face: Int, rotation: Double) -> some View {
        Image(systemName: "die.face.\(face).fill")
            .font(DocketTheme.DiceRoll.dieFont)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, accent)
            .rotationEffect(.degrees(rotation))
            .shadow(
                color: accent.opacity(DocketTheme.DiceRoll.dieShadowOpacity),
                radius: DocketTheme.DiceRoll.dieShadowRadius,
                y: DocketTheme.DiceRoll.dieShadowY
            )
    }

    @MainActor
    private func animateRoll() async {
        for step in 0..<DocketTheme.DiceRoll.rollSteps {
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: DocketTheme.DiceRoll.stepAnimationDuration)) {
                firstFace = Int.random(in: 1...6)
                secondFace = Int.random(in: 1...6)
                firstRotation += step.isMultiple(of: 2) ? 38 : -29
                secondRotation += step.isMultiple(of: 2) ? -34 : 31
                rollScale = step.isMultiple(of: 2) ? 1.04 : 0.92
                tick += 1
            }
            try? await Task.sleep(for: DocketTheme.DiceRoll.stepDuration)
        }

        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
            firstFace = Int.random(in: 1...6)
            secondFace = Int.random(in: 1...6)
            firstRotation = -6
            secondRotation = 7
            rollScale = 1
            isRevealingWinner = true
        }

        try? await Task.sleep(for: DocketTheme.DiceRoll.winnerDuration)
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

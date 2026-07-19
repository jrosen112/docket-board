import SwiftUI

/// Translucent tape strips "holding" a card by its top edge. Apply as a
/// top-aligned overlay. Each board gets a stable color and arrangement —
/// one or two strips, sometimes across a corner — derived from its key.
struct WashiTape: View {
    let boardKey: String

    var body: some View {
        GeometryReader { proxy in
            let color = DocketTheme.WashiTape.color(for: boardKey)
            let strips = DocketTheme.WashiTape.arrangement(for: boardKey)

            ForEach(Array(strips.enumerated()), id: \.offset) { _, strip in
                RoundedRectangle(
                    cornerRadius: DocketTheme.WashiTape.cornerRadius,
                    style: .continuous
                )
                .fill(color.opacity(DocketTheme.WashiTape.opacity))
                .frame(
                    width: DocketTheme.WashiTape.width,
                    height: DocketTheme.WashiTape.height
                )
                .rotationEffect(.degrees(strip.rotationDegrees))
                .position(
                    x: proxy.size.width * strip.xFraction + strip.xNudge,
                    y: strip.yCenter
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        DocketTheme.ink.ignoresSafeArea()
        VStack(spacing: 28) {
            ForEach(["alpha", "bravo", "charlie", "delta", "echo"], id: \.self) { key in
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(DocketTheme.cream)
                    .frame(width: 320, height: 80)
                    .overlay { WashiTape(boardKey: key) }
            }
        }
    }
}

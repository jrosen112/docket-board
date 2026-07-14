import SwiftUI

struct DetailSectionCard<Content: View>: View {
    @Environment(\.docketSurfacePalette) private var palette

    let title: String
    let symbol: String
    let accent: Color
    let rotationDegrees: Double
    @ViewBuilder let content: Content

    init(
        title: String,
        symbol: String,
        accent: Color,
        rotationDegrees: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.accent = accent
        self.rotationDegrees = rotationDegrees
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.Card.contentSpacing) {
            Label(title, systemImage: symbol)
                .font(DocketDetailTheme.Card.titleFont)
                .foregroundStyle(palette.primaryText)
                .symbolRenderingMode(.monochrome)

            Divider()
                .overlay(accent.opacity(DocketDetailTheme.Card.dividerOpacity))

            content
        }
        .padding(DocketDetailTheme.Card.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DocketDetailTheme.Card.cornerRadius)
                .fill(palette.paper)
                .shadow(
                    color: palette.shadow,
                    radius: DocketDetailTheme.Card.shadowRadius,
                    x: DocketDetailTheme.Card.shadowX,
                    y: DocketDetailTheme.Card.shadowY
                )
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accent)
                .frame(width: DocketDetailTheme.Card.stripeWidth)
                .padding(.vertical, DocketDetailTheme.Card.stripeVerticalPadding)
                .padding(.leading, DocketDetailTheme.Card.stripeLeadingPadding)
        }
        .rotationEffect(.degrees(rotationDegrees))
    }
}

import SwiftUI

struct DetailSectionCard<Content: View>: View {
    let title: String
    let symbol: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DocketDetailTheme.Card.contentSpacing) {
            Label(title, systemImage: symbol)
                .font(DocketDetailTheme.Card.titleFont)
                .foregroundStyle(DocketDetailTheme.Card.titleColor)
                .symbolRenderingMode(.monochrome)

            Divider()
                .overlay(accent.opacity(DocketDetailTheme.Card.dividerOpacity))

            content
        }
        .padding(DocketDetailTheme.Card.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DocketDetailTheme.Card.cornerRadius)
                .fill(DocketDetailTheme.Card.paper)
                .shadow(
                    color: DocketDetailTheme.Card.shadowColor,
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
    }
}

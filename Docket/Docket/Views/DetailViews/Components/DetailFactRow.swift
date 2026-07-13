import SwiftUI

struct DetailFactRow: View {
    let symbol: String
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: symbol)
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)

            Text(label)
                .font(DocketDetailTheme.Fact.labelFont)
                .foregroundStyle(DocketDetailTheme.Fact.labelColor)

            Spacer(minLength: DocketDetailTheme.Fact.valueMinimumSpacing)

            Text(value)
                .font(DocketDetailTheme.Fact.valueFont)
                .foregroundStyle(DocketDetailTheme.Fact.valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DocketDetailTheme.Fact.verticalPadding)
    }
}

import SwiftUI

struct DetailEditPickerRow<Selection: Hashable, Options: View>: View {
    @Environment(\.docketSurfacePalette) private var palette

    let symbol: String
    let label: String
    let accent: Color
    @Binding var selection: Selection
    @ViewBuilder let options: Options

    var body: some View {
        HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: symbol)
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)

            Text(label)
                .font(DocketDetailTheme.Fact.labelFont)
                .foregroundStyle(palette.secondaryText)

            Spacer(minLength: DocketDetailTheme.Fact.valueMinimumSpacing)

            Picker(label, selection: $selection) {
                options
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(accent)
        }
        .padding(.vertical, DocketDetailTheme.Edit.fieldVerticalPadding)
    }
}

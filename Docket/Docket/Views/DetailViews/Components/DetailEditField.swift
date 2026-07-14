import SwiftUI
import UIKit

struct DetailEditField: View {
    @Environment(\.docketSurfacePalette) private var palette

    let symbol: String
    let label: String
    let placeholder: String
    let field: ItemDraftField
    let accent: Color
    @Binding var text: String
    let focusedField: FocusState<ItemDraftField?>.Binding
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
            Image(systemName: symbol)
                .font(DocketDetailTheme.Fact.symbolFont)
                .foregroundStyle(accent)
                .frame(width: DocketDetailTheme.Fact.symbolWidth)

            VStack(alignment: .leading, spacing: DocketDetailTheme.Edit.fieldSpacing) {
                Text(label)
                    .font(DocketDetailTheme.Edit.labelFont)
                    .foregroundStyle(palette.mutedText)

                TextField(placeholder, text: $text)
                    .font(DocketDetailTheme.Edit.inputFont)
                    .foregroundStyle(palette.primaryText)
                    .textFieldStyle(.plain)
                    .keyboardType(keyboardType)
                    .focused(focusedField, equals: field)
            }
        }
        .padding(.vertical, DocketDetailTheme.Edit.fieldVerticalPadding)
    }
}

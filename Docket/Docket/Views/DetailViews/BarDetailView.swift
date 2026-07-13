import SwiftUI

struct BarDetailView: View {
    let bar: Bar
    let addedBy: String
    let isEditing: Bool
    let saveErrorMessage: String?
    @Binding var draft: ItemDraft
    let focusedField: FocusState<ItemDraftField?>.Binding
    let onEdit: (ItemDraftField) -> Void

    var body: some View {
        DetailPage(
            item: bar,
            addedBy: addedBy,
            symbol: "wineglass.fill",
            isEditing: isEditing,
            saveErrorMessage: saveErrorMessage,
            draft: $draft,
            focusedField: focusedField,
            onEdit: onEdit
        ) {
            if isEditing {
                DetailEditField(
                    symbol: "mappin.and.ellipse",
                    label: "Location",
                    placeholder: "Add a location",
                    field: .location,
                    accent: bar.category.accent,
                    text: $draft.location,
                    focusedField: focusedField
                )
                DetailEditPickerRow(
                    symbol: "sparkles",
                    label: "Vibe",
                    accent: bar.category.accent,
                    selection: $draft.barType
                ) {
                    Text("Not set").tag(BarType?.none)
                    ForEach(BarType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(Optional(type))
                    }
                }
            } else {
                DetailFactRow(
                    symbol: "mappin.and.ellipse",
                    label: "Location",
                    value: bar.location ?? "Add location",
                    accent: bar.category.accent,
                    isPlaceholder: bar.location == nil,
                    onTap: { onEdit(.location) }
                )
                DetailFactRow(
                    symbol: "sparkles",
                    label: "Vibe",
                    value: bar.barType?.rawValue.capitalized ?? "Set vibe",
                    accent: bar.category.accent,
                    isPlaceholder: bar.barType == nil,
                    onTap: { onEdit(.barType) }
                )
            }
        }
    }
}

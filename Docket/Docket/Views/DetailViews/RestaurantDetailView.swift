import SwiftUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    let addedBy: String
    let isEditing: Bool
    let allowsCategorySelection: Bool
    let saveErrorMessage: String?
    @Binding var draft: ItemDraft
    let focusedField: FocusState<ItemDraftField?>.Binding
    let onEdit: (ItemDraftField) -> Void

    var body: some View {
        DetailPage(
            item: restaurant,
            addedBy: addedBy,
            symbol: "fork.knife",
            isEditing: isEditing,
            allowsCategorySelection: allowsCategorySelection,
            saveErrorMessage: saveErrorMessage,
            draft: $draft,
            focusedField: focusedField,
            onEdit: onEdit
        ) {
            if isEditing {
                editingFields
            } else {
                displayFields
            }
        }
    }

    private var editingFields: some View {
        Group {
            LocationEditRow(
                suggestedQuery: draft.title,
                accent: restaurant.category.accent,
                location: $draft.location,
                showsMapOnBoard: $draft.showsMapOnBoard,
                showsPhotoOnBoard: $draft.showsPhotoOnBoard
            )
            DetailEditField(
                symbol: "takeoutbag.and.cup.and.straw.fill",
                label: "Cuisine",
                placeholder: "Add a cuisine",
                field: .cuisine,
                accent: restaurant.category.accent,
                text: $draft.cuisine,
                focusedField: focusedField
            )
            DetailEditPickerRow(
                symbol: "creditcard.fill",
                label: "Price",
                accent: restaurant.category.accent,
                selection: $draft.priceRange
            ) {
                Text("Not set").tag(PriceRange?.none)
                ForEach(PriceRange.allCases, id: \.self) { price in
                    Text(price.rawValue).tag(Optional(price))
                }
            }
        }
    }

    private var displayFields: some View {
        Group {
            fact(
                symbol: "mappin.and.ellipse",
                label: "Location",
                value: restaurant.location?.detailAddress,
                placeholder: "Add location",
                field: .location
            )
            fact(
                symbol: "takeoutbag.and.cup.and.straw.fill",
                label: "Cuisine",
                value: restaurant.cuisine,
                placeholder: "Add cuisine",
                field: .cuisine
            )
            fact(
                symbol: "creditcard.fill",
                label: "Price",
                value: restaurant.priceRange?.rawValue,
                placeholder: "Set price",
                field: .priceRange
            )
        }
    }

    private func fact(
        symbol: String,
        label: String,
        value: String?,
        placeholder: String,
        field: ItemDraftField
    ) -> some View {
        DetailFactRow(
            symbol: symbol,
            label: label,
            value: value ?? placeholder,
            accent: restaurant.category.accent,
            isPlaceholder: value == nil,
            onTap: { onEdit(field) }
        )
    }
}

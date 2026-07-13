//
//  BoardFilterBar.swift
//  Docket
//
//  Category + status filter chips for the board. Owns no state — takes a
//  BoardFilter binding and mutates it on taps.
//

import SwiftUI

struct BoardFilterBar: View {
    @Binding var filter: BoardFilter
    let categories: [ItemCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isSelected: filter.category == nil) {
                        filter.category = nil
                    }
                    ForEach(categories, id: \.self) { category in
                        FilterChip(
                            label: category.label,
                            isSelected: filter.category == category,
                            accent: category.accent
                        ) {
                            filter.category = filter.category == category ? nil : category
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                FilterChip(label: "Any status", isSelected: filter.status == nil) {
                    filter.status = nil
                }
                ForEach(ItemStatus.allCases, id: \.self) { status in
                    FilterChip(
                        label: status.label,
                        isSelected: filter.status == status
                    ) {
                        filter.status = filter.status == status ? nil : status
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var filter = BoardFilter()
    BoardFilterBar(filter: $filter, categories: ItemCategory.supported)
        .padding()
        .background(DocketTheme.ink)
}

import SwiftUI

struct BoardFilterHeader: View {
    @Binding var filter: BoardFilter
    let categories: [ItemCategory]

    var body: some View {
        BoardFilterBar(filter: $filter, categories: categories)
            .padding(DocketTheme.BoardFilterHeader.contentPadding)
            .glassEffect(
                .regular.tint(DocketTheme.BoardFilterHeader.glassTint),
                in: RoundedRectangle(
                    cornerRadius: DocketTheme.BoardFilterHeader.cornerRadius
                )
            )
            .shadow(
                color: DocketTheme.BoardFilterHeader.shadowColor,
                radius: DocketTheme.BoardFilterHeader.shadowRadius,
                y: DocketTheme.BoardFilterHeader.shadowY
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DocketTheme.BoardFilterHeader.cornerRadius
                )
                .stroke(
                    DocketTheme.BoardFilterHeader.borderColor,
                    lineWidth: DocketTheme.BoardFilterHeader.borderWidth
                )
            )
            .padding(.vertical, DocketTheme.BoardFilterHeader.verticalMargin)
    }
}

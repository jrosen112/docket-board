import SwiftUI

struct BoardFilterHeader: View {
    @Binding var filter: BoardFilter
    let categories: [ItemCategory]
    let cuisines: [String]
    @State private var showingFilterSheet = false
    @State private var draftFilter = BoardFilter()
    @State private var appliesDraftOnDismiss = false

    var body: some View {
        BoardFilterBar(
            filter: filter,
            onShowFilters: presentFilters,
            onClear: clearFilters
        )
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
        .sheet(
            isPresented: $showingFilterSheet,
            onDismiss: applyDismissedDraftIfNeeded
        ) {
            BoardFilterSheet(
                filter: $draftFilter,
                categories: categories,
                cuisines: cuisines,
                onCancel: cancelFilters,
                onApply: applyFilters
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func presentFilters() {
        draftFilter = filter
        appliesDraftOnDismiss = true
        showingFilterSheet = true
    }

    private func applyFilters() {
        appliesDraftOnDismiss = true
        showingFilterSheet = false
    }

    private func cancelFilters() {
        appliesDraftOnDismiss = false
        showingFilterSheet = false
    }

    private func applyDismissedDraftIfNeeded() {
        guard appliesDraftOnDismiss else { return }
        withAnimation(DocketTheme.BoardItems.changeAnimation) {
            filter = draftFilter
        }
        appliesDraftOnDismiss = false
    }

    private func clearFilters() {
        withAnimation(DocketTheme.BoardItems.changeAnimation) {
            filter.clear()
        }
    }
}

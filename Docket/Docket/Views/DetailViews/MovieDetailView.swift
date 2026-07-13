import SwiftUI

struct MovieDetailView: View {
    let movie: Movie
    let addedBy: String
    let isEditing: Bool
    let saveErrorMessage: String?
    @Binding var draft: ItemDraft
    let focusedField: FocusState<ItemDraftField?>.Binding
    let onEdit: (ItemDraftField) -> Void

    var body: some View {
        DetailPage(
            item: movie,
            addedBy: addedBy,
            symbol: "film.fill",
            isEditing: isEditing,
            saveErrorMessage: saveErrorMessage,
            draft: $draft,
            focusedField: focusedField,
            onEdit: onEdit
        ) {
            if isEditing {
                DetailEditField(
                    symbol: "calendar",
                    label: "Released",
                    placeholder: "Add a year",
                    field: .releaseYear,
                    accent: movie.category.accent,
                    text: $draft.releaseYear,
                    focusedField: focusedField,
                    keyboardType: .numberPad
                )
                DetailEditField(
                    symbol: "clock.fill",
                    label: "Runtime",
                    placeholder: "Add minutes",
                    field: .runtime,
                    accent: movie.category.accent,
                    text: $draft.runtime,
                    focusedField: focusedField,
                    keyboardType: .numberPad
                )
                DetailEditField(
                    symbol: "play.tv.fill",
                    label: "Watch on",
                    placeholder: "Add a service",
                    field: .streamingService,
                    accent: movie.category.accent,
                    text: $draft.streamingService,
                    focusedField: focusedField
                )
            } else {
                DetailFactRow(
                    symbol: "calendar",
                    label: "Released",
                    value: movie.releaseYear.map(String.init) ?? "Add year",
                    accent: movie.category.accent,
                    isPlaceholder: movie.releaseYear == nil,
                    onTap: { onEdit(.releaseYear) }
                )
                DetailFactRow(
                    symbol: "clock.fill",
                    label: "Runtime",
                    value: movie.runtimeMinutes.map { "\($0) min" } ?? "Add runtime",
                    accent: movie.category.accent,
                    isPlaceholder: movie.runtimeMinutes == nil,
                    onTap: { onEdit(.runtime) }
                )
                DetailFactRow(
                    symbol: "play.tv.fill",
                    label: "Watch on",
                    value: movie.streamingService ?? "Add service",
                    accent: movie.category.accent,
                    isPlaceholder: movie.streamingService == nil,
                    onTap: { onEdit(.streamingService) }
                )
            }
        }
    }
}

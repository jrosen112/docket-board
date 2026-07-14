import CloudKit
import SwiftUI

struct NewItemView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let itemID: CKRecord.ID
    let dateAdded: Date
    let onSaved: () -> Void

    @State private var draft = ItemDraft()
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: ItemDraftField?

    private var previewItem: (any SharedListItem)? {
        guard let profile = store.currentProfile else { return nil }
        return draft.makeNew(
            id: itemID,
            addedBy: profile.reference,
            dateAdded: dateAdded
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let item = previewItem, let profile = store.currentProfile {
                    editor(for: item, addedBy: profile.displayName)
                } else {
                    ContentUnavailableView(
                        "Profile unavailable",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                DetailBottomToolbar(
                    isVisible: true,
                    isEditing: true,
                    hasKeyboardFocus: focusedField != nil,
                    isSaving: isSaving,
                    canSave: draft.isValid,
                    onEdit: {},
                    onCancel: { dismiss() },
                    onSave: { Task { await save() } }
                )
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            try? await Task.sleep(for: DocketDetailTheme.Edit.focusDelay)
            guard !Task.isCancelled else { return }
            focusedField = .title
        }
    }

    @ViewBuilder
    private func editor(for item: any SharedListItem, addedBy: String) -> some View {
        switch item {
        case let restaurant as Restaurant:
            RestaurantDetailView(
                restaurant: restaurant,
                addedBy: addedBy,
                isEditing: true,
                allowsCategorySelection: true,
                saveErrorMessage: saveErrorMessage,
                draft: $draft,
                focusedField: $focusedField,
                onEdit: { _ in }
            )
        case let bar as Bar:
            BarDetailView(
                bar: bar,
                addedBy: addedBy,
                isEditing: true,
                allowsCategorySelection: true,
                saveErrorMessage: saveErrorMessage,
                draft: $draft,
                focusedField: $focusedField,
                onEdit: { _ in }
            )
        case let movie as Movie:
            MovieDetailView(
                movie: movie,
                addedBy: addedBy,
                isEditing: true,
                allowsCategorySelection: true,
                saveErrorMessage: saveErrorMessage,
                draft: $draft,
                focusedField: $focusedField,
                onEdit: { _ in }
            )
        default:
            ContentUnavailableView("Unsupported category", systemImage: "questionmark")
        }
    }

    private func save() async {
        guard !isSaving else { return }
        guard let profile = store.currentProfile,
              let item = draft.makeNew(
                id: itemID,
                addedBy: profile.reference,
                dateAdded: dateAdded
              )
        else { return }

        focusedField = nil
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        switch await store.save(item) {
        case .saved:
            onSaved()
            dismiss()
        case .conflict(let message), .failed(let message):
            saveErrorMessage = message
        }
    }
}

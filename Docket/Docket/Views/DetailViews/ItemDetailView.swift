import CloudKit
import SwiftUI

struct ItemDetailView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: ItemDraftField?

    let itemID: CKRecord.ID
    let onSave: (any SharedListItem) -> Void
    var startsEditing = false
    @State private var isEditing = false
    @State private var draft = ItemDraft()
    @State private var editBase: DetailEditBase?
    @State private var isToolbarVisible = true
    @State private var appliedInitialEditMode = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?

    private var item: (any SharedListItem)? {
        store.items.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item {
                content(for: item)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarVisibility(.visible, for: .navigationBar)
                    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .navigationBarBackButtonHidden(isEditing || isDeleting)
                    .toolbar {
                        DetailBottomToolbar(
                            isVisible: isToolbarVisible,
                            isEditing: isEditing,
                            hasKeyboardFocus: focusedField != nil,
                            canSave: draft.isValid,
                            isDeleting: isDeleting,
                            onEdit: { beginEditing(item, field: .title) },
                            onDelete: { isShowingDeleteConfirmation = true },
                            onCancel: cancelEditing,
                            onSave: submitSave
                        )
                    }
                    .alert(
                        "Delete “\(item.title)”?",
                        isPresented: $isShowingDeleteConfirmation
                    ) {
                        Button("Delete", role: .destructive) {
                            submitDelete(item)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes the item from the shared board for everyone. This can't be undone.")
                    }
                    .alert(
                        "Couldn't Delete Item",
                        isPresented: Binding(
                            get: { deleteErrorMessage != nil },
                            set: { if !$0 { deleteErrorMessage = nil } }
                        )
                    ) {
                        Button("OK", role: .cancel) {
                            deleteErrorMessage = nil
                        }
                    } message: {
                        Text(deleteErrorMessage ?? "Please try again.")
                    }
                    .onAppear {
                        isToolbarVisible = true
                        guard startsEditing, !appliedInitialEditMode else { return }
                        appliedInitialEditMode = true
                        beginEditing(item, field: .title)
                    }
                    .onDisappear {
                        focusedField = nil
                        isToolbarVisible = false
                    }
            } else {
                ContentUnavailableView(
                    "Item unavailable",
                    systemImage: "pin.slash",
                    description: Text("It may have been deleted from the shared board.")
                )
            }
        }
    }

    @ViewBuilder
    private func content(for item: any SharedListItem) -> some View {
        detail(for: item)
            .animation(DocketDetailTheme.Edit.modeAnimation, value: isEditing)
    }

    @ViewBuilder
    private func detail(for item: any SharedListItem) -> some View {
        let addedBy = store.displayName(for: item)
        let edit: (ItemDraftField) -> Void = { field in beginEditing(item, field: field) }
        switch item {
        case let restaurant as Restaurant:
            RestaurantDetailView(
                restaurant: restaurant,
                addedBy: addedBy,
                isEditing: isEditing,
                allowsCategorySelection: false,
                saveErrorMessage: nil,
                draft: $draft,
                focusedField: $focusedField,
                onEdit: edit
            )
        case let bar as Bar:
            BarDetailView(
                bar: bar,
                addedBy: addedBy,
                isEditing: isEditing,
                allowsCategorySelection: false,
                saveErrorMessage: nil,
                draft: $draft,
                focusedField: $focusedField,
                onEdit: edit
            )
        case let movie as Movie:
            MovieDetailView(
                movie: movie,
                addedBy: addedBy,
                isEditing: isEditing,
                allowsCategorySelection: false,
                saveErrorMessage: nil,
                draft: $draft,
                focusedField: $focusedField,
                onEdit: edit
            )
        default:
            ContentUnavailableView("Unsupported item", systemImage: "questionmark")
        }
    }

    private func beginEditing(_ item: any SharedListItem, field: ItemDraftField) {
        editBase = DetailEditBase(item: item)
        draft = ItemDraft(item: item)
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            isEditing = true
        }
        focus(field)
    }

    private func cancelEditing() {
        editBase = nil
        focusedField = nil
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            isEditing = false
        }
    }

    private func submitSave() {
        // Always apply to the record fetched when editing began. Its CloudKit
        // change tag is what lets the server detect a participant's newer edit.
        guard let base = editBase?.item,
              let edited = draft.applying(to: base)
        else { return }
        focusedField = nil
        onSave(edited)
        dismiss()
    }

    private func submitDelete(_ item: any SharedListItem) {
        guard !isDeleting else { return }
        focusedField = nil
        isDeleting = true

        Task { @MainActor in
            switch await store.delete(item) {
            case .deleted:
                dismiss()
            case let .failed(message):
                store.errorMessage = nil
                isDeleting = false
                deleteErrorMessage = message
            }
        }
    }

    private func focus(_ field: ItemDraftField) {
        Task { @MainActor in
            try? await Task.sleep(for: DocketDetailTheme.Edit.focusDelay)
            guard isEditing else { return }
            switch field {
            case .title, .cuisine, .runtime, .streamingService, .releaseYear, .notes:
                focusedField = field
            case .status, .location, .priceRange, .barType, .photo,
                    .showsPhotoOnBoard, .showsMapOnBoard:
                focusedField = nil
            }
        }
    }
}

private struct DetailEditBase {
    let item: any SharedListItem
}

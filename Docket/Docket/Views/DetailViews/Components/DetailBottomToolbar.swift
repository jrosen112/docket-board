import SwiftUI

struct DetailBottomToolbar: ToolbarContent {
    let isVisible: Bool
    let isEditing: Bool
    let hasKeyboardFocus: Bool
    let canSave: Bool
    let isDeleting: Bool
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some ToolbarContent {
        if isVisible {
            if isEditing {
                if hasKeyboardFocus {
                    ToolbarItemGroup(placement: .keyboard) {
                        cancelButton
                            .padding(.bottom, DocketTheme.DetailToolbar.keyboardBottomPadding)
                        Spacer()
                        saveButton
                            .padding(.bottom, DocketTheme.DetailToolbar.keyboardBottomPadding)
                    }
                } else {
                    ToolbarItem(id: "docket.detail.cancel", placement: .bottomBar) {
                        cancelButton
                    }

                    ToolbarSpacer(.flexible, placement: .bottomBar)

                    ToolbarItem(id: "docket.detail.save", placement: .bottomBar) {
                        saveButton
                    }
                }
            } else {
                if let onDelete {
                    ToolbarItem(id: "docket.detail.delete", placement: .bottomBar) {
                        Button(role: .destructive, action: onDelete) {
                            if isDeleting {
                                ProgressView()
                                    .accessibilityLabel("Deleting")
                            } else {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .disabled(isDeleting)
                    }
                }

                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(id: "docket.detail.edit", placement: .bottomBar) {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .docketPrimaryActionStyle()
                    .disabled(isDeleting)
                }
            }
        }
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
    }

    private var saveButton: some View {
        Button(action: onSave) {
            Label("Save", systemImage: "checkmark")
        }
        .docketPrimaryActionStyle()
        .disabled(!canSave)
        .accessibilityLabel("Save")
    }
}

import SwiftUI

struct DetailBottomToolbar: ToolbarContent {
    let isEditing: Bool
    let hasKeyboardFocus: Bool
    let isSaving: Bool
    let canSave: Bool
    let onEdit: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some ToolbarContent {
        if isEditing {
            if hasKeyboardFocus {
                ToolbarItemGroup(placement: .keyboard) {
                    cancelButton
                    Spacer()
                    saveButton
                }
            } else {
                ToolbarItem(placement: .bottomBar) {
                    cancelButton
                }

                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    saveButton
                }
            }
        } else {
            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .docketPrimaryActionStyle()
            }
        }
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .docketSecondaryActionStyle()
            .disabled(isSaving)
    }

    private var saveButton: some View {
        Button(action: onSave) {
            Label("Save", systemImage: "checkmark")
        }
        .docketPrimaryActionStyle()
        .disabled(!canSave || isSaving)
    }
}

//
//  ItemFormView.swift
//  Docket
//
//  Add + edit form. Adding: category picker → category-specific fields → new
//  item. Editing: same fields pre-filled, category fixed (an item's category is
//  its CKRecord type, which can't change), and the save path mutates the
//  existing item so its record identity + change tag are preserved.
//

import SwiftUI

struct ItemFormView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// nil → adding a new item.
    private let editingItem: (any SharedListItem)?

    @State private var draft: ItemDraft

    @State private var isSaving = false
    @State private var showingConflict = false
    @State private var saveErrorMessage: String?

    init(editing item: (any SharedListItem)? = nil) {
        self.editingItem = item
        _draft = State(initialValue: item.map { ItemDraft(item: $0) } ?? ItemDraft())
    }

    private var isEditing: Bool { editingItem != nil }

    private var canSave: Bool {
        draft.isValid && !isSaving && (isEditing || store.currentProfile != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section {
                        Picker("Category", selection: $draft.category) {
                            ForEach(ItemCategory.supported, id: \.self) { category in
                                Text(category.label).tag(category)
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Title", text: $draft.title)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                    Picker("Status", selection: $draft.status) {
                        ForEach(ItemStatus.allCases, id: \.self) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }

                categorySection

                if let saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit \(draft.category.label)" : "Add to the Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .alert("This item changed", isPresented: $showingConflict) {
                Button("Keep Editing", role: .cancel) {}
                Button("Reload Their Version") {
                    dismiss()
                    Task { await store.refresh() }
                }
            } message: {
                Text("Someone else saved a newer version. Reload the board before editing it again.")
            }
        }
    }

    @ViewBuilder private var categorySection: some View {
        switch draft.category {
        case .restaurant:
            Section("Restaurant") {
                TextField("Location", text: $draft.location)
                TextField("Cuisine", text: $draft.cuisine)
                Picker("Price", selection: $draft.priceRange) {
                    Text("—").tag(PriceRange?.none)
                    ForEach(PriceRange.allCases, id: \.self) { price in
                        Text(price.rawValue).tag(Optional(price))
                    }
                }
            }
        case .bar:
            Section("Bar") {
                TextField("Location", text: $draft.location)
                Picker("Type", selection: $draft.barType) {
                    Text("—").tag(BarType?.none)
                    ForEach(BarType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(Optional(type))
                    }
                }
            }
        case .movie:
            Section("Movie") {
                TextField("Runtime (min)", text: $draft.runtime)
                    .keyboardType(.numberPad)
                TextField("Streaming service", text: $draft.streamingService)
                TextField("Release year", text: $draft.releaseYear)
                    .keyboardType(.numberPad)
            }
        default:
            EmptyView()
        }
    }

    private func save() async {
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let item: (any SharedListItem)?
        if let editingItem {
            item = draft.applying(to: editingItem)
        } else {
            item = newItem()
        }
        guard let item else { return }

        let result = await store.save(item)
        switch result {
        case .saved:
            dismiss()
        case .conflict:
            showingConflict = true
        case .failed:
            saveErrorMessage = store.errorMessage
        }
    }

    private func newItem() -> (any SharedListItem)? {
        guard let me = store.currentProfile else { return nil }
        return draft.makeNew(id: store.newItemID(), addedBy: me.reference)
    }
}

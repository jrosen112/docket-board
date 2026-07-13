//
//  ItemFormView.swift
//  Docket
//
//  Quick-edit form for an existing item, presented from the board. Fields are
//  pre-filled, category is fixed (an item's category is its CKRecord type,
//  which can't change), and the save path mutates the existing item so its
//  record identity + change tag are preserved. Adding new items goes through
//  NewItemView.
//

import SwiftUI

struct ItemFormView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let item: any SharedListItem

    @State private var draft: ItemDraft

    @State private var isSaving = false
    @State private var showingConflict = false
    @State private var saveErrorMessage: String?

    init(editing item: any SharedListItem) {
        self.item = item
        _draft = State(initialValue: ItemDraft(item: item))
    }

    private var canSave: Bool {
        draft.isValid && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Edit \(draft.category.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
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

        guard let edited = draft.applying(to: item) else { return }

        switch await store.save(edited) {
        case .saved:
            dismiss()
        case .conflict:
            showingConflict = true
        case .failed(let message):
            saveErrorMessage = message
        }
    }
}

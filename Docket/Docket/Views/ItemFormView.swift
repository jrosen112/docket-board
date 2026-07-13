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

    @State private var category: ItemCategory = .restaurant
    @State private var title = ""
    @State private var notes = ""
    @State private var status: ItemStatus = .wantToGo

    // Location-based categories
    @State private var location = ""
    // Restaurant
    @State private var cuisine = ""
    @State private var priceRange: PriceRange?
    // Bar
    @State private var barType: BarType?
    // Movie
    @State private var runtime = ""
    @State private var streamingService = ""
    @State private var releaseYear = ""

    @State private var isSaving = false
    @State private var showingConflict = false
    @State private var saveErrorMessage: String?

    init(editing item: (any SharedListItem)? = nil) {
        self.editingItem = item
        guard let item else { return }

        _category = State(initialValue: item.category)
        _title = State(initialValue: item.title)
        _notes = State(initialValue: item.notes ?? "")
        _status = State(initialValue: item.status)

        switch item {
        case let restaurant as Restaurant:
            _location = State(initialValue: restaurant.location ?? "")
            _cuisine = State(initialValue: restaurant.cuisine ?? "")
            _priceRange = State(initialValue: restaurant.priceRange)
        case let bar as Bar:
            _location = State(initialValue: bar.location ?? "")
            _barType = State(initialValue: bar.barType)
        case let movie as Movie:
            _runtime = State(initialValue: movie.runtimeMinutes.map(String.init) ?? "")
            _streamingService = State(initialValue: movie.streamingService ?? "")
            _releaseYear = State(initialValue: movie.releaseYear.map(String.init) ?? "")
        default:
            break
        }
    }

    private var isEditing: Bool { editingItem != nil }

    private var canSave: Bool {
        !title.trimmed.isEmpty && !isSaving && (isEditing || store.currentProfile != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section {
                        Picker("Category", selection: $category) {
                            ForEach(ItemCategory.supported, id: \.self) { category in
                                Text(category.label).tag(category)
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                    Picker("Status", selection: $status) {
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
            .navigationTitle(isEditing ? "Edit \(category.label)" : "Add to the Board")
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
        switch category {
        case .restaurant:
            Section("Restaurant") {
                TextField("Location", text: $location)
                TextField("Cuisine", text: $cuisine)
                Picker("Price", selection: $priceRange) {
                    Text("—").tag(PriceRange?.none)
                    ForEach(PriceRange.allCases, id: \.self) { price in
                        Text(price.rawValue).tag(Optional(price))
                    }
                }
            }
        case .bar:
            Section("Bar") {
                TextField("Location", text: $location)
                Picker("Type", selection: $barType) {
                    Text("—").tag(BarType?.none)
                    ForEach(BarType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(Optional(type))
                    }
                }
            }
        case .movie:
            Section("Movie") {
                TextField("Runtime (min)", text: $runtime)
                    .keyboardType(.numberPad)
                TextField("Streaming service", text: $streamingService)
                TextField("Release year", text: $releaseYear)
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
            item = applyingFields(to: editingItem)
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

    /// Editing path: mutate the existing typed item so id / addedBy /
    /// dateAdded / systemFields all carry through untouched.
    private func applyingFields(to existing: any SharedListItem) -> (any SharedListItem)? {
        switch existing {
        case var restaurant as Restaurant:
            restaurant.title = title.trimmed
            restaurant.notes = notes.orNil
            restaurant.status = status
            restaurant.location = location.orNil
            restaurant.cuisine = cuisine.orNil
            restaurant.priceRange = priceRange
            return restaurant
        case var bar as Bar:
            bar.title = title.trimmed
            bar.notes = notes.orNil
            bar.status = status
            bar.location = location.orNil
            bar.barType = barType
            return bar
        case var movie as Movie:
            movie.title = title.trimmed
            movie.notes = notes.orNil
            movie.status = status
            movie.runtimeMinutes = Int(runtime)
            movie.streamingService = streamingService.orNil
            movie.releaseYear = Int(releaseYear)
            return movie
        default:
            return nil
        }
    }

    private func newItem() -> (any SharedListItem)? {
        guard let me = store.currentProfile else { return nil }
        let id = store.newItemID()
        let addedBy = me.reference
        let trimmedTitle = title.trimmed
        let trimmedNotes = notes.orNil

        switch category {
        case .restaurant:
            return Restaurant(
                id: id, title: trimmedTitle, notes: trimmedNotes, status: status,
                addedBy: addedBy, location: location.orNil,
                cuisine: cuisine.orNil, priceRange: priceRange
            )
        case .bar:
            return Bar(
                id: id, title: trimmedTitle, notes: trimmedNotes, status: status,
                addedBy: addedBy, location: location.orNil, barType: barType
            )
        case .movie:
            return Movie(
                id: id, title: trimmedTitle, notes: trimmedNotes, status: status,
                addedBy: addedBy, runtimeMinutes: Int(runtime),
                streamingService: streamingService.orNil, releaseYear: Int(releaseYear)
            )
        default:
            return nil
        }
    }
}

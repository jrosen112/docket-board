//
//  AddItemView.swift
//  Docket
//
//  Category picker → category-specific fields → save. Only the Phase 1 subset
//  (Restaurant, Bar, Movie) is offered.
//

import SwiftUI

struct AddItemView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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

    private let supportedCategories: [ItemCategory] = [.restaurant, .bar, .movie]

    private var canSave: Bool {
        !title.trimmed.isEmpty && !isSaving && store.currentProfile != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(supportedCategories, id: \.self) { category in
                            Text(category.label).tag(category)
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
            }
            .navigationTitle("Add to the Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(!canSave)
                }
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
        guard let me = store.currentProfile else { return }
        isSaving = true
        defer { isSaving = false }

        let id = store.newItemID()
        let addedBy = me.reference
        let trimmedTitle = title.trimmed
        let trimmedNotes = notes.orNil

        let item: any SharedListItem
        switch category {
        case .restaurant:
            item = Restaurant(
                id: id, title: trimmedTitle, notes: trimmedNotes, status: status,
                addedBy: addedBy, location: location.orNil,
                cuisine: cuisine.orNil, priceRange: priceRange
            )
        case .bar:
            item = Bar(
                id: id, title: trimmedTitle, notes: trimmedNotes, status: status,
                addedBy: addedBy, location: location.orNil, barType: barType
            )
        case .movie:
            item = Movie(
                id: id, title: trimmedTitle, notes: trimmedNotes, status: status,
                addedBy: addedBy, runtimeMinutes: Int(runtime),
                streamingService: streamingService.orNil, releaseYear: Int(releaseYear)
            )
        default:
            return
        }

        await store.add(item)
        dismiss()
    }
}

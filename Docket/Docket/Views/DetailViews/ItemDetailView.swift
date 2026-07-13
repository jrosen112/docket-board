import CloudKit
import SwiftUI

struct ItemDetailView: View {
    @Environment(BoardStore.self) private var store

    let itemID: CKRecord.ID
    @State private var showingEdit = false

    private var item: (any SharedListItem)? {
        store.items.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item {
                detail(for: item)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Edit") { showingEdit = true }
                        }
                    }
                    .sheet(isPresented: $showingEdit) {
                        if let currentItem = self.item {
                            ItemFormView(editing: currentItem)
                        }
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
    private func detail(for item: any SharedListItem) -> some View {
        let addedBy = store.displayName(for: item)
        switch item {
        case let restaurant as Restaurant:
            RestaurantDetailView(restaurant: restaurant, addedBy: addedBy)
        case let bar as Bar:
            BarDetailView(bar: bar, addedBy: addedBy)
        case let movie as Movie:
            MovieDetailView(movie: movie, addedBy: addedBy)
        default:
            ContentUnavailableView("Unsupported item", systemImage: "questionmark")
        }
    }
}

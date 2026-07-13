import SwiftUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    let addedBy: String

    var body: some View {
        Form {
            Section("Docket") {
                LabeledContent("Status", value: restaurant.status.label)
                LabeledContent("Added by", value: addedBy)
            }
            Section("Restaurant") {
                optionalRow("Location", value: restaurant.location)
                optionalRow("Cuisine", value: restaurant.cuisine)
                optionalRow("Price", value: restaurant.priceRange?.rawValue)
            }
            if let notes = restaurant.notes {
                Section("Notes") { Text(notes) }
            }
        }
    }

    @ViewBuilder
    private func optionalRow(_ label: String, value: String?) -> some View {
        if let value {
            LabeledContent(label, value: value)
        }
    }
}

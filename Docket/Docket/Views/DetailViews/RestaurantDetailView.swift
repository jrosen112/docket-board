import SwiftUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    let addedBy: String

    var body: some View {
        DetailPage(item: restaurant, addedBy: addedBy, symbol: "fork.knife") {
            if let location = restaurant.location {
                DetailFactRow(
                    symbol: "mappin.and.ellipse",
                    label: "Location",
                    value: location,
                    accent: restaurant.category.accent
                )
            }
            if let cuisine = restaurant.cuisine {
                DetailFactRow(
                    symbol: "takeoutbag.and.cup.and.straw.fill",
                    label: "Cuisine",
                    value: cuisine,
                    accent: restaurant.category.accent
                )
            }
            if let price = restaurant.priceRange {
                DetailFactRow(
                    symbol: "creditcard.fill",
                    label: "Price",
                    value: price.rawValue,
                    accent: restaurant.category.accent
                )
            }
            if restaurant.location == nil,
               restaurant.cuisine == nil,
               restaurant.priceRange == nil {
                DetailEmptyFacts()
            }
        }
    }
}

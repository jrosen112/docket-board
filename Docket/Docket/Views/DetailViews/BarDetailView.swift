import SwiftUI

struct BarDetailView: View {
    let bar: Bar
    let addedBy: String

    var body: some View {
        DetailPage(item: bar, addedBy: addedBy, symbol: "wineglass.fill") {
            if let location = bar.location {
                DetailFactRow(
                    symbol: "mappin.and.ellipse",
                    label: "Location",
                    value: location,
                    accent: bar.category.accent
                )
            }
            if let type = bar.barType {
                DetailFactRow(
                    symbol: "sparkles",
                    label: "Vibe",
                    value: type.rawValue.capitalized,
                    accent: bar.category.accent
                )
            }
            if bar.location == nil, bar.barType == nil {
                DetailEmptyFacts()
            }
        }
    }
}

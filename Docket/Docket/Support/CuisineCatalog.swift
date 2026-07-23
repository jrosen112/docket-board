import Foundation

/// Shared cuisine vocabulary and normalization used by models, editors, search,
/// and board filters. Custom values live on items and are folded back into the
/// suggestion list whenever that board is loaded.
nonisolated enum CuisineCatalog {
    static let defaults = [
        "American", "Bakery", "Barbecue", "Brazilian", "Breakfast & Brunch",
        "Caribbean", "Chinese", "Ethiopian", "Filipino", "French", "Greek",
        "Indian", "Italian", "Japanese", "Korean", "Mediterranean", "Mexican",
        "Middle Eastern", "Peruvian", "Pizza", "Seafood", "Southern",
        "Spanish", "Steakhouse", "Thai", "Turkish", "Vegan", "Vegetarian",
        "Vietnamese",
    ]

    static func normalized(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            guard let name = normalizedName(value) else { return nil }
            let key = comparisonKey(name)
            guard seen.insert(key).inserted else { return nil }
            return name
        }
    }

    static func normalizedName(_ value: String) -> String? {
        let collapsed = value
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }

        if let standard = defaults.first(where: {
            comparisonKey($0) == comparisonKey(collapsed)
        }) {
            return standard
        }
        return collapsed
    }

    static func availableCuisines(existing values: [String]) -> [String] {
        let custom = normalized(values).filter { value in
            !defaults.contains { comparisonKey($0) == comparisonKey(value) }
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return defaults + custom
    }

    static func suggestions(
        matching query: String,
        selected: [String],
        available: [String]
    ) -> [String] {
        let selectedKeys = Set(selected.map(comparisonKey))
        let trimmedQuery = query.trimmed
        return availableCuisines(existing: available)
            .filter { !selectedKeys.contains(comparisonKey($0)) }
            .filter { trimmedQuery.isEmpty || $0.localizedStandardContains(trimmedQuery) }
    }

    static func comparisonKey(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }
}

nonisolated func itemCuisines(_ item: any SharedListItem) -> [String] {
    switch item {
    case let restaurant as Restaurant:
        restaurant.cuisines
    case let recipe as Recipe:
        recipe.cuisines
    default:
        []
    }
}

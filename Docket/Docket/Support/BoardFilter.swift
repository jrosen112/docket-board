//
//  BoardFilter.swift
//  Docket
//
//  Pure, testable filter logic for the board. The view holds one of these as
//  simple screen state; all the actual behavior lives here.
//

import Foundation

nonisolated struct BoardFilter: Equatable {
    /// Empty means every category is included.
    var categories: Set<ItemCategory> = []
    /// Empty means every status is included.
    var statuses: Set<ItemStatus> = []
    /// Empty means every cuisine is included. Cuisine matching is
    /// case/diacritic-insensitive so custom labels remain forgiving.
    var cuisines: Set<String> = []

    var isActive: Bool { !categories.isEmpty || !statuses.isEmpty || !cuisines.isEmpty }
    var selectionCount: Int { categories.count + statuses.count + cuisines.count }

    mutating func toggle(_ category: ItemCategory) {
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
    }

    mutating func toggle(_ status: ItemStatus) {
        if statuses.contains(status) {
            statuses.remove(status)
        } else {
            statuses.insert(status)
        }
    }

    mutating func toggle(cuisine: String) {
        guard let cuisine = CuisineCatalog.normalizedName(cuisine) else { return }
        if let selected = cuisines.first(where: {
            CuisineCatalog.comparisonKey($0) == CuisineCatalog.comparisonKey(cuisine)
        }) {
            cuisines.remove(selected)
        } else {
            cuisines.insert(cuisine)
        }
    }

    func contains(cuisine: String) -> Bool {
        let key = CuisineCatalog.comparisonKey(cuisine)
        return cuisines.contains { CuisineCatalog.comparisonKey($0) == key }
    }

    mutating func clear() {
        categories.removeAll()
        statuses.removeAll()
        cuisines.removeAll()
    }

    func apply(to items: [any SharedListItem]) -> [any SharedListItem] {
        items.filter { item in
            let itemCuisineKeys = Set(itemCuisines(item).map(CuisineCatalog.comparisonKey))
            let selectedCuisineKeys = Set(cuisines.map(CuisineCatalog.comparisonKey))
            return (categories.isEmpty || categories.contains(item.category))
                && (statuses.isEmpty || statuses.contains(item.status))
                && (cuisines.isEmpty || !itemCuisineKeys.isDisjoint(with: selectedCuisineKeys))
        }
    }
}

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

    var isActive: Bool { !categories.isEmpty || !statuses.isEmpty }
    var selectionCount: Int { categories.count + statuses.count }

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

    mutating func clear() {
        categories.removeAll()
        statuses.removeAll()
    }

    func apply(to items: [any SharedListItem]) -> [any SharedListItem] {
        items.filter { item in
            (categories.isEmpty || categories.contains(item.category))
                && (statuses.isEmpty || statuses.contains(item.status))
        }
    }
}

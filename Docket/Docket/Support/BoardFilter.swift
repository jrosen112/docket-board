//
//  BoardFilter.swift
//  Docket
//
//  Pure, testable filter logic for the board. The view holds one of these as
//  simple screen state; all the actual behavior lives here.
//

import Foundation

nonisolated struct BoardFilter: Equatable {
    /// nil = all categories.
    var category: ItemCategory?
    /// nil = any status.
    var status: ItemStatus?

    var isActive: Bool { category != nil || status != nil }

    func apply(to items: [any SharedListItem]) -> [any SharedListItem] {
        items.filter { item in
            (category == nil || item.category == category)
                && (status == nil || item.status == status)
        }
    }
}

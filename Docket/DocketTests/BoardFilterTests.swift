//
//  BoardFilterTests.swift
//  DocketTests
//
//  The board's filter logic (pure, no UI).
//

import XCTest
import CloudKit
@testable import Docket

final class BoardFilterTests: XCTestCase {

    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-1"),
        action: .none
    )

    private let chicagoLocation = ItemLocation(
        name: "Little Goat Diner",
        fullAddress: "820 W Randolph St, Chicago, IL 60607, United States",
        shortAddress: "820 W Randolph St",
        city: "Chicago",
        cityWithContext: "West Loop, Chicago",
        country: "United States",
        countryCode: "US",
        latitude: 41.8846,
        longitude: -87.6486
    )

    private var items: [any SharedListItem] {
        [
            Restaurant(id: CKRecord.ID(recordName: "r1"), title: "Tartine",
                       status: .wantToGo, addedBy: addedBy),
            Bar(id: CKRecord.ID(recordName: "b1"), title: "Trick Dog",
                status: .planned, addedBy: addedBy),
            Movie(id: CKRecord.ID(recordName: "m1"), title: "Heat",
                  status: .completed, addedBy: addedBy),
            Movie(id: CKRecord.ID(recordName: "m2"), title: "Past Lives",
                  status: .wantToGo, addedBy: addedBy),
        ]
    }

    func testEmptyFilterPassesEverythingAndIsInactive() {
        let filter = BoardFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.apply(to: items).count, 4)
    }

    func testCategoryFilter() {
        let filter = BoardFilter(categories: [.movie])
        XCTAssertTrue(filter.isActive)
        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Heat", "Past Lives"])
    }

    func testStatusFilter() {
        let filter = BoardFilter(statuses: [.wantToGo])
        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Tartine", "Past Lives"])
    }

    func testCombinedCategoryAndStatus() {
        let filter = BoardFilter(categories: [.movie], statuses: [.wantToGo])
        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Past Lives"])
    }

    func testNoMatches() {
        let filter = BoardFilter(categories: [.bar], statuses: [.completed])
        XCTAssertTrue(filter.apply(to: items).isEmpty)
    }

    func testMultipleCategoriesUseORWithinCategoryGroup() {
        let filter = BoardFilter(categories: [.restaurant, .bar])

        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Tartine", "Trick Dog"])
    }

    func testMultipleStatusesUseORWithinStatusGroup() {
        let filter = BoardFilter(statuses: [.wantToGo, .planned])

        XCTAssertEqual(
            filter.apply(to: items).map(\.title),
            ["Tartine", "Trick Dog", "Past Lives"]
        )
    }

    func testSelectionCountAndClear() {
        var filter = BoardFilter(
            categories: [.restaurant, .bar, .movie],
            statuses: [.wantToGo, .planned]
        )
        XCTAssertEqual(filter.selectionCount, 5)

        filter.clear()

        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.selectionCount, 0)
        XCTAssertEqual(filter.apply(to: items).count, 4)
    }

    func testToggleAddsAndRemovesSelections() {
        var filter = BoardFilter()

        filter.toggle(.restaurant)
        filter.toggle(ItemStatus.planned)
        XCTAssertEqual(filter.categories, [.restaurant])
        XCTAssertEqual(filter.statuses, [.planned])

        filter.toggle(.restaurant)
        filter.toggle(ItemStatus.planned)
        XCTAssertFalse(filter.isActive)
    }

    func testBoardSearchMatchesVisibleAndSupportingItemContent() {
        let restaurant = Restaurant(
            id: CKRecord.ID(recordName: "search-r1"),
            title: "Little Goat Diner",
            notes: "Order the pancakes",
            status: .planned,
            addedBy: addedBy,
            location: chicagoLocation,
            cuisine: "American",
            priceRange: .moderate
        )

        XCTAssertTrue(itemMatchesBoardSearch(restaurant, query: "goat"))
        XCTAssertTrue(itemMatchesBoardSearch(restaurant, query: "pancakes"))
        XCTAssertTrue(itemMatchesBoardSearch(restaurant, query: "restaurant planned"))
        XCTAssertTrue(itemMatchesBoardSearch(restaurant, query: "american loop"))
        XCTAssertFalse(itemMatchesBoardSearch(restaurant, query: "movie"))
    }

    func testBoardSearchIsCaseInsensitiveAndIgnoresEmptyQuery() {
        let movie = items[2]

        XCTAssertTrue(itemMatchesBoardSearch(movie, query: "hEaT"))
        XCTAssertTrue(itemMatchesBoardSearch(movie, query: "  \n  "))
    }
}

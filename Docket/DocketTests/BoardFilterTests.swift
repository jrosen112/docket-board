//
//  BoardFilterTests.swift
//  DocketTests
//
//  The board's filter logic (pure, no UI).
//

import CloudKit
import XCTest

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
            Restaurant(
                id: CKRecord.ID(recordName: "r1"), title: "Tartine",
                status: .wantToGo, addedBy: addedBy, cuisines: ["Bakery", "French"]),
            Bar(
                id: CKRecord.ID(recordName: "b1"), title: "Trick Dog",
                status: .planned, addedBy: addedBy),
            Movie(
                id: CKRecord.ID(recordName: "m1"), title: "Heat",
                status: .completed, addedBy: addedBy),
            Movie(
                id: CKRecord.ID(recordName: "m2"), title: "Past Lives",
                status: .wantToGo, addedBy: addedBy),
            Recipe(
                id: CKRecord.ID(recordName: "recipe-1"), title: "Red Curry",
                status: .planned, addedBy: addedBy, cuisines: ["Thai"]),
        ]
    }

    func testEmptyFilterPassesEverythingAndIsInactive() {
        let filter = BoardFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.apply(to: items).count, 5)
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
            ["Tartine", "Trick Dog", "Past Lives", "Red Curry"]
        )
    }

    func testSelectionCountAndClear() {
        var filter = BoardFilter(
            categories: [.restaurant, .bar, .movie],
            statuses: [.wantToGo, .planned],
            cuisines: ["Thai", "French"]
        )
        XCTAssertEqual(filter.selectionCount, 7)

        filter.clear()

        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.selectionCount, 0)
        XCTAssertEqual(filter.apply(to: items).count, 5)
    }

    func testToggleAddsAndRemovesSelections() {
        var filter = BoardFilter()

        filter.toggle(.restaurant)
        filter.toggle(ItemStatus.planned)
        filter.toggle(cuisine: "thai")
        XCTAssertEqual(filter.categories, [.restaurant])
        XCTAssertEqual(filter.statuses, [.planned])
        XCTAssertTrue(filter.contains(cuisine: "Thai"))

        filter.toggle(.restaurant)
        filter.toggle(ItemStatus.planned)
        filter.toggle(cuisine: "THAI")
        XCTAssertFalse(filter.isActive)
    }

    func testCuisineFilterMatchesRecipesAndRestaurants() {
        let thai = BoardFilter(cuisines: ["thai"])
        let bakery = BoardFilter(cuisines: ["Bakery"])

        XCTAssertEqual(thai.apply(to: items).map(\.title), ["Red Curry"])
        XCTAssertEqual(bakery.apply(to: items).map(\.title), ["Tartine"])
    }

    func testMultipleCuisineSelectionsUseORWithinCuisineGroup() {
        let filter = BoardFilter(cuisines: ["Thai", "French"])

        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Tartine", "Red Curry"])
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

    func testBoardSearchFindsRecipeSourceIngredientsAndInstructions() {
        let recipe = Recipe(
            id: CKRecord.ID(recordName: "search-recipe"),
            title: "Crispy Chicken",
            addedBy: addedBy,
            sourceURL: "https://www.tiktok.com/@cook/video/123",
            ingredients: ["Gochujang", "Chicken thighs"],
            instructions: ["Roast until caramelized"]
        )

        XCTAssertTrue(itemMatchesBoardSearch(recipe, query: "tiktok"))
        XCTAssertTrue(itemMatchesBoardSearch(recipe, query: "gochujang"))
        XCTAssertTrue(itemMatchesBoardSearch(recipe, query: "caramelized"))
    }
}

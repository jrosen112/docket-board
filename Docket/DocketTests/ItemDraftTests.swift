import CloudKit
import XCTest

@testable import Docket

final class ItemDraftTests: XCTestCase {
    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-1"),
        action: .none
    )

    private let oldLocation = ItemLocation(
        name: "Old Place",
        fullAddress: "1 Old St, Chicago, IL 60601, United States",
        shortAddress: "1 Old St",
        city: "Chicago",
        cityWithContext: "Chicago, IL",
        country: "United States",
        countryCode: "US",
        latitude: 41.88,
        longitude: -87.63,
        mapItemIdentifier: "old-place"
    )

    private let newLocation = ItemLocation(
        name: "New Place",
        fullAddress: "2 New St, Chicago, IL 60601, United States",
        shortAddress: "2 New St",
        city: "Chicago",
        cityWithContext: "Chicago, IL",
        country: "United States",
        countryCode: "US",
        latitude: 41.881,
        longitude: -87.631,
        mapItemIdentifier: "new-place"
    )

    func testApplyingDraftPreservesCloudKitIdentityAndMetadata() throws {
        let dateAdded = Date(timeIntervalSince1970: 123_456)
        let plannedDate = Date(timeIntervalSince1970: 223_456)
        let completionDate = Date(timeIntervalSince1970: 23_456)
        let fetched = try XCTUnwrap(
            Restaurant(
                record: Restaurant(
                    id: CKRecord.ID(recordName: "restaurant-1"),
                    title: "Before",
                    addedBy: addedBy,
                    dateAdded: dateAdded,
                    plannedDate: plannedDate,
                    plannedDateHasTime: true,
                    completionDates: [completionDate],
                    location: oldLocation
                ).toRecord()))
        var draft = ItemDraft(item: fetched)
        draft.title = "After"
        draft.location = newLocation
        draft.showsMapOnBoard = true
        draft.cuisines = ["Thai", "Chinese"]
        draft.priceRange = .moderate
        draft.photoData = Data([0xCA, 0xFE])
        draft.boardCardMedia = .map

        let edited = try XCTUnwrap(draft.applying(to: fetched) as? Restaurant)

        XCTAssertEqual(edited.id, fetched.id)
        XCTAssertEqual(edited.addedBy.recordID, fetched.addedBy.recordID)
        XCTAssertEqual(edited.dateAdded, dateAdded)
        XCTAssertEqual(edited.plannedDate, plannedDate)
        XCTAssertTrue(edited.plannedDateHasTime)
        XCTAssertEqual(edited.completionDates, [completionDate])
        XCTAssertEqual(edited.systemFields, fetched.systemFields)
        XCTAssertEqual(edited.title, "After")
        XCTAssertEqual(edited.location, newLocation)
        XCTAssertTrue(edited.showsMapOnBoard)
        XCTAssertEqual(edited.cuisines, ["Thai", "Chinese"])
        XCTAssertEqual(edited.priceRange, .moderate)
        XCTAssertEqual(edited.photoData, draft.photoData)
        XCTAssertFalse(edited.showsPhotoOnBoard)
        XCTAssertTrue(edited.showsMapOnBoard)
    }

    func testDraftCanFillPreviouslyMissingMovieFields() throws {
        let movie = Movie(
            id: CKRecord.ID(recordName: "movie-1"),
            title: "Heat",
            addedBy: addedBy
        )
        var draft = ItemDraft(item: movie)
        draft.runtime = "170"
        draft.releaseYear = "1995"
        draft.streamingService = "Max"
        draft.notes = "Friday night"
        draft.tmdbID = 949

        let edited = try XCTUnwrap(draft.applying(to: movie) as? Movie)

        XCTAssertEqual(edited.runtimeMinutes, 170)
        XCTAssertEqual(edited.releaseYear, 1995)
        XCTAssertEqual(edited.streamingService, "Max")
        XCTAssertEqual(edited.notes, "Friday night")
        XCTAssertEqual(edited.tmdbID, 949)
    }

    func testDraftBuildsNewTypedItem() throws {
        var draft = ItemDraft()
        draft.category = .bar
        draft.title = "  Trick Dog  "
        draft.location = newLocation
        draft.showsMapOnBoard = true
        draft.barType = .cocktail
        let id = CKRecord.ID(recordName: "bar-1")
        let dateAdded = Date(timeIntervalSince1970: 456_789)

        let bar = try XCTUnwrap(
            draft.makeNew(id: id, addedBy: addedBy, dateAdded: dateAdded) as? Bar
        )

        XCTAssertEqual(bar.id, id)
        XCTAssertEqual(bar.dateAdded, dateAdded)
        XCTAssertEqual(bar.title, "Trick Dog")
        XCTAssertEqual(bar.location, newLocation)
        XCTAssertTrue(bar.showsMapOnBoard)
        XCTAssertEqual(bar.barType, .cocktail)
    }

    func testDraftCanStartWithAPreselectedCategory() {
        let draft = ItemDraft(category: .movie)

        XCTAssertEqual(draft.category, .movie)
    }

    func testDraftCarriesExistingPhotoSettings() {
        let photoData = Data([0xBA, 0x5E])
        let movie = Movie(
            id: CKRecord.ID(recordName: "movie-photo"),
            title: "Paris, Texas",
            addedBy: addedBy,
            photoData: photoData,
            showsPhotoOnBoard: true,
            boardPhotoPosition: BoardPhotoPosition(x: 0.25, y: 0.75)
        )

        let draft = ItemDraft(item: movie)

        XCTAssertEqual(draft.photoData, photoData)
        XCTAssertTrue(draft.showsPhotoOnBoard)
        XCTAssertEqual(draft.boardPhotoPosition, movie.boardPhotoPosition)

        let edited = try? XCTUnwrap(draft.applying(to: movie) as? Movie)
        XCTAssertEqual(edited?.boardPhotoPosition, movie.boardPhotoPosition)
    }

    func testBoardCardMediaKeepsPhotoAndMapMutuallyExclusive() {
        var draft = ItemDraft(category: .restaurant)
        draft.location = newLocation
        draft.photoData = Data([0x01])

        draft.boardCardMedia = .map
        XCTAssertTrue(draft.showsMapOnBoard)
        XCTAssertFalse(draft.showsPhotoOnBoard)

        draft.boardCardMedia = .photo
        XCTAssertFalse(draft.showsMapOnBoard)
        XCTAssertTrue(draft.showsPhotoOnBoard)

        draft.boardCardMedia = .none
        XCTAssertFalse(draft.showsMapOnBoard)
        XCTAssertFalse(draft.showsPhotoOnBoard)
    }

    func testRecipeDraftBuildsStructuredListsAndGallery() throws {
        var draft = ItemDraft(category: .recipe)
        draft.title = "  Tomato Pasta  "
        draft.sourceURL = "https://www.instagram.com/reel/pasta"
        draft.cuisines = ["Italian", "Vegetarian"]
        draft.ingredients = "- 1 lb tomatoes\n• Olive oil\n\n* Salt"
        draft.instructions = "1. Roast the tomatoes\n2) Toss with pasta"
        draft.photoData = Data([0x01])
        draft.additionalPhotoData = (2...7).map { Data([$0]) }
        draft.boardCardMedia = .photo

        let recipe = try XCTUnwrap(
            draft.makeNew(
                id: CKRecord.ID(recordName: "recipe-draft"),
                addedBy: addedBy
            ) as? Recipe
        )

        XCTAssertEqual(recipe.title, "Tomato Pasta")
        XCTAssertEqual(recipe.cuisines, ["Italian", "Vegetarian"])
        XCTAssertEqual(recipe.ingredients, ["1 lb tomatoes", "Olive oil", "Salt"])
        XCTAssertEqual(recipe.instructions, ["Roast the tomatoes", "Toss with pasta"])
        XCTAssertEqual(recipe.allPhotoData.count, Recipe.maximumPhotoCount)
        XCTAssertTrue(recipe.showsPhotoOnBoard)
    }

    func testRecipeDraftCarriesAndEditsRecipeFields() throws {
        let recipe = Recipe(
            id: CKRecord.ID(recordName: "recipe-edit"),
            title: "Soup",
            addedBy: addedBy,
            sourceURL: "https://example.com/soup",
            cuisines: ["Japanese"],
            ingredients: ["Stock"],
            instructions: ["Simmer"],
            additionalPhotoData: [Data([0x02])]
        )
        var draft = ItemDraft(item: recipe)

        XCTAssertEqual(draft.ingredients, "Stock")
        XCTAssertEqual(draft.cuisines, ["Japanese"])
        XCTAssertEqual(draft.instructions, "Simmer")
        XCTAssertEqual(draft.additionalPhotoData, [Data([0x02])])

        draft.ingredients += "\nNoodles"
        draft.cuisines.append("Comfort Food")
        let edited = try XCTUnwrap(draft.applying(to: recipe) as? Recipe)
        XCTAssertEqual(edited.ingredients, ["Stock", "Noodles"])
        XCTAssertEqual(edited.cuisines, ["Japanese", "Comfort Food"])
        XCTAssertEqual(edited.sourceURL, "https://example.com/soup")
    }

    func testRecipeUsesCookingSpecificStatusLabels() {
        XCTAssertEqual(ItemStatus.wantToGo.label(for: .recipe), "Want to make")
        XCTAssertEqual(ItemStatus.completed.label(for: .recipe), "Made")
        XCTAssertEqual(ItemStatus.wantToGo.label(for: .restaurant), "Want to go")
        XCTAssertEqual(ItemStatus.completed.label(for: .restaurant), "Visited")
        XCTAssertEqual(ItemStatus.wantToGo.label(for: .movie), "Want to watch")
        XCTAssertEqual(ItemStatus.completed.label(for: .movie), "Watched")
        XCTAssertEqual(ItemCategory.restaurant.completionLabel, "Visited")
        XCTAssertEqual(ItemCategory.recipe.completionLabel, "Cooked")
        XCTAssertEqual(ItemCategory.movie.completionLabel, "Watched")
    }

    func testAddingPlannedDateUsesTomorrowAndSuggestsPlannedStatus() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 10))
        )
        var draft = ItemDraft(category: .restaurant)

        draft.addPlannedDate(relativeTo: now, calendar: calendar)

        XCTAssertEqual(draft.status, .planned)
        XCTAssertFalse(draft.plannedDateHasTime)
        XCTAssertEqual(
            calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: try XCTUnwrap(draft.plannedDate)
            ),
            DateComponents(year: 2026, month: 7, day: 24, hour: 19, minute: 0)
        )
    }

    func testLoggingCompletionClearsElapsedPlanAndDeduplicatesDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let plannedDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 19))
        )
        let completionDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 22))
        )
        var draft = ItemDraft(category: .movie)
        draft.plannedDate = plannedDate
        draft.plannedDateHasTime = true
        draft.status = .planned

        draft.logCompletion(on: completionDate, calendar: calendar)
        draft.plannedDate = plannedDate
        draft.plannedDateHasTime = true
        draft.status = .planned
        draft.logCompletion(on: completionDate, calendar: calendar)

        XCTAssertEqual(draft.status, .completed)
        XCTAssertNil(draft.plannedDate)
        XCTAssertFalse(draft.plannedDateHasTime)
        XCTAssertEqual(draft.completionDates, [calendar.startOfDay(for: completionDate)])
    }

    func testLoggingPastCompletionKeepsFuturePlan() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let completionDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 23))
        )
        let plannedDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 30, hour: 19))
        )
        var draft = ItemDraft(category: .restaurant)
        draft.plannedDate = plannedDate

        draft.logCompletion(on: completionDate, calendar: calendar)

        XCTAssertEqual(draft.status, .planned)
        XCTAssertEqual(draft.plannedDate, plannedDate)
        XCTAssertEqual(draft.completionDates, [completionDate])
    }
}

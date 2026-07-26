//
//  ModelConversionTests.swift
//  DocketTests
//
//  Round-trip tests for CKRecord <-> model conversion. These run fully offline
//  (CKRecord / CKRecord.Reference are in-memory objects), so no CloudKit account
//  or network is needed.
//

import CloudKit
import XCTest

@testable import Docket

final class ModelConversionTests: XCTestCase {

    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-alice"),
        action: .none
    )
    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)
    private let location = ItemLocation(
        name: "Tartine Manufactory",
        fullAddress: "595 Alabama St, San Francisco, CA 94110, United States",
        shortAddress: "595 Alabama St",
        city: "San Francisco",
        cityWithContext: "San Francisco, CA",
        country: "United States",
        countryCode: "US",
        latitude: 37.7615,
        longitude: -122.4115,
        mapItemIdentifier: "tartine-map-item"
    )

    // MARK: Restaurant

    func testRestaurantRoundTrip() throws {
        let photoData = Data([0x01, 0x23, 0x45, 0x67])
        let plannedDate = Date(timeIntervalSince1970: 1_100_000)
        let completionDates = [
            Date(timeIntervalSince1970: 800_000),
            Date(timeIntervalSince1970: 900_000),
        ]
        let original = Restaurant(
            id: CKRecord.ID(recordName: "r1"),
            title: "Tartine",
            notes: "get the morning bun",
            status: .planned,
            addedBy: addedBy,
            dateAdded: fixedDate,
            plannedDate: plannedDate,
            plannedDateHasTime: true,
            completionDates: completionDates,
            photoData: photoData,
            showsPhotoOnBoard: true,
            boardPhotoPosition: BoardPhotoPosition(x: 0.2, y: 0.85),
            location: location,
            showsMapOnBoard: true,
            cuisines: ["Bakery", "French"],
            priceRange: .moderate
        )

        let record = original.toRecord()
        XCTAssertEqual(record.recordType, Schema.RecordType.restaurant)

        let decoded = try XCTUnwrap(Restaurant(record: record))
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.notes, original.notes)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.addedBy.recordID, original.addedBy.recordID)
        XCTAssertEqual(decoded.dateAdded, original.dateAdded)
        XCTAssertEqual(decoded.plannedDate, plannedDate)
        XCTAssertTrue(decoded.plannedDateHasTime)
        XCTAssertEqual(decoded.completionDates, completionDates)
        XCTAssertEqual(decoded.photoData, photoData)
        XCTAssertTrue(decoded.showsPhotoOnBoard)
        XCTAssertEqual(decoded.boardPhotoPosition, original.boardPhotoPosition)
        XCTAssertEqual(decoded.location, original.location)
        XCTAssertTrue(decoded.showsMapOnBoard)
        XCTAssertEqual(decoded.cuisines, original.cuisines)
        XCTAssertEqual(record[Schema.Field.cuisine] as? String, "Bakery")
        XCTAssertEqual(decoded.priceRange, original.priceRange)
    }

    // MARK: Bar

    func testBarRoundTrip() throws {
        let original = Bar(
            id: CKRecord.ID(recordName: "b1"),
            title: "Trick Dog",
            status: .wantToGo,
            addedBy: addedBy,
            dateAdded: fixedDate,
            location: location,
            barType: .cocktail
        )

        let decoded = try XCTUnwrap(Bar(record: original.toRecord()))
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.location, original.location)
        XCTAssertFalse(decoded.showsMapOnBoard)
        XCTAssertEqual(decoded.barType, original.barType)
        XCTAssertNil(decoded.notes)
    }

    func testUSLocationAddressPresentation() {
        XCTAssertEqual(location.streetAddress, "595 Alabama St")
        XCTAssertEqual(
            location.detailAddress,
            "595 Alabama St, San Francisco, CA 94110"
        )
    }

    func testInternationalLocationAddressPresentationKeepsCountry() {
        let internationalLocation = ItemLocation(
            name: "Dishoom",
            fullAddress: "12 Upper St, London N1 0PQ, United Kingdom",
            shortAddress: "London",
            city: "London",
            cityWithContext: "London, United Kingdom",
            country: "United Kingdom",
            countryCode: "GB",
            latitude: 51.533,
            longitude: -0.105
        )

        XCTAssertEqual(internationalLocation.streetAddress, "12 Upper St")
        XCTAssertEqual(
            internationalLocation.detailAddress,
            "12 Upper St, London N1 0PQ, United Kingdom"
        )
    }

    // MARK: Movie

    func testMovieRoundTrip() throws {
        let original = Movie(
            id: CKRecord.ID(recordName: "m1"),
            title: "Past Lives",
            status: .completed,
            addedBy: addedBy,
            dateAdded: fixedDate,
            runtimeMinutes: 105,
            streamingService: "Showtime",
            releaseYear: 2023,
            tmdbID: 666277,
            tmdbPosterPath: "/past-lives.jpg"
        )

        let decoded = try XCTUnwrap(Movie(record: original.toRecord()))
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.runtimeMinutes, original.runtimeMinutes)
        XCTAssertEqual(decoded.streamingService, original.streamingService)
        XCTAssertEqual(decoded.releaseYear, original.releaseYear)
        XCTAssertEqual(decoded.tmdbID, original.tmdbID)
        XCTAssertEqual(decoded.tmdbPosterPath, original.tmdbPosterPath)
    }

    /// Movies saved before the poster path existed decode with a nil path rather
    /// than failing, and keep working without full-resolution artwork.
    func testMovieWithoutPosterPathDecodes() throws {
        let original = Movie(
            id: CKRecord.ID(recordName: "m2"),
            title: "Heat",
            addedBy: addedBy,
            dateAdded: fixedDate,
            tmdbID: 949
        )

        let record = original.toRecord()
        XCTAssertNil(record[Schema.Field.tmdbPosterPath])

        let decoded = try XCTUnwrap(Movie(record: record))
        XCTAssertNil(decoded.tmdbPosterPath)
        XCTAssertEqual(decoded.tmdbID, 949)
    }

    // MARK: Recipe

    func testRecipeRoundTripPreservesCookableFieldsAndGallery() throws {
        let cover = Data([0x01, 0x02])
        let processPhoto = Data([0x03, 0x04])
        let finishedPhoto = Data([0x05, 0x06])
        let original = Recipe(
            id: CKRecord.ID(recordName: "recipe-1"),
            title: "Gochujang Chicken",
            notes: "Double the sauce",
            status: .planned,
            addedBy: addedBy,
            dateAdded: fixedDate,
            photoData: cover,
            showsPhotoOnBoard: true,
            sourceURL: "https://www.instagram.com/reel/example",
            cuisines: ["Korean", "American"],
            ingredients: ["Chicken thighs", "Gochujang", "Honey"],
            instructions: ["Whisk the sauce", "Roast the chicken"],
            additionalPhotoData: [processPhoto, finishedPhoto]
        )

        let record = original.toRecord()
        XCTAssertEqual(record.recordType, Schema.RecordType.recipe)

        let decoded = try XCTUnwrap(Recipe(record: record))
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.notes, original.notes)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.sourceURL, original.sourceURL)
        XCTAssertEqual(decoded.cuisines, original.cuisines)
        XCTAssertEqual(decoded.ingredients, original.ingredients)
        XCTAssertEqual(decoded.instructions, original.instructions)
        XCTAssertEqual(decoded.allPhotoData, [cover, processPhoto, finishedPhoto])
        XCTAssertTrue(decoded.showsPhotoOnBoard)
    }

    func testRecipeNormalizesSocialURLWithoutScheme() {
        XCTAssertEqual(
            Recipe.normalizedURL(from: "www.tiktok.com/@cook/video/123")?.absoluteString,
            "https://www.tiktok.com/@cook/video/123"
        )
    }

    func testRecipeRejectsNonWebSourceURL() {
        XCTAssertNil(Recipe.normalizedURL(from: "javascript:alert(1)"))
    }

    // MARK: UserProfile

    func testUserProfileRoundTrip() throws {
        let original = UserProfile(
            id: CKRecord.ID(recordName: "profile-alice"),
            firstName: "Alice",
            lastName: "Nguyen",
            accountRecordName: "opaque-icloud-account-id"
        )

        let decoded = try XCTUnwrap(UserProfile(record: original.toRecord()))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayName, "Alice Nguyen")
        XCTAssertEqual(decoded.accountRecordName, "opaque-icloud-account-id")
    }

    // MARK: Guard rails

    func testWrongRecordTypeReturnsNil() {
        // A Bar record must not decode as a Restaurant.
        let bar = Bar(
            id: CKRecord.ID(recordName: "b2"),
            title: "Zeitgeist",
            addedBy: addedBy
        )
        XCTAssertNil(Restaurant(record: bar.toRecord()))
    }

    func testMissingRequiredFieldReturnsNil() {
        // A record of the right type but missing required shared fields fails.
        let empty = CKRecord(
            recordType: Schema.RecordType.movie,
            recordID: CKRecord.ID(recordName: "m2")
        )
        XCTAssertNil(Movie(record: empty))
    }

    func testLegacyItemWithoutPhotoFieldsUsesSafeDefaults() throws {
        let record = Movie(
            id: CKRecord.ID(recordName: "legacy-movie"),
            title: "Heat",
            addedBy: addedBy,
            dateAdded: fixedDate
        ).toRecord()
        record[Schema.Field.itemPhoto] = nil
        record[Schema.Field.showsPhotoOnBoard] = nil

        let decoded = try XCTUnwrap(Movie(record: record))

        XCTAssertNil(decoded.photoData)
        XCTAssertFalse(decoded.showsPhotoOnBoard)
        XCTAssertEqual(decoded.boardPhotoPosition, .center)
    }

    func testLegacyItemWithoutDateFieldsUsesSafeDefaults() throws {
        let record = Movie(
            id: CKRecord.ID(recordName: "legacy-movie-dates"),
            title: "Heat",
            addedBy: addedBy,
            dateAdded: fixedDate
        ).toRecord()
        record[Schema.Field.plannedDate] = nil
        record[Schema.Field.plannedDateHasTime] = nil
        record[Schema.Field.completionDates] = nil

        let decoded = try XCTUnwrap(Movie(record: record))

        XCTAssertNil(decoded.plannedDate)
        XCTAssertFalse(decoded.plannedDateHasTime)
        XCTAssertTrue(decoded.completionDates.isEmpty)
    }

    func testLegacyPhotoDefaultsToCenteredBoardCrop() throws {
        let record = Movie(
            id: CKRecord.ID(recordName: "legacy-photo-crop"),
            title: "Heat",
            addedBy: addedBy,
            dateAdded: fixedDate,
            photoData: Data([0x01]),
            showsPhotoOnBoard: true
        ).toRecord()
        record[Schema.Field.boardPhotoPositionX] = nil
        record[Schema.Field.boardPhotoPositionY] = nil

        let decoded = try XCTUnwrap(Movie(record: record))

        XCTAssertEqual(decoded.boardPhotoPosition, .center)
    }

    func testBoardPhotoPositionClampsToValidCropRange() {
        XCTAssertEqual(
            BoardPhotoPosition(x: -0.5, y: 1.5),
            BoardPhotoPosition(x: 0, y: 1)
        )
    }

    func testLegacyRestaurantCuisineMigratesIntoCuisineArray() throws {
        let record = Restaurant(
            id: CKRecord.ID(recordName: "legacy-cuisine"),
            title: "Old Favorite",
            addedBy: addedBy,
            dateAdded: fixedDate
        ).toRecord()
        record[Schema.Field.cuisines] = nil
        record[Schema.Field.cuisine] = "Thai"

        let decoded = try XCTUnwrap(Restaurant(record: record))

        XCTAssertEqual(decoded.cuisines, ["Thai"])
    }

    // MARK: System fields (edit support)

    func testDecodedModelCarriesSystemFieldsIntoNextRecord() throws {
        // New model → no system fields; decoded model → carries them, and
        // toRecord() resurrects the same record identity from the archive.
        let fresh = Movie(
            id: CKRecord.ID(recordName: "m3"),
            title: "Heat",
            addedBy: addedBy,
            dateAdded: fixedDate
        )
        XCTAssertNil(fresh.systemFields)

        let decoded = try XCTUnwrap(Movie(record: fresh.toRecord()))
        XCTAssertNotNil(decoded.systemFields)

        let reencoded = decoded.toRecord()
        XCTAssertEqual(reencoded.recordID, fresh.id)
        XCTAssertEqual(reencoded.recordType, Schema.RecordType.movie)
    }

    func testEditedFieldsSurviveSystemFieldsRoundTrip() throws {
        let original = Restaurant(
            id: CKRecord.ID(recordName: "r2"),
            title: "Before",
            addedBy: addedBy,
            dateAdded: fixedDate
        )

        var edited = try XCTUnwrap(Restaurant(record: original.toRecord()))
        edited.title = "After"
        edited.status = .planned
        edited.cuisine = "Thai"

        let decoded = try XCTUnwrap(Restaurant(record: edited.toRecord()))
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "After")
        XCTAssertEqual(decoded.status, .planned)
        XCTAssertEqual(decoded.cuisine, "Thai")
        // Untouched fields carry through.
        XCTAssertEqual(decoded.dateAdded, fixedDate)
        XCTAssertEqual(decoded.addedBy.recordID, addedBy.recordID)
    }
}

//
//  ModelConversionTests.swift
//  DocketTests
//
//  Round-trip tests for CKRecord <-> model conversion. These run fully offline
//  (CKRecord / CKRecord.Reference are in-memory objects), so no CloudKit account
//  or network is needed.
//

import XCTest
import CloudKit
@testable import Docket

final class ModelConversionTests: XCTestCase {

    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-alice"),
        action: .none
    )
    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    // MARK: Restaurant

    func testRestaurantRoundTrip() throws {
        let original = Restaurant(
            id: CKRecord.ID(recordName: "r1"),
            title: "Tartine",
            notes: "get the morning bun",
            status: .planned,
            addedBy: addedBy,
            dateAdded: fixedDate,
            location: "San Francisco",
            cuisine: "Bakery",
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
        XCTAssertEqual(decoded.location, original.location)
        XCTAssertEqual(decoded.cuisine, original.cuisine)
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
            location: "SF Mission",
            barType: .cocktail
        )

        let decoded = try XCTUnwrap(Bar(record: original.toRecord()))
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.location, original.location)
        XCTAssertEqual(decoded.barType, original.barType)
        XCTAssertNil(decoded.notes)
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
            releaseYear: 2023
        )

        let decoded = try XCTUnwrap(Movie(record: original.toRecord()))
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.runtimeMinutes, original.runtimeMinutes)
        XCTAssertEqual(decoded.streamingService, original.streamingService)
        XCTAssertEqual(decoded.releaseYear, original.releaseYear)
    }

    // MARK: UserProfile

    func testUserProfileRoundTrip() throws {
        let original = UserProfile(
            id: CKRecord.ID(recordName: "profile-alice"),
            firstName: "Alice",
            lastName: "Nguyen"
        )

        let decoded = try XCTUnwrap(UserProfile(record: original.toRecord()))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayName, "Alice Nguyen")
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
}

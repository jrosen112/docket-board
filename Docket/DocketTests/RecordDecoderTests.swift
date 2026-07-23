//
//  RecordDecoderTests.swift
//  DocketTests
//
//  The record-type → model dispatch that the service relies on.
//

import CloudKit
import XCTest

@testable import Docket

final class RecordDecoderTests: XCTestCase {

    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-1"),
        action: .none
    )

    func testPartitionSplitsItemsAndProfilesAndDropsUnknown() {
        let restaurant = Restaurant(
            id: CKRecord.ID(recordName: "r1"), title: "Tartine", addedBy: addedBy
        ).toRecord()
        let movie = Movie(
            id: CKRecord.ID(recordName: "m1"), title: "Heat", addedBy: addedBy
        ).toRecord()
        let profile = UserProfile(
            id: CKRecord.ID(recordName: "profile-1"), firstName: "Alice", lastName: ""
        ).toRecord()
        // Stand-in for records the zone contains but the board doesn't render
        // (e.g. the CKShare system record).
        let unknown = CKRecord(recordType: "cloudkit.share")

        let (items, profiles) = RecordDecoder.partition([restaurant, movie, profile, unknown])

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.firstName, "Alice")
    }

    func testItemDispatchesToConcreteTypes() throws {
        let bar = Bar(
            id: CKRecord.ID(recordName: "b1"), title: "Trick Dog", addedBy: addedBy
        ).toRecord()

        let decoded = try XCTUnwrap(RecordDecoder.item(from: bar))
        XCTAssertEqual(decoded.category, .bar)
        XCTAssertTrue(decoded is Bar)
    }

    func testRecipeDispatchesToRecipe() throws {
        let record = Recipe(
            id: CKRecord.ID(recordName: "recipe-1"),
            title: "Tomato Pasta",
            addedBy: addedBy
        ).toRecord()

        let decoded = try XCTUnwrap(RecordDecoder.item(from: record))
        XCTAssertEqual(decoded.category, .recipe)
        XCTAssertTrue(decoded is Recipe)
    }

    func testMalformedKnownTypeIsDropped() {
        // Right record type, missing required shared fields.
        let empty = CKRecord(recordType: Schema.RecordType.restaurant)
        let (items, profiles) = RecordDecoder.partition([empty])
        XCTAssertTrue(items.isEmpty)
        XCTAssertTrue(profiles.isEmpty)
    }

    func testContentsDecodesReactionsAlongsideItemsAndProfiles() throws {
        let itemID = CKRecord.ID(recordName: "m1")
        let profileID = CKRecord.ID(recordName: "profile-1")
        let reaction = BoardReaction(
            id: BoardReaction.recordID(for: itemID, profileID: profileID),
            itemID: itemID,
            reactedBy: CKRecord.Reference(recordID: profileID, action: .none),
            kind: .love,
            dateAdded: Date(timeIntervalSince1970: 100)
        )

        let contents = RecordDecoder.contents(from: [reaction.toRecord()])

        let decoded = try XCTUnwrap(contents.reactions.first)
        XCTAssertEqual(decoded.itemID, itemID)
        XCTAssertEqual(decoded.profileID, profileID)
        XCTAssertEqual(decoded.kind, .love)
        XCTAssertEqual(decoded.dateAdded, Date(timeIntervalSince1970: 100))
    }
}

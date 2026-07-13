import CloudKit
import XCTest
@testable import Docket

final class ItemDraftTests: XCTestCase {
    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-1"),
        action: .none
    )

    func testApplyingDraftPreservesCloudKitIdentityAndMetadata() throws {
        let dateAdded = Date(timeIntervalSince1970: 123_456)
        let fetched = try XCTUnwrap(Restaurant(record: Restaurant(
            id: CKRecord.ID(recordName: "restaurant-1"),
            title: "Before",
            addedBy: addedBy,
            dateAdded: dateAdded,
            location: "Old location"
        ).toRecord()))
        var draft = ItemDraft(item: fetched)
        draft.title = "After"
        draft.location = "New location"
        draft.cuisine = "Thai"
        draft.priceRange = .moderate

        let edited = try XCTUnwrap(draft.applying(to: fetched) as? Restaurant)

        XCTAssertEqual(edited.id, fetched.id)
        XCTAssertEqual(edited.addedBy.recordID, fetched.addedBy.recordID)
        XCTAssertEqual(edited.dateAdded, dateAdded)
        XCTAssertEqual(edited.systemFields, fetched.systemFields)
        XCTAssertEqual(edited.title, "After")
        XCTAssertEqual(edited.location, "New location")
        XCTAssertEqual(edited.cuisine, "Thai")
        XCTAssertEqual(edited.priceRange, .moderate)
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

        let edited = try XCTUnwrap(draft.applying(to: movie) as? Movie)

        XCTAssertEqual(edited.runtimeMinutes, 170)
        XCTAssertEqual(edited.releaseYear, 1995)
        XCTAssertEqual(edited.streamingService, "Max")
        XCTAssertEqual(edited.notes, "Friday night")
    }

    func testDraftBuildsNewTypedItem() throws {
        var draft = ItemDraft()
        draft.category = .bar
        draft.title = "  Trick Dog  "
        draft.location = "Mission"
        draft.barType = .cocktail
        let id = CKRecord.ID(recordName: "bar-1")
        let dateAdded = Date(timeIntervalSince1970: 456_789)

        let bar = try XCTUnwrap(
            draft.makeNew(id: id, addedBy: addedBy, dateAdded: dateAdded) as? Bar
        )

        XCTAssertEqual(bar.id, id)
        XCTAssertEqual(bar.dateAdded, dateAdded)
        XCTAssertEqual(bar.title, "Trick Dog")
        XCTAssertEqual(bar.location, "Mission")
        XCTAssertEqual(bar.barType, .cocktail)
    }
}

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
        let filter = BoardFilter(category: .movie)
        XCTAssertTrue(filter.isActive)
        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Heat", "Past Lives"])
    }

    func testStatusFilter() {
        let filter = BoardFilter(status: .wantToGo)
        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Tartine", "Past Lives"])
    }

    func testCombinedCategoryAndStatus() {
        let filter = BoardFilter(category: .movie, status: .wantToGo)
        XCTAssertEqual(filter.apply(to: items).map(\.title), ["Past Lives"])
    }

    func testNoMatches() {
        let filter = BoardFilter(category: .bar, status: .completed)
        XCTAssertTrue(filter.apply(to: items).isEmpty)
    }
}

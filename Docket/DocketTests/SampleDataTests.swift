//
//  SampleDataTests.swift
//  DocketTests
//
//  The debug seeding path: sample generation + the guarantee that deleting
//  samples never touches real items.
//

import XCTest
import CloudKit
@testable import Docket

@MainActor
final class SampleDataTests: XCTestCase {

    private let zoneID = Space.default.zoneID
    private let addedBy = CKRecord.Reference(
        recordID: CKRecord.ID(recordName: "profile-1"),
        action: .none
    )

    func testSampleItemsAreVariedAndTagged() {
        let items = SampleData.items(addedBy: addedBy, in: zoneID)

        XCTAssertGreaterThanOrEqual(items.count, 8)
        // Every supported category and every status shows up, so all board
        // states are visible while iterating on UI.
        XCTAssertEqual(Set(items.map(\.category)), Set(ItemCategory.supported))
        XCTAssertEqual(Set(items.map(\.status)), Set(ItemStatus.allCases))
        // All tagged as samples, all landing in the right zone.
        XCTAssertTrue(items.allSatisfy { SampleData.isSample($0.id) })
        XCTAssertTrue(items.allSatisfy { $0.id.zoneID == zoneID })
    }

    func testSeedAndDeleteLeavesRealItemsAlone() async {
        let suiteName = "SampleDataTestsSuite"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mock = MockSpaceService()
        let store = BoardStore(defaults: defaults) { _ in mock }

        await store.createProfile(firstName: "Jared", lastName: "R")
        let real = Movie(
            id: store.newItemID(),
            title: "Real Item",
            addedBy: store.currentProfile!.reference
        )
        await store.save(real)
        XCTAssertFalse(SampleData.isSample(real.id))

        await store.seedSampleData()
        XCTAssertGreaterThan(store.items.count, 1)

        await store.deleteSampleData()
        XCTAssertEqual(store.items.map(\.title), ["Real Item"])
    }
}

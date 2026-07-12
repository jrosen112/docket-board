//
//  SpaceTests.swift
//  DocketTests
//
//  Space identity + persistence round-trips.
//

import XCTest
import CloudKit
@testable import Docket

final class SpaceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SpaceTestsSuite"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testLoadWithNothingSavedReturnsDefaultOwnedSpace() {
        let space = SpaceStore.load(from: defaults)
        XCTAssertEqual(space, .default)
        XCTAssertTrue(space.isOwned)
    }

    func testJoinedSpaceRoundTrip() {
        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "SharedSpace", ownerName: "_ownerRecordName"),
            access: .joined
        )
        SpaceStore.save(joined, in: defaults)

        let loaded = SpaceStore.load(from: defaults)
        XCTAssertEqual(loaded, joined)
        XCTAssertFalse(loaded.isOwned)
    }

    func testOwnedAndJoinedSpacesWithSameZoneNameHaveDistinctIdentity() {
        // Two boards can share a zone NAME (every owner's default zone is
        // "SharedSpace") — identity must still differ. This is what makes
        // multiple boards with different people possible later.
        let mine = Space.default
        let girlfriends = Space(
            zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: "_gfOwner"),
            access: .joined
        )
        let brothers = Space(
            zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: "_broOwner"),
            access: .joined
        )
        XCTAssertNotEqual(mine.id, girlfriends.id)
        XCTAssertNotEqual(girlfriends.id, brothers.id)
    }
}

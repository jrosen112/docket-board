//
//  BoardStoreTests.swift
//  DocketTests
//
//  BoardStore behavior against the in-memory MockSpaceService: loading,
//  sorting, profile identity persistence, error surfacing, space switching.
//

import XCTest
import CloudKit
@testable import Docket

@MainActor
final class BoardStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var mock: MockSpaceService!
    private var store: BoardStore!
    private let suiteName = "BoardStoreTestsSuite"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        mock = MockSpaceService()
        store = makeStore()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// New store over the same defaults; reuses `mock` for owned spaces so
    /// "relaunches" see the same data.
    private func makeStore() -> BoardStore {
        let mock = self.mock!
        return BoardStore(defaults: defaults) { space in
            space == mock.space ? mock : MockSpaceService(space: space)
        }
    }

    private func seedProfile(name: String = "Alice") -> UserProfile {
        let profile = UserProfile(
            id: CKRecord.ID(recordName: "profile-\(name)", zoneID: mock.space.zoneID),
            firstName: name,
            lastName: "Nguyen"
        )
        mock.records[profile.id] = profile.toRecord()
        return profile
    }

    private func seedMovie(_ title: String, addedBy: UserProfile, dateAdded: Date) {
        let movie = Movie(
            id: CKRecord.ID(recordName: "movie-\(title)", zoneID: mock.space.zoneID),
            title: title,
            addedBy: addedBy.reference,
            dateAdded: dateAdded
        )
        mock.records[movie.id] = movie.toRecord()
    }

    // MARK: - Loading

    func testBootstrapLoadsItemsAndSetsLoadedFlag() async {
        let alice = seedProfile()
        seedMovie("Heat", addedBy: alice, dateAdded: .now)

        await store.bootstrap()

        XCTAssertTrue(store.hasLoadedOnce)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertNil(store.errorMessage)
    }

    func testItemsSortedNewestFirst() async {
        let alice = seedProfile()
        seedMovie("Older", addedBy: alice, dateAdded: Date(timeIntervalSince1970: 100))
        seedMovie("Newer", addedBy: alice, dateAdded: Date(timeIntervalSince1970: 200))

        await store.refresh()

        XCTAssertEqual(store.items.map(\.title), ["Newer", "Older"])
    }

    func testLoadErrorSurfacesAndStillFinishesBootstrap() async {
        mock.loadError = CKError(.networkFailure)

        await store.bootstrap()

        // The gate must not hang on the loading screen even when CloudKit fails.
        XCTAssertTrue(store.hasLoadedOnce)
        XCTAssertNotNil(store.errorMessage)
    }

    func testSuccessfulRefreshClearsStaleError() async {
        mock.loadError = CKError(.networkFailure)
        await store.refresh()
        XCTAssertNotNil(store.errorMessage)

        mock.loadError = nil
        await store.refresh()
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - Profile identity

    func testCreateProfilePersistsIdentityAcrossRelaunch() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        XCTAssertEqual(store.currentProfile?.firstName, "Jared")

        // Simulate relaunch: fresh store over the same defaults + data.
        let relaunched = makeStore()
        await relaunched.bootstrap()
        XCTAssertEqual(relaunched.currentProfile?.firstName, "Jared")
    }

    func testDisplayNameResolvesThroughProfiles() async {
        let alice = seedProfile()
        seedMovie("Heat", addedBy: alice, dateAdded: .now)

        await store.refresh()

        let item = store.items[0]
        XCTAssertEqual(store.displayName(for: item), "Alice Nguyen")
    }

    func testLegacyGlobalProfileKeyMigratesToDefaultSpace() async {
        let profile = seedProfile(name: "Jared")
        defaults.set(profile.id.recordName, forKey: "docket.currentProfileRecordName")

        let migrated = makeStore()
        await migrated.bootstrap()

        XCTAssertEqual(migrated.currentProfile?.firstName, "Jared")
        XCTAssertNil(defaults.string(forKey: "docket.currentProfileRecordName"))
    }

    // MARK: - Items

    func testAddAndDeleteRoundTrip() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let movie = Movie(
            id: store.newItemID(),
            title: "Past Lives",
            addedBy: store.currentProfile!.reference
        )

        await store.save(movie)
        XCTAssertEqual(store.items.map(\.title), ["Past Lives"])

        await store.delete(store.items[0])
        XCTAssertTrue(store.items.isEmpty)
    }

    func testEditingItemUpdatesInPlaceWithoutDuplicating() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let movie = Movie(
            id: store.newItemID(),
            title: "Old Title",
            addedBy: store.currentProfile!.reference
        )
        await store.save(movie)

        // Edit what came back from the "server" (has systemFields), the way
        // the edit form does.
        var loaded = store.items[0] as! Movie
        XCTAssertNotNil(loaded.systemFields)
        loaded.title = "New Title"
        loaded.status = .completed
        await store.save(loaded)

        XCTAssertEqual(store.items.count, 1, "editing must not create a second record")
        XCTAssertEqual(store.items[0].title, "New Title")
        XCTAssertEqual(store.items[0].status, .completed)
    }

    // MARK: - Space switching

    func testSwitchToJoinedSpacePersistsAndDropsOwnership() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        XCTAssertTrue(store.isOwner)

        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: "_gfOwner"),
            access: .joined
        )
        await store.switchTo(space: joined)

        XCTAssertFalse(store.isOwner)
        XCTAssertEqual(store.space, joined)
        XCTAssertNil(store.currentProfile) // fresh identity on the new board
        XCTAssertTrue(store.items.isEmpty)
        // Choice survives relaunch.
        XCTAssertEqual(SpaceStore.load(from: defaults), joined)
    }

    func testOwnedProfileSurvivesJoiningAnotherBoard() async {
        await store.createProfile(firstName: "Jared", lastName: "R")

        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: "_gfOwner"),
            access: .joined
        )
        await store.switchTo(space: joined)
        await store.switchTo(space: .default)

        // Coming back to the owned board finds the same identity — nothing was
        // wiped by joining someone else's board.
        XCTAssertEqual(store.currentProfile?.firstName, "Jared")
    }
}

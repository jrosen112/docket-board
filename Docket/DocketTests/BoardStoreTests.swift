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
    private var notificationMock: MockBoardNotificationService!
    private var store: BoardStore!
    private let suiteName = "BoardStoreTestsSuite"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        mock = MockSpaceService()
        notificationMock = MockBoardNotificationService()
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
        return BoardStore(
            defaults: defaults,
            makeService: { space in
                space == mock.space ? mock : MockSpaceService(space: space)
            },
            notificationService: notificationMock
        )
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

        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertNil(store.errorMessage)
        let prepareCount = await notificationMock.prepareCount
        XCTAssertEqual(prepareCount, 1)
    }

    func testItemsSortedNewestFirst() async {
        let alice = seedProfile()
        seedMovie("Older", addedBy: alice, dateAdded: Date(timeIntervalSince1970: 100))
        seedMovie("Newer", addedBy: alice, dateAdded: Date(timeIntervalSince1970: 200))

        await store.refresh()

        XCTAssertEqual(store.items.map(\.title), ["Newer", "Older"])
    }

    func testLoadErrorShowsRetryStateInsteadOfOnboarding() async {
        mock.loadError = CKError(.networkFailure)

        await store.bootstrap()

        guard case .failed = store.loadState else {
            return XCTFail("A failed initial read must show a retry state")
        }
        XCTAssertNil(store.currentProfile)
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

    func testCreateProfileFailureDoesNotPersistIdentity() async {
        mock.saveError = CKError(.networkFailure)

        let created = await store.createProfile(firstName: "Jared", lastName: "R")

        XCTAssertFalse(created)
        XCTAssertNil(store.currentProfile)
        XCTAssertTrue(mock.records.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }

    func testCreateProfileCanRetryAfterFailure() async {
        mock.saveError = CKError(.networkFailure)
        let firstAttempt = await store.createProfile(firstName: "Jared", lastName: "R")
        XCTAssertFalse(firstAttempt)

        mock.saveError = nil
        let created = await store.createProfile(firstName: "Jared", lastName: "R")

        XCTAssertTrue(created)
        XCTAssertEqual(store.currentProfile?.firstName, "Jared")
        XCTAssertNil(store.errorMessage)
    }

    func testDisplayNameResolvesThroughProfiles() async {
        let alice = seedProfile()
        seedMovie("Heat", addedBy: alice, dateAdded: .now)

        await store.refresh()

        let item = store.items[0]
        XCTAssertEqual(store.displayName(for: item), "Alice Nguyen")
    }

    func testCurrentUserItemCountUsesProfileReferences() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let currentProfile = store.currentProfile!
        seedMovie("Mine", addedBy: currentProfile, dateAdded: .now)

        let alice = seedProfile(name: "Alice")
        seedMovie("Hers", addedBy: alice, dateAdded: .now)
        await store.refresh()

        XCTAssertEqual(store.currentUserItemCount, 1)
        XCTAssertEqual(store.items.count, 2)
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

        let addResult = await store.save(movie)
        XCTAssertEqual(addResult, .saved)
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
        let addResult = await store.save(movie)
        XCTAssertEqual(addResult, .saved)

        // Edit what came back from the "server" (has systemFields), the way
        // the edit form does.
        var loaded = store.items[0] as! Movie
        XCTAssertNotNil(loaded.systemFields)
        loaded.title = "New Title"
        loaded.status = .completed
        let editResult = await store.save(loaded)
        XCTAssertEqual(editResult, .saved)

        XCTAssertEqual(store.items.count, 1, "editing must not create a second record")
        XCTAssertEqual(store.items[0].title, "New Title")
        XCTAssertEqual(store.items[0].status, .completed)
    }

    func testSaveFailureReturnsFailureAndLeavesBoardUnchanged() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        mock.saveError = CKError(.networkFailure)
        let movie = Movie(
            id: store.newItemID(),
            title: "Past Lives",
            addedBy: store.currentProfile!.reference
        )

        let result = await store.save(movie)

        XCTAssertEqual(result, .failed)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }

    func testConflictReturnsDistinctResult() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        mock.saveError = CKError(.serverRecordChanged)
        let movie = Movie(
            id: store.newItemID(),
            title: "Past Lives",
            addedBy: store.currentProfile!.reference
        )

        let result = await store.save(movie)

        XCTAssertEqual(result, .conflict)
        XCTAssertTrue(store.errorMessage?.contains("Someone else edited") == true)
    }

    // MARK: - Space switching

    func testCreateBoardMakesDistinctOwnedSpaceAndCopiesCurrentProfile() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let originalSpace = store.space

        let created = await store.createBoard(title: "Date Nights")

        XCTAssertTrue(created)
        XCTAssertTrue(store.isOwner)
        XCTAssertNotEqual(store.space, originalSpace)
        XCTAssertEqual(store.space.title, "Date Nights")
        XCTAssertEqual(store.currentProfile?.displayName, "Jared R")
        XCTAssertEqual(store.currentProfile?.id.zoneID, store.space.zoneID)
        XCTAssertEqual(store.spaces.count, 2)
        XCTAssertEqual(SpaceStore.load(from: defaults), store.space)
    }

    func testCreateBoardFailureKeepsCurrentBoardSelectedAndUncatalogued() async {
        let ownedService = mock!
        let failingStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                guard space == ownedService.space else {
                    let service = MockSpaceService(space: space)
                    service.saveError = CKError(.networkFailure)
                    return service
                }
                return ownedService
            },
            notificationService: notificationMock
        )
        await failingStore.createProfile(firstName: "Jared", lastName: "R")
        let originalSpace = failingStore.space

        let created = await failingStore.createBoard(title: "Won't Persist")

        XCTAssertFalse(created)
        XCTAssertEqual(failingStore.space, originalSpace)
        XCTAssertEqual(failingStore.spaces, [originalSpace])
        XCTAssertEqual(SpaceStore.load(from: defaults), originalSpace)
        XCTAssertNotNil(failingStore.errorMessage)
    }

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
        XCTAssertEqual(store.spaces.count, 2)
        XCTAssertTrue(store.spaces.contains(.default))
        XCTAssertTrue(store.spaces.contains(joined))
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

    func testSwitchKeepsBoardPresentationLoadedWhileNewSpaceLoads() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "SlowSharedSpace", ownerName: "_friendOwner"),
            access: .joined,
            title: "Slow Board"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.loadDelayNanoseconds = 100_000_000
        let ownedService = mock!
        let switchingStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == ownedService.space ? ownedService : joinedService
            },
            notificationService: notificationMock
        )
        await switchingStore.bootstrap()

        let switchTask = Task { await switchingStore.switchTo(space: joined) }
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertTrue(switchingStore.isSwitchingBoard)
        XCTAssertEqual(switchingStore.loadState, .loaded)
        XCTAssertEqual(switchingStore.space, joined)

        await switchTask.value
        XCTAssertFalse(switchingStore.isSwitchingBoard)
        XCTAssertEqual(switchingStore.loadState, .loaded)
    }

    func testFailedSwitchRestoresPreviousBoardAndItsContent() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let currentProfile = store.currentProfile!
        seedMovie("Keep Me", addedBy: currentProfile, dateAdded: .now)
        await store.refresh()

        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "UnavailableSpace", ownerName: "_friendOwner"),
            access: .joined,
            title: "Unavailable Board"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.loadError = CKError(.networkFailure)
        let ownedService = mock!
        let switchingStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == ownedService.space ? ownedService : joinedService
            },
            notificationService: notificationMock
        )
        await switchingStore.bootstrap()
        let originalSpace = switchingStore.space

        await switchingStore.switchTo(space: joined)

        XCTAssertFalse(switchingStore.isSwitchingBoard)
        XCTAssertEqual(switchingStore.space, originalSpace)
        XCTAssertEqual(switchingStore.items.map(\.title), ["Keep Me"])
        XCTAssertEqual(switchingStore.currentProfile?.id, currentProfile.id)
        XCTAssertTrue(switchingStore.spaces.contains(joined))
        XCTAssertEqual(SpaceStore.load(from: defaults), originalSpace)
        XCTAssertNotNil(switchingStore.errorMessage)
    }

    func testInFlightRefreshCannotOverwriteNewlySelectedSpace() async {
        let ownedProfile = seedProfile(name: "Owner")
        seedMovie("Old board item", addedBy: ownedProfile, dateAdded: .now)
        mock.loadDelayNanoseconds = 100_000_000

        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: Schema.zoneName, ownerName: "_friendOwner"),
            access: .joined
        )
        let joinedService = MockSpaceService(space: joined)
        let joinedProfile = UserProfile(
            id: CKRecord.ID(recordName: "profile-friend", zoneID: joined.zoneID),
            firstName: "Friend",
            lastName: ""
        )
        joinedService.records[joinedProfile.id] = joinedProfile.toRecord()
        let joinedMovie = Movie(
            id: CKRecord.ID(recordName: "joined-movie", zoneID: joined.zoneID),
            title: "New board item",
            addedBy: joinedProfile.reference
        )
        joinedService.records[joinedMovie.id] = joinedMovie.toRecord()

        let ownedService = mock!
        let switchingStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == ownedService.space ? ownedService : joinedService
            },
            notificationService: notificationMock
        )
        let oldRefresh = Task { await switchingStore.refresh() }
        try? await Task.sleep(nanoseconds: 10_000_000)

        await switchingStore.switchTo(space: joined)
        await oldRefresh.value

        XCTAssertEqual(switchingStore.space, joined)
        XCTAssertEqual(switchingStore.items.map(\.title), ["New board item"])
        XCTAssertEqual(switchingStore.loadState, .loaded)
    }

    // MARK: - Remote additions

    func testRemoteAdditionByAnotherProfilePostsBoardNotification() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let alice = seedProfile(name: "Alice")
        seedMovie("Heat", addedBy: alice, dateAdded: .now)

        let receivedData = await store.handleRemoteDatabaseChange(scope: .private)

        XCTAssertTrue(receivedData)
        let notices = await notificationMock.capturedNotices()
        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices[0].title, "My Board")
        XCTAssertEqual(notices[0].body, "Alice Nguyen added “Heat”.")
        XCTAssertEqual(store.items.map(\.title), ["Heat"])
    }

    func testRemoteAdditionByCurrentProfileDoesNotPostNotification() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        seedMovie("Mine", addedBy: store.currentProfile!, dateAdded: .now)

        let receivedData = await store.handleRemoteDatabaseChange(scope: .private)

        XCTAssertTrue(receivedData)
        let notices = await notificationMock.capturedNotices()
        XCTAssertTrue(notices.isEmpty)
    }

    func testRemoteEditDoesNotPostAdditionNotification() async {
        let alice = seedProfile(name: "Alice")
        seedMovie("Original", addedBy: alice, dateAdded: .now)
        await store.bootstrap()

        let recordID = mock.records.keys.first { $0.recordName == "movie-Original" }!
        var movie = Movie(record: mock.records[recordID]!)!
        movie.title = "Edited"
        mock.records[recordID] = movie.toRecord()

        _ = await store.handleRemoteDatabaseChange(scope: .private)

        let notices = await notificationMock.capturedNotices()
        XCTAssertTrue(notices.isEmpty)
        XCTAssertEqual(store.items.map(\.title), ["Edited"])
    }
}

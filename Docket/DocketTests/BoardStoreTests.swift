//
//  BoardStoreTests.swift
//  DocketTests
//
//  BoardStore behavior against the in-memory MockSpaceService: loading,
//  sorting, profile identity persistence, error surfacing, space switching.
//

import CloudKit
import XCTest

@testable import Docket

@MainActor
final class BoardStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var mock: MockSpaceService!
    private var notificationMock: MockBoardNotificationService!
    private var networkMock: MockNetworkAvailability!
    private var store: BoardStore!
    private let suiteName = "BoardStoreTestsSuite"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        mock = MockSpaceService()
        notificationMock = MockBoardNotificationService()
        networkMock = MockNetworkAvailability()
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
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
    }

    private func seedProfile(name: String = "Alice") -> UserProfile {
        let profile = UserProfile(
            id: CKRecord.ID(recordName: "profile-\(name)", zoneID: mock.space.zoneID),
            firstName: name,
            lastName: "Nguyen"
        )
        mock.records[profile.id] = profile.toRecord()
        mock.profileCreatorRecordNames[profile.id] = mock.accountUserID.recordName
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

    private func makeTransferFixture() -> (
        store: BoardStore,
        sourceProfile: UserProfile,
        destination: Space,
        destinationService: MockSpaceService,
        destinationProfile: UserProfile
    ) {
        let sourceProfile = seedProfile()
        let destination = Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-transfer",
                ownerName: "partner"
            ),
            access: .joined,
            title: "Date Nights"
        )
        let destinationService = MockSpaceService(space: destination)
        destinationService.accountUserID = mock.accountUserID
        let destinationProfile = UserProfile(
            id: CKRecord.ID(recordName: "profile-destination", zoneID: destination.zoneID),
            firstName: "Alice",
            lastName: "Nguyen",
            accountRecordName: mock.accountUserID.recordName
        )
        destinationService.records[destinationProfile.id] = destinationProfile.toRecord()
        destinationService.profileCreatorRecordNames[destinationProfile.id] =
            mock.accountUserID.recordName
        SpaceStore.replace(
            with: [.default, destination],
            selected: .default,
            in: defaults
        )
        let sourceService = mock!
        let transferStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == destination ? destinationService : sourceService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        return (
            transferStore,
            sourceProfile,
            destination,
            destinationService,
            destinationProfile
        )
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

    func testSingleBoardReinstallAutomaticallyReclaimsExistingProfile() async {
        let profile = seedProfile()

        await store.bootstrap()

        XCTAssertEqual(store.currentProfile?.id, profile.id)
        XCTAssertEqual(
            UserProfile(record: mock.records[profile.id]!)?.accountRecordName,
            mock.accountUserID.recordName
        )
        XCTAssertEqual(
            defaults.string(forKey: store.profileKey),
            profile.id.recordName
        )
    }

    func testForegroundRefreshReconcilesChangesMissedByPush() async {
        let alice = seedProfile()
        await store.bootstrap()
        seedMovie("Arrived While Backgrounded", addedBy: alice, dateAdded: .now)

        await store.applicationBecameActive()

        XCTAssertEqual(store.items.map(\.title), ["Arrived While Backgrounded"])
    }

    func testForegroundRetriesNotificationPreparationAfterTransientFailure() async {
        await notificationMock.setPrepareError(CKError(.serviceUnavailable))
        await store.bootstrap()
        let failedPrepareCount = await notificationMock.prepareCount
        XCTAssertEqual(failedPrepareCount, 1)

        await notificationMock.setPrepareError(nil)
        await store.applicationBecameActive()

        let recoveredPrepareCount = await notificationMock.prepareCount
        XCTAssertEqual(recoveredPrepareCount, 2)
    }

    func testAccountChangeClearsPriorAccountsRememberedProfile() async {
        await store.bootstrap()
        await store.createProfile(firstName: "Jared", lastName: "R")
        XCTAssertNotNil(store.currentProfile)

        mock.accountUserID = CKRecord.ID(recordName: "different-icloud-user")
        await store.handleICloudAccountChange()

        XCTAssertNil(store.currentProfile)
        XCTAssertEqual(store.spaces, [.default])
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

    func testRefreshSummaryReportsNewItemCount() async {
        let alice = seedProfile()
        seedMovie("Already Here", addedBy: alice, dateAdded: .now)
        await store.bootstrap()
        seedMovie("Just Added", addedBy: alice, dateAdded: .now)

        let summary = await store.refresh()

        XCTAssertEqual(summary, BoardRefreshSummary(addedItemCount: 1))
        XCTAssertEqual(summary?.message, "1 item added")
    }

    func testRefreshSummaryReportsNoNewItems() async {
        let alice = seedProfile()
        seedMovie("Already Here", addedBy: alice, dateAdded: .now)
        await store.bootstrap()

        let summary = await store.refresh()

        XCTAssertEqual(summary, BoardRefreshSummary(addedItemCount: 0))
        XCTAssertEqual(summary?.message, "No new items")
    }

    func testFailedRefreshDoesNotProduceSuccessSummary() async {
        mock.loadError = CKError(.networkFailure)

        let summary = await store.refresh()

        XCTAssertNil(summary)
    }

    func testOfflineRefreshFinishesWithFriendlyError() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        await networkMock.set(.unavailable)

        let summary = await store.refresh()

        XCTAssertNil(summary)
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(
            store.errorMessage,
            "You're offline. Reconnect and try again."
        )
    }

    // MARK: - Reactions

    func testReactionCanBeAddedReplacedAndRemoved() async throws {
        let alice = seedProfile()
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        await store.bootstrap()
        let movie = try XCTUnwrap(store.items.first)

        await store.setReaction(.love, for: movie)

        let reactionID = BoardReaction.recordID(for: movie.id, profileID: alice.id)
        XCTAssertEqual(store.currentReaction(for: movie), .love)
        XCTAssertEqual(
            store.reactionGroups(for: movie),
            [
                BoardReactionGroup(kind: .love, count: 1, includesCurrentUser: true)
            ])
        XCTAssertNotNil(mock.records[reactionID])

        await store.setReaction(.laugh, for: movie)

        XCTAssertEqual(store.currentReaction(for: movie), .laugh)
        XCTAssertEqual(
            mock.records.values.filter {
                $0.recordType == Schema.RecordType.boardReaction
            }.count,
            1
        )
        XCTAssertEqual(
            BoardReaction(record: try XCTUnwrap(mock.records[reactionID]))?.kind,
            .laugh
        )

        await store.setReaction(.laugh, for: movie)

        XCTAssertNil(store.currentReaction(for: movie))
        XCTAssertTrue(store.reactionGroups(for: movie).isEmpty)
        XCTAssertNil(mock.records[reactionID])
    }

    /// Standard tapbacks read in picker order regardless of when they were
    /// used; emoji from the grid have no such order to fall back on, so they
    /// follow in the order they first appeared on the item.
    func testCustomEmojiFollowStandardKindsInGroups() async throws {
        let alice = seedProfile(name: "Alice")
        let jordan = seedProfile(name: "Jordan")
        mock.profileCreatorRecordNames[jordan.id] = "jordan-icloud-user"
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        let itemID = CKRecord.ID(recordName: "movie-Heat", zoneID: mock.space.zoneID)
        let pizza = try XCTUnwrap(BoardReactionKind(rawValue: "🍕"))

        // The custom reaction is the older of the two.
        let jordanReaction = BoardReaction(
            id: BoardReaction.recordID(for: itemID, profileID: jordan.id),
            itemID: itemID,
            reactedBy: jordan.reference,
            kind: pizza,
            dateAdded: Date(timeIntervalSince1970: 0)
        )
        let aliceReaction = BoardReaction(
            id: BoardReaction.recordID(for: itemID, profileID: alice.id),
            itemID: itemID,
            reactedBy: alice.reference,
            kind: .love,
            dateAdded: Date(timeIntervalSince1970: 100)
        )
        mock.records[jordanReaction.id] = jordanReaction.toRecord()
        mock.records[aliceReaction.id] = aliceReaction.toRecord()
        await store.bootstrap()
        let movie = try XCTUnwrap(store.items.first)

        XCTAssertEqual(
            store.reactionGroups(for: movie).map(\.kind),
            [.love, pizza]
        )
        XCTAssertEqual(store.currentReaction(for: movie), .love)
    }

    /// A grid emoji has to survive the round trip through CloudKit the same way
    /// a built-in one does — the field was always a string.
    func testCustomEmojiReactionRoundTripsThroughCloudKit() async throws {
        let alice = seedProfile()
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        await store.bootstrap()
        let movie = try XCTUnwrap(store.items.first)
        let taco = try XCTUnwrap(BoardReactionKind(rawValue: "🌮"))

        await store.setReaction(taco, for: movie)

        let reactionID = BoardReaction.recordID(for: movie.id, profileID: alice.id)
        XCTAssertEqual(
            BoardReaction(record: try XCTUnwrap(mock.records[reactionID]))?.kind,
            taco
        )
        XCTAssertEqual(store.currentReaction(for: movie), taco)
    }

    func testReactionAttributionsGroupPeopleByTapback() async throws {
        let alice = seedProfile(name: "Alice")
        let jordan = seedProfile(name: "Jordan")
        mock.profileCreatorRecordNames[jordan.id] = "jordan-icloud-user"
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        let itemID = CKRecord.ID(recordName: "movie-Heat", zoneID: mock.space.zoneID)
        // Explicit dates: people are ordered by when they reacted, and two
        // defaulted `.now` timestamps can tie, leaving the order to come from
        // dictionary iteration instead.
        let aliceReaction = BoardReaction(
            id: BoardReaction.recordID(for: itemID, profileID: alice.id),
            itemID: itemID,
            reactedBy: alice.reference,
            kind: .like,
            dateAdded: Date(timeIntervalSince1970: 100)
        )
        let jordanReaction = BoardReaction(
            id: BoardReaction.recordID(for: itemID, profileID: jordan.id),
            itemID: itemID,
            reactedBy: jordan.reference,
            kind: .like,
            dateAdded: Date(timeIntervalSince1970: 200)
        )
        mock.records[aliceReaction.id] = aliceReaction.toRecord()
        mock.records[jordanReaction.id] = jordanReaction.toRecord()
        await store.bootstrap()
        let movie = try XCTUnwrap(store.items.first)

        XCTAssertEqual(
            store.reactionAttributions(for: movie),
            [
                BoardReactionAttribution(
                    kind: .like,
                    people: [
                        BoardReactionPerson(
                            profileID: alice.id,
                            displayName: "Alice Nguyen",
                            initials: "AN"
                        ),
                        BoardReactionPerson(
                            profileID: jordan.id,
                            displayName: "Jordan Nguyen",
                            initials: "JN"
                        ),
                    ]
                )
            ])
    }

    func testRefreshSummaryPluralizesMultipleItems() {
        XCTAssertEqual(
            BoardRefreshSummary(addedItemCount: 2).message,
            "2 items added"
        )
    }

    // MARK: - Profile identity

    func testRestoreFromICloudReclaimsExistingProfileWithoutCreatingDuplicate() async {
        let profile = seedProfile()
        // Private-database system metadata aliases its owner rather than
        // exposing the opaque account record name returned by userRecordID().
        mock.profileCreatorRecordNames[profile.id] = CKCurrentUserDefaultName
        await store.bootstrap()
        XCTAssertEqual(store.currentProfile?.id, profile.id)
        let recordCountBeforeRestore = mock.records.count

        let result = await store.restoreFromICloud()

        XCTAssertEqual(result, .restored(boardCount: 1))
        XCTAssertEqual(store.currentProfile?.id, profile.id)
        XCTAssertEqual(mock.records.count, recordCountBeforeRestore)
    }

    func testRestoreFromICloudReportsNotFoundForAnotherUsersProfile() async {
        let profile = seedProfile()
        mock.profileCreatorRecordNames[profile.id] = "someone-else"
        await store.bootstrap()

        let result = await store.restoreFromICloud()

        XCTAssertEqual(result, .notFound)
        XCTAssertNil(store.currentProfile)
    }

    func testSharedProfileRecognizesCurrentUserAliasDuringLegacyMigration() {
        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "LegacyShared", ownerName: "partner"),
            access: .joined,
            title: "Together"
        )
        let profile = UserProfile(
            id: CKRecord.ID(recordName: "legacy-me", zoneID: joined.zoneID),
            firstName: "Alice",
            lastName: "Nguyen",
            creatorUserRecordName: CKCurrentUserDefaultName
        )

        XCTAssertTrue(
            BoardStore.profileBelongsToCurrentAccount(
                profile,
                in: joined,
                userRecordName: mock.accountUserID.recordName
            )
        )
    }

    func testStaleRememberedProfileCannotAdoptAnotherExplicitAccount() async {
        let mine = UserProfile(
            id: CKRecord.ID(recordName: "profile-mine", zoneID: mock.space.zoneID),
            firstName: "Alice",
            lastName: "Nguyen",
            accountRecordName: mock.accountUserID.recordName
        )
        let someoneElse = UserProfile(
            id: CKRecord.ID(recordName: "profile-someone-else", zoneID: mock.space.zoneID),
            firstName: "Jordan",
            lastName: "Lee",
            accountRecordName: "different-icloud-account"
        )
        mock.records[mine.id] = mine.toRecord()
        mock.records[someoneElse.id] = someoneElse.toRecord()
        mock.profileCreatorRecordNames[mine.id] = mock.accountUserID.recordName
        mock.profileCreatorRecordNames[someoneElse.id] = "different-icloud-account"
        defaults.set(someoneElse.id.recordName, forKey: store.profileKey)

        await store.bootstrap()

        XCTAssertEqual(store.currentProfile?.id, mine.id)
        XCTAssertNotNil(mock.records[someoneElse.id])
        XCTAssertEqual(
            UserProfile(record: mock.records[someoneElse.id]!)?.accountRecordName,
            "different-icloud-account"
        )
    }

    func testBootstrapMergesDuplicateProfileAndRewritesItsItems() async throws {
        let canonical = UserProfile(
            id: CKRecord.ID(recordName: "profile-current", zoneID: mock.space.zoneID),
            firstName: "Alice",
            lastName: "Nguyen",
            accountRecordName: mock.accountUserID.recordName
        )
        let legacyDuplicate = UserProfile(
            id: CKRecord.ID(recordName: "profile-pre-reinstall", zoneID: mock.space.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        let legacyMovie = Movie(
            id: CKRecord.ID(recordName: "movie-from-old-profile", zoneID: mock.space.zoneID),
            title: "Heat",
            addedBy: legacyDuplicate.reference
        )
        let legacyReaction = BoardReaction(
            id: BoardReaction.recordID(
                for: legacyMovie.id,
                profileID: legacyDuplicate.id
            ),
            itemID: legacyMovie.id,
            reactedBy: legacyDuplicate.reference,
            kind: .love
        )
        mock.records[canonical.id] = canonical.toRecord()
        mock.records[legacyDuplicate.id] = legacyDuplicate.toRecord()
        mock.records[legacyMovie.id] = legacyMovie.toRecord()
        mock.records[legacyReaction.id] = legacyReaction.toRecord()
        mock.profileCreatorRecordNames[canonical.id] = mock.accountUserID.recordName
        mock.profileCreatorRecordNames[legacyDuplicate.id] = CKCurrentUserDefaultName
        defaults.set(canonical.id.recordName, forKey: store.profileKey)

        await store.bootstrap()

        XCTAssertEqual(store.profiles.map(\.id), [canonical.id])
        XCTAssertEqual(store.currentProfile?.id, canonical.id)
        XCTAssertNil(mock.records[legacyDuplicate.id])
        let repairedRecord = try XCTUnwrap(mock.records[legacyMovie.id])
        let repairedReference = try XCTUnwrap(
            repairedRecord[Schema.Field.addedBy] as? CKRecord.Reference
        )
        XCTAssertEqual(repairedReference.recordID, canonical.id)
        XCTAssertEqual(store.items.first?.addedBy.recordID, canonical.id)
        XCTAssertEqual(store.reactions.first?.profileID, canonical.id)
        XCTAssertEqual(store.reactions.first?.kind, .love)
        XCTAssertNil(mock.records[legacyReaction.id])
        XCTAssertNotNil(
            mock.records[
                BoardReaction.recordID(
                    for: legacyMovie.id,
                    profileID: canonical.id
                )
            ]
        )
    }

    func testRestoreRepairsDuplicatesOnBoardsThatAreNotSelected() async throws {
        _ = seedProfile()
        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "RepairEveryBoard", ownerName: "partner"),
            access: .joined,
            title: "Together"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.accountUserID = mock.accountUserID
        let canonical = UserProfile(
            id: CKRecord.ID(recordName: "profile-a", zoneID: joined.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        let duplicate = UserProfile(
            id: CKRecord.ID(recordName: "profile-b", zoneID: joined.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        let movie = Movie(
            id: CKRecord.ID(recordName: "joined-old-pin", zoneID: joined.zoneID),
            title: "Heat",
            addedBy: duplicate.reference
        )
        joinedService.records[canonical.id] = canonical.toRecord()
        joinedService.records[duplicate.id] = duplicate.toRecord()
        joinedService.records[movie.id] = movie.toRecord()
        joinedService.profileCreatorRecordNames[canonical.id] = mock.accountUserID.recordName
        joinedService.profileCreatorRecordNames[duplicate.id] = CKCurrentUserDefaultName
        mock.discoveredSpaces = [.default, joined]
        let defaultService = mock!
        let restoringStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == joined ? joinedService : defaultService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        await restoringStore.bootstrap()

        _ = await restoringStore.restoreFromICloud()

        XCTAssertEqual(restoringStore.space, .default)
        XCTAssertNotNil(joinedService.records[canonical.id])
        XCTAssertNil(joinedService.records[duplicate.id])
        let repairedMovie = try XCTUnwrap(joinedService.records[movie.id])
        let reference = try XCTUnwrap(
            repairedMovie[Schema.Field.addedBy] as? CKRecord.Reference
        )
        XCTAssertEqual(reference.recordID, canonical.id)
    }

    func testRestoreFromICloudRebuildsMultipleBoardCatalog() async {
        let defaultProfile = seedProfile()
        let joined = Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-joined",
                ownerName: "partner"
            ),
            access: .joined,
            title: "Date Nights"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.accountUserID = mock.accountUserID
        let joinedProfile = UserProfile(
            id: CKRecord.ID(recordName: "profile-me-joined", zoneID: joined.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        joinedService.records[joinedProfile.id] = joinedProfile.toRecord()
        joinedService.profileCreatorRecordNames[joinedProfile.id] = mock.accountUserID.recordName
        mock.discoveredSpaces = [.default, joined]
        let defaultService = mock!

        let restoringStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == joined ? joinedService : defaultService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        await restoringStore.bootstrap()

        let result = await restoringStore.restoreFromICloud()

        XCTAssertEqual(result, .restored(boardCount: 2))
        XCTAssertEqual(restoringStore.currentProfile?.id, defaultProfile.id)
        XCTAssertEqual(Set(restoringStore.spaces.map(\.id)), Set([Space.default.id, joined.id]))

        await restoringStore.switchTo(space: joined)
        XCTAssertEqual(restoringStore.currentProfile?.id, joinedProfile.id)
    }

    func testRestoreKeepsDiscoveredBoardWhenItsLoadFailsTransiently() async {
        let defaultProfile = seedProfile()
        mock.profileCreatorRecordNames[defaultProfile.id] = CKCurrentUserDefaultName
        let unavailable = Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-temporarily-unavailable",
                ownerName: "partner"
            ),
            access: .joined,
            title: "Still Mine"
        )
        let unavailableService = MockSpaceService(space: unavailable)
        unavailableService.loadError = CKError(.serviceUnavailable)
        mock.discoveredSpaces = [.default, unavailable]
        let defaultService = mock!
        let restoringStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == unavailable ? unavailableService : defaultService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        await restoringStore.bootstrap()

        let result = await restoringStore.restoreFromICloud()

        XCTAssertEqual(result, .restored(boardCount: 1))
        XCTAssertTrue(restoringStore.spaces.contains(unavailable))

        let recoveredProfile = UserProfile(
            id: CKRecord.ID(recordName: "profile-recovered", zoneID: unavailable.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        unavailableService.records[recoveredProfile.id] = recoveredProfile.toRecord()
        unavailableService.profileCreatorRecordNames[recoveredProfile.id] =
            mock.accountUserID.recordName
        unavailableService.loadError = nil

        await restoringStore.applicationBecameActive()
        await restoringStore.switchTo(space: unavailable)

        XCTAssertEqual(restoringStore.currentProfile?.id, recoveredProfile.id)
    }

    func testNameUpdatePropagatesProfilesAcrossBoardsWithoutRewritingItems() async throws {
        let defaultProfile = seedProfile()
        seedMovie("Default Pin", addedBy: defaultProfile, dateAdded: .now)
        let defaultMovieID = try XCTUnwrap(
            mock.records.values.first { $0.recordType == Schema.RecordType.movie }?.recordID
        )
        let originalDefaultMovie = try XCTUnwrap(mock.records[defaultMovieID])
        let originalDefaultReference = try XCTUnwrap(
            originalDefaultMovie[Schema.Field.addedBy] as? CKRecord.Reference
        )

        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "DocketBoard-rename", ownerName: "partner"),
            access: .joined,
            title: "Together"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.accountUserID = mock.accountUserID
        let joinedProfile = UserProfile(
            id: CKRecord.ID(recordName: "profile-me-rename", zoneID: joined.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        joinedService.records[joinedProfile.id] = joinedProfile.toRecord()
        joinedService.profileCreatorRecordNames[joinedProfile.id] = mock.accountUserID.recordName
        let joinedMovie = Movie(
            id: CKRecord.ID(recordName: "joined-pin", zoneID: joined.zoneID),
            title: "Joined Pin",
            addedBy: joinedProfile.reference
        )
        joinedService.records[joinedMovie.id] = joinedMovie.toRecord()
        mock.discoveredSpaces = [.default, joined]
        let defaultService = mock!
        let renamingStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == joined ? joinedService : defaultService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        await renamingStore.bootstrap()
        _ = await renamingStore.restoreFromICloud()
        let recordCounts = (mock.records.count, joinedService.records.count)

        let result = await renamingStore.updateCurrentUserName(
            firstName: "Alicia",
            lastName: "Stone"
        )

        XCTAssertEqual(result, .updated(boardCount: 2))
        XCTAssertEqual(UserProfile(record: try XCTUnwrap(mock.records[defaultProfile.id]))?.displayName, "Alicia Stone")
        XCTAssertEqual(
            UserProfile(record: try XCTUnwrap(joinedService.records[joinedProfile.id]))?.displayName, "Alicia Stone")
        XCTAssertEqual(mock.records.count, recordCounts.0)
        XCTAssertEqual(joinedService.records.count, recordCounts.1)
        let updatedDefaultMovie = try XCTUnwrap(mock.records[defaultMovieID])
        let updatedDefaultReference = try XCTUnwrap(
            updatedDefaultMovie[Schema.Field.addedBy] as? CKRecord.Reference
        )
        XCTAssertEqual(updatedDefaultReference.recordID, originalDefaultReference.recordID)
    }

    func testProfileStatsAggregateOnlyCurrentUsersItemsAcrossBoards() async {
        let defaultProfile = seedProfile()
        let defaultMovieOne = Movie(
            id: CKRecord.ID(recordName: "mine-1", zoneID: mock.space.zoneID),
            title: "Mine One",
            status: .planned,
            addedBy: defaultProfile.reference
        )
        let defaultMovieTwo = Movie(
            id: CKRecord.ID(recordName: "mine-2", zoneID: mock.space.zoneID),
            title: "Mine Two",
            status: .wantToGo,
            addedBy: defaultProfile.reference
        )
        mock.records[defaultMovieOne.id] = defaultMovieOne.toRecord()
        mock.records[defaultMovieTwo.id] = defaultMovieTwo.toRecord()
        let otherProfile = seedProfile(name: "Other")
        mock.profileCreatorRecordNames[otherProfile.id] = "someone-else"
        seedMovie("Not Mine", addedBy: otherProfile, dateAdded: .now)

        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "DocketBoard-stats", ownerName: "partner"),
            access: .joined,
            title: "Date Nights"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.accountUserID = mock.accountUserID
        let joinedProfile = UserProfile(
            id: CKRecord.ID(recordName: "profile-me-stats", zoneID: joined.zoneID),
            firstName: "Alice",
            lastName: "Nguyen"
        )
        joinedService.records[joinedProfile.id] = joinedProfile.toRecord()
        joinedService.profileCreatorRecordNames[joinedProfile.id] = mock.accountUserID.recordName
        let joinedRestaurant = Restaurant(
            id: CKRecord.ID(recordName: "mine-restaurant", zoneID: joined.zoneID),
            title: "Dinner",
            status: .completed,
            addedBy: joinedProfile.reference
        )
        joinedService.records[joinedRestaurant.id] = joinedRestaurant.toRecord()
        mock.discoveredSpaces = [.default, joined]
        let defaultService = mock!
        let statsStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == joined ? joinedService : defaultService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        await statsStore.bootstrap()
        _ = await statsStore.restoreFromICloud()

        let result = await statsStore.loadProfileStats()

        guard case .loaded(let stats) = result else {
            return XCTFail("Expected profile stats")
        }
        XCTAssertEqual(stats.boardCount, 2)
        XCTAssertEqual(stats.loadedBoardCount, 2)
        XCTAssertEqual(stats.itemCount, 3)
        XCTAssertEqual(stats.wantToGoCount, 1)
        XCTAssertEqual(stats.plannedCount, 1)
        XCTAssertEqual(stats.completedCount, 1)
        XCTAssertEqual(stats.favoriteCategory, .movie)
        XCTAssertEqual(stats.boards.map(\.itemCount).reduce(0, +), 3)
    }

    func testProfileStatsIncludeItemsFromEverySameAccountProfile() async {
        await store.createProfile(firstName: "Alice", lastName: "Nguyen")
        let canonical = store.currentProfile!
        seedMovie("Current Profile Pin", addedBy: canonical, dateAdded: .now)
        let duplicate = UserProfile(
            id: CKRecord.ID(recordName: "same-account-duplicate", zoneID: mock.space.zoneID),
            firstName: "Alice",
            lastName: "Nguyen",
            accountRecordName: mock.accountUserID.recordName
        )
        mock.records[duplicate.id] = duplicate.toRecord()
        mock.profileCreatorRecordNames[duplicate.id] = mock.accountUserID.recordName
        seedMovie("Old Profile Pin", addedBy: duplicate, dateAdded: .now)

        let result = await store.loadProfileStats()

        guard case .loaded(let stats) = result else {
            return XCTFail("Expected profile stats")
        }
        XCTAssertEqual(stats.itemCount, 2)
    }

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

    func testRefreshMissingProfileRecordDoesNotSignOutUser() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let profileID = store.currentProfile!.id

        // A fetch can transiently omit the remembered profile record (e.g.
        // eventual consistency right after the save). That must not blank
        // `currentProfile` and bounce a signed-in user back to onboarding.
        mock.records.removeValue(forKey: profileID)
        await store.refresh()

        XCTAssertEqual(store.currentProfile?.id, profileID)
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
        mock.profileCreatorRecordNames[alice.id] = "alice-icloud-user"
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

        let deleteResult = await store.delete(store.items[0])
        XCTAssertEqual(deleteResult, .deleted)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDeleteFailureKeepsItemAndReturnsMessage() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let movie = Movie(
            id: store.newItemID(),
            title: "Past Lives",
            addedBy: store.currentProfile!.reference
        )
        let saveResult = await store.save(movie)
        XCTAssertEqual(saveResult, .saved)
        mock.deleteError = CKError(.networkFailure)

        let result = await store.delete(store.items[0])

        guard case .failed(let message) = result else {
            return XCTFail("Expected delete to fail")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(store.items.map(\.title), ["Past Lives"])
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

        guard case .failed(let message) = result else {
            return XCTFail("Expected .failed, got \(result)")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
        // The edit surface shows the failure inline; the shared board banner
        // must stay clear so it doesn't linger after the sheet is dismissed.
        XCTAssertNil(store.errorMessage)
    }

    func testSuccessfulSaveAppearsLocallyWhenConfirmingRefreshFails() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        mock.loadErrorAfterSave = CKError(.networkFailure)
        let movie = Movie(
            id: store.newItemID(),
            title: "Saved Once",
            addedBy: store.currentProfile!.reference
        )

        let result = await store.save(movie)

        XCTAssertEqual(result, .saved)
        XCTAssertEqual(store.items.map(\.title), ["Saved Once"])
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

        guard case .conflict(let message) = result else {
            return XCTFail("Expected .conflict, got \(result)")
        }
        XCTAssertTrue(message.contains("Someone else edited"))
        XCTAssertNil(store.errorMessage)
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
            notificationService: notificationMock,
            networkAvailability: networkMock
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
        XCTAssertEqual(store.currentProfile?.displayName, "Jared R")
        XCTAssertEqual(store.currentProfile?.id.zoneID, joined.zoneID)
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

    func testColdLaunchInviteWaitsForBootstrapAndJoinConfirmation() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let ownedService = mock!
        let joined = Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-cold-invite",
                ownerName: "partner"
            ),
            access: .joined,
            title: "Together"
        )
        let joinedService = MockSpaceService(space: joined)
        joinedService.accountUserID = mock.accountUserID
        let coldLaunchStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == joined ? joinedService : ownedService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )

        await coldLaunchStore.openAcceptedShare(joined, inviterName: "Alex")
        XCTAssertEqual(coldLaunchStore.space, .default)
        XCTAssertNil(coldLaunchStore.boardInvitation)

        await coldLaunchStore.bootstrap()

        XCTAssertEqual(coldLaunchStore.space, .default)
        XCTAssertEqual(
            coldLaunchStore.boardInvitation,
            BoardInvitation(space: joined, inviterName: "Alex")
        )
        XCTAssertTrue(coldLaunchStore.spaces.contains(joined))
        XCTAssertTrue(joinedService.records.isEmpty)

        await coldLaunchStore.joinPendingBoardInvitation()

        XCTAssertEqual(coldLaunchStore.space, joined)
        XCTAssertEqual(coldLaunchStore.currentProfile?.displayName, "Jared R")
        XCTAssertEqual(joinedService.records.values.count, 1)
        XCTAssertNil(coldLaunchStore.boardInvitation)
    }

    func testNotNowKeepsAcceptedBoardWithoutChangingSelection() async {
        await store.bootstrap()
        await store.createProfile(firstName: "Jared", lastName: "R")
        let originalSpace = store.space
        let joined = Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-later-invite",
                ownerName: "partner"
            ),
            access: .joined,
            title: "Watch List"
        )

        await store.openAcceptedShare(joined, inviterName: "Alex")
        store.dismissBoardInvitation()

        XCTAssertNil(store.boardInvitation)
        XCTAssertEqual(store.space, originalSpace)
        XCTAssertEqual(SpaceStore.load(from: defaults), originalSpace)
        XCTAssertTrue(store.spaces.contains(joined))
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
            notificationService: notificationMock,
            networkAvailability: networkMock
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
            notificationService: notificationMock,
            networkAvailability: networkMock
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

    func testSwitchingToCurrentFailedBoardRetriesItsLoad() async {
        mock.loadError = CKError(.serviceUnavailable)
        await store.bootstrap()
        guard case .failed = store.loadState else {
            return XCTFail("Expected the initial load to fail")
        }

        mock.loadError = nil
        await store.switchTo(space: .default)

        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertNil(store.errorMessage)
    }

    func testOfflineSwitchImmediatelyRestoresPreviousBoard() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let originalSpace = store.space
        let joined = Space(
            zoneID: CKRecordZone.ID(zoneName: "OfflineSpace", ownerName: "_friendOwner"),
            access: .joined,
            title: "Offline Board"
        )
        await networkMock.set(.unavailable)

        await store.switchTo(space: joined)

        XCTAssertFalse(store.isSwitchingBoard)
        XCTAssertEqual(store.space, originalSpace)
        XCTAssertEqual(SpaceStore.load(from: defaults), originalSpace)
        XCTAssertEqual(
            store.errorMessage,
            "You're offline. Reconnect and try again."
        )
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
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        let oldRefresh = Task { await switchingStore.refresh() }
        try? await Task.sleep(nanoseconds: 10_000_000)

        await switchingStore.switchTo(space: joined)
        _ = await oldRefresh.value

        XCTAssertEqual(switchingStore.space, joined)
        XCTAssertEqual(switchingStore.items.map(\.title), ["New board item"])
        XCTAssertEqual(switchingStore.loadState, .loaded)
    }

    func testColdLaunchNotificationSwitchesBoardAndRequestsExactItem() async {
        let owned = Space.default
        let joined = Space(
            zoneID: CKRecordZone.ID(
                zoneName: "DocketBoard-notification",
                ownerName: "partner"
            ),
            access: .joined,
            title: "Together"
        )
        SpaceStore.replace(with: [owned, joined], selected: owned, in: defaults)

        let ownedService = MockSpaceService(space: owned)
        let joinedService = MockSpaceService(space: joined)
        let author = UserProfile(
            id: CKRecord.ID(recordName: "profile-partner", zoneID: joined.zoneID),
            firstName: "Alex",
            lastName: "Stone"
        )
        let movie = Movie(
            id: CKRecord.ID(recordName: "movie-notification", zoneID: joined.zoneID),
            title: "Heat",
            addedBy: author.reference
        )
        joinedService.records[author.id] = author.toRecord()
        joinedService.records[movie.id] = movie.toRecord()

        let deepLinkStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == joined ? joinedService : ownedService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        let link = BoardDeepLink(
            spaceID: joined.id,
            itemRecordName: movie.id.recordName
        )

        await deepLinkStore.openDeepLink(link)
        XCTAssertNil(deepLinkStore.itemNavigationRequest)

        await deepLinkStore.bootstrap()

        XCTAssertEqual(deepLinkStore.space, joined)
        XCTAssertEqual(deepLinkStore.itemNavigationRequest?.recordID, movie.id)
        let requestID = deepLinkStore.itemNavigationRequest!.id
        deepLinkStore.consumeItemNavigationRequest(requestID)
        XCTAssertNil(deepLinkStore.itemNavigationRequest)
    }

    func testDeletingCurrentOwnedBoardMovesToFallbackAndDeletesZone() async {
        let fallback = Space.default
        let deletable = Space.newOwned(
            title: "Old Board",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        )
        SpaceStore.replace(with: [fallback, deletable], selected: deletable, in: defaults)
        let fallbackService = MockSpaceService(space: fallback)
        let deletableService = MockSpaceService(space: deletable)
        let deletingStore = BoardStore(
            defaults: defaults,
            makeService: { space in
                space == deletable ? deletableService : fallbackService
            },
            notificationService: notificationMock,
            networkAvailability: networkMock
        )
        await deletingStore.bootstrap()

        let deleted = await deletingStore.deleteBoard(deletable)

        XCTAssertTrue(deleted)
        XCTAssertTrue(deletableService.didDeleteBoardZone)
        XCTAssertEqual(deletingStore.space, fallback)
        XCTAssertEqual(deletingStore.spaces, [fallback])
        XCTAssertEqual(SpaceStore.load(from: defaults), fallback)
    }

    func testBoardManagementSnapshotsIncludePinsAndParticipantNames() async {
        let alice = seedProfile(name: "Alice")
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        await store.bootstrap()

        let snapshots = await store.loadBoardManagementSnapshots()

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].space, .default)
        XCTAssertEqual(snapshots[0].itemCount, 1)
        XCTAssertEqual(snapshots[0].participantCount, 1)
        XCTAssertEqual(snapshots[0].participantNames, ["Alice Nguyen"])
        XCTAssertEqual(snapshots[0].latestUpdate?.title, "Heat")
        XCTAssertEqual(snapshots[0].latestUpdate?.category, .movie)
        XCTAssertEqual(snapshots[0].latestUpdate?.authorName, "Alice Nguyen")
        XCTAssertTrue(snapshots[0].isAvailable)
    }

    func testBoardManagementLatestUpdateIsNewestItem() async {
        let alice = seedProfile(name: "Alice")
        for (index, title) in ["Heat", "Ronin", "Thief", "Alien"].enumerated() {
            seedMovie(
                title,
                addedBy: alice,
                dateAdded: .now.addingTimeInterval(TimeInterval(index))
            )
        }
        await store.bootstrap()

        let snapshots = await store.loadBoardManagementSnapshots()

        XCTAssertEqual(snapshots[0].itemCount, 4)
        XCTAssertEqual(snapshots[0].latestUpdate?.title, "Alien")
    }

    func testBoardManagementUsesShareRosterInsteadOfProfileRecordCount() async {
        let alice = seedProfile(name: "Alice")
        let staleProfile = seedProfile(name: "Old Copy")
        mock.profileCreatorRecordNames[staleProfile.id] = "departed-user"
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        mock.participantRoster = BoardParticipantRoster(
            participantCount: 2,
            participantNames: ["Alice Nguyen", "Jared Rosen"]
        )
        await store.bootstrap()

        let snapshots = await store.loadBoardManagementSnapshots()

        XCTAssertEqual(snapshots[0].participantCount, 2)
        XCTAssertEqual(
            snapshots[0].participantNames,
            ["Alice Nguyen", "Jared Rosen"]
        )
    }

    func testBoardManagementKeepsBoardAvailableWhenRosterFetchFails() async {
        let alice = seedProfile(name: "Alice")
        seedMovie("Heat", addedBy: alice, dateAdded: .now)
        mock.participantRosterError = CKError(.serviceUnavailable)
        await store.bootstrap()

        let snapshots = await store.loadBoardManagementSnapshots()

        XCTAssertTrue(snapshots[0].isAvailable)
        XCTAssertEqual(snapshots[0].itemCount, 1)
        XCTAssertEqual(snapshots[0].participantCount, 1)
    }

    // MARK: - Remote additions

    func testRemoteAdditionByAnotherProfilePostsBoardNotification() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let alice = seedProfile(name: "Alice")
        mock.profileCreatorRecordNames[alice.id] = "alice-icloud-user"
        seedMovie("Heat", addedBy: alice, dateAdded: .now)

        let receivedData = await store.handleRemoteDatabaseChange(scope: .private)

        XCTAssertTrue(receivedData)
        let notices = await notificationMock.capturedNotices()
        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices[0].title, "New on My Board")
        XCTAssertEqual(notices[0].body, "Alice Nguyen pinned “Heat” · Movie")
        XCTAssertEqual(notices[0].itemRecordName, "movie-Heat")
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

    func testRemoteAdditionByDuplicateSameAccountProfileDoesNotNotifySelf() async {
        await store.createProfile(firstName: "Jared", lastName: "R")
        let duplicate = UserProfile(
            id: CKRecord.ID(recordName: "my-other-device-profile", zoneID: mock.space.zoneID),
            firstName: "Jared",
            lastName: "R",
            accountRecordName: mock.accountUserID.recordName
        )
        mock.records[duplicate.id] = duplicate.toRecord()
        mock.profileCreatorRecordNames[duplicate.id] = mock.accountUserID.recordName
        seedMovie("From My Other Device", addedBy: duplicate, dateAdded: .now)

        let receivedData = await store.handleRemoteDatabaseChange(scope: .private)

        XCTAssertTrue(receivedData)
        let notices = await notificationMock.capturedNotices()
        XCTAssertTrue(notices.isEmpty)
    }

    func testRemoteEditPostsItemAwareUpdateNotification() async {
        let alice = seedProfile(name: "Alice")
        seedMovie("Original", addedBy: alice, dateAdded: .now)
        await store.bootstrap()

        let recordID = mock.records.keys.first { $0.recordName == "movie-Original" }!
        var movie = Movie(record: mock.records[recordID]!)!
        movie.title = "Edited"
        mock.records[recordID] = movie.toRecord()

        _ = await store.handleRemoteDatabaseChange(scope: .private)

        let notices = await notificationMock.capturedNotices()
        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices[0].title, "Updated on My Board")
        XCTAssertEqual(notices[0].body, "“Edited” has new details.")
        XCTAssertEqual(notices[0].itemRecordName, recordID.recordName)
        XCTAssertEqual(store.items.map(\.title), ["Edited"])
    }

    func testRemoteProfileRenameRefreshesAttributionWithoutPostingNotification() async {
        await store.createProfile(firstName: "Alice", lastName: "Nguyen")
        var renamed = store.currentProfile!
        renamed.firstName = "Alicia"
        renamed.lastName = "Stone"
        mock.records[renamed.id] = renamed.toRecord()

        let receivedData = await store.handleRemoteDatabaseChange(scope: .private)

        XCTAssertTrue(receivedData)
        XCTAssertEqual(store.currentProfile?.displayName, "Alicia Stone")
        let notices = await notificationMock.capturedNotices()
        XCTAssertTrue(notices.isEmpty)
    }

    // MARK: - Duplicate and move

    func testDuplicateCopiesCompleteItemToDestinationAndKeepsSource() async throws {
        let fixture = makeTransferFixture()
        let recipe = Recipe(
            id: CKRecord.ID(recordName: "source-recipe", zoneID: mock.space.zoneID),
            title: "Gochujang Chicken",
            notes: "Double the sauce",
            status: .planned,
            addedBy: fixture.sourceProfile.reference,
            dateAdded: Date(timeIntervalSince1970: 100),
            photoData: Data([0x01]),
            showsPhotoOnBoard: true,
            boardPhotoPosition: BoardPhotoPosition(x: 0.3, y: 0.8),
            sourceURL: "https://example.com/recipe",
            cuisines: ["Korean", "American"],
            ingredients: ["Chicken", "Gochujang"],
            instructions: ["Roast"],
            additionalPhotoData: [Data([0x02])]
        )
        mock.records[recipe.id] = recipe.toRecord()
        await fixture.store.bootstrap()
        let destinationID = fixture.store.newItemID(in: fixture.destination)

        let result = await fixture.store.transfer(
            recipe,
            to: fixture.destination,
            kind: .duplicate,
            destinationRecordID: destinationID
        )

        XCTAssertEqual(result, .duplicated)
        XCTAssertNotNil(mock.records[recipe.id])
        let copiedRecord = try XCTUnwrap(fixture.destinationService.records[destinationID])
        let copied = try XCTUnwrap(Recipe(record: copiedRecord))
        XCTAssertEqual(copied.title, recipe.title)
        XCTAssertEqual(copied.notes, recipe.notes)
        XCTAssertEqual(copied.status, recipe.status)
        XCTAssertEqual(copied.cuisines, recipe.cuisines)
        XCTAssertEqual(copied.ingredients, recipe.ingredients)
        XCTAssertEqual(copied.instructions, recipe.instructions)
        XCTAssertEqual(copied.allPhotoData, recipe.allPhotoData)
        XCTAssertEqual(copied.boardPhotoPosition, recipe.boardPhotoPosition)
        XCTAssertEqual(copied.addedBy.recordID, fixture.destinationProfile.id)
        XCTAssertGreaterThan(copied.dateAdded, recipe.dateAdded)
    }

    func testMoveCopiesFirstThenRemovesSourceFromCurrentBoard() async throws {
        let fixture = makeTransferFixture()
        let restaurant = Restaurant(
            id: CKRecord.ID(recordName: "source-restaurant", zoneID: mock.space.zoneID),
            title: "Souvla",
            status: .wantToGo,
            addedBy: fixture.sourceProfile.reference,
            cuisines: ["Greek"],
            priceRange: .moderate
        )
        mock.records[restaurant.id] = restaurant.toRecord()
        await fixture.store.bootstrap()
        let destinationID = fixture.store.newItemID(in: fixture.destination)

        let result = await fixture.store.transfer(
            restaurant,
            to: fixture.destination,
            kind: .move,
            destinationRecordID: destinationID
        )

        XCTAssertEqual(result, .moved)
        XCTAssertNil(mock.records[restaurant.id])
        XCTAssertFalse(fixture.store.items.contains { $0.id == restaurant.id })
        let copied = try XCTUnwrap(
            Restaurant(record: try XCTUnwrap(fixture.destinationService.records[destinationID]))
        )
        XCTAssertEqual(copied.title, restaurant.title)
        XCTAssertEqual(copied.cuisines, restaurant.cuisines)
    }

    func testFailedDestinationCopyLeavesSourceUntouched() async {
        let fixture = makeTransferFixture()
        let movie = Movie(
            id: CKRecord.ID(recordName: "source-movie", zoneID: mock.space.zoneID),
            title: "Heat",
            addedBy: fixture.sourceProfile.reference
        )
        mock.records[movie.id] = movie.toRecord()
        await fixture.store.bootstrap()
        fixture.destinationService.saveError = CKError(.networkFailure)

        let result = await fixture.store.transfer(
            movie,
            to: fixture.destination,
            kind: .move,
            destinationRecordID: fixture.store.newItemID(in: fixture.destination)
        )

        guard case .failed = result else { return XCTFail("Expected failed copy") }
        XCTAssertNotNil(mock.records[movie.id])
        XCTAssertTrue(fixture.store.items.contains { $0.id == movie.id })
    }

    func testPartialMoveCanRetryOnlySourceRemovalWithoutDuplicating() async {
        let fixture = makeTransferFixture()
        let bar = Bar(
            id: CKRecord.ID(recordName: "source-bar", zoneID: mock.space.zoneID),
            title: "Trick Dog",
            addedBy: fixture.sourceProfile.reference,
            barType: .cocktail
        )
        mock.records[bar.id] = bar.toRecord()
        await fixture.store.bootstrap()
        mock.deleteError = CKError(.networkFailure)
        let destinationID = fixture.store.newItemID(in: fixture.destination)

        let firstResult = await fixture.store.transfer(
            bar,
            to: fixture.destination,
            kind: .move,
            destinationRecordID: destinationID
        )

        guard case .copiedButSourceKept = firstResult else {
            return XCTFail("Expected a completed copy with source retained")
        }
        XCTAssertNotNil(mock.records[bar.id])
        XCTAssertNotNil(fixture.destinationService.records[destinationID])
        let destinationItemCount = RecordDecoder.partition(
            Array(fixture.destinationService.records.values)
        ).items.count

        mock.deleteError = nil
        let retryResult = await fixture.store.finishMove(bar, from: .default)

        XCTAssertEqual(retryResult, .moved)
        XCTAssertNil(mock.records[bar.id])
        XCTAssertEqual(
            RecordDecoder.partition(Array(fixture.destinationService.records.values)).items.count,
            destinationItemCount
        )
    }
}

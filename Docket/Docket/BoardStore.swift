//
//  BoardStore.swift
//  Docket
//
//  The main-actor, observable layer the UI watches. Wraps a SpaceDataService
//  and holds the currently-loaded items, the participants' profiles, and who
//  "I" am. Views stay dumb: they read these properties and call these methods.
//
//  The service and UserDefaults are injected (with real-CloudKit defaults) so
//  every behavior here is unit-testable with an in-memory mock.
//

import CloudKit
import Observation

nonisolated enum BoardLoadState: Equatable {
    case loading
    case loaded
    case failed(message: String)
}

nonisolated enum StoreSaveResult: Equatable {
    case saved
    case conflict(message: String)
    case failed(message: String)
}

nonisolated enum ICloudRestoreResult: Equatable {
    case restored(boardCount: Int)
    case notFound
    case failed(message: String)
}

nonisolated struct BoardRefreshSummary: Equatable, Sendable {
    let addedItemCount: Int

    var message: String {
        switch addedItemCount {
        case 0: "No new items"
        case 1: "1 item added"
        default: "\(addedItemCount) items added"
        }
    }
}

@MainActor
@Observable
final class BoardStore {

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let makeService: @Sendable (Space) -> any SpaceDataService
    @ObservationIgnored private let notificationService: any BoardNotificationService
    @ObservationIgnored private let networkAvailability: any NetworkAvailabilityProviding
    private var service: any SpaceDataService

    /// The board (space) this store is currently pointed at.
    private(set) var space: Space
    /// Every owned or accepted board available to the switcher.
    private(set) var spaces: [Space]
    /// True when this device owns the current board (can invite others).
    var isOwner: Bool { space.isOwned }

    /// Every item currently on the board, newest first.
    var items: [any SharedListItem] = []
    /// All participants' profiles on this board, for displaying `addedBy`.
    var profiles: [UserProfile] = []
    /// Whichever profile belongs to this device's user on this board.
    var currentProfile: UserProfile?
    /// Number of board items created by the profile selected on this device.
    var currentUserItemCount: Int {
        guard let currentProfile else { return 0 }
        return items.count {
            $0.addedBy.recordID.recordName == currentProfile.id.recordName
        }
    }

    var isLoading = false
    /// True only while replacing the current board with another space. Views
    /// use this to keep their chrome mounted and skeletonize the card region.
    private(set) var isSwitchingBoard = false
    var errorMessage: String?
    /// Initial loading is distinct from onboarding. A failed CloudKit read must
    /// never look like a brand-new user with no profile.
    var loadState: BoardLoadState = .loading

    /// Monotonically increasing token for refreshes. Main-actor methods can be
    /// re-entered while awaiting CloudKit, so only the newest request may
    /// publish results.
    @ObservationIgnored private var refreshGeneration = 0

    /// The container, exposed for UICloudSharingController.
    var container: CKContainer { service.container }
    /// A share prepared and waiting to be presented in the share sheet.
    var activeShare: CKShare?

    init(
        defaults: UserDefaults = .standard,
        makeService: @escaping @Sendable (Space) -> any SpaceDataService = { CloudKitService(space: $0) },
        notificationService: any BoardNotificationService = CloudKitBoardNotificationService(),
        networkAvailability: any NetworkAvailabilityProviding = SystemNetworkAvailability.shared
    ) {
        let space = SpaceStore.load(from: defaults)
        self.defaults = defaults
        self.makeService = makeService
        self.notificationService = notificationService
        self.networkAvailability = networkAvailability
        self.space = space
        self.spaces = SpaceStore.loadAll(from: defaults)
        self.service = makeService(space)
        migrateLegacyProfileKey()
    }

    // MARK: - "Who am I" persistence (per space)

    /// Which profile record is "me" is local state, and it's per-board: the
    /// same person can have different profiles on different boards.
    private var profileKey: String { profileKey(for: space) }

    private func profileKey(for space: Space) -> String {
        "docket.currentProfileRecordName.\(space.id)"
    }

    /// Pre-Space builds stored the profile record name under a single global
    /// key. Carry it over to the default owned space so existing test devices
    /// don't re-prompt for a name (and create a duplicate profile).
    private func migrateLegacyProfileKey() {
        let legacyKey = "docket.currentProfileRecordName"
        if let legacy = defaults.string(forKey: legacyKey) {
            let defaultSpaceKey = "docket.currentProfileRecordName.\(Space.default.id)"
            if defaults.string(forKey: defaultSpaceKey) == nil {
                defaults.set(legacy, forKey: defaultSpaceKey)
            }
            defaults.removeObject(forKey: legacyKey)
        }
    }

    /// Re-resolves `currentProfile` from the locally-remembered record name.
    private func reconcileCurrentProfile() {
        guard let name = defaults.string(forKey: profileKey) else {
            currentProfile = nil
            return
        }
        // A fetch can transiently omit the remembered record (e.g. a refresh
        // racing the profile save it follows). Never downgrade an already-set
        // profile to nil, or a signed-in user gets bounced back to onboarding.
        if let match = profiles.first(where: { $0.id.recordName == name }) {
            currentProfile = match
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        await loadForPresentation()
        try? await notificationService.prepare()
    }

    private func loadForPresentation() async {
        loadState = .loading
        switch await performRefresh() {
        case .loaded:
            loadState = .loaded
        case .failed(let message):
            loadState = .failed(message: message)
        case .superseded:
            break
        }
    }

    @discardableResult
    func refresh() async -> BoardRefreshSummary? {
        let previousIDs = Set(items.map(\.id))
        switch await performRefresh() {
        case .loaded:
            let addedItemCount = items.count { !previousIDs.contains($0.id) }
            return BoardRefreshSummary(addedItemCount: addedItemCount)
        case .failed, .superseded:
            return nil
        }
    }

    private enum RefreshResult {
        case loaded
        case failed(String)
        case superseded
    }

    private func performRefresh() async -> RefreshResult {
        refreshGeneration += 1
        let generation = refreshGeneration
        let requestedService = service
        isLoading = true
        do {
            try await requireNetwork()
            let loaded = try await requestedService.loadEverything()
            guard generation == refreshGeneration else { return .superseded }
            items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = loaded.profiles
            reconcileCurrentProfile()
            remember(items: loaded.items, in: space)
            errorMessage = nil
            isLoading = false
            return .loaded
        } catch {
            guard generation == refreshGeneration else { return .superseded }
            let message = Self.message(for: error)
            errorMessage = message
            isLoading = false
            return .failed(message)
        }
    }

    // MARK: - Profile

    /// Reclaims this iCloud user's profiles and board memberships on a new
    /// device. Profile ownership comes from CloudKit's creator metadata; no
    /// names are guessed and no duplicate profile records are created.
    func restoreFromICloud() async -> ICloudRestoreResult {
        errorMessage = nil
        isLoading = true

        do {
            try await requireNetwork()
            let userRecordName = (try await service.accountUserRecordID()).recordName
            let discovered = try await service.discoverSpaces()
            let candidates = discovered.map { discoveredSpace in
                spaces.first(where: { $0.id == discoveredSpace.id }) ?? discoveredSpace
            }

            var restored: [(
                space: Space,
                service: any SpaceDataService,
                items: [any SharedListItem],
                profiles: [UserProfile],
                profile: UserProfile
            )] = []
            var firstLoadError: Error?

            for candidate in candidates {
                let candidateService = makeService(candidate)
                do {
                    let loaded = try await candidateService.loadEverything()
                    guard let profile = loaded.profiles.first(where: {
                        Self.profileBelongsToCurrentAccount(
                            $0,
                            in: candidate,
                            userRecordName: userRecordName
                        )
                    }) else { continue }
                    restored.append((
                        candidate,
                        candidateService,
                        loaded.items,
                        loaded.profiles,
                        profile
                    ))
                } catch {
                    if firstLoadError == nil { firstLoadError = error }
                }
            }

            guard !restored.isEmpty else {
                isLoading = false
                if let firstLoadError {
                    let message = Self.message(for: firstLoadError)
                    errorMessage = message
                    return .failed(message: message)
                }
                return .notFound
            }

            let selected = restored.first(where: { $0.space.id == space.id }) ?? restored[0]
            let restoredSpaces = restored.map(\.space)
            SpaceStore.replace(with: restoredSpaces, selected: selected.space, in: defaults)
            for board in restored {
                defaults.set(
                    board.profile.id.recordName,
                    forKey: profileKey(for: board.space)
                )
                remember(items: board.items, in: board.space)
            }

            refreshGeneration += 1
            space = selected.space
            spaces = SpaceStore.loadAll(from: defaults)
            service = selected.service
            items = selected.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = selected.profiles
            currentProfile = selected.profile
            activeShare = nil
            errorMessage = nil
            isLoading = false
            loadState = .loaded
            return .restored(boardCount: restored.count)
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            isLoading = false
            return .failed(message: message)
        }
    }

    /// CloudKit aliases the owner of a private database to
    /// `CKCurrentUserDefaultName` in record system metadata. Shared databases
    /// do not get that fallback because their default owner is another person.
    private static func profileBelongsToCurrentAccount(
        _ profile: UserProfile,
        in space: Space,
        userRecordName: String
    ) -> Bool {
        guard let creator = profile.creatorUserRecordName else { return false }
        if creator == userRecordName { return true }
        return space.isOwned && creator == CKCurrentUserDefaultName
    }

    @discardableResult
    func createProfile(firstName: String, lastName: String) async -> Bool {
        errorMessage = nil
        let profile = UserProfile(
            id: service.newRecordID(),
            firstName: firstName,
            lastName: lastName
        )
        do {
            try await requireNetwork()
            try await service.save(profile.toRecord())
            defaults.set(profile.id.recordName, forKey: profileKey)
            currentProfile = profile
            await refresh()
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    // MARK: - Items

    /// A fresh record ID in this space's zone, for building a new item.
    func newItemID() -> CKRecord.ID { service.newRecordID() }

    /// Saves a new or edited item. Edited items carry their CloudKit change
    /// tag (systemFields), so concurrent-edit conflicts surface as errors
    /// rather than silently clobbering the other person's change.
    ///
    /// Failures ride back in the result rather than `errorMessage` so the
    /// board-level save pill can morph into a retry action without also
    /// leaving a second, unrelated error banner behind.
    @discardableResult
    func save(_ item: any SharedListItem) async -> StoreSaveResult {
        do {
            try await requireNetwork()
            try await service.save(item.toRecord())
            await refresh()
            return .saved
        } catch {
            if Self.isConflict(error) {
                return .conflict(
                    message: "Someone else edited this item. Reload the board to see their version, then try your edit again."
                )
            }
            return .failed(message: Self.message(for: error))
        }
    }

    func delete(_ item: any SharedListItem) async {
        do {
            try await requireNetwork()
            try await service.delete(item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Display name for whoever added an item.
    func displayName(for item: any SharedListItem) -> String {
        profiles.first { $0.id.recordName == item.addedBy.recordID.recordName }?.displayName ?? "—"
    }

    // MARK: - Sharing

    func prepareShare() async {
        do {
            try await requireNetwork()
            activeShare = try await service.loadShare()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Board creation

    /// Creates a distinct private record zone and copies this person's profile
    /// into it before switching. The current board remains visible if any
    /// CloudKit step fails, so creation never strands the user in a half-built
    /// board.
    @discardableResult
    func createBoard(title: String) async -> Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, let existingProfile = currentProfile else {
            return false
        }

        errorMessage = nil
        isLoading = true
        let newSpace = Space.newOwned(title: cleanedTitle)
        let newService = makeService(newSpace)
        let newProfile = UserProfile(
            id: newService.newRecordID(),
            firstName: existingProfile.firstName,
            lastName: existingProfile.lastName
        )

        do {
            try await requireNetwork()
            // The first load creates the custom zone. Saving the copied profile
            // then makes the board immediately usable when it becomes current.
            _ = try await newService.loadEverything()
            try await newService.save(newProfile.toRecord())
            let loaded = try await newService.loadEverything()

            refreshGeneration += 1
            SpaceStore.save(newSpace, in: defaults)
            spaces = SpaceStore.loadAll(from: defaults)
            space = newSpace
            service = newService
            defaults.set(newProfile.id.recordName, forKey: profileKey(for: newSpace))
            items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = loaded.profiles
            reconcileCurrentProfile()
            remember(items: loaded.items, in: newSpace)
            activeShare = nil
            errorMessage = nil
            isLoading = false
            loadState = .loaded
            return true
        } catch {
            errorMessage = Self.message(for: error)
            isLoading = false
            return false
        }
    }

    // MARK: - Debug seeding (compiled out of Release/TestFlight)

    #if DEBUG
    /// Populates the board with SampleData so UI iteration doesn't require
    /// re-entering items by hand. Saved once, then a single refresh.
    func seedSampleData() async {
        guard let me = currentProfile else { return }
        do {
            try await requireNetwork()
            for item in SampleData.items(addedBy: me.reference, in: service.space.zoneID) {
                try await service.save(item.toRecord())
            }
            await refresh()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Removes ONLY seeded records (sample- ID prefix); real items untouched.
    func deleteSampleData() async {
        let samples = items.filter { SampleData.isSample($0.id) }
        do {
            try await requireNetwork()
            for item in samples {
                try await service.delete(item.id)
            }
            await refresh()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }
    #endif

    /// Adds an accepted board to the catalog, selects it, and reloads. Existing
    /// memberships and their per-board profiles remain available to switch
    /// back to at any time.
    func switchTo(space newSpace: Space) async {
        SpaceStore.save(newSpace, in: defaults)
        spaces = SpaceStore.loadAll(from: defaults)
        let selectedSpace = spaces.first(where: { $0.id == newSpace.id }) ?? newSpace
        guard selectedSpace != space else {
            space = selectedSpace
            return
        }

        let previousSpace = space
        let previousService = service
        let previousItems = items
        let previousProfiles = profiles
        let previousProfile = currentProfile
        let previousShare = activeShare
        let previousLoadState = loadState

        // Invalidate any in-flight read before changing services.
        refreshGeneration += 1
        isSwitchingBoard = true
        space = selectedSpace
        service = makeService(selectedSpace)
        items = []
        profiles = []
        currentProfile = nil
        activeShare = nil

        let result = await performRefresh()
        // A newer switch owns the presentation state if the selected space
        // changed while this CloudKit request was suspended.
        guard space == selectedSpace else { return }
        isSwitchingBoard = false

        switch result {
        case .loaded:
            loadState = .loaded
        case .failed:
            // A failed switch must not strand the app with the new service and
            // the old board's profile. Restore the fully-consistent board that
            // was visible before the request; the failed board stays cataloged
            // so the user can retry it later.
            space = previousSpace
            service = previousService
            items = previousItems
            profiles = previousProfiles
            currentProfile = previousProfile
            activeShare = previousShare
            loadState = previousLoadState
            SpaceStore.save(previousSpace, in: defaults)
            spaces = SpaceStore.loadAll(from: defaults)
        case .superseded:
            break
        }
    }

    // MARK: - Remote board changes

    /// Handles a silent CloudKit database notification. A push is only a hint
    /// that something changed, so each matching board is fetched and compared
    /// with its persisted item IDs. Only newly-created records belonging to a
    /// different profile become visible notifications.
    func handleRemoteDatabaseChange(scope: CKDatabase.Scope) async -> Bool {
        let matchingSpaces = spaces.filter { candidate in
            switch scope {
            case .private: candidate.isOwned
            case .shared: !candidate.isOwned
            default: false
            }
        }
        guard !matchingSpaces.isEmpty else { return false }

        var receivedData = false
        for candidate in matchingSpaces {
            do {
                let loaded = try await makeService(candidate).loadEverything()
                let previousIDs = rememberedItemIDs(in: candidate)
                let currentIDs = Set(loaded.items.map { $0.id.recordName })
                remember(itemIDs: currentIDs, in: candidate)
                // A database push means the server observed a change. Even an
                // edit can leave the set of IDs untouched while still giving
                // us fresh data to publish.
                receivedData = true

                if let previousIDs {
                    let newItems = loaded.items.filter {
                        !previousIDs.contains($0.id.recordName)
                    }
                    let myProfileID = defaults.string(forKey: profileKey(for: candidate))
                    let additionsByOthers = newItems.filter {
                        $0.addedBy.recordID.recordName != myProfileID
                    }
                    if !additionsByOthers.isEmpty {
                        try? await notificationService.post(
                            notice(
                                for: additionsByOthers,
                                profiles: loaded.profiles,
                                in: candidate
                            )
                        )
                    }
                }

                if candidate == space {
                    publishRemoteLoad(loaded)
                }
            } catch {
                // A push-triggered fetch failing is invisible work the user
                // never asked for; don't surface a banner over valid data.
                // The data on screen simply stays as it was.
                continue
            }
        }
        return receivedData
    }

    private func publishRemoteLoad(
        _ loaded: (items: [any SharedListItem], profiles: [UserProfile])
    ) {
        // Supersede any in-flight refresh: it started before this push-driven
        // fetch, so letting it publish would overwrite newer data with older.
        refreshGeneration += 1
        items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
        profiles = loaded.profiles
        reconcileCurrentProfile()
        errorMessage = nil
        loadState = .loaded
    }

    private func notice(
        for newItems: [any SharedListItem],
        profiles: [UserProfile],
        in space: Space
    ) -> BoardChangeNotice {
        let body: String
        if newItems.count == 1, let item = newItems.first {
            let author = profiles.first {
                $0.id.recordName == item.addedBy.recordID.recordName
            }?.displayName
            if let author, !author.isEmpty {
                body = "\(author) added “\(item.title)”."
            } else {
                body = "Someone added “\(item.title)”."
            }
        } else {
            body = "\(newItems.count) new items were added."
        }
        return BoardChangeNotice(boardID: space.id, title: space.title, body: body)
    }

    private func rememberedItemIDs(in space: Space) -> Set<String>? {
        let key = rememberedItemsKey(for: space)
        guard defaults.object(forKey: key) != nil else { return nil }
        return Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func remember(items: [any SharedListItem], in space: Space) {
        remember(itemIDs: Set(items.map { $0.id.recordName }), in: space)
    }

    private func remember(itemIDs: Set<String>, in space: Space) {
        defaults.set(itemIDs.sorted(), forKey: rememberedItemsKey(for: space))
    }

    private func rememberedItemsKey(for space: Space) -> String {
        "docket.knownItemRecordNames.\(space.id)"
    }

    // MARK: - Error presentation

    private func requireNetwork() async throws {
        if await networkAvailability.availability() == .unavailable {
            throw BoardConnectivityError.offline
        }
    }

    private static func isConflict(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .serverRecordChanged { return true }
        guard cloudError.code == .partialFailure,
              let partial = cloudError.partialErrorsByItemID
        else { return false }
        return partial.values.contains { isConflict($0) }
    }

    private static func message(for error: Error) -> String {
        UserFacingError.message(for: error)
    }
}

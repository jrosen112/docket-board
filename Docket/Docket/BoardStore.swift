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

nonisolated struct BoardProfileStats: Identifiable, Equatable {
    let id: String
    let title: String
    let itemCount: Int
}

nonisolated struct ProfileStats: Equatable {
    let boardCount: Int
    let loadedBoardCount: Int
    let itemCount: Int
    let wantToGoCount: Int
    let plannedCount: Int
    let completedCount: Int
    let favoriteCategory: ItemCategory?
    let boards: [BoardProfileStats]

    var unavailableBoardCount: Int { boardCount - loadedBoardCount }
}

nonisolated enum ProfileStatsLoadResult: Equatable {
    case loaded(ProfileStats)
    case failed(message: String)
}

nonisolated enum ProfileNameUpdateResult: Equatable {
    case updated(boardCount: Int)
    case partiallyUpdated(updatedBoardCount: Int, failedBoardTitles: [String])
    case failed(message: String)
}

nonisolated struct BoardInvitation: Identifiable, Equatable, Sendable {
    let space: Space
    let inviterName: String?

    var id: String { space.id }
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

    private static let accountRecordNameKey = "docket.iCloudAccountRecordName.v1"
    private static let profileTemplateFirstNameKey = "docket.profileTemplate.firstName.v1"
    private static let profileTemplateLastNameKey = "docket.profileTemplate.lastName.v1"
    @ObservationIgnored private var isBootstrapping = false
    @ObservationIgnored private var didBootstrap = false
    @ObservationIgnored private var isReconcilingLifecycle = false
    @ObservationIgnored private var notificationsPrepared = false
    @ObservationIgnored private var needsMembershipRecovery = false
    @ObservationIgnored private var pendingAcceptedInvitation: BoardInvitation?

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
    var shareAcceptanceErrorMessage: String?
    /// An accepted CloudKit invitation waiting for the user to choose whether
    /// to open it now. The membership remains in the board switcher if they
    /// choose Not Now.
    private(set) var boardInvitation: BoardInvitation?
    private(set) var isJoiningBoardInvitation = false
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

    private struct ProfileNameTemplate {
        let firstName: String
        let lastName: String
    }

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
            rememberProfileTemplate(match)
        }
    }

    private func rememberProfileTemplate(_ profile: UserProfile) {
        defaults.set(profile.firstName, forKey: Self.profileTemplateFirstNameKey)
        defaults.set(profile.lastName, forKey: Self.profileTemplateLastNameKey)
    }

    private func rememberedProfileTemplate() -> ProfileNameTemplate? {
        guard let firstName = defaults.string(forKey: Self.profileTemplateFirstNameKey),
              !firstName.isEmpty
        else { return nil }
        return ProfileNameTemplate(
            firstName: firstName,
            lastName: defaults.string(forKey: Self.profileTemplateLastNameKey) ?? ""
        )
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !isBootstrapping else { return }
        isBootstrapping = true

        switch await reconcileAccountIdentity() {
        case .changed:
            resetLocalStateForNewAccount()
            await loadForPresentation()
            _ = await restoreFromICloud()
        case .signedOut(let message):
            presentSignedOutState(message: message)
        case .unchanged, .indeterminate:
            await loadForPresentation()
        }
        if loadState == .loaded,
           currentProfile == nil,
           (pendingAcceptedInvitation != nil || spaces.count > 1) {
            _ = await restoreFromICloud()
        }
        await prepareNotificationsIfNeeded()
        isBootstrapping = false
        didBootstrap = true
        presentPendingBoardInvitationIfNeeded()
    }

    /// Refreshes on every foreground transition because CloudKit pushes are
    /// coalesced hints, not a guaranteed change log. This also retries a share
    /// whose zone was still being prepared and notification setup that failed
    /// during a previous launch.
    func applicationBecameActive() async {
        guard didBootstrap, !isBootstrapping else { return }
        await reconcileLifecycle()
    }

    /// Called for `CKAccountChanged`. The same reconciliation also runs when
    /// the app foregrounds, covering account changes that happened while the
    /// process was suspended or terminated.
    func handleICloudAccountChange() async {
        guard didBootstrap, !isBootstrapping else { return }
        await reconcileLifecycle()
    }

    private func reconcileLifecycle() async {
        guard !isReconcilingLifecycle else { return }
        isReconcilingLifecycle = true
        defer { isReconcilingLifecycle = false }

        switch await reconcileAccountIdentity() {
        case .changed:
            notificationsPrepared = false
            needsMembershipRecovery = true
            resetLocalStateForNewAccount()
            await loadForPresentation()
            _ = await restoreFromICloud()
        case .signedOut(let message):
            notificationsPrepared = false
            presentSignedOutState(message: message)
        case .unchanged, .indeterminate:
            if needsMembershipRecovery {
                _ = await restoreFromICloud()
            } else {
                _ = await refresh()
            }
            presentPendingBoardInvitationIfNeeded()
        }
        await prepareNotificationsIfNeeded()
    }

    private enum AccountIdentityResult {
        case unchanged
        case changed
        case signedOut(message: String)
        case indeterminate
    }

    private func reconcileAccountIdentity() async -> AccountIdentityResult {
        do {
            let currentRecordName = try await service.accountUserRecordID().recordName
            let previousRecordName = defaults.string(forKey: Self.accountRecordNameKey)
            defaults.set(currentRecordName, forKey: Self.accountRecordNameKey)
            guard let previousRecordName else { return .unchanged }
            return previousRecordName == currentRecordName ? .unchanged : .changed
        } catch let error as CKError where error.code == .notAuthenticated {
            return .signedOut(message: Self.message(for: error))
        } catch {
            // Network and temporary account failures must not erase cached
            // identity. The normal refresh path will surface a useful error and
            // a later foreground transition will try the identity check again.
            return .indeterminate
        }
    }

    private func resetLocalStateForNewAccount() {
        refreshGeneration += 1
        for key in defaults.dictionaryRepresentation().keys where
            key.hasPrefix("docket.currentProfileRecordName.")
                || key.hasPrefix("docket.knownItemRecordNames.")
                || key.hasPrefix("docket.profileTemplate.") {
            defaults.removeObject(forKey: key)
        }
        SpaceStore.replace(with: [.default], selected: .default, in: defaults)
        space = .default
        spaces = SpaceStore.loadAll(from: defaults)
        service = makeService(.default)
        items = []
        profiles = []
        currentProfile = nil
        activeShare = nil
        pendingAcceptedInvitation = nil
        boardInvitation = nil
        isJoiningBoardInvitation = false
        shareAcceptanceErrorMessage = nil
        errorMessage = nil
        isLoading = false
        isSwitchingBoard = false
        loadState = .loading
    }

    private func presentSignedOutState(message: String) {
        refreshGeneration += 1
        items = []
        profiles = []
        currentProfile = nil
        activeShare = nil
        errorMessage = message
        isLoading = false
        isSwitchingBoard = false
        loadState = .failed(message: message)
    }

    private func prepareNotificationsIfNeeded() async {
        guard !notificationsPrepared else { return }
        do {
            try await notificationService.prepare()
            notificationsPrepared = true
        } catch {
            // Sync remains usable through foreground and manual refreshes. Keep
            // this false so the next foreground transition retries setup.
        }
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
                    needsMembershipRecovery = true
                    let message = Self.message(for: firstLoadError)
                    errorMessage = message
                    return .failed(message: message)
                }
                needsMembershipRecovery = false
                return .notFound
            }

            let selected = restored.first(where: { $0.space.id == space.id }) ?? restored[0]
            // Discovery succeeded for every candidate even if loading one of
            // those zones failed transiently. Keep all discovered memberships
            // so one flaky board never disappears from the local switcher.
            SpaceStore.replace(with: candidates, selected: selected.space, in: defaults)
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
            rememberProfileTemplate(selected.profile)
            activeShare = nil
            errorMessage = nil
            isLoading = false
            loadState = .loaded
            needsMembershipRecovery = firstLoadError != nil
            return .restored(boardCount: restored.count)
        } catch {
            needsMembershipRecovery = true
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

    /// Aggregates only items whose `addedBy` reference points at this user's
    /// profile on that board. No records are mutated while calculating stats.
    func loadProfileStats() async -> ProfileStatsLoadResult {
        do {
            try await requireNetwork()
            let userRecordName = (try await service.accountUserRecordID()).recordName
            var loadedBoardCount = 0
            var itemCount = 0
            var wantToGoCount = 0
            var plannedCount = 0
            var completedCount = 0
            var categoryCounts: [ItemCategory: Int] = [:]
            var boardStats: [BoardProfileStats] = []

            for candidate in spaces {
                do {
                    let loaded = try await makeService(candidate).loadEverything()
                    guard let profile = profileForCurrentAccount(
                        in: loaded.profiles,
                        space: candidate,
                        userRecordName: userRecordName
                    ) else { continue }

                    loadedBoardCount += 1
                    let authoredItems = loaded.items.filter {
                        $0.addedBy.recordID == profile.id
                    }
                    itemCount += authoredItems.count
                    for item in authoredItems {
                        switch item.status {
                        case .wantToGo: wantToGoCount += 1
                        case .planned: plannedCount += 1
                        case .completed: completedCount += 1
                        }
                        categoryCounts[item.category, default: 0] += 1
                    }
                    boardStats.append(
                        BoardProfileStats(
                            id: candidate.id,
                            title: candidate.title,
                            itemCount: authoredItems.count
                        )
                    )
                } catch {
                    // Keep useful partial stats when one board is temporarily
                    // unavailable. The page calls this out explicitly.
                }
            }

            let favoriteCategory = ItemCategory.supported.max { lhs, rhs in
                let lhsCount = categoryCounts[lhs, default: 0]
                let rhsCount = categoryCounts[rhs, default: 0]
                if lhsCount == rhsCount {
                    return ItemCategory.supported.firstIndex(of: lhs)!
                        > ItemCategory.supported.firstIndex(of: rhs)!
                }
                return lhsCount < rhsCount
            }.flatMap { categoryCounts[$0, default: 0] > 0 ? $0 : nil }

            return .loaded(
                ProfileStats(
                    boardCount: spaces.count,
                    loadedBoardCount: loadedBoardCount,
                    itemCount: itemCount,
                    wantToGoCount: wantToGoCount,
                    plannedCount: plannedCount,
                    completedCount: completedCount,
                    favoriteCategory: favoriteCategory,
                    boards: boardStats.sorted {
                        if $0.itemCount == $1.itemCount { return $0.title < $1.title }
                        return $0.itemCount > $1.itemCount
                    }
                )
            )
        } catch {
            return .failed(message: Self.message(for: error))
        }
    }

    /// Updates the profile record in every known board. Item records are left
    /// untouched: their `addedBy` references continue pointing at the same
    /// profile IDs and resolve to the new display name automatically.
    func updateCurrentUserName(
        firstName: String,
        lastName: String
    ) async -> ProfileNameUpdateResult {
        let cleanedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedFirstName.isEmpty else {
            return .failed(message: "Enter a first name.")
        }

        do {
            try await requireNetwork()
            let userRecordName = (try await service.accountUserRecordID()).recordName
            var updatedBoardCount = 0
            var failedBoardTitles: [String] = []

            for candidate in spaces {
                let candidateService = makeService(candidate)
                do {
                    let loaded = try await candidateService.loadEverything()
                    guard var profile = profileForCurrentAccount(
                        in: loaded.profiles,
                        space: candidate,
                        userRecordName: userRecordName
                    ) else {
                        failedBoardTitles.append(candidate.title)
                        continue
                    }

                    profile.firstName = cleanedFirstName
                    profile.lastName = cleanedLastName
                    let savedRecord = try await candidateService.save(profile.toRecord())
                    let savedProfile = UserProfile(record: savedRecord) ?? profile
                    defaults.set(
                        savedProfile.id.recordName,
                        forKey: profileKey(for: candidate)
                    )
                    updatedBoardCount += 1

                    if candidate == space {
                        if let index = profiles.firstIndex(where: { $0.id == savedProfile.id }) {
                            profiles[index] = savedProfile
                        }
                        currentProfile = savedProfile
                        rememberProfileTemplate(savedProfile)
                    }
                } catch {
                    failedBoardTitles.append(candidate.title)
                }
            }

            if failedBoardTitles.isEmpty {
                return .updated(boardCount: updatedBoardCount)
            }
            if updatedBoardCount > 0 {
                return .partiallyUpdated(
                    updatedBoardCount: updatedBoardCount,
                    failedBoardTitles: failedBoardTitles
                )
            }
            return .failed(message: "Your name couldn’t be updated. Please try again.")
        } catch {
            return .failed(message: Self.message(for: error))
        }
    }

    private func profileForCurrentAccount(
        in candidates: [UserProfile],
        space: Space,
        userRecordName: String
    ) -> UserProfile? {
        if let rememberedID = defaults.string(forKey: profileKey(for: space)),
           let remembered = candidates.first(where: { $0.id.recordName == rememberedID }) {
            return remembered
        }
        return candidates.first {
            Self.profileBelongsToCurrentAccount(
                $0,
                in: space,
                userRecordName: userRecordName
            )
        }
    }

    @discardableResult
    func createProfile(firstName: String, lastName: String) async -> Bool {
        errorMessage = nil
        let requestedSpace = space
        let requestedService = service
        let profile = UserProfile(
            id: requestedService.newRecordID(),
            firstName: firstName,
            lastName: lastName
        )
        do {
            try await requireNetwork()
            let savedRecord = try await requestedService.save(profile.toRecord())
            let savedProfile = UserProfile(record: savedRecord) ?? profile
            guard space == requestedSpace else { return true }
            defaults.set(profile.id.recordName, forKey: profileKey)
            currentProfile = savedProfile
            rememberProfileTemplate(savedProfile)
            if let index = profiles.firstIndex(where: { $0.id == savedProfile.id }) {
                profiles[index] = savedProfile
            } else {
                profiles.append(savedProfile)
            }
            _ = await refresh()
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
        let requestedSpace = space
        let requestedService = service
        do {
            try await requireNetwork()
            let savedRecord = try await requestedService.save(item.toRecord())
            if space == requestedSpace,
               let savedItem = RecordDecoder.item(from: savedRecord) {
                if let index = items.firstIndex(where: { $0.id == savedItem.id }) {
                    items[index] = savedItem
                } else {
                    items.append(savedItem)
                }
                items.sort { $0.dateAdded > $1.dateAdded }
                remember(items: items, in: requestedSpace)
                _ = await refresh()
            }
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
        let profileTemplate = currentProfile.map {
            ProfileNameTemplate(firstName: $0.firstName, lastName: $0.lastName)
        } ?? rememberedProfileTemplate()
        if isSwitchingBoard, selectedSpace == space { return }
        guard selectedSpace != space else {
            space = selectedSpace
            isSwitchingBoard = true
            if loadState == .loaded {
                do {
                    try await provisionProfileIfNeeded(
                        in: selectedSpace,
                        using: profileTemplate
                    )
                    guard space == selectedSpace else { return }
                } catch {
                    let message = Self.message(for: error)
                    errorMessage = message
                    loadState = .failed(message: message)
                }
                isSwitchingBoard = false
                return
            }
            let result = await performRefresh()
            guard space == selectedSpace else { return }
            if case .loaded = result {
                do {
                    try await provisionProfileIfNeeded(
                        in: selectedSpace,
                        using: profileTemplate
                    )
                    guard space == selectedSpace else { return }
                    loadState = .loaded
                } catch {
                    let message = Self.message(for: error)
                    errorMessage = message
                    loadState = .failed(message: message)
                }
            }
            isSwitchingBoard = false
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

        switch result {
        case .loaded:
            do {
                try await provisionProfileIfNeeded(
                    in: selectedSpace,
                    using: profileTemplate
                )
                guard space == selectedSpace else { return }
                loadState = .loaded
                isSwitchingBoard = false
            } catch {
                guard space == selectedSpace else { return }
                errorMessage = Self.message(for: error)
                space = previousSpace
                service = previousService
                items = previousItems
                profiles = previousProfiles
                currentProfile = previousProfile
                activeShare = previousShare
                loadState = previousLoadState
                isSwitchingBoard = false
                SpaceStore.save(previousSpace, in: defaults)
                spaces = SpaceStore.loadAll(from: defaults)
            }
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
            isSwitchingBoard = false
            SpaceStore.save(previousSpace, in: defaults)
            spaces = SpaceStore.loadAll(from: defaults)
        case .superseded:
            break
        }
    }

    /// Profiles are records inside each board's zone. When an existing Docket
    /// user joins a new board, copy their name into that zone silently instead
    /// of treating the absent per-board record as a signed-out session.
    private func provisionProfileIfNeeded(
        in targetSpace: Space,
        using template: ProfileNameTemplate?
    ) async throws {
        guard currentProfile == nil else { return }
        let targetService = service
        let userRecordName = try await targetService.accountUserRecordID().recordName
        guard space == targetSpace else { return }

        if let existing = profileForCurrentAccount(
            in: profiles,
            space: targetSpace,
            userRecordName: userRecordName
        ) {
            defaults.set(existing.id.recordName, forKey: profileKey(for: targetSpace))
            currentProfile = existing
            rememberProfileTemplate(existing)
            return
        }

        guard let template else { return }
        let profile = UserProfile(
            id: targetService.newRecordID(),
            firstName: template.firstName,
            lastName: template.lastName
        )
        let savedRecord = try await targetService.save(profile.toRecord())
        guard space == targetSpace else { return }
        var savedProfile = UserProfile(record: savedRecord) ?? profile
        savedProfile.creatorUserRecordName = userRecordName
        defaults.set(savedProfile.id.recordName, forKey: profileKey(for: targetSpace))
        profiles.append(savedProfile)
        currentProfile = savedProfile
        rememberProfileTemplate(savedProfile)
    }

    /// Queues a confirmation sheet after CloudKit accepts an invitation. On a
    /// cold launch, presentation waits until the user's existing identity has
    /// had a chance to load so the invite never looks like a sign-in failure.
    func openAcceptedShare(
        _ acceptedSpace: Space,
        inviterName: String? = nil
    ) async {
        let invitation = BoardInvitation(
            space: acceptedSpace,
            inviterName: inviterName?.trimmingCharacters(in: .whitespacesAndNewlines).orNil
        )
        pendingAcceptedInvitation = invitation
        shareAcceptanceErrorMessage = nil
        guard didBootstrap else { return }
        presentPendingBoardInvitationIfNeeded()
    }

    /// Keeps the already-accepted CloudKit membership available without
    /// changing the board currently on screen.
    func dismissBoardInvitation() {
        guard !isJoiningBoardInvitation else { return }
        boardInvitation = nil
        pendingAcceptedInvitation = nil
    }

    /// Opens the accepted board and silently provisions this person's profile
    /// inside its shared zone. CloudKit can take a few moments to expose a
    /// freshly accepted zone, so retry briefly before surfacing an error.
    func joinPendingBoardInvitation() async {
        guard
            let invitation = boardInvitation ?? pendingAcceptedInvitation,
            !isJoiningBoardInvitation
        else { return }

        isJoiningBoardInvitation = true
        shareAcceptanceErrorMessage = nil
        defer { isJoiningBoardInvitation = false }

        let acceptedSpace = invitation.space
        await switchTo(space: acceptedSpace)
        if finishBoardInvitationIfLoaded(acceptedSpace) { return }

        for delay in [
            Duration.milliseconds(500),
            .seconds(1.5),
            .seconds(3),
            .seconds(6)
        ] {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            await switchTo(space: acceptedSpace)
            if finishBoardInvitationIfLoaded(acceptedSpace) { return }
        }

        shareAcceptanceErrorMessage =
            "The invitation was accepted, but iCloud is still preparing the board. Tap Join Board to try again in a moment."
    }

    private func presentPendingBoardInvitationIfNeeded() {
        guard didBootstrap, let invitation = pendingAcceptedInvitation else { return }

        // CKAcceptSharesOperation has already granted membership. Catalog it
        // now while preserving the currently selected board, which gives Not
        // Now useful semantics instead of losing the accepted invitation.
        SpaceStore.replace(
            with: spaces + [invitation.space],
            selected: space,
            in: defaults
        )
        spaces = SpaceStore.loadAll(from: defaults)
        boardInvitation = invitation
    }

    private func finishBoardInvitationIfLoaded(_ acceptedSpace: Space) -> Bool {
        guard space == acceptedSpace, loadState == .loaded, !isSwitchingBoard else {
            return false
        }
        boardInvitation = nil
        pendingAcceptedInvitation = nil
        return true
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

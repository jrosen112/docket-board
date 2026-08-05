//
//  BoardStore.swift
//  Docket
//
//  The main-actor, observable façade the UI watches. This file owns loaded
//  state plus lifecycle and refresh orchestration. Focused behavior lives in
//  the BoardStore extensions under Store/.
//
//  Services and UserDefaults are injected (with production defaults) so the
//  store remains unit-testable with in-memory collaborators.
//

import CloudKit
import Observation

@MainActor
@Observable
final class BoardStore {
    // Implementation dependencies and coordination state are internal so the
    // focused BoardStore extensions in Store/ can collaborate without making
    // them part of any public API.
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored let makeService: @Sendable (Space) -> any SpaceDataService
    @ObservationIgnored let notificationService: any BoardNotificationService
    @ObservationIgnored let networkAvailability: any NetworkAvailabilityProviding
    var service: any SpaceDataService

    static let accountRecordNameKey = "docket.iCloudAccountRecordName.v1"
    static let profileTemplateFirstNameKey = "docket.profileTemplate.firstName.v1"
    static let profileTemplateLastNameKey = "docket.profileTemplate.lastName.v1"
    @ObservationIgnored var isBootstrapping = false
    @ObservationIgnored var didBootstrap = false
    @ObservationIgnored var isReconcilingLifecycle = false
    @ObservationIgnored var notificationsPrepared = false
    @ObservationIgnored var needsMembershipRecovery = false
    @ObservationIgnored var pendingAcceptedInvitation: BoardInvitation?
    @ObservationIgnored var pendingDeepLink: BoardDeepLink?

    /// The board (space) this store is currently pointed at.
    var space: Space
    /// Every owned or accepted board available to the switcher.
    var spaces: [Space]
    /// True when this device owns the current board (can invite others).
    var isOwner: Bool { space.isOwned }

    /// Every item currently on the board, newest first.
    var items: [any SharedListItem] = []
    /// All participants' profiles on this board, for displaying `addedBy`.
    var profiles: [UserProfile] = []
    /// Tapbacks are separate records so reacting never conflicts with editing
    /// the item itself.
    var reactions: [BoardReaction] = []
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
    var isSwitchingBoard = false
    var errorMessage: String?
    var shareAcceptanceErrorMessage: String?
    /// An accepted CloudKit invitation waiting for the user to choose whether
    /// to open it now. The membership remains in the board switcher if they
    /// choose Not Now.
    var boardInvitation: BoardInvitation?
    var isJoiningBoardInvitation = false
    /// Consumed by BoardView after a notification has selected and loaded the
    /// destination board.
    var itemNavigationRequest: BoardItemNavigationRequest?
    /// Initial loading is distinct from onboarding. A failed CloudKit read must
    /// never look like a brand-new user with no profile.
    var loadState: BoardLoadState = .loading

    /// Monotonically increasing token for refreshes. Main-actor methods can be
    /// re-entered while awaiting CloudKit, so only the newest request may
    /// publish results.
    @ObservationIgnored var refreshGeneration = 0

    /// The container, exposed for UICloudSharingController.
    var container: CKContainer { service.container }
    /// A share prepared and waiting to be presented in the share sheet.
    var activeShare: CKShare?
    var activeShareSpace: Space?

    init(
        defaults: UserDefaults = DocketSharedDefaults.production(),
        makeService: @escaping @Sendable (Space) -> any SpaceDataService = {
            CloudKitService(space: $0)
        },
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

    struct ProfileNameTemplate {
        let firstName: String
        let lastName: String
    }

    /// Which profile record is "me" is local state, and it's per-board: the
    /// same person can have different profiles on different boards.
    var profileKey: String { profileKey(for: space) }

    func profileKey(for space: Space) -> String {
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
    func reconcileCurrentProfile() {
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

    func rememberProfileTemplate(_ profile: UserProfile) {
        defaults.set(profile.firstName, forKey: Self.profileTemplateFirstNameKey)
        defaults.set(profile.lastName, forKey: Self.profileTemplateLastNameKey)
    }

    func rememberedProfileTemplate() -> ProfileNameTemplate? {
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
        case .firstRun:
            // A second device of the same account: pull the board catalog down
            // rather than leaving the user on the default board alone. A
            // genuinely new account discovers nothing and falls through to
            // profile setup unchanged.
            await loadForPresentation()
            _ = await restoreFromICloud()
        case .signedOut(let message):
            presentSignedOutState(message: message)
        case .unchanged, .indeterminate:
            await loadForPresentation()
        }
        await reclaimCurrentProfileFromLoadedBoardIfPossible()
        if loadState == .loaded,
            currentProfile == nil,
            pendingAcceptedInvitation != nil || spaces.count > 1
        {
            _ = await restoreFromICloud()
        }
        await prepareNotificationsIfNeeded()
        isBootstrapping = false
        didBootstrap = true
        presentPendingBoardInvitationIfNeeded()
        await openPendingDeepLinkIfNeeded()
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
        case .firstRun, .unchanged, .indeterminate:
            if needsMembershipRecovery {
                _ = await restoreFromICloud()
            } else {
                _ = await refresh()
            }
            presentPendingBoardInvitationIfNeeded()
        }
        await prepareNotificationsIfNeeded()
        await openPendingDeepLinkIfNeeded()
    }

    private enum AccountIdentityResult {
        case unchanged
        /// This install has never seen an account before. Distinct from
        /// `changed`: there is no stale local state to wipe, but the board
        /// catalog is device-local, so memberships still have to be discovered
        /// from CloudKit or the device shows nothing but the default board.
        case firstRun
        case changed
        case signedOut(message: String)
        case indeterminate
    }

    private func reconcileAccountIdentity() async -> AccountIdentityResult {
        do {
            let currentRecordName = try await service.accountUserRecordID().recordName
            let previousRecordName = defaults.string(forKey: Self.accountRecordNameKey)
            defaults.set(currentRecordName, forKey: Self.accountRecordNameKey)
            guard let previousRecordName else { return .firstRun }
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
        for key in defaults.dictionaryRepresentation().keys
        where
            key.hasPrefix("docket.currentProfileRecordName.")
            || key.hasPrefix("docket.knownItemRecordNames.")
            || key.hasPrefix("docket.knownItemVersions.")
            || key.hasPrefix("docket.profileTemplate.")
        {
            defaults.removeObject(forKey: key)
        }
        SpaceStore.replace(with: [.default], selected: .default, in: defaults)
        space = .default
        spaces = SpaceStore.loadAll(from: defaults)
        service = makeService(.default)
        items = []
        profiles = []
        reactions = []
        currentProfile = nil
        activeShare = nil
        activeShareSpace = nil
        pendingAcceptedInvitation = nil
        boardInvitation = nil
        isJoiningBoardInvitation = false
        pendingDeepLink = nil
        itemNavigationRequest = nil
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
        reactions = []
        currentProfile = nil
        activeShare = nil
        activeShareSpace = nil
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
            await repairCurrentProfileIdentityIfNeeded()
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
            await repairCurrentProfileIdentityIfNeeded()
            let addedItemCount = items.count { !previousIDs.contains($0.id) }
            return BoardRefreshSummary(addedItemCount: addedItemCount)
        case .failed, .superseded:
            return nil
        }
    }

    enum RefreshResult {
        case loaded
        case failed(String)
        case superseded
    }

    func performRefresh() async -> RefreshResult {
        refreshGeneration += 1
        let generation = refreshGeneration
        let requestedService = service
        let requestedSpace = space
        isLoading = true
        do {
            try await requireNetwork()
            let loaded = try await requestedService.loadEverything()
            guard generation == refreshGeneration else { return .superseded }
            items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = loaded.profiles
            reactions = loaded.reactions
            reconcileCurrentProfile()
            remember(items: loaded.items, in: space)
            errorMessage = nil
            isLoading = false
            await reconcileBoardTitle(
                from: loaded,
                in: requestedSpace,
                using: requestedService
            )
            return .loaded
        } catch {
            guard generation == refreshGeneration else { return .superseded }
            let message = Self.message(for: error)
            errorMessage = message
            isLoading = false
            return .failed(message)
        }
    }

    // MARK: - Shared error presentation

    func requireNetwork() async throws {
        if await networkAvailability.availability() == .unavailable {
            throw BoardConnectivityError.offline
        }
    }

    static func isConflict(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .serverRecordChanged { return true }
        guard cloudError.code == .partialFailure,
            let partial = cloudError.partialErrorsByItemID
        else { return false }
        return partial.values.contains { isConflict($0) }
    }

    static func message(for error: Error) -> String {
        UserFacingError.message(for: error)
    }
}

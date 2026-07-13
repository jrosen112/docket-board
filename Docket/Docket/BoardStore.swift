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
    case conflict
    case failed
}

@MainActor
@Observable
final class BoardStore {

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let makeService: @Sendable (Space) -> any SpaceDataService
    private var service: any SpaceDataService

    /// The board (space) this store is currently pointed at.
    private(set) var space: Space
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
        makeService: @escaping @Sendable (Space) -> any SpaceDataService = { CloudKitService(space: $0) }
    ) {
        let space = SpaceStore.load(from: defaults)
        self.defaults = defaults
        self.makeService = makeService
        self.space = space
        self.service = makeService(space)
        migrateLegacyProfileKey()
    }

    // MARK: - "Who am I" persistence (per space)

    /// Which profile record is "me" is local state, and it's per-board: the
    /// same person can have different profiles on different boards.
    private var profileKey: String { "docket.currentProfileRecordName.\(space.id)" }

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
        currentProfile = profiles.first(where: { $0.id.recordName == name })
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        await loadForPresentation()
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

    func refresh() async {
        _ = await performRefresh()
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
            let loaded = try await requestedService.loadEverything()
            guard generation == refreshGeneration else { return .superseded }
            items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = loaded.profiles
            reconcileCurrentProfile()
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

    @discardableResult
    func createProfile(firstName: String, lastName: String) async -> Bool {
        errorMessage = nil
        let profile = UserProfile(
            id: service.newRecordID(),
            firstName: firstName,
            lastName: lastName
        )
        do {
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
    @discardableResult
    func save(_ item: any SharedListItem) async -> StoreSaveResult {
        errorMessage = nil
        do {
            try await service.save(item.toRecord())
            await refresh()
            return .saved
        } catch {
            let isConflict = Self.isConflict(error)
            errorMessage = isConflict
                ? "Someone else edited this item. Reload the board to see their version, then try your edit again."
                : Self.message(for: error)
            return isConflict ? .conflict : .failed
        }
    }

    func delete(_ item: any SharedListItem) async {
        do {
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
            activeShare = try await service.createZoneShare()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Debug seeding (compiled out of Release/TestFlight)

    #if DEBUG
    /// Populates the board with SampleData so UI iteration doesn't require
    /// re-entering items by hand. Saved once, then a single refresh.
    func seedSampleData() async {
        guard let me = currentProfile else { return }
        do {
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
            for item in samples {
                try await service.delete(item.id)
            }
            await refresh()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }
    #endif

    /// Point the store at a different board (e.g. after accepting a share
    /// invite) and reload. Per-space profile keys mean any profile on the
    /// previous board stays intact for when multi-board switching arrives.
    func switchTo(space newSpace: Space) async {
        guard newSpace != space else { return }
        // Invalidate any in-flight read before changing services.
        refreshGeneration += 1
        SpaceStore.save(newSpace, in: defaults)
        space = newSpace
        service = makeService(newSpace)
        items = []
        profiles = []
        currentProfile = nil
        activeShare = nil
        await loadForPresentation()
    }

    // MARK: - Error presentation

    private static func isConflict(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .serverRecordChanged { return true }
        guard cloudError.code == .partialFailure,
              let partial = cloudError.partialErrorsByItemID
        else { return false }
        return partial.values.contains { isConflict($0) }
    }

    private static func message(for error: Error) -> String {
        error.localizedDescription
    }
}

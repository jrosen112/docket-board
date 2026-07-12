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

    var isLoading = false
    var errorMessage: String?
    /// False until the first load finishes, so the UI doesn't flash the profile
    /// setup screen before we've checked CloudKit for an existing profile.
    var hasLoadedOnce = false

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
        guard let name = defaults.string(forKey: profileKey) else { return }
        if let match = profiles.first(where: { $0.id.recordName == name }) {
            currentProfile = match
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        await refresh()
        hasLoadedOnce = true
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await service.loadEverything()
            items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = loaded.profiles
            reconcileCurrentProfile()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Profile

    func createProfile(firstName: String, lastName: String) async {
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Items

    /// A fresh record ID in this space's zone, for building a new item.
    func newItemID() -> CKRecord.ID { service.newRecordID() }

    /// Saves a new or edited item. Edited items carry their CloudKit change
    /// tag (systemFields), so concurrent-edit conflicts surface as errors
    /// rather than silently clobbering the other person's change.
    func save(_ item: any SharedListItem) async {
        do {
            try await service.save(item.toRecord())
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: any SharedListItem) async {
        do {
            try await service.delete(item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    /// Point the store at a different board (e.g. after accepting a share
    /// invite) and reload. Per-space profile keys mean any profile on the
    /// previous board stays intact for when multi-board switching arrives.
    func switchTo(space newSpace: Space) async {
        guard newSpace != space else { return }
        SpaceStore.save(newSpace, in: defaults)
        space = newSpace
        service = makeService(newSpace)
        items = []
        profiles = []
        currentProfile = nil
        activeShare = nil
        await refresh()
    }
}

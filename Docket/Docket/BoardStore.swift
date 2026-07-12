//
//  BoardStore.swift
//  Docket
//
//  The main-actor, observable layer the UI watches. Wraps CloudKitService and
//  holds the currently-loaded items, the participants' profiles, and who "I" am.
//  Views stay dumb: they read these properties and call these methods.
//

import CloudKit
import Observation

@MainActor
@Observable
final class BoardStore {

    private let service = CloudKitService()
    private static let currentProfileKey = "docket.currentProfileRecordName"

    /// Every item currently on the board, newest first.
    var items: [any SharedListItem] = []
    /// Both participants' profiles, keyed for display of `addedBy`.
    var profiles: [UserProfile] = []
    /// Whichever profile belongs to this device's user.
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

    // MARK: - Lifecycle

    func bootstrap() async {
        await refresh()
        reconcileCurrentProfile()
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-resolves `currentProfile` from the locally-remembered record name.
    private func reconcileCurrentProfile() {
        guard let name = UserDefaults.standard.string(forKey: Self.currentProfileKey) else { return }
        if let match = profiles.first(where: { $0.id.recordName == name }) {
            currentProfile = match
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
            UserDefaults.standard.set(profile.id.recordName, forKey: Self.currentProfileKey)
            currentProfile = profile
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Items

    /// A fresh record ID in the shared zone, for building a new item.
    func newItemID() -> CKRecord.ID { service.newRecordID() }

    func add(_ item: any SharedListItem) async {
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
}

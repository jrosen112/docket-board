import CloudKit
import Foundation

extension BoardStore {
    @discardableResult
    func prepareShare(for targetSpace: Space? = nil) async -> Bool {
        let targetSpace = targetSpace ?? space
        do {
            try await requireNetwork()
            let targetService = targetSpace == space ? service : makeService(targetSpace)
            activeShare = try await targetService.loadShare()
            activeShareSpace = targetSpace
            return true
        } catch {
            errorMessage = Self.message(for: error)
            activeShare = nil
            activeShareSpace = nil
            return false
        }
    }

    func clearPreparedShare() {
        activeShare = nil
        activeShareSpace = nil
    }

    /// Loads lightweight board cards without changing the selected board.
    func loadBoardManagementSnapshots() async -> [BoardManagementSnapshot] {
        let candidates = spaces
        return await withTaskGroup(of: BoardManagementSnapshot.self) { group in
            for candidate in candidates {
                let candidateService = candidate == space ? service : makeService(candidate)
                group.addTask {
                    do {
                        let loaded = try await candidateService.loadEverything()
                        return BoardManagementSnapshot(
                            space: candidate,
                            itemCount: loaded.items.count,
                            participantNames: loaded.profiles
                                .map(\.displayName)
                                .filter { !$0.isEmpty }
                                .sorted(),
                            isAvailable: true
                        )
                    } catch {
                        return BoardManagementSnapshot(
                            space: candidate,
                            itemCount: 0,
                            participantNames: [],
                            isAvailable: false
                        )
                    }
                }
            }

            var snapshotsByID: [String: BoardManagementSnapshot] = [:]
            for await snapshot in group {
                snapshotsByID[snapshot.id] = snapshot
            }
            return candidates.compactMap { snapshotsByID[$0.id] }
        }
    }

    /// Permanently removes an owned board's CloudKit zone. If it is currently
    /// open, move to a healthy fallback before deleting so a failed switch can
    /// never strand the UI on a zone that no longer exists.
    @discardableResult
    func deleteBoard(_ targetSpace: Space) async -> Bool {
        guard targetSpace.isOwned else {
            errorMessage = "Only the board owner can delete this board."
            return false
        }
        guard spaces.count > 1,
              let fallback = spaces.first(where: { $0 != targetSpace })
        else {
            errorMessage = "Create another board before deleting your only board."
            return false
        }

        let targetService = targetSpace == space ? service : makeService(targetSpace)
        if targetSpace == space {
            await switchTo(space: fallback)
            guard space == fallback, loadState == .loaded else { return false }
        }

        do {
            try await requireNetwork()
            try await targetService.deleteBoardZone()
            removeLocalBoard(targetSpace, selecting: space)
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    /// The native CloudKit people sheet performs the actual leave operation.
    /// Its delegate calls this afterward to remove the stale local membership.
    func finishLeavingBoard(_ targetSpace: Space) async {
        guard !targetSpace.isOwned, spaces.count > 1 else { return }
        if targetSpace == space,
           let fallback = spaces.first(where: { $0 != targetSpace }) {
            // The shared zone is already gone, so select a fallback directly
            // through normal switching before pruning the local membership.
            await switchTo(space: fallback)
            guard space == fallback else { return }
        }
        removeLocalBoard(targetSpace, selecting: space)
    }

    private func removeLocalBoard(_ targetSpace: Space, selecting selected: Space) {
        defaults.removeObject(forKey: profileKey(for: targetSpace))
        defaults.removeObject(forKey: rememberedItemsKey(for: targetSpace))
        defaults.removeObject(forKey: rememberedItemVersionsKey(for: targetSpace))
        SpaceStore.remove(targetSpace, selecting: selected, in: defaults)
        spaces = SpaceStore.loadAll(from: defaults)
        if activeShareSpace == targetSpace { clearPreparedShare() }
    }

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
            activeShareSpace = nil
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
}

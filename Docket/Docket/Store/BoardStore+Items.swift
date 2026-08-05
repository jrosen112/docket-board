import CloudKit
import Foundation

extension BoardStore {
    /// A fresh record ID in this space's zone, for building a new item.
    func newItemID() -> CKRecord.ID { service.newRecordID() }

    /// A stable destination ID is chosen before an operation starts so retrying
    /// a network failure cannot create a second copy.
    func newItemID(in destination: Space) -> CKRecord.ID {
        (destination == space ? service : makeService(destination)).newRecordID()
    }

    /// Copies an item into another board without switching the visible board.
    /// A move saves and confirms the destination first, then removes the source.
    func transfer(
        _ item: any SharedListItem,
        to destination: Space,
        kind: BoardItemTransferKind,
        destinationRecordID: CKRecord.ID
    ) async -> BoardItemTransferResult {
        let sourceSpace = space
        let sourceService = service

        guard destination != sourceSpace, spaces.contains(destination) else {
            return .failed(message: "Choose another available board.")
        }

        do {
            try await requireNetwork()
            let destinationService = makeService(destination)
            var loaded = try await destinationService.loadEverything()
            let destinationProfile = try await transferProfile(
                in: destination,
                loadedProfiles: loaded.profiles,
                using: destinationService
            )

            if !loaded.items.contains(where: { $0.id == destinationRecordID }) {
                guard
                    let copiedItem = ItemDraft(item: item).makeNew(
                        id: destinationRecordID,
                        addedBy: destinationProfile.reference,
                        dateAdded: .now
                    )
                else {
                    return .failed(message: "This item type can’t be copied yet.")
                }

                do {
                    let savedRecord = try await destinationService.save(copiedItem.toRecord())
                    if let savedItem = RecordDecoder.item(from: savedRecord) {
                        loaded.items.append(savedItem)
                    } else {
                        loaded.items.append(copiedItem)
                    }
                } catch let error as CKError where error.code == .serverRecordChanged {
                    // This random ID belongs only to this operation. A conflict
                    // means an earlier attempt reached CloudKit before its
                    // response was lost, so continuing is the idempotent path.
                }
            }
            remember(items: loaded.items, in: destination)

            guard kind == .move else { return .duplicated }
            return await removeTransferredSource(
                item,
                from: sourceSpace,
                using: sourceService
            )
        } catch let error as BoardItemTransferError {
            return .failed(message: error.localizedDescription)
        } catch {
            return .failed(message: Self.message(for: error))
        }
    }

    /// Retries only the destructive half of a move after the copy is already
    /// known to exist in the destination.
    func finishMove(
        _ item: any SharedListItem,
        from sourceSpace: Space
    ) async -> BoardItemTransferResult {
        do {
            try await requireNetwork()
            let sourceService = sourceSpace == space ? service : makeService(sourceSpace)
            return await removeTransferredSource(
                item,
                from: sourceSpace,
                using: sourceService
            )
        } catch {
            return .copiedButSourceKept(message: Self.message(for: error))
        }
    }

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
                let savedItem = RecordDecoder.item(from: savedRecord)
            {
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
                    message:
                        "Someone else edited this item. Reload the board to see their version, then try your edit again."
                )
            }
            return .failed(message: Self.message(for: error))
        }
    }

    @discardableResult
    func delete(_ item: any SharedListItem) async -> StoreDeleteResult {
        do {
            try await requireNetwork()
            try await service.delete(item.id)
            items.removeAll { $0.id == item.id }
            reactions.removeAll { $0.itemID == item.id }
            return .deleted
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            return .failed(message: message)
        }
    }

    private func transferProfile(
        in destination: Space,
        loadedProfiles: [UserProfile],
        using destinationService: any SpaceDataService
    ) async throws -> UserProfile {
        let userRecordName = try await destinationService.accountUserRecordID().recordName
        if let existing = profileForCurrentAccount(
            in: loadedProfiles,
            space: destination,
            userRecordName: userRecordName
        ) {
            defaults.set(existing.id.recordName, forKey: profileKey(for: destination))
            return existing
        }

        guard
            let template = currentProfile.map({
                ProfileNameTemplate(firstName: $0.firstName, lastName: $0.lastName)
            }) ?? rememberedProfileTemplate()
        else {
            throw BoardItemTransferError.profileUnavailable
        }

        let profile = UserProfile(
            id: destinationService.newRecordID(),
            firstName: template.firstName,
            lastName: template.lastName,
            accountRecordName: userRecordName
        )
        let savedRecord = try await destinationService.save(profile.toRecord())
        let savedProfile = UserProfile(record: savedRecord) ?? profile
        defaults.set(savedProfile.id.recordName, forKey: profileKey(for: destination))
        return savedProfile
    }

    private func removeTransferredSource(
        _ item: any SharedListItem,
        from sourceSpace: Space,
        using sourceService: any SpaceDataService
    ) async -> BoardItemTransferResult {
        do {
            try await sourceService.delete(item.id)
        } catch let error as CKError where error.code == .unknownItem {
            // A retry after an ambiguous response is already complete.
        } catch {
            return .copiedButSourceKept(message: Self.message(for: error))
        }

        if space == sourceSpace {
            items.removeAll { $0.id == item.id }
            reactions.removeAll { $0.itemID == item.id }
            remember(items: items, in: sourceSpace)
        }
        return .moved
    }

    /// Display name for whoever added an item.
    func displayName(for item: any SharedListItem) -> String {
        profiles.first { $0.id.recordName == item.addedBy.recordID.recordName }?.displayName ?? "—"
    }

    func reactionGroups(for item: any SharedListItem) -> [BoardReactionGroup] {
        let mine = currentProfile?.id
        return orderedKinds(for: item).map { kind in
            let matches = reactions.filter {
                $0.itemID == item.id && $0.kind == kind
            }
            return BoardReactionGroup(
                kind: kind,
                count: matches.count,
                includesCurrentUser: mine.map { profileID in
                    matches.contains { $0.profileID == profileID }
                } ?? false
            )
        }
    }

    /// Kinds actually present on an item. Standard tapbacks come first in their
    /// picker order so the familiar set reads the same everywhere; custom emoji
    /// follow in the order they were first used on this item.
    private func orderedKinds(for item: any SharedListItem) -> [BoardReactionKind] {
        let itemReactions =
            reactions
            .filter { $0.itemID == item.id }
            .sorted { $0.dateAdded < $1.dateAdded }
        let present = Set(itemReactions.map(\.kind))

        var ordered = BoardReactionKind.standard.filter(present.contains)
        for reaction in itemReactions
        where !reaction.kind.isStandard && !ordered.contains(reaction.kind) {
            ordered.append(reaction.kind)
        }
        return ordered
    }

    func currentReaction(for item: any SharedListItem) -> BoardReactionKind? {
        guard let profileID = currentProfile?.id else { return nil }
        return reactions.first {
            $0.itemID == item.id && $0.profileID == profileID
        }?.kind
    }

    func reactionAttributions(
        for item: any SharedListItem
    ) -> [BoardReactionAttribution] {
        orderedKinds(for: item).compactMap { kind in
            let people =
                reactions
                .filter { $0.itemID == item.id && $0.kind == kind }
                .sorted { $0.dateAdded < $1.dateAdded }
                .map { reaction -> BoardReactionPerson in
                    let profile = profiles.first { $0.id == reaction.profileID }
                    let name =
                        profile?.displayName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .orNil
                    return BoardReactionPerson(
                        profileID: reaction.profileID,
                        displayName: name ?? "Someone",
                        // A missing profile still gets an avatar rather than a gap.
                        initials: profile?.initials ?? "?"
                    )
                }
            guard !people.isEmpty else { return nil }
            return BoardReactionAttribution(kind: kind, people: people)
        }
    }

    /// Selecting the current tapback removes it; selecting another replaces
    /// it. Optimistic local updates keep the interaction feeling immediate.
    func setReaction(
        _ kind: BoardReactionKind,
        for item: any SharedListItem
    ) async {
        guard let profile = currentProfile else {
            errorMessage = "Finish setting up your profile before reacting."
            return
        }

        do {
            try await requireNetwork()
            if let existingIndex = reactions.firstIndex(where: {
                $0.itemID == item.id && $0.profileID == profile.id
            }) {
                let existing = reactions[existingIndex]
                if existing.kind == kind {
                    reactions.remove(at: existingIndex)
                    do {
                        try await service.delete(existing.id)
                    } catch {
                        reactions.insert(existing, at: min(existingIndex, reactions.count))
                        throw error
                    }
                } else {
                    var replacement = existing
                    replacement.kind = kind
                    reactions[existingIndex] = replacement
                    do {
                        let saved = try await service.save(replacement.toRecord())
                        reactions[existingIndex] = BoardReaction(record: saved) ?? replacement
                    } catch {
                        reactions[existingIndex] = existing
                        throw error
                    }
                }
            } else {
                let reaction = BoardReaction(
                    id: BoardReaction.recordID(for: item.id, profileID: profile.id),
                    itemID: item.id,
                    reactedBy: profile.reference,
                    kind: kind
                )
                reactions.append(reaction)
                do {
                    let saved = try await service.save(reaction.toRecord())
                    if let index = reactions.firstIndex(where: { $0.id == reaction.id }) {
                        reactions[index] = BoardReaction(record: saved) ?? reaction
                    }
                } catch {
                    reactions.removeAll { $0.id == reaction.id }
                    throw error
                }
            }
            errorMessage = nil
        } catch {
            errorMessage =
                Self.isConflict(error)
                ? "Your reactions changed on another device. Refresh the board and try again."
                : Self.message(for: error)
        }
    }

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
}

private enum BoardItemTransferError: LocalizedError {
    case profileUnavailable

    var errorDescription: String? {
        "Your profile isn’t available on the destination board yet. Open that board once, then try again."
    }
}

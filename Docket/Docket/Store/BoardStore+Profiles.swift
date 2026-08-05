import CloudKit
import Foundation

private struct ProfileIdentityRepair {
    let items: [any SharedListItem]
    let profiles: [UserProfile]
    let reactions: [BoardReaction]
    let profile: UserProfile
}

extension BoardStore {
    /// Reclaims this iCloud user's profiles and board memberships on a new
    /// device. New profiles carry an explicit account record name; creator
    /// metadata remains as the migration path for older records.
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

            var restored:
                [(
                    space: Space,
                    service: any SpaceDataService,
                    items: [any SharedListItem],
                    profiles: [UserProfile],
                    reactions: [BoardReaction],
                    profile: UserProfile
                )] = []
            var firstLoadError: Error?
            // Titles CloudKit knows win over whatever this device cached — a
            // device that only ever saw "Shared Board" corrects itself here.
            var resolvedCandidates: [Space] = []

            for candidate in candidates {
                let candidateService = makeService(candidate)
                do {
                    let loaded = try await candidateService.loadEverything()
                    let candidate = Self.retitled(candidate, from: loaded.boardInfo)
                    resolvedCandidates.append(candidate)
                    guard
                        let profile = profileForCurrentAccount(
                            in: loaded.profiles,
                            space: candidate,
                            userRecordName: userRecordName
                        )
                    else { continue }
                    let repair = try? await repairProfileIdentity(
                        items: loaded.items,
                        profiles: loaded.profiles,
                        reactions: loaded.reactions,
                        preferredProfile: profile,
                        in: candidate,
                        using: candidateService,
                        userRecordName: userRecordName
                    )
                    restored.append(
                        (
                            candidate,
                            candidateService,
                            repair?.items ?? loaded.items,
                            repair?.profiles ?? loaded.profiles,
                            repair?.reactions ?? loaded.reactions,
                            repair?.profile ?? profile
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
            let catalog = candidates.map { candidate in
                resolvedCandidates.first(where: { $0.id == candidate.id }) ?? candidate
            }
            SpaceStore.replace(with: catalog, selected: selected.space, in: defaults)
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
            reactions = selected.reactions
            currentProfile = selected.profile
            rememberProfileTemplate(selected.profile)
            activeShare = nil
            activeShareSpace = nil
            errorMessage = nil
            isLoading = false
            loadState = .loaded
            needsMembershipRecovery = firstLoadError != nil
            await repairCurrentProfileIdentityIfNeeded()
            return .restored(boardCount: restored.count)
        } catch {
            needsMembershipRecovery = true
            let message = Self.message(for: error)
            errorMessage = message
            isLoading = false
            return .failed(message: message)
        }
    }

    /// A board named in its own zone overrides the local title, which may be
    /// nothing more than the fallback this device invented when it discovered
    /// the zone.
    private static func retitled(_ space: Space, from boardInfo: BoardInfo?) -> Space {
        guard let title = boardInfo?.title.orNil, title != space.title else { return space }
        return Space(zoneID: space.zoneID, access: space.access, title: title)
    }

    /// New records use the explicit account field. CloudKit creator metadata
    /// is only a legacy fallback; the current account can be represented by
    /// `CKCurrentUserDefaultName` in fetched system metadata.
    static func profileBelongsToCurrentAccount(
        _ profile: UserProfile,
        in space: Space,
        userRecordName: String
    ) -> Bool {
        if profile.accountRecordName == userRecordName { return true }
        guard let creator = profile.creatorUserRecordName else { return false }
        if creator == userRecordName { return true }
        return creator == CKCurrentUserDefaultName
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
                    let accountProfiles = profilesForCurrentAccount(
                        in: loaded.profiles,
                        space: candidate,
                        userRecordName: userRecordName
                    )
                    guard !accountProfiles.isEmpty else { continue }

                    loadedBoardCount += 1
                    let profileIDs = Set(accountProfiles.map(\.id))
                    let authoredItems = loaded.items.filter {
                        profileIDs.contains($0.addedBy.recordID)
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

    /// Updates the profile record in every known board. Any legacy duplicate
    /// identity is folded into the canonical profile first, preserving item
    /// attribution while the name propagates.
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
                    guard
                        let existingProfile = profileForCurrentAccount(
                            in: loaded.profiles,
                            space: candidate,
                            userRecordName: userRecordName
                        )
                    else {
                        failedBoardTitles.append(candidate.title)
                        continue
                    }

                    let repair = try? await repairProfileIdentity(
                        items: loaded.items,
                        profiles: loaded.profiles,
                        reactions: loaded.reactions,
                        preferredProfile: existingProfile,
                        in: candidate,
                        using: candidateService,
                        userRecordName: userRecordName
                    )
                    var profile = repair?.profile ?? existingProfile

                    profile.firstName = cleanedFirstName
                    profile.lastName = cleanedLastName
                    profile.accountRecordName = userRecordName
                    let savedRecord = try await candidateService.save(profile.toRecord())
                    let savedProfile = UserProfile(record: savedRecord) ?? profile
                    defaults.set(
                        savedProfile.id.recordName,
                        forKey: profileKey(for: candidate)
                    )
                    updatedBoardCount += 1

                    if candidate == space {
                        if let repair {
                            items = repair.items.sorted { $0.dateAdded > $1.dateAdded }
                            profiles = repair.profiles
                            reactions = repair.reactions
                        }
                        if let index = profiles.firstIndex(where: { $0.id == savedProfile.id }) {
                            profiles[index] = savedProfile
                        } else {
                            profiles.append(savedProfile)
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

    func profileForCurrentAccount(
        in candidates: [UserProfile],
        space: Space,
        userRecordName: String
    ) -> UserProfile? {
        let matches = profilesForCurrentAccount(
            in: candidates,
            space: space,
            userRecordName: userRecordName
        )
        if let rememberedID = defaults.string(forKey: profileKey(for: space)),
            let remembered = matches.first(where: { $0.id.recordName == rememberedID })
        {
            return remembered
        }
        let stamped = matches.filter { $0.accountRecordName == userRecordName }
        return (stamped.isEmpty ? matches : stamped).min {
            $0.id.recordName < $1.id.recordName
        }
    }

    func profilesForCurrentAccount(
        in candidates: [UserProfile],
        space: Space,
        userRecordName: String
    ) -> [UserProfile] {
        var matches = candidates.filter {
            Self.profileBelongsToCurrentAccount(
                $0,
                in: space,
                userRecordName: userRecordName
            )
        }

        // A freshly-saved record can briefly arrive without creator metadata.
        // Trust a remembered legacy record only when it has no explicit,
        // contradictory account identity.
        if let rememberedID = defaults.string(forKey: profileKey(for: space)),
            let remembered = candidates.first(where: { $0.id.recordName == rememberedID }),
            remembered.accountRecordName == nil,
            remembered.creatorUserRecordName == nil,
            !matches.contains(where: { $0.id == remembered.id })
        {
            matches.append(remembered)
        }
        return matches
    }

    func reclaimCurrentProfileFromLoadedBoardIfPossible() async {
        guard currentProfile == nil, loadState == .loaded else { return }
        do {
            let userRecordName = try await service.accountUserRecordID().recordName
            guard
                let profile = profileForCurrentAccount(
                    in: profiles,
                    space: space,
                    userRecordName: userRecordName
                )
            else { return }
            defaults.set(profile.id.recordName, forKey: profileKey)
            currentProfile = profile
            rememberProfileTemplate(profile)
            await repairCurrentProfileIdentityIfNeeded()
        } catch {
            // Normal restore/onboarding remains available if identity lookup is
            // temporarily unavailable.
        }
    }

    @discardableResult
    func createProfile(firstName: String, lastName: String) async -> Bool {
        errorMessage = nil
        let requestedSpace = space
        let requestedService = service
        do {
            try await requireNetwork()
            let accountRecordName = try await requestedService.accountUserRecordID().recordName
            let profile = UserProfile(
                id: requestedService.newRecordID(),
                firstName: firstName,
                lastName: lastName,
                accountRecordName: accountRecordName
            )
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
            await repairCurrentProfileIdentityIfNeeded()
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    /// Stamps legacy profiles with the stable account field and safely folds
    /// duplicate profiles created by an earlier reinstall bug into one stable
    /// survivor. Every item reference is rewritten before an extra profile is
    /// deleted, so attribution is never orphaned.
    func repairCurrentProfileIdentityIfNeeded() async {
        guard let selectedProfile = currentProfile else { return }

        do {
            let accountRecordName = try await service.accountUserRecordID().recordName
            defaults.set(accountRecordName, forKey: Self.accountRecordNameKey)
            guard
                let repair = try await repairProfileIdentity(
                    items: items,
                    profiles: profiles,
                    reactions: reactions,
                    preferredProfile: selectedProfile,
                    in: space,
                    using: service,
                    userRecordName: accountRecordName
                )
            else { return }

            items = repair.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = repair.profiles
            reactions = repair.reactions
            replaceLoadedProfile(repair.profile)
            defaults.set(repair.profile.id.recordName, forKey: profileKey)
            remember(items: items, in: space)
        } catch {
            // Identity repair is maintenance, not a reason to hide a healthy
            // board. It retries on the next launch or foreground transition.
        }
    }

    private func repairProfileIdentity(
        items loadedItems: [any SharedListItem],
        profiles loadedProfiles: [UserProfile],
        reactions loadedReactions: [BoardReaction],
        preferredProfile: UserProfile,
        in targetSpace: Space,
        using targetService: any SpaceDataService,
        userRecordName: String
    ) async throws -> ProfileIdentityRepair? {
        var accountProfiles = loadedProfiles.filter {
            Self.profileBelongsToCurrentAccount(
                $0,
                in: targetSpace,
                userRecordName: userRecordName
            )
        }

        // Permit only a metadata-less remembered profile as an additional
        // migration candidate. An explicitly different account must never be
        // adopted merely because a stale UserDefaults key points to it.
        if let loadedPreferred = loadedProfiles.first(where: { $0.id == preferredProfile.id }),
            loadedPreferred.accountRecordName == nil,
            loadedPreferred.creatorUserRecordName == nil,
            !accountProfiles.contains(where: { $0.id == loadedPreferred.id })
        {
            accountProfiles.append(loadedPreferred)
        }
        guard !accountProfiles.isEmpty else { return nil }

        // Every device signed into the same iCloud account must choose the
        // same survivor. Prefer an already-stamped profile, then use the
        // record name as a stable tie-breaker so concurrent repairs converge.
        let stamped = accountProfiles.filter {
            $0.accountRecordName == userRecordName
        }
        let canonicalPool = stamped.isEmpty ? accountProfiles : stamped
        guard
            var canonical = canonicalPool.min(by: {
                $0.id.recordName < $1.id.recordName
            })
        else { return nil }
        let duplicates = accountProfiles.filter { $0.id != canonical.id }

        if canonical.accountRecordName != userRecordName {
            let legacyCreator = canonical.creatorUserRecordName
            canonical.accountRecordName = userRecordName
            let saved = try await targetService.save(canonical.toRecord())
            canonical = UserProfile(record: saved) ?? canonical
            canonical.creatorUserRecordName =
                canonical.creatorUserRecordName ?? legacyCreator
        }

        let duplicateIDs = Set(duplicates.map(\.id))
        var repairedItems: [any SharedListItem] = []
        repairedItems.reserveCapacity(loadedItems.count)

        // Finish every reference rewrite before deleting any profile. A
        // network or conflict failure therefore leaves a retryable state.
        for item in loadedItems {
            guard duplicateIDs.contains(item.addedBy.recordID) else {
                repairedItems.append(item)
                continue
            }
            var repaired = item
            repaired.addedBy = canonical.reference
            let saved = try await targetService.save(repaired.toRecord())
            repairedItems.append(RecordDecoder.item(from: saved) ?? repaired)
        }

        var repairedReactions = loadedReactions
        for reaction in loadedReactions
        where duplicateIDs.contains(reaction.profileID) {
            if repairedReactions.contains(where: {
                $0.id != reaction.id
                    && $0.itemID == reaction.itemID
                    && $0.profileID == canonical.id
            }) {
                try await targetService.delete(reaction.id)
                repairedReactions.removeAll { $0.id == reaction.id }
                continue
            }

            let replacement = BoardReaction(
                id: BoardReaction.recordID(
                    for: reaction.itemID,
                    profileID: canonical.id
                ),
                itemID: reaction.itemID,
                reactedBy: canonical.reference,
                kind: reaction.kind,
                dateAdded: reaction.dateAdded
            )
            let saved = try await targetService.save(replacement.toRecord())
            let savedReaction = BoardReaction(record: saved) ?? replacement
            try await targetService.delete(reaction.id)
            if let index = repairedReactions.firstIndex(where: { $0.id == reaction.id }) {
                repairedReactions[index] = savedReaction
            }
        }

        for duplicate in duplicates {
            try await targetService.delete(duplicate.id)
        }

        var repairedProfiles = loadedProfiles.filter {
            !duplicateIDs.contains($0.id)
        }
        if let index = repairedProfiles.firstIndex(where: { $0.id == canonical.id }) {
            repairedProfiles[index] = canonical
        } else {
            repairedProfiles.append(canonical)
        }
        return ProfileIdentityRepair(
            items: repairedItems,
            profiles: repairedProfiles,
            reactions: repairedReactions,
            profile: canonical
        )
    }

    private func replaceLoadedProfile(_ profile: UserProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        currentProfile = profile
        rememberProfileTemplate(profile)
    }
}
